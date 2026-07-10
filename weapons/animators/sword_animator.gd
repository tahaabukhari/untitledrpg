extends WeaponAnimator
class_name SwordAnimator
## Animation provider for a ONE-HANDED short sword.
## Hold: gripped by the hilt in the FORWARD hand (LeftArmPivot), blade up-forward.
## The free back hand (RightArmPivot) swings naturally when moving.
## Combo: quick 3-hit one-handed chain (down-slash → reverse → overhead chop).
## Charged: TWO-HANDED lunging thrust (the back hand comes onto the grip).
## Parry: raise the blade across the body into a guard (overrides the generic parry).
##
## All feel/placement lives in the tuning block below — edit these to reshape it.

# ─── Tuning ──────────────────────────────────────────────────────────────────
# Held in the FORWARD hand (LeftArmPivot); the WeaponSprite is its child, so its
# rotation is relative to that hand. Rig-local units (pre 2× PlayerSkin scale).
const BLADE_SCALE     := 0.42               # short-sword size (was 0.5, two-handed)
const HILT_TO_HAND    := 4.0                # px the grip pokes past the sprite bottom
const HAND_GRIP       := Vector2(7, -3)     # forward-hand position at rest
const HAND_GRIP_ROT   := -0.15              # forward-hand tilt at rest (rad)
const WEAPON_POS      := Vector2(-5, 3)     # sprite pos relative to LeftArmPivot → in the hand
const BLADE_REST_DEG  := -45.0              # blade angle at rest (up & forward)
const MOVE_SWING_MUL  := 0.35               # damp the sword arm while walking/running (0..1)
const BACK_HAND       := Vector2(-6, -4.5)  # free back-hand rest position

# Attack-shape knobs (radians unless noted)
const CHARGE_BLADE_DEG := 60.0              # blade leveled forward during the thrust
const PARRY_BLADE_DEG  := -88.0             # blade near-vertical in the guard pose
const CHARGE_OFFHAND   := Vector2(9, -1)    # where the back hand grips during the thrust


func setup_visual(weapon_sprite: Sprite2D, weapon_data: WeaponData, pivots: Dictionary) -> void:
	if not weapon_sprite or not weapon_data.weapon_icon:
		return

	weapon_sprite.texture = weapon_data.weapon_icon
	weapon_sprite.scale = Vector2(BLADE_SCALE, BLADE_SCALE)

	# Pivot at the hilt (bottom of the sprite) so the blade swings from the grip.
	var tex_h = weapon_data.weapon_icon.get_height()
	weapon_sprite.offset = Vector2(0, -tex_h / 2.0 + HILT_TO_HAND)
	weapon_sprite.position = WEAPON_POS
	weapon_sprite.rotation = deg_to_rad(BLADE_REST_DEG)
	weapon_sprite.z_index = 10  # above all body parts
	weapon_sprite.visible = true

	# One-handed: forward hand grips the hilt; back hand relaxes at its rest.
	var larm = pivots.get("larm_node") as Node2D
	var rarm = pivots.get("rarm_node") as Node2D
	if larm:
		larm.position = HAND_GRIP
		larm.rotation = HAND_GRIP_ROT
	if rarm:
		rarm.position = BACK_HAND
		rarm.rotation = 0.0


func get_hold_positions() -> Dictionary:
	## One-handed grip: forward hand holds the hilt (held steadier while moving so
	## the blade doesn't flail); the back hand keeps its full natural swing.
	return {
		"base_larm": HAND_GRIP,
		"base_rarm": BACK_HAND,
		"larm_rot": HAND_GRIP_ROT,
		"rarm_rot": 0.0,
		"larm_swing_mul": MOVE_SWING_MUL,
		"rarm_swing_mul": 1.0,
	}


func get_attack_animations(pivots: Dictionary) -> Dictionary:
	var base_torso: Vector2 = pivots.get("base_torso", Vector2(0, 0.5))
	var base_head: Vector2  = pivots.get("base_head", Vector2(0, -5.5))
	var base_lleg: Vector2  = pivots.get("base_lleg", Vector2(-1, 4))
	var base_rleg: Vector2  = pivots.get("base_rleg", Vector2(0, 4))
	var f := HAND_GRIP   # forward (sword) hand base
	var b := BACK_HAND   # free back hand base

	return {
		"sword_combo_1": _make_combo_1(f, b, base_torso, base_head, base_lleg, base_rleg),
		"sword_combo_2": _make_combo_2(f, b, base_torso, base_head, base_lleg, base_rleg),
		"sword_combo_3": _make_combo_3(f, b, base_torso, base_head, base_lleg, base_rleg),
		"sword_charged": _make_charged_thrust(f, b, base_torso, base_head, base_lleg, base_rleg),
		"parry":         _make_parry_guard(f, b, base_torso, base_head, base_lleg, base_rleg),
	}


# ─── COMBO 1: Diagonal slash, down-forward ──────────────────────────────────

func _make_combo_1(f: Vector2, b: Vector2, base_torso: Vector2, base_head: Vector2, base_lleg: Vector2, base_rleg: Vector2) -> Animation:
	var a = Animation.new()
	a.length = 0.38
	a.step = 0.05
	var REST := deg_to_rad(BLADE_REST_DEG)

	# Forward (sword) arm: wind up high-back, slash down-forward, recover
	anim_rot(a, "LeftArmPivot", [
		[0.0,  HAND_GRIP_ROT],
		[0.08, HAND_GRIP_ROT - 0.7],
		[0.18, HAND_GRIP_ROT + 1.3],
		[0.28, HAND_GRIP_ROT + 0.9],
		[0.38, HAND_GRIP_ROT],
	])
	anim_pos(a, "LeftArmPivot", [
		[0.0,  f],
		[0.08, f + Vector2(-2, -4)],
		[0.18, f + Vector2(5, 3)],
		[0.28, f + Vector2(3, 1)],
		[0.38, f],
	])
	# Blade sweeps through the arc (relative to the hand), returns to rest
	anim_rot(a, "LeftArmPivot/WeaponSprite", [
		[0.0,  REST],
		[0.08, REST - 0.5],
		[0.18, REST + 2.4],
		[0.28, REST + 2.0],
		[0.38, REST],
	])

	# Free back hand counter-balances (does NOT grip)
	anim_pos(a, "RightArmPivot", [[0.0, b], [0.18, b + Vector2(-2, 1)], [0.38, b]])
	anim_rot(a, "RightArmPivot", [[0.0, 0.0], [0.18, 0.3], [0.38, 0.0]])

	# Torso/head lean into the swing
	anim_rot(a, "TorsoPivot", [[0.0, 0.0], [0.08, -0.08], [0.18, 0.12], [0.3, 0.06], [0.38, 0.0]])
	anim_pos(a, "TorsoPivot", [[0.0, base_torso], [0.18, base_torso + Vector2(2, 0)], [0.38, base_torso]])
	anim_pos(a, "HeadPivot", [[0.0, base_head], [0.18, base_head + Vector2(1, 0)], [0.38, base_head]])

	# Legs planted
	anim_rot(a, "LeftLegPivot",  [[0.0, 0.0], [0.38, 0.0]])
	anim_rot(a, "RightLegPivot", [[0.0, 0.0], [0.38, 0.0]])
	anim_pos(a, "LeftLegPivot",  [[0.0, base_lleg], [0.38, base_lleg]])
	anim_pos(a, "RightLegPivot", [[0.0, base_rleg], [0.38, base_rleg]])

	# Hitbox + slash VFX (downward)
	anim_method(a, ".", 0.10, "_enable_hitbox")
	anim_method(a, ".", 0.12, "_spawn_sword_slash_effect", [true])
	anim_method(a, ".", 0.24, "_disable_hitbox")

	return a


# ─── COMBO 2: Quick reverse slash, up-back ──────────────────────────────────

func _make_combo_2(f: Vector2, b: Vector2, base_torso: Vector2, base_head: Vector2, base_lleg: Vector2, base_rleg: Vector2) -> Animation:
	var a = Animation.new()
	a.length = 0.30
	a.step = 0.05
	var REST := deg_to_rad(BLADE_REST_DEG)

	# Forward arm: brief low-forward windup, then whip up-back
	anim_rot(a, "LeftArmPivot", [
		[0.0,  HAND_GRIP_ROT],
		[0.06, HAND_GRIP_ROT + 0.8],
		[0.15, HAND_GRIP_ROT - 1.3],
		[0.24, HAND_GRIP_ROT - 0.9],
		[0.30, HAND_GRIP_ROT],
	])
	anim_pos(a, "LeftArmPivot", [
		[0.0,  f],
		[0.06, f + Vector2(3, 3)],
		[0.15, f + Vector2(-3, -4)],
		[0.30, f],
	])
	anim_rot(a, "LeftArmPivot/WeaponSprite", [
		[0.0,  REST],
		[0.06, REST + 1.6],
		[0.15, REST - 1.4],
		[0.30, REST],
	])

	anim_pos(a, "RightArmPivot", [[0.0, b], [0.15, b + Vector2(1, -1)], [0.30, b]])
	anim_rot(a, "RightArmPivot", [[0.0, 0.0], [0.15, -0.25], [0.30, 0.0]])

	anim_rot(a, "TorsoPivot", [[0.0, 0.0], [0.06, 0.1], [0.15, -0.1], [0.30, 0.0]])
	anim_pos(a, "TorsoPivot", [[0.0, base_torso], [0.08, base_torso + Vector2(1, 0)], [0.30, base_torso]])
	anim_pos(a, "HeadPivot", [[0.0, base_head], [0.08, base_head + Vector2(0.5, 0)], [0.30, base_head]])

	anim_rot(a, "LeftLegPivot",  [[0.0, 0.0], [0.30, 0.0]])
	anim_rot(a, "RightLegPivot", [[0.0, 0.0], [0.30, 0.0]])
	anim_pos(a, "LeftLegPivot",  [[0.0, base_lleg], [0.30, base_lleg]])
	anim_pos(a, "RightLegPivot", [[0.0, base_rleg], [0.30, base_rleg]])

	# Hitbox + slash VFX (upward)
	anim_method(a, ".", 0.06, "_enable_hitbox")
	anim_method(a, ".", 0.08, "_spawn_sword_slash_effect", [false])
	anim_method(a, ".", 0.18, "_disable_hitbox")

	return a


# ─── COMBO 3: Heavy overhead chop ────────────────────────────────────────────

func _make_combo_3(f: Vector2, b: Vector2, base_torso: Vector2, base_head: Vector2, base_lleg: Vector2, base_rleg: Vector2) -> Animation:
	var a = Animation.new()
	a.length = 0.5
	a.step = 0.05
	var REST := deg_to_rad(BLADE_REST_DEG)

	# Forward arm: raise the blade high overhead, then chop straight down-forward
	anim_rot(a, "LeftArmPivot", [
		[0.0,  HAND_GRIP_ROT],
		[0.1,  HAND_GRIP_ROT - 0.4],
		[0.2,  HAND_GRIP_ROT - 1.3],
		[0.32, HAND_GRIP_ROT + 1.8],
		[0.42, HAND_GRIP_ROT + 1.3],
		[0.5,  HAND_GRIP_ROT],
	])
	anim_pos(a, "LeftArmPivot", [
		[0.0,  f],
		[0.2,  f + Vector2(-2, -8)],
		[0.32, f + Vector2(5, 5)],
		[0.42, f + Vector2(3, 2)],
		[0.5,  f],
	])
	anim_rot(a, "LeftArmPivot/WeaponSprite", [
		[0.0,  REST],
		[0.2,  REST - 1.0],
		[0.32, REST + 2.9],
		[0.42, REST + 2.6],
		[0.5,  REST],
	])

	# Back hand braces near the chest for the heavy blow
	anim_pos(a, "RightArmPivot", [[0.0, b], [0.2, b + Vector2(1, -2)], [0.32, b + Vector2(2, 1)], [0.5, b]])
	anim_rot(a, "RightArmPivot", [[0.0, 0.0], [0.2, -0.3], [0.5, 0.0]])

	# Torso: crouch on the raise, drive down on the chop
	anim_rot(a, "TorsoPivot", [[0.0, 0.0], [0.2, -0.12], [0.32, 0.18], [0.42, 0.08], [0.5, 0.0]])
	anim_pos(a, "TorsoPivot", [
		[0.0, base_torso],
		[0.2, base_torso + Vector2(0, -2)],
		[0.32, base_torso + Vector2(3, 2)],
		[0.5, base_torso],
	])
	anim_pos(a, "HeadPivot", [
		[0.0, base_head],
		[0.2, base_head + Vector2(0, -3)],
		[0.32, base_head + Vector2(2, 1)],
		[0.5, base_head],
	])

	# Legs: slight crouch then plant
	anim_rot(a, "LeftLegPivot",  [[0.0, 0.0], [0.2, 0.06], [0.32, -0.04], [0.5, 0.0]])
	anim_rot(a, "RightLegPivot", [[0.0, 0.0], [0.2, 0.06], [0.32, -0.04], [0.5, 0.0]])
	anim_pos(a, "LeftLegPivot",  [[0.0, base_lleg], [0.5, base_lleg]])
	anim_pos(a, "RightLegPivot", [[0.0, base_rleg], [0.5, base_rleg]])

	# Hitbox + double slash VFX for the heavy chop
	anim_method(a, ".", 0.30, "_enable_hitbox")
	anim_method(a, ".", 0.32, "_spawn_sword_slash_effect", [true])
	anim_method(a, ".", 0.36, "_spawn_sword_slash_effect", [true])
	anim_method(a, ".", 0.44, "_disable_hitbox")

	return a


# ─── CHARGED: Two-handed lunging thrust ──────────────────────────────────────

func _make_charged_thrust(f: Vector2, b: Vector2, base_torso: Vector2, base_head: Vector2, base_lleg: Vector2, base_rleg: Vector2) -> Animation:
	var a = Animation.new()
	a.length = 0.8
	a.step = 0.05
	var REST := deg_to_rad(BLADE_REST_DEG)
	var LEVEL := deg_to_rad(CHARGE_BLADE_DEG)  # blade leveled forward for the thrust

	# ── Windup (0.0–0.3): both hands pull to the waist, blade levels forward ──
	# ── Thrust (0.3–0.55): explode forward ── Recover (0.55–0.8) ──
	anim_rot(a, "LeftArmPivot", [
		[0.0,  HAND_GRIP_ROT],
		[0.3,  HAND_GRIP_ROT + 0.4],   # cocked back
		[0.42, HAND_GRIP_ROT - 0.3],   # driven forward
		[0.8,  HAND_GRIP_ROT],
	])
	anim_pos(a, "LeftArmPivot", [
		[0.0,  f],
		[0.3,  f + Vector2(-7, 2)],     # retract to the hip
		[0.42, f + Vector2(12, -2)],    # full extension
		[0.55, f + Vector2(6, -1)],
		[0.8,  f],
	])
	anim_rot(a, "LeftArmPivot/WeaponSprite", [
		[0.0,  REST],
		[0.3,  LEVEL],                  # tip points forward
		[0.42, LEVEL],                  # stays level through the thrust
		[0.8,  REST],
	])

	# Back hand comes ONTO the grip (two-handed) for the thrust, then releases
	anim_pos(a, "RightArmPivot", [
		[0.0,  b],
		[0.3,  b + CHARGE_OFFHAND * 0.6],
		[0.42, b + CHARGE_OFFHAND],     # both hands driving forward together
		[0.55, b + CHARGE_OFFHAND * 0.5],
		[0.8,  b],
	])
	anim_rot(a, "RightArmPivot", [
		[0.0,  0.0],
		[0.3,  -0.35],
		[0.42, -0.5],
		[0.8,  0.0],
	])

	# Torso: coil back, then lunge forward
	anim_rot(a, "TorsoPivot", [
		[0.0, 0.0], [0.3, -0.12], [0.42, 0.15], [0.55, 0.1], [0.8, 0.0]
	])
	anim_pos(a, "TorsoPivot", [
		[0.0, base_torso],
		[0.3, base_torso + Vector2(-4, 0)],
		[0.42, base_torso + Vector2(8, -1)],
		[0.55, base_torso + Vector2(4, 0)],
		[0.8, base_torso],
	])
	anim_pos(a, "HeadPivot", [
		[0.0, base_head],
		[0.3, base_head + Vector2(-3, 0)],
		[0.42, base_head + Vector2(6, -1)],
		[0.8, base_head],
	])

	# Legs: brace during windup, push off on the lunge
	anim_rot(a, "LeftLegPivot",  [[0.0, 0.0], [0.3, 0.1], [0.42, -0.06], [0.8, 0.0]])
	anim_rot(a, "RightLegPivot", [[0.0, 0.0], [0.3, 0.08], [0.42, -0.08], [0.8, 0.0]])
	anim_pos(a, "LeftLegPivot", [
		[0.0, base_lleg], [0.3, base_lleg + Vector2(-1, 0)], [0.42, base_lleg + Vector2(2, 0)], [0.8, base_lleg]
	])
	anim_pos(a, "RightLegPivot", [
		[0.0, base_rleg], [0.3, base_rleg + Vector2(-1, 0)], [0.42, base_rleg + Vector2(2, 0)], [0.8, base_rleg]
	])

	# Hitbox during the thrust + forward dash impulse
	anim_method(a, ".", 0.38, "_enable_hitbox")
	anim_method(a, ".", 0.40, "_trigger_thrust_dash")
	anim_method(a, ".", 0.42, "_spawn_sword_slash_effect", [true])
	anim_method(a, ".", 0.55, "_disable_hitbox")

	return a


# ─── PARRY: Raise the blade across the body into a guard ─────────────────────

func _make_parry_guard(f: Vector2, b: Vector2, base_torso: Vector2, base_head: Vector2, base_lleg: Vector2, base_rleg: Vector2) -> Animation:
	## Overrides the generic fist parry with a sword guard: snap the blade up
	## across the chest, hold the deflection window, then relax back to the hold.
	var a = Animation.new()
	a.length = 0.45
	a.loop_mode = Animation.LOOP_NONE
	var REST := deg_to_rad(BLADE_REST_DEG)
	var GUARD := deg_to_rad(PARRY_BLADE_DEG)

	# Forward hand raises the sword up and across, holds, relaxes
	anim_pos(a, "LeftArmPivot", [
		[0.0,  f],
		[0.05, f + Vector2(1, -5)],
		[0.28, f + Vector2(1, -5)],
		[0.45, f],
	])
	anim_rot(a, "LeftArmPivot", [
		[0.0,  HAND_GRIP_ROT],
		[0.05, HAND_GRIP_ROT - 1.0],
		[0.28, HAND_GRIP_ROT - 1.0],
		[0.45, HAND_GRIP_ROT],
	])
	# Blade snaps to a near-vertical guard, then back to rest
	anim_rot(a, "LeftArmPivot/WeaponSprite", [
		[0.0,  REST],
		[0.05, GUARD],
		[0.28, GUARD],
		[0.45, REST],
	])

	# Back hand braces behind the blade
	anim_pos(a, "RightArmPivot", [
		[0.0,  b],
		[0.05, b + Vector2(6, -2)],
		[0.28, b + Vector2(6, -2)],
		[0.45, b],
	])
	anim_rot(a, "RightArmPivot", [[0.0, 0.0], [0.05, -0.6], [0.28, -0.6], [0.45, 0.0]])

	# Slight brace: torso leans back, legs plant wide
	anim_pos(a, "TorsoPivot", [
		[0.0,  base_torso],
		[0.05, base_torso + Vector2(-1.5, 0.5)],
		[0.28, base_torso + Vector2(-1.5, 0.5)],
		[0.45, base_torso],
	])
	anim_rot(a, "TorsoPivot", [[0.0, 0.0], [0.05, -0.08], [0.28, -0.08], [0.45, 0.0]])
	anim_pos(a, "HeadPivot", [
		[0.0,  base_head],
		[0.05, base_head + Vector2(-1, 0.5)],
		[0.28, base_head + Vector2(-1, 0.5)],
		[0.45, base_head],
	])
	anim_rot(a, "LeftLegPivot",  [[0.0, 0.0], [0.05, -0.12], [0.28, -0.12], [0.45, 0.0]])
	anim_rot(a, "RightLegPivot", [[0.0, 0.0], [0.05, 0.12], [0.28, 0.12], [0.45, 0.0]])
	anim_pos(a, "LeftLegPivot",  [[0.0, base_lleg], [0.45, base_lleg]])
	anim_pos(a, "RightLegPivot", [[0.0, base_rleg], [0.45, base_rleg]])

	return a
