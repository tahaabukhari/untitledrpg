extends Control
## Custom ring-shaped attack button with charge progress arc and glow.

signal attack_tapped
signal attack_charged

@export var ring_radius := 42.0
@export var ring_thickness := 4.0
@export var charge_time := 1.0  # seconds to fully charge

var charge_progress := 0.0  # 0.0 → 1.0
var is_held := false
var is_fully_charged := false
var glow_tween: Tween = null

# Colors
var ring_color := Color(0.7, 0.7, 0.7, 0.8)
var charge_color := Color(1.0, 0.85, 0.2, 1.0)
var full_color := Color(1.0, 0.95, 0.4, 1.0)
var text_color := Color(1.0, 1.0, 1.0, 0.9)

func _ready() -> void:
	# Set minimum size so the control has a clickable area
	custom_minimum_size = Vector2(ring_radius * 2 + 20, ring_radius * 2 + 20)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _process(delta: float) -> void:
	if is_held and not is_fully_charged:
		charge_progress = minf(charge_progress + delta / charge_time, 1.0)
		if charge_progress >= 1.0:
			is_fully_charged = true
			_start_glow()
		queue_redraw()


func _draw() -> void:
	var center := size / 2.0

	# Background circle fill (subtle)
	draw_circle(center, ring_radius, Color(0.15, 0.15, 0.2, 0.5))

	# Outer ring
	_draw_arc_outline(center, ring_radius, 0, TAU, ring_color, ring_thickness)

	# Charge arc (fills clockwise from top)
	if charge_progress > 0.0:
		var arc_angle := charge_progress * TAU
		var c := charge_color if not is_fully_charged else full_color
		_draw_arc_outline(center, ring_radius, -PI / 2.0, -PI / 2.0 + arc_angle, c, ring_thickness + 2.0)

	# Inner glow when fully charged
	if is_fully_charged:
		draw_circle(center, ring_radius - 4, Color(1.0, 0.95, 0.4, 0.15))

	# "ATK" text
	var font := ThemeDB.fallback_font
	var font_size := 16
	var text := "ATK"
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	draw_string(font, center - Vector2(text_size.x / 2.0, -text_size.y / 4.0), text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, text_color)


func _draw_arc_outline(center: Vector2, radius: float, start_angle: float, end_angle: float, color: Color, width: float) -> void:
	var points := 32
	var arc_points := PackedVector2Array()
	for i in range(points + 1):
		var t := float(i) / float(points)
		var angle := lerpf(start_angle, end_angle, t)
		arc_points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	if arc_points.size() >= 2:
		draw_polyline(arc_points, color, width, true)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_on_press()
		else:
			_on_release()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_on_press()
			else:
				_on_release()


func _on_press() -> void:
	is_held = true
	charge_progress = 0.0
	is_fully_charged = false
	if glow_tween:
		glow_tween.kill()
	modulate = Color.WHITE
	queue_redraw()


func _on_release() -> void:
	if not is_held:
		return
	is_held = false
	if glow_tween:
		glow_tween.kill()
	modulate = Color.WHITE

	if is_fully_charged:
		attack_charged.emit()
	else:
		attack_tapped.emit()

	charge_progress = 0.0
	is_fully_charged = false
	queue_redraw()


func _start_glow() -> void:
	if glow_tween:
		glow_tween.kill()
	glow_tween = create_tween().set_loops()
	glow_tween.tween_property(self, "modulate", Color(1.3, 1.3, 1.0, 1.0), 0.3)
	glow_tween.tween_property(self, "modulate", Color.WHITE, 0.3)
	queue_redraw()
