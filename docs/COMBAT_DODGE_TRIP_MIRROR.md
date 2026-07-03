# COMBAT UPDATE — Directional Dodge · Tripping · Mirror Monster · Blood

> **STATUS: BUILT** (commit `c95d899`) to the §7.5 locked decisions.
> `tests/test_dodge_trip.gd` (17) + `tests/test_mirror.gd` (13) green; full
> suite green. Spawn the Mirror in the arena with the **M** key. Only the §2c
> "feel" polish (hitstop / perfect-dodge reward) is deferred.

> **Design/context doc — written BEFORE implementation** (per request). Grounds
> the feature in the current code, proposes concrete mechanics + numbers, and
> lays out a build order. Anything marked **[PROPOSAL]** is a default I picked to
> keep momentum — steer it before I build. Companion: `ARCHITECTURE.md`,
> `WEAPON_ITEM_ARCHITECTURE.md`. Current as of `10b82ea` (bombug).

---

## 0. Goal

Round out the combat feel with:
1. **Refine** the existing parry + dodge.
2. **Directional dodge** — the dodge animation & effect changes with your aim:
   up = a leap, side/forward = the roll, down = a forward **slide**.
3. **Tripping** — sliding *under* an opponent knocks them to their knees (2s).
   Symmetric: players trip monsters, monsters trip players.
4. **Mirror monster** — a warrior clone with the full player kit (attacks,
   parry, dodge, slide+trip, counters) to show the mechanics off against you.
5. **Blood & particles** on flesh-and-blood combatants so hits land with weight.

---

## 1. What exists today (grounded)

**Dodge roll** — `playercontroller._perform_dodge_roll()` ([playercontroller.gd:1322](playercontroller.gd:1322)):
- Direction from `joystick_vector.x` (fallback facing). `ROLL_SPEED` 480, `ROLL_TIME`
  0.35s, `ROLL_COOLDOWN` 0.6s, `ROLL_COST` 25 stamina.
- Full-window i-frames (`invuln_timer = ROLL_TIME`), `is_rolling` gates attack/jump.
- Puppet `play_roll()` → `_make_roll()` (full-body tuck, whole-skin spin).

**Parry** — `_perform_parry()` / `_try_parry()` ([playercontroller.gd:1349](playercontroller.gd:1349), :1226):
- `PARRY_WINDOW` 0.2s, `PARRY_RECOVERY` 0.25s, `PARRY_COOLDOWN` 0.5s, `PARRY_COST` 10.
- Perfect parry (in-window + frontal) negates, sparks, opens counter (clears
  `attack_cooldown_timer`), reflects projectiles or `apply_stagger()`s the attacker.

**Shared pieces this update leans on:**
- `input_ctrl.get_aim_vector()` — 8-dir aim (mouse or joystick) already used by
  attacks/laser. **This drives the dodge variant.**
- `WeaponAnimator.make_directional_swing()` — the rig-agnostic swing builder
  (reused by mannequin & boss) — the mirror's attacks use it.
- `EnemyBase` — HP / `take_damage` / `apply_stagger(dur, push)` / attack-hitbox
  helper / LOS. The mirror extends it; tripping adds a downed state to it.
- `Fx` — scene-safe VFX autoload; blood + trip dust land here.
- Player state flags (`is_hurt`, `invuln_timer`, `is_rolling`, `is_parrying`,
  `is_dead`, `is_grabbed`) + `_gameplay_blocked()` — the trip adds one more.

---

## 2. Directional Dodge

**Trigger unchanged** (Shift/L or touch dodge). The *variant* is chosen from the
aim vector **at dodge time** (`input_ctrl.get_aim_vector()`, fallback facing):

| Aim | Variant | Feel |
|---|---|---|
| Up (`y < -0.5`) | **Evade Leap** | a hop ~double-jump height with a horizontal drift + motion streak; airborne i-frames |
| Down (`y > 0.5`) | **Slide** | low forward dash that slides *under* things; trips opponents it passes below |
| Side / forward / neutral | **Roll** | today's tuck-and-roll |

Shared: same button, same `ROLL_COST`/cooldown budget, i-frames during the active
window, `is_rolling` (or a shared `is_dodging`) gates attacks. Each variant is its
own puppet animation.

### 2a. Evade Leap  **[PROPOSAL]**
- Vertical impulse ≈ `JUMP_VELOCITY * 1.15` (a touch above a normal jump; "double-
  jump-sized"), horizontal drift `~260px/s` toward `aim.x` (or facing if centered).
- I-frames for the rising portion (~0.4s). Lands into normal locomotion.
- Motion effect: `Fx.motion_streak()` — a few afterimage/streak lines trailing the
  leap so it reads as a burst, not a jump.
- Anim `_make_evade_leap()` — a tucked upward twist.

### 2b. Slide  **[PROPOSAL]**
- Low forward dash: `~560px/s` for `~0.4s` toward facing, body dropped near the
  ground (visually "sliding under").
- I-frames for the first ~0.3s (early invuln so you slide *through* an attack).
- Carries a **SlideBox** (Area2D at leg/low height, layer = PlayerHitbox-ish) active
  for the whole slide; any opponent it overlaps that is grounded & not i-framed gets
  `trip()`'d (§3).
- Anim `_make_slide()` — legs forward, torso low, one arm back.
- Cannot attack mid-slide, but the trip *is* the payoff (sets up free hits).

### 2c. Refinements to parry/dodge (the "refine" ask)  **[PROPOSAL]**
- **Dodge-cancel window:** allow dodge to interrupt attack *recovery* (not the
  active hitbox) so combat flows better.
- **Perfect-dodge reward:** dodging within ~0.15s of an incoming hit briefly
  refunds a little stamina + a small time-dilation blip (parity with a good parry
  feel). Small, optional.
- **Parry feedback pass:** a hitstop (2–3 frame freeze) on a perfect parry + the
  existing spark, so it *reads* as a hard deflect.
- Consolidate the roll/leap/slide under one `is_dodging` flag + a `dodge_variant`
  enum so gates (`_gameplay_blocked`, locomotion suppression) stay in one place.

---

## 3. Tripping

**Rule:** when a combatant is **sliding** (§2b) and its SlideBox overlaps an
opponent who is **grounded, not invulnerable/airborne, AND stands on two legs**,
that opponent **trips** — falls to their knees, `DOWNED` for **2.0s**, unable to
act and wide open.

### 3.0 Only bipeds can be tripped  **(hard rule — must-honor)**
You can only sweep the legs out from something that *has* two legs. Tripping
checks a **`trippable` (bipedal)** flag on the target and no-ops otherwise:
- **Trippable (bipedal):** the **player**, the **Mirror Warrior**, and any future
  humanoid. `trip()` on a non-bipedal target does nothing (no knockdown, no state).
- **NOT trippable:** **slime** (a blob — no legs), **bombug** (flying centipede),
  **mannequin** (mounted on a post), and — unless we decide otherwise — the
  **whisperer** and the **4-blade boss**. A slide still passes harmlessly under
  them; it just can't knock them down.
- Implementation: `EnemyBase.trippable: bool = false` (default — most creatures
  aren't bipedal); set `true` only on humanoids. The player is trippable. `trip()`
  early-returns unless the target reports `trippable == true`. This keeps the
  detail declarative and impossible to forget per-monster.

### Shared "downed" state
Both the player and monsters need it, so it's a small shared concept:
- **Player:** new `is_downed` + `downed_timer`; `_gameplay_blocked()` returns true
  while downed; knockdown animation `_make_knockdown()` (drop to knees, hands down);
  brief i-frames on *recovery* (~0.3s) so you're not instantly re-punished on stand-up.
  Taking damage while downed is allowed (that's the risk) — **[PROPOSAL: downed
  takes +25% damage]** to make it matter, or keep 1× to start.
- **`EnemyBase`:** add `trip(duration)` + a `DOWNED`-style freeze (like the existing
  stagger, but on-knees pose + longer). `_enemy_physics` early-outs while downed;
  subclasses get an `_on_tripped()` hook to interrupt their state machine (mirrors
  the existing `_on_staggered()` pattern).
- Guard against loops: a combatant that is itself sliding/i-framed/airborne/downed
  can't be tripped; short trip immunity (~0.5s) after standing up.

### Counterplay
- Slide *through* a windup to trip the attacker → free punish (the intended combo).
- A leaping/rolling target is airborne/i-framed → **immune**, so trips aren't
  guaranteed; spacing matters.
- Non-bipedal enemies (§3.0) are **immune by nature** — vs. slimes/bombugs the
  slide is purely a mobility/i-frame tool, so tripping shines specifically in
  humanoid duels (esp. the Mirror Warrior).
- Perfect-parry does not stop a slide (it's not an "attack"), but you can slide to
  beat a slide (both whiff / neither grounded).

---

## 4. Mirror Monster — "Mirror Warrior"  **[PROPOSAL: name]**

A duel partner that *is* the warrior: same kit, used against you.

- **Base:** `enemies/mirror_warrior.gd` extends `EnemyBase`. Code-built humanoid rig
  (same programmatic approach as the boss/mannequin) tinted like a dark reflection,
  wielding a sword drawn with the shared swing builder.
- **Kit (mirrors the player):**
  - **Attacks:** directional sword swings via `make_directional_swing` (shares the
    EnemyBase attack-hitbox → `player.take_damage`).
  - **Parry:** reads the player's `is_attacking`; on a well-timed guard it parries,
    which **staggers the player** (calls back into the player's stagger path) and
    opens *its* counter. Symmetric to the player's parry.
  - **Dodge:** rolls/leaps away from the player's attacks (reactive i-frames).
  - **Slide + Trip:** slides under the player to trip them, then punishes the
    knockdown — the showcase of §3 from the other side.
  - **Counters:** a simple "read" AI — if the player charges/winds up, it may
    parry or dodge; if the player is downed/recovering, it slides in or slams.
- **Reuse strategy [PROPOSAL]:** extract the trip/slide/parry *resolution* into
  small shared helpers (or a `Combatant` mixin) so the mirror and player share the
  rules, not copy them. Minimum viable: EnemyBase gains `trip()`/downed + a
  `SlideBox`, and the mirror composes attacks/parry from existing primitives.
- Substantial HP, scaled EXP; a proper mini-duel, not a trash mob.

> **Scope note:** a *full* mirror (every player ability incl. class weapons) is
> large. **[PROPOSAL]** v1 = warrior sword kit + parry + dodge + slide/trip +
> basic read-counters. Ranged/laser/prayer mirroring is a later pass.

---

## 5. Blood & Particles

Make flesh combatants bleed so hits feel real.

- **`Fx.blood_spray(pos, dir, amount)`** — red particle burst along the hit
  direction + a few arcing droplets; scales with damage. **[PROPOSAL]** optional
  short-lived ground splatter that fades (kept cheap/scene-safe under `Fx`).
- **Per-entity hit reaction:** add a `hit_fx` kind so we don't bleed slimes/bombugs.
  - `EnemyBase.hit_fx` **[PROPOSAL enum]**: `flesh` (blood), `goo` (slime splat),
    `mech`/`spark`, `none`. `take_damage` routes to the matching `Fx` call. Default
    keeps current behavior; mirror/whisperer = `flesh`, slime = `goo`, bombug keeps
    its spark/embers.
  - **Player** bleeds on `take_damage` (flesh) — the "player-like monsters" and the
    player share the flesh reaction.
- Tune for readability, not gore: brief, punchy, fades fast. A global intensity
  constant so it's easy to dial down.

---

## 6. Architecture fit

- **No new god-class branches.** Dodge variants live behind one `dodge_variant`
  switch in the dodge entry point + per-variant `_physics` handling and per-variant
  anims — contained to the movement section, mirroring how attacks quantize aim.
- **Tripping is a shared verb**, not player-only: `trip()` on both the player and
  `EnemyBase`, plus a `SlideBox` helper. This is the same pattern as `apply_stagger`
  (already symmetric).
- **Mirror reuses primitives** (swing builder, Fx, EnemyBase hitbox, trip/parry
  rules) rather than duplicating the player script.
- **Blood via a routed `hit_fx`** keeps entity-specific reactions declarative.

New/changed files (indicative):
```
playercontroller.gd     directional dodge (leap/slide), is_downed, trip(), slide box
player_animator.gd      _make_evade_leap / _make_slide / _make_knockdown
enemies/enemy_base.gd    trip()/downed + _on_tripped hook, hit_fx routing, SlideBox helper
enemies/mirror_warrior.gd/.tscn   the duel partner
autoload/fx.gd          blood_spray, motion_streak, trip_dust
tests/test_dodge_trip.gd, tests/test_mirror.gd
```

---

## 7. Build order (each step ships green, headless-testable)

1. **Directional dodge** — aim-driven variant select; Evade Leap + Slide (+ anims,
   motion streak). Roll unchanged. *No trip yet.* `test_dodge_trip.gd` (variant
   selection, leap height, slide i-frames).
2. **Tripping** — shared `is_downed`/`trip()` on player + `EnemyBase`; SlideBox
   wires slide→trip; knockdown anim; 2s duration + recovery i-frames. Extend the
   test (slide trips a dummy; dummy stands after 2s; airborne target immune).
3. **Parry/dodge refinements** — hitstop, perfect-dodge, dodge-cancel, flag cleanup.
4. **Blood/particle pass** — `Fx.blood_spray` + `hit_fx` routing; player + flesh
   monsters bleed.
5. **Mirror Warrior** — the duel partner using all of the above. `test_mirror.gd`
   (attacks/parries/dodges/slides+trips the player; is killable; scaled EXP).

I'll **build in the order you specify** — this is just the dependency-sane default.

---

## 7.5 LOCKED DECISIONS (2026 — build to these)

- **Variant selects from MOVEMENT input**, not aim: read `joystick_vector` at
  dodge press. `y < -0.4` → **leap**, `y > 0.4` → **slide**, else → **roll**.
- **Slide goes in the FACING direction** (not the move vector).
- **Downed takes BONUS damage** (`DOWNED_DMG_MULT`, no hurt-i-frames while down —
  the knockdown is a real punish window).
- **Bipedal only** (§3.0): trippable = player + Mirror Warrior; everything else
  immune, including whisperer + boss.
- **Slide knockdown is a chance roll**, not guaranteed (balance patch `57ba82d`,
  odds tuned later): a slide always passes through with i-frames (evade), but the
  knockdown only lands on a roll — **player `SLIDE_TRIP_CHANCE` = 0.6**, **Mirror
  = 0.3** — per opponent-per-slide. A **successful** knockdown costs **+50
  stamina** on both sides (the Mirror has its own stamina pool + regen and won't
  attempt a slide-trip it can't afford). `trip()` returns bool so the slider only
  pays on a real knockdown.
- **Mirror = SWORD only**, but must **trip the player, parry, and attack like the
  player**. Other classes/weapons mirrored later.
- **Blood = punchy & gory**, and **only the Mirror bleeds for now** (routed via
  `hit_fx` so anything else — incl. the player — opts in with one flag later).

## 8. Open questions (steer me)

1. **Dodge variant mapping** — up=leap / down=slide / side=roll as above? Or map
   by movement input instead of aim? (Aim is my default since attacks already use it.)
2. **Downed severity** — does a downed target take extra damage (punish combo) or 1×?
3. **Trip fairness** — should trips cost the slider anything, or be free on connect?
   Any cap so a mirror can't perma-trip-loop you (I've proposed stand-up immunity)?
3b. **Bipedal roster** — confirmed trippable: player + Mirror Warrior; confirmed
   immune: slime, bombug, mannequin. **Your call on the whisperer and the 4-blade
   boss** — do they count as "standing on two legs"? (Default: both immune.)
4. **Mirror v1 scope** — warrior sword kit only (my proposal), or must it mirror
   whatever class/weapon *you* currently hold?
5. **Blood intensity / tone** — punchy-but-tasteful (default), or dial way down?
6. **Mirror name** — "Mirror Warrior"? "Warden"? "Doppelganger"?
