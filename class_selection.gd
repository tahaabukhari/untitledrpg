extends Control

# Node references — will be set up in _ready since we build the UI programmatically
var title_label: Label
var cards_container: HBoxContainer
var detail_section: Control
var desc_label: RichTextLabel
var stat_chart: Control
var confirm_btn: Button
var card_buttons := {}  # cls_name -> Button
var card_panels := {}   # cls_name -> PanelContainer

var selected_class := ""
var class_cards_list: Array[PanelContainer] = []

var pixel_font: Font = null

# Card styling
const CARD_NORMAL_COLOR := Color(0.12, 0.12, 0.18, 0.9)
const CARD_HOVER_COLOR := Color(0.18, 0.18, 0.28, 0.95)
const CARD_SELECTED_COLOR := Color(0.15, 0.25, 0.35, 0.95)
const CARD_BORDER_COLOR := Color(0.35, 0.35, 0.5, 0.7)
const CARD_SELECTED_BORDER := Color(0.3, 0.8, 1.0, 1.0)
const BG_COLOR := Color(0.04, 0.04, 0.07, 1.0)

# Class icons (emoji/text placeholders — will be replaced with real assets later)
const CLASS_ICONS := {
	"Warrior": "⚔️",
	"Ranger": "🏹",
	"Mage": "✨",
	"Healer": "💚"
}

func _ready():
	# Load pixel font
	var font_res = load("res://fonts/PressStart2P.ttf")
	if font_res:
		pixel_font = font_res
	
	_build_ui()
	# Wait one frame for layout to settle, THEN animate
	await get_tree().process_frame
	_play_intro()

func _build_ui():
	# === Background ===
	var bg = ColorRect.new()
	bg.color = BG_COLOR
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	# === Main VBox ===
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 60)
	margin.add_theme_constant_override("margin_right", 60)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 12)
	margin.add_child(main_vbox)
	
	# === Title ===
	title_label = Label.new()
	title_label.text = "CHOOSE YOUR CLASS"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if pixel_font:
		title_label.add_theme_font_override("font", pixel_font)
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6, 1.0))
	main_vbox.add_child(title_label)
	
	# === Decorative line under title ===
	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	sep.add_theme_stylebox_override("separator", _make_line_style())
	main_vbox.add_child(sep)
	
	# === Detail Section (ABOVE cards — hidden initially) ===
	detail_section = HBoxContainer.new()
	detail_section.visible = false
	detail_section.custom_minimum_size = Vector2(0, 180)
	(detail_section as HBoxContainer).add_theme_constant_override("separation", 24)
	main_vbox.add_child(detail_section)
	
	# -- Description panel (left side) --
	var desc_panel = PanelContainer.new()
	desc_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_panel.size_flags_stretch_ratio = 1.2
	desc_panel.add_theme_stylebox_override("panel", _make_detail_panel_style())
	detail_section.add_child(desc_panel)
	
	var desc_margin = MarginContainer.new()
	desc_margin.add_theme_constant_override("margin_left", 16)
	desc_margin.add_theme_constant_override("margin_right", 16)
	desc_margin.add_theme_constant_override("margin_top", 12)
	desc_margin.add_theme_constant_override("margin_bottom", 12)
	desc_panel.add_child(desc_margin)
	
	desc_label = RichTextLabel.new()
	desc_label.bbcode_enabled = true
	desc_label.fit_content = true
	desc_label.scroll_active = false
	if pixel_font:
		desc_label.add_theme_font_override("normal_font", pixel_font)
	desc_label.add_theme_font_size_override("normal_font_size", 11)
	desc_label.add_theme_color_override("default_color", Color(0.78, 0.78, 0.85, 1.0))
	desc_margin.add_child(desc_label)
	
	# -- Stat chart (right side) --
	var chart_container = PanelContainer.new()
	chart_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chart_container.custom_minimum_size = Vector2(240, 180)
	chart_container.add_theme_stylebox_override("panel", _make_detail_panel_style())
	detail_section.add_child(chart_container)
	
	stat_chart = Control.new()
	stat_chart.set_script(load("res://stat_chart.gd"))
	stat_chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stat_chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chart_container.add_child(stat_chart)
	
	# === Class Cards ===
	cards_container = HBoxContainer.new()
	cards_container.alignment = BoxContainer.ALIGNMENT_CENTER
	cards_container.add_theme_constant_override("separation", 20)
	cards_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(cards_container)
	
	for cls_name in Global.class_data.keys():
		var card = _create_class_card(cls_name)
		cards_container.add_child(card)
	
	# === Confirm Button ===
	confirm_btn = Button.new()
	confirm_btn.text = "CONFIRM SELECTION"
	confirm_btn.custom_minimum_size = Vector2(300, 45)
	confirm_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if pixel_font:
		confirm_btn.add_theme_font_override("font", pixel_font)
	confirm_btn.add_theme_font_size_override("font_size", 13)
	confirm_btn.add_theme_stylebox_override("normal", _make_confirm_btn_style(false))
	confirm_btn.add_theme_stylebox_override("hover", _make_confirm_btn_style(true))
	confirm_btn.add_theme_stylebox_override("pressed", _make_confirm_btn_style(true))
	confirm_btn.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6, 1.0))
	confirm_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.7, 1.0))
	confirm_btn.visible = false
	confirm_btn.pressed.connect(_on_confirm_pressed)
	main_vbox.add_child(confirm_btn)

func _create_class_card(cls_name: String) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(180, 0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _make_card_style(false))
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 10)
	
	var inner_margin = MarginContainer.new()
	inner_margin.add_theme_constant_override("margin_left", 12)
	inner_margin.add_theme_constant_override("margin_right", 12)
	inner_margin.add_theme_constant_override("margin_top", 14)
	inner_margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(inner_margin)
	inner_margin.add_child(vbox)
	
	# Icon
	var icon_label = Label.new()
	icon_label.text = CLASS_ICONS.get(cls_name, "❓")
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.add_theme_font_size_override("font_size", 38)
	vbox.add_child(icon_label)
	
	# Class name
	var name_label = Label.new()
	name_label.text = cls_name.to_upper()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if pixel_font:
		name_label.add_theme_font_override("font", pixel_font)
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.95, 1.0))
	vbox.add_child(name_label)
	
	# Click button (invisible overlay)
	var btn = Button.new()
	btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn.flat = true
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var transparent_style = StyleBoxFlat.new()
	transparent_style.bg_color = Color(0, 0, 0, 0)
	btn.add_theme_stylebox_override("normal", transparent_style)
	btn.add_theme_stylebox_override("hover", transparent_style)
	btn.add_theme_stylebox_override("pressed", transparent_style)
	btn.add_theme_stylebox_override("focus", transparent_style)
	btn.pressed.connect(_on_class_selected.bind(cls_name))
	panel.add_child(btn)
	
	card_buttons[cls_name] = btn
	card_panels[cls_name] = panel
	class_cards_list.append(panel)
	return panel

func _play_intro():
	# Fade in title
	title_label.modulate.a = 0.0
	for card in class_cards_list:
		card.modulate.a = 0.0
	
	var tw = create_tween()
	tw.tween_property(title_label, "modulate:a", 1.0, 0.35)
	
	for card in class_cards_list:
		tw.tween_property(card, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_SINE)
		tw.tween_interval(0.08)

func _on_class_selected(cls_name: String):
	if selected_class == cls_name:
		return
		
	var is_first_selection = (selected_class == "")
	selected_class = cls_name
	
	# Update title to class name
	title_label.text = cls_name.to_upper()
	
	# Highlight selected card, unhighlight others
	for key in card_panels:
		card_panels[key].add_theme_stylebox_override("panel", _make_card_style(key == cls_name))
	
	# Update description
	var stats = Global.class_data[cls_name]
	desc_label.text = stats["description"]
	
	if is_first_selection:
		# Show and fade in detail section + confirm button
		detail_section.visible = true
		confirm_btn.visible = true
		detail_section.modulate.a = 0.0
		confirm_btn.modulate.a = 0.0
		
		var tw = create_tween()
		tw.tween_property(detail_section, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_SINE)
		tw.parallel().tween_property(confirm_btn, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_SINE)
	
	# Update stat chart with animation
	stat_chart.set_stats(
		float(stats["hp"]),
		float(stats["def"]),
		float(stats["sta"]),
		float(stats["mana"]),
		true
	)

func _on_confirm_pressed():
	if selected_class == "":
		return
	Global.set_class(selected_class)
	get_tree().change_scene_to_file("res://DemoMap.tscn")

# === Style Helpers ===

func _make_card_style(is_selected: bool) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = CARD_SELECTED_COLOR if is_selected else CARD_NORMAL_COLOR
	style.border_color = CARD_SELECTED_BORDER if is_selected else CARD_BORDER_COLOR
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 4
	return style

func _make_detail_panel_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.14, 0.85)
	style.border_color = Color(0.3, 0.3, 0.45, 0.5)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	return style

func _make_confirm_btn_style(is_hover: bool) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	if is_hover:
		style.bg_color = Color(0.2, 0.55, 0.35, 0.95)
	else:
		style.bg_color = Color(0.12, 0.4, 0.25, 0.9)
	style.border_color = Color(0.3, 0.8, 0.5, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.shadow_color = Color(0.1, 0.4, 0.2, 0.3)
	style.shadow_size = 3
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

func _make_line_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.4, 0.35, 0.2, 0.5)
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	return style
