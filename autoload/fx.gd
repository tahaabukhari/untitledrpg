extends Node2D
## Fx — scene-safe VFX / damage-number manager (autoload).
## Transient effects (particles, arcs, slashes, damage numbers, beams) are
## parented HERE instead of the current scene, so a scene change mid-effect
## never orphans them. Every tween callback is guarded with is_instance_valid().

# ─── Colors ──────────────────────────────────────────────────────────────────
const HIT_PARTICLE_COLOR := Color(1.0, 0.95, 0.6, 1.0)
const DAMAGE_COLOR := Color(1.0, 0.3, 0.3, 1.0)
const PLAYER_DAMAGE_COLOR := Color(1.0, 0.55, 0.15, 1.0)
const SWING_ARC_COLOR := Color(1.0, 1.0, 0.8, 0.95)
const SLASH_COLOR := Color(1.0, 1.0, 1.0, 0.9)


var _last_scene: Node = null


func _process(_delta: float) -> void:
	# Clear leftover effects whenever the scene changes so nothing lingers
	# visually across levels (nodes here are already crash-safe regardless).
	if not is_inside_tree():
		return
	var scene := get_tree().current_scene
	if scene == _last_scene:
		return
	_last_scene = scene
	for child in get_children():
		child.queue_free()


# ─── Hit particles ───────────────────────────────────────────────────────────

func hit_particles(pos: Vector2, color: Color = HIT_PARTICLE_COLOR) -> void:
	for i in range(5):
		var p := ColorRect.new()
		p.size = Vector2(2, 2)
		p.color = color
		p.z_index = 100
		add_child(p)
		p.global_position = pos + Vector2(randf_range(-6, 6), randf_range(-6, 6))
		var tw := p.create_tween()
		tw.set_parallel(true)
		tw.tween_property(p, "global_position:y", p.global_position.y - randf_range(8, 16), 0.25)
		tw.tween_property(p, "modulate:a", 0.0, 0.25)
		tw.chain().tween_callback(func() -> void:
			if is_instance_valid(p):
				p.queue_free())


# ─── Damage numbers ──────────────────────────────────────────────────────────

func damage_number(pos: Vector2, amount: int, color: Color = DAMAGE_COLOR) -> void:
	var label := Label.new()
	label.text = str(amount)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", color)
	label.z_index = 100
	add_child(label)
	label.global_position = pos + Vector2(randf_range(-8, 8), -20)

	var tw := label.create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "global_position:y", label.global_position.y - 30, 0.6).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "modulate:a", 0.0, 0.6).set_delay(0.3)
	tw.chain().tween_callback(func() -> void:
		if is_instance_valid(label):
			label.queue_free())


# ─── Swing arc (light weapon swoosh) ─────────────────────────────────────────

func swing_arc(origin: Vector2, dir: float) -> void:
	var arc := Line2D.new()
	arc.width = 4.0
	arc.default_color = SWING_ARC_COLOR
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

	add_child(arc)
	arc.global_position = origin

	var tw := arc.create_tween()
	tw.set_parallel(true)
	tw.tween_property(arc, "width", 0.0, 0.2).set_ease(Tween.EASE_IN)
	tw.tween_property(arc, "modulate:a", 0.0, 0.22)
	tw.chain().tween_callback(func() -> void:
		if is_instance_valid(arc):
			arc.queue_free())

	for i in range(5):
		var p := ColorRect.new()
		p.size = Vector2(3, 3)
		p.color = Color(1.0, 0.9, 0.5, 0.9)
		p.z_index = 100
		add_child(p)
		p.global_position = origin + Vector2(dir * randf_range(10, 28), randf_range(-12, 12))
		var tw2 := p.create_tween()
		tw2.set_parallel(true)
		tw2.tween_property(p, "global_position", p.global_position + Vector2(dir * randf_range(6, 16), randf_range(-8, 8)), 0.22)
		tw2.tween_property(p, "modulate:a", 0.0, 0.22)
		tw2.chain().tween_callback(func() -> void:
			if is_instance_valid(p):
				p.queue_free())


# ─── Parry spark (perfect-parry deflect burst) ───────────────────────────────

func parry_spark(pos: Vector2) -> void:
	# Bright radial burst of lines + a flash circle
	for i in range(8):
		var angle := TAU * float(i) / 8.0 + randf_range(-0.15, 0.15)
		var line := Line2D.new()
		line.width = 3.0
		line.default_color = Color(1.0, 0.95, 0.5, 1.0)
		line.z_index = 110
		line.add_point(Vector2.ZERO)
		line.add_point(Vector2(cos(angle), sin(angle)) * randf_range(10, 18))
		add_child(line)
		line.global_position = pos
		var tw := line.create_tween()
		tw.set_parallel(true)
		tw.tween_property(line, "scale", Vector2(1.8, 1.8), 0.18).set_ease(Tween.EASE_OUT)
		tw.tween_property(line, "modulate:a", 0.0, 0.2)
		tw.chain().tween_callback(func() -> void:
			if is_instance_valid(line):
				line.queue_free())

	# Flash ring
	var flash := Line2D.new()
	flash.width = 4.0
	flash.default_color = Color(1.0, 1.0, 0.9, 0.9)
	flash.z_index = 110
	flash.closed = true
	for i in range(17):
		var t := TAU * float(i) / 16.0
		flash.add_point(Vector2(cos(t), sin(t)) * 8.0)
	add_child(flash)
	flash.global_position = pos
	var tw2 := flash.create_tween()
	tw2.set_parallel(true)
	tw2.tween_property(flash, "scale", Vector2(3.0, 3.0), 0.22).set_ease(Tween.EASE_OUT)
	tw2.tween_property(flash, "modulate:a", 0.0, 0.22)
	tw2.chain().tween_callback(func() -> void:
		if is_instance_valid(flash):
			flash.queue_free())


# ─── Slash effect (bright sword arc) ─────────────────────────────────────────
## `dir` is the horizontal facing sign (1/-1). `angle` rotates the whole slash
## plane (radians, world space) for directional attacks; 0 = horizontal slash.

func slash_effect(origin: Vector2, dir: float, downward: bool, angle: float = 0.0, arc_scale: float = 1.0) -> void:
	var arc := Line2D.new()
	arc.width = 12.0 * arc_scale
	arc.default_color = SLASH_COLOR
	arc.z_index = 105
	arc.begin_cap_mode = Line2D.LINE_CAP_ROUND
	arc.end_cap_mode = Line2D.LINE_CAP_ROUND

	var arc_radius := 26.0 * arc_scale

	var start_angle: float
	var end_angle: float
	if downward:
		start_angle = -PI * 0.6
		end_angle = PI * 0.4
	else:
		start_angle = PI * 0.6
		end_angle = -PI * 0.4

	for i in range(12):
		var t: float = float(i) / 11.0
		var a: float = lerpf(start_angle, end_angle, t)
		var pt := Vector2(cos(a) * arc_radius * dir, sin(a) * arc_radius)
		pt += Vector2(dir * 20 * arc_scale, -5 * arc_scale)
		pt = pt.rotated(angle)
		arc.add_point(pt)

	add_child(arc)
	arc.global_position = origin

	var tw := arc.create_tween()
	tw.set_parallel(true)
	tw.tween_property(arc, "width", 0.0, 0.15).set_ease(Tween.EASE_OUT)
	tw.tween_property(arc, "modulate:a", 0.0, 0.18)
	tw.chain().tween_callback(func() -> void:
		if is_instance_valid(arc):
			arc.queue_free())

	# Sharp sparks along the slash direction
	var spark_dir := Vector2(dir, 0).rotated(angle)
	for i in range(4):
		var p := ColorRect.new()
		p.size = Vector2(8, 2)
		p.color = Color(1.0, 1.0, 1.0, 0.8)
		p.z_index = 100
		add_child(p)
		p.global_position = origin + spark_dir * randf_range(15, 30) + Vector2(randf_range(-8, 8), randf_range(-15, 15))
		p.rotation = angle + deg_to_rad(randf_range(-20, 20))
		var tw2 := p.create_tween()
		tw2.set_parallel(true)
		tw2.tween_property(p, "global_position", p.global_position + spark_dir * randf_range(10, 20) + Vector2(0, randf_range(-10, 10)), 0.15)
		tw2.tween_property(p, "scale", Vector2(0.1, 0.1), 0.15)
		tw2.tween_property(p, "modulate:a", 0.0, 0.15)
		tw2.chain().tween_callback(func() -> void:
			if is_instance_valid(p):
				p.queue_free())
