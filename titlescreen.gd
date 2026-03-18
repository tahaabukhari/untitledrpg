extends Control

var pixel_font: Font = null

var title_elements: Array[Control] = []

func _ready():
	pixel_font = load("res://fonts/PressStart2P.ttf")
	_build_ui()
	# Wait one frame for layout to settle, THEN animate
	await get_tree().process_frame
	_play_intro_animation()

func _build_ui():
	# === Background ===
	var bg = ColorRect.new()
	bg.color = Color(0.03, 0.03, 0.06, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	# === Gradient overlay ===
	var gradient_tex = GradientTexture2D.new()
	var grad = Gradient.new()
	grad.colors = PackedColorArray([
		Color(0.08, 0.02, 0.12, 0.6),
		Color(0.02, 0.02, 0.04, 0.0)
	])
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	gradient_tex.gradient = grad
	gradient_tex.fill = GradientTexture2D.FILL_RADIAL
	gradient_tex.fill_from = Vector2(0.5, 0.4)
	gradient_tex.fill_to = Vector2(0.5, 1.0)
	
	var grad_rect = TextureRect.new()
	grad_rect.texture = gradient_tex
	grad_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grad_rect.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(grad_rect)
	
	# === Main layout ===
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 100)
	margin.add_theme_constant_override("margin_right", 100)
	margin.add_theme_constant_override("margin_top", 60)
	margin.add_theme_constant_override("margin_bottom", 40)
	add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	margin.add_child(vbox)
	
	# === Spacer top ===
	var spacer_top = Control.new()
	spacer_top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer_top)
	
	# === Subtitle ===
	var subtitle = Label.new()
	subtitle.text = "- AN UNTITLED ADVENTURE -"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if pixel_font:
		subtitle.add_theme_font_override("font", pixel_font)
	subtitle.add_theme_font_size_override("font_size", 10)
	subtitle.add_theme_color_override("font_color", Color(0.5, 0.45, 0.35, 0.7))
	vbox.add_child(subtitle)
	title_elements.append(subtitle)
	
	# === Title ===
	var title = Label.new()
	title.text = "UNTITLED RPG"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if pixel_font:
		title.add_theme_font_override("font", pixel_font)
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5, 1.0))
	title.add_theme_constant_override("outline_size", 6)
	title.add_theme_color_override("font_outline_color", Color(0.6, 0.4, 0.1, 0.5))
	vbox.add_child(title)
	title_elements.append(title)
	
	# === Decorative separator ===
	var sep_container = HBoxContainer.new()
	sep_container.alignment = BoxContainer.ALIGNMENT_CENTER
	sep_container.add_theme_constant_override("separation", 12)
	vbox.add_child(sep_container)
	
	var left_dash = Label.new()
	left_dash.text = "━━━━━━━"
	if pixel_font:
		left_dash.add_theme_font_override("font", pixel_font)
	left_dash.add_theme_font_size_override("font_size", 8)
	left_dash.add_theme_color_override("font_color", Color(0.45, 0.35, 0.2, 0.6))
	sep_container.add_child(left_dash)
	
	var diamond = Label.new()
	diamond.text = "◆"
	if pixel_font:
		diamond.add_theme_font_override("font", pixel_font)
	diamond.add_theme_font_size_override("font_size", 10)
	diamond.add_theme_color_override("font_color", Color(0.85, 0.7, 0.3, 0.8))
	sep_container.add_child(diamond)
	
	var right_dash = Label.new()
	right_dash.text = "━━━━━━━"
	if pixel_font:
		right_dash.add_theme_font_override("font", pixel_font)
	right_dash.add_theme_font_size_override("font_size", 8)
	right_dash.add_theme_color_override("font_color", Color(0.45, 0.35, 0.2, 0.6))
	sep_container.add_child(right_dash)
	title_elements.append(sep_container)
	
	# === Spacer middle ===
	var spacer_mid = Control.new()
	spacer_mid.custom_minimum_size = Vector2(0, 30)
	vbox.add_child(spacer_mid)
	
	# === Play Button ===
	var play_btn = Button.new()
	play_btn.text = "START GAME"
	play_btn.custom_minimum_size = Vector2(300, 55)
	play_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if pixel_font:
		play_btn.add_theme_font_override("font", pixel_font)
	play_btn.add_theme_font_size_override("font_size", 16)
	play_btn.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5, 1.0))
	play_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.7, 1.0))
	play_btn.add_theme_stylebox_override("normal", _make_btn_style(false))
	play_btn.add_theme_stylebox_override("hover", _make_btn_style(true))
	play_btn.add_theme_stylebox_override("pressed", _make_btn_style(true))
	play_btn.add_theme_stylebox_override("focus", _make_btn_style(false))
	play_btn.pressed.connect(_on_play_pressed)
	vbox.add_child(play_btn)
	
	# === Touch overlay for mobile ===
	var touch_btn = TouchScreenButton.new()
	touch_btn.shape = RectangleShape2D.new()
	(touch_btn.shape as RectangleShape2D).size = Vector2(300, 55)
	touch_btn.position = play_btn.position
	touch_btn.pressed.connect(_on_play_pressed)
	play_btn.add_child(touch_btn)
	title_elements.append(play_btn)
	
	# === Spacer bottom ===
	var spacer_bot = Control.new()
	spacer_bot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer_bot)
	
	# === Version text ===
	var version = Label.new()
	version.text = "v0.1 - EARLY DEVELOPMENT"
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if pixel_font:
		version.add_theme_font_override("font", pixel_font)
	version.add_theme_font_size_override("font_size", 8)
	version.add_theme_color_override("font_color", Color(0.35, 0.35, 0.4, 0.5))
	vbox.add_child(version)
	title_elements.append(version)

func _play_intro_animation():
	# Only animate opacity — never touch position on layout-managed nodes
	for el in title_elements:
		el.modulate.a = 0.0
		
	var tw = create_tween()
	for el in title_elements:
		tw.tween_property(el, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_SINE)
		tw.tween_interval(0.12)

func _on_play_pressed():
	get_tree().change_scene_to_file("res://class_selection.tscn")

func _make_btn_style(is_hover: bool) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	if is_hover:
		style.bg_color = Color(0.15, 0.12, 0.08, 0.95)
	else:
		style.bg_color = Color(0.1, 0.08, 0.05, 0.9)
	style.border_color = Color(0.7, 0.55, 0.2, 0.8) if not is_hover else Color(0.85, 0.7, 0.3, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.shadow_color = Color(0.5, 0.35, 0.1, 0.3)
	style.shadow_size = 4
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style
