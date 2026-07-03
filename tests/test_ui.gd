extends SceneTree
## Headless smoke test for the UI upgrade + character customization.
## Run: godot --headless -s res://tests/test_ui.gd

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


func _run() -> void:
	var global_node: Node = root.get_node("/root/Global")

	# ── Rename ────────────────────────────────────────────────────────────
	_check("game renamed to Wonders Of Creation",
		ProjectSettings.get_setting("application/config/name") == "Wonders Of Creation")

	# ── Customization scene builds ────────────────────────────────────────
	change_scene_to_file("res://character_customization.tscn")
	await process_frame
	await process_frame
	await _wait_frames(10)
	var swatch_count := 0
	var has_name_edit := false
	var stack: Array[Node] = [current_scene]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		if n is LineEdit:
			has_name_edit = true
		if n is Button and (n as Button).text == "":
			swatch_count += 1
		stack.append_array(n.get_children())
	_check("customization has a name field", has_name_edit)
	_check("customization has tint swatches (8+6+8)", swatch_count >= 22)

	# ── Selections flow into Global and onto the spawned player ──────────
	global_node.player_custom["name"] = "TESTHERO"
	global_node.player_custom["hair_color"] = Color(0.3, 0.5, 0.85)
	global_node.player_custom["skin_tone"] = Color(0.8, 0.6, 0.42)
	global_node.player_custom["outfit_color"] = Color(0.75, 0.3, 0.3)

	change_scene_to_file("res://DemoMap.tscn")
	await process_frame
	await process_frame
	await _wait_frames(15)
	var player: CharacterBody2D = get_first_node_in_group("player")
	_check("player spawns", player != null)
	if player:
		_check("hero name applied", player.player_name == "TESTHERO")
		var skin: Node2D = player.get_node("PlayerSkin")
		var hair: CanvasItem = skin.get_node("HeadPivot/HairPivot/Sprite")
		var head: CanvasItem = skin.get_node("HeadPivot/Sprite")
		var torso: CanvasItem = skin.get_node("TorsoPivot/Sprite")
		var face: CanvasItem = skin.get_node("HeadPivot/FacePivot/Sprite")
		_check("hair tint applied", hair.modulate.is_equal_approx(Color(0.3, 0.5, 0.85)))
		_check("skin tint applied", head.modulate.is_equal_approx(Color(0.8, 0.6, 0.42)))
		_check("outfit tint applied", torso.modulate.is_equal_approx(Color(0.75, 0.3, 0.3)))
		_check("face left untinted", face.modulate.is_equal_approx(Color(1, 1, 1)))
		var hud: Control = player.get_node("HUDLayer/PlayerHUD")
		_check("HUD shows the hero name", hud.player_name_text == "TESTHERO")

	# ── Titlescreen has the three menu buttons ────────────────────────────
	change_scene_to_file("res://titlescreen.tscn")
	await process_frame
	await process_frame
	await _wait_frames(10)
	var labels: Array[String] = []
	stack = [current_scene]
	while stack.size() > 0:
		var n2: Node = stack.pop_back()
		if n2 is Button:
			labels.append((n2 as Button).text)
		if n2 is Label and (n2 as Label).text == "WONDERS":
			labels.append("TITLE_LINE")
		stack.append_array(n2.get_children())
	_check("title shows WONDERS OF CREATION", "TITLE_LINE" in labels)
	_check("title has START GAME", "START GAME" in labels)
	_check("title has CUSTOMIZE HERO", "CUSTOMIZE HERO" in labels)
	_check("title has BOSS ARENA", "BOSS ARENA" in labels)

	print("RESULT: %s (%d failures)" % ["OK" if _fails == 0 else "FAILED", _fails])
	quit(1 if _fails > 0 else 0)
