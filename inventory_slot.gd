extends PanelContainer

# A single inventory/equipment slot with RPG styling
# Can display an item icon and quantity label (for future use)

signal slot_pressed(slot: Control)

var slot_type := "inventory"  # "inventory", "helmet", "chest", "pants", "boots", "mainhand", "offhand", "trinket"
var slot_index := 0
var is_empty := true

var pixel_font: Font = null

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
		var type_label = Label.new()
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
