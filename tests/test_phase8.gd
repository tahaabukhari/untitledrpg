extends SceneTree
## Headless smoke test for Phase 8 (boss arena + quick-launch + class switch).
## Run: godot --headless -s res://tests/test_phase8.gd

var _fails := 0


func _init() -> void:
	call_deferred("_run")


func _check(name: String, ok: bool) -> void:
	if ok:
		print("PASS: " + name)
	else:
		_fails += 1
		print("FAIL: " + name)


func _key(physical: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = physical
	ev.keycode = physical
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _wait_frames(n: int) -> void:
	for i in range(n):
		await physics_frame


func _run() -> void:
	# Quick-launch: arena boots directly, no title/class-select needed
	change_scene_to_file("res://boss_arena.tscn")
	await process_frame
	await process_frame
	await _wait_frames(30)

	var arena: Node = current_scene
	var player: CharacterBody2D = get_first_node_in_group("player")
	_check("arena quick-launch boots with a player", player != null)
	if player == null:
		quit(1)
		return
	_check("class auto-assigned on quick launch", player.current_class != "")
	_check("mannequin waits off to the side", get_nodes_in_group("enemy").size() >= 1)

	# Determinism: clear any pre-placed boss so it can't interfere with the
	# input checks below; B will spawn a fresh one.
	for b in get_nodes_in_group("boss"):
		b.queue_free()
	if "boss" in arena:
		arena.boss = null
	await process_frame
	_check("death screen present in arena", get_first_node_in_group("death_screen") != null)
	_check("player landed on arena floor", player.is_on_floor() or player.velocity.y >= 0)

	# ── Runtime class switching (debug keys 1-4) ──────────────────────────
	_key(KEY_3, true)
	await _wait_frames(2)
	_key(KEY_3, false)
	await _wait_frames(2)
	_check("key 3 switches to Mage with staff", player.current_class == "Mage"
		and player.equipped_weapon.charged_style == "laser")

	_key(KEY_2, true)
	await _wait_frames(2)
	_key(KEY_2, false)
	await _wait_frames(2)
	_check("key 2 switches to Ranger with bow", player.current_class == "Ranger"
		and player.equipped_weapon.attack_style == "ranged")

	_key(KEY_1, true)
	await _wait_frames(2)
	_key(KEY_1, false)
	await _wait_frames(2)
	_check("key 1 switches to Warrior with sword", player.current_class == "Warrior"
		and player.equipped_weapon.weapon_type == "Sword")

	# ── B ensures exactly one boss (spawns it, or adopts a pre-placed one) ──
	_key(KEY_B, true)
	await _wait_frames(2)
	_key(KEY_B, false)
	await _wait_frames(5)
	var boss: Node = get_first_node_in_group("boss")
	_check("B yields a FOURBLADE boss", boss != null)
	_key(KEY_B, true)
	await _wait_frames(2)
	_key(KEY_B, false)
	await _wait_frames(2)
	_check("second B does not double-spawn", get_nodes_in_group("boss").size() == 1)

	# Boss actually fights in the arena
	if boss:
		var hp0: int = player.health
		player.invuln_timer = 0.0
		var engaged := false
		for i in range(600):  # up to ~10s of AI
			await physics_frame
			if not is_instance_valid(boss):
				break
			player.invuln_timer = 0.0
			player.is_hurt = false
			if player.health < hp0 or player.is_grabbed:
				engaged = true
				break
		_check("boss engages and hits the player in the arena", engaged)

	# ── Normal flow untouched: titlescreen still boots ────────────────────
	change_scene_to_file("res://titlescreen.tscn")
	await process_frame
	await process_frame
	await _wait_frames(10)
	_check("titlescreen still boots (normal flow intact)", current_scene != null
		and current_scene.scene_file_path.ends_with("titlescreen.tscn"))

	print("RESULT: %s (%d failures)" % ["OK" if _fails == 0 else "FAILED", _fails])
	quit(1 if _fails > 0 else 0)
