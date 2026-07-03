extends Control
## Character customization — early tool, built to expand later.
## Live layered-sprite preview of the puppet with tint-based options
## (hair color / skin tone / outfit color) + hero name. Selections are
## stored in Global.player_custom and applied to the player on spawn.
## All UI programmatic, pixel theme.

var pixel_font: Font = null

# Preview sprite layers (tint targets)
var _hair: Sprite2D = null
var _head: Sprite2D = null
var _lhand: Sprite2D = null
var _rhand: Sprite2D = null
var _torso: Sprite2D = null
var _lleg: Sprite2D = null
var _rleg: Sprite2D = null

var _name_edit: LineEdit = null
var _swatch_groups: Dictionary = {}  # key -> Array[Button]

const GOLD := Color(0.95, 0.85, 0.5, 1.0)
const PANEL_BG := Color(0.07, 0.06, 0.1, 0.96)
const PANEL_BORDER := Color(0.55, 0.45, 0.2, 0.8)


func _ready() -> void:
	pixel_font = load("res://fonts/PressStart2P.ttf")
	_build_ui()
	_apply_preview_tints()


# ─── UI construction ─────────────────────────────────────────────────────────

func _build_ui() -> void:
	# Background
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.03, 0.06, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Header
	var header := Label.new()
	header.text = "FORGE YOUR HERO"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if pixel_font:
		header.add_theme_font_override("font", pixel_font)
	header.add_theme_font_size_override("font_size", 24)
	header.add_theme_color_override("font_color", GOLD)
	header.add_theme_color_override("font_shadow_color", Color(0.25, 0.12, 0.05, 0.9))
	header.add_theme_constant_override("shadow_offset_x", 3)
	header.add_theme_constant_override("shadow_offset_y", 3)
	header.set_anchors_preset(Control.PRESET_TOP_WIDE)
	header.offset_top = 28
	header.offset_bottom = 66
	add_child(header)

	_build_preview()
	_build_options_panel()

	# Scanline overlay
	var scan := ScanlineControl.new()
	scan.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scan)


func _build_preview() -> void:
	## Layered puppet preview — mirrors player.tscn's pivot/sprite offsets.
	var pedestal_panel := Panel.new()
	pedestal_panel.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	pedestal_panel.anchor_left = 0.08
	pedestal_panel.anchor_right = 0.08
	pedestal_panel.offset_left = 0
	pedestal_panel.offset_right = 380
	pedestal_panel.offset_top = -210
	pedestal_panel.offset_bottom = 210
	pedestal_panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(pedestal_panel)

	var preview := Node2D.new()
	preview.name = "Preview"
	preview.position = Vector2(190, 210)
	preview.scale = Vector2(9, 9)
	pedestal_panel.add_child(preview)

	# Pedestal disc
	var disc := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(16):
		var t := TAU * float(i) / 16.0
		pts.append(Vector2(cos(t) * 14.0, 10.0 + sin(t) * 3.5))
	disc.polygon = pts
	disc.color = Color(0.18, 0.15, 0.24, 1.0)
	preview.add_child(disc)

	# Layer order mirrors the puppet: legs behind, arms/head in front
	_lleg = _sprite("res://sprites/player/male/male-leftleg-base.png", Vector2(0, -0.5), -2, preview)
	_rleg = _sprite("res://sprites/player/male/male-rightleg-base.png", Vector2(0, -0.5), -2, preview)
	_torso = _sprite("res://sprites/player/male/male-torso-base.png", Vector2(0, -0.5), 0, preview)
	_rhand = _sprite("res://sprites/player/male/male-righthand-base.png", Vector2(0, -0.5), 2, preview)
	_lhand = _sprite("res://sprites/player/male/male-lefthand-base.png", Vector2(0, -0.5), 2, preview)
	_head = _sprite("res://sprites/player/male/male-head-base.png", Vector2(0, -0.5), 2, preview)
	_sprite("res://sprites/player/male/male-face-base.png", Vector2(0, -0.5), 3, preview)
	_hair = _sprite("res://sprites/player/male/male-hair-base.png", Vector2(0, -0.5), 4, preview)

	# Gentle idle bob
	var tw := preview.create_tween().set_loops()
	tw.tween_property(preview, "position:y", 206.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(preview, "position:y", 210.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _sprite(path: String, pos: Vector2, z: int, parent: Node) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(path)
	s.position = pos
	s.z_index = z
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	parent.add_child(s)
	return s


func _build_options_panel() -> void:
	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	panel.anchor_left = 0.92
	panel.anchor_right = 0.92
	panel.offset_left = -640
	panel.offset_right = 0
	panel.offset_top = -215
	panel.offset_bottom = 215
	panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(panel)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(m, 24)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	# ── Name ──
	vbox.add_child(_section_label("HERO NAME"))
	_name_edit = LineEdit.new()
	_name_edit.text = str(Global.player_custom.get("name", "Adventurer"))
	_name_edit.max_length = 16
	_name_edit.custom_minimum_size = Vector2(0, 40)
	if pixel_font:
		_name_edit.add_theme_font_override("font", pixel_font)
	_name_edit.add_theme_font_size_override("font_size", 12)
	_name_edit.add_theme_color_override("font_color", Color(0.95, 0.92, 0.8))
	_name_edit.add_theme_color_override("caret_color", GOLD)
	var le_style := StyleBoxFlat.new()
	le_style.bg_color = Color(0.05, 0.04, 0.08, 1.0)
	le_style.border_color = PANEL_BORDER
	le_style.set_border_width_all(2)
	le_style.set_corner_radius_all(0)
	le_style.content_margin_left = 10
	le_style.content_margin_top = 6
	le_style.content_margin_bottom = 6
	_name_edit.add_theme_stylebox_override("normal", le_style)
	var le_focus: StyleBoxFlat = le_style.duplicate()
	le_focus.border_color = GOLD
	_name_edit.add_theme_stylebox_override("focus", le_focus)
	_name_edit.text_changed.connect(func(t: String) -> void:
		Global.player_custom["name"] = t.strip_edges() if t.strip_edges() != "" else "Adventurer")
	vbox.add_child(_name_edit)

	# ── Tint swatch rows ──
	vbox.add_child(_section_label("HAIR"))
	vbox.add_child(_swatch_row("hair_color", Global.HAIR_COLORS))
	vbox.add_child(_section_label("SKIN"))
	vbox.add_child(_swatch_row("skin_tone", Global.SKIN_TONES))
	vbox.add_child(_section_label("OUTFIT"))
	vbox.add_child(_swatch_row("outfit_color", Global.OUTFIT_COLORS))

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	# ── Bottom buttons ──
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 14)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	var reset_btn := _pixel_button("RESET", 10)
	reset_btn.pressed.connect(_on_reset_pressed)
	btn_row.add_child(reset_btn)

	var done_btn := _pixel_button("SAVE & RETURN", 12)
	done_btn.pressed.connect(_on_done_pressed)
	btn_row.add_child(done_btn)


func _section_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	if pixel_font:
		lbl.add_theme_font_override("font", pixel_font)
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color(0.6, 0.55, 0.42, 0.9))
	return lbl


func _swatch_row(key: String, colors: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var buttons: Array[Button] = []
	for i in range(colors.size()):
		var color: Color = colors[i]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(44, 34)
		btn.tooltip_text = "natural" if i == 0 else ""
		btn.add_theme_stylebox_override("normal", _swatch_style(color, false))
		btn.add_theme_stylebox_override("hover", _swatch_style(color, true))
		btn.add_theme_stylebox_override("pressed", _swatch_style(color, true))
		btn.add_theme_stylebox_override("focus", _swatch_style(color, false))
		btn.pressed.connect(_on_swatch_pressed.bind(key, color, i))
		row.add_child(btn)
		buttons.append(btn)
	_swatch_groups[key] = buttons
	# Highlight the currently saved choice
	var current: Color = Global.player_custom.get(key, colors[0])
	for i in range(colors.size()):
		if colors[i].is_equal_approx(current):
			_set_selected_swatch(key, i)
			break
	return row


func _swatch_style(color: Color, highlight: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	# The first "natural" swatch shows as a neutral checker-ish grey
	style.bg_color = color if not color.is_equal_approx(Color(1, 1, 1)) else Color(0.45, 0.45, 0.5, 1.0)
	style.border_color = GOLD if highlight else Color(0.25, 0.22, 0.3, 1.0)
	style.set_border_width_all(3 if highlight else 2)
	style.set_corner_radius_all(0)
	return style


func _set_selected_swatch(key: String, index: int) -> void:
	var buttons: Array = _swatch_groups.get(key, [])
	for i in range(buttons.size()):
		var btn: Button = buttons[i]
		var colors: Array = _colors_for(key)
		btn.add_theme_stylebox_override("normal", _swatch_style(colors[i], i == index))


func _colors_for(key: String) -> Array:
	match key:
		"hair_color":
			return Global.HAIR_COLORS
		"skin_tone":
			return Global.SKIN_TONES
		_:
			return Global.OUTFIT_COLORS


func _pixel_button(text: String, font_size: int) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 44)
	if pixel_font:
		btn.add_theme_font_override("font", pixel_font)
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", GOLD)
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.7, 1.0))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.1, 0.08, 0.05, 0.9)
	normal.border_color = PANEL_BORDER
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(0)
	normal.content_margin_left = 18
	normal.content_margin_right = 18
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	btn.add_theme_stylebox_override("normal", normal)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color(0.15, 0.12, 0.08, 0.95)
	hover.border_color = Color(0.85, 0.7, 0.3, 1.0)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_stylebox_override("focus", normal)
	return btn


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = PANEL_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(0)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 6
	return style


# ─── Behavior ────────────────────────────────────────────────────────────────

func _on_swatch_pressed(key: String, color: Color, index: int) -> void:
	Global.player_custom[key] = color
	_set_selected_swatch(key, index)
	_apply_preview_tints()


func _apply_preview_tints() -> void:
	var hair: Color = Global.player_custom.get("hair_color", Color(1, 1, 1))
	var skin: Color = Global.player_custom.get("skin_tone", Color(1, 1, 1))
	var outfit: Color = Global.player_custom.get("outfit_color", Color(1, 1, 1))
	if _hair:
		_hair.modulate = hair
	for s in [_head, _lhand, _rhand]:
		if s:
			s.modulate = skin
	for s in [_torso, _lleg, _rleg]:
		if s:
			s.modulate = outfit


func _on_reset_pressed() -> void:
	Global.player_custom["hair_color"] = Color(1, 1, 1)
	Global.player_custom["skin_tone"] = Color(1, 1, 1)
	Global.player_custom["outfit_color"] = Color(1, 1, 1)
	Global.player_custom["name"] = "Adventurer"
	_name_edit.text = "Adventurer"
	for key in ["hair_color", "skin_tone", "outfit_color"]:
		_set_selected_swatch(key, 0)
	_apply_preview_tints()


func _on_done_pressed() -> void:
	get_tree().change_scene_to_file("res://titlescreen.tscn")


# ─── CRT scanlines ───────────────────────────────────────────────────────────

class ScanlineControl:
	extends Control

	func _draw() -> void:
		var y := 0.0
		while y < size.y:
			draw_rect(Rect2(0, y, size.x, 1.0), Color(0, 0, 0, 0.10))
			y += 3.0
