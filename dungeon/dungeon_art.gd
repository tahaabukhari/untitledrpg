extends RefCounted
class_name DungeonArt
## Shared helper for code-drawn dungeon props and room dressing.

static func add_poly(parent: Node, points: PackedVector2Array, color: Color,
		pos: Vector2 = Vector2.ZERO, z: int = 0) -> Polygon2D:
	var poly := Polygon2D.new()
	poly.polygon = points
	poly.color = color
	poly.position = pos
	poly.z_index = z
	parent.add_child(poly)
	return poly


static func add_line(parent: Node, points: PackedVector2Array, color: Color,
		width: float = 2.0, pos: Vector2 = Vector2.ZERO, z: int = 0) -> Line2D:
	var line := Line2D.new()
	line.points = points
	line.default_color = color
	line.width = width
	line.position = pos
	line.z_index = z
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	parent.add_child(line)
	return line


static func add_rect(parent: Node, size: Vector2, color: Color,
		pos: Vector2 = Vector2.ZERO, z: int = 0) -> Polygon2D:
	return add_poly(parent, PackedVector2Array([
		Vector2.ZERO,
		Vector2(size.x, 0),
		Vector2(size.x, size.y),
		Vector2(0, size.y),
	]), color, pos, z)


static func add_stone_backdrop(parent: Node, width: float, height: float = 340.0) -> void:
	add_rect(parent, Vector2(width, height), Color(0.09, 0.1, 0.12, 1.0), Vector2(0, -height), -20)
	add_rect(parent, Vector2(width, 28), Color(0.14, 0.15, 0.18, 1.0), Vector2(0, -height), -19)
	var x := 12.0
	while x < width - 32.0:
		add_line(parent, PackedVector2Array([Vector2(0, 0), Vector2(18, 0)]),
			Color(0.16, 0.17, 0.2, 0.32), 2.0, Vector2(x, -height + 44.0 + float(int(x) % 24)), -18)
		x += 44.0


static func add_floor_visual(parent: Node, width: float, depth: float = 120.0) -> void:
	add_rect(parent, Vector2(width, depth), Color(0.13, 0.12, 0.11, 1.0), Vector2(0, 0), -5)
	add_rect(parent, Vector2(width, 10), Color(0.34, 0.31, 0.28, 1.0), Vector2(0, 0), -4)
	var x := 20.0
	while x < width - 24.0:
		var wobble := float(int(x / 17.0) % 3) * 2.0
		add_line(parent, PackedVector2Array([Vector2(0, 0), Vector2(0, 24 + wobble)]),
			Color(0.22, 0.2, 0.18, 0.55), 2.0, Vector2(x, 0), -3)
		x += 42.0


static func add_rubble(parent: Node, pos: Vector2, count: int = 4) -> void:
	for i in range(count):
		var ox := randf_range(-22.0, 22.0)
		var oy := randf_range(-6.0, 8.0)
		var w := randf_range(10.0, 24.0)
		var h := randf_range(6.0, 14.0)
		add_poly(parent, PackedVector2Array([
			Vector2(-w * 0.5, h * 0.2),
			Vector2(-w * 0.15, -h * 0.5),
			Vector2(w * 0.5, -h * 0.1),
			Vector2(w * 0.2, h * 0.45),
		]), Color(0.24, 0.22, 0.2, 1.0), pos + Vector2(ox, oy), -2)


static func add_vines(parent: Node, pos: Vector2, strands: int = 4, length: float = 70.0) -> void:
	for i in range(strands):
		var pts := PackedVector2Array()
		var base_x := float(i - strands / 2) * 8.0
		pts.append(Vector2(base_x, 0))
		pts.append(Vector2(base_x + randf_range(-4.0, 4.0), length * 0.35))
		pts.append(Vector2(base_x + randf_range(-8.0, 8.0), length * 0.7))
		pts.append(Vector2(base_x + randf_range(-10.0, 10.0), length))
		add_line(parent, pts, Color(0.2, 0.42, 0.22, 0.9), 2.0, pos, -10)
		add_poly(parent, PackedVector2Array([
			Vector2(-3, -1),
			Vector2(4, -2),
			Vector2(6, 4),
			Vector2(-2, 5),
		]), Color(0.3, 0.52, 0.25, 0.85), pos + Vector2(base_x + randf_range(-6.0, 6.0), length * randf_range(0.3, 0.85)), -9)


static func add_grass(parent: Node, pos: Vector2, blades: int = 5) -> void:
	for i in range(blades):
		var h := randf_range(12.0, 24.0)
		var x := float(i - blades / 2) * 5.0
		add_line(parent, PackedVector2Array([
			Vector2.ZERO,
			Vector2(randf_range(-2.0, 2.0), -h * 0.5),
			Vector2(randf_range(-4.0, 4.0), -h),
		]), Color(0.35, 0.55, 0.24, 0.9), 2.0, pos + Vector2(x, 0), -1)


static func add_mushrooms(parent: Node, pos: Vector2, count: int = 3) -> void:
	for i in range(count):
		var x := randf_range(-14.0, 14.0)
		var stem_h := randf_range(8.0, 13.0)
		add_line(parent, PackedVector2Array([Vector2(0, 0), Vector2(0, -stem_h)]),
			Color(0.87, 0.83, 0.74, 1.0), 2.0, pos + Vector2(x, 0), -1)
		add_poly(parent, PackedVector2Array([
			Vector2(-6, -stem_h),
			Vector2(0, -stem_h - 5),
			Vector2(6, -stem_h),
			Vector2(4, -stem_h + 3),
			Vector2(-4, -stem_h + 3),
		]), Color(0.8, 0.42, 0.28, 0.95), pos + Vector2(x, 0), -1)


static func radial_glow(radius: int, color: Color) -> Texture2D:
	var img := Image.create(radius * 2, radius * 2, false, Image.FORMAT_RGBA8)
	var center := Vector2(radius, radius)
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var dist := center.distance_to(Vector2(x, y)) / float(radius)
			var a := clampf(1.0 - dist, 0.0, 1.0)
			a = a * a * 0.65
			img.set_pixel(x, y, Color(color.r, color.g, color.b, color.a * a))
	return ImageTexture.create_from_image(img)
