# ARCHITECTURE — Wonders Of Creation

> **Context report for agentic development.** Current as of the combat overhaul +
> UI upgrade (2026-07-03). This SUPERSEDES `CODEBASE_CONTEXT.md` (which describes
> the pre-overhaul codebase and is kept only as historical reference alongside
> `MASTER_PROMPT.md` / `KICKOFF_PROMPT.md`).
> Read this fully before modifying code; the **Invariants & Gotchas** section at
> the bottom prevents real crashes and lost work.

---

## 1. Snapshot

| Attribute | Detail |
|---|---|
| Name | **Wonders Of Creation** (`project.godot` `config/name`) |
| Engine | **Godot 4.3** (stay on 4.3 APIs — no 4.4+ features), Mobile renderer |
| Language | GDScript only, typed where practical |
| Viewport | 1440×640, `stretch/mode="viewport"`, `emulate_touch_from_mouse=true` |
| Main scene | `res://titlescreen.tscn` |
| Autoloads | `Global` (`res://global.gd`), `Fx` (`res://autoload/fx.gd`), `ItemDB` (`res://autoload/item_db.gd`) |
| Genre | 2D side-scrolling action RPG (Soul-Knight-ish combat feel) |
| Targets | Android touch-first; full keyboard/mouse PC support |
| Test harness | `tests/test_phase1..8.gd`, `tests/test_ui.gd` — headless SceneTree scripts |

Run tests: `Godot_v4.3-stable_win64_console.exe --headless --path . -s res://tests/test_phaseN.gd`
(binary lives at `C:\Users\S-Z Computers\Downloads\Web\Godot_v4.3-stable_win64.exe\`).
Every suite prints `PASS:`/`FAIL:` lines and a final `RESULT:` and exits nonzero on failure.

---

## 2. Scene Flow

```
titlescreen.tscn ──START GAME──► class_selection.tscn ──► DemoMap.tscn
      │                              (sets Global.current_class)
      ├─CUSTOMIZE HERO──► character_customization.tscn ──back──► titlescreen
      └─BOSS ARENA (button or B key)──► boss_arena.tscn
                                          (1-4 = class switch, B = spawn boss)
```

- `DemoMap.tscn` — normal gameplay level: player, slime, `dieo` death-screen instance.
- `boss_arena.tscn` — flat walled test arena: player, mannequin, death screen,
  `boss_arena.gd` handles debug keys + boss spawning.
- `Global.respawn()` is the **single respawn path** (pause RETRY + death RETRY).

---

## 3. File Map (current)

### Core player
| File | Role |
|---|---|
| `playercontroller.gd` | Player brain on `player.tscn` root (CharacterBody2D). Movement, jump/double-jump/wall-jump, dodge roll, parry, attack dispatch (melee/ranged/laser/heal), `take_damage`/death, grab/thrown state, stats/EXP/saturation/mana regen, class application, customization application, UI wiring. |
| `input_controller.gd` | `class_name PlayerInput`. **Unified input layer** — the ONLY input source the player consumes. See §4. |
| `player_animator.gd` | Code-driven puppet animator on `PlayerSkin` (Node2D, scale 2×). Builds all locomotion + hurt/death/roll/parry animations in code; hosts weapon-animator plugins; 8-dir attack orchestration. See §5. |
| `player.tscn` | Player prefab: body shape, `Hurtbox` (Area2D), `GroundRay`, `PlayerInput` node, `PlayerSkin` puppet (+`AttackHitbox`), Camera, TouchControls, HUDLayer. |

### Weapons
| File | Role |
|---|---|
| `weapon_data.gd` | `class_name WeaponData` (Resource). `id` (catalog key), stats, `combo_anims`, `animator_script` (visuals), `behavior_script` (charged-attack plugin) + `get_behavior()`; `charged_style`/`attack_style` kept as fallback selectors. |
| `autoload/item_db.gd` | `ItemDB` autoload — scans `res://weapons/`, maps `id`→resource. `get_item/has_item/all_of_kind/all_ids`. All item discovery routes here (see WEAPON_ITEM_ARCHITECTURE.md). |
| `weapons/behaviors/*.gd` | `WeaponBehavior` (base = melee) + `laser_behavior`, `heal_behavior`. Own charged-attack dispatch (`on_release`, `wants_charge_stance`); the player forwards charge events here instead of branching on a style enum. |
| `weapons/animators/weapon_animator.gd` | `class_name WeaponAnimator` (RefCounted) — plugin base. Contract: `setup_visual`, `get_attack_animations`, `get_hold_positions`, `teardown_visual`. **Also hosts `static make_directional_swing(pivots, angle, opts)`** — THE shared angle-parameterized swing builder used by player, mannequin, and boss (see §6). Static track helpers `anim_pos/rot/zidx/method`. |
| `weapons/animators/fists_animator.gd` | Default/unequip fallback. `attack_right/left`, `uppercut`. |
| `weapons/animators/sword_animator.gd` | Warrior. 3-hit combo + charged thrust (`_trigger_thrust_dash`). |
| `weapons/animators/staff_animator.gd` | Base staff: `staff_attack_right/left` melee. |
| `weapons/animators/mage_staff_animator.gd` | extends StaffAnimator; adds `staff_charged` cast anim + `staff_aim` rifle stance (looping charge pose); tints the staff cool white-blue. Used by the beam staff. |
| `weapons/animators/projectile_weapon_animator.gd` | Ranger bow. `bow_shot`/`bow_shot_charged` with `_fire_projectile` method track; **code-generates its bow texture** when WeaponData has no icon. |
| `weapons/animators/wand_animator.gd` | Healer. `wand_flick_r/l` pokes + `wand_heal` channel pose; code-generated wand texture. |
| `weapons/projectile.gd` | `class_name PlayerProjectile` (Area2D). Static `spawn(from, dir, dmg, spd)`; parents itself **under Fx** (scene-safe); `reflect()` for parries; sticks in walls. |
| `weapons/*.tres` | `weapon_fists`, `starter_sword` (Warrior), `starter_staff` (Mage default — plain `charged_style="melee"`), `mage_beam_staff` "Arcane Conduit" (the laser, `charged_style="laser"`, added to the mage's inventory to equip), `ranger_bow`, `healer_wand`. |

### Enemies
| File | Role |
|---|---|
| `enemies/enemy_base.gd` | `class_name EnemyBase` (CharacterBody2D). THE enemy contract — see §7. |
| `slime.gd/.tscn` | Hopper. PATROL/AGGRO/**WINDUP→LUNGE→RECOVER** telegraphed bite; HP/EXP/damage scale with random size. |
| `whisperer.gd/.tscn` | Fast rusher. PATROL/AGGRO/WINDUP/ATTACK/RECOVER swipe with slash VFX. |
| `enemies/mannequin.gd/.tscn` | Training dummy: unkillable+regen, DPS/last-hit readout, `attacks` toggle = telegraphed practice swing (uses shared swing builder). |
| `enemies/boss_fourblade.gd/.tscn` | FOURBLADE miniboss — see §8. |

### UI / meta
| File | Role |
|---|---|
| `global.gd` | Autoload. `class_data` (4 classes), `current_class`, `class_starter_weapon` map + `get_starter_weapon_path()`, `player_custom` dict + `HAIR_COLORS/SKIN_TONES/OUTFIT_COLORS` palettes, `respawn()`. |
| `autoload/fx.gd` | Autoload `Fx` (Node2D). Scene-safe VFX manager — see §9. |
| `titlescreen.gd/.tscn` | Programmatic title: starfield + scanlines (inner classes `StarfieldControl`/`ScanlineControl`), bobbing hard-shadow logo, START/CUSTOMIZE/ARENA buttons. B = arena hotkey. |
| `character_customization.gd/.tscn` | Early customization tool: layered-sprite live preview, name field, hair/skin/outfit tint swatch rows → `Global.player_custom`. |
| `class_selection.gd/.tscn` | Class picker (radar chart via `stat_chart.gd`) → DemoMap. |
| `player_hud.gd` | Custom `_draw()` HUD: pixel frame panels, hearts, STA/MP bars with segment ticks, saturation food icons, EXP ring + level + **hero name plate**, INV + profile buttons (signals). |
| `player_inventory_ui.gd/.tscn`, `inventory_slot.gd` | 52-slot drag-drop inventory; emits `weapon_equipped(WeaponData)` (NOTE: `weapon_unequipped` on swap still missing — deferred). |
| `player_profile_ui.gd/.tscn` | Stat allocation; equipment/skills sections still placeholder (deferred). |
| `pausemenu.gd` | Pause overlay inside TouchControls; RETRY → `Global.respawn()`. |
| `dieo.gd/.tscn` | Death screen ("YOU DIED", Retry/Title) as hidden CanvasLayer; group `"death_screen"`; player auto-instantiates it if a scene lacks one. |
| `boss_arena.gd/.tscn` | Arena + debug controls + boss spawner. |
| `joystick.gd`, `attack_button_ring.gd`, `touchcontrols.tscn`, `touch_button_style.gd` | Touch input widgets. Ring is **press/release only** — charge logic lives in PlayerInput. |

---

## 4. Input System (PlayerInput — `input_controller.gd`)

One canonical stream; playercontroller NEVER reads raw input.

```
joystick / attack ring (touch)──┐
keyboard / mouse (InputMap) ────┴─► PlayerInput ─► signals ─► playercontroller
```

- **Signals:** `move_changed(Vector2)`, `jump_pressed`, `dodge_pressed`,
  `parry_pressed`, `interact_pressed`, `attack_pressed`,
  `attack_released(charge_level: float, hold_time: float)`,
  `inventory_toggle_pressed`, `profile_toggle_pressed`.
- **Modes:** `TOUCH` (default) ↔ `KBM`. A physical key press → KBM (touch buttons
  hide); a REAL screen touch (`event.device != InputEvent.DEVICE_ID_EMULATION`)
  → TOUCH. In TOUCH mode mouse buttons stay emulated-touch (prevents ring
  double-fire); `_mouse_gated()` enforces this.
- **Continuous charge:** PlayerInput owns `charge_level` 0..1, driven by
  `charge_time` (set from the equipped weapon on every equip). The ring is a
  dumb display (`set_charge(level)`). The hold is INDEFINITE —
  `charge_hold_time` keeps counting past full; release emits
  `attack_released(level, hold_time)`. `cancel_charge()` kills a hold without
  firing (mana circle break) — the held button stays dead until re-pressed.
- **Aim:** `get_aim_vector()` → mouse direction (KBM) or joystick direction
  (TOUCH); ZERO means "no aim, use facing".
- Esc toggles the pause menu directly (PlayerInput is `PROCESS_MODE_ALWAYS`);
  gameplay events are suppressed while paused.
- InputMap actions (project.godot): `move_left/right/up/down`, `jump`, `attack`
  (J/LMB), `dodge` (Shift/L), `parry` (K/RMB), `interact` (E), `open_inventory`
  (I/Tab), `open_profile` (P), `pause` (Esc), `dbg_class_1..4` (1-4),
  `dbg_spawn_boss` (B).

**Attack dispatch on release** (`playercontroller._on_attack_released`):
```
charged_style == "laser" and level >= 0.15  → _fire_laser(level, hold_time)
level >= 1.0                                → _on_attack_charged()
   charged_style == "heal" → _perform_heal()
   else                    → charged melee/ranged (play_uppercut → charged_anim)
else                                        → _on_attack_button_pressed() (normal)
```

**Laser hold mechanics** (`playercontroller`): while charging a laser weapon
the player locks into the `staff_aim` rifle stance (`_laser_stance_active()`
gates locomotion + turns with the aim). At full charge a `ChargeCircle`
(inner class — rotating rune ring, CONCENTRIC with the charge orb so they
read as one cast) brightens and gains stack pips (1 per `STACK_INTERVAL`=2s,
visual cap 5, +8% damage each). Colors: dynamic cyan→white gradient by charge,
pure **white** in overdrive. Past `OVERDRIVE_HOLD_TIME`=10s the hold drains
`OVERDRIVE_MANA_DRAIN`=8 mana/s and charge is **uncapped**: width freezes
(`OVERDRIVE_WIDTH_MULT` once) while each extra second adds
`OVERDRIVE_RANGE_PER_SEC`=240px range (wide) and `OVERDRIVE_DAMAGE_PER_SEC`=4
damage (light), unbounded. Overdrive fires a white helix beam
(`Fx.beam(..., helix, intensity)` — gradient core + counter-phased strands +
dense white motes). If mana hits 0 mid-hold → `_break_charge_circle()`:
`Fx.circle_break`, fizzle cooldown, charge cancelled, **no beam** (no
auto-fire by design — the mana pool is the only limiter).

---

## 5. Puppet Animation System (`player_animator.gd`)

- Pivot rig (children of PlayerSkin): `TorsoPivot`, `HeadPivot` (+Face/Hair),
  `LeftArmPivot` (+`WeaponSprite`), `RightArmPivot`, `LeftLegPivot`,
  `RightLegPivot`, `AttackHitbox` (Area2D + `HitShape`).
- Facing = flipping `PlayerSkin.scale.x` sign. Weapon/enemy code must account
  for the mirror (`sign(scale.x)`).
- **Library animations** (built in `_build_all_animations`, rebuilt on equip via
  `_rebuild_locomotion_animations`): `idle walk run jump fall long_fall hurt
  death roll parry` + weapon-provided attack anims + cached `dirswing_*`.
- **Playback API** (called by playercontroller):
  - `play_state(name)` — dedup'd locomotion.
  - `play_attack(aim: Vector2)` — quantizes world aim into octants
    (`0=fwd, ±1 diag, ±2 up/down`; backward folds into forward because the
    controller flips facing to aim first). Horizontal → the weapon's authored
    combo anims; other octants → `WeaponAnimator.make_directional_swing`
    built+cached as `dirswing_<oct>_<step>`. Rotates `AttackHitbox` to the
    local aim angle; restored in `_on_attack_done`.
  - `play_uppercut()` — plays `equipped_weapon.charged_anim` (also used as the
    laser cast + heal channel body language).
  - `play_hurt() / play_death() / play_roll() / play_parry()` — one-shots that
    force-restart.
  - `equip_weapon_visual(WeaponData)` / `unequip_weapon_visual()`.
- **Method-track callbacks** (fired BY animations, path "." = PlayerSkin):
  `_enable_hitbox`, `_disable_hitbox`, `_spawn_swing_arc`,
  `_spawn_sword_slash_effect(downward)`, `_spawn_directional_slash`,
  `_trigger_thrust_dash`, `_fire_projectile(charged)`.
- `long_fall`, `death`, and `roll` animate **`.:rotation` (the whole skin)** —
  playercontroller resets `player_skin.rotation = 0` on landing / roll end.

---

## 6. Shared Directional Swing Builder (THE reuse point)

`WeaponAnimator.make_directional_swing(pivots: Dictionary, angle: float, opts: Dictionary) -> Animation`
(static, `weapons/animators/weapon_animator.gd`)

- One builder → all 8 attack directions for **players AND monsters**.
- `angle` is in the RIG's local space (0 = forward +x; caller converts world→local:
  `atan2(aim.y, aim.x * facing_sign)`); mirrored rigs flip via `scale.x`.
- `opts` makes it rig-agnostic: `arm_nodes`, `arm_bases`, `arm_base_rots`,
  `weapon_node` ("" to skip), `length`, `reach`, `windup`, `follow`,
  `hit_start/hit_end/slash_time`, `enable_method/disable_method/slash_method`,
  `method_target`, `body_nodes`.
- Consumers today: `player_animator.play_attack` (player arms),
  `mannequin._build_swing_animation` (`Visual/ArmPivot`, callbacks
  `_swing_hit_on/_swing_hit_off/_swing_slash`), `boss_fourblade._build_animations`
  (one anim per boss arm, same callback names).

---

## 7. Enemy Framework (`EnemyBase`)

Contract (extend it; don't reimplement):

- **Override hooks:** `_enemy_ready()` (setup), `_enemy_physics(delta)` (AI —
  the base's `_physics_process` handles dead/staggered first), `_on_staggered()`
  (interrupt your attack state).
- **Provided:** `take_damage(amount, knockback)` (flash + `Fx.damage_number` +
  knockback + `_die`), `_die()` (scaled `exp_value` to player, fade, free,
  `died` signal), `apply_stagger(duration, push)` (parry hook — freezes AI,
  disables hitbox), `flash_hit(color)`, `setup_attack_hitbox(size, offset)` +
  `enable_attack_hitbox(dir)` / `disable_attack_hitbox()` (one damage attempt
  per swing; routes through `player.take_damage(dmg, source_pos, kb, self)` so
  the PLAYER resolves parry/i-frames), `_distance_to_player()`,
  `_has_line_of_sight()` (Environment-masked ray, excludes self + player body),
  `_can_see_player()` (range + LOS).
- Base `_ready` standardizes: group `"enemy"`, `collision_layer = 4`
  (EnemyHurtbox), `collision_mask = 1`, gravity cached, `hp = max_hp`,
  `_flash_sprite` from `flash_sprite_path` (default `Sprite2D`; set `_flash_sprite`
  manually for code-built rigs).
- Exports: `max_hp`, `attack_damage`, `exp_value`, `aggro_range`.

## 8. FOURBLADE boss (`enemies/boss_fourblade.gd`)

- State machine: `IDLE APPROACH SLASH DASH_WIND DASH GRAB_WIND GRAB_HOLD SUMMON RECOVER`
  (+ base stagger). `_decide()` picks by distance/rolls; `phase2` at ≤50% HP
  (more swords, 1.8× accrual, more dashes; checked in `take_damage` override).
- **Sword power**: `_swords` array of dicts `{pivot, sword_pivot, blade, glow,
  power, active, base_pos, base_rot}`. Active swords gain
  `randf_range(accrual_min, accrual_max) * dt` up to `power_cap`; glow
  color/alpha/scale = telegraph. `_spend_sword(idx)` → damage, resets power.
- Summon/dismiss: `_set_active_swords(indices)` fades pivots; attacks only use
  active swords.
- Grab: `_attempt_grab()` reach-checks; beaten by `invuln_timer > 0` /
  `is_rolling` (whiff = punish window) or `is_parrying` (boss staggers);
  success → `player.begin_grabbed(self)` → held at hand
  (`update_grabbed(pos)` per frame) → `_throw_player()` →
  `player.launch_thrown(vel, GRAB_IMPACT, GRAB_LANDING)`.
- Player side (playercontroller): `is_grabbed`/`_grabber` (physics early-out),
  `launch_thrown` applies impact damage + locks control (`is_hurt` 0.6s) +
  sets `_thrown`; landing while `_thrown` applies `_throw_landing_damage`.

## 9. Fx autoload (`autoload/fx.gd`) — ALL transient visuals go here

Never parent VFX/projectiles to the current scene — parent to `Fx` (survives
scene changes; children pruned when `current_scene` changes; every tween
callback guarded with `is_instance_valid`).

API: `hit_particles(pos, color?)`, `damage_number(pos, amount, color?)`
(`PLAYER_DAMAGE_COLOR` for player hits), `swing_arc(origin, dir)`,
`slash_effect(origin, dir, downward, angle=0, arc_scale=1)` (angle rotates the
slash plane — world radians; mirrored rigs pass `local_angle * facing`),
`beam(start, end, width, core?, glow?)` (laser core+glow+muzzle+impact sparks),
`heal_burst(pos)`, `parry_spark(pos)`.

---

## 10. Collision Layers (VALUES, not bit indices)

| Value | Bit | Name | Used by |
|---|---|---|---|
| 1 | 1 | Environment | Terrain StaticBody2D; player & enemy body masks; beam/LOS ray mask |
| 2 | 2 | PlayerHitbox | `PlayerSkin/AttackHitbox` (mask 4) |
| 4 | 3 | EnemyHurtbox | Every EnemyBase body (player hitbox + laser + arrows mask this) |
| 8 | 4 | PlayerHurtbox | `Player/Hurtbox` Area2D (mask 0, monitorable) |
| 16 | 5 | EnemyHitbox | EnemyBase attack areas (mask 8) |
| 32 | 6 | Projectile | `PlayerProjectile` (mask 4\|1) |

**NOTE:** the player BODY sits on layer 1 (Environment) — LOS rays and beams
must exclude it explicitly (`EnemyBase._has_line_of_sight` does).

## 11. Damage Routing

**Player → enemy:** anim method track `_enable_hitbox` → `AttackHitbox.body_entered`
→ `playercontroller._on_attack_hit(body)` → group `"enemy"` + dedup
(`hit_enemies_this_swing`) → `body.take_damage(dmg, kb)`. Laser: hitscan rays
(wall-stopped, enemy-piercing) → `take_damage` directly. Arrows: Area2D overlap.

**Enemy → player:** `EnemyBase` hitbox `area_entered` (player `Hurtbox`) →
`player.take_damage(amount, source_pos, knockback, attacker)`, which resolves
IN ORDER: dead → no; **parry** (`_try_parry`: window + frontal → negate,
spark, counter window, `attacker.reflect()` for projectiles else
`attacker.apply_stagger()`) → **i-frames** (`invuln_timer`: hurt recovery /
dodge roll) → mitigation `max(amount - (defense + stat_def), 1)` → hitstun +
knockback + `HURT_IFRAMES` → `die()` at 0.

## 12. Player state flags (mutually interacting — check before adding states)

`is_attacking, is_rolling, is_parrying (+parry_recovery_timer), is_hurt,
is_dead, is_grabbed, _thrown, invuln_timer, attack_cooldown_timer,
roll_cooldown, parry_cooldown_timer`.
`_gameplay_blocked()` = dead/hurt/menus → gates all combat input.
Locomotion anim state machine only runs when NOT
attacking/hurt/parrying/rolling/dead/grabbed.

## 13. Character customization

- `Global.player_custom` = `{name, hair_color, skin_tone, outfit_color}`;
  palettes in `Global.HAIR_COLORS/SKIN_TONES/OUTFIT_COLORS` (index 0 = untinted).
- Applied by `playercontroller._apply_customization()` on spawn: modulates
  hair sprite (hair), head+hand sprites (skin), torso+leg sprites (outfit);
  **face sprite stays untinted**. HUD reads `player.player_name` (deferred fetch).
- To extend: add palette entries (one line), or new keys in `player_custom` +
  a swatch row in `character_customization.gd` + application in
  `_apply_customization`.

---

## 14. INVARIANTS & GOTCHAS (violating these has bitten us already)

1. **NEVER mutate an AnimationLibrary while its AnimationPlayer is playing.**
   Random engine segfault (~50%) from stale track caches. Always
   `anim_player.stop()` first (guards exist in `equip_weapon_visual`,
   `unequip_weapon_visual`, `_rebuild_locomotion_animations` — keep them).
2. **Scene-safe spawning only.** Transient nodes → `Fx`; never
   `get_tree().current_scene.add_child` for VFX/projectiles; guard every
   deferred/tween callback with `is_instance_valid`.
3. **Editor clobber hazard.** The developer's open Godot editor has re-saved
   stale buffers over committed files TWICE. Before every commit run
   `git status --short` and confirm only intended files changed; canary:
   `Select-String project.godot -Pattern "Fx="` must hit. If the editor is
   open, ask for Project → Reload Current Project after external edits.
4. **Headless `-s` test scripts can't reference autoloads by identifier** at
   compile time (`Global.x` fails) — use `root.get_node("/root/Global")`.
   Global CLASSES (`EnemyBase`, `WeaponData`) may also race the cache; prefer
   duck-typing (`has_method`) in tests. Isolate combat tests from live enemy
   AI (`for e in get_nodes_in_group("enemy"): e.queue_free()`).
5. **Touch/PC parity**: never fork combat logic per input method — everything
   goes through PlayerInput. Mouse buttons are gated to KBM mode.
6. **Facing mirror**: PlayerSkin/boss Visual flip via `scale.x`; convert
   world↔local angles with the facing sign (see `play_attack`,
   `_spawn_directional_slash`).
7. **Programmatic UI + code-driven animation are conventions**, not accidents:
   no .tscn UI layouts, no sprite sheets for the puppet, weapon textures may be
   code-generated (`Image` → `ImageTexture`).
8. **Method tracks** target the ANIMATION ROOT (AnimPlayer's parent): PlayerSkin
   for the player, the body root for mannequin/boss. New rigs need the callback
   methods (`_enable_hitbox`-style) defined there.
9. `pausemenu`/touch buttons are wired BOTH in .tscn connections and code —
   keep the `is_connected` guards when touching `_ready` wiring.
10. Windows/PowerShell 5.1: no `&&`, no embedded `"` in `git commit -m`
    here-string args (it splits the arg), `Remove-Item -Confirm:$false`.

## 15. Deferred work (agreed "later patches" list)

PlayerController component split (Movement/Combat/Stats/UIManager child nodes,
public API stable) · save/load system (versioned) · strict-typing pass ·
`preload()` conversions · inventory fixes (`weapon_unequipped` on swap, armor
slot drag-drop validation, texture icons instead of emoji, Dictionary for
`hit_enemies_this_swing`) · profile UI real equipment/skills/preview · HUD
de-magic-numbering + update-on-change only · titlescreen TouchScreenButton
alignment · whisperer/slime sprite-flip polish.
