extends Node2D
## Assembles a linear module list into one continuous dungeon.

@export var layout: Array[String] = []
@export var player_path: NodePath = ^"../Player"

var modules: Array[Node] = []


func _ready() -> void:
	assemble()


func assemble() -> void:
	for child in get_children():
		child.queue_free()
	modules.clear()

	var cursor := Vector2.ZERO
	var spawn_pos := Vector2(96, -80)
	for i in range(layout.size()):
		var path := layout[i]
		var packed := load(path) as PackedScene
		if packed == null:
			push_warning("DungeonAssembler: missing module scene %s" % path)
			continue
		var module := packed.instantiate()
		if module == null:
			push_warning("DungeonAssembler: scene is not a DungeonModule %s" % path)
			continue
		add_child(module)
		var left = module.get_node_or_null("PortLeft")
		if left == null:
			left = module._ensure_marker("PortLeft", Vector2.ZERO)
		module.position = cursor - left.position
		var right = module.get_node_or_null("PortRight")
		if right == null:
			right = module._ensure_marker("PortRight", Vector2(module.module_width, 0))
		cursor = module.position + right.position
		modules.append(module)
		if i == 0:
			var spawn = module.get_node_or_null("PlayerSpawn")
			if spawn:
				spawn_pos = spawn.global_position + Vector2(0, -80)
	var player := get_node_or_null(player_path) as Node2D
	if player:
		player.global_position = spawn_pos
