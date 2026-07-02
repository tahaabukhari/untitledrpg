# MASTER PROMPT — UNTITLED RPG: Combat Overhaul + Boss Fight

> **You are an expert Godot 4.3 GDScript engineer.** Your job is to implement the
> features and fixes below in the existing **UNTITLED RPG** project without breaking
> working systems, matching the codebase's established conventions.
>
> **Before writing any code, read `docs/CODEBASE_CONTEXT.md` in full.** It documents the
> architecture, the puppet animator, the weapon-animator plugin pattern, signal wiring,
> collision layers, and the known-issue list. Every instruction below assumes that context.

---

## 0. Ground Rules (non-negotiable)

1. **Match existing conventions** (see CONTEXT §4): programmatic UI, code-driven puppet
   animation (no external anim editor, no player sprite sheets), data-driven weapons via
   `WeaponData` + `WeaponAnimator` plugins, signal-based communication, groups for discovery.
2. **Stay on Godot 4.3 APIs.** GDScript only. Typed variables and function signatures.
3. **Scene-safe spawning.** All transient VFX / projectiles / damage numbers go through a
   persistent container or autoload — never orphan-prone `get_tree().current_scene` /
   `get_parent().get_parent()`. Guard callbacks with `is_instance_valid()`.
4. **Don't hardcode viewport coordinates.** Use viewport-relative positioning / anchors.
5. **Reuse the plugin patterns.** New weapons = new `WeaponAnimator` subclass + `.tres`.
   New enemies = extend a shared enemy base. New attacks = angle-parameterized builders.
6. **Keep touch and PC input behavior-identical** by routing both through one input layer
   (see Phase 1). Do not fork combat logic per input method.
7. **Every phase must leave the game runnable.** Work incrementally; verify on PC after
   each phase (see §Testing).
8. Preserve save-compat where a save system exists after Phase 8 (version your save format).

### Global design decisions (already made — implement exactly these)
- **Audit scope:** fix **all** audit issues (P0–P3) in addition to new features (Phase 8
  covers the remainder not required earlier).
- **Dodge roll REPLACES the current evade dash** (directional roll + i-frames).
- **Boss fight runs in a NEW dedicated arena scene** (`boss_arena.tscn`), quick-launchable.
- **Directional attacks are 8-directional**, implemented via an **angle-parameterized swing
  builder** (one builder → 8 directions) rather than 8 hand-authored animations.

---

## 1. Deliverables Overview

New/changed systems:
- A. PC controls (keyboard + mouse) + unified input layer + continuous charge input.
- B. Player combat completion: `take_damage`, hurtbox, hit/hurt state, i-frames, death
  (implement `dieo` death screen), 8-directional attacks + directional slash VFX.
- C. **Dodge roll** (replaces evade) and **Parry** (timing block + stagger/reflect).
- D. Enemy combat framework: shared enemy base, enemy attack hitboxes that damage the
  player, directional slash animations; upgrade slime, complete whisperer.
- E. **Mannequin** training dummy (with a parry-practice toggle).
- F. Basic class weapons/tools for all 4 classes + **Mage charged laser beam**.
- G. **4-armed / 4-sword miniboss** (4× size, dynamic sword damage, summon/dismiss swords,
   dash attacks, grab-and-throw with airtime damage).
- H. Boss arena scene + quick-launch + class/debug switches.
- I. Audit remediation (refactor PlayerController, save/load, VFX manager, typing, etc.).

Build order below is dependency-ordered. **Follow it.**

---

## PHASE 0 — Foundation & Blocking Audit Fixes

Do these first; later phases depend on them.

- **VFX/particle manager (scene-safe).** Add an autoload `Fx` (or a persistent Node2D
  container spawned per level) exposing: `hit_particles(pos)`, `damage_number(pos, amount, color)`,
  `swing_arc(...)`, `slash_effect(pos, dir, downward)`, `beam(...)`. Migrate the current
  spawners in `playercontroller.gd` (`_spawn_hit_particles`), `player_animator.gd`
  (`_spawn_swing_arc`, `_spawn_sword_slash_effect`) and `slime.gd` (`_spawn_damage_number`)
  to route through it. Guard every tween callback with `is_instance_valid()`.
- **Single jump path.** Extract the duplicated jump logic
  (`_physics_process` `ui_accept` block vs `_on_jump_button_pressed`) into one
  `_perform_jump()` and call it from both input sources.
- **Fix profile toggle.** Replace the hardcoded screen-rect check
  (`playercontroller.gd:223-238`) with a viewport-relative hit test on the HUD preview
  circle, or (better) route it through a HUD signal.
- **Standardize collision layers** per CONTEXT §10. Add named layers in project settings.
- **Delete dead code:** `playbutton.gd`. Implement (don't delete) `dieo` as the death
  screen in Phase 2.

---

## PHASE 1 — PC Controls + Unified Input Layer

**Goal:** the game is fully playable on PC with keyboard+mouse, while touch still works.

- **Add InputMap actions** (`project.godot` `[input]`). Recommended bindings:

  | Action | Keyboard/Mouse | Notes |
  |---|---|---|
  | `move_left` / `move_right` | A/D + ←/→ | feeds `joystick_vector.x` |
  | `move_up` / `move_down` | W/S + ↑/↓ | aim vertical component |
  | `jump` | Space | also keep `ui_accept` working |
  | `attack` | J or Left-Click | tap = normal, hold = charge |
  | `dodge` | Shift or L | dodge roll |
  | `parry` | K or Right-Click | parry window |
  | `interact` | E | pick up / activate |
  | `open_inventory` | I or Tab | |
  | `open_profile` | P | |
  | `pause` | Esc | |
  | Aim | Mouse position | 8-dir aim for directional attacks/laser |
  | Debug: `dbg_class_1..4` | 1/2/3/4 | switch class at runtime (arena only) |
  | Debug: `dbg_spawn_boss` | B | (arena only) |

- **Unified input layer.** Create `input_controller.gd` (or fold into a small
  `PlayerInput` child node) that produces a single canonical output each frame:
  `move_vector: Vector2`, `aim_vector: Vector2`, and edge/held signals for
  attack/dodge/parry/jump. Both the virtual joystick/ring **and** keyboard/mouse feed it.
  `playercontroller` consumes only this layer's output — no duplicated per-source logic.
  - Keyboard move → `move_vector` from `Input.get_vector("move_left","move_right","move_up","move_down")`.
  - Mouse aim → `aim_vector = (mouse_world_pos - player_world_pos).normalized()`.
  - Touch aim → existing `joystick.get_attack_direction()`.
- **Continuous charge.** Replace the binary charge in `attack_button_ring.gd` /input layer
  with a **continuous** charge level `0.0..1.0` (clamp) plus an optional overcharge flag.
  Expose `charge_level` on attack-release so the mage laser (Phase 6/F) scales with it.
  Keep the ring's visual arc driven by the same value.
- Auto-hide touch controls when a keyboard/mouse input is detected, show again on touch
  (optional but recommended for clean PC testing).

**Acceptance:** Move/jump/attack/charge/dodge/parry/inventory/profile/pause all work from
keyboard+mouse; touch still works; aim direction reflects mouse or joystick.

---

## PHASE 2 — Player Combat Completion

### 2A. Player damageable
- Add a **PlayerHurtbox** Area2D (layer 3) to `player.tscn`.
- Implement on the player: `take_damage(amount:int, source_pos:Vector2, knockback:Vector2)`:
  - Apply `defense`/`stat_def` mitigation, subtract HP (`update_bars()`).
  - Trigger **hurt state** (brief hitstun, flash), knockback impulse, damage number.
  - Grant **i-frames** (short invulnerability) after being hit.
  - Respect current defensive state: if parrying → negate + trigger parry success; if
    dodge i-frames or hurt i-frames → ignore.
  - On HP ≤ 0 → `die()`.
- **Hurt & death animations** in the puppet animator (`_make_hurt()`, `_make_death()`).
- **Death screen:** implement `dieo.gd/.tscn` (programmatic UI: "You Died", Retry/Title).
  Wire `pausemenu` RETRY + death retry through a single respawn path.

### 2B. 8-Directional attacks + slash VFX (players AND monsters share the builder)
- Add an **angle-parameterized swing builder** to `WeaponAnimator` (base) or a shared
  helper: `make_directional_swing(pivots, angle_rad, opts) -> Animation`. It builds a slash
  whose swing plane is oriented by `angle_rad` (derived from the 8 aim directions), inserts
  `_enable_hitbox`/`_disable_hitbox` method tracks and a directional slash-VFX call, and
  positions/rotates the `AttackHitbox` toward the aim direction.
- `play_attack()` picks the direction from `aim_vector` (8-way quantized) and plays the
  corresponding directional swing. Combos still advance per `combo_anims` but each step is
  oriented by aim.
- **Directional slash VFX**: `Fx.slash_effect(pos, dir, ...)` draws the arc oriented along
  the attack direction (generalize the current horizontal-only slash).
- The **same builder is reused by enemies** (Phase 4/G) so monster slashes are directional too.

**Acceptance:** attacking while aiming up/down/diagonally produces correctly-oriented
swings, hitboxes, and slash VFX; hits register on enemies in those directions.

---

## PHASE 3 — Dodge Roll & Parry

### 3A. Dodge roll (REPLACES evade)
- Remove the reversed-dash evade. New **dodge roll**:
  - Direction from `move_vector` (fallback: facing).
  - Costs stamina + small saturation; has a cooldown.
  - **I-frames** during the roll's active window (player invulnerable).
  - Roll animation in the puppet animator (`_make_roll()` — forward tuck/rotation; reuse
    the long-fall full-body rotation technique but grounded and directional).
  - Cannot attack mid-roll; movement is roll-driven.
- Rebind to `dodge` action + repurpose the existing EvadeButton to dodge on touch.

### 3B. Parry
- On `parry` input: enter a short **parry window** (e.g. 0.2s) with a guard pose animation
  (`_make_parry()`), then a brief recovery. Must be **facing** the incoming attack
  (or within a frontal arc) to succeed.
- Enemy attack hitboxes (Phase 4) check the player's parry state on contact:
  - **Perfect parry** (within window, correct facing): negate all damage, **stagger the
    attacker** (stun + knockback), spark VFX, optional slow-mo/flash, and open a counter
    window. **Reflect projectiles/beams** back at the source.
  - **Late/failed parry:** normal damage (optionally reduced chip damage).
- Parry consumes a small stamina amount; add cooldown to prevent spam.

**Acceptance:** dodge roll grants i-frames (walk through an attack unharmed mid-roll);
a well-timed parry negates a slime/boss hit and staggers the attacker; a mistimed parry
takes damage.

---

## PHASE 4 — Enemy Combat Framework

- **Shared enemy base** `enemy_base.gd` (`class_name EnemyBase`, extends CharacterBody2D):
  HP, `take_damage`, `_die` (scaled EXP — fix the fixed-10 issue: EXP scales with size/level),
  flash, damage numbers (via `Fx`), knockback, group `"enemy"`, standardized collision
  layer 4, and an **attack hitbox helper** (spawns/enables an EnemyHitbox Area2D on layer 5
  / mask 3 that calls `player.take_damage`, honoring parry/i-frames).
- **Directional enemy slashes** using the Phase 2 shared swing builder (enemies face the
  player and swing toward them).
- **Line-of-sight** for aggro: replace pure distance checks with a `RayCast2D`/`ShapeCast2D`
  LOS test (fixes the "no LOS" audit item).
- **Upgrade slime** (`slime.gd`): ATTACK state now performs a real telegraphed lunge/bite
  that enables an EnemyHitbox and damages the player; keep the state machine; refactor onto
  `EnemyBase`.
- **Complete whisperer** (`whisperer.gd`): give it HP/`take_damage`/`_die`, collision layer 4,
  a working `_attack_player`, sprite flip on rush, and EXP on death. Refactor onto `EnemyBase`.

**Acceptance:** slime and whisperer both damage the player, can be killed, drop scaled EXP,
and respect parry/i-frames.

---

## PHASE 5 — Mannequin (Training Dummy)

- `mannequin.gd/.tscn`, in group `"enemy"` (so player hitboxes/laser detect it), on
  `EnemyBase`.
- Behaves as a **stationary dummy**: very high or regenerating HP (configurable, default
  effectively unkillable for testing), reacts to hits (flash, damage numbers, small hitstun
  wobble), and shows a floating **DPS / last-hit readout** above it.
- **Parry-practice toggle** (`@export var attacks: bool`): when on, it performs a slow,
  clearly telegraphed swing on an interval so the tester can practice parry/dodge timing.
- Uses the puppet-style rig OR a simple sprite — a simple layered sprite is acceptable here.

**Acceptance:** you can wail on it to test directional attacks, combos, and the laser; DPS
readout updates; with `attacks=true` you can practice parry/dodge against it.

---

## PHASE 6 — Class Weapons/Tools + Mage Laser Beam

### 6A. Basic class weapons/tools (all 4 classes)
- Give each class a **starter weapon** `WeaponData` `.tres` + animator, selected from class:
  - **Warrior:** starter sword (reuse `sword_animator`) — melee combo (already exists).
  - **Ranger:** ranged weapon (bow/thrown) — fires a simple projectile toward `aim_vector`
    (new `ProjectileWeaponAnimator` + projectile scene through `Fx`/scene-safe spawn).
  - **Mage:** staff — normal attack via `staff_animator`; **charged = laser beam** (6B).
  - **Healer:** staff/wand — normal attack + a **heal tool** charged action (restores
    HP over a short channel, costs mana).
- Auto-equip the class's starter weapon on spawn based on `Global.current_class`
  (extend `global.gd` with a `class_starter_weapon` mapping, or resolve in player `_ready`).
- Keep these **basic** — correctness over polish for non-mage classes. Mage laser is the
  showcase.

### 6B. Mage charged laser beam (SHOWCASE FEATURE)
- **Trigger:** hold the attack/charge input while a mage staff is equipped → charge builds
  a continuous `charge_level` (Phase 1). Release to **fire**.
- **Direction:** `aim_vector` (8-dir from joystick, or mouse aim on PC). A straight beam.
- **Scaling with hold time / charge_level:**
  - `damage = lerp(min_dmg, max_dmg, charge_level)`
  - `range  = lerp(min_range, max_range, charge_level)`
  - Optionally `width`/pierce scales too. Allow a max charge cap.
  - Costs mana proportional to charge (block firing if insufficient mana).
- **Hitscan implementation:** `RayCast2D`/`ShapeCast2D` from player along `aim_vector`,
  length = computed range, mask = enemy layer 4. **Piercing** (hits all enemies along the
  line) for a laser feel. Apply damage + knockback + hit VFX at each hit point.
- **Visuals:** a `Line2D` beam (bright core + fading glow), a charge-up telegraph on the
  staff tip that grows with `charge_level`, muzzle flash, and a short beam-fade on release.
  Route through `Fx.beam(...)`. A brief cast animation in the puppet (`_make_cast()`).
- **Feel:** small screen shake / recoil scaled by charge; beam persists ~0.1–0.2s.

**Acceptance:** holding longer visibly grows the charge telegraph; a short tap fires a
weak short beam, a full charge fires a strong long piercing beam; mana is consumed; the
beam damages all enemies (and the mannequin) along the aimed line in any of the 8 directions.

---

## PHASE 7 — 4-Armed / 4-Sword Miniboss

Create `boss_fourblade.gd/.tscn` on `EnemyBase` (extend as needed). Spec:

- **Size:** ~**4× the player**. Substantial HP; scaled EXP on death.
- **Body:** 4 arms, each wielding a sword (puppet-style rig or layered sprites with per-arm
  pivots so swords can swing independently and be shown/hidden).
- **Dynamic sword damage ("attack points at will"):** each of the 4 swords independently
  **accrues a randomized damage/charge value over time** (a per-sword `power` that ticks up
  by random increments, capped). When a sword strikes, its damage = its current `power`,
  then resets. **Telegraph** each sword's power via glow intensity/scale so attacks read as
  unpredictable but fair (bigger glow = harder hit). This is the boss's signature — make the
  randomness visible.
- **Summon/dismiss swords at will:** the boss can make any subset of its 4 swords **appear
  or disappear** (fade + VFX). Attacks only come from currently-summoned swords. Vary the
  active set between actions for unpredictability.
- **Dash attacks:** telegraphed dash toward the player (or across the arena) with active
  sword hitboxes during the dash; brief recovery after. Uses the shared directional swing/
  hitbox system.
- **Grab-and-throw (chance-based):** on a cooldown, a chance to attempt a **grab** when in
  range — if it connects (and the player isn't dodging/parrying):
  - Seize the player, lift them, and **throw** them (launch upward/across). During the
    **airtime**, apply damage (impact on throw + fall/landing damage), disabling normal
    control briefly. A well-timed **parry/dodge just before the grab avoids it** (counterplay).
  - Make the grab **telegraphed** (wind-up pose + reach) so it's dodgeable.
- **AI / phases:** a simple state machine (IDLE/APPROACH/SLASH/DASH/GRAB/SUMMON/STAGGER).
  Optional 2-phase: below 50% HP, summon more swords / faster power accrual / more dashes.
  Boss must be **staggerable by a perfect parry** (opens a damage window).
- **Directional slashes** via the shared Phase 2 builder, scaled up for boss size.
- All VFX/telegraphs scene-safe via `Fx`.

**Acceptance:** the boss summons/dismisses swords, each sword hits for a visibly-telegraphed
variable amount, it performs dash attacks, and it can grab+throw the player for airtime
damage (avoidable by dodge/parry). The fight is winnable with the player kit and clearly
readable.

---

## PHASE 8 — Boss Arena + Audit Remediation (remainder)

### 8A. Boss arena scene
- `boss_arena.tscn`: a flat, walled arena (platforms optional) containing the player,
  the miniboss (spawn on `B` debug key or on start), and a mannequin off to the side.
- **Quick-launch:** allow bypassing title→class-select when testing (e.g. an export/debug
  flag or a launch key), auto-assigning a class. Provide runtime **class switch** (debug
  keys 1–4) that re-equips the class starter weapon so all classes (esp. mage laser) can be
  tested in one session.
- Do **not** modify `DemoMap.tscn` for the boss test.

### 8B. Remaining audit items (finish these here if not already done)
- **Refactor PlayerController** into components as child nodes: `PlayerMovement.gd`,
  `PlayerCombat.gd`, `PlayerStats.gd`, `PlayerUIManager.gd` (per audit rec #4). Keep the
  public API/signals stable so scenes keep working.
- **Save/load system** (ConfigFile or JSON): persist inventory, stats, level, equipped
  weapon, saturation, class. Load on level enter; save on pause/quit and key milestones.
  Version the format.
- **Strict typing** pass: add type hints project-wide; enable typed checks.
- **`preload()`/`const`** instead of runtime `load()` for fonts/scripts.
- **Inventory fixes:** emit `weapon_unequipped` on swap; allow drag-drop to armor slots
  with type validation; remove emoji icons (use textures) at least for the close button and
  class icons; use a `Dictionary`/`Set` for `hit_enemies_this_swing`.
- **Profile UI:** populate the equipment section with actual equipped items; implement (or
  clearly stub with real data) the skills section; render an actual character preview;
  cache `player_ref` once.
- **HUD:** de-magic-number the viewport-relative positions; avoid recreating tweens faster
  than their duration; reduce per-frame `update_bars()` cost (only push on change).
- **Titlescreen:** fix the `TouchScreenButton`-nested-in-`Button` misalignment.

---

## Testing & Verification (PC)

After each phase, run the project on PC and verify the phase's **Acceptance** criteria.
Recommended smoke test once Phase 7–8 land:
1. Launch → boss arena (quick-launch). Switch through classes 1–4.
2. As **Warrior**: 8-direction combos on the mannequin; dodge-roll through a mannequin
   telegraphed swing (no damage during i-frames); parry it (attacker staggers).
3. As **Mage**: tap laser (weak/short) vs full-charge laser (strong/long/piercing) in
   several directions; confirm mana drain.
4. As **Ranger/Healer**: basic weapon + tool work.
5. Spawn boss (`B`): confirm sword summon/dismiss, variable telegraphed sword damage, dash
   attacks, and grab-and-throw (then confirm dodge/parry avoids the grab). Kill it → scaled
   EXP + no orphaned VFX after it frees.
6. Take lethal damage → death screen → retry respawns cleanly.
7. Confirm touch controls still function (emulate touch / mobile export).

## Definition of Done
- All 8 phases implemented; each phase's acceptance criteria pass on PC.
- No orphaned nodes/errors on scene changes or entity death (check the debugger).
- Touch and PC inputs both work and are behavior-identical.
- Audit HIGH/MEDIUM items resolved; LOW/INFO addressed or explicitly deferred with a note.
- Project still boots from `titlescreen.tscn` and the normal flow works, plus the new
  `boss_arena.tscn` quick-launch.

## Suggested new files (indicative — adapt to your structure)
```
autoload/fx.gd                      # scene-safe VFX/damage-number/beam manager
input_controller.gd                 # unified touch+KBM input layer (+ continuous charge)
player/player_movement.gd           # (Phase 8 refactor)
player/player_combat.gd
player/player_stats.gd
player/player_ui_manager.gd
combat/hurtbox.gd, combat/hitbox.gd # reusable Area2D helpers
enemies/enemy_base.gd               # class_name EnemyBase
enemies/mannequin.gd/.tscn
enemies/boss_fourblade.gd/.tscn
weapons/animators/projectile_weapon_animator.gd   # ranger
weapons/animators/mage_staff_animator.gd          # + laser cast anim
weapons/laser_beam.gd               # hitscan beam + Line2D visual
weapons/{ranger_bow,mage_staff,healer_wand}.tres  # class starter weapons
dieo.gd (implement)                 # death screen
save/save_manager.gd                # (Phase 8) persistence
boss_arena.tscn                     # dedicated test arena
```
Keep the flat-repo style where the project already uses it; only add subfolders where they
clearly improve organization (weapons/ and enemies/ groupings are encouraged).
