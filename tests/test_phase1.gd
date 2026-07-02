extends SceneTree
## Headless smoke test for Phase 1 (unified input layer + PC controls).
## Run: godot --headless -s res://tests/test_phase1.gd
## Injects synthetic input events and asserts on player state.

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


func _touch(pos: Vector2, pressed: bool, index: int = 0) -> void:
	var ev := InputEventScreenTouch.new()
	ev.position = pos
	ev.pressed = pressed
	ev.index = index
	ev.device = 0  # real touch device (not mouse emulation)
	Input.parse_input_event(ev)


func _wait_frames(n: int) -> void:
	for i in range(n):
		await physics_frame


func _run() -> void:
	change_scene_to_file("res://DemoMap.tscn")
	await process_frame
	await process_frame
	await _wait_frames(5)

	var player: CharacterBody2D = get_first_node_in_group("player")
	_check("player exists", player != null)
	if player == null:
		quit(1)
		return

	var input_ctrl: Node = player.get_node("PlayerInput")
	_check("PlayerInput node exists", input_ctrl != null)

	# Let the player land on the floor first
	await _wait_frames(60)
	_check("player landed on floor", player.is_on_floor())

	# ── Keyboard movement (D → move right, switches to KBM mode) ──────────
	var x0: float = player.global_position.x
	_key(KEY_D, true)
	await _wait_frames(30)
	_key(KEY_D, false)
	await _wait_frames(5)
	_check("keyboard D moves player right", player.global_position.x > x0 + 20.0)
	_check("keyboard input switched mode to KBM", input_ctrl.mode == 1)

	var joystick: Control = player.get_node("TouchControls/JOYSTICK")
	_check("touch joystick hidden in KBM mode", not joystick.visible)

	# ── Jump (Space) ──────────────────────────────────────────────────────
	await _wait_frames(30)
	_check("player grounded before jump", player.is_on_floor())
	_key(KEY_SPACE, true)
	await _wait_frames(3)
	_key(KEY_SPACE, false)
	_check("space jump gives upward velocity", player.velocity.y < -100.0)
	await _wait_frames(90)

	# ── Attack tap (J, short press) ───────────────────────────────────────
	_key(KEY_J, true)
	await _wait_frames(2)
	_key(KEY_J, false)
	await _wait_frames(2)
	_check("attack tap starts attack", player.is_attacking)
	await _wait_frames(60)
	_check("attack finished after animation", not player.is_attacking)

	# ── Continuous charge (hold J past charge_time) ───────────────────────
	player.stamina = player.max_stamina
	_key(KEY_J, true)
	await _wait_frames(20)
	var mid_charge: float = input_ctrl.charge_level
	_check("charge level accumulates continuously (0 < mid < 1)",
		mid_charge > 0.05 and mid_charge < 1.0)
	await _wait_frames(60)
	_check("charge level caps at 1.0", input_ctrl.charge_level >= 1.0)
	var sta_before: float = player.stamina
	_key(KEY_J, false)
	await _wait_frames(2)
	_check("full-charge release triggers charged attack (stamina paid)",
		player.stamina < sta_before and player.is_attacking)
	await _wait_frames(80)

	# ── Real touch switches back to TOUCH mode ────────────────────────────
	_touch(Vector2(300, 400), true)
	await _wait_frames(2)
	_touch(Vector2(300, 400), false)
	await _wait_frames(2)
	_check("real touch switches mode back to TOUCH", input_ctrl.mode == 0)
	_check("touch joystick visible again", joystick.visible)

	# ── Aim vector: mouse aim in KBM mode ─────────────────────────────────
	_key(KEY_A, true)
	await _wait_frames(2)
	_key(KEY_A, false)
	await _wait_frames(2)
	var aim: Vector2 = input_ctrl.get_aim_vector()
	_check("aim vector is normalized or zero", aim == Vector2.ZERO or absf(aim.length() - 1.0) < 0.01)

	print("RESULT: %s (%d failures)" % ["OK" if _fails == 0 else "FAILED", _fails])
	quit(1 if _fails > 0 else 0)
