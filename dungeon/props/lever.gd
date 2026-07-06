extends "res://dungeon/interactable.gd"
## Lever that can open a linked breakable door.

const DungeonArt = preload("res://dungeon/dungeon_art.gd")

@export var target_path: NodePath

var _used := false
var _handle: Line2D = null


func _ready() -> void:
	prompt_text = "LEVER"
	super._ready()
	DungeonArt.add_poly(self, PackedVector2Array([
		Vector2(-10, 0),
		Vector2(10, 0),
		Vector2(8, -8),
		Vector2(-8, -8),
	]), Color(0.34, 0.31, 0.24, 1.0), Vector2(0, 0), 1)
	_handle = DungeonArt.add_line(self, PackedVector2Array([Vector2(0, 0), Vector2(0, -24)]),
		Color(0.7, 0.57, 0.2, 1.0), 4.0, Vector2(0, -8), 2)


func interact(by: Node) -> void:
	if _used:
		return
	_used = true
	super.interact(by)
	if _handle:
		_handle.rotation = -0.7
	var target := get_node_or_null(target_path)
	if target and target.has_method("open_by_switch"):
		target.open_by_switch()
	Fx.parry_spark(global_position + Vector2(0, -20))
