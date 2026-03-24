extends PanelContainer

# A single inventory/equipment slot with RPG styling
# Supports drag-and-drop of WeaponData items with icon display

signal slot_pressed(slot: Control)
signal item_equipped(weapon: WeaponData, slot_type: String)
signal item_unequipped(slot_type: String)

var slot_type := "inventory"  # "inventory", "helmet", "chest", "pants", "boots", "mainhand", "offhand", "trinket"
var slot_index := 0
var is_empty := true
var item: WeaponData = null

var pixel_font: Font = null
var icon_rect: TextureRect = null
var type_label: Label = null

# Slot visual config
const SLOT_SIZE := 48
const SLOT_BG := Color(0.08, 0.08, 0.14, 0.9)
const SLOT_BORDER := Color(0.3, 0.3, 0.45, 0.6)
const SLOT_HOVER_BORDER := Color(0.5, 0.75, 1.0, 0.8)
const EQUIP_BORDER := Color(0.7, 0.55, 0.2, 0.7)
const EQUIP_HOVER_BORDER := Color(0.95, 0.8, 0.4, 0.9)

func _init():
	custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)

func _ready():
	pixel_font = load("res://fonts/PressStart2P.ttf")
	_apply_style()

	# Icon for displaying item
	icon_rect = TextureRect.new()
	icon_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(icon_rect)

	# Add invisible click button
	var btn = Button.new()
	btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn.flat = true
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var transparent = StyleBoxFlat.new()
	transparent.bg_color = Color(0, 0, 0, 0)
	btn.add_theme_stylebox_override("normal", transparent)
	btn.add_theme_stylebox_override("hover", transparent)
	btn.add_theme_stylebox_override("pressed", transparent)
	btn.add_theme_stylebox_override("focus", transparent)
	btn.pressed.connect(func(): slot_pressed.emit(self))
	add_child(btn)

func _apply_style():
	var is_equip = slot_type != "inventory"
	var style = StyleBoxFlat.new()
	style.bg_color = SLOT_BG
	style.border_color = EQUIP_BORDER if is_equip else SLOT_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.shadow_color = Color(0, 0, 0, 0.25)
	style.shadow_size = 2
	add_theme_stylebox_override("panel", style)

func set_slot_type(type: String, idx: int = 0):
	slot_type = type
	slot_index = idx
	_apply_style()

	# Add a subtle type label for equipment slots
	if type != "inventory":
		type_label = Label.new()
		type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		type_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		type_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		if pixel_font:
			type_label.add_theme_font_override("font", pixel_font)
		type_label.add_theme_font_size_override("font_size", 6)
		type_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5, 0.5))

		match type:
			"helmet": type_label.text = "HEAD"
			"chest": type_label.text = "BODY"
			"pants": type_label.text = "LEGS"
			"boots": type_label.text = "FEET"
			"mainhand": type_label.text = "MAIN"
			"offhand": type_label.text = "OFF"
			"trinket": type_label.text = "TRNK"

		add_child(type_label)


# ─── Item Management ─────────────────────────────────────────────────────────

func set_item(weapon: WeaponData) -> void:
	item = weapon
	is_empty = (weapon == null)
	_update_icon()

func clear_item() -> void:
	item = null
	is_empty = true
	_update_icon()

func _update_icon() -> void:
	if not icon_rect:
		return
	if item and item.weapon_icon:
		icon_rect.texture = item.weapon_icon
		icon_rect.visible = true
		if type_label:
			type_label.visible = false
	else:
		icon_rect.texture = null
		icon_rect.visible = false
		if type_label:
			type_label.visible = true


# ─── Drag and Drop ───────────────────────────────────────────────────────────

func _get_drag_data(_at_position: Vector2) -> Variant:
	if is_empty or item == null:
		return null

	# Create drag preview
	var preview = TextureRect.new()
	preview.texture = item.weapon_icon
	preview.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.modulate = Color(1, 1, 1, 0.8)
	set_drag_preview(preview)

	# Return the drag payload
	var data = {"source_slot": self, "weapon": item}

	# Visually dim the source slot while dragging
	icon_rect.modulate = Color(1, 1, 1, 0.3)

	return data


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if data == null or not data is Dictionary:
		return false
	if not data.has("weapon"):
		return false

	# Only allow weapons in mainhand, offhand, or inventory slots
	if slot_type in ["mainhand", "offhand", "inventory"]:
		return true
	return false


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if data == null or not data is Dictionary:
		return

	var source_slot: Control = data["source_slot"]
	var dragged_weapon: WeaponData = data["weapon"]

	# Restore source slot visual
	if source_slot and source_slot.icon_rect:
		source_slot.icon_rect.modulate = Color.WHITE

	if source_slot == self:
		return  # Dropped on itself

	# Swap items between slots
	var my_old_item = item

	# Place dragged item in this slot
	set_item(dragged_weapon)

	# Place this slot's old item back in the source
	if my_old_item:
		source_slot.set_item(my_old_item)
	else:
		source_slot.clear_item()

	# Emit equip/unequip signals
	if slot_type == "mainhand":
		item_equipped.emit(dragged_weapon, slot_type)
	elif source_slot.slot_type == "mainhand":
		# Item was dragged OUT of mainhand
		if source_slot.item:
			item_equipped.emit(source_slot.item, "mainhand")
		else:
			item_unequipped.emit("mainhand")


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		# Reset icon modulate if drag was cancelled
		if icon_rect:
			icon_rect.modulate = Color.WHITE
