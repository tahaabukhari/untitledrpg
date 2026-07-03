extends EnemyBase
## FOURBLADE — 4-armed, 4-sword miniboss, ~4× player size.
##
## Signature mechanic: each summoned sword independently accrues a randomized
## damage "power" over time (visible as glow intensity/scale — bigger glow =
## harder hit). When a sword strikes, it spends its power and resets.
## The boss can summon/dismiss any subset of its four swords, performs
## telegraphed dash attacks, and on a cooldown attempts a telegraphed
## grab-and-throw with airtime + landing damage (dodge/parry avoids it,
## and a perfect parry staggers the boss open).
##
## Rig is code-built (puppet-style, no sprites); slashes use the SHARED
## directional swing builder, scaled up for boss size.

enum State { IDLE, APPROACH, SLASH, DASH_WIND, DASH, GRAB_WIND, GRAB_HOLD, SUMMON, RECOVER }

@export_group("Boss")
@export var walk_speed: float = 130.0
@export var dash_speed: float = 850.0
@export var grab_cooldown: float = 7.0
@export var grab_chance: float = 0.45
@export var summon_interval: float = 6.0

@export_group("Sword Power")
@export var power_min: float = 8.0    ## freshly reset sword damage
@export var power_cap: float = 40.0   ## fully charged sword damage
@export var accrual_min: float = 2.0  ## power gained per second (low roll)
@export var accrual_max: float = 7.0  ## power gained per second (high roll)

const ARM_COUNT := 4
const GRAB_IMPACT := 14
const GRAB_LANDING := 10
const DASH_TIME := 0.4
const PLAYER_GRAB_RANGE := 110.0

var state: State = State.IDLE
var state_timer := 0.0
var face_dir := 1
var grab_timer := 3.0          # first grab possible after a few seconds
var summon_timer := 4.0
var phase2 := false            # below 50% HP: more swords, faster power, more dashes

var _visual: Node2D = null
var _anim: AnimationPlayer = null
var _swords: Array = []        # [{pivot, arm, blade, glow, power, active, base_pos, base_rot}]
var _attacking_sword := -1
var _dash_dir := 1
var _grab_hold_time := 0.0


# ─── Setup ───────────────────────────────────────────────────────────────────

func _enemy_ready() -> void:
	max_hp = 600
	hp = max_hp
	exp_value = 200.0
	attack_damage = 12
	aggro_range = 2200.0
	add_to_group("boss")

	_build_visual()
	_flash_sprite = _visual
	# Big frontal wall of a hitbox: reaches from sword height down to the
	# ground so grounded players are hit (boss center sits ~100px up)
	setup_attack_hitbox(Vector2(120, 170), Vector2(80, 15))
	_build_animations()
	_set_active_swords([0, 1, 2])  # start with three summoned


func _build_visual() -> void:
	_visual = Node2D.new()
	_visual.name = "Visual"
	add_child(_visual)

	var body_col := Color(0.16, 0.13, 0.2)
	var body_hi := Color(0.24, 0.2, 0.3)
	var arm_col := Color(0.2, 0.17, 0.26)

	# Legs — two thick pillars
	_visual.add_child(_rect(Vector2(-34, 20), Vector2(24, 80), body_col))
	_visual.add_child(_rect(Vector2(10, 20), Vector2(24, 80), body_col))
	# Torso — broad slab, slightly tapered
	var torso := Polygon2D.new()
	torso.polygon = PackedVector2Array([
		Vector2(-42, -110), Vector2(42, -110), Vector2(50, 30), Vector2(-50, 30),
	])
	torso.color = body_hi
	_visual.add_child(torso)
	# Chest plate detail
	_visual.add_child(_rect(Vector2(-30, -80), Vector2(60, 12), body_col))
	_visual.add_child(_rect(Vector2(-24, -50), Vector2(48, 8), body_col))
	# Head — horned dome with glowing eyes
	var head := Polygon2D.new()
	var hp_pts := PackedVector2Array()
	for i in range(10):
		var t := PI + PI * float(i) / 9.0
		hp_pts.append(Vector2(0, -118) + Vector2(cos(t), sin(t)) * 22.0)
	hp_pts.append(Vector2(22, -112))
	hp_pts.append(Vector2(-22, -112))
	head.polygon = hp_pts
	head.color = body_col
	_visual.add_child(head)
	var eye := _rect(Vector2(4, -128), Vector2(12, 4), Color(1.0, 0.25, 0.2))
	eye.name = "Eye"
	_visual.add_child(eye)

	# Four arms: two high shoulders, two low — all swing toward +x (facing)
	var shoulder_points := [
		Vector2(30, -100), Vector2(-30, -95),
		Vector2(36, -55), Vector2(-36, -50),
	]
	_swords.clear()
	for i in range(ARM_COUNT):
		var pivot := Node2D.new()
		pivot.name = "Arm%d" % i
		pivot.position = shoulder_points[i]
		_visual.add_child(pivot)

		var arm := _rect(Vector2(0, -5), Vector2(40, 10), arm_col)
		arm.name = "Bone"
		pivot.add_child(arm)

		# Sword pivot at the hand
		var sword_pivot := Node2D.new()
		sword_pivot.name = "SwordPivot"
		sword_pivot.position = Vector2(40, 0)
		pivot.add_child(sword_pivot)

		# Power glow BEHIND the blade — the readable telegraph
		var glow := Polygon2D.new()
		glow.name = "Glow"
		glow.polygon = PackedVector2Array([
			Vector2(-4, -12), Vector2(64, -8), Vector2(72, 0), Vector2(64, 8), Vector2(-4, 12),
		])
		glow.color = Color(0.4, 0.8, 1.0, 0.0)
		glow.z_index = -1
		sword_pivot.add_child(glow)

		var blade := Polygon2D.new()
		blade.name = "Blade"
		blade.polygon = PackedVector2Array([
			Vector2(0, -5), Vector2(52, -3), Vector2(62, 0), Vector2(52, 3), Vector2(0, 5),
		])
		blade.color = Color(0.78, 0.8, 0.88)
		sword_pivot.add_child(blade)
		# Crossguard
		var guard := _rect(Vector2(-2, -8), Vector2(4, 16), Color(0.5, 0.42, 0.25))
		sword_pivot.add_child(guard)

		_swords.append({
			"pivot": pivot,
			"sword_pivot": sword_pivot,
			"blade": blade,
			"glow": glow,
			"power": power_min,
			"active": false,
			"base_pos": shoulder_points[i],
			"base_rot": [-0.5, -0.9, 0.35, 0.7][i],  # resting fan of blades
		})
		pivot.rotation = _swords[i]["base_rot"]
		pivot.visible = false


func _rect(pos: Vector2, size: Vector2, color: Color) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = PackedVector2Array([
		pos, pos + Vector2(size.x, 0), pos + size, pos + Vector2(0, size.y),
	])
	p.color = color
	return p


func _build_animations() -> void:
	## One directional swing per arm via the SHARED builder, boss-scaled.
	_anim = AnimationPlayer.new()
	_anim.name = "AnimPlayer"
	add_child(_anim)
	var lib := AnimationLibrary.new()
	for i in range(ARM_COUNT):
		var s: Dictionary = _swords[i]
		var swing := WeaponAnimator.make_directional_swing({}, 0.0, {
			"length": 0.7,
			"arm_nodes": ["Visual/Arm%d" % i],
			"arm_bases": [s["base_pos"]],
			"arm_base_rots": [s["base_rot"]],
			"weapon_node": "",
			"reach": 26.0,
			"windup": 1.5,
			"follow": 1.3,
			"hit_start": 0.7 * 0.4,
			"hit_end": 0.7 * 0.62,
			"slash_time": 0.7 * 0.44,
			"enable_method": "_swing_hit_on",
			"disable_method": "_swing_hit_off",
			"slash_method": "_swing_slash",
		})
		lib.add_animation("slash_%d" % i, swing)
	_anim.add_animation_library("", lib)
	_anim.animation_finished.connect(_on_anim_finished)


# ─── Main loop ───────────────────────────────────────────────────────────────

func _enemy_physics(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta

	_accrue_power(delta)
	_update_sword_glows()
	_face_player()

	# Phase 2 trigger
	if not phase2 and hp <= max_hp / 2:
		_enter_phase2()

	grab_timer -= delta
	summon_timer -= delta
	state_timer -= delta

	match state:
		State.IDLE:
			velocity.x = move_toward(velocity.x, 0, 800 * delta)
			if state_timer <= 0.0:
				_decide()
		State.APPROACH:
			velocity.x = face_dir * walk_speed * (1.35 if phase2 else 1.0)
			if _distance_to_player() < 170.0 or state_timer <= 0.0:
				velocity.x = 0.0
				_decide()
		State.SLASH:
			velocity.x = move_toward(velocity.x, 0, 600 * delta)
			if state_timer <= 0.0:  # safety if the anim stalls
				_to_idle(0.4)
		State.DASH_WIND:
			velocity.x = 0.0
			if state_timer <= 0.0:
				_begin_dash()
		State.DASH:
			velocity.x = _dash_dir * dash_speed
			if state_timer <= 0.0:
				disable_attack_hitbox()
				_to_idle(0.7)
		State.GRAB_WIND:
			velocity.x = face_dir * 60.0
			if state_timer <= 0.0:
				_attempt_grab()
		State.GRAB_HOLD:
			velocity.x = 0.0
			_grab_hold_time -= delta
			if player and is_instance_valid(player) and player.get("is_grabbed"):
				# Hold the victim aloft in the upper hand
				var hand := _visual.to_global(Vector2(46 , -120))
				player.update_grabbed(hand)
				if _grab_hold_time <= 0.0:
					_throw_player()
			else:
				_to_idle(0.5)
		State.SUMMON:
			velocity.x = 0.0
			if state_timer <= 0.0:
				_finish_summon()
		State.RECOVER:
			velocity.x = move_toward(velocity.x, 0, 700 * delta)
			if state_timer <= 0.0:
				_to_idle(0.1)

	move_and_slide()


func _decide() -> void:
	if not player or not is_instance_valid(player):
		_to_idle(1.0)
		return
	var dist := _distance_to_player()
	var roll := randf()

	# Summon/dismiss on its own clock — unpredictability between actions
	if summon_timer <= 0.0:
		_begin_summon()
		return
	if dist > 260.0:
		if roll < (0.4 if phase2 else 0.25):
			_begin_dash_wind()
		else:
			state = State.APPROACH
			state_timer = 2.2
		return
	# In range: grab / slash / dash
	if grab_timer <= 0.0 and dist < PLAYER_GRAB_RANGE + 60.0 and roll < grab_chance:
		_begin_grab_wind()
		return
	if roll < (0.3 if phase2 else 0.18):
		_begin_dash_wind()
		return
	_begin_slash()


func _to_idle(pause: float) -> void:
	state = State.IDLE
	state_timer = pause


func _on_staggered() -> void:
	# Perfect parry: attack interrupted, boss wide open
	stagger_timer = maxf(stagger_timer, 1.6)
	if _anim and _anim.is_playing():
		_anim.stop()
		_reset_arm_poses()
	if state == State.GRAB_HOLD and player and is_instance_valid(player) and player.get("is_grabbed"):
		# Dropped the victim
		player.launch_thrown(Vector2(-face_dir * 160, -120), 0, 0)
	disable_attack_hitbox()
	_to_idle(0.8)


# ─── Sword power (the signature) ─────────────────────────────────────────────

func _accrue_power(delta: float) -> void:
	var mult := 1.8 if phase2 else 1.0
	for s: Dictionary in _swords:
		if s["active"]:
			s["power"] = minf(s["power"] + randf_range(accrual_min, accrual_max) * delta * mult, power_cap)


func _update_sword_glows() -> void:
	for s: Dictionary in _swords:
		var glow: Polygon2D = s["glow"]
		var blade: Polygon2D = s["blade"]
		if not s["active"]:
			continue
		var t: float = inverse_lerp(power_min, power_cap, s["power"])
		# Cyan → white → orange as power builds; alpha and size grow with it
		glow.color = Color(0.4 + 0.6 * t, 0.8 - 0.15 * t, 1.0 - 0.75 * t, 0.15 + 0.75 * t)
		glow.scale = Vector2.ONE * (0.8 + 0.55 * t)
		blade.color = Color(0.78 + 0.2 * t, 0.8, 0.88 - 0.3 * t)


func _strongest_active_sword() -> int:
	var best := -1
	var best_power := -1.0
	for i in range(ARM_COUNT):
		if _swords[i]["active"] and _swords[i]["power"] > best_power:
			best_power = _swords[i]["power"]
			best = i
	return best


func _spend_sword(idx: int) -> int:
	## A striking sword deals its accrued power, then resets.
	if idx < 0:
		return attack_damage
	var dmg := int(_swords[idx]["power"])
	_swords[idx]["power"] = power_min
	return maxi(dmg, int(power_min))


# ─── Slash ───────────────────────────────────────────────────────────────────

func _begin_slash() -> void:
	# Attack with a random SUMMONED sword
	var candidates: Array[int] = []
	for i in range(ARM_COUNT):
		if _swords[i]["active"]:
			candidates.append(i)
	if candidates.is_empty():
		_begin_summon()
		return
	_attacking_sword = candidates[randi() % candidates.size()]
	attack_damage = _spend_sword(_attacking_sword)  # damage = its current power
	state = State.SLASH
	state_timer = 1.0
	if _anim:
		_anim.play("slash_%d" % _attacking_sword)


func _on_anim_finished(_name: String) -> void:
	if state == State.SLASH:
		disable_attack_hitbox()
		_to_idle(0.35 if phase2 else 0.55)


func _reset_arm_poses() -> void:
	for s: Dictionary in _swords:
		var pivot: Node2D = s["pivot"]
		pivot.position = s["base_pos"]
		pivot.rotation = s["base_rot"]


# Method-track callbacks (shared swing builder)

func _swing_hit_on() -> void:
	enable_attack_hitbox(face_dir)


func _swing_hit_off() -> void:
	disable_attack_hitbox()


func _swing_slash() -> void:
	Fx.slash_effect(global_position + Vector2(face_dir * 60, -60), float(face_dir), true, 0.0, 2.4)


# ─── Dash attack ─────────────────────────────────────────────────────────────

func _begin_dash_wind() -> void:
	state = State.DASH_WIND
	state_timer = 0.5
	# Telegraph: crouch-lean + red pulse
	flash_hit(Color(1.5, 0.5, 0.4))
	if _visual:
		var tw := create_tween()
		tw.tween_property(_visual, "rotation", -0.12 * face_dir, 0.4)


func _begin_dash() -> void:
	state = State.DASH
	state_timer = DASH_TIME
	_dash_dir = face_dir
	# Dash carries the strongest sword's power
	var idx := _strongest_active_sword()
	attack_damage = _spend_sword(idx)
	enable_attack_hitbox(face_dir)
	if _visual:
		var tw := create_tween()
		tw.tween_property(_visual, "rotation", 0.0, 0.2)
	# Speed lines
	Fx.slash_effect(global_position + Vector2(face_dir * 40, -60), float(face_dir), false, 0.0, 1.6)


# ─── Grab-and-throw ──────────────────────────────────────────────────────────

func _begin_grab_wind() -> void:
	state = State.GRAB_WIND
	state_timer = 0.6
	grab_timer = grab_cooldown
	# Telegraph: both lower arms reach wide + yellow pulse (distinct from dash red)
	flash_hit(Color(1.5, 1.3, 0.4))
	for i in [2, 3]:
		var pivot: Node2D = _swords[i]["pivot"]
		var tw := create_tween()
		tw.tween_property(pivot, "rotation", -0.2, 0.5)


func _attempt_grab() -> void:
	# Reach: connects only if the player is close, in front, and vulnerable.
	# Dodge i-frames or an active parry beat it (parry also staggers us).
	for i in [2, 3]:
		var pivot: Node2D = _swords[i]["pivot"]
		var tw := create_tween()
		tw.tween_property(pivot, "rotation", _swords[i]["base_rot"], 0.3)

	if player == null or not is_instance_valid(player):
		_to_idle(0.6)
		return
	var to_player: Vector2 = player.global_position - global_position
	var in_reach: bool = absf(to_player.x) < PLAYER_GRAB_RANGE \
		and to_player.y > -140.0 and to_player.y < 60.0 \
		and signf(to_player.x) == float(face_dir)
	if not in_reach:
		_to_idle(0.8)  # whiffed — punish window
		return
	if player.get("is_parrying"):
		# Parried the grab: boss staggers wide open
		apply_stagger(1.6, Vector2(-face_dir * 60, 0))
		if player.has_method("_try_parry"):
			player._try_parry(global_position, self)
		return
	if player.get("invuln_timer") > 0.0 or player.get("is_rolling"):
		_to_idle(0.8)  # dodged clean through it
		return

	# Seized!
	player.begin_grabbed(self)
	state = State.GRAB_HOLD
	_grab_hold_time = 0.55
	state_timer = 2.0
	Fx.hit_particles(player.global_position, Color(1.0, 0.9, 0.4))


func _throw_player() -> void:
	if player and is_instance_valid(player) and player.get("is_grabbed"):
		var vel := Vector2(face_dir * randf_range(420.0, 560.0), -520.0)
		player.launch_thrown(vel, GRAB_IMPACT, GRAB_LANDING, global_position)
		Fx.slash_effect(_visual.to_global(Vector2(40, -110)), float(face_dir), false, -PI / 5.0, 1.5)
		_screen_pop()
	_to_idle(0.9)


func _screen_pop() -> void:
	# Small camera shake through the player's camera if present
	if player and is_instance_valid(player) and player.has_method("_screen_shake"):
		player._screen_shake(3.5)


# ─── Summon / dismiss swords ─────────────────────────────────────────────────

func _begin_summon() -> void:
	state = State.SUMMON
	state_timer = 0.8
	summon_timer = summon_interval * (0.7 if phase2 else 1.0)
	flash_hit(Color(0.6, 0.6, 1.6))


func _finish_summon() -> void:
	# Choose a new random subset (phase 2 keeps more blades out)
	var min_count := 3 if phase2 else 2
	var count := randi_range(min_count, ARM_COUNT)
	var order := [0, 1, 2, 3]
	order.shuffle()
	var chosen: Array[int] = []
	for i in range(count):
		chosen.append(order[i])
	_set_active_swords(chosen)
	_to_idle(0.4)


func _set_active_swords(indices: Array) -> void:
	for i in range(ARM_COUNT):
		var s: Dictionary = _swords[i]
		var want: bool = i in indices
		if want == s["active"]:
			continue
		s["active"] = want
		var pivot: Node2D = s["pivot"]
		if want:
			s["power"] = power_min
			pivot.visible = true
			pivot.modulate = Color(1, 1, 1, 0)
			var tw := create_tween()
			tw.tween_property(pivot, "modulate:a", 1.0, 0.3)
			Fx.hit_particles(_visual.to_global(s["base_pos"] + Vector2(30, 0)), Color(0.6, 0.8, 1.0))
		else:
			var tw := create_tween()
			tw.tween_property(pivot, "modulate:a", 0.0, 0.3)
			tw.tween_callback(func() -> void:
				if is_instance_valid(pivot) and not s["active"]:
					pivot.visible = false)
			s["power"] = power_min


func active_sword_count() -> int:
	var n := 0
	for s: Dictionary in _swords:
		if s["active"]:
			n += 1
	return n


# ─── Phase 2 ─────────────────────────────────────────────────────────────────

func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO) -> void:
	super.take_damage(amount, knockback)
	# React immediately, even while staggered
	if not is_dead and not phase2 and hp <= max_hp / 2:
		_enter_phase2()


func _enter_phase2() -> void:
	phase2 = true
	flash_hit(Color(1.8, 0.4, 0.4))
	summon_timer = 0.0  # immediate re-summon with more blades
	Fx.parry_spark(global_position + Vector2(0, -110))


# ─── Facing ──────────────────────────────────────────────────────────────────

func _face_player() -> void:
	# Committed states keep their heading
	if state == State.DASH or state == State.GRAB_HOLD or state == State.SLASH:
		return
	if player and is_instance_valid(player):
		var d := 1 if player.global_position.x > global_position.x else -1
		if d != face_dir:
			face_dir = d
			if _visual:
				_visual.scale.x = face_dir
