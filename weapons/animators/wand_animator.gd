extends WeaponAnimator
class_name WandAnimator
## Healer wand: one-handed. Quick flick melee pokes plus a "wand_heal"
## channel pose used by the charged heal (the HP/mana logic lives in
## playercontroller._perform_heal). Wand texture is code-generated.


func setup_visual(weapon_sprite: Sprite2D, weapon_data: WeaponData, pivots: Dictionary) -> void:
	if not weapon_sprite:
		return
	var tex: Texture2D = weapon_data.weapon_icon
	if tex == null:
		tex = _make_wand_texture()
	weapon_sprite.texture = tex
	weapon_sprite.scale = Vector2(1, 1)
	weapon_sprite.offset = Vector2.ZERO
	weapon_sprite.position = Vector2(2, 2)
	weapon_sprite.rotation = deg_to_rad(-35)
	weapon_sprite.z_index = 4
	weapon_sprite.visible = true

	# One-handed: wand hand forward, off-hand relaxed
	var larm := pivots.get("larm_node") as Node2D
	var rarm := pivots.get("rarm_node") as Node2D
	if larm:
		larm.position = Vector2(6, -5)
		larm.rotation = -0.1
	if rarm:
		rarm.position = Vector2(-6, -4.5)
		rarm.rotation = 0.0


func get_hold_positions() -> Dictionary:
	return {
		"base_larm": Vector2(6, -5),
		"base_rarm": Vector2(-6, -4.5),
		"larm_rot": -0.1,
		"rarm_rot": 0.0,
	}


func get_attack_animations(pivots: Dictionary) -> Dictionary:
	return {
		"wand_flick_r": _make_flick(pivots, false),
		"wand_flick_l": _make_flick(pivots, true),
		"wand_heal": _make_heal_channel(pivots),
	}


func _make_flick(pivots: Dictionary, alt: bool) -> Animation:
	var base_torso: Vector2 = pivots.get("base_torso", Vector2(0, 0.5))
	var base_head: Vector2 = pivots.get("base_head", Vector2(0, -5.5))
	var base_lleg: Vector2 = pivots.get("base_lleg", Vector2(-1, 4))
	var base_rleg: Vector2 = pivots.get("base_rleg", Vector2(0, 4))
	var g_larm := Vector2(6, -5)
	var g_rarm := Vector2(-6, -4.5)

	var a := Animation.new()
	a.length = 0.3
	a.step = 0.05
	var flick_rot := -0.7 if not alt else -1.1

	# Wand hand snaps forward/up
	anim_pos(a, "LeftArmPivot", [
		[0.0, g_larm],
		[0.08, g_larm + Vector2(7, -3 if alt else -1)],
		[0.2, g_larm + Vector2(3, -1)],
		[0.3, g_larm],
	])
	anim_rot(a, "LeftArmPivot", [
		[0.0, -0.1],
		[0.08, flick_rot],
		[0.2, -0.3],
		[0.3, -0.1],
	])
	anim_rot(a, "LeftArmPivot/WeaponSprite", [
		[0.0, deg_to_rad(-35)],
		[0.08, deg_to_rad(-95 if alt else -70)],
		[0.3, deg_to_rad(-35)],
	])

	# Off-hand braces
	anim_pos(a, "RightArmPivot", [[0.0, g_rarm], [0.1, g_rarm + Vector2(-1, 0)], [0.3, g_rarm]])
	anim_rot(a, "RightArmPivot", [[0.0, 0.0], [0.3, 0.0]])

	anim_pos(a, "TorsoPivot", [
		[0.0, base_torso],
		[0.08, base_torso + Vector2(2, -0.5)],
		[0.3, base_torso],
	])
	anim_rot(a, "TorsoPivot", [[0.0, 0.0], [0.08, 0.06], [0.3, 0.0]])
	anim_pos(a, "HeadPivot", [[0.0, base_head], [0.08, base_head + Vector2(1.5, 0)], [0.3, base_head]])
	anim_pos(a, "LeftLegPivot",  [[0.0, base_lleg], [0.3, base_lleg]])
	anim_pos(a, "RightLegPivot", [[0.0, base_rleg], [0.3, base_rleg]])
	anim_rot(a, "LeftLegPivot",  [[0.0, 0.0], [0.3, 0.0]])
	anim_rot(a, "RightLegPivot", [[0.0, 0.0], [0.3, 0.0]])

	# Short poke hitbox + arc
	anim_method(a, ".", 0.06, "_enable_hitbox")
	anim_method(a, ".", 0.08, "_spawn_swing_arc")
	anim_method(a, ".", 0.16, "_disable_hitbox")

	return a


func _make_heal_channel(pivots: Dictionary) -> Animation:
	var base_torso: Vector2 = pivots.get("base_torso", Vector2(0, 0.5))
	var base_head: Vector2 = pivots.get("base_head", Vector2(0, -5.5))
	var base_lleg: Vector2 = pivots.get("base_lleg", Vector2(-1, 4))
	var base_rleg: Vector2 = pivots.get("base_rleg", Vector2(0, 4))
	var g_larm := Vector2(6, -5)
	var g_rarm := Vector2(-6, -4.5)

	var a := Animation.new()
	a.length = 0.8
	a.step = 0.05

	# Raise the wand overhead and hold the channel
	anim_pos(a, "LeftArmPivot", [
		[0.0, g_larm],
		[0.2, g_larm + Vector2(1, -7)],
		[0.6, g_larm + Vector2(1, -7)],
		[0.8, g_larm],
	])
	anim_rot(a, "LeftArmPivot", [
		[0.0, -0.1],
		[0.2, -1.6],
		[0.6, -1.6],
		[0.8, -0.1],
	])
	anim_rot(a, "LeftArmPivot/WeaponSprite", [
		[0.0, deg_to_rad(-35)],
		[0.2, deg_to_rad(0)],
		[0.6, deg_to_rad(0)],
		[0.8, deg_to_rad(-35)],
	])

	# Off-hand over the heart
	anim_pos(a, "RightArmPivot", [
		[0.0, g_rarm],
		[0.2, g_rarm + Vector2(4, -2)],
		[0.6, g_rarm + Vector2(4, -2)],
		[0.8, g_rarm],
	])
	anim_rot(a, "RightArmPivot", [[0.0, 0.0], [0.2, -0.5], [0.6, -0.5], [0.8, 0.0]])

	# Gentle rise of the whole body
	anim_pos(a, "TorsoPivot", [
		[0.0, base_torso],
		[0.4, base_torso + Vector2(0, -1.5)],
		[0.8, base_torso],
	])
	anim_rot(a, "TorsoPivot", [[0.0, 0.0], [0.8, 0.0]])
	anim_pos(a, "HeadPivot", [
		[0.0, base_head],
		[0.4, base_head + Vector2(0, -1.5)],
		[0.8, base_head],
	])
	anim_pos(a, "LeftLegPivot",  [[0.0, base_lleg], [0.8, base_lleg]])
	anim_pos(a, "RightLegPivot", [[0.0, base_rleg], [0.8, base_rleg]])
	anim_rot(a, "LeftLegPivot",  [[0.0, 0.0], [0.8, 0.0]])
	anim_rot(a, "RightLegPivot", [[0.0, 0.0], [0.8, 0.0]])

	return a


static func _make_wand_texture() -> Texture2D:
	## Code-drawn 16x16 wand: short stick with a glowing tip.
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var wood := Color(0.45, 0.3, 0.18, 1.0)
	# Diagonal shaft from (3,13) to (11,4)
	for i in range(10):
		var t := float(i) / 9.0
		var x := int(round(lerpf(3.0, 11.0, t)))
		var y := int(round(lerpf(13.0, 4.0, t)))
		img.set_pixel(x, y, wood)
		if x + 1 < 16:
			img.set_pixel(x + 1, y, wood)
	# Glowing tip
	var glow := Color(0.5, 1.0, 0.7, 1.0)
	var glow_soft := Color(0.5, 1.0, 0.7, 0.45)
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var px := 12 + dx
			var py := 3 + dy
			if px >= 0 and px < 16 and py >= 0 and py < 16:
				img.set_pixel(px, py, glow if (dx == 0 or dy == 0) else glow_soft)
	return ImageTexture.create_from_image(img)
