extends Control
## Title screen — WONDERS OF CREATION.
## Programmatic pixel-theme UI: twinkling starfield, CRT scanlines,
## hard-shadow pixel title with a floating bob, crisp square buttons.

var pixel_font: Font = null
var title_elements: Array[Control] = []

const GOLD := Color(0.95, 0.85, 0.5, 1.0)
const GOLD_DIM := Color(0.6, 0.4, 0.1, 0.55)


func _ready():
	pixel_font = load("res://fonts/PressStart2P.ttf")
	_build_ui()
	# Wait one frame for layout to settle, THEN animate
	await get_tree().process_frame
	_play_intro_animation()


func _unhandled_input(event: InputEvent) -> void:
	# Debug quick-launch: B jumps straight into the boss arena
	# (class auto-assigned; switch with 1-4 inside)
	if event.is_action_pressed("dbg_spawn_boss"):
		get_tree().change_scene_to_file("res://boss_arena.tscn")


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

	# === Twinkling pixel starfield ===
	var stars := StarfieldControl.new()
	stars.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stars)

	# === Main layout ===
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 100)
	margin.add_theme_constant_override("margin_right", 100)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 30)
	add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	# === Spacer top ===
	var spacer_top = Control.new()
	spacer_top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer_top)

	# === Subtitle ===
	var subtitle = Label.new()
	subtitle.text = "- A  H A N D M A D E  W O R L D -"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if pixel_font:
		subtitle.add_theme_font_override("font", pixel_font)
	subtitle.add_theme_font_size_override("font_size", 10)
	subtitle.add_theme_color_override("font_color", Color(0.5, 0.45, 0.35, 0.7))
	vbox.add_child(subtitle)
	title_elements.append(subtitle)

	# === Title (two stacked lines, hard pixel drop-shadow, floating bob) ===
	var title_wrap := Control.new()
	title_wrap.custom_minimum_size = Vector2(0, 130)
	vbox.add_child(title_wrap)
	title_elements.append(title_wrap)

	var title_box := VBoxContainer.new()
	title_box.set_anchors_preset(Control.PRESET_CENTER)
	title_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	title_box.grow_vertical = Control.GROW_DIRECTION_BOTH
	title_box.alignment = BoxContainer.ALIGNMENT_CENTER
	title_box.add_theme_constant_override("separation", 2)
	title_wrap.add_child(title_box)

	var line1 := _make_title_line("WONDERS", 46)
	var line2 := _make_title_line("OF CREATION", 30)
	line2.add_theme_color_override("font_color", Color(0.85, 0.7, 0.4, 1.0))
	title_box.add_child(line1)
	title_box.add_child(line2)

	# Gentle pixel bob on the whole title block
	var bob := create_tween().set_loops()
	bob.tween_property(title_box, "position:y", -4.0, 1.6).as_relative().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(title_box, "position:y", 4.0, 1.6).as_relative().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# === Decorative separator ===
	var sep_container = HBoxContainer.new()
	sep_container.alignment = BoxContainer.ALIGNMENT_CENTER
	sep_container.add_theme_constant_override("separation", 12)
	vbox.add_child(sep_container)

	for part in ["━━━━━━━", "◆", "━━━━━━━"]:
		var lbl = Label.new()
		lbl.text = part
		if pixel_font:
			lbl.add_theme_font_override("font", pixel_font)
		lbl.add_theme_font_size_override("font_size", 10 if part == "◆" else 8)
		lbl.add_theme_color_override("font_color",
			Color(0.85, 0.7, 0.3, 0.8) if part == "◆" else Color(0.45, 0.35, 0.2, 0.6))
		sep_container.add_child(lbl)
	title_elements.append(sep_container)

	# === Spacer middle ===
	var spacer_mid = Control.new()
	spacer_mid.custom_minimum_size = Vector2(0, 16)
	vbox.add_child(spacer_mid)

	# === Menu buttons ===
	var start_btn := _make_menu_button("START GAME", 16, Vector2(320, 52))
	start_btn.pressed.connect(_on_play_pressed)
	vbox.add_child(start_btn)
	_add_touch_overlay(start_btn, _on_play_pressed)
	title_elements.append(start_btn)

	var custom_btn := _make_menu_button("CUSTOMIZE HERO", 12, Vector2(320, 44))
	custom_btn.pressed.connect(_on_customize_pressed)
	vbox.add_child(custom_btn)
	_add_touch_overlay(custom_btn, _on_customize_pressed)
	title_elements.append(custom_btn)

	var arena_btn := _make_menu_button("BOSS ARENA", 12, Vector2(320, 44))
	arena_btn.pressed.connect(_on_arena_pressed)
	vbox.add_child(arena_btn)
	_add_touch_overlay(arena_btn, _on_arena_pressed)
	title_elements.append(arena_btn)

	var dungeon_btn := _make_menu_button("DUNGEON STAGE", 12, Vector2(320, 44))
	dungeon_btn.pressed.connect(_on_dungeon_pressed)
	vbox.add_child(dungeon_btn)
	_add_touch_overlay(dungeon_btn, _on_dungeon_pressed)
	title_elements.append(dungeon_btn)

	# === Spacer bottom ===
	var spacer_bot = Control.new()
	spacer_bot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer_bot)

	# === Version text ===
	var version = Label.new()
	version.text = "v0.2 - EARLY DEVELOPMENT"
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if pixel_font:
		version.add_theme_font_override("font", pixel_font)
	version.add_theme_font_size_override("font_size", 8)
	version.add_theme_color_override("font_color", Color(0.35, 0.35, 0.4, 0.5))
	vbox.add_child(version)
	title_elements.append(version)

	# === CRT scanline overlay (topmost, ignores mouse) ===
	var scan := ScanlineControl.new()
	scan.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scan)


func _make_title_line(text: String, size: int) -> Label:
	var title = Label.new()
	title.text = text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if pixel_font:
		title.add_theme_font_override("font", pixel_font)
	title.add_theme_font_size_override("font_size", size)
	title.add_theme_color_override("font_color", GOLD)
	# Hard pixel drop-shadow (no blur) + thin outline
	title.add_theme_color_override("font_shadow_color", Color(0.25, 0.12, 0.05, 0.9))
	title.add_theme_constant_override("shadow_offset_x", 4)
	title.add_theme_constant_override("shadow_offset_y", 4)
	title.add_theme_constant_override("outline_size", 6)
	title.add_theme_color_override("font_outline_color", GOLD_DIM)
	return title


func _make_menu_button(text: String, font_size: int, min_size: Vector2) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = min_size
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if pixel_font:
		btn.add_theme_font_override("font", pixel_font)
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", GOLD)
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.7, 1.0))
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	btn.add_theme_stylebox_override("normal", _make_btn_style(false))
	btn.add_theme_stylebox_override("hover", _make_btn_style(true))
	btn.add_theme_stylebox_override("pressed", _make_btn_style(true))
	btn.add_theme_stylebox_override("focus", _make_btn_style(false))
	return btn


func _add_touch_overlay(btn: Button, callback: Callable) -> void:
	var touch_btn = TouchScreenButton.new()
	touch_btn.shape = RectangleShape2D.new()
	(touch_btn.shape as RectangleShape2D).size = btn.custom_minimum_size
	touch_btn.position = btn.custom_minimum_size / 2.0
	touch_btn.pressed.connect(callback)
	btn.add_child(touch_btn)


func _play_intro_animation():
	# Only animate opacity — never touch position on layout-managed nodes
	for el in title_elements:
		el.modulate.a = 0.0

	var tw = create_tween()
	for el in title_elements:
		tw.tween_property(el, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_SINE)
		tw.tween_interval(0.1)


func _on_play_pressed():
	get_tree().change_scene_to_file("res://class_selection.tscn")


func _on_customize_pressed():
	get_tree().change_scene_to_file("res://character_customization.tscn")


func _on_arena_pressed():
	get_tree().change_scene_to_file("res://boss_arena.tscn")


func _on_dungeon_pressed():
	get_tree().change_scene_to_file("res://dungeon/dungeon_stage_1.tscn")


func _make_btn_style(is_hover: bool) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	if is_hover:
		style.bg_color = Color(0.15, 0.12, 0.08, 0.95)
	else:
		style.bg_color = Color(0.1, 0.08, 0.05, 0.9)
	style.border_color = Color(0.7, 0.55, 0.2, 0.8) if not is_hover else Color(0.85, 0.7, 0.3, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(0)  # crisp pixel corners
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 0
	# Hard drop-shadow illusion via expand margin on the bottom/right
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style


# ─── Pixel starfield ─────────────────────────────────────────────────────────

class StarfieldControl:
	extends Control
	var _stars: Array = []  # [[pos, phase, speed, size], ...]

	func _ready() -> void:
		randomize()
		for i in range(70):
			_stars.append([
				Vector2(randf(), randf()),
				randf() * TAU,
				randf_range(0.6, 2.2),
				1.0 + float(randi() % 2),
			])

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var t := Time.get_ticks_msec() / 1000.0
		for s in _stars:
			var pos: Vector2 = Vector2(s[0].x * size.x, s[0].y * size.y)
			var tw: float = 0.35 + 0.65 * (0.5 + 0.5 * sin(t * s[2] + s[1]))
			var px: float = s[3]
			draw_rect(Rect2(pos, Vector2(px, px)), Color(0.8, 0.8, 0.95, 0.5 * tw))


# ─── CRT scanlines ───────────────────────────────────────────────────────────

class ScanlineControl:
	extends Control

	func _draw() -> void:
		var y := 0.0
		while y < size.y:
			draw_rect(Rect2(0, y, size.x, 1.0), Color(0, 0, 0, 0.10))
			y += 3.0
