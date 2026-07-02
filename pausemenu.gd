extends Panel

@export_node_path("TouchScreenButton") var pause_button_path: NodePath
@onready var resume_button: TouchScreenButton = $Resume/RESUMEBUTTON
@onready var retry_button: TouchScreenButton = $Retry/RETRYBUTTON
@onready var return_button: TouchScreenButton = $Return/RETURNBUTTON

var pause_button: TouchScreenButton
var pixel_font: Font = null

var menu_buttons: Array[Button] = []
var original_positions: Array[Vector2] = []
var is_transitioning := false

func _ready() -> void:
	process_mode = Node.ProcessMode.PROCESS_MODE_ALWAYS
	visible = false
	
	# Load pixel font
	pixel_font = load("res://fonts/PressStart2P.ttf")
	
	# Style the pause panel itself
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.06, 0.1, 0.92)
	panel_style.border_color = Color(0.4, 0.35, 0.2, 0.8)
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(8)
	panel_style.shadow_color = Color(0, 0, 0, 0.5)
	panel_style.shadow_size = 8
	add_theme_stylebox_override("panel", panel_style)
	
	# Add PAUSED title programmatically
	var title_label = Label.new()
	title_label.text = "PAUSED"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if pixel_font:
		title_label.add_theme_font_override("font", pixel_font)
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5, 1.0))
	title_label.add_theme_constant_override("outline_size", 4)
	title_label.add_theme_color_override("font_outline_color", Color(0.5, 0.35, 0.1, 0.5))
	title_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title_label.offset_top = 20
	title_label.offset_bottom = 60
	add_child(title_label)
	
	# Style the menu buttons
	var buttons = [
		[$Resume, "RESUME"],
		[$Retry, "RETRY"],
		[$Return, "RETURN"]
	]
	
	for btn_data in buttons:
		var btn: Button = btn_data[0]
		var text: String = btn_data[1]
		btn.text = text
		_apply_rpg_button_style(btn)
		menu_buttons.append(btn)
		original_positions.append(btn.position)
	
	# Connect pause button
	if pause_button_path:
		pause_button = get_node(pause_button_path) as TouchScreenButton
		if pause_button:
			pause_button.pressed.connect(_on_pause_button_pressed)
		else:
			push_error("PauseMenu: Node at pause_button_path is not a TouchScreenButton!")
	else:
		push_error("PauseMenu: No PauseButton path assigned!")

	resume_button.pressed.connect(_on_resumebutton_pressed)
	retry_button.pressed.connect(_on_retrybutton_pressed)
	return_button.pressed.connect(_on_returnbutton_pressed)

func _apply_rpg_button_style(btn: Button) -> void:
	if pixel_font:
		btn.add_theme_font_override("font", pixel_font)
	btn.add_theme_font_size_override("font_size", 12)
	btn.add_theme_color_override("font_color", Color(0.85, 0.8, 0.6, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.7, 1.0))
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.1, 0.09, 0.06, 0.9)
	normal_style.border_color = Color(0.55, 0.45, 0.2, 0.7)
	normal_style.set_border_width_all(2)
	normal_style.set_corner_radius_all(4)
	normal_style.content_margin_left = 16
	normal_style.content_margin_right = 16
	normal_style.content_margin_top = 8
	normal_style.content_margin_bottom = 8
	btn.add_theme_stylebox_override("normal", normal_style)
	
	var hover_style = normal_style.duplicate()
	hover_style.bg_color = Color(0.15, 0.12, 0.08, 0.95)
	hover_style.border_color = Color(0.75, 0.6, 0.25, 0.9)
	btn.add_theme_stylebox_override("hover", hover_style)
	
	var pressed_style = normal_style.duplicate()
	pressed_style.bg_color = Color(0.18, 0.15, 0.1, 1.0)
	pressed_style.border_color = Color(0.85, 0.7, 0.3, 1.0)
	btn.add_theme_stylebox_override("pressed", pressed_style)
	btn.add_theme_stylebox_override("focus", normal_style)

func _on_pause_button_pressed() -> void:
	if is_transitioning: return
	is_transitioning = true
	
	visible = true
	if pause_button:
		pause_button.visible = false
	get_tree().paused = true
	
	# Position relative to the pause button: 100px lower, 50px to the left
	if pause_button:
		position = Vector2(pause_button.position.x - 210, pause_button.position.y)
	
	# Setup initial state for tween
	pivot_offset = size / 2.0
	scale = Vector2.ZERO
	
	for btn in menu_buttons:
		btn.modulate.a = 0.0
		
	var tw = create_tween()
	# The menu itself pops in
	tw.tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Cascade the buttons fading in
	for i in range(menu_buttons.size()):
		var btn = menu_buttons[i]
		tw.tween_property(btn, "modulate:a", 1.0, 0.15).set_trans(Tween.TRANS_SINE)
		tw.tween_interval(0.06)
	
	await tw.finished
	is_transitioning = false

func _on_resumebutton_pressed() -> void:
	_close_menu()

func _on_retrybutton_pressed() -> void:
	if is_transitioning: return
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_returnbutton_pressed() -> void:
	if is_transitioning: return
	get_tree().paused = false
	get_tree().change_scene_to_file("res://titlescreen.tscn")

func _close_menu() -> void:
	if is_transitioning: return
	is_transitioning = true
	
	var tw = create_tween()
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "scale", Vector2.ZERO, 0.2)
	
	await tw.finished
	visible = false
	is_transitioning = false
	if pause_button:
		pause_button.visible = true
	get_tree().paused = false
