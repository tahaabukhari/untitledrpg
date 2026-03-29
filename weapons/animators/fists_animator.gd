extends WeaponAnimator
class_name FistsAnimator
## Animation provider for bare fists (default weapon).
## Contains: attack_right, attack_left, uppercut.


func setup_visual(_weapon_sprite: Sprite2D, _weapon_data: WeaponData, pivots: Dictionary) -> void:
	# Fists don't show a weapon sprite
	if _weapon_sprite:
		_weapon_sprite.visible = false
	# Reset hands to default positions
	var larm = pivots.get("larm_node") as Node2D
	var rarm = pivots.get("rarm_node") as Node2D
	if larm:
		larm.position = pivots.get("base_larm", Vector2(6, -4.5))
	if rarm:
		rarm.position = pivots.get("base_rarm", Vector2(-6, -4.5))


func get_attack_animations(pivots: Dictionary) -> Dictionary:
	var base_torso: Vector2 = pivots.get("base_torso", Vector2(0, 0.5))
	var base_head: Vector2  = pivots.get("base_head", Vector2(0, -5.5))
	var base_larm: Vector2  = pivots.get("base_larm", Vector2(6, -4.5))
	var base_rarm: Vector2  = pivots.get("base_rarm", Vector2(-6, -4.5))
	var base_lleg: Vector2  = pivots.get("base_lleg", Vector2(-1, 4))
	var base_rleg: Vector2  = pivots.get("base_rleg", Vector2(0, 4))
	
	return {
		"attack_right": _make_attack_right(base_torso, base_head, base_larm, base_rarm, base_lleg, base_rleg),
		"attack_left":  _make_attack_left(base_torso, base_head, base_larm, base_rarm, base_lleg, base_rleg),
		"uppercut":     _make_uppercut(base_torso, base_head, base_larm, base_rarm, base_lleg, base_rleg),
	}


# ─── ATTACK RIGHT: Single right fist punch ─────────────────────────────────

func _make_attack_right(base_torso: Vector2, base_head: Vector2, base_larm: Vector2, base_rarm: Vector2, base_lleg: Vector2, base_rleg: Vector2) -> Animation:
	var a = Animation.new()
	a.length = 0.2
	a.loop_mode = Animation.LOOP_NONE

	# Right arm: punch forward 8px then snap back
	anim_pos(a, "RightArmPivot", [
		[0.0,   base_rarm],
		[0.05,  base_rarm + Vector2(8, -1)],
		[0.12,  base_rarm + Vector2(2, 0)],
		[0.17,  base_rarm],
	])
	anim_rot(a, "RightArmPivot", [
		[0.0,   0.0],
		[0.03, -0.2],
		[0.08, -0.15],
		[0.17,  0.0],
	])

	# Left arm: stays at rest
	anim_pos(a, "LeftArmPivot", [[0.0, base_larm], [0.2, base_larm]])
	anim_rot(a, "LeftArmPivot", [[0.0, 0.0], [0.2, 0.0]])

	# Torso: lunge forward (4px)
	anim_pos(a, "TorsoPivot", [
		[0.0,   base_torso],
		[0.05,  base_torso + Vector2(4, -0.5)],
		[0.12,  base_torso + Vector2(1, 0)],
		[0.17,  base_torso],
		[0.2,   base_torso],
	])
	anim_rot(a, "TorsoPivot", [
		[0.0,  0.0],
		[0.05, 0.06],
		[0.17, 0.0],
		[0.2,  0.0],
	])

	# Head: follows body (3px)
	anim_pos(a, "HeadPivot", [
		[0.0,   base_head],
		[0.05,  base_head + Vector2(3, -0.5)],
		[0.12,  base_head + Vector2(0.5, 0)],
		[0.17,  base_head],
		[0.2,   base_head],
	])

	# Legs: stay at rest
	anim_rot(a, "LeftLegPivot",  [[0.0, 0.0], [0.2, 0.0]])
	anim_rot(a, "RightLegPivot", [[0.0, 0.0], [0.2, 0.0]])
	anim_pos(a, "LeftLegPivot",  [[0.0, base_lleg], [0.2, base_lleg]])
	anim_pos(a, "RightLegPivot", [[0.0, base_rleg], [0.2, base_rleg]])

	# Hitbox + swing particle
	anim_method(a, ".", 0.03, "_enable_hitbox")
	anim_method(a, ".", 0.05, "_spawn_swing_arc")
	anim_method(a, ".", 0.13, "_disable_hitbox")

	return a


# ─── ATTACK LEFT: Single left fist punch ──────────────────────────────────

func _make_attack_left(base_torso: Vector2, base_head: Vector2, base_larm: Vector2, base_rarm: Vector2, base_lleg: Vector2, base_rleg: Vector2) -> Animation:
	var a = Animation.new()
	a.length = 0.2
	a.loop_mode = Animation.LOOP_NONE

	# Left arm: punch forward 8px then snap back
	anim_pos(a, "LeftArmPivot", [
		[0.0,   base_larm],
		[0.05,  base_larm + Vector2(8, -1)],
		[0.12,  base_larm + Vector2(2, 0)],
		[0.17,  base_larm],
	])
	anim_rot(a, "LeftArmPivot", [
		[0.0,   0.0],
		[0.03, -0.2],
		[0.08, -0.15],
		[0.17,  0.0],
	])

	# Right arm: stays at rest
	anim_pos(a, "RightArmPivot", [[0.0, base_rarm], [0.2, base_rarm]])
	anim_rot(a, "RightArmPivot", [[0.0, 0.0], [0.2, 0.0]])

	# Torso: lunge forward (4px)
	anim_pos(a, "TorsoPivot", [
		[0.0,   base_torso],
		[0.05,  base_torso + Vector2(4, -0.5)],
		[0.12,  base_torso + Vector2(1, 0)],
		[0.17,  base_torso],
		[0.2,   base_torso],
	])
	anim_rot(a, "TorsoPivot", [
		[0.0,  0.0],
		[0.05, 0.06],
		[0.17, 0.0],
		[0.2,  0.0],
	])

	# Head: follows body (3px)
	anim_pos(a, "HeadPivot", [
		[0.0,   base_head],
		[0.05,  base_head + Vector2(3, -0.5)],
		[0.12,  base_head + Vector2(0.5, 0)],
		[0.17,  base_head],
		[0.2,   base_head],
	])

	# Legs: stay at rest
	anim_rot(a, "LeftLegPivot",  [[0.0, 0.0], [0.2, 0.0]])
	anim_rot(a, "RightLegPivot", [[0.0, 0.0], [0.2, 0.0]])
	anim_pos(a, "LeftLegPivot",  [[0.0, base_lleg], [0.2, base_lleg]])
	anim_pos(a, "RightLegPivot", [[0.0, base_rleg], [0.2, base_rleg]])

	# Hitbox + swing particle
	anim_method(a, ".", 0.03, "_enable_hitbox")
	anim_method(a, ".", 0.05, "_spawn_swing_arc")
	anim_method(a, ".", 0.13, "_disable_hitbox")

	return a


# ─── UPPERCUT: Charged sweeping upward punch ─────────────────────────────────

func _make_uppercut(base_torso: Vector2, base_head: Vector2, base_larm: Vector2, base_rarm: Vector2, base_lleg: Vector2, base_rleg: Vector2) -> Animation:
	var a = Animation.new()
	a.length = 0.35
	a.loop_mode = Animation.LOOP_NONE

	# Right arm: start low, sweep upward 18px (wide x-reach)
	anim_pos(a, "RightArmPivot", [
		[0.0,   base_rarm + Vector2(0, 6)],
		[0.08,  base_rarm + Vector2(7, 3)],
		[0.16,  base_rarm + Vector2(11, -10)],
		[0.22,  base_rarm + Vector2(7, -18)],
		[0.3,   base_rarm + Vector2(0, -6)],
		[0.35,  base_rarm],
	])
	anim_rot(a, "RightArmPivot", [
		[0.0,   0.3],
		[0.08,  0.1],
		[0.16, -0.3],
		[0.22, -0.4],
		[0.3,  -0.1],
		[0.35,  0.0],
	])

	# Left arm: brace slightly
	anim_pos(a, "LeftArmPivot", [
		[0.0,   base_larm],
		[0.1,   base_larm + Vector2(-1.4, 1)],
		[0.25,  base_larm + Vector2(-1.4, 0)],
		[0.35,  base_larm],
	])
	anim_rot(a, "LeftArmPivot", [
		[0.0,  0.0],
		[0.1,  0.15],
		[0.25, 0.1],
		[0.35, 0.0],
	])

	# Torso: crouch then lift upward (3px)
	anim_pos(a, "TorsoPivot", [
		[0.0,   base_torso + Vector2(0, 2)],
		[0.08,  base_torso + Vector2(1.4, 1)],
		[0.16,  base_torso + Vector2(2.8, -2)],
		[0.22,  base_torso + Vector2(1.4, -3)],
		[0.3,   base_torso + Vector2(0, -1)],
		[0.35,  base_torso],
	])
	anim_rot(a, "TorsoPivot", [
		[0.0,  -0.05],
		[0.08, -0.02],
		[0.16,  0.08],
		[0.22,  0.06],
		[0.3,   0.02],
		[0.35,  0.0],
	])

	# Head: follow torso arc
	anim_pos(a, "HeadPivot", [
		[0.0,   base_head + Vector2(0, 2)],
		[0.08,  base_head + Vector2(0.7, 1)],
		[0.16,  base_head + Vector2(2.1, -3)],
		[0.22,  base_head + Vector2(1.4, -4)],
		[0.3,   base_head + Vector2(0, -1)],
		[0.35,  base_head],
	])

	# Legs: slight crouch then push up
	anim_rot(a, "LeftLegPivot", [
		[0.0,  0.08],
		[0.1,  0.04],
		[0.2,  -0.04],
		[0.35, 0.0],
	])
	anim_rot(a, "RightLegPivot", [
		[0.0,  0.08],
		[0.1,  0.04],
		[0.2,  -0.04],
		[0.35, 0.0],
	])
	anim_pos(a, "LeftLegPivot",  [[0.0, base_lleg], [0.35, base_lleg]])
	anim_pos(a, "RightLegPivot", [[0.0, base_rleg], [0.35, base_rleg]])

	# Hitbox + big swing arc
	anim_method(a, ".", 0.06, "_enable_hitbox")
	anim_method(a, ".", 0.10, "_spawn_swing_arc")
	anim_method(a, ".", 0.14, "_spawn_swing_arc")
	anim_method(a, ".", 0.24, "_disable_hitbox")

	return a
