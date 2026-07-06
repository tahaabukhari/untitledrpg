extends Node2D
class_name DungeonModule
## Base module contract for assembled dungeon rooms.

@export var module_width: float = 640.0
@export var tags: Array[String] = []

var _built := false


func _ready() -> void:
	_ensure_marker("PortLeft", Vector2.ZERO)
	_ensure_marker("PortRight", Vector2(module_width, 0))


func _ensure_marker(node_name: String, pos: Vector2) -> Marker2D:
	var marker := get_node_or_null(node_name) as Marker2D
	if marker == null:
		marker = Marker2D.new()
		marker.name = node_name
		add_child(marker)
	marker.position = pos
	return marker


func set_player_spawn(pos: Vector2) -> void:
	_ensure_marker("PlayerSpawn", pos)


func get_player_spawn() -> Marker2D:
	return get_node_or_null("PlayerSpawn") as Marker2D


func get_left_port() -> Marker2D:
	return get_node_or_null("PortLeft") as Marker2D


func get_right_port() -> Marker2D:
	return get_node_or_null("PortRight") as Marker2D
