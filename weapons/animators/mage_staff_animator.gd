extends StaffAnimator
class_name MageStaffAnimator
## Mage staff: inherits the staff's melee sweep/jab and adds the missing
## "staff_charged" cast animation used when the charged laser fires.
## The beam itself is hitscan code in playercontroller (_fire_laser) —
## this animation is the body language: plant, thrust staff, recoil.


func setup_visual(weapon_sprite: Sprite2D, weapon_data: WeaponData, pivots: Dictionary) -> void:
	super.setup_visual(weapon_sprite, weapon_data, pivots)
	# The beam conduit reads as arcane: cool white-blue tint on the compact staff.
	if weapon_sprite:
		weapon_sprite.modulate = Color(0.7, 0.9, 1.15, 1.0)


func get_attack_animations(pivots: Dictionary) -> Dictionary:
	var anims := super.get_attack_animations(pivots)
	anims["staff_charged"] = _make_cast(pivots)
	anims["staff_aim"] = _make_aim_pose(pivots)
	return anims


func _make_aim_pose(pivots: Dictionary) -> Animation:
	## Battle stance while charging the laser: staff leveled forward like a
	## rifle, lead hand extended down the shaft, rear hand braced at the chest,
	## slight crouch. Loops with a subtle breathing sway.
	var base_torso: Vector2 = pivots.get("base_torso", Vector2(0, 0.5))
	var base_head: Vector2 = pivots.get("base_head", Vector2(0, -5.5))
	var base_lleg: Vector2 = pivots.get("base_lleg", Vector2(-1, 4))
	var base_rleg: Vector2 = pivots.get("base_rleg", Vector2(0, 4))

	var a := Animation.new()
	a.length = 1.0
	a.loop_mode = Animation.LOOP_LINEAR

	# Lead (weapon) hand thrust forward along the aim line
	anim_pos(a, "LeftArmPivot", [
		[0.0, Vector2(9, -4)],
		[0.5, Vector2(9, -3.6)],
		[1.0, Vector2(9, -4)],
	])
	anim_rot(a, "LeftArmPivot", [[0.0, -0.15], [1.0, -0.15]])

	# Rear hand braced at the chest, steadying the shaft
	anim_pos(a, "RightArmPivot", [
		[0.0, Vector2(2, -3)],
		[0.5, Vector2(2, -2.6)],
		[1.0, Vector2(2, -3)],
	])
	anim_rot(a, "RightArmPivot", [[0.0, -0.35], [1.0, -0.35]])

	# Staff leveled horizontal, muzzle forward (gun stance)
	anim_rot(a, "LeftArmPivot/WeaponSprite", [
		[0.0, deg_to_rad(30)],
		[1.0, deg_to_rad(30)],
	])

	# Body: shoulders squared into the shot, slight crouch, breathing bob
	anim_pos(a, "TorsoPivot", [
		[0.0, base_torso + Vector2(-1, 1)],
		[0.5, base_torso + Vector2(-1, 1.5)],
		[1.0, base_torso + Vector2(-1, 1)],
	])
	anim_rot(a, "TorsoPivot", [[0.0, 0.06], [1.0, 0.06]])
	anim_pos(a, "HeadPivot", [
		[0.0, base_head + Vector2(0.5, 1)],
		[0.5, base_head + Vector2(0.5, 1.5)],
		[1.0, base_head + Vector2(0.5, 1)],
	])

	# Wide braced stance
	anim_rot(a, "LeftLegPivot",  [[0.0, -0.14], [1.0, -0.14]])
	anim_rot(a, "RightLegPivot", [[0.0, 0.14], [1.0, 0.14]])
	anim_pos(a, "LeftLegPivot",  [[0.0, base_lleg + Vector2(-0.5, 0)], [1.0, base_lleg + Vector2(-0.5, 0)]])
	anim_pos(a, "RightLegPivot", [[0.0, base_rleg + Vector2(0.5, 0)], [1.0, base_rleg + Vector2(0.5, 0)]])

	return a


func _make_cast(pivots: Dictionary) -> Animation:
	var base_torso: Vector2 = pivots.get("base_torso", Vector2(0, 0.5))
	var base_head: Vector2 = pivots.get("base_head", Vector2(0, -5.5))
	var base_lleg: Vector2 = pivots.get("base_lleg", Vector2(-1, 4))
	var base_rleg: Vector2 = pivots.get("base_rleg", Vector2(0, 4))
	# Two-handed staff grip (read from the weapon so recoil settles to the hold)
	var g_larm := _front()
	var g_rarm := _back()

	var a := Animation.new()
	a.length = 0.45
	a.step = 0.05

	# Thrust the staff forward on fire (0.0 is the moment the beam spawns),
	# hold against the recoil, then settle.
	anim_pos(a, "LeftArmPivot", [
		[0.0, g_larm + Vector2(7, -3)],
		[0.18, g_larm + Vector2(5, -2)],
		[0.45, g_larm],
	])
	anim_rot(a, "LeftArmPivot", [[0.0, -0.5], [0.2, -0.35], [0.45, 0.0]])
	anim_pos(a, "RightArmPivot", [
		[0.0, g_rarm + Vector2(6, -2)],
		[0.18, g_rarm + Vector2(4, -1)],
		[0.45, g_rarm],
	])
	anim_rot(a, "RightArmPivot", [[0.0, -0.4], [0.2, -0.3], [0.45, 0.0]])

	# Staff levels out toward the aim
	anim_rot(a, "LeftArmPivot/WeaponSprite", [
		[0.0, deg_to_rad(30)],
		[0.25, deg_to_rad(-20)],
		[0.45, 0.0],
	])

	# Body: braced back against the recoil
	anim_pos(a, "TorsoPivot", [
		[0.0, base_torso + Vector2(-3, 0.5)],
		[0.2, base_torso + Vector2(-1.5, 0)],
		[0.45, base_torso],
	])
	anim_rot(a, "TorsoPivot", [[0.0, -0.12], [0.2, -0.06], [0.45, 0.0]])
	anim_pos(a, "HeadPivot", [
		[0.0, base_head + Vector2(-2, 0.5)],
		[0.45, base_head],
	])

	# Wide stance
	anim_rot(a, "LeftLegPivot",  [[0.0, -0.15], [0.3, -0.08], [0.45, 0.0]])
	anim_rot(a, "RightLegPivot", [[0.0, 0.15], [0.3, 0.08], [0.45, 0.0]])
	anim_pos(a, "LeftLegPivot",  [[0.0, base_lleg], [0.45, base_lleg]])
	anim_pos(a, "RightLegPivot", [[0.0, base_rleg], [0.45, base_rleg]])

	return a
