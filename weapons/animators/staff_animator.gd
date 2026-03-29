extends WeaponAnimator
class_name StaffAnimator
## Animation provider for two-handed staffs.
## Contains: staff_attack_right, staff_attack_left (stubs for now).


func setup_visual(weapon_sprite: Sprite2D, weapon_data: WeaponData, pivots: Dictionary) -> void:
	if not weapon_sprite or not weapon_data.weapon_icon:
		return
	
	weapon_sprite.texture = weapon_data.weapon_icon
	weapon_sprite.scale = Vector2(1, 1)
	weapon_sprite.rotation = deg_to_rad(-60)
	weapon_sprite.position = Vector2(5, 3)
	weapon_sprite.offset = Vector2.ZERO
	weapon_sprite.z_index = -1  # Behind hands
	weapon_sprite.visible = true
	
	# Two-handed grip — reposition both hands
	var larm = pivots.get("larm_node") as Node2D
	var rarm = pivots.get("rarm_node") as Node2D
	if larm:
		larm.position = Vector2(2, -1)    # upper grip
	if rarm:
		rarm.position = Vector2(0, 2)     # lower grip


func get_attack_animations(pivots: Dictionary) -> Dictionary:
	var base_larm: Vector2 = pivots.get("base_larm", Vector2(6, -4.5))
	var base_rarm: Vector2 = pivots.get("base_rarm", Vector2(-6, -4.5))
	var base_torso: Vector2 = pivots.get("base_torso", Vector2(0, 0.5))
	var base_lleg: Vector2 = pivots.get("base_lleg", Vector2(-1, 4))
	var base_rleg: Vector2 = pivots.get("base_rleg", Vector2(0, 4))
	
	return {
		"staff_attack_right": _make_staff_sweep(base_torso, base_larm, base_rarm, base_lleg, base_rleg),
		"staff_attack_left":  _make_staff_jab(base_torso, base_larm, base_rarm, base_lleg, base_rleg),
	}


# ─── Staff Sweep (wide horizontal arc) ──────────────────────────────────────

func _make_staff_sweep(base_torso: Vector2, base_larm: Vector2, base_rarm: Vector2, base_lleg: Vector2, base_rleg: Vector2) -> Animation:
	var a = Animation.new()
	a.length = 0.45
	a.step = 0.05
	
	# Wind up → sweep across → recover
	anim_rot(a, "TorsoPivot", [[0, 0.0], [0.1, -0.15], [0.25, 0.2], [0.35, 0.1], [0.45, 0.0]])
	
	# Both arms swing together (staff is two-handed)
	anim_rot(a, "LeftArmPivot", [[0, 0.0], [0.1, -0.5], [0.25, 1.2], [0.35, 0.8], [0.45, 0.0]])
	anim_pos(a, "LeftArmPivot", [
		[0.0, Vector2(2, -1)],
		[0.1, Vector2(0, -4)],
		[0.25, Vector2(6, 1)],
		[0.35, Vector2(4, 0)],
		[0.45, Vector2(2, -1)]
	])
	
	anim_rot(a, "RightArmPivot", [[0, 0.0], [0.1, -0.4], [0.25, 1.0], [0.35, 0.6], [0.45, 0.0]])
	anim_pos(a, "RightArmPivot", [
		[0.0, Vector2(0, 2)],
		[0.1, Vector2(-2, -1)],
		[0.25, Vector2(4, 4)],
		[0.35, Vector2(2, 3)],
		[0.45, Vector2(0, 2)]
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

func _make_staff_jab(base_torso: Vector2, base_larm: Vector2, base_rarm: Vector2, base_lleg: Vector2, base_rleg: Vector2) -> Animation:
	var a = Animation.new()
	a.length = 0.35
	a.step = 0.05
	
	# Quick forward jab
	anim_rot(a, "TorsoPivot", [[0, 0.0], [0.08, 0.1], [0.2, -0.05], [0.35, 0.0]])
	
	# Both arms thrust forward together
	anim_pos(a, "LeftArmPivot", [
		[0.0, Vector2(2, -1)],
		[0.08, Vector2(8, -2)],
		[0.2, Vector2(4, -1)],
		[0.35, Vector2(2, -1)]
	])
	anim_rot(a, "LeftArmPivot", [[0, 0.0], [0.08, -0.3], [0.2, -0.1], [0.35, 0.0]])
	
	anim_pos(a, "RightArmPivot", [
		[0.0, Vector2(0, 2)],
		[0.08, Vector2(6, 1)],
		[0.2, Vector2(2, 2)],
		[0.35, Vector2(0, 2)]
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
