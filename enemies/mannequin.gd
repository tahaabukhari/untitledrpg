extends EnemyBase
## Mannequin — stationary training dummy. Effectively unkillable (regenerates),
## reacts to hits (flash, damage numbers, wobble), and shows a floating
## DPS / last-hit readout. With `attacks` enabled it performs slow, clearly
## telegraphed swings on an interval so you can practice parry/dodge timing.

@export_group("Dummy")
@export var unkillable: bool = true          ## Never drops below 1 HP
@export var regen: bool = true               ## Refill HP after a quiet period
@export var regen_delay: float = 4.0

@export_group("Parry Practice")
@export var attacks: bool = false            ## Telegraphed swing on an interval
@export var swing_interval: float = 2.5
@export var swing_length: float = 1.2        ## Slow = readable telegraph

const DPS_WINDOW := 3.0  # seconds of hits counted toward the DPS readout

var _visual: Node2D = null
var _arm_pivot: Node2D = null
var _anim: AnimationPlayer = null
var _readout: Label = null
var _hits: Array = []            # [[time_sec, amount], ...]
var _last_hit_amount: int = 0
var _last_hit_time: float = 0.0
var _swing_timer: float = 0.0
var _face_dir: int = 1
var _swinging := false


func _enemy_ready() -> void:
	max_hp = 1000000
	hp = max_hp
	exp_value = 0.0
	attack_damage = 8
	aggro_range = 0.0  # never aggros — it's furniture

	_build_visual()
	setup_attack_hitbox(Vector2(34, 16), Vector2(22, -14))
	_build_swing_animation()
	_build_readout()
	_swing_timer = swing_interval
	_flash_sprite = _visual


func _build_visual() -> void:
	## Simple layered wooden dummy, built in code (programmatic-UI convention).
	_visual = Node2D.new()
	_visual.name = "Visual"
	add_child(_visual)

	var wood := Color(0.45, 0.3, 0.16)
	var wood_dark := Color(0.32, 0.2, 0.1)
	var wood_light := Color(0.55, 0.4, 0.22)

	# Post (base pole)
	_visual.add_child(_make_rect_poly(Vector2(-3, -6), Vector2(6, 32), wood_dark))
	# Base foot
	_visual.add_child(_make_rect_poly(Vector2(-12, 22), Vector2(24, 5), wood_dark))
	# Torso
	_visual.add_child(_make_rect_poly(Vector2(-8, -26), Vector2(16, 22), wood))
	# Chest strap detail
	_visual.add_child(_make_rect_poly(Vector2(-8, -18), Vector2(16, 3), wood_dark))
	# Head
	var head := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(12):
		var t := TAU * float(i) / 12.0
		pts.append(Vector2(0, -33) + Vector2(cos(t), sin(t)) * 7.0)
	head.polygon = pts
	head.color = wood_light
	_visual.add_child(head)

	# Arm pivot at the shoulder, holding a swinging plank
	_arm_pivot = Node2D.new()
	_arm_pivot.name = "ArmPivot"
	_arm_pivot.position = Vector2(6, -22)
	_visual.add_child(_arm_pivot)
	var arm := _make_rect_poly(Vector2(0, -2), Vector2(20, 4), wood_light)
	arm.name = "Arm"
	_arm_pivot.add_child(arm)


func _make_rect_poly(pos: Vector2, size: Vector2, color: Color) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = PackedVector2Array([
		pos, pos + Vector2(size.x, 0), pos + size, pos + Vector2(0, size.y),
	])
	p.color = color
	return p


func _build_swing_animation() -> void:
	## Reuses the shared directional swing builder on the mannequin's own rig.
	_anim = AnimationPlayer.new()
	_anim.name = "AnimPlayer"
	add_child(_anim)

	var swing := WeaponAnimator.make_directional_swing({}, 0.0, {
		"length": swing_length,
		"arm_nodes": ["Visual/ArmPivot"],
		"arm_bases": [Vector2(6, -22)],
		"arm_base_rots": [0.0],
		"weapon_node": "",
		"reach": 4.0,
		"windup": 1.4,
		"follow": 1.2,
		"hit_start": swing_length * 0.42,
		"hit_end": swing_length * 0.62,
		"slash_time": swing_length * 0.46,
		"enable_method": "_swing_hit_on",
		"disable_method": "_swing_hit_off",
		"slash_method": "_swing_slash",
	})
	var lib := AnimationLibrary.new()
	lib.add_animation("swing", swing)
	_anim.add_animation_library("", lib)
	_anim.animation_finished.connect(_on_swing_finished)


func _build_readout() -> void:
	_readout = Label.new()
	_readout.text = "DPS 0.0"
	_readout.add_theme_font_size_override("font_size", 10)
	_readout.add_theme_color_override("font_color", Color(0.95, 0.9, 0.6))
	_readout.add_theme_constant_override("outline_size", 3)
	_readout.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_readout.position = Vector2(-40, -62)
	_readout.size = Vector2(80, 14)
	_readout.z_index = 50
	add_child(_readout)


func _enemy_physics(delta: float) -> void:
	# Settle onto the floor, otherwise stationary
	if not is_on_floor():
		velocity.y += gravity * delta
	velocity.x = 0.0
	move_and_slide()

	var now := Time.get_ticks_msec() / 1000.0

	# Rolling DPS readout decay
	_prune_hits(now)
	_update_readout(now)

	# Regen after a quiet period
	if regen and hp < max_hp and now - _last_hit_time > regen_delay:
		hp = max_hp
		flash_hit(Color(0.5, 1.0, 0.5))

	# Parry practice swings
	if attacks and not _swinging:
		_swing_timer -= delta
		if _swing_timer <= 0.0:
			_begin_swing()


func take_damage(amount: int, _knockback: Vector2 = Vector2.ZERO) -> void:
	## Dummy version: no knockback, no death (by default), tracks DPS.
	if is_dead:
		return
	hp -= amount
	if unkillable and hp < 1:
		hp = 1
	flash_hit()
	Fx.damage_number(global_position + Vector2(0, -20), amount)

	var now := Time.get_ticks_msec() / 1000.0
	_hits.append([now, amount])
	_last_hit_amount = amount
	_last_hit_time = now
	_update_readout(now)
	_wobble()

	if hp <= 0:
		_die()


func _wobble() -> void:
	if not _visual:
		return
	var tw := create_tween()
	tw.tween_property(_visual, "rotation", 0.12, 0.05)
	tw.tween_property(_visual, "rotation", -0.08, 0.08)
	tw.tween_property(_visual, "rotation", 0.0, 0.1)


func _prune_hits(now: float) -> void:
	while _hits.size() > 0 and now - _hits[0][0] > DPS_WINDOW:
		_hits.pop_front()


func _update_readout(now: float) -> void:
	if not _readout:
		return
	_prune_hits(now)
	var total := 0
	for h in _hits:
		total += h[1]
	var dps := float(total) / DPS_WINDOW
	if _hits.is_empty():
		_readout.text = "DPS 0.0"
	else:
		_readout.text = "DPS %.1f | LAST %d" % [dps, _last_hit_amount]


# ─── Parry-practice swing ────────────────────────────────────────────────────

func _begin_swing() -> void:
	_swinging = true
	_swing_timer = swing_interval
	# Face the player so the swing (and its hitbox) can be parried head-on
	if player and is_instance_valid(player):
		_face_dir = 1 if player.global_position.x > global_position.x else -1
	if _visual:
		_visual.scale.x = _face_dir
	# Telegraph glow — bright red rising during the windup
	if _visual:
		_visual.modulate = Color(1, 1, 1)
		var tw := create_tween()
		tw.tween_property(_visual, "modulate", Color(1.5, 0.7, 0.6), swing_length * 0.4)
		tw.tween_property(_visual, "modulate", Color(1, 1, 1), swing_length * 0.3)
	if _anim:
		_anim.play("swing")


func _on_swing_finished(_name: String) -> void:
	_swinging = false
	disable_attack_hitbox()


func _on_staggered() -> void:
	# A parried swing stops immediately
	if _swinging and _anim:
		_anim.stop()
		_swinging = false
		if _arm_pivot:
			_arm_pivot.rotation = 0.0
			_arm_pivot.position = Vector2(6, -22)
		if _visual:
			_visual.modulate = Color(1, 1, 1)
	_swing_timer = swing_interval


# Method-track callbacks (fired by the shared swing builder)

func _swing_hit_on() -> void:
	enable_attack_hitbox(_face_dir)


func _swing_hit_off() -> void:
	disable_attack_hitbox()


func _swing_slash() -> void:
	Fx.slash_effect(global_position + Vector2(_face_dir * 16, -16), float(_face_dir), true, 0.0, 0.7)
