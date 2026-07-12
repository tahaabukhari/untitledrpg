# Graph Report - .  (2026-07-12)

## Corpus Check
- Corpus is ~25,312 words - fits in a single context window. You may not need a graph.

## Summary
- 105 nodes · 144 edges · 15 communities (10 shown, 5 thin omitted)
- Extraction: 74% EXTRACTED · 26% INFERRED · 1% AMBIGUOUS · INFERRED: 37 edges (avg confidence: 0.82)
- Token cost: 312,331 input · 0 output

## Community Hubs (Navigation)
- Weapon Animators & Hitbox/VFX Callbacks
- Enemy Framework, Boss & Design Docs
- Dodge / Trip / Mirror Mechanic
- Damage Resolution (take_damage)
- Charged Attacks (Laser/Heal) & Aim
- Melee Swing & Slash VFX
- Weapon Behavior Plugins
- Weapon Equip Pipeline
- Prayer / Lightning Effect
- Input Layer & Player Core
- Charge Telegraph
- Trip Effect
- Prayer Attack Trigger
- Fx Autoload
- Bombug Damage

## God Nodes (most connected - your core abstractions)
1. `EnemyBase` - 13 edges
2. `ARCHITECTURE.md (Wonders Of Creation)` - 13 edges
3. `WeaponData (weapon Resource)` - 8 edges
4. `WeaponAnimator (base plugin)` - 8 edges
5. `WeaponBehavior (base = melee)` - 8 edges
6. `Boss FOURBLADE` - 8 edges
7. `PlayerController.take_damage` - 7 edges
8. `EnemyBase.take_damage` - 7 edges
9. `Mirror Warrior` - 7 edges
10. `WeaponAnimator.make_directional_swing (static)` - 6 edges

## Surprising Connections (you probably didn't know these)
- `Breakables reuse the combat damage path` --semantically_similar_to--> `EnemyBase.take_damage`  [INFERRED] [semantically similar]
  docs/DUNGEON_STAGE_PLAN.md → enemies/enemy_base.gd
- `SwordAnimator` --references--> `PlayerAnimator._spawn_sword_slash_effect`  [INFERRED]
  weapons/animators/sword_animator.gd → player_animator.gd
- `WeaponBehavior.on_release` --conceptually_related_to--> `PlayerController.take_damage`  [AMBIGUOUS]
  weapons/behaviors/weapon_behavior.gd → playercontroller.gd
- `PlayerController._on_weapon_equipped` --conceptually_related_to--> `WeaponAnimator (base plugin)`  [INFERRED]
  playercontroller.gd → weapons/animators/weapon_animator.gd
- `SwordAnimator` --references--> `PlayerAnimator._enable_hitbox`  [INFERRED]
  weapons/animators/sword_animator.gd → player_animator.gd

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **All WeaponAnimator subclasses** — weapons_animators_weapon_animator_weaponanimator, weapons_animators_fists_animator_fistsanimator, weapons_animators_sword_animator_swordanimator, weapons_animators_staff_animator_staffanimator, weapons_animators_mage_staff_animator_magestaffanimator, weapons_animators_wand_animator_wandanimator, weapons_animators_projectile_weapon_animator_projectileweaponanimator, weapons_animators_prayer_animator_prayeranimator [EXTRACTED 1.00]
- **Weapon equip pipeline** — playercontroller__on_weapon_equipped, player_animator_equip_weapon_visual, weapons_animators_weapon_animator_get_hold_positions, weapons_animators_weapon_animator_get_attack_animations, weapons_animators_weapon_animator_setup_visual [EXTRACTED 0.95]
- **Directional attack + slash VFX flow** — playercontroller_do_normal_attack, player_animator_play_attack, weapons_animators_weapon_animator_make_directional_swing, player_animator__spawn_directional_slash, autoload_fx_slash_effect [INFERRED 0.85]
- **WeaponBehavior plugin family (charged-attack dispatch)** — weapons_behaviors_weapon_behavior_weaponbehavior, weapons_behaviors_laser_behavior_laserbehavior, weapons_behaviors_heal_behavior_healbehavior, weapons_behaviors_prayer_behavior_prayerbehavior [EXTRACTED 1.00]
- **EnemyBase subclass family** — enemies_enemy_base_enemybase, enemies_boss_fourblade_bossfourblade, enemies_mirror_warrior_mirrorwarrior, enemies_bombug_bombug, enemies_mannequin_mannequin, slime_slime [EXTRACTED 1.00]
- **Dodge/trip/mirror combat mechanic** — concept_dodge_trip_mirror, enemies_enemy_base_trip, enemies_mirror_warrior_process_slide, concept_bipedal_trip_rule, playercontroller_take_damage [INFERRED 0.85]

## Communities (15 total, 5 thin omitted)

### Community 0 - "Weapon Animators & Hitbox/VFX Callbacks"
Cohesion: 0.16
Nodes (19): Fx.swing_arc, PlayerAnimator._disable_hitbox, PlayerAnimator._enable_hitbox, PlayerAnimator._fire_projectile, PlayerAnimator._spawn_swing_arc, PlayerAnimator._trigger_thrust_dash, PlayerAnimator (code-driven puppet), PlayerController.fire_projectile (+11 more)

### Community 1 - "Enemy Framework, Boss & Design Docs"
Cohesion: 0.17
Nodes (17): Breakables reuse the combat damage path, Dungeon Stage 1 escape-themed modular level, EnemyBase enemy framework contract, FOURBLADE dynamic sword-power signature, ARCHITECTURE.md (Wonders Of Creation), CODEBASE_CONTEXT.md (superseded), MASTER_PROMPT.md (8-phase combat overhaul), Boss FOURBLADE (+9 more)

### Community 2 - "Dodge / Trip / Mirror Mechanic"
Cohesion: 0.29
Nodes (8): Bipedal-only trip rule, Directional dodge / tripping / mirror combat mechanic, hit_fx blood routing, Slide-trip chance-roll + stamina cost, EnemyBase.trip, Mirror Warrior, MirrorWarrior._on_tripped, MirrorWarrior._process_slide (slide-trip)

### Community 3 - "Damage Resolution (take_damage)"
Cohesion: 0.22
Nodes (10): Bombug, Bombug._detonate, BossFourblade._attempt_grab, BossFourblade.take_damage (phase2 override), EnemyBase._die, EnemyBase._on_attack_hitbox_hit, EnemyBase.take_damage, Mannequin.take_damage (DPS-tracking override) (+2 more)

### Community 4 - "Charged Attacks (Laser/Heal) & Aim"
Cohesion: 0.22
Nodes (9): Fx.beam, Fx.damage_number, Fx.heal_burst, PlayerInput.get_aim_vector, Joystick.get_attack_direction, PlayerAnimator.play_uppercut, PlayerController.channel_heal, PlayerController.do_charged_melee (+1 more)

### Community 5 - "Melee Swing & Slash VFX"
Cohesion: 0.25
Nodes (8): Fx.slash_effect, BossFourblade._build_animations, Mannequin._build_swing_animation, PlayerAnimator._spawn_directional_slash, PlayerAnimator._spawn_sword_slash_effect, PlayerAnimator.play_attack, PlayerController.do_normal_attack, WeaponAnimator.make_directional_swing (static)

### Community 6 - "Weapon Behavior Plugins"
Cohesion: 0.43
Nodes (8): Charged-attack flow (charged_style to behavior), Weapon behavior-as-plugin architecture, HealBehavior, LaserBehavior, PrayerBehavior, WeaponBehavior.on_release, WeaponBehavior.wants_charge_stance, WeaponBehavior (base = melee)

### Community 7 - "Weapon Equip Pipeline"
Cohesion: 0.33
Nodes (6): PlayerAnimator.equip_weapon_visual, PlayerController._on_weapon_equipped, WeaponData.get_behavior, WeaponAnimator.get_attack_animations, WeaponAnimator.get_hold_positions, WeaponAnimator.setup_visual

### Community 8 - "Prayer / Lightning Effect"
Cohesion: 0.50
Nodes (4): Fx.lightning_strike, Fx.prayer_sparkle, PlayerAnimator._trigger_prayer_effect, PlayerController.on_prayer_completed

### Community 9 - "Input Layer & Player Core"
Cohesion: 0.50
Nodes (4): PlayerInput (unified input layer), Virtual Joystick, PlayerAnimator.play_state, PlayerController (CharacterBody2D)

## Ambiguous Edges - Review These
- `PlayerController.take_damage` → `WeaponBehavior.on_release`  [AMBIGUOUS]
  weapons/behaviors/weapon_behavior.gd · relation: conceptually_related_to

## Knowledge Gaps
- **37 isolated node(s):** `PlayerAnimator (code-driven puppet)`, `Virtual Joystick`, `Fx (VFX/damage-number autoload)`, `MageStaffAnimator`, `PlayerController.do_charged_melee` (+32 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **5 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `PlayerController.take_damage` and `WeaponBehavior.on_release`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **Why does `WeaponAnimator.make_directional_swing (static)` connect `Melee Swing & Slash VFX` to `Enemy Framework, Boss & Design Docs`, `Dodge / Trip / Mirror Mechanic`?**
  _High betweenness centrality (0.467) - this node is a cross-community bridge._
- **Why does `SwordAnimator` connect `Weapon Animators & Hitbox/VFX Callbacks` to `Melee Swing & Slash VFX`?**
  _High betweenness centrality (0.397) - this node is a cross-community bridge._
- **Are the 2 inferred relationships involving `WeaponBehavior (base = melee)` (e.g. with `Charged-attack flow (charged_style to behavior)` and `Weapon behavior-as-plugin architecture`) actually correct?**
  _`WeaponBehavior (base = melee)` has 2 INFERRED edges - model-reasoned connections that need verification._
- **What connects `PlayerAnimator (code-driven puppet)`, `Virtual Joystick`, `Fx (VFX/damage-number autoload)` to the rest of the system?**
  _37 weakly-connected nodes found - possible documentation gaps or missing edges._