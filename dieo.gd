extends Node2D
## Death screen ("dieo"). Lives as a hidden CanvasLayer-based overlay in the
## level; the player calls show_death_screen() on death. UI is built
## programmatically to match the project's style.

var _layer: CanvasLayer = null
var _dim: ColorRect = null
var _title: Label = null
var _buttons: Array[Button] = []
var pixel_font: Font = null


func _ready() -> void:
	add_to_group("death_screen")
	# Keep working while the tree is paused (we pause it ourselves)
	process_mode = Node.PROCESS_MODE_ALWAYS

	pixel_font = load("res://fonts/PressStart2P.ttf")

	_layer = CanvasLayer.new()
	_layer.layer = 20
	_layer.visible = false
	add_child(_layer)

	# Full-screen dark red dim
	_dim = ColorRect.new()
	_dim.color = Color(0.05, 0.0, 0.0, 0.85)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(_dim)

	# "YOU DIED" title
	_title = Label.new()
	_title.text = "YOU DIED"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if pixel_font:
		_title.add_theme_font_override("font", pixel_font)
	_title.add_theme_font_size_override("font_size", 42)
	_title.add_theme_color_override("font_color", Color(0.75, 0.1, 0.1, 1.0))
	_title.add_theme_constant_override("outline_size", 6)
	_title.add_theme_color_override("font_outline_color", Color(0.2, 0.0, 0.0, 0.8))
	_title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_title.anchor_top = 0.28
	_title.anchor_bottom = 0.28
	_title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_dim.add_child(_title)

	# Buttons
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.anchor_top = 0.5
	vbox.anchor_bottom = 0.5
	vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	vbox.add_theme_constant_override("separation", 18)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_dim.add_child(vbox)

	var retry := _make_button("RETRY")
	retry.pressed.connect(_on_retry_pressed)
	vbox.add_child(retry)
	_buttons.append(retry)

	var title_btn := _make_button("TITLE SCREEN")
	title_btn.pressed.connect(_on_title_pressed)
	vbox.add_child(title_btn)
	_buttons.append(title_btn)


func _make_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(260, 52)
	if pixel_font:
		btn.add_theme_font_override("font", pixel_font)
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_color_override("font_color", Color(0.85, 0.8, 0.6, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.7, 1.0))
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)

	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(0.1, 0.05, 0.05, 0.9)
	normal_style.border_color = Color(0.55, 0.2, 0.15, 0.8)
	normal_style.set_border_width_all(2)
	normal_style.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", normal_style)

	var hover_style: StyleBoxFlat = normal_style.duplicate()
	hover_style.bg_color = Color(0.18, 0.07, 0.06, 0.95)
	hover_style.border_color = Color(0.8, 0.3, 0.2, 0.9)
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.add_theme_stylebox_override("pressed", hover_style)
	btn.add_theme_stylebox_override("focus", normal_style)
	return btn


func show_death_screen() -> void:
	if _layer.visible:
		return
	_layer.visible = true
	get_tree().paused = true

	# Fade-in drama: dim from transparent, title sinks into place
	_dim.modulate.a = 0.0
	for btn in _buttons:
		btn.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_dim, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)
	for btn in _buttons:
		tw.tween_property(btn, "modulate:a", 1.0, 0.25)


func _on_retry_pressed() -> void:
	_layer.visible = false
	Global.respawn()


func _on_title_pressed() -> void:
	_layer.visible = false
	get_tree().paused = false
	get_tree().change_scene_to_file("res://titlescreen.tscn")
