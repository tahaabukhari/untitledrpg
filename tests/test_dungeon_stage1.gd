extends SceneTree
## Headless smoke test for the new dungeon Stage 1.

var _fails := 0


func _init() -> void:
	call_deferred("_run")


func _check(name: String, ok: bool) -> void:
	if ok:
		print("PASS: " + name)
	else:
		_fails += 1
		print("FAIL: " + name)


func _wait_frames(n: int) -> void:
	for i in range(n):
		await physics_frame


func _count_inventory_items(ui: Node) -> int:
	var count := 0
	for slot in ui.inventory_slots:
		if not slot.is_empty:
			count += 1
	return count


func _run() -> void:
	change_scene_to_file("res://dungeon/dungeon_stage_1.tscn")
	await process_frame
	await process_frame
	await _wait_frames(40)

	var scene := current_scene
	var player := get_first_node_in_group("player")
	_check("stage scene loads", scene != null and scene.scene_file_path.ends_with("dungeon_stage_1.tscn"))
	_check("player spawns in stage", player != null)
	if scene == null or player == null:
		print("RESULT: FAILED (%d failures)" % _fails)
		quit(1)
		return

	var assembler := scene.get_node_or_null("DungeonAssembler")
	_check("assembler exists", assembler != null)
	_check("layout assembled into 9 modules", assembler != null and assembler.modules.size() == 9)
	_check("boss exists in final chamber", get_first_node_in_group("boss") != null)

	var gate: Node = null
	var lever: Node = null
	var door: Node = null
	var chest: Node = null
	for node in scene.find_children("*", "", true, false):
		if gate == null and node.name == "ExitGate":
			gate = node
		elif lever == null and node.name == "Lever":
			lever = node
		elif chest == null and node.name == "Chest":
			chest = node
		elif door == null and node.name == "Door":
			door = node

	_check("exit gate exists", gate != null)
	_check("guardroom lever exists", lever != null)
	_check("breakable door exists", door != null)
	_check("reward chest exists", chest != null)

	if lever != null:
		var linked = lever.get_node_or_null(lever.target_path)
		if linked != null:
			door = linked
	if lever != null and door != null:
		lever.interact(player)
		await _wait_frames(2)
		_check("lever opens linked door", door.collision_layer == 0)

	if chest != null and player.has_node("HUDLayer/InventoryUI"):
		var ui := player.get_node("HUDLayer/InventoryUI")
		var before := _count_inventory_items(ui)
		chest.interact(player)
		await _wait_frames(2)
		var after := _count_inventory_items(ui)
		_check("chest grants a reward or fallback", after >= before)

	var boss := get_first_node_in_group("boss")
	if boss != null and gate != null:
		boss.take_damage(999999)
		await _wait_frames(25)
		_check("boss death unlocks exit gate", gate.locked == false)

	print("RESULT: %s (%d failures)" % ["OK" if _fails == 0 else "FAILED", _fails])
	quit(1 if _fails > 0 else 0)
