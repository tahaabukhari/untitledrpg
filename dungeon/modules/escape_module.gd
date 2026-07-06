extends "res://dungeon/dungeon_module.gd"
class_name EscapeModule
## Authored Stage 1 module variants built from generated props and shapes.

const DungeonArt = preload("res://dungeon/dungeon_art.gd")
const SLIME_SCENE := preload("res://slime.tscn")
const BOSS_SCENE := preload("res://enemies/boss_fourblade.tscn")
const BREAKABLE_SCENE := preload("res://dungeon/props/pot.tscn")
const DOOR_SCENE := preload("res://dungeon/props/door.tscn")
const HEAVY_DOOR_SCENE := preload("res://dungeon/props/heavy_door.tscn")
const TORCH_SCENE := preload("res://dungeon/props/torch.tscn")
const LEVER_SCENE := preload("res://dungeon/props/lever.tscn")
const CHEST_SCENE := preload("res://dungeon/props/chest.tscn")
const EXIT_GATE_SCENE := preload("res://dungeon/props/exit_gate.tscn")

enum ModuleKind {
	CELL,
	CORRIDOR_VINES,
	CHAMBER_SMALL,
	CORRIDOR_POTS,
	GUARDROOM,
	CORRIDOR_MOSS,
	CHAMBER_LARGE,
	ANTECHAMBER,
	BOSS_CHAMBER,
}

@export var module_kind: ModuleKind = ModuleKind.CELL


func _ready() -> void:
	_configure()
	super._ready()
	if _built:
		return
	_built = true
	_build_shell()
	match module_kind:
		ModuleKind.CELL:
			_build_cell()
		ModuleKind.CORRIDOR_VINES:
			_build_corridor_vines()
		ModuleKind.CHAMBER_SMALL:
			_build_small_chamber()
		ModuleKind.CORRIDOR_POTS:
			_build_corridor_pots()
		ModuleKind.GUARDROOM:
			_build_guardroom()
		ModuleKind.CORRIDOR_MOSS:
			_build_corridor_moss()
		ModuleKind.CHAMBER_LARGE:
			_build_large_chamber()
		ModuleKind.ANTECHAMBER:
			_build_antechamber()
		ModuleKind.BOSS_CHAMBER:
			_build_boss_chamber()


func _configure() -> void:
	match module_kind:
		ModuleKind.CELL:
			module_width = 560.0
			tags = ["start", "cell"]
		ModuleKind.CORRIDOR_VINES, ModuleKind.CORRIDOR_POTS, ModuleKind.CORRIDOR_MOSS:
			module_width = 520.0
			tags = ["corridor"]
		ModuleKind.CHAMBER_SMALL:
			module_width = 720.0
			tags = ["combat", "small"]
		ModuleKind.GUARDROOM:
			module_width = 760.0
			tags = ["guardroom", "combat"]
		ModuleKind.CHAMBER_LARGE:
			module_width = 860.0
			tags = ["combat", "large"]
		ModuleKind.ANTECHAMBER:
			module_width = 640.0
			tags = ["transition", "boss"]
		ModuleKind.BOSS_CHAMBER:
			module_width = 1040.0
			tags = ["boss", "exit"]


func _build_shell() -> void:
	DungeonArt.add_stone_backdrop(self, module_width, 330.0)
	var floor := StaticBody2D.new()
	floor.position = Vector2(module_width * 0.5, 60)
	floor.collision_layer = 1
	floor.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(module_width, 120)
	shape.shape = rect
	floor.add_child(shape)
	add_child(floor)
	DungeonArt.add_floor_visual(self, module_width)
	DungeonArt.add_poly(self, PackedVector2Array([
		Vector2(0, -320),
		Vector2(26, -320),
		Vector2(26, 0),
		Vector2(0, 0),
	]), Color(0.12, 0.13, 0.15, 1.0), Vector2.ZERO, -15)
	DungeonArt.add_poly(self, PackedVector2Array([
		Vector2(module_width - 26, -320),
		Vector2(module_width, -320),
		Vector2(module_width, 0),
		Vector2(module_width - 26, 0),
	]), Color(0.12, 0.13, 0.15, 1.0), Vector2.ZERO, -15)


func _spawn_slime(pos: Vector2) -> void:
	var slime := SLIME_SCENE.instantiate()
	add_child(slime)
	slime.position = pos


func _spawn_pot(pos: Vector2) -> void:
	var pot := BREAKABLE_SCENE.instantiate()
	add_child(pot)
	pot.position = pos


func _spawn_torch(pos: Vector2) -> void:
	var torch := TORCH_SCENE.instantiate()
	add_child(torch)
	torch.position = pos


func _spawn_door(pos: Vector2, heavy: bool = false):
	var door := (HEAVY_DOOR_SCENE if heavy else DOOR_SCENE).instantiate()
	add_child(door)
	door.position = pos
	return door


func _build_cell() -> void:
	set_player_spawn(Vector2(140, 0))
	_spawn_torch(Vector2(92, -160))
	_spawn_torch(Vector2(260, -150))
	DungeonArt.add_poly(self, PackedVector2Array([
		Vector2(0, -200),
		Vector2(110, -200),
		Vector2(110, -20),
		Vector2(0, -20),
	]), Color(0.09, 0.09, 0.11, 0.95), Vector2(16, 0), -11)
	for i in range(4):
		DungeonArt.add_line(self, PackedVector2Array([Vector2.ZERO, Vector2(0, 118)]),
			Color(0.56, 0.62, 0.68, 0.85), 3.0, Vector2(44 + i * 18, -154), -9)
	DungeonArt.add_rubble(self, Vector2(402, -2), 5)
	_spawn_pot(Vector2(320, 0))
	_spawn_door(Vector2(module_width - 42, 0))


func _build_corridor_vines() -> void:
	_spawn_torch(Vector2(120, -158))
	_spawn_torch(Vector2(380, -158))
	DungeonArt.add_vines(self, Vector2(140, -300), 4, 84.0)
	DungeonArt.add_vines(self, Vector2(340, -300), 5, 76.0)
	DungeonArt.add_grass(self, Vector2(112, 0), 5)
	DungeonArt.add_grass(self, Vector2(402, 0), 4)
	_spawn_pot(Vector2(262, 0))


func _build_small_chamber() -> void:
	_spawn_torch(Vector2(100, -154))
	_spawn_torch(Vector2(620, -154))
	_spawn_slime(Vector2(230, -20))
	_spawn_slime(Vector2(386, -20))
	_spawn_pot(Vector2(150, 0))
	_spawn_pot(Vector2(560, 0))
	DungeonArt.add_grass(self, Vector2(86, 0), 6)
	DungeonArt.add_vines(self, Vector2(532, -300), 4, 94.0)
	DungeonArt.add_rubble(self, Vector2(350, 4), 4)


func _build_corridor_pots() -> void:
	_spawn_torch(Vector2(180, -154))
	_spawn_pot(Vector2(170, 0))
	_spawn_pot(Vector2(240, 0))
	_spawn_pot(Vector2(320, 0))
	DungeonArt.add_rubble(self, Vector2(430, 2), 3)


func _build_guardroom() -> void:
	_spawn_torch(Vector2(110, -154))
	_spawn_torch(Vector2(644, -154))
	_spawn_slime(Vector2(360, -20))
	var door = _spawn_door(Vector2(module_width - 42, 0))
	var lever := LEVER_SCENE.instantiate()
	add_child(lever)
	lever.position = Vector2(190, -8)
	lever.target_path = lever.get_path_to(door)
	var chest := CHEST_SCENE.instantiate()
	add_child(chest)
	chest.position = Vector2(530, -2)
	(chest as Node).set("reward_item_id", &"ranger_bow")
	_spawn_pot(Vector2(274, 0))
	DungeonArt.add_rubble(self, Vector2(94, 2), 3)


func _build_corridor_moss() -> void:
	_spawn_torch(Vector2(300, -158))
	DungeonArt.add_vines(self, Vector2(248, -300), 5, 88.0)
	DungeonArt.add_mushrooms(self, Vector2(154, 0), 3)
	DungeonArt.add_grass(self, Vector2(352, 0), 5)


func _build_large_chamber() -> void:
	_spawn_torch(Vector2(110, -156))
	_spawn_torch(Vector2(744, -156))
	_spawn_slime(Vector2(230, -20))
	_spawn_slime(Vector2(430, -20))
	_spawn_slime(Vector2(620, -20))
	_spawn_pot(Vector2(144, 0))
	_spawn_pot(Vector2(690, 0))
	_spawn_pot(Vector2(510, 0))
	DungeonArt.add_grass(self, Vector2(98, 0), 5)
	DungeonArt.add_vines(self, Vector2(640, -300), 6, 104.0)
	DungeonArt.add_mushrooms(self, Vector2(336, 0), 4)
	DungeonArt.add_rubble(self, Vector2(438, 4), 5)


func _build_antechamber() -> void:
	_spawn_torch(Vector2(84, -156))
	_spawn_torch(Vector2(556, -156))
	_spawn_door(Vector2(module_width - 46, 0), true)
	DungeonArt.add_poly(self, PackedVector2Array([
		Vector2(0, -220),
		Vector2(84, -220),
		Vector2(84, -8),
		Vector2(0, -8),
	]), Color(0.08, 0.07, 0.09, 0.95), Vector2(280, 0), -12)
	DungeonArt.add_rubble(self, Vector2(210, 3), 4)
	DungeonArt.add_rubble(self, Vector2(428, 3), 4)


func _build_boss_chamber() -> void:
	_spawn_torch(Vector2(110, -158))
	_spawn_torch(Vector2(870, -158))
	var boss := BOSS_SCENE.instantiate()
	add_child(boss)
	boss.position = Vector2(534, -120)
	var gate := EXIT_GATE_SCENE.instantiate()
	add_child(gate)
	gate.position = Vector2(module_width - 82, 0)
	DungeonArt.add_poly(self, PackedVector2Array([
		Vector2(0, -250),
		Vector2(150, -250),
		Vector2(150, -10),
		Vector2(0, -10),
	]), Color(0.08, 0.09, 0.11, 0.95), Vector2(416, 0), -12)
	DungeonArt.add_rubble(self, Vector2(268, 3), 5)
	DungeonArt.add_rubble(self, Vector2(776, 3), 5)
