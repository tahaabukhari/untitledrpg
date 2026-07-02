extends Node2D

## Code-driven puppet animator for the layered player character.
## Attach to the PlayerSkin node. Creates core locomotion animations
## programmatically. Weapon-specific animations are provided by
## WeaponAnimator plugins loaded from weapon_data.animator_script.

@onready var anim_player: AnimationPlayer = $AnimPlayer
var weapon_sprite: Sprite2D

var current_state: String = ""
var has_weapon_equipped := false
var equipped_weapon: WeaponData = null
var _active_animator: WeaponAnimator = null
var _weapon_anim_names: Array = []  # tracks which anims the current weapon registered

# Combo system
var combo_step: int = 0
var combo_reset_timer: float = 0.0
const COMBO_RESET_TIME: float = 0.8  # seconds before combo resets to step 0

signal attack_finished

# ─── Adjustable Pivot Positions (tweak these in the Inspector) ───────────────
@export_group("Upper Body")
@export var base_torso := Vector2(0, 0.5)
@export var base_head  := Vector2(0, -5.5)
@export var base_larm  := Vector2(6, -4.5)
@export var base_rarm  := Vector2(-6, -4.5)

@export_group("Lower Body")
@export var base_lleg  := Vector2(-1, 4)
@export var base_rleg  := Vector2(0, 4)

var base_larm_rot := 0.0
var base_rarm_rot := 0.0

@export_group("Weapon Adjustments")
@export var weapon_pos_offset := Vector2(0, 0)  ## Manual position tweak for weapon sprite
@export var weapon_rot_offset := 0.0             ## Manual rotation tweak (radians)

# Store the original default arm positions (before weapon overrides)
var _default_larm: Vector2
var _default_rarm: Vector2

# Default animator (fists) loaded once at startup
var _fists_animator: WeaponAnimator = null


func _ready() -> void:
	# WeaponSprite lives on LeftArmPivot (defined in player.tscn).
	# For two-handed weapons, we position it via offset to appear centered.
	weapon_sprite = get_node_or_null("LeftArmPivot/WeaponSprite")
	
	# Remember original arm positions so we can restore them on unequip
	_default_larm = base_larm
	_default_rarm = base_rarm
	
	# Load default fists animator
	var fists_script = load("res://weapons/animators/fists_animator.gd")
	if fists_script:
		_fists_animator = fists_script.new()
	
	_build_all_animations()
	play_state("idle")


func _process(delta: float) -> void:
	# Tick down combo reset timer
	if combo_reset_timer > 0.0:
		combo_reset_timer -= delta
		if combo_reset_timer <= 0.0:
			combo_step = 0


func _get_pivots() -> Dictionary:
	## Returns the pivot data dictionary that weapon animators need.
	return {
		"base_torso": base_torso,
		"base_head": base_head,
		"base_larm": base_larm,
		"base_rarm": base_rarm,
		"base_lleg": base_lleg,
		"base_rleg": base_rleg,
		"larm_node": get_node_or_null("LeftArmPivot"),
		"rarm_node": get_node_or_null("RightArmPivot"),
	}


# ─── Weapon Visuals (delegated to weapon animators) ─────────────────────────

func equip_weapon_visual(weapon: WeaponData) -> void:
	has_weapon_equipped = true
	equipped_weapon = weapon
	
	# Remove old weapon animations from the library
	_unregister_weapon_animations()
	
	# Instantiate the weapon-specific animator
	_active_animator = null
	if weapon.animator_script:
		_active_animator = weapon.animator_script.new()
	
	if not _active_animator:
		# Fallback: no animator script → use fists
		_active_animator = _fists_animator
	
	# Apply weapon hold positions (overrides arm positions in locomotion anims)
	var hold = _active_animator.get_hold_positions()
	if hold.size() > 0:
		base_larm = hold.get("base_larm", _default_larm)
		base_rarm = hold.get("base_rarm", _default_rarm)
		base_larm_rot = hold.get("larm_rot", 0.0)
		base_rarm_rot = hold.get("rarm_rot", 0.0)
		_rebuild_locomotion_animations()
	
	# Apply hold arm rotations immediately to the nodes if provided
	var larm_node = get_node_or_null("LeftArmPivot")
	var rarm_node = get_node_or_null("RightArmPivot")
	if hold.has("larm_rot") and larm_node:
		larm_node.rotation = hold["larm_rot"]
	if hold.has("rarm_rot") and rarm_node:
		rarm_node.rotation = hold["rarm_rot"]
	
	var pivots = _get_pivots()
	
	# Let the animator configure the weapon sprite
	_active_animator.setup_visual(weapon_sprite, weapon, pivots)
	
	# Apply manual offset from Inspector so the user can fine-tune placement
	if weapon_sprite:
		weapon_sprite.position += weapon_pos_offset
		weapon_sprite.rotation += weapon_rot_offset
	
	# Register weapon attack animations
	var anims: Dictionary = _active_animator.get_attack_animations(pivots)
	var lib = anim_player.get_animation_library("")
	if lib:
		for anim_name in anims:
			if lib.has_animation(anim_name):
				lib.remove_animation(anim_name)
			lib.add_animation(anim_name, anims[anim_name])
			_weapon_anim_names.append(anim_name)


func unequip_weapon_visual() -> void:
	has_weapon_equipped = false
	equipped_weapon = null
	
	# Teardown current weapon visuals
	if _active_animator:
		_active_animator.teardown_visual(weapon_sprite, _get_pivots())
	
	# Remove weapon-specific animations
	_unregister_weapon_animations()
	
	# Restore default arm positions and rebuild locomotion with them
	base_larm = _default_larm
	base_rarm = _default_rarm
	base_larm_rot = 0.0
	base_rarm_rot = 0.0
	_rebuild_locomotion_animations()
	
	# Restore fist animations as default
	_active_animator = _fists_animator
	if _active_animator:
		var anims = _active_animator.get_attack_animations(_get_pivots())
		var lib = anim_player.get_animation_library("")
		if lib:
			for anim_name in anims:
				if lib.has_animation(anim_name):
					lib.remove_animation(anim_name)
				lib.add_animation(anim_name, anims[anim_name])
				_weapon_anim_names.append(anim_name)
	
	# Reset hands to default position and rotation
	var larm = get_node_or_null("LeftArmPivot")
	var rarm = get_node_or_null("RightArmPivot")
	if larm:
		larm.position = base_larm
		larm.rotation = 0.0
	if rarm:
		rarm.position = base_rarm
		rarm.rotation = 0.0


func _unregister_weapon_animations() -> void:
	var lib = anim_player.get_animation_library("")
	if lib:
		for anim_name in _weapon_anim_names:
			if lib.has_animation(anim_name):
				lib.remove_animation(anim_name)
	_weapon_anim_names.clear()


# ─── Playback ────────────────────────────────────────────────────────────────

func play_state(new_state: String) -> void:
	if new_state == current_state:
		return
	current_state = new_state
	anim_player.play(new_state)


func play_attack() -> void:
	var anim_name: String
	
	# Use combo system if the weapon defines combo_anims
	if equipped_weapon and equipped_weapon.combo_anims.size() > 0:
		var combos = equipped_weapon.combo_anims
		if combo_step >= combos.size():
			combo_step = 0
		anim_name = combos[combo_step]
		combo_step += 1
		if combo_step >= combos.size():
			combo_step = 0  # wrap around
		combo_reset_timer = COMBO_RESET_TIME
	elif equipped_weapon:
		# Legacy fallback: alternate right/left
		var step = combo_step % 2
		anim_name = equipped_weapon.attack_right_anim if step == 0 else equipped_weapon.attack_left_anim
		combo_step += 1
		combo_reset_timer = COMBO_RESET_TIME
	else:
		anim_name = "attack_right" if combo_step % 2 == 0 else "attack_left"
		combo_step += 1
		combo_reset_timer = COMBO_RESET_TIME
	
	current_state = anim_name
	if anim_player.has_animation(anim_name):
		anim_player.play(anim_name)
	else:
		anim_player.play("attack_right") # ultimate fallback
	
	if not anim_player.animation_finished.is_connected(_on_attack_done):
		anim_player.animation_finished.connect(_on_attack_done, CONNECT_ONE_SHOT)


func play_uppercut() -> void:
	var anim_name = "uppercut"
	if equipped_weapon:
		anim_name = equipped_weapon.charged_anim
		
	current_state = anim_name
	if anim_player.has_animation(anim_name):
		anim_player.play(anim_name)
	else:
		anim_player.play("uppercut") # fallback
		
	if not anim_player.animation_finished.is_connected(_on_attack_done):
		anim_player.animation_finished.connect(_on_attack_done, CONNECT_ONE_SHOT)


func _on_attack_done(_anim_name: String) -> void:
	current_state = ""
	attack_finished.emit()


# ─── Animation Library Builder ──────────────────────────────────────────────

func _build_all_animations() -> void:
	var lib = AnimationLibrary.new()
	# Core locomotion (weapon-independent)
	lib.add_animation("idle", _make_idle())
	lib.add_animation("walk", _make_walk())
	lib.add_animation("run",  _make_run())
	lib.add_animation("jump", _make_jump())
	lib.add_animation("fall", _make_fall())
	lib.add_animation("long_fall", _make_long_fall())
	
	# Register default fist animations
	if _fists_animator:
		var anims = _fists_animator.get_attack_animations(_get_pivots())
		for anim_name in anims:
			lib.add_animation(anim_name, anims[anim_name])
			_weapon_anim_names.append(anim_name)
	
	anim_player.add_animation_library("", lib)


func _rebuild_locomotion_animations() -> void:
	## Rebuild only the locomotion animations using the current base_larm/base_rarm.
	## Called when equipping/unequipping weapons that change the arm hold positions.
	var lib = anim_player.get_animation_library("")
	if not lib:
		return
	
	var locomotion_names = ["idle", "walk", "run", "jump", "fall", "long_fall"]
	var locomotion_builders = {
		"idle": _make_idle,
		"walk": _make_walk,
		"run": _make_run,
		"jump": _make_jump,
		"fall": _make_fall,
		"long_fall": _make_long_fall,
	}
	
	for anim_name in locomotion_names:
		if lib.has_animation(anim_name):
			lib.remove_animation(anim_name)
		lib.add_animation(anim_name, locomotion_builders[anim_name].call())


# ─── IDLE: Gentle breathing rhythm ──────────────────────────────────────────

func _make_idle() -> Animation:
	var a = Animation.new()
	a.length = 1.2
	a.loop_mode = Animation.LOOP_LINEAR

	_pos(a, "TorsoPivot", [
		[0.0,  base_torso],
		[0.3,  base_torso + Vector2(0, -0.5)],
		[0.6,  base_torso],
		[0.9,  base_torso + Vector2(0,  0.5)],
		[1.2,  base_torso],
	])

	_pos(a, "HeadPivot", [
		[0.0,   base_head],
		[0.35,  base_head + Vector2(0, -0.5)],
		[0.65,  base_head],
		[0.95,  base_head + Vector2(0,  0.5)],
		[1.2,   base_head],
	])

	_pos(a, "LeftArmPivot", [
		[0.0,  base_larm],
		[0.3,  base_larm + Vector2(0, -0.5)],
		[0.6,  base_larm],
		[0.9,  base_larm + Vector2(0,  0.5)],
		[1.2,  base_larm],
	])

	_pos(a, "RightArmPivot", [
		[0.0,  base_rarm],
		[0.3,  base_rarm + Vector2(0, -0.5)],
		[0.6,  base_rarm],
		[0.9,  base_rarm + Vector2(0,  0.5)],
		[1.2,  base_rarm],
	])

	_rot(a, "LeftLegPivot",  [[0.0, 0.0], [1.2, 0.0]])
	_rot(a, "RightLegPivot", [[0.0, 0.0], [1.2, 0.0]])
	_rot(a, "LeftArmPivot",  [[0.0, base_larm_rot], [1.2, base_larm_rot]])
	_rot(a, "RightArmPivot", [[0.0, base_rarm_rot], [1.2, base_rarm_rot]])

	_pos(a, "LeftLegPivot",  [[0.0, base_lleg], [1.2, base_lleg]])
	_pos(a, "RightLegPivot", [[0.0, base_rleg], [1.2, base_rleg]])

	_rot(a, "TorsoPivot", [[0.0, 0.0], [1.2, 0.0]])

	_zidx(a, "TorsoPivot/Sprite",    [[0.0, 0]])
	_zidx(a, "LeftLegPivot/Sprite",  [[0.0, -2]])
	_zidx(a, "RightLegPivot/Sprite", [[0.0, -2]])
	_zidx(a, "LeftArmPivot/Sprite",  [[0.0, 2]])
	_zidx(a, "RightArmPivot/Sprite", [[0.0, 2]])

	return a


# ─── WALK: Light step cycle ─────────────────────────────────────────────────

func _make_walk() -> Animation:
	var a = Animation.new()
	a.length = 0.6
	a.loop_mode = Animation.LOOP_LINEAR

	_rot(a, "LeftLegPivot", [
		[0.0,   -0.06],
		[0.15,   0.0],
		[0.3,    0.06],
		[0.45,   0.0],
		[0.6,   -0.06],
	])
	_rot(a, "RightLegPivot", [
		[0.0,    0.06],
		[0.15,   0.0],
		[0.3,   -0.06],
		[0.45,   0.0],
		[0.6,    0.06],
	])

	_rot(a, "LeftArmPivot", [
		[0.0,    0.1 + base_larm_rot],
		[0.15,   0.0 + base_larm_rot],
		[0.3,   -0.1 + base_larm_rot],
		[0.45,   0.0 + base_larm_rot],
		[0.6,    0.1 + base_larm_rot],
	])
	_rot(a, "RightArmPivot", [
		[0.0,   -0.1 + base_rarm_rot],
		[0.15,   0.0 + base_rarm_rot],
		[0.3,    0.1 + base_rarm_rot],
		[0.45,   0.0 + base_rarm_rot],
		[0.6,   -0.1 + base_rarm_rot],
	])

	_pos(a, "TorsoPivot", [
		[0.0,   base_torso],
		[0.15,  base_torso + Vector2(0, -0.5)],
		[0.3,   base_torso],
		[0.45,  base_torso + Vector2(0, -0.5)],
		[0.6,   base_torso],
	])

	_pos(a, "HeadPivot", [
		[0.0,   base_head],
		[0.15,  base_head + Vector2(0, -0.5)],
		[0.3,   base_head],
		[0.45,  base_head + Vector2(0, -0.5)],
		[0.6,   base_head],
	])

	_pos(a, "LeftArmPivot",  [[0.0, base_larm], [0.6, base_larm]])
	_pos(a, "RightArmPivot", [[0.0, base_rarm], [0.6, base_rarm]])

	_pos(a, "LeftLegPivot",  [[0.0, base_lleg], [0.6, base_lleg]])
	_pos(a, "RightLegPivot", [[0.0, base_rleg], [0.6, base_rleg]])

	_rot(a, "TorsoPivot", [[0.0, 0.0], [0.6, 0.0]])

	return a


# ─── RUN: Faster, wider, with forward lean ──────────────────────────────────

func _make_run() -> Animation:
	var a = Animation.new()
	a.length = 0.28
	a.loop_mode = Animation.LOOP_LINEAR

	var q: float = a.length / 4.0

	_rot(a, "LeftLegPivot", [
		[0.0,      -0.1],
		[q,         0.0],
		[q * 2.0,   0.1],
		[q * 3.0,   0.0],
		[a.length, -0.1],
	])
	_rot(a, "RightLegPivot", [
		[0.0,       0.1],
		[q,         0.0],
		[q * 2.0,  -0.1],
		[q * 3.0,   0.0],
		[a.length,  0.1],
	])

	_rot(a, "LeftArmPivot", [
		[0.0,       0.2 + base_larm_rot],
		[q,         0.0 + base_larm_rot],
		[q * 2.0,  -0.2 + base_larm_rot],
		[q * 3.0,   0.0 + base_larm_rot],
		[a.length,  0.2 + base_larm_rot],
	])
	_rot(a, "RightArmPivot", [
		[0.0,      -0.2 + base_rarm_rot],
		[q,         0.0 + base_rarm_rot],
		[q * 2.0,   0.2 + base_rarm_rot],
		[q * 3.0,   0.0 + base_rarm_rot],
		[a.length, -0.2 + base_rarm_rot],
	])

	_pos(a, "TorsoPivot", [
		[0.0,      base_torso],
		[q,        base_torso + Vector2(0, -1)],
		[q * 2.0,  base_torso],
		[q * 3.0,  base_torso + Vector2(0, -1)],
		[a.length, base_torso],
	])

	_rot(a, "TorsoPivot", [
		[0.0, 0.05],
		[a.length, 0.05],
	])

	_pos(a, "HeadPivot", [
		[0.0,      base_head],
		[q,        base_head + Vector2(0, -1)],
		[q * 2.0,  base_head],
		[q * 3.0,  base_head + Vector2(0, -1)],
		[a.length, base_head],
	])

	_pos(a, "LeftArmPivot",  [[0.0, base_larm], [a.length, base_larm]])
	_pos(a, "RightArmPivot", [[0.0, base_rarm], [a.length, base_rarm]])

	_pos(a, "LeftLegPivot",  [[0.0, base_lleg], [a.length, base_lleg]])
	_pos(a, "RightLegPivot", [[0.0, base_rleg], [a.length, base_rleg]])

	return a


# ─── JUMP: Rising pose ───────────────────────────────────────────────────────

func _make_jump() -> Animation:
	var a = Animation.new()
	a.length = 0.5
	a.loop_mode = Animation.LOOP_LINEAR

	_rot(a, "LeftLegPivot", [[0.0, -0.05], [0.25, -0.08], [0.5, -0.05]])
	_rot(a, "RightLegPivot", [[0.0, -0.05], [0.25, -0.08], [0.5, -0.05]])
	_pos(a, "LeftLegPivot", [
		[0.0,  base_lleg + Vector2(0.5, -1)],
		[0.25, base_lleg + Vector2(0.5, -1.5)],
		[0.5,  base_lleg + Vector2(0.5, -1)],
	])
	_pos(a, "RightLegPivot", [
		[0.0,  base_rleg + Vector2(-0.5, -1)],
		[0.25, base_rleg + Vector2(-0.5, -1.5)],
		[0.5,  base_rleg + Vector2(-0.5, -1)],
	])

	_rot(a, "LeftArmPivot", [[0.0, -0.2 + base_larm_rot], [0.25, -0.25 + base_larm_rot], [0.5, -0.2 + base_larm_rot]])
	_rot(a, "RightArmPivot", [[0.0, 0.2 + base_rarm_rot], [0.25, 0.25 + base_rarm_rot], [0.5, 0.2 + base_rarm_rot]])
	_pos(a, "LeftArmPivot", [
		[0.0,  base_larm + Vector2(0, -1)],
		[0.25, base_larm + Vector2(0, -1.5)],
		[0.5,  base_larm + Vector2(0, -1)],
	])
	_pos(a, "RightArmPivot", [
		[0.0,  base_rarm + Vector2(0, -1)],
		[0.25, base_rarm + Vector2(0, -1.5)],
		[0.5,  base_rarm + Vector2(0, -1)],
	])

	_pos(a, "TorsoPivot", [
		[0.0,  base_torso + Vector2(0, -1.5)],
		[0.25, base_torso + Vector2(0, -2)],
		[0.5,  base_torso + Vector2(0, -1.5)],
	])
	_rot(a, "TorsoPivot", [[0.0, 0.0], [0.5, 0.0]])

	_pos(a, "HeadPivot", [
		[0.0,  base_head + Vector2(0, -1.5)],
		[0.25, base_head + Vector2(0, -2)],
		[0.5,  base_head + Vector2(0, -1.5)],
	])

	return a


# ─── FALL: Default short fall ───────────────────────────────────────────────

func _make_fall() -> Animation:
	var a = Animation.new()
	a.length = 0.4
	a.loop_mode = Animation.LOOP_LINEAR

	_rot(a, "LeftLegPivot", [[0.0, -0.05], [0.2, -0.06], [0.4, -0.05]])
	_rot(a, "RightLegPivot", [[0.0, -0.05], [0.2, -0.06], [0.4, -0.05]])
	_pos(a, "LeftLegPivot", [
		[0.0,  base_lleg + Vector2(0.5, -1)],
		[0.2,  base_lleg + Vector2(0.5, -1)],
		[0.4,  base_lleg + Vector2(0.5, -1)],
	])
	_pos(a, "RightLegPivot", [
		[0.0,  base_rleg + Vector2(-0.5, -1)],
		[0.2,  base_rleg + Vector2(-0.5, -1)],
		[0.4,  base_rleg + Vector2(-0.5, -1)],
	])

	_rot(a, "LeftArmPivot", [[0.0, -0.15 + base_larm_rot], [0.2, -0.2 + base_larm_rot], [0.4, -0.15 + base_larm_rot]])
	_rot(a, "RightArmPivot", [[0.0, 0.15 + base_rarm_rot], [0.2, 0.2 + base_rarm_rot], [0.4, 0.15 + base_rarm_rot]])
	_pos(a, "LeftArmPivot", [
		[0.0,  base_larm + Vector2(1.5, -1)],
		[0.2,  base_larm + Vector2(2, -1.5)],
		[0.4,  base_larm + Vector2(1.5, -1)],
	])
	_pos(a, "RightArmPivot", [
		[0.0,  base_rarm + Vector2(-1.5, -1)],
		[0.2,  base_rarm + Vector2(-2, -1.5)],
		[0.4,  base_rarm + Vector2(-1.5, -1)],
	])

	_pos(a, "TorsoPivot", [
		[0.0,  base_torso + Vector2(0, 0.5)],
		[0.2,  base_torso + Vector2(0, 1)],
		[0.4,  base_torso + Vector2(0, 0.5)],
	])
	_rot(a, "TorsoPivot", [[0.0, -0.03], [0.4, -0.03]])

	_pos(a, "HeadPivot", [
		[0.0,  base_head + Vector2(0, 0.5)],
		[0.2,  base_head + Vector2(0, 1)],
		[0.4,  base_head + Vector2(0, 0.5)],
	])

	_zidx(a, "TorsoPivot/Sprite",    [[0.0, -1]])
	_zidx(a, "LeftLegPivot/Sprite",  [[0.0, 1]])
	_zidx(a, "RightLegPivot/Sprite", [[0.0, 1]])
	_zidx(a, "LeftArmPivot/Sprite",  [[0.0, 3]])
	_zidx(a, "RightArmPivot/Sprite", [[0.0, 3]])

	return a


# ─── LONG FALL: Dramatic high fall ──────────────────────────────────────────

func _make_long_fall() -> Animation:
	var a = Animation.new()
	a.length = 1.0
	a.loop_mode = Animation.LOOP_LINEAR

	_rot(a, "LeftLegPivot", [[0.0, -0.2], [0.5, -0.25], [1.0, -0.2]])
	_rot(a, "RightLegPivot", [[0.0, -0.2], [0.5, -0.25], [1.0, -0.2]])
	_pos(a, "LeftLegPivot", [
		[0.0,  base_lleg + Vector2(1.5, -3)],
		[0.5,  base_lleg + Vector2(1.5, -3.5)],
		[1.0,  base_lleg + Vector2(1.5, -3)],
	])
	_pos(a, "RightLegPivot", [
		[0.0,  base_rleg + Vector2(-1.5, -3)],
		[0.5,  base_rleg + Vector2(-1.5, -3.5)],
		[1.0,  base_rleg + Vector2(-1.5, -3)],
	])

	_rot(a, "LeftArmPivot", [[0.0, 0.4 + base_larm_rot], [0.5, 0.45 + base_larm_rot], [1.0, 0.4 + base_larm_rot]])
	_rot(a, "RightArmPivot", [[0.0, -0.4 + base_rarm_rot], [0.5, -0.45 + base_rarm_rot], [1.0, -0.4 + base_rarm_rot]])
	_pos(a, "LeftArmPivot", [
		[0.0,  base_larm + Vector2(-2, 2)],
		[0.5,  base_larm + Vector2(-2, 1.5)],
		[1.0,  base_larm + Vector2(-2, 2)],
	])
	_pos(a, "RightArmPivot", [
		[0.0,  base_rarm + Vector2(2, 2)],
		[0.5,  base_rarm + Vector2(2, 1.5)],
		[1.0,  base_rarm + Vector2(2, 2)],
	])

	_pos(a, "TorsoPivot", [
		[0.0,  base_torso + Vector2(0, 1)],
		[0.5,  base_torso + Vector2(0, 1.5)],
		[1.0,  base_torso + Vector2(0, 1)],
	])
	_rot(a, "TorsoPivot", [[0.0, -0.05], [1.0, -0.05]])

	_pos(a, "HeadPivot", [
		[0.0,  base_head + Vector2(0, 1)],
		[0.5,  base_head + Vector2(0, 1.5)],
		[1.0,  base_head + Vector2(0, 1)],
	])

	# FULL BODY 360° rotation
	var rt := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(rt, ".:rotation")
	a.track_set_interpolation_type(rt, Animation.INTERPOLATION_LINEAR)
	a.track_insert_key(rt, 0.0, 0.0)
	a.track_insert_key(rt, 1.0, TAU)

	_zidx(a, "TorsoPivot/Sprite",    [[0.0, -1]])
	_zidx(a, "LeftLegPivot/Sprite",  [[0.0, 1]])
	_zidx(a, "RightLegPivot/Sprite", [[0.0, 1]])
	_zidx(a, "LeftArmPivot/Sprite",  [[0.0, 3]])
	_zidx(a, "RightArmPivot/Sprite", [[0.0, 3]])

	return a


# ─── Combat Utilities ────────────────────────────────────────────────────────

func _enable_hitbox() -> void:
	var hitbox = get_node_or_null("AttackHitbox/HitShape")
	if hitbox:
		hitbox.disabled = false


func _disable_hitbox() -> void:
	var hitbox = get_node_or_null("AttackHitbox/HitShape")
	if hitbox:
		hitbox.disabled = true


func _spawn_swing_arc() -> void:
	var player_node = get_parent()
	if not player_node:
		return
	var dir: float = sign(scale.x) if scale.x != 0 else 1.0
	var origin: Vector2 = player_node.global_position

	var arc = Line2D.new()
	arc.width = 4.0
	arc.default_color = Color(1.0, 1.0, 0.8, 0.95)
	arc.z_index = 100
	arc.begin_cap_mode = Line2D.LINE_CAP_ROUND
	arc.end_cap_mode = Line2D.LINE_CAP_ROUND

	var arc_radius := 20.0
	for i in range(9):
		var t: float = float(i) / 8.0
		var angle: float = lerpf(-PI * 0.4, PI * 0.4, t)
		var pt := Vector2(cos(angle) * arc_radius * dir, sin(angle) * arc_radius)
		pt += Vector2(dir * 14, 0)
		arc.add_point(pt)

	arc.global_position = origin
	player_node.get_parent().add_child(arc)

	var tw = arc.create_tween()
	tw.set_parallel(true)
	tw.tween_property(arc, "width", 0.0, 0.2).set_ease(Tween.EASE_IN)
	tw.tween_property(arc, "modulate:a", 0.0, 0.22)
	tw.chain().tween_callback(arc.queue_free)

	for i in range(5):
		var p = ColorRect.new()
		p.size = Vector2(3, 3)
		p.color = Color(1.0, 0.9, 0.5, 0.9)
		p.global_position = origin + Vector2(dir * randf_range(10, 28), randf_range(-12, 12))
		p.z_index = 100
		player_node.get_parent().add_child(p)
		var tw2 = p.create_tween()
		tw2.set_parallel(true)
		tw2.tween_property(p, "global_position", p.global_position + Vector2(dir * randf_range(6, 16), randf_range(-8, 8)), 0.22)
		tw2.tween_property(p, "modulate:a", 0.0, 0.22)
		tw2.chain().tween_callback(p.queue_free)


func _spawn_sword_slash_effect(downward: bool) -> void:
	var player_node = get_parent()
	if not player_node:
		return
	var dir: float = sign(scale.x) if scale.x != 0 else 1.0
	var origin: Vector2 = player_node.global_position

	var arc = Line2D.new()
	arc.width = 12.0
	arc.default_color = Color(1.0, 1.0, 1.0, 0.9)  # Bright white for sword slash
	arc.z_index = 105
	arc.begin_cap_mode = Line2D.LINE_CAP_ROUND
	arc.end_cap_mode = Line2D.LINE_CAP_ROUND
	
	var arc_radius := 26.0
	
	# Angles depend on swing direction
	var start_angle: float
	var end_angle: float
	if downward:
		start_angle = -PI * 0.6
		end_angle = PI * 0.4
	else:
		start_angle = PI * 0.6
		end_angle = -PI * 0.4
	
	# More points for smoother sword arc
	for i in range(12):
		var t: float = float(i) / 11.0
		var angle: float = lerpf(start_angle, end_angle, t)
		var pt := Vector2(cos(angle) * arc_radius * dir, sin(angle) * arc_radius)
		pt += Vector2(dir * 20, -5) # pushed out and up
		arc.add_point(pt)

	arc.global_position = origin
	player_node.get_parent().add_child(arc)

	# Animate: shrink width fast + fade out
	var tw = arc.create_tween()
	tw.set_parallel(true)
	tw.tween_property(arc, "width", 0.0, 0.15).set_ease(Tween.EASE_OUT)
	tw.tween_property(arc, "modulate:a", 0.0, 0.18)
	tw.chain().tween_callback(arc.queue_free)

	# Sharp sparks
	for i in range(4):
		var p = ColorRect.new()
		p.size = Vector2(8, 2) # stretched lines instead of dots
		p.color = Color(1.0, 1.0, 1.0, 0.8)
		if dir < 0:
			p.size = Vector2(-8, 2)
		p.global_position = origin + Vector2(dir * randf_range(15, 30), randf_range(-15, 15))
		p.rotation = deg_to_rad(randf_range(-20, 20))
		p.z_index = 100
		player_node.get_parent().add_child(p)
		var tw2 = p.create_tween()
		tw2.set_parallel(true)
		tw2.tween_property(p, "global_position", p.global_position + Vector2(dir * randf_range(10, 20), randf_range(-10, 10)), 0.15)
		tw2.tween_property(p, "scale", Vector2(0.1, 0.1), 0.15)
		tw2.tween_property(p, "modulate:a", 0.0, 0.15)
		tw2.chain().tween_callback(p.queue_free)


func _trigger_thrust_dash() -> void:
	## Called by sword charged animation to propel the player forward.
	var player_node = get_parent()
	if player_node and player_node.has_method("trigger_weapon_dash"):
		player_node.trigger_weapon_dash(700.0)


# ─── Track Helpers ───────────────────────────────────────────────────────────

func _pos(anim: Animation, node_name: String, keys: Array) -> void:
	var t := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(t, node_name + ":position")
	anim.track_set_interpolation_type(t, Animation.INTERPOLATION_CUBIC)
	for k in keys:
		anim.track_insert_key(t, k[0], k[1])


func _rot(anim: Animation, node_name: String, keys: Array) -> void:
	var t := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(t, node_name + ":rotation")
	anim.track_set_interpolation_type(t, Animation.INTERPOLATION_CUBIC)
	for k in keys:
		anim.track_insert_key(t, k[0], k[1])


func _zidx(anim: Animation, node_name: String, keys: Array) -> void:
	var t := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(t, node_name + ":z_index")
	anim.track_set_interpolation_type(t, Animation.INTERPOLATION_NEAREST)
	for k in keys:
		anim.track_insert_key(t, k[0], k[1])
