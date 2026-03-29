extends WeaponAnimator
class_name SwordAnimator
## Animation provider for a TWO-HANDED sword.
## Idle: sword held upright at center, both hands gripping the hilt.
## Combo: 3-hit chain (diagonal slash → reverse slash → vertical slam).
## Charged: forward thrust with movement boost.


func setup_visual(weapon_sprite: Sprite2D, weapon_data: WeaponData, pivots: Dictionary) -> void:
	if not weapon_sprite or not weapon_data.weapon_icon:
		return
	
	weapon_sprite.texture = weapon_data.weapon_icon
	weapon_sprite.scale = Vector2(0.5, 0.5)  # Set scale to 0.5
	
	# Pivot from the hilt (bottom of sprite) so rotations swing from the grip
	var tex_h = weapon_data.weapon_icon.get_height()
	weapon_sprite.offset = Vector2(-6, -tex_h / 2.0 + 6)  # +6 pushes hilt further down into hand
	
	# Position relative to LeftArmPivot (at 6, -4.5 in PlayerSkin space).
	# Adjusted to sit inside the hand grip, not float above it.
	weapon_sprite.position = Vector2(-1, 13.5)
	weapon_sprite.rotation = deg_to_rad(40)  # Tilt 40 degrees forward
	
	# Top layer — well above all body parts
	weapon_sprite.z_index = 10
	weapon_sprite.visible = true
	
	# Two-handed grip: move both arms inward to converge on the hilt
	var larm = pivots.get("larm_node") as Node2D
	var rarm = pivots.get("rarm_node") as Node2D
	if larm:
		larm.position = Vector2(2, -5.5)   # Left hand grips upper part of hilt
		larm.rotation = -0.15            # Slight inward tilt
	if rarm:
		rarm.position = Vector2(-2, -4.5)  # Right hand grips lower part of hilt
		rarm.rotation = 0.15             # Slight inward tilt


func get_attack_animations(pivots: Dictionary) -> Dictionary:
	var base_torso: Vector2 = pivots.get("base_torso", Vector2(0, 0.5))
	var base_head: Vector2  = pivots.get("base_head", Vector2(0, -5.5))
	var base_lleg: Vector2  = pivots.get("base_lleg", Vector2(-1, 4))
	var base_rleg: Vector2  = pivots.get("base_rleg", Vector2(0, 4))
	
	# Two-handed grip positions (not the default arm positions)
	var grip_larm := Vector2(2, -5.5)
	var grip_rarm := Vector2(-2, -4.5)
	
	return {
		"sword_combo_1": _make_combo_1(grip_larm, grip_rarm, base_torso, base_head, base_lleg, base_rleg),
		"sword_combo_2": _make_combo_2(grip_larm, grip_rarm, base_torso, base_head, base_lleg, base_rleg),
		"sword_combo_3": _make_combo_3(grip_larm, grip_rarm, base_torso, base_head, base_lleg, base_rleg),
		"sword_charged": _make_charged_thrust(grip_larm, grip_rarm, base_torso, base_head, base_lleg, base_rleg),
	}


func get_hold_positions() -> Dictionary:
	## Two-handed grip: both arms converge on the hilt at center, tilted inward.
	return {
		"base_larm": Vector2(2, -5.5),
		"base_rarm": Vector2(-2, -4.5),
		"larm_rot": -0.15,  # Slight inward tilt for left hand
		"rarm_rot": 0.15,   # Slight inward tilt for right hand
	}


# ─── COMBO 1: Diagonal slash down-right ─────────────────────────────────────

func _make_combo_1(g_larm: Vector2, g_rarm: Vector2, base_torso: Vector2, base_head: Vector2, base_lleg: Vector2, base_rleg: Vector2) -> Animation:
	var a = Animation.new()
	a.length = 0.4
	a.step = 0.05
	
	# Torso leans into the swing
	anim_rot(a, "TorsoPivot", [
		[0.0, 0.0], [0.08, -0.08], [0.18, 0.12], [0.3, 0.06], [0.4, 0.0]
	])
	anim_pos(a, "TorsoPivot", [
		[0.0, base_torso],
		[0.1, base_torso + Vector2(2, -1)],
		[0.3, base_torso + Vector2(1, 0)],
		[0.4, base_torso]
	])
	
	# Head follows torso
	anim_pos(a, "HeadPivot", [
		[0.0, base_head],
		[0.1, base_head + Vector2(1.5, -1)],
		[0.3, base_head + Vector2(0.5, 0)],
		[0.4, base_head]
	])
	
	# Both arms swing together (two-handed) — diagonal slash from upper-left to lower-right
	anim_rot(a, "LeftArmPivot", [
		[0.0, 0.0], [0.08, -0.6], [0.18, 1.4], [0.3, 1.0], [0.4, 0.0]
	])
	anim_pos(a, "LeftArmPivot", [
		[0.0, g_larm],
		[0.08, g_larm + Vector2(-3, -5)],
		[0.18, g_larm + Vector2(6, 4)],
		[0.3, g_larm + Vector2(3, 2)],
		[0.4, g_larm]
	])
	
	anim_rot(a, "RightArmPivot", [
		[0.0, 0.0], [0.08, -0.5], [0.18, 1.2], [0.3, 0.8], [0.4, 0.0]
	])
	anim_pos(a, "RightArmPivot", [
		[0.0, g_rarm],
		[0.08, g_rarm + Vector2(-3, -4)],
		[0.18, g_rarm + Vector2(6, 3)],
		[0.3, g_rarm + Vector2(3, 1)],
		[0.4, g_rarm]
	])
	
	# Sword rotation — swings from raised to slashed down
	anim_rot(a, "LeftArmPivot/WeaponSprite", [
		[0.0, 0.0],
		[0.08, -0.5],
		[0.18, 1.8],
		[0.3, 2.0],
		[0.4, 0.0]
	])
	
	# Legs stay planted
	anim_rot(a, "LeftLegPivot",  [[0.0, 0.0], [0.4, 0.0]])
	anim_rot(a, "RightLegPivot", [[0.0, 0.0], [0.4, 0.0]])
	anim_pos(a, "LeftLegPivot",  [[0.0, base_lleg], [0.4, base_lleg]])
	anim_pos(a, "RightLegPivot", [[0.0, base_rleg], [0.4, base_rleg]])
	
	# Hitbox + slash VFX
	anim_method(a, ".", 0.08, "_enable_hitbox")
	anim_method(a, ".", 0.12, "_spawn_sword_slash_effect", [true])
	anim_method(a, ".", 0.25, "_disable_hitbox")
	
	return a


# ─── COMBO 2: Quick reverse slash up-left ────────────────────────────────────

func _make_combo_2(g_larm: Vector2, g_rarm: Vector2, base_torso: Vector2, base_head: Vector2, base_lleg: Vector2, base_rleg: Vector2) -> Animation:
	var a = Animation.new()
	a.length = 0.35
	a.step = 0.05
	
	# Torso leans the other way — snappier
	anim_rot(a, "TorsoPivot", [
		[0.0, 0.0], [0.06, 0.1], [0.15, -0.1], [0.25, -0.04], [0.35, 0.0]
	])
	anim_pos(a, "TorsoPivot", [
		[0.0, base_torso],
		[0.08, base_torso + Vector2(1, 0)],
		[0.35, base_torso]
	])
	
	# Head follows
	anim_pos(a, "HeadPivot", [
		[0.0, base_head],
		[0.08, base_head + Vector2(0.5, 0)],
		[0.35, base_head]
	])
	
	# Both arms swing reverse — from lower-right to upper-left
	anim_rot(a, "LeftArmPivot", [
		[0.0, 0.0], [0.06, 0.5], [0.15, -1.5], [0.25, -1.2], [0.35, 0.0]
	])
	anim_pos(a, "LeftArmPivot", [
		[0.0, g_larm],
		[0.06, g_larm + Vector2(2, 3)],
		[0.15, g_larm + Vector2(-4, -5)],
		[0.25, g_larm + Vector2(-2, -3)],
		[0.35, g_larm]
	])
	
	anim_rot(a, "RightArmPivot", [
		[0.0, 0.0], [0.06, 0.4], [0.15, -1.3], [0.25, -1.0], [0.35, 0.0]
	])
	anim_pos(a, "RightArmPivot", [
		[0.0, g_rarm],
		[0.06, g_rarm + Vector2(2, 2)],
		[0.15, g_rarm + Vector2(-4, -4)],
		[0.25, g_rarm + Vector2(-2, -2)],
		[0.35, g_rarm]
	])
	
	# Sword rotation — reverse swing
	anim_rot(a, "LeftArmPivot/WeaponSprite", [
		[0.0, 0.0],
		[0.06, 1.8],
		[0.15, -1.0],
		[0.25, -0.7],
		[0.35, 0.0]
	])
	
	# Legs
	anim_rot(a, "LeftLegPivot",  [[0.0, 0.0], [0.35, 0.0]])
	anim_rot(a, "RightLegPivot", [[0.0, 0.0], [0.35, 0.0]])
	anim_pos(a, "LeftLegPivot",  [[0.0, base_lleg], [0.35, base_lleg]])
	anim_pos(a, "RightLegPivot", [[0.0, base_rleg], [0.35, base_rleg]])
	
	# Hitbox + slash VFX
	anim_method(a, ".", 0.06, "_enable_hitbox")
	anim_method(a, ".", 0.10, "_spawn_sword_slash_effect", [false])
	anim_method(a, ".", 0.22, "_disable_hitbox")
	
	return a


# ─── COMBO 3: Heavy vertical slam ────────────────────────────────────────────

func _make_combo_3(g_larm: Vector2, g_rarm: Vector2, base_torso: Vector2, base_head: Vector2, base_lleg: Vector2, base_rleg: Vector2) -> Animation:
	var a = Animation.new()
	a.length = 0.5
	a.step = 0.05
	
	# Torso: crouch slightly, then explosive upward lift, then slam forward
	anim_rot(a, "TorsoPivot", [
		[0.0, 0.0], [0.1, -0.06], [0.2, -0.12], [0.3, 0.18], [0.4, 0.08], [0.5, 0.0]
	])
	anim_pos(a, "TorsoPivot", [
		[0.0, base_torso],
		[0.1, base_torso + Vector2(0, 1)],
		[0.2, base_torso + Vector2(0, -2)],
		[0.3, base_torso + Vector2(3, 2)],
		[0.4, base_torso + Vector2(1, 0)],
		[0.5, base_torso]
	])
	
	# Head follows the arc
	anim_pos(a, "HeadPivot", [
		[0.0, base_head],
		[0.1, base_head + Vector2(0, 1)],
		[0.2, base_head + Vector2(0, -3)],
		[0.3, base_head + Vector2(2, 1)],
		[0.4, base_head + Vector2(0.5, 0)],
		[0.5, base_head]
	])
	
	# Both arms: raise sword high overhead, then slam straight down
	anim_rot(a, "LeftArmPivot", [
		[0.0, 0.0], [0.1, -0.3], [0.2, -1.2], [0.3, 2.0], [0.4, 1.6], [0.5, 0.0]
	])
	anim_pos(a, "LeftArmPivot", [
		[0.0, g_larm],
		[0.1, g_larm + Vector2(-1, -2)],
		[0.2, g_larm + Vector2(-2, -8)],
		[0.3, g_larm + Vector2(5, 6)],
		[0.4, g_larm + Vector2(2, 3)],
		[0.5, g_larm]
	])
	
	anim_rot(a, "RightArmPivot", [
		[0.0, 0.0], [0.1, -0.25], [0.2, -1.0], [0.3, 1.8], [0.4, 1.4], [0.5, 0.0]
	])
	anim_pos(a, "RightArmPivot", [
		[0.0, g_rarm],
		[0.1, g_rarm + Vector2(-1, -2)],
		[0.2, g_rarm + Vector2(-2, -7)],
		[0.3, g_rarm + Vector2(5, 5)],
		[0.4, g_rarm + Vector2(2, 2)],
		[0.5, g_rarm]
	])
	
	# Sword: raise up then slam down with huge arc
	anim_rot(a, "LeftArmPivot/WeaponSprite", [
		[0.0, 0.0],
		[0.1, -0.3],
		[0.2, -1.0],
		[0.3, 2.5],
		[0.4, 2.8],
		[0.5, 0.0]
	])
	
	# Legs: slight crouch on wind-up then push
	anim_rot(a, "LeftLegPivot", [
		[0.0, 0.0], [0.1, 0.06], [0.2, 0.04], [0.3, -0.04], [0.5, 0.0]
	])
	anim_rot(a, "RightLegPivot", [
		[0.0, 0.0], [0.1, 0.06], [0.2, 0.04], [0.3, -0.04], [0.5, 0.0]
	])
	anim_pos(a, "LeftLegPivot",  [[0.0, base_lleg], [0.5, base_lleg]])
	anim_pos(a, "RightLegPivot", [[0.0, base_rleg], [0.5, base_rleg]])
	
	# Hitbox + DOUBLE slash VFX for the heavy slam
	anim_method(a, ".", 0.22, "_enable_hitbox")
	anim_method(a, ".", 0.25, "_spawn_sword_slash_effect", [true])
	anim_method(a, ".", 0.30, "_spawn_sword_slash_effect", [true])
	anim_method(a, ".", 0.40, "_disable_hitbox")
	
	return a


# ─── CHARGED: Forward thrust with movement boost ─────────────────────────────

func _make_charged_thrust(g_larm: Vector2, g_rarm: Vector2, base_torso: Vector2, base_head: Vector2, base_lleg: Vector2, base_rleg: Vector2) -> Animation:
	var a = Animation.new()
	a.length = 0.8
	a.step = 0.05
	
	# ── Phase 1: Windup (0.0–0.3) — pull sword back to waist, tip forward ──
	anim_rot(a, "TorsoPivot", [
		[0.0, 0.0],
		[0.15, -0.1],     # lean back slightly
		[0.3, -0.12],     # tension
		[0.42, 0.15],     # thrust forward
		[0.55, 0.1],
		[0.8, 0.0]
	])
	anim_pos(a, "TorsoPivot", [
		[0.0, base_torso],
		[0.15, base_torso + Vector2(-3, 0)],
		[0.3, base_torso + Vector2(-4, 0)],
		[0.42, base_torso + Vector2(8, -1)],
		[0.55, base_torso + Vector2(4, 0)],
		[0.8, base_torso]
	])
	
	# Head follows torso
	anim_pos(a, "HeadPivot", [
		[0.0, base_head],
		[0.15, base_head + Vector2(-2, 0)],
		[0.3, base_head + Vector2(-3, 0)],
		[0.42, base_head + Vector2(6, -1)],
		[0.55, base_head + Vector2(3, 0)],
		[0.8, base_head]
	])
	
	# Arms: retract for windup, then thrust forward explosively
	anim_rot(a, "LeftArmPivot", [
		[0.0, 0.0],
		[0.15, 0.3],
		[0.3, 0.4],       # arms pulled back
		[0.42, -0.3],     # thrust forward
		[0.55, -0.15],
		[0.8, 0.0]
	])
	anim_pos(a, "LeftArmPivot", [
		[0.0, g_larm],
		[0.15, g_larm + Vector2(-6, 2)],
		[0.3, g_larm + Vector2(-8, 3)],
		[0.42, g_larm + Vector2(12, -2)],
		[0.55, g_larm + Vector2(6, -1)],
		[0.8, g_larm]
	])
	
	anim_rot(a, "RightArmPivot", [
		[0.0, 0.0],
		[0.15, 0.25],
		[0.3, 0.35],
		[0.42, -0.25],
		[0.55, -0.12],
		[0.8, 0.0]
	])
	anim_pos(a, "RightArmPivot", [
		[0.0, g_rarm],
		[0.15, g_rarm + Vector2(-5, 2)],
		[0.3, g_rarm + Vector2(-7, 3)],
		[0.42, g_rarm + Vector2(11, -2)],
		[0.55, g_rarm + Vector2(5, -1)],
		[0.8, g_rarm]
	])
	
	# Sword: rotate to horizontal (pointing forward) during windup, then thrust straight
	anim_rot(a, "LeftArmPivot/WeaponSprite", [
		[0.0, 0.0],
		[0.15, 1.2],       # tilting to horizontal
		[0.3, 1.57],       # perfectly horizontal (PI/2)
		[0.42, 1.57],      # stays horizontal during thrust
		[0.55, 1.2],
		[0.8, 0.0]         # back to upright
	])
	
	# Legs: brace during windup, push off during thrust
	anim_rot(a, "LeftLegPivot", [
		[0.0, 0.0], [0.15, 0.08], [0.3, 0.1], [0.42, -0.06], [0.55, -0.03], [0.8, 0.0]
	])
	anim_rot(a, "RightLegPivot", [
		[0.0, 0.0], [0.15, 0.06], [0.3, 0.08], [0.42, -0.08], [0.55, -0.04], [0.8, 0.0]
	])
	anim_pos(a, "LeftLegPivot", [
		[0.0, base_lleg],
		[0.3, base_lleg + Vector2(-1, 0)],
		[0.42, base_lleg + Vector2(2, 0)],
		[0.8, base_lleg]
	])
	anim_pos(a, "RightLegPivot", [
		[0.0, base_rleg],
		[0.3, base_rleg + Vector2(-1, 0)],
		[0.42, base_rleg + Vector2(2, 0)],
		[0.8, base_rleg]
	])
	
	# Hitbox: active during thrust phase
	anim_method(a, ".", 0.38, "_enable_hitbox")
	anim_method(a, ".", 0.42, "_spawn_sword_slash_effect", [true])
	anim_method(a, ".", 0.55, "_disable_hitbox")
	
	# Movement boost — calls trigger_weapon_dash on the Player (parent of PlayerSkin)
	anim_method(a, ".", 0.40, "_trigger_thrust_dash")
	
	return a
