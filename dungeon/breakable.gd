extends StaticBody2D
class_name Breakable
## Smashable prop or door that shares the player combat path.

const DungeonArt = preload("res://dungeon/dungeon_art.gd")

const LAYER_ENVIRONMENT := 1
const LAYER_ENEMY_HURTBOX := 4

@export var max_hp: int = 1
@export var solid: bool = false
@export var prop_kind: String = "pot"
@export var body_size: Vector2 = Vector2(36, 42)

var hp: int = 1
var _shape: CollisionShape2D = null
var _opened := false


func _ready() -> void:
	add_to_group("breakable")
	hp = max_hp
	collision_layer = LAYER_ENEMY_HURTBOX | (LAYER_ENVIRONMENT if solid else 0)
	collision_mask = LAYER_ENVIRONMENT
	_build_collision()
	_build_visual()


func _build_collision() -> void:
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = body_size
	_shape.shape = rect
	_shape.position = Vector2(0, -body_size.y * 0.5)
	add_child(_shape)


func _build_visual() -> void:
	match prop_kind:
		"door", "heavy_door":
			DungeonArt.add_poly(self, PackedVector2Array([
				Vector2(-body_size.x * 0.5, -body_size.y),
				Vector2(body_size.x * 0.5, -body_size.y),
				Vector2(body_size.x * 0.5, 0),
				Vector2(-body_size.x * 0.5, 0),
			]), Color(0.36, 0.22, 0.12, 1.0), Vector2(0, 0), 1)
			DungeonArt.add_poly(self, PackedVector2Array([
				Vector2(-body_size.x * 0.5 + 6, -body_size.y + 8),
				Vector2(body_size.x * 0.5 - 6, -body_size.y + 8),
				Vector2(body_size.x * 0.5 - 6, -10),
				Vector2(-body_size.x * 0.5 + 6, -10),
			]), Color(0.46, 0.29, 0.17, 1.0), Vector2.ZERO, 2)
			for i in range(3):
				DungeonArt.add_line(self, PackedVector2Array([Vector2(0, 0), Vector2(0, body_size.y - 18)]),
					Color(0.23, 0.15, 0.09, 0.9), 3.0, Vector2(-body_size.x * 0.25 + i * body_size.x * 0.25, -body_size.y + 10), 3)
			if prop_kind == "heavy_door":
				DungeonArt.add_line(self, PackedVector2Array([Vector2(-body_size.x * 0.5 + 6, 0), Vector2(body_size.x * 0.5 - 6, 0)]),
					Color(0.58, 0.45, 0.18, 0.9), 4.0, Vector2(0, -body_size.y * 0.55), 4)
		"crate":
			DungeonArt.add_poly(self, PackedVector2Array([
				Vector2(-body_size.x * 0.5, -body_size.y),
				Vector2(body_size.x * 0.5, -body_size.y),
				Vector2(body_size.x * 0.5, 0),
				Vector2(-body_size.x * 0.5, 0),
			]), Color(0.38, 0.28, 0.18, 1.0), Vector2.ZERO, 1)
			DungeonArt.add_line(self, PackedVector2Array([Vector2(-body_size.x * 0.5, -body_size.y), Vector2(body_size.x * 0.5, 0)]),
				Color(0.25, 0.18, 0.11, 0.9), 3.0, Vector2.ZERO, 2)
			DungeonArt.add_line(self, PackedVector2Array([Vector2(body_size.x * 0.5, -body_size.y), Vector2(-body_size.x * 0.5, 0)]),
				Color(0.25, 0.18, 0.11, 0.9), 3.0, Vector2.ZERO, 2)
		_:
			DungeonArt.add_poly(self, PackedVector2Array([
				Vector2(-16, -34),
				Vector2(16, -28),
				Vector2(18, -6),
				Vector2(10, 0),
				Vector2(-12, -2),
				Vector2(-18, -14),
			]), Color(0.58, 0.47, 0.28, 1.0), Vector2.ZERO, 1)
			DungeonArt.add_poly(self, PackedVector2Array([
				Vector2(-10, -36),
				Vector2(10, -32),
				Vector2(12, -24),
				Vector2(-8, -26),
			]), Color(0.68, 0.58, 0.33, 1.0), Vector2.ZERO, 2)


func take_damage(amount: int, _knockback: Vector2 = Vector2.ZERO) -> void:
	if _opened:
		return
	hp -= amount
	if hp <= 0:
		_shatter()
	else:
		Fx.hit_particles(global_position, Color(0.92, 0.84, 0.52, 0.95))


func open_by_switch() -> void:
	if _opened:
		return
	_opened = true
	if _shape:
		_shape.set_deferred("disabled", true)
	collision_layer = 0
	Fx.splinters(global_position)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "position:y", position.y - 14.0, 0.14)
	tw.tween_property(self, "modulate:a", 0.15, 0.18)


func _shatter() -> void:
	if _opened:
		return
	_opened = true
	if prop_kind == "door" or prop_kind == "heavy_door":
		Fx.splinters(global_position)
	else:
		Fx.shatter(global_position, Color(0.72, 0.58, 0.34, 1.0))
	queue_free()
