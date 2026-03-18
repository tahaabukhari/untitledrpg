extends Control

# Player Inventory UI — Minecraft-style layout
# Equipment section with player preview + scrollable 52-slot inventory grid

signal inventory_closed

var pixel_font: Font = null
var is_open := false
var is_transitioning := false

# Colors
const BG_COLOR := Color(0.05, 0.05, 0.09, 0.95)
const PANEL_BG := Color(0.08, 0.08, 0.14, 0.9)
const PANEL_BORDER := Color(0.35, 0.3, 0.2, 0.65)
const TITLE_COLOR := Color(0.9, 0.85, 0.55, 1.0)
const LABEL_COLOR := Color(0.7, 0.7, 0.78, 0.9)
const PREVIEW_BG := Color(0.06, 0.06, 0.1, 0.95)
const PREVIEW_BORDER := Color(0.25, 0.25, 0.4, 0.6)
const DIVIDER_COLOR := Color(0.35, 0.3, 0.2, 0.4)

var main_panel: PanelContainer = null
var inventory_slot_script = null

func _ready():
	pixel_font = load("res://fonts/PressStart2P.ttf")
	inventory_slot_script = load("res://inventory_slot.gd")
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()

func _build_ui():
	# === Dark overlay background ===
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.5)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	
	# === Centered main panel ===
	main_panel = PanelContainer.new()
	main_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	main_panel.custom_minimum_size = Vector2(520, 480)
	main_panel.add_theme_stylebox_override("panel", _make_main_panel_style())
	main_panel.anchor_left = 0.5
	main_panel.anchor_top = 0.5
	main_panel.anchor_right = 0.5
	main_panel.anchor_bottom = 0.5
	main_panel.offset_left = -260
	main_panel.offset_top = -240
	main_panel.offset_right = 260
	main_panel.offset_bottom = 240
	main_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	main_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(main_panel)
	
	# === Inner margin ===
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	main_panel.add_child(margin)
	
	var root_vbox = VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 10)
	margin.add_child(root_vbox)
	
	# === Title bar with back button ===
	var title_bar = HBoxContainer.new()
	title_bar.add_theme_constant_override("separation", 8)
	root_vbox.add_child(title_bar)
	
	var title = Label.new()
	title.text = "INVENTORY"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if pixel_font:
		title.add_theme_font_override("font", pixel_font)
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", TITLE_COLOR)
	title_bar.add_child(title)
	
	var back_btn = Button.new()
	back_btn.text = "✕"
	back_btn.custom_minimum_size = Vector2(36, 36)
	if pixel_font:
		back_btn.add_theme_font_override("font", pixel_font)
	back_btn.add_theme_font_size_override("font_size", 14)
	back_btn.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3, 1.0))
	back_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.4, 0.4, 1.0))
	back_btn.add_theme_stylebox_override("normal", _make_close_btn_style(false))
	back_btn.add_theme_stylebox_override("hover", _make_close_btn_style(true))
	back_btn.add_theme_stylebox_override("pressed", _make_close_btn_style(true))
	back_btn.add_theme_stylebox_override("focus", _make_close_btn_style(false))
	back_btn.pressed.connect(close_inventory)
	title_bar.add_child(back_btn)
	
	# === Separator ===
	var sep = HSeparator.new()
	sep.add_theme_stylebox_override("separator", _make_sep_style())
	root_vbox.add_child(sep)
	
	# === Equipment Section ===
	var equip_section = HBoxContainer.new()
	equip_section.add_theme_constant_override("separation", 14)
	equip_section.custom_minimum_size = Vector2(0, 200)
	root_vbox.add_child(equip_section)
	
	# -- Left column: Armor slots --
	var armor_col = VBoxContainer.new()
	armor_col.alignment = BoxContainer.ALIGNMENT_CENTER
	armor_col.add_theme_constant_override("separation", 6)
	equip_section.add_child(armor_col)
	
	armor_col.add_child(_make_equip_slot("helmet"))
	armor_col.add_child(_make_equip_slot("chest"))
	armor_col.add_child(_make_equip_slot("pants"))
	armor_col.add_child(_make_equip_slot("boots"))
	
	# -- Center: Player Preview --
	var preview_panel = PanelContainer.new()
	preview_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_panel.custom_minimum_size = Vector2(140, 180)
	preview_panel.add_theme_stylebox_override("panel", _make_preview_style())
	equip_section.add_child(preview_panel)
	
	var preview_vbox = VBoxContainer.new()
	preview_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	preview_panel.add_child(preview_vbox)
	
	var preview_label = Label.new()
	preview_label.text = "PLAYER\nPREVIEW"
	preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if pixel_font:
		preview_label.add_theme_font_override("font", pixel_font)
	preview_label.add_theme_font_size_override("font_size", 9)
	preview_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5, 0.5))
	preview_vbox.add_child(preview_label)
	
	# -- Right column: Weapons + Trinkets --
	var right_col = VBoxContainer.new()
	right_col.alignment = BoxContainer.ALIGNMENT_CENTER
	right_col.add_theme_constant_override("separation", 6)
	equip_section.add_child(right_col)
	
	right_col.add_child(_make_equip_slot("mainhand"))
	right_col.add_child(_make_equip_slot("offhand"))
	
	# Trinket sub-row
	var trinket_sep = HSeparator.new()
	trinket_sep.add_theme_stylebox_override("separator", _make_sep_style())
	right_col.add_child(trinket_sep)
	
	right_col.add_child(_make_equip_slot("trinket"))
	right_col.add_child(_make_equip_slot("trinket"))
	
	# === Separator between equip and inventory ===
	var sep2 = HSeparator.new()
	sep2.add_theme_stylebox_override("separator", _make_sep_style())
	root_vbox.add_child(sep2)
	
	# === Inventory Label ===
	var inv_label = Label.new()
	inv_label.text = "ITEMS"
	if pixel_font:
		inv_label.add_theme_font_override("font", pixel_font)
	inv_label.add_theme_font_size_override("font_size", 10)
	inv_label.add_theme_color_override("font_color", LABEL_COLOR)
	root_vbox.add_child(inv_label)
	
	# === Scrollable Inventory Grid ===
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 130)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	
	# Style the scrollbar
	var scroll_style = StyleBoxFlat.new()
	scroll_style.bg_color = Color(0, 0, 0, 0)
	scroll.add_theme_stylebox_override("panel", scroll_style)
	root_vbox.add_child(scroll)
	
	var grid = GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 5)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	
	# Create 52 inventory slots (2 rows of 26 = approx 7 rows of 8)
	for i in range(52):
		var slot = PanelContainer.new()
		slot.set_script(inventory_slot_script)
		slot.set_slot_type("inventory", i)
		grid.add_child(slot)

# === Equipment slot helper ===
func _make_equip_slot(type: String) -> PanelContainer:
	var slot = PanelContainer.new()
	slot.set_script(inventory_slot_script)
	slot.set_slot_type(type)
	return slot

# === Open / Close ===
func open_inventory():
	if is_transitioning or is_open:
		return
	is_transitioning = true
	is_open = true
	visible = true
	
	# Tween: pop in
	main_panel.pivot_offset = main_panel.size / 2.0
	main_panel.scale = Vector2.ZERO
	main_panel.modulate.a = 0.0
	
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(main_panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(main_panel, "modulate:a", 1.0, 0.2)
	
	await tw.finished
	is_transitioning = false

func close_inventory():
	if is_transitioning or not is_open:
		return
	is_transitioning = true
	
	main_panel.pivot_offset = main_panel.size / 2.0
	
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(main_panel, "scale", Vector2.ZERO, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(main_panel, "modulate:a", 0.0, 0.15)
	
	await tw.finished
	visible = false
	is_open = false
	is_transitioning = false
	inventory_closed.emit()

# === Style Helpers ===

func _make_main_panel_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = BG_COLOR
	style.border_color = PANEL_BORDER
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0, 0, 0, 0.6)
	style.shadow_size = 12
	return style

func _make_preview_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = PREVIEW_BG
	style.border_color = PREVIEW_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	return style

func _make_close_btn_style(is_hover: bool) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.06, 0.06, 0.85) if not is_hover else Color(0.25, 0.08, 0.08, 0.95)
	style.border_color = Color(0.6, 0.2, 0.2, 0.6) if not is_hover else Color(0.8, 0.3, 0.3, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	return style

func _make_sep_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = DIVIDER_COLOR
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	return style
