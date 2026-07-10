extends WeaponAnimator
class_name StaffAnimator
## Animation provider for a TWO-HANDED staff.
## Hold: both hands grip the shaft ADJACENT to each other; both are damped while
## moving so the staff stays composed. Attacks: a wide sweep and a quick jab.
##
## Grip/visual tuning is on the weapon's .tres ("Staff Hold & Visual" group),
## read here off weapon_data with const fallbacks.

const _DEF_SCALE := 0.42
const _DEF_REST_DEG := -60.0
const _DEF_SPRITE_POS := Vector2(3, 1)
const _DEF_FRONT := Vector2(2, -1)
const _DEF_BACK := Vector2(1, 1)
const _DEF_SWING := 0.25


func _sscale() -> float:    return weapon_data.staff_scale if weapon_data else _DEF_SCALE
func _srest() -> float:     return deg_to_rad(weapon_data.staff_rest_deg if weapon_data else _DEF_REST_DEG)
func _spos() -> Vector2:    return weapon_data.staff_sprite_pos if weapon_data else _DEF_SPRITE_POS
func _front() -> Vector2:   return weapon_data.staff_front_hand if weapon_data else _DEF_FRONT
func _back() -> Vector2:    return weapon_data.staff_back_hand if weapon_data else _DEF_BACK
func _sswing() -> float:    return weapon_data.staff_swing_mul if weapon_data else _DEF_SWING


func setup_visual(weapon_sprite: Sprite2D, wdata: WeaponData, pivots: Dictionary) -> void:
	if not weapon_sprite or not wdata.weapon_icon:
		return

	weapon_sprite.texture = wdata.weapon_icon
	weapon_sprite.scale = Vector2(_sscale(), _sscale())
	weapon_sprite.rotation = _srest()
	weapon_sprite.position = _spos()
	weapon_sprite.offset = Vector2.ZERO
	weapon_sprite.modulate = Color(1, 1, 1, 1)  # base staff: untinted
	weapon_sprite.z_index = -1  # behind the hands
	weapon_sprite.visible = true

	# Two-handed: both hands grip the shaft, adjacent to each other.
	var larm = pivots.get("larm_node") as Node2D
	var rarm = pivots.get("rarm_node") as Node2D
	if larm:
		larm.position = _front()
		larm.rotation = 0.0
	if rarm:
		rarm.position = _back()
		rarm.rotation = 0.0


func get_hold_positions() -> Dictionary:
	## Two-handed grip: hands adjacent on the shaft, both damped while moving so
	## the staff is carried steadily rather than swung around.
	return {
		"base_larm": _front(),
		"base_rarm": _back(),
		"larm_rot": 0.0,
		"rarm_rot": 0.0,
		"larm_swing_mul": _sswing(),
		"rarm_swing_mul": _sswing(),
	}


func get_attack_animations(pivots: Dictionary) -> Dictionary:
	var base_torso: Vector2 = pivots.get("base_torso", Vector2(0, 0.5))
	var base_lleg: Vector2 = pivots.get("base_lleg", Vector2(-1, 4))
	var base_rleg: Vector2 = pivots.get("base_rleg", Vector2(0, 4))
	var f := _front()
	var b := _back()

	return {
		"staff_attack_right": _make_staff_sweep(f, b, base_torso, base_lleg, base_rleg),
		"staff_attack_left":  _make_staff_jab(f, b, base_torso, base_lleg, base_rleg),
	}


# ─── Staff Sweep (wide horizontal arc) ──────────────────────────────────────

func _make_staff_sweep(f: Vector2, b: Vector2, base_torso: Vector2, base_lleg: Vector2, base_rleg: Vector2) -> Animation:
	var a = Animation.new()
	a.length = 0.45
	a.step = 0.05

	# Wind up → sweep across → recover
	anim_rot(a, "TorsoPivot", [[0, 0.0], [0.1, -0.15], [0.25, 0.2], [0.35, 0.1], [0.45, 0.0]])

	# Both hands swing together (staff is two-handed), keeping their spacing
	anim_rot(a, "LeftArmPivot", [[0, 0.0], [0.1, -0.5], [0.25, 1.2], [0.35, 0.8], [0.45, 0.0]])
	anim_pos(a, "LeftArmPivot", [
		[0.0, f],
		[0.1, f + Vector2(-2, -3)],
		[0.25, f + Vector2(4, 2)],
		[0.35, f + Vector2(2, 1)],
		[0.45, f],
	])

	anim_rot(a, "RightArmPivot", [[0, 0.0], [0.1, -0.4], [0.25, 1.0], [0.35, 0.6], [0.45, 0.0]])
	anim_pos(a, "RightArmPivot", [
		[0.0, b],
		[0.1, b + Vector2(-2, -3)],
		[0.25, b + Vector2(4, 2)],
		[0.35, b + Vector2(2, 1)],
		[0.45, b],
	])

	# Legs stay planted
	anim_rot(a, "LeftLegPivot",  [[0.0, 0.0], [0.45, 0.0]])
	anim_rot(a, "RightLegPivot", [[0.0, 0.0], [0.45, 0.0]])
	anim_pos(a, "LeftLegPivot",  [[0.0, base_lleg], [0.45, base_lleg]])
	anim_pos(a, "RightLegPivot", [[0.0, base_rleg], [0.45, base_rleg]])

	# Hitbox
	anim_method(a, ".", 0.10, "_enable_hitbox")
	anim_method(a, ".", 0.12, "_spawn_swing_arc")
	anim_method(a, ".", 0.30, "_disable_hitbox")

	return a


# ─── Staff Jab (quick forward thrust) ───────────────────────────────────────

func _make_staff_jab(f: Vector2, b: Vector2, base_torso: Vector2, base_lleg: Vector2, base_rleg: Vector2) -> Animation:
	var a = Animation.new()
	a.length = 0.35
	a.step = 0.05

	# Quick forward jab
	anim_rot(a, "TorsoPivot", [[0, 0.0], [0.08, 0.1], [0.2, -0.05], [0.35, 0.0]])

	# Both hands thrust forward together, keeping their spacing
	anim_pos(a, "LeftArmPivot", [
		[0.0, f],
		[0.08, f + Vector2(6, -1)],
		[0.2, f + Vector2(2, 0)],
		[0.35, f],
	])
	anim_rot(a, "LeftArmPivot", [[0, 0.0], [0.08, -0.3], [0.2, -0.1], [0.35, 0.0]])

	anim_pos(a, "RightArmPivot", [
		[0.0, b],
		[0.08, b + Vector2(6, -1)],
		[0.2, b + Vector2(2, 0)],
		[0.35, b],
	])
	anim_rot(a, "RightArmPivot", [[0, 0.0], [0.08, -0.2], [0.2, -0.05], [0.35, 0.0]])

	# Legs stay planted
	anim_rot(a, "LeftLegPivot",  [[0.0, 0.0], [0.35, 0.0]])
	anim_rot(a, "RightLegPivot", [[0.0, 0.0], [0.35, 0.0]])
	anim_pos(a, "LeftLegPivot",  [[0.0, base_lleg], [0.35, base_lleg]])
	anim_pos(a, "RightLegPivot", [[0.0, base_rleg], [0.35, base_rleg]])

	# Hitbox
	anim_method(a, ".", 0.05, "_enable_hitbox")
	anim_method(a, ".", 0.07, "_spawn_swing_arc")
	anim_method(a, ".", 0.18, "_disable_hitbox")

	return a
