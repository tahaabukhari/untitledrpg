extends EnemyBase
## BOMBUG - a small winged centipede (black & purple) that flies at the
## player, rolls itself into a ball, and EXPLODES after a 1-second fuse.
##
## Counterplay: the armed bug is stationary and flashing for the whole fuse -
## an easy free hit. Kill it before the boom and it's DEFUSED (normal death,
## full EXP). Let it detonate and it grants nothing. The blast itself routes
## through player.take_damage, so dodge i-frames and parry both beat it.
##
## Rig is code-built (no sprites): 5 alternating body segments, translucent
## flapping wings, glowing eyes. Stats scale with random size, slime-style.

enum State { PATROL, CHASE, ARM }

@export_group("Flight")
@export var patrol_speed: float = 55.0
@export var chase_speed: float = 180.0
@export var wobble_amp: float = 26.0      ## sine weave while chasing
@export var patrol_range: float = 120.0   ## hover-wander radius around home

@export_group("Bomb")
@export var arm_range: float = 72.0       ## roll up when this close (scaled)
@export var fuse_time: float = 1.0        ## seconds between charging and BOOM
@export var explosion_radius: float = 95.0

@export_group("Scale")
@export var min_scale: float = 0.72
@export var max_scale: float = 1.42

const BLACK := Color(0.12, 0.1, 0.16)
const PURPLE := Color(0.45, 0.25, 0.62)
const WING_COLOR := Color(0.75, 0.65, 0.95, 0.4)
const EYE_COLOR := Color(1.0, 0.5, 0.9, 1.0)
const ARMED_GLOW := Color(1.7, 0.55, 0.7, 1.0)

var state: State = State.PATROL
var fuse: float = 0.0
var explosion_damage: int = 14
var size_factor: float = 1.0
var blast_radius_scaled: float = 95.0
var home_position := Vector2.ZERO
var _t: float = 0.0
var _wander_target := Vector2.ZERO
var _wander_timer: float = 0.0
var _visual: Node2D = null
var _wings: Array = []              # [{node, base_rot}]
var _segments: Array = []           # [{node, base_pos}]
var _eyes: Array = []               # Polygon2D glow squares
var _legs: Array = []               # [{node, p0, p1}]
var _face := 1
var _armed_scale: float = 0.0
var _detonated := false


func _enemy_ready() -> void:
	home_position = global_position
	_wander_target = home_position

	# Size scaling: weighted toward "normal", with smaller and larger outliers
	# that noticeably change both the body silhouette and the bomb threat.
	size_factor = _roll_size_factor()
	scale = Vector2(size_factor, size_factor)
	var ratio := inverse_lerp(min_scale, max_scale, size_factor)
	max_hp = int(lerpf(14.0, 30.0, ratio))
	hp = max_hp
	explosion_damage = int(lerpf(10.0, 22.0, ratio))
	blast_radius_scaled = explosion_radius * lerpf(0.8, 1.35, ratio)
	exp_value = lerpf(8.0, 18.0, ratio)
	aggro_range = 640.0

	_build_visual()
	_flash_sprite = _visual


func _build_visual() -> void:
	_visual = Node2D.new()
	_visual.name = "Visual"
	add_child(_visual)

	# Wings first (behind the body): two translucent ellipses on the back.
	for side in [-1, 1]:
		var wing := Polygon2D.new()
		wing.name = "Wing"
		var pts := PackedVector2Array()
		for i in range(10):
			var t := TAU * float(i) / 10.0
			pts.append(Vector2(cos(t) * 3.0, sin(t) * 7.5 - 7.5))
		wing.polygon = pts
		wing.color = WING_COLOR
		wing.position = Vector2(side * 2.0 - 1.0, -3.0)
		wing.rotation = side * 0.35
		wing.z_index = -1
		_visual.add_child(wing)
		_wings.append({"node": wing, "base_rot": side * 0.35})

	# Segmented centipede body: head (front, +x) down to tail, alternating
	# black/purple, sizes tapering.
	var seg_data := [
		[Vector2(6, 0), 3.4, PURPLE],
		[Vector2(2.5, 0.8), 3.0, BLACK],
		[Vector2(-1, 0), 2.7, PURPLE],
		[Vector2(-4.4, 0.8), 2.4, BLACK],
		[Vector2(-7.5, 0), 2.0, PURPLE],
	]
	for sd in seg_data:
		var seg := Polygon2D.new()
		var pts2 := PackedVector2Array()
		for i in range(12):
			var t := TAU * float(i) / 12.0
			pts2.append(Vector2(cos(t), sin(t)) * sd[1])
		seg.polygon = pts2
		seg.color = sd[2]
		seg.position = sd[0]
		_visual.add_child(seg)
		_segments.append({"node": seg, "base_pos": seg.position})

	# Glowing eyes on the head.
	for ey in [-1.2, 1.2]:
		var eye := Polygon2D.new()
		eye.polygon = PackedVector2Array([
			Vector2(-0.6, -0.6), Vector2(0.6, -0.6), Vector2(0.6, 0.6), Vector2(-0.6, 0.6),
		])
		eye.color = EYE_COLOR
		eye.position = Vector2(7.5, ey)
		eye.z_index = 1
		_visual.add_child(eye)
		_segments.append({"node": eye, "base_pos": eye.position})
		_eyes.append(eye)

	# Tiny legs: short dark bristles under the segments.
	for i in range(4):
		var leg := Line2D.new()
		leg.width = 0.8
		leg.default_color = Color(0.2, 0.15, 0.28, 0.9)
		var lx := 4.0 - float(i) * 3.5
		leg.add_point(Vector2(lx, 2.0))
		leg.add_point(Vector2(lx - 0.8, 4.5))
		_visual.add_child(leg)
		_legs.append({"node": leg, "p0": leg.get_point_position(0), "p1": leg.get_point_position(1)})


func _enemy_physics(delta: float) -> void:
	_t += delta
	_animate_visuals(delta)

	match state:
		State.PATROL:
			_process_patrol(delta)
		State.CHASE:
			_process_chase(delta)
		State.ARM:
			_process_arm(delta)

	move_and_slide()

	# Face travel direction (rig is drawn facing +x).
	if state != State.ARM and absf(velocity.x) > 6.0:
		_face = 1 if velocity.x > 0 else -1
		if _visual:
			_visual.scale.x = _face


func _animate_visuals(delta: float) -> void:
	# Wings flutter continuously while the body gets a centipede wave in flight.
	var freq := 28.0 if state == State.CHASE else 20.0
	for w in _wings:
		var wing: Polygon2D = w["node"]
		if state == State.ARM:
			wing.scale = wing.scale.lerp(Vector2(0.25, 0.25), 0.2)
			wing.rotation = lerpf(wing.rotation, 0.0, 0.18)
		else:
			var flutter := sin(_t * freq) * 0.85 + sin(_t * (freq * 1.8)) * 0.18
			wing.scale = wing.scale.lerp(Vector2(0.92, 1.16 + absf(flutter) * 0.08), 0.32)
			wing.rotation = w["base_rot"] + flutter

	_armed_scale = move_toward(_armed_scale, 1.0 if state == State.ARM else 0.0, delta * 7.0)
	var chase_blend := 1.0 if state == State.CHASE else 0.0
	var wave_speed := 7.5 + chase_blend * 2.5
	var wave_amp := 0.35 + chase_blend * 0.55
	var hot_pulse := 0.5 + 0.5 * sin(_t * 12.0)

	for i in range(_segments.size()):
		var sdat: Dictionary = _segments[i]
		var node: Node2D = sdat["node"]
		var base_pos: Vector2 = sdat["base_pos"]
		var phase := _t * wave_speed + float(i) * 0.85
		var live_pos := base_pos + Vector2(0.0, sin(phase) * wave_amp)
		var curl_ang := TAU * float(i) / float(max(_segments.size(), 1)) + _t * 2.8
		var curl_pos := Vector2(cos(curl_ang), sin(curl_ang)) * (3.0 + 0.2 * sin(_t * 10.0 + i))
		if i == 0:
			curl_pos += Vector2(1.4, -0.4)
		node.position = live_pos.lerp(curl_pos, _armed_scale)
		node.rotation = lerpf(0.0, curl_ang + PI * 0.35, _armed_scale * 0.35)
		if state == State.ARM:
			var glow := PURPLE.lerp(ARMED_GLOW, 0.35 + 0.35 * hot_pulse)
			node.modulate = Color.WHITE.lerp(glow, 0.4)
		else:
			node.modulate = Color.WHITE

	for i in range(_eyes.size()):
		var eye: Polygon2D = _eyes[i]
		var blink := 0.5 + 0.5 * sin(_t * (8.0 if state == State.ARM else 4.5) + float(i) * 0.9)
		eye.color = EYE_COLOR.lerp(ARMED_GLOW, _armed_scale * 0.8)
		eye.modulate = Color(1.0, 1.0, 1.0, 0.65 + blink * 0.35)
		eye.scale = Vector2.ONE * lerpf(1.0, 1.45, _armed_scale * blink)

	for i in range(_legs.size()):
		var leg_data: Dictionary = _legs[i]
		var leg: Line2D = leg_data["node"]
		var kick := sin(_t * (10.0 + chase_blend * 4.0) + float(i) * 1.5) * (0.9 + chase_blend * 0.5)
		leg.visible = _armed_scale < 0.7
		leg.set_point_position(0, leg_data["p0"] + Vector2(0, sin(_t * 5.0 + i) * 0.4))
		leg.set_point_position(1, leg_data["p1"] + Vector2(kick, absf(kick) * 0.35))

	if _visual and state != State.ARM:
		_visual.position.y = sin(_t * 3.2) * 1.4
		_visual.rotation = lerpf(_visual.rotation, velocity.x * 0.0018, 0.08)
	elif _visual:
		_visual.position.y = lerpf(_visual.position.y, 0.0, 0.2)


# State logic ---------------------------------------------------------------

func _process_patrol(delta: float) -> void:
	if _can_see_player():
		state = State.CHASE
		return
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_wander_timer = randf_range(1.2, 2.6)
		_wander_target = home_position + Vector2(
			randf_range(-patrol_range, patrol_range), randf_range(-patrol_range * 0.5, patrol_range * 0.5))
	var to_target := _wander_target - global_position
	velocity = velocity.lerp(to_target.normalized() * patrol_speed if to_target.length() > 10.0 else Vector2.ZERO, 0.08)


func _process_chase(delta: float) -> void:
	if not player or not is_instance_valid(player):
		state = State.PATROL
		return
	var to_player := player.global_position + Vector2(0, -42) - global_position
	var dir := to_player.normalized()
	var perp := Vector2(-dir.y, dir.x)
	velocity = velocity.lerp(dir * chase_speed + perp * sin(_t * 6.0) * wobble_amp, 12.0 * delta)

	if to_player.length() < arm_range * scale.x:
		_begin_arm()


func _process_arm(delta: float) -> void:
	velocity = velocity.lerp(Vector2.ZERO, 10.0 * delta)
	if _visual:
		_visual.rotation += delta * 9.0
	fuse -= delta
	var urgency := 1.0 - fuse / fuse_time
	var pulse := 0.5 + 0.5 * sin(_t * lerpf(10.0, 34.0, urgency))
	if _visual:
		_visual.modulate = Color(1.0, 1.0, 1.0).lerp(Color(1.8, 0.5, 0.6), pulse * urgency)
	if fuse <= 0.0:
		_detonate()


func _begin_arm() -> void:
	state = State.ARM
	fuse = fuse_time
	velocity = Vector2.ZERO
	flash_hit(Color(1.6, 0.7, 1.4))
	var idx := 0
	for sdat in _segments:
		var node: Node2D = sdat["node"]
		if node is Line2D:
			node.visible = false
			continue
		var ang := TAU * float(idx) / 7.0
		idx += 1
		var tw := create_tween()
		tw.tween_property(node, "position", Vector2(cos(ang), sin(ang)) * 3.2, 0.18)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _detonate() -> void:
	if is_dead:
		return
	_detonated = true
	var pos := global_position
	var blast_radius := blast_radius_scaled
	Fx.bomb_explosion(pos, blast_radius)

	if player and is_instance_valid(player) \
			and player.global_position.distance_to(pos) <= blast_radius:
		var kb := (player.global_position - pos).normalized() * 300.0 + Vector2(0, -140)
		if player.has_method("take_damage"):
			player.take_damage(explosion_damage, pos, kb, self)
		if player.has_method("_screen_shake"):
			player._screen_shake(5.0)

	exp_value = 0.0
	if _visual:
		_visual.visible = false
	_die()


func _die() -> void:
	if state == State.ARM and not _detonated:
		Fx.bomb_defuse(global_position, 30.0 * scale.x)
	super._die()


func _roll_size_factor() -> float:
	var roll := randf()
	if roll < 0.22:
		return randf_range(min_scale, 0.9)
	if roll < 0.78:
		return randf_range(0.95, 1.15)
	return randf_range(1.2, max_scale)
