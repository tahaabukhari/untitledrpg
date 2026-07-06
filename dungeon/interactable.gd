extends Area2D
class_name Interactable
## Base interactable with a self-managed prompt.

signal interacted(by)

@export var prompt_text: String = "USE"
@export var interact_radius: float = 46.0

var _prompt: Label = null


func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 0
	collision_mask = 0
	monitorable = true
	monitoring = false

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = interact_radius
	shape.shape = circle
	add_child(shape)

	_prompt = Label.new()
	_prompt.text = "[E] " + prompt_text
	var pixel_font := load("res://fonts/PressStart2P.ttf")
	if pixel_font:
		_prompt.add_theme_font_override("font", pixel_font)
	_prompt.add_theme_font_size_override("font_size", 8)
	_prompt.add_theme_color_override("font_color", Color(0.96, 0.9, 0.7, 1.0))
	_prompt.add_theme_constant_override("outline_size", 3)
	_prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_prompt.position = Vector2(-34, -78)
	_prompt.visible = false
	add_child(_prompt)


func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if _prompt == null or player == null:
		return
	_prompt.visible = player.global_position.distance_to(global_position) <= interact_radius + 24.0


func interact(by: Node) -> void:
	interacted.emit(by)
