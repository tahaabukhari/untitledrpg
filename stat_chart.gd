extends Control

# Animated radar/spider chart for RPG stats
# Axes: HP, DEF, STA, MANA

const STAT_NAMES := ["HP", "DEF", "STA", "MANA"]
const MAX_STAT := 20.0 # max possible stat value for scaling
const AXIS_COUNT := 4

@export var chart_radius := 80.0
@export var animation_duration := 0.4

# Colors
var grid_color := Color(0.4, 0.4, 0.6, 0.3)
var outline_color := Color(0.3, 0.8, 1.0, 0.9)
var fill_color := Color(0.2, 0.5, 0.8, 0.25)
var axis_color := Color(0.5, 0.5, 0.7, 0.4)
var label_color := Color(0.85, 0.85, 0.95, 1.0)
var glow_color := Color(0.3, 0.8, 1.0, 0.4)

var current_values := [0.0, 0.0, 0.0, 0.0]
var target_values := [0.0, 0.0, 0.0, 0.0]
var display_values := [0.0, 0.0, 0.0, 0.0]

var _tween: Tween = null

var pixel_font: Font = null

func _ready():
	# Try to load the pixel font
	var font_res = load("res://fonts/PressStart2P.ttf")
	if font_res:
		pixel_font = font_res

func set_stats(hp: float, def_val: float, sta: float, mana: float, animate := true) -> void:
	target_values = [hp, def_val, sta, mana]
	
	if animate:
		_animate_to_target()
	else:
		display_values = target_values.duplicate()
		current_values = target_values.duplicate()
		queue_redraw()

func _animate_to_target() -> void:
	if _tween:
		_tween.kill()
	
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_OUT)
	_tween.set_trans(Tween.TRANS_CUBIC)
	
	# We animate a progress float from 0 to 1
	var start_vals = display_values.duplicate()
	_tween.tween_method(
		func(progress: float):
			for i in range(AXIS_COUNT):
				display_values[i] = lerp(start_vals[i], target_values[i], progress)
			queue_redraw(),
		0.0, 1.0, animation_duration
	)
	_tween.tween_callback(func():
		current_values = target_values.duplicate()
	)

func _draw() -> void:
	var center = size / 2.0
	var angles := []
	for i in range(AXIS_COUNT):
		angles.append(-PI / 2.0 + i * (TAU / AXIS_COUNT))
	
	# Draw grid rings (3 concentric)
	for ring in range(1, 4):
		var r = chart_radius * ring / 3.0
		var ring_points := PackedVector2Array()
		for i in range(AXIS_COUNT):
			ring_points.append(center + Vector2(cos(angles[i]), sin(angles[i])) * r)
		ring_points.append(ring_points[0])
		draw_polyline(ring_points, grid_color, 1.0, true)
	
	# Draw axis lines
	for i in range(AXIS_COUNT):
		var end_pt = center + Vector2(cos(angles[i]), sin(angles[i])) * chart_radius
		draw_line(center, end_pt, axis_color, 1.0, true)
	
	# Draw stat polygon (filled + outlined + glow)
	var stat_points := PackedVector2Array()
	for i in range(AXIS_COUNT):
		var ratio = clamp(display_values[i] / MAX_STAT, 0.0, 1.0)
		var pt = center + Vector2(cos(angles[i]), sin(angles[i])) * chart_radius * ratio
		stat_points.append(pt)
	
	if stat_points.size() >= 3:
		# Fill
		draw_colored_polygon(stat_points, fill_color)
		
		# Glow outline (thicker, semi-transparent)
		var glow_pts = stat_points.duplicate()
		glow_pts.append(stat_points[0])
		draw_polyline(glow_pts, glow_color, 4.0, true)
		
		# Sharp outline
		draw_polyline(glow_pts, outline_color, 2.0, true)
		
		# Draw vertex dots
		for pt in stat_points:
			draw_circle(pt, 4.0, outline_color)
			draw_circle(pt, 2.0, Color.WHITE)
	
	# Draw labels
	var font_to_use = pixel_font if pixel_font else ThemeDB.fallback_font
	var label_font_size := 10
	
	for i in range(AXIS_COUNT):
		var label_offset = Vector2(cos(angles[i]), sin(angles[i])) * (chart_radius + 22.0)
		var label_pos = center + label_offset
		var text = STAT_NAMES[i] + " " + str(int(display_values[i]))
		var text_size = font_to_use.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, label_font_size)
		
		# Center the label on the calculated position
		label_pos.x -= text_size.x / 2.0
		label_pos.y += text_size.y / 4.0
		
		draw_string(font_to_use, label_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, label_font_size, label_color)
