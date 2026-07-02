# CODEBASE CONTEXT — UNTITLED RPG

> Reference document for any model/engineer executing work on this project.
> Read this **fully** before touching code. It captures the actual architecture,
> conventions, and known issues so your changes match the existing style and
> don't regress working systems. Companion doc: `MASTER_PROMPT.md` (the task).

---

## 1. Snapshot

| Attribute | Detail |
|---|---|
| Engine | **Godot 4.3** (`config_version=5`), **Mobile** renderer |
| Language | GDScript only |
| Viewport | 1440×640, `stretch/mode="viewport"` |
| Main scene | `res://titlescreen.tscn` |
| Genre | 2D **side-scrolling** action RPG (Soul-Knight-style combat feel) |
| Target platform | Android (touch-first); **currently tested on PC** |
| Autoload | `Global` (`res://global.gd`) — class-data dictionary |
| Size | ~4,300 lines across 23 `.gd` files |
| Existing weapons | Fists, Starter Sword, Starter Staff (+ 4 animator classes) |

**Godot version constraint: stay on 4.3 APIs.** Do not use 4.4+ only features.

---

## 2. File Map

| File | Role |
|---|---|
| `global.gd` | Autoload. `class_data` dict (Warrior/Ranger/Mage/Healer → hp/def/sta/mana/description). `current_class`, `get_current_class_stats()`, `set_class()`. |
| `titlescreen.gd/.tscn` | Entry scene. Programmatic UI, intro animation. → class_selection. |
| `class_selection.gd/.tscn` | Class picker. Sets `Global.current_class`. Uses `stat_chart.gd`. → DemoMap. |
| `DemoMap.tscn` | Gameplay level. Hosts player, slime, whisperer, dieo. |
| `playercontroller.gd` | **God class (615 lines).** Player movement, combat, stats, EXP, saturation, UI wiring, weapon equipping. Attached to `player.tscn` root (CharacterBody2D). |
| `player.tscn` | Player prefab: body + PlayerSkin puppet + TouchControls + HUDLayer + Camera. |
| `player_animator.gd` | **Puppet animator (813 lines).** Code-builds locomotion animations; hosts weapon-animator plugins. Attached to `PlayerSkin` (Node2D). |
| `player_hud.gd` | Custom `_draw()` HUD (hearts, bars, EXP ring, food icons). |
| `player_inventory_ui.gd/.tscn` | 52-slot drag-drop inventory + equipment slots + weapon preview card. |
| `player_profile_ui.gd/.tscn` | Character profile, stat allocation. **Equipment/skills sections are placeholders.** |
| `inventory_slot.gd` | Single slot with drag-and-drop + swap. |
| `stat_chart.gd` | Radar chart drawing. |
| `joystick.gd` | Virtual joystick. Emits `joystick_moved(Vector2)`. Has `get_attack_direction()` (8-dir). |
| `attack_button_ring.gd` | Ring attack button. Emits `attack_tapped` / `attack_charged` (binary charge). |
| `touch_button_style.gd` | Static `apply(button, kind, font)` styling helper. |
| `touchcontrols.tscn` | Joystick + attack/jump/evade/pause buttons overlay. |
| `pausemenu.gd` | Pause overlay (RETRY reloads scene). |
| `playbutton.gd` | **Dead code** (empty template). |
| `weapon_data.gd` | `WeaponData` Resource. Stats + `animator_script` ref. |
| `weapons/animators/weapon_animator.gd` | `WeaponAnimator` base (RefCounted). Plugin contract + static track helpers. |
| `weapons/animators/{fists,sword,staff}_animator.gd` | Per-weapon animation providers. |
| `weapons/*.tres` | `weapon_fists`, `starter_sword`, `starter_staff` WeaponData resources. |
| `slime.gd/.tscn` | Enemy with PATROL/AGGRO/ATTACK state machine. **Deals no damage to player.** |
| `whisperer.gd/.tscn` | **Incomplete enemy stub** (no HP/damage/death/collision). |
| `dieo.gd/.tscn` | **Empty placeholder** (intended death screen, unimplemented). |
| `player_profile_ui`, etc. | See above. |

---

## 3. Scene Flow

```
titlescreen.tscn
  → class_selection.tscn          (sets Global.current_class)
     → DemoMap.tscn
        ├─ player.tscn (CharacterBody2D, group "player")
        │    ├─ CollisionShape2D            (body vs terrain)
        │    ├─ GroundRay (RayCast2D)       (long-fall distance check)
        │    ├─ PlayerSkin (Node2D, player_animator.gd, scale 2×)
        │    │    ├─ AnimPlayer (AnimationPlayer)
        │    │    ├─ LeftLegPivot/Sprite, RightLegPivot/Sprite
        │    │    ├─ TorsoPivot/Sprite
        │    │    ├─ RightArmPivot/Sprite, LeftArmPivot/Sprite
        │    │    │    └─ WeaponSprite (Sprite2D, hidden until equip)
        │    │    ├─ HeadPivot/Sprite + FacePivot/Sprite + HairPivot/Sprite
        │    │    └─ AttackHitbox (Area2D, layer 2 / mask 4) → HitShape (disabled by default)
        │    ├─ Camera (Camera2D, %Camera, zoom 2×)
        │    ├─ TouchControls (instance) → JOYSTICK, AttackButton(+RingUI), JumpButton, EvadeButton, PauseButton, PAUSEMENU
        │    ├─ AttackDirection (Label)
        │    └─ HUDLayer (CanvasLayer, layer 10) → PlayerHUD, InventoryUI (+ ProfileUI added at runtime)
        ├─ slime.tscn (CharacterBody2D, group "enemy")
        ├─ whisperer.tscn (WIP)
        └─ dieo.tscn (empty)
```

---

## 4. Core Architecture Patterns (FOLLOW THESE)

1. **Programmatic UI.** No `.tscn`-based UI layouts. All HUD/menus built in `_ready()`
   with `StyleBoxFlat`, containers, and custom `_draw()`. New UI must follow suit.
2. **Code-driven puppet animation.** No external animation editor / no sprite sheets
   for the player. Animations are `Animation` objects with value tracks built in code.
   See §5.
3. **Data-driven weapon system with pluggable animators.** `WeaponData` (`.tres`) holds
   stats; `WeaponAnimator` (GDScript) supplies hold pose + attack animations. See §6.
4. **Signal-based communication.** Player ↔ HUD/Inventory/Joystick/AttackButtonRing via
   signals. Keep loose coupling. Prefer signals over direct cross-node reaching.
5. **Groups for discovery.** Player is in group `"player"`; enemies in group `"enemy"`.
   Enemies find the player via `get_tree().get_first_node_in_group("player")`.

**Style conventions observed:** typed vars where present, `snake_case`, section
banner comments (`# ─── Title ───`), `@onready`/`@export_group`, `_on_*` signal
handlers, `push_warning` for soft errors. Match this.

---

## 5. Puppet Animation System (player_animator.gd)

Attached to `PlayerSkin`. Builds an `AnimationLibrary` ("") in `_ready()` via
`_build_all_animations()`.

- **Pivot nodes** animated by name (relative to PlayerSkin):
  `TorsoPivot`, `HeadPivot`, `LeftArmPivot`, `RightArmPivot`, `LeftLegPivot`,
  `RightLegPivot`, and sprite children (`.../Sprite`), plus `LeftArmPivot/WeaponSprite`.
- **Base pose exports:** `base_torso`, `base_head`, `base_larm`, `base_rarm`,
  `base_lleg`, `base_rleg` (Vector2), and `base_larm_rot`/`base_rarm_rot` (float,
  set by weapon hold pose).
- **Track helpers** (instance): `_pos(anim, node, keys)`, `_rot(anim, node, keys)`,
  `_zidx(anim, node, keys)`. Keys are `[[time, value], ...]`. Position/rotation use
  CUBIC interpolation; z_index uses NEAREST.
- **Locomotion builders:** `_make_idle/walk/run/jump/fall/long_fall()`. Rebuilt on
  weapon equip/unequip via `_rebuild_locomotion_animations()` so the hold pose bakes in.
- **Playback API (called by playercontroller):**
  - `play_state(name)` — locomotion states (idle/walk/run/jump/fall/long_fall).
  - `play_attack()` — combo-aware normal attack (uses `equipped_weapon.combo_anims`
    or falls back to `attack_right`/`attack_left`). Emits `attack_finished` on done.
  - `play_uppercut()` — charged attack; plays `equipped_weapon.charged_anim`.
  - `equip_weapon_visual(weapon)` / `unequip_weapon_visual()`.
- **Combat callbacks invoked from animation method tracks:** `_enable_hitbox()`,
  `_disable_hitbox()` (toggle `AttackHitbox/HitShape.disabled`), `_spawn_swing_arc()`,
  `_spawn_sword_slash_effect(downward)`, `_trigger_thrust_dash()`.
- **Facing** is done by flipping `PlayerSkin.scale.x` sign (see
  playercontroller `_on_joystick_moved`). Weapon animators must account for `sign(scale.x)`.

**Adding a new player animation** = add a builder returning an `Animation`, register
it in the library (locomotion) or provide it from a weapon animator (attacks).

### ⚠ Known animation-system hazards (fix when you touch these)
- `long_fall` adds a track on `.:rotation` (rotates PlayerSkin itself) → can fight
  facing flip. Player resets `player_skin.rotation = 0.0` on landing as a workaround.
- `_spawn_swing_arc` / `_spawn_sword_slash_effect` add VFX nodes to
  `get_parent().get_parent()` (scene). **Scene change mid-swing orphans them.** Use a
  persistent VFX container instead (see MASTER_PROMPT Phase 0).

---

## 6. Weapon System

### WeaponData (`weapon_data.gd`, `class_name WeaponData`, extends Resource)
Exports: `weapon_name`, `weapon_type`, `weapon_description`, `weapon_icon`,
`animator_script` (GDScript). Normal attack: `atk_min`, `atk_max`, `attack_cooldown`,
`stamina_cost`. Charged: `charged_damage`, `charged_knockback`, `charged_stamina_cost`,
`charge_time`. Animations: `attack_right_anim`, `attack_left_anim`, `charged_anim`,
`combo_anims: Array[String]`. `calc_damage(stat_atk)` → `randi_range(atk_min+stat_atk, atk_max+stat_atk)`.

### WeaponAnimator (`weapon_animator.gd`, `class_name WeaponAnimator`, extends RefCounted)
Stateless plugin contract — override:
- `setup_visual(weapon_sprite, weapon_data, pivots)` — texture/scale/offset/position/
  rotation/z_index of the WeaponSprite; reposition `larm_node`/`rarm_node` for grip.
- `get_attack_animations(pivots) -> Dictionary` — `{ "anim_name": Animation }`.
- `get_hold_positions() -> Dictionary` — `{ base_larm, base_rarm, larm_rot, rarm_rot }`
  baked into locomotion so the character holds the weapon while moving.
- `teardown_visual(weapon_sprite, pivots)` — base impl hides/clears the sprite.
- **Static track helpers:** `anim_pos`, `anim_rot`, `anim_zidx`, and
  `anim_method(anim, node_path, time, method, args)` for method-call tracks.

`pivots` dict contains: `base_torso/head/larm/rarm/lleg/rleg` (Vector2) +
`larm_node`/`rarm_node` (Node2D).

### Existing animators
- `fists_animator.gd` — default; registered at startup and as unequip fallback.
- `sword_animator.gd` — two-handed; `sword_combo_1/2/3` + `sword_charged` (thrust +
  `_trigger_thrust_dash`). Good reference for combos + method tracks + slash VFX.
- `staff_animator.gd` — two-handed; `staff_attack_right` (sweep) + `staff_attack_left`
  (jab). **No charged/laser animation yet.**

**Adding a weapon** = create a `.tres` WeaponData pointing `animator_script` at a new
`WeaponAnimator` subclass in `weapons/animators/`.

---

## 7. Combat Flow (current)

1. Input → `attack_tapped`/`attack_charged` (touch ring) → player `_on_attack_button_pressed()` /
   `_on_attack_charged()`.
2. Player pays stamina/saturation, sets `is_attacking`, clears `hit_enemies_this_swing`,
   calls `player_skin.play_attack()` / `play_uppercut()`.
3. Animation method track fires `_enable_hitbox()` → `AttackHitbox` (Area2D) begins
   monitoring; `body_entered` → player `_on_attack_hit(body)`.
4. `_on_attack_hit`: if `body` in group `"enemy"` and not already hit this swing →
   compute damage (`calc_damage` or `charged_damage`) → `body.take_damage(dmg, kb)` →
   `_spawn_hit_particles()`.
5. `_disable_hitbox()` later in the anim; `animation_finished` → `attack_finished` →
   player `_on_attack_finished()` sets cooldown.

**Enemy `take_damage(amount, knockback)`** exists on slime (flash, damage number,
knockback, `_die` → +10 EXP, fade). Whisperer lacks it.

### ⚠ Critical combat gaps
- **Player has NO `take_damage()` / hurtbox / hurt state / death handling.** Enemies
  cannot hurt the player. `dieo.tscn` (death screen) is unimplemented.
- Slime ATTACK state only zeroes velocity — no player damage.
- Whisperer: empty `_attack_player`, no HP/death, no `collision_layer=4` (player hitbox
  can't detect it).

---

## 8. Input System (current) — IMPORTANT for PC controls

- **No custom InputMap actions defined** in `project.godot` (only Godot defaults).
  The only action referenced in code is `ui_accept` (jump, in `_physics_process`).
- **Movement:** virtual `joystick.gd` emits `joystick_moved(Vector2)` →
  `playercontroller._on_joystick_moved()` sets `joystick_vector` + facing. Joystick also
  has mouse fallback (left-half of screen) for desktop.
- **Attack:** `attack_button_ring.gd` (touch/mouse) → `attack_tapped`/`attack_charged`.
  Charge is **binary** (fully charged or not) — no continuous charge level exposed.
- **Jump/Evade/Pause:** TouchControls buttons → player `_on_jump_button_pressed()`,
  `_on_evade_button_pressed()`, pause menu.
- `project.godot` has `pointing/emulate_touch_from_mouse=true`.

**Implication:** PC controls require adding an InputMap (WASD/arrows/space/mouse/etc.)
and routing keyboard/mouse into the *same* `joystick_vector` + action handlers so touch
and KBM stay behavior-identical. The charge system must be extended to a **continuous**
charge level for the mage laser.

---

## 9. Stats / Class / Progression / Saturation

- Class stats loaded in player `_ready()` from `Global.get_current_class_stats()`; hp/sta/
  mana scaled ×10 for bars; `defense` raw.
- **Stat allocation:** `allocate_stat(name)` for HP/MP/STA/ATK/DEF/EVA; `stat_points`
  start 4, +4 per level.
- **EXP/level:** `add_exp(amount)`; `max_exp = 100 * 2^(level-1)`; level-up refills
  health/stamina/mana/saturation.
- **Saturation (hunger):** drains with movement (`SAT_MOVE_COST`) and actions
  (`SAT_ACTION_COST`); HP regens 1/s only when saturation > 60%.
- **Stamina:** discrete 7/s regen unless paused (attacks/jumps/wall-slide/dash).
- **Movement extras:** wall-slide (30% fall reduction if stamina>0), wall-jump,
  double-jump (stamina cost), dash/evade (reversed direction — being replaced by dodge roll).

---

## 10. Collision Layers (observed + PROPOSED standard)

**Observed today:**
- Player `AttackHitbox`: `collision_layer = 2`, `collision_mask = 4`, `monitorable=false`.
- Slime sets `collision_layer = 4` in `_ready()` (so player hitbox mask 4 detects it).
- Player/enemy bodies: default (layer 1) — collide with terrain.

**PROPOSED standard to adopt project-wide (verify before applying):**

| Bit | Layer | Used by |
|---|---|---|
| 1 | Environment | Terrain / platforms (StaticBody2D); player & enemy bodies collide here |
| 2 | PlayerHitbox | Player attack Area2D (mask → 4) *(existing)* |
| 3 | PlayerHurtbox | New Area2D on player (damageable) |
| 4 | EnemyHurtbox | Enemy body/hurtbox *(existing convention)*; player hitbox masks this |
| 5 | EnemyHitbox | New enemy attack Area2D (mask → 3, damages player) |
| 6 | Projectile/Beam | Player beams mask 4; enemy projectiles mask 3 |

Damage routing:
- Player attack: hitbox layer 2 / mask 4 → `enemy.take_damage()`.
- Enemy attack: hitbox layer 5 / mask 3 → checks player parry/i-frames → `player.take_damage()`.

---

## 11. Known Issues (audit summary — all in scope per MASTER_PROMPT)

**HIGH:** God-class PlayerController; slime deals no damage; whisperer incomplete
(no combat/death/collision); hardcoded profile-toggle screen coords
(`playercontroller.gd:223-238`).

**MEDIUM:** duplicate jump logic (`_physics_process` vs `_on_jump_button_pressed`);
missing staff charged anim; profile equipment/skills placeholders; no line-of-sight for
aggro; VFX/particles parented to scene root (orphan risk); inventory swap emits
`weapon_equipped` but not `weapon_unequipped`; drag-drop can't target armor slots;
`joystick._end_touch()` called externally (encapsulation); touch button nested in Button
(titlescreen); viewport-dependent magic numbers in HUD.

**LOW:** missing type hints; runtime `load()` vs `preload()`/const; dead files
(`dieo.gd`, `playbutton.gd`); emoji icons render inconsistently; `original_positions`
unused; per-frame `update_bars()` with 11 args; O(n) `hit_enemies_this_swing` array.

**INFO:** file sizes (813/615/584); evade direction unintuitive; `clip_polygon_left`
single-axis; whisperer WIP.

**No save/persistence system** — everything resets on scene reload.

---

## 12. Godot 4.3 gotchas relevant to this work

- `create_tween()` is bound to the node; `.chain()`, `.set_parallel(true)`, `.tween_callback`.
- `Area2D` needs `monitoring`/`monitorable` set correctly for detection direction.
- Use `is_instance_valid(node)` before touching nodes in deferred/tween callbacks
  (scene changes can free them).
- `RayCast2D` / `ShapeCast2D` for hitscan (mage laser, LOS). Set `collision_mask`.
- Add InputMap actions in `project.godot` under `[input]` with events, or via
  `InputMap` at runtime. Prefer editing `project.godot` for persistence.
- `@export var x: Array[String] = []` typed arrays are supported.
- Method-call animation tracks: value = `{"method": name, "args": [...]}`.
