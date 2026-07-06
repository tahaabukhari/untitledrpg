extends "res://dungeon/interactable.gd"
## Locked gate that opens after the boss dies, then returns to title on use.

const DungeonArt = preload("res://dungeon/dungeon_art.gd")

@export var next_scene_path: String = "res://titlescreen.tscn"

var locked := true
var _gate: Polygon2D = null


func _ready() -> void:
	prompt_text = "EXIT"
	super._ready()
	_gate = DungeonArt.add_poly(self, PackedVector2Array([
		Vector2(-26, -84),
		Vector2(26, -84),
		Vector2(26, 0),
		Vector2(-26, 0),
	]), Color(0.44, 0.46, 0.5, 0.92), Vector2.ZERO, 2)
	for i in range(3):
		DungeonArt.add_line(self, PackedVector2Array([Vector2(0, 0), Vector2(0, 72)]),
			Color(0.72, 0.76, 0.8, 0.85), 3.0, Vector2(-14 + i * 14, -76), 3)
	call_deferred("_bind_boss")


func _bind_boss() -> void:
	var boss := get_tree().get_first_node_in_group("boss")
	if boss and boss.has_signal("died") and not boss.died.is_connected(_on_boss_died):
		boss.died.connect(_on_boss_died)


func _on_boss_died() -> void:
	locked = false
	if _gate:
		_gate.modulate = Color(0.55, 0.9, 0.62, 0.45)
	Fx.parry_spark(global_position + Vector2(0, -50))


func interact(by: Node) -> void:
	if locked:
		Fx.hit_particles(global_position + Vector2(0, -30), Color(0.8, 0.92, 1.0, 1.0))
		return
	super.interact(by)
	get_tree().change_scene_to_file(next_scene_path)
