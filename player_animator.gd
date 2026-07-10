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

# Directional attack state (set by play_attack, read by VFX method tracks)
var _aim_local_angle: float = 0.0
var _aim_facing: float = 1.0
var _slash_downward: bool = true

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
# Per-arm locomotion swing scale (1.0 = full). A weapon's hold can damp the arm
# that grips it (e.g. the sword hand) so the blade is held steadier while moving,
# while the free hand keeps its natural swing. Set via get_hold_positions().
var larm_swing_mul := 1.0
var rarm_swing_mul := 1.0

@export_group("Weapon Adjustments")
@export var weapon_pos_offset := Vector2(0, 0)  ## Manual position tweak for weapon sprite
@export var weapon_rot_offset := 0.0             ## Manual rotation tweak (radians)

# NOTE: animation tuning is exposed as @export so it can be dialed in from the
# Inspector. Values are baked into the animations at _ready(), so edits apply on
# the next run of the scene (same as the pivot positions above). Keep this
# pattern for any new animation knob — promote magic numbers to @export.
@export_group("Walk Cycle")
@export var walk_length := 0.6      ## seconds per full stride (two steps)
@export var walk_leg_swing := 0.14  ## hip swing amplitude (radians)
@export var walk_arm_swing := 0.15  ## arm counter-swing amplitude (radians)
@export var walk_foot_lift := 1.3   ## swing-foot clearance at pass (px)
@export var walk_body_bob := 1.1    ## hip rise at pass (px)
@export var walk_head_bob := 0.9    ## head rise at pass (px)
@export var walk_lean := 0.05       ## forward torso tilt at contact (radians)

@export_group("Run Cycle")
@export var run_length := 0.24      ## seconds per full stride (two steps)
@export var run_leg_swing := 0.22   ## hip swing amplitude (radians)
@export var run_arm_swing := 0.42   ## arm pump amplitude (radians)
@export var run_foot_lift := 3.0    ## swing-foot clearance at pass (px)
@export var run_body_bob := 2.4     ## hip rise at pass (px)
@export var run_head_bob := 1.8     ## head rise at pass (px)
@export var run_lean_x := 2.0       ## upper-body forward shift into the run (px)
@export var run_lean := 0.13        ## forward torso tilt (radians)

@export_group("Slide (down-dodge)")
## Feet-first baseball slide: legs lead low & forward, torso/head recline back
## following them, back hand drags behind, front hand tracks across the body.
@export var slide_length := 0.45     ## total slide duration (s)
@export var slide_sink := 8.0        ## how far the whole rig drops to the ground (px)
@export var slide_lead_leg := -1.45  ## lead leg extension forward (rad; NEGATIVE = forward)
@export var slide_trail_leg := -0.95 ## trailing leg angle (rad)
@export var slide_recline := -0.35   ## torso/back recline (rad; NEGATIVE = lean back)
@export var slide_back_reach := 1.25 ## trailing hand reach back & down onto the ground (rad)
@export var slide_front_reach := -0.55 ## leading hand follow across the body (rad)

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
		"base_larm_rot": base_larm_rot,
		"base_rarm_rot": base_rarm_rot,
		"larm_node": get_node_or_null("LeftArmPivot"),
		"rarm_node": get_node_or_null("RightArmPivot"),
	}


# ─── Weapon Visuals (delegated to weapon animators) ─────────────────────────

func equip_weapon_visual(weapon: WeaponData) -> void:
	has_weapon_equipped = true
	equipped_weapon = weapon

	# CRASH GUARD: never mutate the animation library while the player is
	# evaluating one of its animations — stale track caches segfault (4.3).
	anim_player.stop()
	current_state = ""

	# Remove old weapon animations from the library
	_unregister_weapon_animations()
	
	# Instantiate the weapon-specific animator
	_active_animator = null
	if weapon.animator_script:
		_active_animator = weapon.animator_script.new()
	
	if not _active_animator:
		# Fallback: no animator script → use fists
		_active_animator = _fists_animator

	# Hand the animator its resource so it can read per-weapon @export tuning.
	_active_animator.weapon_data = weapon

	# Reset per-arm swing damping; a weapon's hold may re-damp below. Track the
	# prior state so we still rebuild locomotion when clearing stale damping.
	var had_damping := larm_swing_mul != 1.0 or rarm_swing_mul != 1.0
	larm_swing_mul = 1.0
	rarm_swing_mul = 1.0

	# Apply weapon hold positions (overrides arm positions in locomotion anims)
	var hold = _active_animator.get_hold_positions()
	if hold.size() > 0:
		base_larm = hold.get("base_larm", _default_larm)
		base_rarm = hold.get("base_rarm", _default_rarm)
		base_larm_rot = hold.get("larm_rot", 0.0)
		base_rarm_rot = hold.get("rarm_rot", 0.0)
		larm_swing_mul = hold.get("larm_swing_mul", 1.0)
		rarm_swing_mul = hold.get("rarm_swing_mul", 1.0)
		_rebuild_locomotion_animations()
	elif had_damping:
		# Incoming weapon has no hold overrides but the previous one damped an
		# arm — rebuild so the swing returns to full.
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

	# CRASH GUARD: stop playback before mutating the library (see equip)
	anim_player.stop()
	current_state = ""

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
	larm_swing_mul = 1.0
	rarm_swing_mul = 1.0
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


func play_attack(aim: Vector2 = Vector2.ZERO) -> void:
	## Combo-aware attack, oriented by the world-space `aim` vector (8-way
	## quantized). Horizontal aim keeps the weapon's hand-authored combos;
	## the other directions use the shared angle-parameterized swing builder.
	var facing_sign: float = sign(scale.x) if scale.x != 0 else 1.0
	if aim == Vector2.ZERO:
		aim = Vector2(facing_sign, 0)

	# World aim → rig-local angle (the rig mirrors via scale.x)
	var local_angle := atan2(aim.y, aim.x * facing_sign)
	# Quantize to octants: 0 = forward, ±1 diagonals, ±2 straight up/down.
	# Backward aims fold into forward (playercontroller flips facing first).
	var oct := clampi(roundi(local_angle / (PI / 4.0)), -2, 2)
	_aim_local_angle = oct * (PI / 4.0)
	_aim_facing = facing_sign

	# Point the hitbox along the aim
	var hitbox := get_node_or_null("AttackHitbox")
	if hitbox:
		hitbox.rotation = _aim_local_angle

	# Advance the combo counter
	var combo_count := 2
	if equipped_weapon and equipped_weapon.combo_anims.size() > 0:
		combo_count = equipped_weapon.combo_anims.size()
	if combo_step >= combo_count:
		combo_step = 0
	var step := combo_step
	combo_step = (combo_step + 1) % combo_count
	combo_reset_timer = COMBO_RESET_TIME
	_slash_downward = step % 2 == 0

	var anim_name: String
	if oct == 0:
		# Horizontal: use the weapon's authored animations
		if equipped_weapon and equipped_weapon.combo_anims.size() > 0:
			anim_name = equipped_weapon.combo_anims[step]
		elif equipped_weapon:
			anim_name = equipped_weapon.attack_right_anim if step % 2 == 0 else equipped_weapon.attack_left_anim
		else:
			anim_name = "attack_right" if step % 2 == 0 else "attack_left"
	else:
		# Directional: build (and cache) an angle-parameterized swing
		anim_name = "dirswing_%d_%d" % [oct, step % 2]
		if not anim_player.has_animation(anim_name):
			var opts := {
				"length": 0.35,
				"windup": 0.7 if step % 2 == 0 else 0.5,
				"follow": 1.1 if step % 2 == 0 else 0.9,
			}
			var anim := WeaponAnimator.make_directional_swing(_get_pivots(), _aim_local_angle, opts)
			var lib := anim_player.get_animation_library("")
			if lib:
				lib.add_animation(anim_name, anim)
				_weapon_anim_names.append(anim_name)

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
	# Restore the hitbox to its forward orientation
	var hitbox := get_node_or_null("AttackHitbox")
	if hitbox:
		hitbox.rotation = 0.0
	attack_finished.emit()


func play_hurt() -> void:
	## One-shot hurt recoil; always restarts even if already playing.
	current_state = "hurt"
	if anim_player.has_animation("hurt"):
		anim_player.play("hurt")
		anim_player.seek(0.0, true)


func play_roll() -> void:
	## One-shot dodge roll tuck; always restarts.
	current_state = "roll"
	if anim_player.has_animation("roll"):
		anim_player.play("roll")
		anim_player.seek(0.0, true)


func play_parry() -> void:
	## One-shot guard pose (window + recovery); always restarts.
	current_state = "parry"
	if anim_player.has_animation("parry"):
		anim_player.play("parry")
		anim_player.seek(0.0, true)


func play_aim_pose() -> void:
	## Looping battle stance while charging (weapon-provided, e.g. staff_aim).
	## Silently no-ops for weapons without one.
	if current_state == "staff_aim":
		return
	if anim_player.has_animation("staff_aim"):
		current_state = "staff_aim"
		anim_player.play("staff_aim")


func play_slide() -> void:
	## One-shot low forward slide (down-dodge). Always restarts.
	current_state = "slide"
	if anim_player.has_animation("slide"):
		anim_player.play("slide")
		anim_player.seek(0.0, true)


func play_knockdown() -> void:
	## Tripped: drop to the knees. Held (looped) for the downed duration; the
	## controller stops driving it when the player recovers.
	current_state = "knockdown"
	if anim_player.has_animation("knockdown"):
		anim_player.play("knockdown")
		anim_player.seek(0.0, true)


func play_named_attack(anim_name: String) -> void:
	## Play a specific weapon-registered attack animation (bypasses the combo/
	## aim pipeline — e.g. the healer's prayer_rub). Emits attack_finished when
	## done, same as play_attack/play_uppercut.
	if not anim_player.has_animation(anim_name):
		# Unknown anim: end the attack immediately so is_attacking never sticks
		attack_finished.emit()
		return
	current_state = anim_name
	anim_player.play(anim_name)
	anim_player.seek(0.0, true)
	if not anim_player.animation_finished.is_connected(_on_attack_done):
		anim_player.animation_finished.connect(_on_attack_done, CONNECT_ONE_SHOT)


func play_death() -> void:
	current_state = "death"
	if anim_player.has_animation("death"):
		anim_player.play("death")


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
	lib.add_animation("hurt", _make_hurt())
	lib.add_animation("death", _make_death())
	lib.add_animation("roll", _make_roll())
	lib.add_animation("parry", _make_parry())
	lib.add_animation("slide", _make_slide())
	lib.add_animation("knockdown", _make_knockdown())
	
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

	# CRASH GUARD: replacing an animation out from under an active playback
	# leaves stale track caches (random segfault). Stop first; the controller's
	# state machine re-plays the right locomotion next frame.
	if anim_player.is_playing():
		anim_player.stop()
		current_state = ""
	
	var locomotion_names = ["idle", "walk", "run", "jump", "fall", "long_fall", "hurt", "death", "roll", "parry", "slide", "knockdown"]
	var locomotion_builders = {
		"idle": _make_idle,
		"walk": _make_walk,
		"run": _make_run,
		"jump": _make_jump,
		"fall": _make_fall,
		"long_fall": _make_long_fall,
		"hurt": _make_hurt,
		"death": _make_death,
		"roll": _make_roll,
		"parry": _make_parry,
		"slide": _make_slide,
		"knockdown": _make_knockdown,
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
	var L := walk_length
	a.length = L
	a.loop_mode = Animation.LOOP_LINEAR

	# Full stride = two steps. Contacts at 0 / L·0.5 / L (a foot forward),
	# passes at L·0.25 / L·0.75 (legs vertical under the body). The rig faces +x
	# and legs pivot at the hip: NEGATIVE swings a foot forward, POSITIVE back.
	var q := L * 0.25
	var SWING := walk_leg_swing
	var LIFT  := Vector2(0, -walk_foot_lift)

	# Left leg: forward at contact → vertical at pass → back → pass → forward
	_rot(a, "LeftLegPivot", [
		[0.0,     -SWING],
		[q,        0.0],
		[q * 2.0,  SWING],
		[q * 3.0,  0.0],
		[L,       -SWING],
	])
	# Right leg rides the exact opposite phase
	_rot(a, "RightLegPivot", [
		[0.0,      SWING],
		[q,        0.0],
		[q * 2.0, -SWING],
		[q * 3.0,  0.0],
		[L,        SWING],
	])

	# Foot clearance: lift each leg only while it swings forward through pass
	# (left drives q2→L, peak at q3; right drives 0→q2, peak at q).
	_pos(a, "LeftLegPivot", [
		[0.0,     base_lleg],
		[q * 2.0, base_lleg],
		[q * 3.0, base_lleg + LIFT],
		[L,       base_lleg],
	])
	_pos(a, "RightLegPivot", [
		[0.0,     base_rleg],
		[q,       base_rleg + LIFT],
		[q * 2.0, base_rleg],
		[L,       base_rleg],
	])

	# Body bob: hips ride highest at pass (leg at full vertical length), lowest
	# at contact (leg angled). This cancels the pendulum foot-arc so the feet
	# hold a steady ground line. Two rises per stride.
	var BOB := Vector2(0, -walk_body_bob)
	_pos(a, "TorsoPivot", [
		[0.0,     base_torso],
		[q,       base_torso + BOB],
		[q * 2.0, base_torso],
		[q * 3.0, base_torso + BOB],
		[L,       base_torso],
	])
	# Subtle forward lean that eases as the body rises over the stance leg
	_rot(a, "TorsoPivot", [
		[0.0,     walk_lean],
		[q,       walk_lean * 0.4],
		[q * 2.0, walk_lean],
		[q * 3.0, walk_lean * 0.4],
		[L,       walk_lean],
	])

	# Head tracks the torso bob with a hair of damping so the neck stays natural
	var HBOB := Vector2(0, -walk_head_bob)
	var HREST := Vector2(0, 0.2)
	_pos(a, "HeadPivot", [
		[0.0,     base_head + HREST],
		[q,       base_head + HBOB],
		[q * 2.0, base_head + HREST],
		[q * 3.0, base_head + HBOB],
		[L,       base_head + HREST],
	])

	# Arms counter-swing — each opposes its same-side leg. Per-arm scale lets a
	# weapon damp the hand that grips it; base_*_rot folds in weapon holds.
	var LARM := walk_arm_swing * larm_swing_mul
	var RARM := walk_arm_swing * rarm_swing_mul
	_rot(a, "LeftArmPivot", [
		[0.0,     LARM + base_larm_rot],
		[q,       0.0 + base_larm_rot],
		[q * 2.0,-LARM + base_larm_rot],
		[q * 3.0, 0.0 + base_larm_rot],
		[L,       LARM + base_larm_rot],
	])
	_rot(a, "RightArmPivot", [
		[0.0,    -RARM + base_rarm_rot],
		[q,       0.0 + base_rarm_rot],
		[q * 2.0, RARM + base_rarm_rot],
		[q * 3.0, 0.0 + base_rarm_rot],
		[L,      -RARM + base_rarm_rot],
	])

	# Hands pinned to their hold positions (rotation carries the swing)
	_pos(a, "LeftArmPivot",  [[0.0, base_larm], [L, base_larm]])
	_pos(a, "RightArmPivot", [[0.0, base_rarm], [L, base_rarm]])

	return a


# ─── RUN: Brisk sprint — grounded feet, real bounce, forward lean ────────────

func _make_run() -> Animation:
	## Same grounded technique as the walk (contact/pass cycle, hip bob cancels
	## the pendulum foot-arc, per-leg toe clearance) but pushed harder and faster:
	## quicker cadence, longer reach, deeper bounce, a committed forward lean, and
	## a strong arm pump. Timeline: contacts at 0.0/0.12/0.24, passes at 0.06/0.18.
	var a = Animation.new()
	var L := run_length
	a.length = L
	a.loop_mode = Animation.LOOP_LINEAR

	var q := L * 0.25
	var SWING := run_leg_swing            # bigger stride than the walk, feet still under body
	var LIFT  := Vector2(0, -run_foot_lift)
	var BOB   := Vector2(0, -run_body_bob)
	var LEAN  := Vector2(run_lean_x, 0)   # whole upper body pitched forward into the run

	# Legs: NEGATIVE swings a foot forward, POSITIVE swings it back.
	_rot(a, "LeftLegPivot", [
		[0.0,     -SWING],
		[q,        0.0],
		[q * 2.0,  SWING],
		[q * 3.0,  0.0],
		[L,       -SWING],
	])
	_rot(a, "RightLegPivot", [
		[0.0,      SWING],
		[q,        0.0],
		[q * 2.0, -SWING],
		[q * 3.0,  0.0],
		[L,        SWING],
	])

	# Toe clearance while each leg drives forward through its pass
	# (right drives 0→q2 peak q; left drives q2→L peak q3).
	_pos(a, "RightLegPivot", [
		[0.0,     base_rleg],
		[q,       base_rleg + LIFT],
		[q * 2.0, base_rleg],
		[L,       base_rleg],
	])
	_pos(a, "LeftLegPivot", [
		[0.0,     base_lleg],
		[q * 2.0, base_lleg],
		[q * 3.0, base_lleg + LIFT],
		[L,       base_lleg],
	])

	# Hips ride highest at pass, lowest at contact — keeps planted feet on the
	# ground line and gives the run its bounce. Two rises per stride.
	_pos(a, "TorsoPivot", [
		[0.0,     base_torso + LEAN],
		[q,       base_torso + LEAN + BOB],
		[q * 2.0, base_torso + LEAN],
		[q * 3.0, base_torso + LEAN + BOB],
		[L,       base_torso + LEAN],
	])
	# Committed forward lean (siblings don't inherit torso rotation, so the lean
	# is sold by the LEAN shift above plus this torso tilt).
	_rot(a, "TorsoPivot", [[0.0, run_lean], [L, run_lean]])

	# Head pitched forward, tracking the bob a touch under the torso
	var HLEAN := LEAN + Vector2(1.0, 0.2)
	var HBOB  := Vector2(0, -run_head_bob)
	_pos(a, "HeadPivot", [
		[0.0,     base_head + HLEAN],
		[q,       base_head + HLEAN + HBOB],
		[q * 2.0, base_head + HLEAN],
		[q * 3.0, base_head + HLEAN + HBOB],
		[L,       base_head + HLEAN],
	])

	# Arms pump hard, each opposing its same-side leg. Per-arm scale lets a weapon
	# damp the hand that grips it; base_*_rot folds in weapon holds.
	var LARM := run_arm_swing * larm_swing_mul
	var RARM := run_arm_swing * rarm_swing_mul
	_rot(a, "LeftArmPivot", [
		[0.0,     LARM + base_larm_rot],
		[q,       0.0 + base_larm_rot],
		[q * 2.0,-LARM + base_larm_rot],
		[q * 3.0, 0.0 + base_larm_rot],
		[L,       LARM + base_larm_rot],
	])
	_rot(a, "RightArmPivot", [
		[0.0,    -RARM + base_rarm_rot],
		[q,       0.0 + base_rarm_rot],
		[q * 2.0, RARM + base_rarm_rot],
		[q * 3.0, 0.0 + base_rarm_rot],
		[L,      -RARM + base_rarm_rot],
	])

	# Hands ride forward with the lean; rotation carries the pump
	_pos(a, "LeftArmPivot",  [[0.0, base_larm + LEAN], [L, base_larm + LEAN]])
	_pos(a, "RightArmPivot", [[0.0, base_rarm + LEAN], [L, base_rarm + LEAN]])

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


# ─── HURT: Quick recoil flinch ───────────────────────────────────────────────

func _make_hurt() -> Animation:
	var a = Animation.new()
	a.length = 0.25
	a.loop_mode = Animation.LOOP_NONE

	# Whole upper body snaps back, then settles
	_pos(a, "TorsoPivot", [
		[0.0,  base_torso + Vector2(-3, 1)],
		[0.1,  base_torso + Vector2(-2, 0.5)],
		[0.25, base_torso],
	])
	_rot(a, "TorsoPivot", [[0.0, -0.18], [0.12, -0.1], [0.25, 0.0]])

	_pos(a, "HeadPivot", [
		[0.0,  base_head + Vector2(-4, 1)],
		[0.1,  base_head + Vector2(-2, 0.5)],
		[0.25, base_head],
	])

	_pos(a, "LeftArmPivot", [
		[0.0,  base_larm + Vector2(-2, -2)],
		[0.25, base_larm],
	])
	_rot(a, "LeftArmPivot", [[0.0, -0.5 + base_larm_rot], [0.25, base_larm_rot]])
	_pos(a, "RightArmPivot", [
		[0.0,  base_rarm + Vector2(-2, -2)],
		[0.25, base_rarm],
	])
	_rot(a, "RightArmPivot", [[0.0, 0.5 + base_rarm_rot], [0.25, base_rarm_rot]])

	_rot(a, "LeftLegPivot",  [[0.0, 0.1], [0.25, 0.0]])
	_rot(a, "RightLegPivot", [[0.0, -0.1], [0.25, 0.0]])
	_pos(a, "LeftLegPivot",  [[0.0, base_lleg], [0.25, base_lleg]])
	_pos(a, "RightLegPivot", [[0.0, base_rleg], [0.25, base_rleg]])

	return a


# ─── DEATH: Collapse backward ────────────────────────────────────────────────

func _make_death() -> Animation:
	var a = Animation.new()
	a.length = 0.8
	a.loop_mode = Animation.LOOP_NONE

	# Body crumples: torso and head sink, limbs go limp
	_pos(a, "TorsoPivot", [
		[0.0,  base_torso],
		[0.3,  base_torso + Vector2(-2, 2)],
		[0.8,  base_torso + Vector2(-4, 6)],
	])
	_rot(a, "TorsoPivot", [[0.0, 0.0], [0.4, -0.4], [0.8, -0.9]])

	_pos(a, "HeadPivot", [
		[0.0,  base_head],
		[0.3,  base_head + Vector2(-3, 3)],
		[0.8,  base_head + Vector2(-6, 9)],
	])

	_pos(a, "LeftArmPivot", [
		[0.0,  base_larm],
		[0.8,  base_larm + Vector2(-3, 5)],
	])
	_rot(a, "LeftArmPivot", [[0.0, base_larm_rot], [0.8, base_larm_rot - 1.2]])
	_pos(a, "RightArmPivot", [
		[0.0,  base_rarm],
		[0.8,  base_rarm + Vector2(-3, 5)],
	])
	_rot(a, "RightArmPivot", [[0.0, base_rarm_rot], [0.8, base_rarm_rot + 1.2]])

	_rot(a, "LeftLegPivot",  [[0.0, 0.0], [0.8, 0.5]])
	_rot(a, "RightLegPivot", [[0.0, 0.0], [0.8, -0.5]])
	_pos(a, "LeftLegPivot",  [[0.0, base_lleg], [0.8, base_lleg + Vector2(1, 2)]])
	_pos(a, "RightLegPivot", [[0.0, base_rleg], [0.8, base_rleg + Vector2(-1, 2)]])

	# Whole-skin tilt (reset externally on respawn, like long_fall)
	var rt := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(rt, ".:rotation")
	a.track_set_interpolation_type(rt, Animation.INTERPOLATION_LINEAR)
	a.track_insert_key(rt, 0.0, 0.0)
	a.track_insert_key(rt, 0.8, -PI / 2.2)

	return a


# ─── ROLL: Grounded forward tuck (dodge) ─────────────────────────────────────

func _make_roll() -> Animation:
	## Full-body forward rotation with limbs tucked in — reuses the long_fall
	## whole-skin rotation technique but grounded and one-shot. The controller
	## resets PlayerSkin.rotation when the roll ends.
	var a = Animation.new()
	a.length = 0.35
	a.loop_mode = Animation.LOOP_NONE

	# Tuck: everything pulls toward the center
	_pos(a, "TorsoPivot", [
		[0.0,  base_torso],
		[0.08, base_torso + Vector2(0, 2)],
		[0.3,  base_torso + Vector2(0, 2)],
		[0.35, base_torso],
	])
	_rot(a, "TorsoPivot", [[0.0, 0.0], [0.35, 0.0]])
	_pos(a, "HeadPivot", [
		[0.0,  base_head],
		[0.08, base_head + Vector2(2, 4)],
		[0.3,  base_head + Vector2(2, 4)],
		[0.35, base_head],
	])
	_pos(a, "LeftArmPivot", [
		[0.0,  base_larm],
		[0.08, base_larm + Vector2(-2, 2)],
		[0.3,  base_larm + Vector2(-2, 2)],
		[0.35, base_larm],
	])
	_rot(a, "LeftArmPivot", [[0.0, base_larm_rot], [0.1, base_larm_rot + 1.2], [0.35, base_larm_rot]])
	_pos(a, "RightArmPivot", [
		[0.0,  base_rarm],
		[0.08, base_rarm + Vector2(2, 2)],
		[0.3,  base_rarm + Vector2(2, 2)],
		[0.35, base_rarm],
	])
	_rot(a, "RightArmPivot", [[0.0, base_rarm_rot], [0.1, base_rarm_rot - 1.2], [0.35, base_rarm_rot]])
	_pos(a, "LeftLegPivot", [
		[0.0,  base_lleg],
		[0.08, base_lleg + Vector2(1, -2)],
		[0.3,  base_lleg + Vector2(1, -2)],
		[0.35, base_lleg],
	])
	_rot(a, "LeftLegPivot", [[0.0, 0.0], [0.1, 0.9], [0.35, 0.0]])
	_pos(a, "RightLegPivot", [
		[0.0,  base_rleg],
		[0.08, base_rleg + Vector2(-1, -2)],
		[0.3,  base_rleg + Vector2(-1, -2)],
		[0.35, base_rleg],
	])
	_rot(a, "RightLegPivot", [[0.0, 0.0], [0.1, -0.9], [0.35, 0.0]])

	# FULL BODY forward rotation (mirrors automatically with scale.x flip)
	var rt := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(rt, ".:rotation")
	a.track_set_interpolation_type(rt, Animation.INTERPOLATION_LINEAR)
	a.track_insert_key(rt, 0.0, 0.0)
	a.track_insert_key(rt, 0.35, TAU)

	return a


# ─── PARRY: Guard pose (window + recovery) ───────────────────────────────────

func _make_parry() -> Animation:
	var a = Animation.new()
	a.length = 0.45
	a.loop_mode = Animation.LOOP_NONE

	# Both arms snap up into a cross-guard in front of the chest, then relax
	_pos(a, "LeftArmPivot", [
		[0.0,  base_larm],
		[0.05, base_larm + Vector2(6, -3)],
		[0.28, base_larm + Vector2(6, -3)],
		[0.45, base_larm],
	])
	_rot(a, "LeftArmPivot", [
		[0.0,  base_larm_rot],
		[0.05, base_larm_rot - 0.9],
		[0.28, base_larm_rot - 0.9],
		[0.45, base_larm_rot],
	])
	_pos(a, "RightArmPivot", [
		[0.0,  base_rarm],
		[0.05, base_rarm + Vector2(7, -2)],
		[0.28, base_rarm + Vector2(7, -2)],
		[0.45, base_rarm],
	])
	_rot(a, "RightArmPivot", [
		[0.0,  base_rarm_rot],
		[0.05, base_rarm_rot - 0.7],
		[0.28, base_rarm_rot - 0.7],
		[0.45, base_rarm_rot],
	])

	# Slight brace: torso leans back, legs plant wide
	_pos(a, "TorsoPivot", [
		[0.0,  base_torso],
		[0.05, base_torso + Vector2(-1.5, 0.5)],
		[0.28, base_torso + Vector2(-1.5, 0.5)],
		[0.45, base_torso],
	])
	_rot(a, "TorsoPivot", [[0.0, 0.0], [0.05, -0.08], [0.28, -0.08], [0.45, 0.0]])
	_pos(a, "HeadPivot", [
		[0.0,  base_head],
		[0.05, base_head + Vector2(-1, 0.5)],
		[0.28, base_head + Vector2(-1, 0.5)],
		[0.45, base_head],
	])
	_rot(a, "LeftLegPivot",  [[0.0, 0.0], [0.05, -0.12], [0.28, -0.12], [0.45, 0.0]])
	_rot(a, "RightLegPivot", [[0.0, 0.0], [0.05, 0.12], [0.28, 0.12], [0.45, 0.0]])
	_pos(a, "LeftLegPivot",  [[0.0, base_lleg], [0.45, base_lleg]])
	_pos(a, "RightLegPivot", [[0.0, base_rleg], [0.45, base_rleg]])

	return a


# ─── SLIDE: low forward baseball-slide (down-dodge) ─────────────────────────

func _make_slide() -> Animation:
	## Feet-first baseball slide. The legs shoot forward and lay low; the torso
	## and head recline BACK, following the legs down; the back hand drags along
	## the ground behind for balance while the front hand tracks across the body.
	## Drop in fast (0→t_set), hold the slide, then pop back up on recovery.
	var a = Animation.new()
	var L := slide_length
	a.loop_mode = Animation.LOOP_NONE
	a.length = L

	var t_set := L * 0.18   # fully committed into the slide
	var t_hold := L * 0.72  # start standing back up
	# The rig faces +x. Legs pivot at the hip: NEGATIVE rotation throws the feet
	# FORWARD; torso NEGATIVE rotation reclines the chest BACK.

	# ── Legs: shoot forward and lay low (lead leg leads, trail tucks behind) ──
	_rot(a, "LeftLegPivot", [
		[0.0, 0.0], [t_set, slide_lead_leg], [t_hold, slide_lead_leg], [L, 0.0],
	])
	_rot(a, "RightLegPivot", [
		[0.0, 0.0], [t_set, slide_trail_leg], [t_hold, slide_trail_leg], [L, 0.0],
	])
	# Lead foot pushes forward and low; trailing foot stays tucked under the hips
	_pos(a, "LeftLegPivot", [
		[0.0, base_lleg],
		[t_set, base_lleg + Vector2(5, 2)],
		[t_hold, base_lleg + Vector2(6, 2)],
		[L, base_lleg],
	])
	_pos(a, "RightLegPivot", [
		[0.0, base_rleg],
		[t_set, base_rleg + Vector2(1, 1)],
		[t_hold, base_rleg + Vector2(1, 1)],
		[L, base_rleg],
	])

	# ── Torso: recline BACK and low, following the legs down ──
	_rot(a, "TorsoPivot", [
		[0.0, 0.0], [t_set, slide_recline], [t_hold, slide_recline], [L, 0.0],
	])
	_pos(a, "TorsoPivot", [
		[0.0, base_torso],
		[t_set, base_torso + Vector2(-2, 4)],
		[t_hold, base_torso + Vector2(-2, 4)],
		[L, base_torso],
	])

	# ── Head: follows the torso back and down, still facing the slide line ──
	_rot(a, "HeadPivot", [
		[0.0, 0.0], [t_set, slide_recline * 0.6], [t_hold, slide_recline * 0.6], [L, 0.0],
	])
	_pos(a, "HeadPivot", [
		[0.0, base_head],
		[t_set, base_head + Vector2(-2, 3)],
		[t_hold, base_head + Vector2(-2, 3)],
		[L, base_head],
	])

	# ── Back hand (RightArm): drags DOWN and BEHIND along the ground ──
	_rot(a, "RightArmPivot", [
		[0.0, base_rarm_rot],
		[t_set, slide_back_reach + base_rarm_rot],
		[t_hold, slide_back_reach + base_rarm_rot],
		[L, base_rarm_rot],
	])
	_pos(a, "RightArmPivot", [
		[0.0, base_rarm],
		[t_set, base_rarm + Vector2(-4, 4)],
		[t_hold, base_rarm + Vector2(-5, 5)],
		[L, base_rarm],
	])

	# ── Front hand (LeftArm): follows the body, reaching across/forward ──
	_rot(a, "LeftArmPivot", [
		[0.0, base_larm_rot],
		[t_set, slide_front_reach + base_larm_rot],
		[t_hold, slide_front_reach + base_larm_rot],
		[L, base_larm_rot],
	])
	_pos(a, "LeftArmPivot", [
		[0.0, base_larm],
		[t_set, base_larm + Vector2(1, 2)],
		[t_hold, base_larm + Vector2(1, 2)],
		[L, base_larm],
	])

	# ── Sink the whole rig toward the ground for the low slide ──
	var rt := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(rt, ".:position:y")
	a.track_set_interpolation_type(rt, Animation.INTERPOLATION_CUBIC)
	a.track_insert_key(rt, 0.0, 0.0)
	a.track_insert_key(rt, t_set, slide_sink)
	a.track_insert_key(rt, t_hold, slide_sink)
	a.track_insert_key(rt, L, 0.0)

	return a


# ─── KNOCKDOWN: tripped onto the knees (looped while downed) ─────────────────

func _make_knockdown() -> Animation:
	var a = Animation.new()
	a.length = 0.9
	a.loop_mode = Animation.LOOP_LINEAR

	# Slumped forward onto the knees, head bowed, arms braced on the ground.
	# A faint tremble sells "struggling to get up".
	_pos(a, "TorsoPivot", [
		[0.0,  base_torso + Vector2(-1, 7)],
		[0.45, base_torso + Vector2(-1, 7.4)],
		[0.9,  base_torso + Vector2(-1, 7)],
	])
	_rot(a, "TorsoPivot", [[0.0, 0.55], [0.45, 0.6], [0.9, 0.55]])
	_pos(a, "HeadPivot", [
		[0.0,  base_head + Vector2(-2, 8)],
		[0.45, base_head + Vector2(-2, 8.5)],
		[0.9,  base_head + Vector2(-2, 8)],
	])

	# Knees down: legs folded under
	_rot(a, "LeftLegPivot",  [[0.0, 1.5], [0.9, 1.5]])
	_rot(a, "RightLegPivot", [[0.0, 1.3], [0.9, 1.3]])
	_pos(a, "LeftLegPivot",  [[0.0, base_lleg + Vector2(0, 3)], [0.9, base_lleg + Vector2(0, 3)]])
	_pos(a, "RightLegPivot", [[0.0, base_rleg + Vector2(0, 3)], [0.9, base_rleg + Vector2(0, 3)]])

	# Hands planted on the ground in front
	_rot(a, "LeftArmPivot",  [[0.0, 1.0 + base_larm_rot], [0.9, 1.0 + base_larm_rot]])
	_rot(a, "RightArmPivot", [[0.0, 0.9 + base_rarm_rot], [0.9, 0.9 + base_rarm_rot]])
	_pos(a, "LeftArmPivot",  [[0.0, base_larm + Vector2(3, 6)], [0.45, base_larm + Vector2(3, 6.4)], [0.9, base_larm + Vector2(3, 6)]])
	_pos(a, "RightArmPivot", [[0.0, base_rarm + Vector2(2, 6)], [0.9, base_rarm + Vector2(2, 6)]])

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
	var player_node := get_parent()
	if not player_node:
		return
	var dir: float = sign(scale.x) if scale.x != 0 else 1.0
	Fx.swing_arc(player_node.global_position, dir)


func _spawn_sword_slash_effect(downward: bool) -> void:
	var player_node := get_parent()
	if not player_node:
		return
	var dir: float = sign(scale.x) if scale.x != 0 else 1.0
	Fx.slash_effect(player_node.global_position, dir, downward)


func _spawn_directional_slash() -> void:
	## Slash VFX oriented along the current aim (called from directional swings).
	var player_node := get_parent()
	if not player_node:
		return
	var dir: float = sign(scale.x) if scale.x != 0 else 1.0
	# Convert the rig-local aim angle to a world rotation (mirrored rigs flip)
	var world_angle := _aim_local_angle * dir
	Fx.slash_effect(player_node.global_position, dir, _slash_downward, world_angle)


func _trigger_thrust_dash() -> void:
	## Called by sword charged animation to propel the player forward.
	var player_node = get_parent()
	if player_node and player_node.has_method("trigger_weapon_dash"):
		player_node.trigger_weapon_dash(700.0)


func _fire_projectile(charged: bool = false) -> void:
	## Called by bow animation method tracks at the loose moment.
	var player_node = get_parent()
	if player_node and player_node.has_method("fire_projectile"):
		player_node.fire_projectile(charged)


func _trigger_prayer_effect() -> void:
	## Called by the healer's prayer_rub method track at the rub's climax.
	var player_node = get_parent()
	if player_node and player_node.has_method("on_prayer_completed"):
		player_node.on_prayer_completed()


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
