extends Control

# Player Inventory UI — Minecraft-style layout
# Equipment section with player preview + scrollable 52-slot inventory grid

signal inventory_closed
signal weapon_equipped(weapon: WeaponData)
signal weapon_unequipped

var pixel_font: Font = null
var is_open := false
var is_transitioning := false

# Slot tracking
var inventory_slots: Array = []
var equip_slots: Dictionary = {}  # key: slot_type, value: slot Control
var preview_card: PanelContainer = null  # weapon preview popup

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
	# Add starting items based on class (delayed one frame so Global is ready)
	call_deferred("_add_starting_items")

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
	equip_section.add_theme_constant_override("separation", 10)
	equip_section.custom_minimum_size = Vector2(0, 210)
	root_vbox.add_child(equip_section)
	
	# -- Left column: Armor slots --
	var armor_col = VBoxContainer.new()
	armor_col.alignment = BoxContainer.ALIGNMENT_CENTER
	armor_col.add_theme_constant_override("separation", 6)
	equip_section.add_child(armor_col)
	
	var helmet_slot = _make_equip_slot("helmet")
	armor_col.add_child(helmet_slot)
	var chest_slot = _make_equip_slot("chest")
	armor_col.add_child(chest_slot)
	var pants_slot = _make_equip_slot("pants")
	armor_col.add_child(pants_slot)
	var boots_slot = _make_equip_slot("boots")
	armor_col.add_child(boots_slot)
	
	# -- Center: Player Preview (30% thinner) --
	var preview_container = VBoxContainer.new()
	preview_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_container.add_theme_constant_override("separation", 6)
	equip_section.add_child(preview_container)
	
	var preview_panel = PanelContainer.new()
	preview_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_panel.custom_minimum_size = Vector2(98, 150)
	preview_panel.add_theme_stylebox_override("panel", _make_preview_style())
	preview_container.add_child(preview_panel)
	
	# Character sprite preview — composite of all body parts
	var preview_center = CenterContainer.new()
	preview_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_panel.add_child(preview_center)
	
	# Use a Control as a container to layer sprites
	var char_container = Control.new()
	char_container.custom_minimum_size = Vector2(64, 80)
	preview_center.add_child(char_container)
	
	# Layer order: legs, torso, arms, head, face, hair
	var sprite_layers = [
		{"path": "res://sprites/player/male/male-leftleg-base.png",  "pos": Vector2(18, 52)},
		{"path": "res://sprites/player/male/male-rightleg-base.png", "pos": Vector2(30, 52)},
		{"path": "res://sprites/player/male/male-torso-base.png",    "pos": Vector2(16, 30)},
		{"path": "res://sprites/player/male/male-lefthand-base.png", "pos": Vector2(8, 38)},
		{"path": "res://sprites/player/male/male-righthand-base.png","pos": Vector2(42, 38)},
		{"path": "res://sprites/player/male/male-head-base.png",     "pos": Vector2(16, 4)},
		{"path": "res://sprites/player/male/male-face-base.png",     "pos": Vector2(16, 4)},
		{"path": "res://sprites/player/male/male-hair-base.png",     "pos": Vector2(16, 0)},
	]
	for layer in sprite_layers:
		var spr = Sprite2D.new()
		var tex = load(layer["path"])
		if tex:
			spr.texture = tex
		spr.position = layer["pos"]
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.scale = Vector2(2.5, 2.5)
		char_container.add_child(spr)
	
	# -- Weapon slots below the preview --
	var weapon_row = HBoxContainer.new()
	weapon_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	weapon_row.add_theme_constant_override("separation", 6)
	preview_container.add_child(weapon_row)
	
	var mainhand_slot = _make_equip_slot("mainhand")
	weapon_row.add_child(mainhand_slot)
	var offhand_slot = _make_equip_slot("offhand")
	weapon_row.add_child(offhand_slot)
	
	# -- Right column: Trinkets --
	var right_col = VBoxContainer.new()
	right_col.alignment = BoxContainer.ALIGNMENT_CENTER
	right_col.add_theme_constant_override("separation", 6)
	equip_section.add_child(right_col)
	
	var trinket1_slot = _make_equip_slot("trinket")
	right_col.add_child(trinket1_slot)
	var trinket2_slot = _make_equip_slot("trinket")
	right_col.add_child(trinket2_slot)
	
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
	
	# Create 52 inventory slots
	for i in range(52):
		var slot = PanelContainer.new()
		slot.set_script(inventory_slot_script)
		slot.set_slot_type("inventory", i)
		_wire_slot_signals(slot)
		inventory_slots.append(slot)
		grid.add_child(slot)

# === Equipment slot helper ===
func _make_equip_slot(type: String) -> PanelContainer:
	var slot = PanelContainer.new()
	slot.set_script(inventory_slot_script)
	slot.set_slot_type(type)
	_wire_slot_signals(slot)
	equip_slots[type] = slot
	return slot


func _wire_slot_signals(slot: Control) -> void:
	if slot.has_signal("item_equipped"):
		slot.item_equipped.connect(_on_item_equipped)
	if slot.has_signal("item_unequipped"):
		slot.item_unequipped.connect(_on_item_unequipped)
	if slot.has_signal("slot_pressed"):
		slot.slot_pressed.connect(_on_slot_clicked)


func _on_item_equipped(weapon: WeaponData, _stype: String) -> void:
	weapon_equipped.emit(weapon)


func _on_item_unequipped(_stype: String) -> void:
	weapon_unequipped.emit()


func _on_slot_clicked(slot: Control) -> void:
	if slot.item != null:
		_show_weapon_preview_card(slot.item, slot)


# ─── Weapon Preview Card ─────────────────────────────────────────────────────

func _show_weapon_preview_card(weapon: WeaponData, source_slot: Control) -> void:
	_dismiss_preview_card()
	
	preview_card = PanelContainer.new()
	preview_card.add_theme_stylebox_override("panel", _make_card_style())
	preview_card.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	preview_card.custom_minimum_size = Vector2(280, 320)
	preview_card.anchor_left = 0.5
	preview_card.anchor_top = 0.5
	preview_card.anchor_right = 0.5
	preview_card.anchor_bottom = 0.5
	preview_card.offset_left = -140
	preview_card.offset_top = -160
	preview_card.offset_right = 140
	preview_card.offset_bottom = 160
	add_child(preview_card)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	preview_card.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)
	
	# -- Close button row --
	var top_row = HBoxContainer.new()
	vbox.add_child(top_row)
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(spacer)
	var close_btn = Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(28, 28)
	if pixel_font:
		close_btn.add_theme_font_override("font", pixel_font)
	close_btn.add_theme_font_size_override("font_size", 10)
	close_btn.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3))
	close_btn.pressed.connect(_dismiss_preview_card)
	top_row.add_child(close_btn)
	
	# -- Weapon Icon (large) --
	var icon_center = CenterContainer.new()
	vbox.add_child(icon_center)
	var icon_rect = TextureRect.new()
	if weapon.weapon_icon:
		icon_rect.texture = weapon.weapon_icon
	icon_rect.custom_minimum_size = Vector2(64, 64)
	icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon_center.add_child(icon_rect)
	
	# -- Weapon Name --
	var name_label = Label.new()
	name_label.text = weapon.weapon_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if pixel_font:
		name_label.add_theme_font_override("font", pixel_font)
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", TITLE_COLOR)
	vbox.add_child(name_label)
	
	# -- Description --
	var desc_label = Label.new()
	desc_label.text = weapon.weapon_description
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if pixel_font:
		desc_label.add_theme_font_override("font", pixel_font)
	desc_label.add_theme_font_size_override("font_size", 7)
	desc_label.add_theme_color_override("font_color", LABEL_COLOR)
	vbox.add_child(desc_label)
	
	# -- Stats Grid --
	var sep = HSeparator.new()
	sep.add_theme_stylebox_override("separator", _make_sep_style())
	vbox.add_child(sep)
	
	var stats_grid = GridContainer.new()
	stats_grid.columns = 2
	stats_grid.add_theme_constant_override("h_separation", 16)
	stats_grid.add_theme_constant_override("v_separation", 3)
	vbox.add_child(stats_grid)
	
	var stat_entries = [
		["ATK", "%d-%d" % [weapon.atk_min, weapon.atk_max]],
		["CHARGED", str(weapon.charged_damage)],
		["KNOCKBACK", str(int(weapon.charged_knockback))],
		["STA COST", str(int(weapon.charged_stamina_cost))],
	]
	for entry in stat_entries:
		var key_lbl = Label.new()
		key_lbl.text = entry[0]
		if pixel_font:
			key_lbl.add_theme_font_override("font", pixel_font)
		key_lbl.add_theme_font_size_override("font_size", 7)
		key_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
		stats_grid.add_child(key_lbl)
		var val_lbl = Label.new()
		val_lbl.text = entry[1]
		if pixel_font:
			val_lbl.add_theme_font_override("font", pixel_font)
		val_lbl.add_theme_font_size_override("font_size", 7)
		val_lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.55))
		stats_grid.add_child(val_lbl)
	
	# -- Equip / Unequip Button --
	var btn_row = CenterContainer.new()
	vbox.add_child(btn_row)
	
	var is_equipped = (source_slot.slot_type == "mainhand" or source_slot.slot_type == "offhand")
	var equip_btn = Button.new()
	equip_btn.text = "UNEQUIP" if is_equipped else "EQUIP"
	equip_btn.custom_minimum_size = Vector2(120, 32)
	if pixel_font:
		equip_btn.add_theme_font_override("font", pixel_font)
	equip_btn.add_theme_font_size_override("font_size", 9)
	equip_btn.add_theme_stylebox_override("normal", _make_equip_btn_style(false))
	equip_btn.add_theme_stylebox_override("hover", _make_equip_btn_style(true))
	equip_btn.add_theme_stylebox_override("pressed", _make_equip_btn_style(true))
	equip_btn.add_theme_color_override("font_color", Color(0.9, 0.85, 0.55))
	equip_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.65))
	
	if is_equipped:
		equip_btn.pressed.connect(func():
			_unequip_weapon(source_slot)
			_dismiss_preview_card()
		)
	else:
		equip_btn.pressed.connect(func():
			_equip_weapon_from_inventory(source_slot)
			_dismiss_preview_card()
		)
	btn_row.add_child(equip_btn)


func _dismiss_preview_card() -> void:
	if preview_card and is_instance_valid(preview_card):
		preview_card.queue_free()
		preview_card = null


func _equip_weapon_from_inventory(source_slot: Control) -> void:
	var weapon = source_slot.item
	if weapon == null:
		return
	# Try mainhand first, then offhand
	var target_slot = null
	if equip_slots.has("mainhand") and equip_slots["mainhand"].is_empty:
		target_slot = equip_slots["mainhand"]
	elif equip_slots.has("offhand") and equip_slots["offhand"].is_empty:
		target_slot = equip_slots["offhand"]
	elif equip_slots.has("mainhand"):
		# Mainhand occupied — swap
		target_slot = equip_slots["mainhand"]
		var old_weapon = target_slot.item
		target_slot.set_item(weapon)
		source_slot.set_item(old_weapon)
		weapon_equipped.emit(weapon)
		return
	
	if target_slot:
		target_slot.set_item(weapon)
		source_slot.clear_item()
		weapon_equipped.emit(weapon)


func _unequip_weapon(equip_slot: Control) -> void:
	var weapon = equip_slot.item
	if weapon == null:
		return
	# Put back in first empty inventory slot
	for slot in inventory_slots:
		if slot.is_empty:
			slot.set_item(weapon)
			equip_slot.clear_item()
			weapon_unequipped.emit()
			return


func _make_card_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.1, 0.98)
	style.border_color = Color(0.6, 0.5, 0.2, 0.8)
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0, 0, 0, 0.7)
	style.shadow_size = 16
	return style


func _make_equip_btn_style(is_hover: bool) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.1, 0.05, 0.9) if not is_hover else Color(0.18, 0.15, 0.06, 0.95)
	style.border_color = Color(0.6, 0.5, 0.2, 0.7) if not is_hover else Color(0.8, 0.7, 0.3, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	return style


# ─── Item Management ─────────────────────────────────────────────────────────

func add_item(weapon: WeaponData) -> bool:
	## Add a weapon to the first empty inventory slot. Returns true if successful.
	for slot in inventory_slots:
		if slot.is_empty:
			slot.set_item(weapon)
			return true
	return false  # inventory full


func get_mainhand_weapon() -> WeaponData:
	## Returns the weapon in the mainhand slot, or null.
	if equip_slots.has("mainhand"):
		return equip_slots["mainhand"].item
	return null


func _add_starting_items() -> void:
	## Give class-appropriate starting weapons.
	var cls = Global.current_class
	match cls:
		"Mage":
			var staff = load("res://weapons/starter_staff.tres")
			if staff:
				add_item(staff)
		"Warrior":
			var sword = load("res://weapons/starter_sword.tres")
			if sword:
				add_item(sword)
		_:
			pass  # Other classes: no starting weapon (fists)

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
