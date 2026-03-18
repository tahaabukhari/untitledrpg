extends Control

var is_closing := false
var pixel_font: Font
var player_ref = null

# UI Elements
var bg_rect: ColorRect
var main_panel: PanelContainer
var points_label: Label
var stat_labels: Dictionary = {}
var stat_buttons: Dictionary = {}
var name_label: Label
var title_label: Label
var class_label: Label
var level_label: Label
var uuid_label: Label

func _ready() -> void:
	pixel_font = load("res://fonts/PressStart2P.ttf")
	player_ref = get_tree().get_first_node_in_group("player")
	_build_ui()
	_refresh_all()
	_animate_open()

func _build_ui() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# === Dark overlay background ===
	bg_rect = ColorRect.new()
	bg_rect.color = Color(0, 0, 0, 0.6)
	bg_rect.set_anchors_preset(PRESET_FULL_RECT)
	bg_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	bg_rect.gui_input.connect(_on_bg_gui_input)
	add_child(bg_rect)
	
	# === Main Panel (centered, much larger) ===
	main_panel = PanelContainer.new()
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.06, 0.09, 0.97)
	panel_style.border_color = Color(0.5, 0.4, 0.15, 1.0)
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(12)
	panel_style.content_margin_left = 35
	panel_style.content_margin_right = 35
	panel_style.content_margin_top = 28
	panel_style.content_margin_bottom = 28
	main_panel.add_theme_stylebox_override("panel", panel_style)
	main_panel.set_anchors_preset(PRESET_CENTER)
	main_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	main_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	# Force a generous minimum size
	main_panel.custom_minimum_size = Vector2(680, 480)
	add_child(main_panel)
	
	# === Root VBox ===
	var root_vbox = VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 18)
	main_panel.add_child(root_vbox)
	
	# ---- HEADER ----
	_build_header(root_vbox)
	
	# ---- Gold Separator ----
	root_vbox.add_child(_make_separator())
	
	# ---- BODY: Two columns ----
	var body_hbox = HBoxContainer.new()
	body_hbox.add_theme_constant_override("separation", 40)
	root_vbox.add_child(body_hbox)
	
	# == LEFT COLUMN ==
	var left_col = VBoxContainer.new()
	left_col.add_theme_constant_override("separation", 16)
	left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_hbox.add_child(left_col)
	
	# == RIGHT COLUMN ==
	var right_col = VBoxContainer.new()
	right_col.add_theme_constant_override("separation", 16)
	right_col.custom_minimum_size.x = 200
	body_hbox.add_child(right_col)
	
	# ---- LEFT: Identity ----
	_build_identity_section(left_col)
	left_col.add_child(_make_separator())
	
	# ---- LEFT: Stats + Progression ----
	_build_stats_section(left_col)
	
	# ---- RIGHT: Player Preview ----
	_build_preview_section(right_col)
	right_col.add_child(_make_separator())
	
	# ---- RIGHT: Equipment ----
	_build_equipment_section(right_col)
	right_col.add_child(_make_separator())
	
	# ---- RIGHT: Skills ----
	_build_skills_section(right_col)

# =====================
# HEADER
# =====================
func _build_header(parent: VBoxContainer) -> void:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	
	var title = Label.new()
	title.text = "CHARACTER PROFILE"
	if pixel_font: title.add_theme_font_override("font", pixel_font)
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hbox.add_child(title)
	
	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(34, 34)
	if pixel_font: close_btn.add_theme_font_override("font", pixel_font)
	close_btn.add_theme_font_size_override("font_size", 12)
	var cstyle = StyleBoxFlat.new()
	cstyle.bg_color = Color(0.55, 0.12, 0.12, 0.9)
	cstyle.border_color = Color(0.8, 0.2, 0.2, 0.5)
	cstyle.set_border_width_all(1)
	cstyle.set_corner_radius_all(5)
	close_btn.add_theme_stylebox_override("normal", cstyle)
	var chover = cstyle.duplicate()
	chover.bg_color = Color(0.75, 0.18, 0.18, 1.0)
	close_btn.add_theme_stylebox_override("hover", chover)
	close_btn.add_theme_stylebox_override("pressed", chover)
	close_btn.pressed.connect(close)
	close_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	hbox.add_child(close_btn)
	
	parent.add_child(hbox)

# =====================
# IDENTITY SECTION
# =====================
func _build_identity_section(parent: VBoxContainer) -> void:
	var section_lbl = _make_label("— IDENTITY —", 8, Color(0.5, 0.45, 0.35))
	section_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	parent.add_child(section_lbl)
	
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	
	name_label = _make_label("", 16, Color(1, 1, 1))
	title_label = _make_label("", 10, Color(0.6, 0.6, 0.65))
	class_label = _make_label("", 11, Color(0.9, 0.78, 0.35))
	level_label = _make_label("", 12, Color(0.25, 0.85, 0.4))
	uuid_label = _make_label("", 8, Color(0.3, 0.3, 0.35))
	
	box.add_child(name_label)
	
	var title_row = HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 20)
	title_row.add_child(title_label)
	title_row.add_child(class_label)
	box.add_child(title_row)
	
	var level_row = HBoxContainer.new()
	level_row.add_theme_constant_override("separation", 20)
	level_row.add_child(level_label)
	level_row.add_child(uuid_label)
	box.add_child(level_row)
	
	parent.add_child(box)

# =====================
# STATS + PROGRESSION
# =====================
func _build_stats_section(parent: VBoxContainer) -> void:
	var section_lbl = _make_label("— PROGRESSION —", 8, Color(0.5, 0.45, 0.35))
	section_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	parent.add_child(section_lbl)
	
	# Points header
	points_label = _make_label("", 11, Color(0.95, 0.85, 0.2))
	parent.add_child(points_label)
	
	# Stats grid: 3 columns (Name | Value | [+])
	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 10)
	
	var stats_config = [
		{"key": "HP",  "label": "MAX HP",      "color": Color(0.9, 0.2, 0.25)},
		{"key": "MP",  "label": "MAX MANA",    "color": Color(0.5, 0.3, 0.85)},
		{"key": "STA", "label": "MAX STAMINA", "color": Color(0.15, 0.7, 0.85)},
		{"key": "ATK", "label": "ATTACK",      "color": Color(0.95, 0.65, 0.15)},
		{"key": "DEF", "label": "DEFENSE",     "color": Color(0.4, 0.6, 0.85)},
		{"key": "EVA", "label": "EVASION",     "color": Color(0.3, 0.85, 0.5)},
	]
	
	for s in stats_config:
		# Stat name
		var name_lbl = _make_label(s["label"], 10, s["color"])
		name_lbl.custom_minimum_size.x = 130
		grid.add_child(name_lbl)
		
		# Stat value
		var val_lbl = _make_label("0", 10, Color(0.9, 0.9, 0.95))
		val_lbl.custom_minimum_size.x = 60
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		stat_labels[s["key"]] = val_lbl
		grid.add_child(val_lbl)
		
		# [+] button
		var btn = Button.new()
		btn.text = "+"
		btn.custom_minimum_size = Vector2(28, 28)
		if pixel_font: btn.add_theme_font_override("font", pixel_font)
		btn.add_theme_font_size_override("font_size", 11)
		btn.add_theme_color_override("font_color", Color(0.2, 0.95, 0.35))
		var bstyle = StyleBoxFlat.new()
		bstyle.bg_color = Color(0.06, 0.14, 0.06, 0.9)
		bstyle.border_color = Color(0.15, 0.45, 0.15, 0.8)
		bstyle.set_border_width_all(1)
		bstyle.set_corner_radius_all(4)
		bstyle.content_margin_left = 4
		bstyle.content_margin_right = 4
		btn.add_theme_stylebox_override("normal", bstyle)
		var bhover = bstyle.duplicate()
		bhover.bg_color = Color(0.1, 0.25, 0.1, 1.0)
		bhover.border_color = Color(0.25, 0.65, 0.25, 1.0)
		btn.add_theme_stylebox_override("hover", bhover)
		btn.add_theme_stylebox_override("pressed", bhover)
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		var stat_key = s["key"]
		btn.pressed.connect(func(): _on_allocate_pressed(stat_key))
		stat_buttons[s["key"]] = btn
		grid.add_child(btn)
	
	parent.add_child(grid)

# =====================
# PLAYER PREVIEW
# =====================
func _build_preview_section(parent: VBoxContainer) -> void:
	var section_lbl = _make_label("— PLAYER —", 8, Color(0.5, 0.45, 0.35))
	section_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(section_lbl)
	
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.04, 0.07, 0.85)
	style.border_color = Color(0.22, 0.18, 0.32, 0.6)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 15
	style.content_margin_right = 15
	style.content_margin_top = 15
	style.content_margin_bottom = 15
	panel.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	
	var rect = ColorRect.new()
	rect.color = Color(0.06, 0.06, 0.1)
	rect.custom_minimum_size = Vector2(150, 160)
	vbox.add_child(rect)
	
	var placeholder = _make_label("??", 22, Color(0.25, 0.25, 0.35))
	placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	placeholder.set_anchors_preset(PRESET_FULL_RECT)
	rect.add_child(placeholder)
	
	panel.add_child(vbox)
	parent.add_child(panel)

# =====================
# EQUIPMENT
# =====================
func _build_equipment_section(parent: VBoxContainer) -> void:
	var section_lbl = _make_label("— EQUIPMENT —", 8, Color(0.55, 0.5, 0.35))
	section_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(section_lbl)
	
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	
	var slots = ["Weapon", "Shield", "Helmet", "Armor", "Boots", "Ring"]
	for slot_name in slots:
		var slot = PanelContainer.new()
		var ss = StyleBoxFlat.new()
		ss.bg_color = Color(0.05, 0.05, 0.08, 0.85)
		ss.border_color = Color(0.22, 0.18, 0.12, 0.55)
		ss.set_border_width_all(1)
		ss.set_corner_radius_all(4)
		ss.content_margin_left = 8
		ss.content_margin_right = 8
		ss.content_margin_top = 6
		ss.content_margin_bottom = 6
		slot.add_theme_stylebox_override("panel", ss)
		slot.custom_minimum_size = Vector2(85, 30)
		
		var sl = _make_label(slot_name, 8, Color(0.4, 0.4, 0.48))
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot.add_child(sl)
		grid.add_child(slot)
	
	parent.add_child(grid)

# =====================
# SKILLS
# =====================
func _build_skills_section(parent: VBoxContainer) -> void:
	var section_lbl = _make_label("— SKILLS —", 8, Color(0.5, 0.4, 0.6))
	section_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(section_lbl)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	
	for i in range(4):
		var skill_slot = PanelContainer.new()
		var ss = StyleBoxFlat.new()
		ss.bg_color = Color(0.05, 0.04, 0.09, 0.85)
		ss.border_color = Color(0.28, 0.2, 0.38, 0.5)
		ss.set_border_width_all(1)
		ss.set_corner_radius_all(4)
		ss.content_margin_left = 4
		ss.content_margin_right = 4
		ss.content_margin_top = 4
		ss.content_margin_bottom = 4
		skill_slot.add_theme_stylebox_override("panel", ss)
		skill_slot.custom_minimum_size = Vector2(38, 38)
		
		var sl = _make_label("?", 12, Color(0.28, 0.28, 0.38))
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		skill_slot.add_child(sl)
		hbox.add_child(skill_slot)
	
	parent.add_child(hbox)

# =====================
# HELPERS
# =====================
func _make_label(text: String, font_size: int, color: Color) -> Label:
	var l = Label.new()
	l.text = text
	if pixel_font: l.add_theme_font_override("font", pixel_font)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l

func _make_separator() -> HSeparator:
	var sep = HSeparator.new()
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.35, 0.28, 0.12, 0.45)
	s.content_margin_top = 1
	s.content_margin_bottom = 1
	sep.add_theme_stylebox_override("separator", s)
	return sep

# =====================
# STAT ALLOCATION
# =====================
func _on_allocate_pressed(stat_key: String) -> void:
	if player_ref == null:
		player_ref = get_tree().get_first_node_in_group("player")
	if player_ref == null: return
	
	if player_ref.stat_points <= 0:
		return
	
	player_ref.allocate_stat(stat_key)
	_refresh_all()

# =====================
# REFRESH ALL DISPLAY
# =====================
func _refresh_all() -> void:
	if player_ref == null:
		player_ref = get_tree().get_first_node_in_group("player")
	if player_ref == null: return
	
	# Identity
	name_label.text = player_ref.player_name
	title_label.text = "Title: " + player_ref.player_title
	class_label.text = "Class: " + player_ref.current_class
	level_label.text = "Level " + str(player_ref.level)
	uuid_label.text = "ID: " + player_ref.player_uuid
	
	# Stat points
	if player_ref.stat_points > 0:
		points_label.text = "AVAILABLE POINTS: " + str(player_ref.stat_points)
		points_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.2))
	else:
		points_label.text = "NO POINTS AVAILABLE"
		points_label.add_theme_color_override("font_color", Color(0.35, 0.35, 0.4))
	
	# Stat values
	stat_labels["HP"].text = str(int(player_ref.max_health))
	stat_labels["MP"].text = str(int(player_ref.max_mana))
	stat_labels["STA"].text = str(int(player_ref.max_stamina))
	stat_labels["ATK"].text = str(player_ref.stat_atk)
	stat_labels["DEF"].text = str(player_ref.stat_def)
	stat_labels["EVA"].text = str(player_ref.stat_evasion)
	
	# Toggle [+] buttons
	for key in stat_buttons:
		stat_buttons[key].visible = player_ref.stat_points > 0

# =====================
# INPUT
# =====================
func _on_bg_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		close()

# =====================
# ANIMATIONS
# =====================
func _animate_open() -> void:
	modulate.a = 0.0
	main_panel.scale = Vector2(0.85, 0.85)
	main_panel.pivot_offset = main_panel.size / 2.0
	
	var t = create_tween()
	t.set_parallel(true)
	t.tween_property(self, "modulate:a", 1.0, 0.2).set_ease(Tween.EASE_OUT)
	t.tween_property(main_panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func close() -> void:
	if is_closing: return
	is_closing = true
	
	var t = create_tween()
	t.set_parallel(true)
	t.tween_property(self, "modulate:a", 0.0, 0.15).set_ease(Tween.EASE_IN)
	t.tween_property(main_panel, "scale", Vector2(0.9, 0.9), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.chain().tween_callback(_on_close_finished)

func _on_close_finished() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.profile_ui = null
	queue_free()
