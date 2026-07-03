extends WeaponAnimator
class_name PrayerAnimator
## The healer's empty-handed prayer. No weapon sprite at all — the "attack" is
## rubbing both hands together in supplication (with a little head bow), and a
## method track fires `_trigger_prayer_effect` at the climax so the 1-in-7
## lightning roll syncs with the animation.


func setup_visual(weapon_sprite: Sprite2D, _weapon_data: WeaponData, pivots: Dictionary) -> void:
	# Empty hands — hide any weapon sprite entirely
	if weapon_sprite:
		weapon_sprite.visible = false
		weapon_sprite.texture = null
	# Rest pose: hands loosely forward, ready to clasp
	var larm := pivots.get("larm_node") as Node2D
	var rarm := pivots.get("rarm_node") as Node2D
	if larm:
		larm.position = Vector2(5, -4.5)
		larm.rotation = -0.1
	if rarm:
		rarm.position = Vector2(-4, -4.5)
		rarm.rotation = 0.1


func get_hold_positions() -> Dictionary:
	return {
		"base_larm": Vector2(5, -4.5),
		"base_rarm": Vector2(-4, -4.5),
		"larm_rot": -0.1,
		"rarm_rot": 0.1,
	}


func get_attack_animations(pivots: Dictionary) -> Dictionary:
	return {
		"prayer_rub": _make_prayer_rub(pivots),
	}


func _make_prayer_rub(pivots: Dictionary) -> Animation:
	var base_torso: Vector2 = pivots.get("base_torso", Vector2(0, 0.5))
	var base_head: Vector2 = pivots.get("base_head", Vector2(0, -5.5))
	var base_lleg: Vector2 = pivots.get("base_lleg", Vector2(-1, 4))
	var base_rleg: Vector2 = pivots.get("base_rleg", Vector2(0, 4))
	var g_larm := Vector2(5, -4.5)
	var g_rarm := Vector2(-4, -4.5)

	var a := Animation.new()
	a.length = 0.7
	a.step = 0.05

	# Hands meet at the chest, then RUB — three quick opposing slides
	var clasp_l := Vector2(2.5, -3.5)   # left hand at the clasp point
	var clasp_r := Vector2(-0.5, -3.5)  # right hand just beneath/against it
	anim_pos(a, "LeftArmPivot", [
		[0.0, g_larm],
		[0.12, clasp_l],
		[0.2, clasp_l + Vector2(1.2, -0.3)],   # rub forward
		[0.28, clasp_l + Vector2(-1.0, 0.3)],  # rub back
		[0.36, clasp_l + Vector2(1.2, -0.3)],
		[0.44, clasp_l + Vector2(-1.0, 0.3)],
		[0.52, clasp_l + Vector2(0.8, -0.2)],
		[0.6, clasp_l],
		[0.7, g_larm],
	])
	anim_rot(a, "LeftArmPivot", [
		[0.0, -0.1],
		[0.12, -0.45],
		[0.6, -0.45],
		[0.7, -0.1],
	])
	anim_pos(a, "RightArmPivot", [
		[0.0, g_rarm],
		[0.12, clasp_r],
		[0.2, clasp_r + Vector2(-1.2, 0.3)],   # opposite phase = rubbing
		[0.28, clasp_r + Vector2(1.0, -0.3)],
		[0.36, clasp_r + Vector2(-1.2, 0.3)],
		[0.44, clasp_r + Vector2(1.0, -0.3)],
		[0.52, clasp_r + Vector2(-0.8, 0.2)],
		[0.6, clasp_r],
		[0.7, g_rarm],
	])
	anim_rot(a, "RightArmPivot", [
		[0.0, 0.1],
		[0.12, 0.45],
		[0.6, 0.45],
		[0.7, 0.1],
	])

	# Reverent little head bow while the hands work
	anim_pos(a, "HeadPivot", [
		[0.0, base_head],
		[0.16, base_head + Vector2(0.5, 1.2)],
		[0.55, base_head + Vector2(0.5, 1.2)],
		[0.7, base_head],
	])
	anim_pos(a, "TorsoPivot", [
		[0.0, base_torso],
		[0.16, base_torso + Vector2(0, 0.6)],
		[0.55, base_torso + Vector2(0, 0.6)],
		[0.7, base_torso],
	])
	anim_rot(a, "TorsoPivot", [[0.0, 0.0], [0.16, 0.05], [0.55, 0.05], [0.7, 0.0]])

	# Legs planted
	anim_pos(a, "LeftLegPivot",  [[0.0, base_lleg], [0.7, base_lleg]])
	anim_pos(a, "RightLegPivot", [[0.0, base_rleg], [0.7, base_rleg]])
	anim_rot(a, "LeftLegPivot",  [[0.0, 0.0], [0.7, 0.0]])
	anim_rot(a, "RightLegPivot", [[0.0, 0.0], [0.7, 0.0]])

	# The prayer lands (sparkle always; 1/7 answers with lightning)
	anim_method(a, ".", 0.55, "_trigger_prayer_effect")

	return a
