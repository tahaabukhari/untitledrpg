extends Control

# Custom RPG HUD drawn via _draw()
# Features: pixel heart HP, styled stamina/mana bars, class label

var pixel_font: Font = null

# Current display values (for animation)
var display_health := 0.0
var display_stamina := 0.0
var display_mana := 0.0
var display_saturation := 100.0
var display_exp := 0.0

# Target values
var target_health := 100.0
var max_health := 100.0
var target_stamina := 100.0
var max_stamina := 100.0
var target_mana := 0.0
var max_mana := 0.0
var target_saturation := 100.0
var target_exp := 0.0
var max_exp := 100.0
var current_level := 1
var cls_name := "Warrior"

# Circle preview config (scaled 30% up)
const CIRCLE_RADIUS := 39.0
const CIRCLE_CENTER_X := 52.0
const CIRCLE_CENTER_Y := 58.0
const ARC_WIDTH := 5.0

# Heart config (scaled 20% up)
const HEART_SIZE := 22.0
const HEART_SPACING := 6.0
const HP_PER_HEART := 10.0

# Food config
const FOOD_SIZE := 22.0
const FOOD_SPACING := 6.0
const SAT_PER_FOOD := 10.0

# Bar config (scaled 20% up)
const BAR_WIDTH := 166.0
const BAR_HEIGHT := 14.0
const BAR_SPACING := 8.0

# Position offsets — shifted right for larger circle
const HUD_X := 119.0
const HUD_Y := 30.0

# Colors
const HEART_FULL := Color(0.9, 0.15, 0.2, 1.0)
const HEART_HALF := Color(0.9, 0.15, 0.2, 0.5)
const HEART_EMPTY := Color(0.25, 0.2, 0.2, 0.6)
const HEART_OUTLINE := Color(0.15, 0.1, 0.1, 0.9)

const STA_FILL := Color(0.15, 0.7, 0.85, 1.0)
const STA_BG := Color(0.1, 0.15, 0.2, 0.8)
const STA_BORDER := Color(0.25, 0.55, 0.7, 0.7)

const MANA_FILL := Color(0.5, 0.3, 0.85, 1.0)
const MANA_BG := Color(0.12, 0.08, 0.2, 0.8)
const MANA_BORDER := Color(0.45, 0.3, 0.7, 0.7)

const BAR_BORDER_COLOR := Color(0.2, 0.2, 0.25, 0.9)
const LABEL_COLOR := Color(0.75, 0.75, 0.82, 1.0)
const CLASS_COLOR := Color(0.85, 0.75, 0.4, 1.0)

# Food colors
const FOOD_FULL := Color(0.85, 0.45, 0.2, 1.0)
const FOOD_HALF := Color(0.85, 0.45, 0.2, 0.5)
const FOOD_EMPTY := Color(0.2, 0.2, 0.2, 0.6)

# EXP ring and Circle colors
const EXP_FULL := Color(0.2, 0.8, 0.3, 1.0)
const EXP_BG := Color(0.7, 0.75, 0.8, 0.4)
const CIRCLE_BG := Color(0.06, 0.06, 0.1, 0.9)
const CIRCLE_BORDER := Color(0.25, 0.25, 0.4, 0.5)

var _tween: Tween = null

signal inv_button_pressed
signal profile_button_pressed

func _ready():
	pixel_font = load("res://fonts/PressStart2P.ttf")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_create_inv_button()
	_create_profile_button()

func update_hud(health: float, p_max_health: float, stamina: float, p_max_stamina: float, mana_val: float, p_max_mana: float, p_class: String = "", saturation: float = -1.0, exp_val: float = -1.0, p_max_exp: float = -1.0, level: int = -1) -> void:
	target_health = health
	max_health = p_max_health
	target_stamina = stamina
	max_stamina = p_max_stamina
	target_mana = mana_val
	max_mana = p_max_mana
	if saturation >= 0.0:
		target_saturation = saturation
	if exp_val >= 0.0:
		target_exp = exp_val
	if p_max_exp >= 0.0:
		max_exp = p_max_exp
	if level >= 1:
		current_level = level
	if p_class != "":
		cls_name = p_class
	
	# Animate smoothly
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_OUT)
	_tween.set_trans(Tween.TRANS_CUBIC)
	
	var start_h = display_health
	var start_s = display_stamina
	var start_m = display_mana
	var start_sat = display_saturation
	var start_exp = display_exp
	
	_tween.tween_method(
		func(t: float):
			display_health = lerp(start_h, target_health, t)
			display_stamina = lerp(start_s, target_stamina, t)
			display_mana = lerp(start_m, target_mana, t)
			display_saturation = lerp(start_sat, target_saturation, t)
			display_exp = lerp(start_exp, target_exp, t)
			queue_redraw(),
		0.0, 1.0, 0.25
	)

func set_immediate(health: float, p_max_health: float, stamina: float, p_max_stamina: float, mana_val: float, p_max_mana: float, p_class: String = "", saturation: float = -1.0, exp_val: float = -1.0, p_max_exp: float = -1.0, level: int = -1) -> void:
	target_health = health
	max_health = p_max_health
	display_health = health
	target_stamina = stamina
	max_stamina = p_max_stamina
	display_stamina = stamina
	target_mana = mana_val
	max_mana = p_max_mana
	display_mana = mana_val
	if saturation >= 0.0:
		target_saturation = saturation
		display_saturation = saturation
	if exp_val >= 0.0:
		target_exp = exp_val
		display_exp = exp_val
	if p_max_exp >= 0.0:
		max_exp = p_max_exp
	if level >= 1:
		current_level = level
	if p_class != "":
		cls_name = p_class
	queue_redraw()

func _draw() -> void:
	var font = pixel_font if pixel_font else ThemeDB.fallback_font
	var y_cursor := HUD_Y
	
	# === Player Preview Circle + Saturation Arc ===
	_draw_player_circle(font)
	
	# === Hearts (no class label — removed) ===
	# (class label removed — will be shown elsewhere)
	
	# === Hearts ===
	var total_hearts = int(ceil(max_health / HP_PER_HEART))
	
	for i in range(total_hearts):
		var hx = HUD_X + i * (HEART_SIZE + HEART_SPACING)
		var hy = y_cursor
		var heart_val = display_health - (i * HP_PER_HEART)
		var fill_r = clamp(heart_val / HP_PER_HEART, 0.0, 1.0)
		_draw_pixel_heart(Vector2(hx, hy), HEART_SIZE, fill_r)
	
	y_cursor += HEART_SIZE + BAR_SPACING + 2
	
	# === Stamina Bar ===
	_draw_stat_bar(Vector2(HUD_X, y_cursor), "STA", display_stamina, max_stamina, STA_FILL, STA_BG, STA_BORDER, font)
	y_cursor += BAR_HEIGHT + BAR_SPACING + 4
	
	# === Mana Bar ===
	if max_mana > 0:
		_draw_stat_bar(Vector2(HUD_X, y_cursor), "MP", display_mana, max_mana, MANA_FILL, MANA_BG, MANA_BORDER, font)

	# === Food / Saturation (Right Side) ===
	var max_food = 10
	
	for i in range(max_food):
		# Draw from right to left, moved 30px further left (offset 60.0 instead of 30.0)
		var fx = size.x - 60.0 - i * (FOOD_SIZE + FOOD_SPACING)
		var fy = HUD_Y  # Parallel to health bars
		var food_val = display_saturation - (i * SAT_PER_FOOD)
		var fill_r = clamp(food_val / SAT_PER_FOOD, 0.0, 1.0)
		_draw_pixel_food(Vector2(fx, fy), FOOD_SIZE, fill_r)

func _draw_player_circle(font: Font) -> void:
	var cx = CIRCLE_CENTER_X
	var cy = CIRCLE_CENTER_Y
	
	# Background arc track (silver ring)
	draw_arc(Vector2(cx, cy), CIRCLE_RADIUS, 0, TAU, 64, EXP_BG, ARC_WIDTH + 2, true)
	
	# Inner circle
	draw_circle(Vector2(cx, cy), CIRCLE_RADIUS - ARC_WIDTH - 1, CIRCLE_BG)
	
	# Inner circle border
	draw_arc(Vector2(cx, cy), CIRCLE_RADIUS - ARC_WIDTH - 1, 0, TAU, 64, CIRCLE_BORDER, 1.5, true)
	
	# Player silhouette placeholder text
	if pixel_font:
		draw_string(pixel_font, Vector2(cx - 8, cy + 4), "??", HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color(0.35, 0.35, 0.45, 0.4))
	
	# EXP arc (green ring, fills clockwise from bottom)
	var exp_ratio = clamp(display_exp / max_exp, 0.0, 1.0) if max_exp > 0 else 0.0
	if exp_ratio > 0.0:
		var start_angle = PI / 2.0  # Bottom
		var end_angle = start_angle + TAU * exp_ratio
		
		draw_arc(Vector2(cx, cy), CIRCLE_RADIUS, start_angle, end_angle, 64, EXP_FULL, ARC_WIDTH, true)
	
	# Level text below circle
	var lvl_text = "LVL " + str(current_level)
	draw_string(font, Vector2(cx - 16, cy + CIRCLE_RADIUS + 14), lvl_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.9, 0.9, 0.9, 1.0))

func _draw_pixel_heart(pos: Vector2, s: float, fill_ratio: float) -> void:
	# Hear center
	var cx = pos.x + s / 2.0
	var cy = pos.y + s / 2.0
	
	# Heart polygon points (normalized -1 to 1, then scaled)
	var heart_points := PackedVector2Array()
	var num_segments := 30
	for i in range(num_segments + 1):
		var t = float(i) / float(num_segments) * TAU
		var hx = 16.0 * pow(sin(t), 3)
		var hy = -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		var scale_factor = s / 36.0
		heart_points.append(Vector2(cx + hx * scale_factor, cy + hy * scale_factor - s * 0.05))
	
	# Draw dark outline
	if heart_points.size() >= 3:
		var outline_points := PackedVector2Array()
		var outline_scale = 1.15
		for pt in heart_points:
			var dx = pt.x - cx
			var dy = pt.y - (cy - s * 0.05)
			outline_points.append(Vector2(cx + dx * outline_scale, (cy - s * 0.05) + dy * outline_scale))
		draw_colored_polygon(outline_points, HEART_OUTLINE)
	
	# Draw empty background heart
	if heart_points.size() >= 3:
		draw_colored_polygon(heart_points, HEART_EMPTY)
	
	# Draw filled partial heart using clipped polygon
	if fill_ratio > 0.0 and heart_points.size() >= 3:
		var clip_x = pos.x + s * fill_ratio
		var clipped_heart = clip_polygon_left(heart_points, clip_x)
		if clipped_heart.size() >= 3:
			draw_colored_polygon(clipped_heart, HEART_FULL)
		
		# Draw highlight shimmer (small bright spot on upper-left bump) ONLY if the left side is drawn
		var shimmer_pos = Vector2(cx - s * 0.18, cy - s * 0.2)
		var hl_poly = get_circle_poly(shimmer_pos, s * 0.1)
		var c_hl = clip_polygon_left(hl_poly, clip_x)
		if c_hl.size() >= 3:
			draw_colored_polygon(c_hl, Color(1.0, 1.0, 1.0, 0.35))

func _draw_pixel_food(pos: Vector2, s: float, fill_ratio: float) -> void:
	var outline_color = Color(0.15, 0.1, 0.1, 0.9)
	var meat_color = FOOD_FULL
	var bone_color = Color(0.85, 0.8, 0.75, 1.0)
	var empty_color = FOOD_EMPTY
	
	# A simple drumstick/meat haunch shape
	var m_center = pos + Vector2(s * 0.6, s * 0.4) # Top right meat
	var b_end = pos + Vector2(s * 0.2, s * 0.8)    # Bottom left bone
	var t1 = pos + Vector2(s * 0.12, s * 0.72)     # Bone tip 1
	var t2 = pos + Vector2(s * 0.28, s * 0.88)     # Bone tip 2
	
	var meat_poly = get_circle_poly(m_center, s * 0.35)
	var bone_shaft = get_line_poly(m_center, b_end, s * 0.2)
	var tip1 = get_circle_poly(t1, s * 0.12)
	var tip2 = get_circle_poly(t2, s * 0.12)
	
	var meat_out = get_circle_poly(m_center, s * 0.35 + 1.5)
	var bone_out = get_line_poly(m_center, b_end, s * 0.2 + 3.0)
	var tip1_out = get_circle_poly(t1, s * 0.12 + 1.5)
	var tip2_out = get_circle_poly(t2, s * 0.12 + 1.5)
	
	# Draw outlines first (slightly thicker elements underneath)
	draw_colored_polygon(meat_out, outline_color)
	draw_colored_polygon(bone_out, outline_color)
	draw_colored_polygon(tip1_out, outline_color)
	draw_colored_polygon(tip2_out, outline_color)
	
	# Draw empty bone and meat backgrounds
	draw_colored_polygon(meat_poly, empty_color)
	draw_colored_polygon(bone_shaft, empty_color)
	draw_colored_polygon(tip1, empty_color)
	draw_colored_polygon(tip2, empty_color)
	
	# Draw partially filled shapes clipped left-to-right
	if fill_ratio > 0.0:
		var clip_x = pos.x + s * fill_ratio
		
		var c_tip1 = clip_polygon_left(tip1, clip_x)
		var c_tip2 = clip_polygon_left(tip2, clip_x)
		var c_bone = clip_polygon_left(bone_shaft, clip_x)
		var c_meat = clip_polygon_left(meat_poly, clip_x)
		
		if c_tip1.size() >= 3: draw_colored_polygon(c_tip1, bone_color)
		if c_tip2.size() >= 3: draw_colored_polygon(c_tip2, bone_color)
		if c_bone.size() >= 3: draw_colored_polygon(c_bone, bone_color)
		if c_meat.size() >= 3: draw_colored_polygon(c_meat, meat_color)
		
		# Meat highlight
		var hl_poly = get_circle_poly(m_center - Vector2(s*0.1, s*0.15), s*0.1)
		var c_hl = clip_polygon_left(hl_poly, clip_x)
		if c_hl.size() >= 3:
			draw_colored_polygon(c_hl, Color(1,1,1,0.3))

func _draw_stat_bar(pos: Vector2, label: String, current: float, maximum: float, fill_col: Color, bg_col: Color, border_col: Color, font: Font) -> void:
	var label_width := 40.0
	
	# Label
	draw_string(font, Vector2(pos.x, pos.y + BAR_HEIGHT - 1), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, LABEL_COLOR)
	
	var bar_x = pos.x + label_width + 4
	var bar_rect = Rect2(bar_x, pos.y, BAR_WIDTH, BAR_HEIGHT)
	
	# Background
	draw_rect(bar_rect, bg_col)
	
	# Fill
	var fill_ratio = clamp(current / maximum, 0.0, 1.0) if maximum > 0 else 0.0
	var fill_rect = Rect2(bar_x + 1, pos.y + 1, (BAR_WIDTH - 2) * fill_ratio, BAR_HEIGHT - 2)
	draw_rect(fill_rect, fill_col)
	
	# Inner highlight (top pixel line, subtle)
	if fill_ratio > 0:
		var highlight_rect = Rect2(bar_x + 1, pos.y + 1, (BAR_WIDTH - 2) * fill_ratio, 2)
		draw_rect(highlight_rect, Color(fill_col.r + 0.2, fill_col.g + 0.2, fill_col.b + 0.2, 0.4))
	
	# Border
	draw_rect(bar_rect, border_col, false, 1.0)
	
	# Value text
	var value_text = str(int(current)) + "/" + str(int(maximum))
	draw_string(font, Vector2(bar_x + BAR_WIDTH + 6, pos.y + BAR_HEIGHT - 1), value_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, LABEL_COLOR)

func _create_inv_button():
	var inv_btn = Button.new()
	inv_btn.text = "INV"
	inv_btn.custom_minimum_size = Vector2(78, 36)
	if pixel_font:
		inv_btn.add_theme_font_override("font", pixel_font)
	inv_btn.add_theme_font_size_override("font_size", 13)
	inv_btn.add_theme_color_override("font_color", Color(0.8, 0.75, 0.55, 1.0))
	inv_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.7, 1.0))
	
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.1, 0.1, 0.14, 0.85)
	normal_style.border_color = Color(0.55, 0.45, 0.2, 0.7)
	normal_style.set_border_width_all(2)
	normal_style.set_corner_radius_all(5)
	normal_style.content_margin_left = 12
	normal_style.content_margin_right = 12
	normal_style.content_margin_top = 6
	normal_style.content_margin_bottom = 6
	inv_btn.add_theme_stylebox_override("normal", normal_style)
	
	var hover_style = normal_style.duplicate()
	hover_style.bg_color = Color(0.15, 0.12, 0.08, 0.95)
	hover_style.border_color = Color(0.75, 0.6, 0.25, 0.9)
	inv_btn.add_theme_stylebox_override("hover", hover_style)
	inv_btn.add_theme_stylebox_override("pressed", hover_style)
	inv_btn.add_theme_stylebox_override("focus", normal_style)
	
	# Position under the SAT bar on the left side
	inv_btn.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	inv_btn.offset_left = 14
	inv_btn.offset_top = 156
	inv_btn.offset_right = 96
	inv_btn.offset_bottom = 196
	
	inv_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	inv_btn.pressed.connect(func(): inv_button_pressed.emit())
	add_child(inv_btn)

func _create_profile_button():
	var btn = TextureButton.new()
	# The circle is at roughly (52, 58) with radius 39
	# Bounding box roughly x: 13 to 91, y: 19 to 97 (width/height ~ 78)
	btn.custom_minimum_size = Vector2(80, 80)
	btn.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	btn.offset_left = 13
	btn.offset_top = 19
	btn.offset_right = 93
	btn.offset_bottom = 99
	
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.pressed.connect(func(): profile_button_pressed.emit())
	add_child(btn)

# === Polygon Clipping Helpers ===

func get_circle_poly(center: Vector2, radius: float) -> PackedVector2Array:
	var poly = PackedVector2Array()
	var sides = 32
	for i in range(sides):
		var t = float(i) / float(sides) * TAU
		poly.append(center + Vector2(cos(t), sin(t)) * radius)
	return poly

func get_line_poly(p1: Vector2, p2: Vector2, thickness: float) -> PackedVector2Array:
	var dir = (p2 - p1).normalized()
	var norm = Vector2(-dir.y, dir.x) * (thickness / 2.0)
	return PackedVector2Array([
		p1 + norm,
		p2 + norm,
		p2 - norm,
		p1 - norm
	])

func clip_polygon_left(points: PackedVector2Array, clip_x: float) -> PackedVector2Array:
	var clipped := PackedVector2Array()
	var size = points.size()
	if size < 3: return points
	
	for i in range(size):
		var p1 = points[i]
		var p2 = points[(i + 1) % size]
		
		var p1_in = p1.x <= clip_x
		var p2_in = p2.x <= clip_x
		
		if p1_in:
			clipped.append(p1)
		
		# If the line segment crosses the clip line, calculate the intersection
		if p1_in != p2_in:
			if (p2.x - p1.x) != 0:
				var t = (clip_x - p1.x) / (p2.x - p1.x)
				var inter_y = p1.y + t * (p2.y - p1.y)
				clipped.append(Vector2(clip_x, inter_y))
			else:
				clipped.append(Vector2(clip_x, p1.y))
			
	return clipped
