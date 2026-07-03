extends WeaponAnimator
class_name ProjectileWeaponAnimator
## Animation provider for the ranger's bow. The draw-and-loose animation
## fires a real projectile via a "_fire_projectile" method track (handled by
## player_animator → playercontroller.fire_projectile()).
## The bow texture is generated in code when the WeaponData has no icon.


func setup_visual(weapon_sprite: Sprite2D, weapon_data: WeaponData, pivots: Dictionary) -> void:
	if not weapon_sprite:
		return
	var tex: Texture2D = weapon_data.weapon_icon
	if tex == null:
		tex = _make_bow_texture()
	weapon_sprite.texture = tex
	weapon_sprite.scale = Vector2(1, 1)
	weapon_sprite.offset = Vector2.ZERO
	weapon_sprite.position = Vector2(6, 9)
	weapon_sprite.rotation = 0.0
	weapon_sprite.z_index = 3
	weapon_sprite.visible = true

	# Bow arm forward, draw arm back near the cheek
	var larm := pivots.get("larm_node") as Node2D
	var rarm := pivots.get("rarm_node") as Node2D
	if larm:
		larm.position = Vector2(7, -5)
		larm.rotation = 0.0
	if rarm:
		rarm.position = Vector2(-2, -5)
		rarm.rotation = 0.0


func get_hold_positions() -> Dictionary:
	return {
		"base_larm": Vector2(7, -5),
		"base_rarm": Vector2(-2, -5),
		"larm_rot": 0.0,
		"rarm_rot": 0.0,
	}


func get_attack_animations(pivots: Dictionary) -> Dictionary:
	return {
		"bow_shot": _make_bow_shot(pivots, false),
		"bow_shot_charged": _make_bow_shot(pivots, true),
	}


func _make_bow_shot(pivots: Dictionary, charged: bool) -> Animation:
	var base_torso: Vector2 = pivots.get("base_torso", Vector2(0, 0.5))
	var base_head: Vector2 = pivots.get("base_head", Vector2(0, -5.5))
	var base_lleg: Vector2 = pivots.get("base_lleg", Vector2(-1, 4))
	var base_rleg: Vector2 = pivots.get("base_rleg", Vector2(0, 4))
	var g_larm := Vector2(7, -5)
	var g_rarm := Vector2(-2, -5)

	var a := Animation.new()
	a.length = 0.5 if charged else 0.35
	a.step = 0.05
	var t_draw: float = a.length * 0.45   # fully drawn
	var t_loose: float = a.length * 0.55  # arrow flies

	# Bow arm holds steady, pushes slightly forward on release
	anim_pos(a, "LeftArmPivot", [
		[0.0, g_larm],
		[t_draw, g_larm + Vector2(1, 0)],
		[t_loose, g_larm + Vector2(2.5, -0.5)],
		[a.length, g_larm],
	])
	anim_rot(a, "LeftArmPivot", [[0.0, 0.0], [a.length, 0.0]])

	# Draw arm pulls back to the cheek then snaps forward
	anim_pos(a, "RightArmPivot", [
		[0.0, g_rarm],
		[t_draw, g_rarm + Vector2(-5, -1)],
		[t_loose, g_rarm + Vector2(3, 0)],
		[a.length, g_rarm],
	])
	anim_rot(a, "RightArmPivot", [
		[0.0, 0.0],
		[t_draw, 0.25],
		[t_loose, -0.15],
		[a.length, 0.0],
	])

	# Slight lean into the shot
	anim_pos(a, "TorsoPivot", [
		[0.0, base_torso],
		[t_draw, base_torso + Vector2(-1.5, 0)],
		[t_loose, base_torso + Vector2(1.5, 0)],
		[a.length, base_torso],
	])
	anim_rot(a, "TorsoPivot", [[0.0, 0.0], [t_draw, -0.05], [t_loose, 0.06], [a.length, 0.0]])
	anim_pos(a, "HeadPivot", [
		[0.0, base_head],
		[t_draw, base_head + Vector2(-1, 0)],
		[a.length, base_head],
	])
	anim_pos(a, "LeftLegPivot",  [[0.0, base_lleg], [a.length, base_lleg]])
	anim_pos(a, "RightLegPivot", [[0.0, base_rleg], [a.length, base_rleg]])
	anim_rot(a, "LeftLegPivot",  [[0.0, 0.0], [a.length, 0.0]])
	anim_rot(a, "RightLegPivot", [[0.0, 0.0], [a.length, 0.0]])

	# Bowstring wobble on the sprite
	anim_rot(a, "LeftArmPivot/WeaponSprite", [
		[0.0, 0.0],
		[t_loose, -0.12],
		[a.length, 0.0],
	])

	# Loose the arrow (no melee hitbox at all)
	anim_method(a, ".", t_loose, "_fire_projectile", [charged])

	return a


func make_icon() -> Texture2D:
	## Inventory icon for the icon-less bow (see WeaponData.get_icon).
	return _make_bow_texture()


static func _make_bow_texture() -> Texture2D:
	## Code-drawn 24x24 bow: wooden arc + taut string.
	var img := Image.create(24, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var wood := Color(0.5, 0.33, 0.16, 1.0)
	var wood_hi := Color(0.62, 0.44, 0.24, 1.0)
	var center := Vector2(7.0, 12.0)
	for i in range(61):
		var ang := deg_to_rad(lerpf(-62.0, 62.0, float(i) / 60.0))
		var p := center + Vector2(cos(ang), sin(ang)) * 9.0
		var xi := int(round(p.x))
		var yi := int(round(p.y))
		for off: Vector2i in [Vector2i(0, 0), Vector2i(1, 0)]:
			var px: int = xi + off.x
			var py: int = yi + off.y
			if px >= 0 and px < 24 and py >= 0 and py < 24:
				img.set_pixel(px, py, wood if off.x == 0 else wood_hi)
	# String between arc tips
	var tip_top := center + Vector2(cos(deg_to_rad(-62.0)), sin(deg_to_rad(-62.0))) * 9.0
	var tip_bot := center + Vector2(cos(deg_to_rad(62.0)), sin(deg_to_rad(62.0))) * 9.0
	var string_x := int(round(tip_top.x))
	for y in range(int(round(tip_top.y)), int(round(tip_bot.y)) + 1):
		if string_x >= 0 and string_x < 24 and y >= 0 and y < 24:
			img.set_pixel(string_x, y, Color(0.85, 0.85, 0.8, 0.9))
	return ImageTexture.create_from_image(img)
