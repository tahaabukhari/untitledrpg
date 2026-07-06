extends Node2D
## Code-drawn torch with additive glow.

const DungeonArt = preload("res://dungeon/dungeon_art.gd")

var _glow: Sprite2D = null
var _flame: Polygon2D = null
var _time := randf() * 10.0


func _ready() -> void:
	DungeonArt.add_line(self, PackedVector2Array([Vector2(0, 0), Vector2(0, -26)]),
		Color(0.34, 0.22, 0.12, 1.0), 4.0)
	DungeonArt.add_poly(self, PackedVector2Array([
		Vector2(-8, -28),
		Vector2(8, -28),
		Vector2(6, -20),
		Vector2(-6, -20),
	]), Color(0.55, 0.42, 0.16, 1.0))
	_glow = Sprite2D.new()
	_glow.texture = DungeonArt.radial_glow(48, Color(1.0, 0.72, 0.28, 0.5))
	_glow.centered = true
	_glow.position = Vector2(0, -28)
	_glow.material = CanvasItemMaterial.new()
	_glow.material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.z_index = -8
	add_child(_glow)
	_flame = DungeonArt.add_poly(self, PackedVector2Array([
		Vector2(-5, -18),
		Vector2(0, -38),
		Vector2(5, -18),
		Vector2(0, -8),
	]), Color(1.0, 0.68, 0.2, 0.95), Vector2.ZERO, 4)


func _process(delta: float) -> void:
	_time += delta * 3.5
	if _glow:
		var pulse := 0.92 + sin(_time) * 0.08
		_glow.scale = Vector2.ONE * pulse
		_glow.modulate.a = 0.42 + 0.12 * sin(_time * 1.4)
	if _flame:
		_flame.scale.x = 0.9 + sin(_time * 1.8) * 0.08
		_flame.scale.y = 0.95 + sin(_time * 2.3 + 1.0) * 0.1
