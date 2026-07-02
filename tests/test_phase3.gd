extends SceneTree
## Headless smoke test for Phase 3 (dodge roll + parry).
## Run: godot --headless -s res://tests/test_phase3.gd

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
	change_scene_to_file("res://DemoMap.tscn")
	await process_frame
	await process_frame
	await _wait_frames(60)

	var player: CharacterBody2D = get_first_node_in_group("player")
	if player == null:
		print("FAIL: no player")
		quit(1)
		return

	# ── Dodge roll basics ─────────────────────────────────────────────────
	var x0: float = player.global_position.x
	var sta0: float = player.stamina
	player._perform_dodge_roll()
	await _wait_frames(2)
	_check("roll starts", player.is_rolling)
	_check("roll costs stamina", player.stamina < sta0)
	_check("roll grants i-frames", player.invuln_timer > 0.0)

	# Damage during the roll is ignored (walk through an attack unharmed)
	var hp0: int = player.health
	var applied: bool = player.take_damage(25, player.global_position + Vector2(20, 0))
	_check("hit during roll ignored", not applied and player.health == hp0)

	# Cannot attack mid-roll
	player._on_attack_button_pressed()
	_check("cannot attack mid-roll", not player.is_attacking)

	await _wait_frames(30)
	_check("roll ends after its window", not player.is_rolling)
	_check("roll moved the player", absf(player.global_position.x - x0) > 40.0)
	var skin: Node2D = player.get_node("PlayerSkin")
	_check("skin rotation reset after roll", absf(skin.rotation) < 0.01)

	# Roll cooldown blocks immediate re-roll
	player._perform_dodge_roll()
	_check("roll cooldown blocks instant re-roll", not player.is_rolling)

	# Direction: rolls toward movement input
	await _wait_frames(45)
	player.joystick_vector = Vector2(-1, 0)
	var x1: float = player.global_position.x
	player._perform_dodge_roll()
	await _wait_frames(30)
	_check("roll follows movement direction (left)", player.global_position.x < x1 - 40.0)
	player.joystick_vector = Vector2.ZERO
	await _wait_frames(45)

	# ── Keyboard dodge action (Shift) ─────────────────────────────────────
	player.stamina = player.max_stamina
	_key(KEY_SHIFT, true)
	await _wait_frames(2)
	_key(KEY_SHIFT, false)
	_check("Shift key triggers dodge via input layer", player.is_rolling)
	await _wait_frames(45)

	# ── Parry ─────────────────────────────────────────────────────────────
	player.stamina = player.max_stamina
	player.invuln_timer = 0.0
	player._perform_parry()
	await _wait_frames(1)
	_check("parry window opens", player.is_parrying)

	# Frontal hit inside the window → negated
	var hp1: int = player.health
	var front := player.global_position + Vector2(player.facing * 30.0, 0)
	var applied2: bool = player.take_damage(30, front)
	_check("perfect parry negates damage", not applied2 and player.health == hp1)
	_check("parry consumed after success", not player.is_parrying)
	_check("counter window opens (attack cooldown cleared)", player.attack_cooldown_timer == 0.0)

	# Mistimed hit (after the window) → damage
	await _wait_frames(60)
	player.invuln_timer = 0.0
	player.is_hurt = false
	var hp2: int = player.health
	var applied3: bool = player.take_damage(30, front)
	_check("mistimed hit still damages", applied3 and player.health < hp2)

	# Hit from behind during parry → damage
	await _wait_frames(60)
	player.stamina = player.max_stamina
	player.invuln_timer = 0.0
	player.is_hurt = false
	player.parry_cooldown_timer = 0.0
	player._perform_parry()
	await _wait_frames(1)
	var hp3: int = player.health
	var behind := player.global_position + Vector2(-player.facing * 30.0, 0)
	var applied4: bool = player.take_damage(30, behind)
	_check("hit from behind ignores parry", applied4 and player.health < hp3)

	print("RESULT: %s (%d failures)" % ["OK" if _fails == 0 else "FAILED", _fails])
	quit(1 if _fails > 0 else 0)
