extends WeaponAnimator
class_name SwordAnimator
## Animation provider for a ONE-HANDED short sword.
## Hold: gripped by the hilt in the FORWARD hand (LeftArmPivot), blade up-forward.
## The free back hand (RightArmPivot) swings naturally when moving.
## Combo: quick 3-hit one-handed chain (down-slash → reverse → overhead chop).
## Charged: TWO-HANDED lunging thrust (the back hand comes onto the grip).
## Parry: raise the blade across the body into a guard (overrides the generic parry).
##
## ALL placement/feel is tunable in the Inspector via the "Sword Hold & Visual"
## group on the weapon's .tres — this script only reads those @export values off
## weapon_data. Edit starter_sword.tres to reshape the sword.

# Fallback defaults if weapon_data is somehow missing (should not happen in play).
const _DEF_SCALE := 0.42
const _DEF_HILT := 4.0
const _DEF_WEAPON_POS := Vector2(-5, 3)
const _DEF_REST_DEG := -45.0
const _DEF_GRIP := Vector2(7, -3)
const _DEF_GRIP_ROT := -0.15
const _DEF_BACK := Vector2(-6, -4.5)
const _DEF_SWING_MUL := 0.35
const _DEF_CHARGE_DEG := 60.0
const _DEF_CHARGE_OFFHAND := Vector2(9, -1)
const _DEF_PARRY_DEG := -88.0


# ─── Tuning accessors (read from weapon_data, fall back to defaults) ─────────

func _scale() -> float:        return weapon_data.sword_blade_scale if weapon_data else _DEF_SCALE
func _hilt() -> float:         return weapon_data.sword_hilt_to_hand if weapon_data else _DEF_HILT
func _weapon_pos() -> Vector2: return weapon_data.sword_weapon_pos if weapon_data else _DEF_WEAPON_POS
func _rest() -> float:         return deg_to_rad(weapon_data.sword_blade_rest_deg if weapon_data else _DEF_REST_DEG)
func _grip() -> Vector2:       return weapon_data.sword_hand_grip if weapon_data else _DEF_GRIP
func _grip_rot() -> float:     return weapon_data.sword_hand_grip_rot if weapon_data else _DEF_GRIP_ROT
func _back() -> Vector2:       return weapon_data.sword_back_hand if weapon_data else _DEF_BACK
func _swing_mul() -> float:    return weapon_data.sword_move_swing_mul if weapon_data else _DEF_SWING_MUL
func _charge_deg() -> float:   return deg_to_rad(weapon_data.sword_charge_blade_deg if weapon_data else _DEF_CHARGE_DEG)
func _charge_off() -> Vector2: return weapon_data.sword_charge_offhand if weapon_data else _DEF_CHARGE_OFFHAND
func _parry_deg() -> float:    return deg_to_rad(weapon_data.sword_parry_blade_deg if weapon_data else _DEF_PARRY_DEG)


func setup_visual(weapon_sprite: Sprite2D, wdata: WeaponData, pivots: Dictionary) -> void:
	if not weapon_sprite or not wdata.weapon_icon:
		return

	weapon_sprite.texture = wdata.weapon_icon
	weapon_sprite.scale = Vector2(_scale(), _scale())

	# Pivot at the hilt (bottom of the sprite) so the blade swings from the grip.
	var tex_h = wdata.weapon_icon.get_height()
	weapon_sprite.offset = Vector2(0, -tex_h / 2.0 + _hilt())
	weapon_sprite.position = _weapon_pos()
	weapon_sprite.rotation = _rest()
	weapon_sprite.z_index = 10  # above all body parts
	weapon_sprite.visible = true

	# One-handed: forward hand grips the hilt; back hand relaxes at its rest.
	var larm = pivots.get("larm_node") as Node2D
	var rarm = pivots.get("rarm_node") as Node2D
	if larm:
		larm.position = _grip()
		larm.rotation = _grip_rot()
	if rarm:
		rarm.position = _back()
		rarm.rotation = 0.0


func get_hold_positions() -> Dictionary:
	## One-handed grip: forward hand holds the hilt (held steadier while moving so
	## the blade doesn't flail); the back hand keeps its full natural swing.
	return {
		"base_larm": _grip(),
		"base_rarm": _back(),
		"larm_rot": _grip_rot(),
		"rarm_rot": 0.0,
		"larm_swing_mul": _swing_mul(),
		"rarm_swing_mul": 1.0,
	}


func get_attack_animations(pivots: Dictionary) -> Dictionary:
	var base_torso: Vector2 = pivots.get("base_torso", Vector2(0, 0.5))
	var base_head: Vector2  = pivots.get("base_head", Vector2(0, -5.5))
	var base_lleg: Vector2  = pivots.get("base_lleg", Vector2(-1, 4))
	var base_rleg: Vector2  = pivots.get("base_rleg", Vector2(0, 4))
	var f := _grip()   # forward (sword) hand base
	var b := _back()   # free back hand base

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
	var REST := _rest()
	var GR := _grip_rot()

	# Forward (sword) arm: wind up high-back, slash down-forward, recover
	anim_rot(a, "LeftArmPivot", [
		[0.0,  GR],
		[0.08, GR - 0.7],
		[0.18, GR + 1.3],
		[0.28, GR + 0.9],
		[0.38, GR],
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
	var REST := _rest()
	var GR := _grip_rot()

	# Forward arm: brief low-forward windup, then whip up-back
	anim_rot(a, "LeftArmPivot", [
		[0.0,  GR],
		[0.06, GR + 0.8],
		[0.15, GR - 1.3],
		[0.24, GR - 0.9],
		[0.30, GR],
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
	var REST := _rest()
	var GR := _grip_rot()

	# Forward arm: raise the blade high overhead, then chop straight down-forward
	anim_rot(a, "LeftArmPivot", [
		[0.0,  GR],
		[0.1,  GR - 0.4],
		[0.2,  GR - 1.3],
		[0.32, GR + 1.8],
		[0.42, GR + 1.3],
		[0.5,  GR],
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
	var REST := _rest()
	var GR := _grip_rot()
	var LEVEL := _charge_deg()  # blade leveled forward for the thrust
	var OFF := _charge_off()

	# ── Windup (0.0–0.3): both hands pull to the waist, blade levels forward ──
	# ── Thrust (0.3–0.55): explode forward ── Recover (0.55–0.8) ──
	anim_rot(a, "LeftArmPivot", [
		[0.0,  GR],
		[0.3,  GR + 0.4],   # cocked back
		[0.42, GR - 0.3],   # driven forward
		[0.8,  GR],
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
		[0.3,  b + OFF * 0.6],
		[0.42, b + OFF],     # both hands driving forward together
		[0.55, b + OFF * 0.5],
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
	var REST := _rest()
	var GR := _grip_rot()
	var GUARD := _parry_deg()

	# Forward hand raises the sword up and across, holds, relaxes
	anim_pos(a, "LeftArmPivot", [
		[0.0,  f],
		[0.05, f + Vector2(1, -5)],
		[0.28, f + Vector2(1, -5)],
		[0.45, f],
	])
	anim_rot(a, "LeftArmPivot", [
		[0.0,  GR],
		[0.05, GR - 1.0],
		[0.28, GR - 1.0],
		[0.45, GR],
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
