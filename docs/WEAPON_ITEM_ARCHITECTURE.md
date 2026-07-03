# WEAPON & ITEM ARCHITECTURE — Audit & Scaling Plan

> **Purpose.** We intend to ship *tons* of weapons and items, each owning its own
> attack animations, stances, effects, and stats. This document audits what is
> **built and working today**, names the **coupling that will not scale**, and
> proposes a **target architecture + migration path** to get there.
>
> This is a design/audit doc — no code changes yet. Companion: `ARCHITECTURE.md`
> (whole-game reference). Current as of the mage beam-staff refinement
> (commit `236ea8b`).

---

## 0. TL;DR

- The **data-driven weapon core is genuinely good** and worth building on:
  `WeaponData` (`.tres`) + a pluggable `WeaponAnimator` (GDScript) is the right
  seam. Each weapon already owns its hold pose, attack animations, and grip.
- **Three things block scale:**
  1. **Behavior lives in the player god-class, not the weapon.** `charged_style`
     is `if/else`-branched inside `playercontroller.gd` (laser/heal/melee). Every
     new attack *kind* edits the 1000-line player script. Effects (beam, heal
     burst, projectile) live in `Fx`/player, not on the weapon.
  2. **`WeaponData` is a flat god-resource.** Laser-only and heal-only fields sit
     on every weapon (a sword carries `laser_min_width`). This bloats linearly
     with each new behavior.
  3. **No item model beyond weapons, and no catalog.** Inventory slots for armor/
     trinkets exist but only `WeaponData` is supported. Weapons are discovered by
     hardcoded `res://…` paths in 3 files — no registry, no stable IDs (save/load
     will need them).
- **Recommended shape:** an `ItemData` hierarchy, weapon **behavior as a plugin**
  (the animator — or a sibling `WeaponBehavior` — owns attack execution + effects),
  per-behavior tuning as **sub-resources**, per-weapon **animation namespacing**,
  and a **central item registry** keyed by ID.

---

## 1. What's Built & Working

### 1.1 The core pattern (KEEP THIS)

```
WeaponData (.tres, Resource)          ← stats + which animator + which anims
   └─ animator_script: GDScript  ──►  WeaponAnimator subclass (RefCounted)
                                         • setup_visual()      grip + sprite
                                         • get_hold_positions()  baked into locomotion
                                         • get_attack_animations() → { name: Animation }
                                         • teardown_visual()
```

- `weapon_data.gd` — `class_name WeaponData extends Resource`. Exported stat
  groups (Identity / Normal / Charged / Laser / Heal / Animations). `calc_damage()`.
- `weapons/animators/weapon_animator.gd` — `class_name WeaponAnimator extends
  RefCounted`. Plugin contract + **static** track helpers (`anim_pos/rot/zidx/
  method`) and the shared **`make_directional_swing()`** builder.
- `player_animator.gd` — on weapon equip: stops playback (crash guard), applies
  hold pose, calls `setup_visual`, registers the animator's animations into the
  single shared `AnimationLibrary ("")`, and tracks their names in
  `_weapon_anim_names` for clean unregister on swap.

**This is the seam to scale on.** A weapon already fully owns: its sprite/grip
(`setup_visual`), its rest pose while moving (`get_hold_positions`), and its
attack animation set (`get_attack_animations`). Adding a *visually* new weapon of
an existing behavior kind = one `.tres` + one animator subclass, no engine edits.

### 1.2 Weapons shipping today (6)

| `.tres` | Name | Type | Normal | Charged | Animator |
|---|---|---|---|---|---|
| `weapon_fists.tres` | Fists | Fists | melee combo | melee (uppercut) | `fists_animator.gd` |
| `starter_sword.tres` | Starter Sword | Sword | 3-hit melee combo | melee thrust + dash | `sword_animator.gd` |
| `starter_staff.tres` | Starter Staff | Staff | melee sweep/jab | melee | `staff_animator.gd` |
| `mage_beam_staff.tres` | Arcane Conduit | Staff | melee sweep/jab | **laser** (hold beam) | `mage_staff_animator.gd` |
| `ranger_bow.tres` | Starter Bow | Bow | **ranged** (arrow) | ranged (heavier arrow) | `projectile_weapon_animator.gd` |
| `healer_wand.tres` | Healer Wand | Wand | melee flick | **heal** channel | `wand_animator.gd` |

### 1.3 Behavior "styles" that exist (4)

- **melee** — animation method tracks toggle `AttackHitbox`; `_on_attack_hit`
  applies `calc_damage`. Directional (8-way) via `make_directional_swing`.
- **ranged** — the *animation* fires a projectile through a `_fire_projectile`
  method track → `playercontroller.fire_projectile()` → `PlayerProjectile.spawn()`
  (code-drawn arrow, parented under `Fx`, `reflect()`-able).
- **laser** (charged) — hold-to-charge hitscan beam: aim stance, concentric mana
  circle, stacks, uncapped overdrive (range/damage grow, width freezes), mana
  drain + circle-break failure. Piercing rays, `Fx.beam` helix visuals.
- **heal** (charged) — channel that spends mana to restore HP (`Fx.heal_burst`).

### 1.4 Shared systems weapons plug into

- **`make_directional_swing(pivots, angle, opts)`** — one builder → all 8
  directions, rig-agnostic via `opts`. Reused by player, mannequin, and every
  boss arm. New weapons get directional attacks for free.
- **`Fx` autoload** — scene-safe VFX (`hit_particles`, `slash_effect`, `beam`,
  `heal_burst`, `parry_spark`, `circle_break`, damage numbers).
- **Inventory** (`player_inventory_ui.gd` + `inventory_slot.gd`) — 52-slot grid,
  drag-and-drop, equip/unequip via mainhand slot, weapon preview card with stats.
  Emits `weapon_equipped(WeaponData)` / `weapon_unequipped`.
- **Class starter mapping** — `Global.class_starter_weapon` picks each class's
  spawn weapon; `_apply_customization` + stats applied on spawn.

---

## 2. What Each Weapon "Owns" Today vs. What Leaks

| Concern | Owned by the weapon? | Where it actually lives |
|---|---|---|
| Sprite / grip / scale / tint | ✅ Yes | `WeaponAnimator.setup_visual` |
| Hold pose (locomotion) | ✅ Yes | `WeaponAnimator.get_hold_positions` |
| Attack animations + stances | ✅ Yes | `WeaponAnimator.get_attack_animations` (incl. `staff_aim`) |
| Attack STATS (dmg/cooldown/costs) | ✅ Yes | `WeaponData` exports |
| Combo sequence | ✅ Yes | `WeaponData.combo_anims` |
| **Which behavior runs on charge** | ⚠️ Data flag only | `WeaponData.charged_style` **branched in `playercontroller`** |
| **Attack execution logic** | ❌ No | `playercontroller._fire_laser / _perform_heal / _on_attack_button_pressed / fire_projectile` |
| **Effects (beam/heal/beam-break)** | ❌ No | `Fx` + player, keyed by behavior not weapon |
| **Which anim names to play** | ⚠️ Partly | `WeaponData.attack_right_anim/charged_anim` (strings) + hardcoded fallbacks |
| **Discovery / identity** | ❌ No | hardcoded `res://` paths; no stable ID |

**Reading:** the *content* seam (art + anims + numbers) is clean; the *behavior*
seam is not. Behavior is a fixed enum interpreted by the player.

---

## 3. Scaling Risks (the honest audit)

### R1 — Behavior is hardcoded in the player god-class 🔴 HIGH
`charged_style` is switched in **3 places** in `playercontroller.gd`
(`_on_attack_released` :315, `_on_attack_charged` :652, `_laser_stance_active`
:821), and each behavior has a bespoke method (`_fire_laser`, `_perform_heal`, …).
A 5th behavior (e.g. "summon", "whip", "chain-lightning") means editing the
player script again and growing the `if/else`. This is O(behaviors) churn in the
most fragile file.

> Note: `attack_style` ("melee"/"ranged") is **effectively vestigial** — nothing
> branches on it; ranged works purely because the bow's *animation* calls
> `_fire_projectile`. Good (proves animations can own execution) and bad (the
> field lies about being load-bearing). Tests assert on it; real code doesn't.

### R2 — `WeaponData` is a flat god-resource 🟠 MEDIUM
Laser has 7 fields, heal has 2 — all present on *every* weapon incl. fists. Add
"summon" (minion scene, count, duration) and "whip" (reach, arc) and the resource
grows to dozens of mostly-null fields. The inspector becomes unreadable and
weapon `.tres` files carry irrelevant data.

### R3 — One shared animation library, string-addressed 🟠 MEDIUM
All weapons register into `AnimationPlayer`'s single `""` library. Names are
global: two weapons both providing `"attack_right"` or `"staff_charged"` collide;
the directional cache uses `dirswing_<oct>_<step>`; `staff_aim` is hard-referenced
by name in `player_animator.play_aim_pose()`. With hundreds of weapons this risks
silent name clashes and orphaned anims. Registration is guarded (stop-before-mutate
crash fix) but not namespaced.

### R4 — No item model beyond weapons 🟠 MEDIUM
`inventory_slot.item` is typed `WeaponData`. Armor/pants/boots/trinket slots
render and accept drops but there is **no ArmorData/ConsumableData/TrinketData** —
nothing can go in them meaningfully. `_can_drop_data` only allows weapons.
"Same for other items in inventory" (the request) has no foundation yet.

### R5 — No registry / stable IDs 🟠 MEDIUM (blocks save/load)
Weapons are referenced by literal path in `global.gd` (starter map),
`player_inventory_ui._add_starting_items`, and `playercontroller` defaults. There
is no catalog to enumerate, no ID→resource lookup, and **saving inventory will
need stable IDs** (you can't reliably serialize a resource path across renames).

### R6 — Effects not owned by weapons 🟡 LOW-MED
`Fx.beam`/`heal_burst` are generic but *chosen* by player code per behavior. A
weapon can't say "my beam is green with lightning forks" without new `Fx` params
or branches. Fine at 6 weapons; friction at 60.

### R7 — Stats are fixed per `.tres` 🟡 LOW (future)
No rarity, affixes, upgrade levels, or runtime modifiers. Every "Iron Sword +1"
would be a separate `.tres`. Acceptable now; plan for a modifier layer before a
loot system.

---

## 4. Target Architecture (proposed)

Goal: **adding a weapon or item is data + one small plugin, never an engine edit.**

### 4.1 Item type hierarchy

```
ItemData (Resource)                     ← id, display_name, description, icon,
   │                                       item_kind, stack rules, rarity hook
   ├─ WeaponData        (adds combat: behavior + stats + animator)
   ├─ ArmorData         (slot: helmet/chest/pants/boots; defense, resist, set-id)
   ├─ TrinketData       (passive modifiers / on-hit hooks)
   └─ ConsumableData    (use effect: heal/buff/throwable; charges)
```

- `inventory_slot.item` becomes `ItemData`; `_can_drop_data` checks
  `item_kind` against `slot_type` (armor→armor slots, weapon→hand slots).
- Every item has a stable **`id: StringName`** (e.g. `&"arcane_conduit"`), the
  key the registry and save system use — never the file path.

### 4.2 Weapon behavior as a plugin (fixes R1)

Move attack *execution* off the player and onto the weapon. Two viable seams:

- **Option A (recommended): extend the existing animator into a `WeaponBehavior`.**
  The animator already owns anims; give it the execution hooks too:
  ```gdscript
  class_name WeaponBehavior extends WeaponAnimator   # (or a sibling)
      func on_normal(ctx) -> void        # ctx = { player, aim, stat_atk, ... }
      func on_charge_start(ctx) -> void  # enter stance / telegraph
      func on_charge_tick(ctx, level, hold) -> void   # mana circle, drain
      func on_charge_release(ctx, level, hold) -> void # fire beam / heal / …
      func wants_charge_stance() -> bool
  ```
  `playercontroller` shrinks to: gather `ctx`, forward input events to
  `equipped_weapon.behavior`. No `if charged_style ==`. New behavior = new
  subclass, zero player edits.

- **Option B:** a separate `WeaponBehavior` Resource referenced by `WeaponData`,
  so behavior and animation are independently swappable. More flexible, more
  wiring. Prefer A unless a weapon needs to mix-and-match.

Player keeps only *primitives* the behaviors call: `apply_hitscan(...)`,
`spawn_projectile(...)`, `heal(...)`, `screen_shake(...)`, `spend_mana(...)`.
These are the reusable verbs; behaviors compose them.

### 4.3 Per-behavior tuning as sub-resources (fixes R2)

```gdscript
# WeaponData
@export var behavior: WeaponBehavior          # the plugin (4.2)
@export var tuning: BehaviorTuning            # sub-resource, behavior-specific
```
`LaserTuning`, `HealTuning`, `ProjectileTuning` each extend `BehaviorTuning`. A
sword's `.tres` carries no laser fields; the mage staff carries a `LaserTuning`
sub-resource. Inspector shows only what's relevant.

### 4.4 Animation namespacing (fixes R3)

Register each weapon's anims under a per-weapon library name (its `id`) instead of
the shared `""`, or prefix names with the id (`arcane_conduit/charged`). Playback
resolves `equipped_weapon.id + "/" + logical_name`. Kills global collisions and
makes unregister trivial (drop the whole library). Keep the stop-before-mutate
crash guard.

### 4.5 Item registry / catalog (fixes R5)

```gdscript
# autoload ItemDB
func get(id: StringName) -> ItemData
func all_of_kind(kind) -> Array[ItemData]
func starter_for_class(cls) -> WeaponData
```
Populated by scanning `res://items/**` at boot (editor) → baked manifest for
export. `Global.class_starter_weapon`, inventory starting items, and save/load all
go through `ItemDB.get(id)`. One place to register; save files store ids.

### 4.6 Directory layout for scale

```
items/
  weapons/{swords,staves,bows,wands,…}/<id>.tres
  armor/…  trinkets/…  consumables/…
  behaviors/   *.gd  (WeaponBehavior subclasses: melee_combo, projectile, laser, heal, …)
  tuning/      *.gd  (BehaviorTuning subclasses)
  animators/   *.gd  (visual/anim providers — may equal behavior under Option A)
```

---

## 5. Migration Path (incremental, each step ships green)

1. **Registry first (non-breaking).** Add `ItemDB` autoload + `id` on `WeaponData`;
   route the 3 hardcoded-path sites through it. Unlocks save/load later. *No
   behavior change.*
2. **Extract player "verbs".** Pull `_fire_laser`/`_perform_heal`/`fire_projectile`
   bodies into small reusable methods that take params (they mostly are already).
3. **Introduce `WeaponBehavior`** (Option A). Port the 4 existing behaviors into
   subclasses that call the verbs. Replace the `charged_style` branches with
   `behavior.on_charge_release(...)`. Keep `charged_style` as a deprecated shim
   for one release.
4. **Sub-resource tuning.** Move laser/heal flat fields into `LaserTuning`/
   `HealTuning`; migrate the 6 `.tres`.
5. **Namespace animations** per weapon id.
6. **`ItemData` hierarchy + armor/consumables.** Now the inventory slots that
   already exist become functional; `_can_drop_data` gates by kind.
7. **Modifier/rarity layer** (when a loot system is actually needed).

Each step is independently testable with the existing headless harness
(`tests/test_*.gd`); add a `test_itemdb.gd` and `test_behavior_dispatch.gd`.

---

## 6. Invariants to preserve through any refactor

- **Never mutate an `AnimationLibrary` while its `AnimationPlayer` is playing** —
  `stop()` first (the ~50% segfault; guards live in `player_animator`).
- **Scene-safe spawning** — transient nodes parent under `Fx`, guard tween
  callbacks with `is_instance_valid`.
- **One input layer** — behaviors receive already-resolved `aim`/charge from
  `PlayerInput`; never read raw input per weapon.
- **Public signals stable** — `weapon_equipped(WeaponData)` etc.; widen types
  (`ItemData`) rather than renaming.
- **Editor clobber hazard** — the open Godot editor has repeatedly re-saved stale
  buffers over commits; verify `git status` + `Fx=` canary before every commit,
  and reload the project in-editor after external edits.

---

## 7. How to add a weapon — now vs. after refactor

**Today (existing behavior, e.g. a new sword):**
1. New `weapons/animators/my_sword_animator.gd` extends `WeaponAnimator`
   (`setup_visual`, `get_hold_positions`, `get_attack_animations`).
2. New `weapons/my_sword.tres` (stats + `animator_script` + anim names).
3. Reference it (starter map / inventory / drop) by path.
*New behavior kind today also requires editing `playercontroller.gd` — the thing
we're fixing.*

**After refactor (target):**
1. New `items/weapons/…/<id>.tres` with `id`, stats, a `behavior`, and a `tuning`
   sub-resource.
2. Reuse an existing `WeaponBehavior`, or write a new subclass if the *kind* is
   new — **player script untouched**.
3. It auto-registers in `ItemDB`; starter maps, inventory, and saves reference it
   by `id`.

---

## 8. Open questions for product/design

- Are weapons **unique instances** (per-item durability/affixes) or **flyweight**
  shared resources? Decides whether `WeaponData` is duplicated per-inventory-item
  or referenced. (Affects R7 and save format.)
- Dual-wield / offhand semantics — the slot exists; is it a second full weapon, a
  shield (block/parry mod), or a stat trinket?
- Do consumables share the attack button or get their own hotbar?
- Rarity/upgrade model timing — needed for v1 loot, or post-launch?
