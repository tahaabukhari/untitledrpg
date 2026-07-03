extends SceneTree
## Headless smoke test for directional dodge + tripping.
## Run: godot --headless -s res://tests/test_dodge_trip.gd

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


func _reset_dodge(player: CharacterBody2D) -> void:
	player.stamina = player.max_stamina
	player.roll_cooldown = 0.0
	player.is_rolling = false
	player.invuln_timer = 0.0
	player.velocity = Vector2.ZERO


func _run() -> void:
	root.get_node("/root/Global").set_class("Warrior")
	change_scene_to_file("res://boss_arena.tscn")
	await process_frame
	await process_frame
	await _wait_frames(40)

	var player: CharacterBody2D = get_first_node_in_group("player")
	if player == null:
		print("FAIL: no player")
		quit(1)
		return
	for e in get_nodes_in_group("enemy"):
		e.queue_free()
	await process_frame

	# ── Variant select from MOVEMENT input ────────────────────────────────
	_reset_dodge(player)
	player.joystick_vector = Vector2(1, 0)          # side → roll
	player._perform_dodge_roll()
	_check("side input → ROLL", player.dodge_variant == player.DodgeVariant.ROLL and player.is_rolling)
	await _wait_frames(30)

	_reset_dodge(player)
	player.facing = 1
	player.joystick_vector = Vector2(0, 1)          # down → slide
	player._perform_dodge_roll()
	await _wait_frames(2)
	_check("down input → SLIDE", player.dodge_variant == player.DodgeVariant.SLIDE and player.is_rolling)
	_check("slide grants early i-frames", player.invuln_timer > 0.0)
	_check("slide runs in the facing direction", player.roll_direction == player.facing)
	await _wait_frames(40)

	_reset_dodge(player)
	player.joystick_vector = Vector2(0, -1)         # up → leap
	var vy0: float = player.velocity.y
	player._perform_dodge_roll()
	await _wait_frames(1)
	_check("up input → LEAP", player.dodge_variant == player.DodgeVariant.LEAP)
	_check("leap gives a strong upward pop", player.velocity.y < -400.0)
	_check("leap is airborne (not a grounded dodge)", not player.is_rolling)
	_check("leap grants i-frames", player.invuln_timer > 0.0)
	await _wait_frames(60)

	# ── Slide TRIP — bipeds only ──────────────────────────────────────────
	var mann_scene: PackedScene = load("res://enemies/mannequin.tscn")
	var biped: CharacterBody2D = mann_scene.instantiate()
	current_scene.add_child(biped)
	biped.trippable = true                          # a two-legged dummy
	var blob: CharacterBody2D = mann_scene.instantiate()
	current_scene.add_child(blob)
	blob.trippable = false                          # a legless dummy
	await _wait_frames(5)
	# Slide knockdown is a chance roll (player 60%, failures still pass through /
	# evade), bipeds only, and a success burns +50 stamina. Verify statistically.
	var knockdowns := 0
	var blob_downs := 0
	var stamina_on_knockdown := -1.0
	for i in range(30):
		biped.is_downed = false
		biped.downed_timer = 0.0
		blob.is_downed = false
		blob.downed_timer = 0.0
		_reset_dodge(player)
		player.stamina = player.max_stamina
		biped.global_position = player.global_position + Vector2(34, 0)
		blob.global_position = player.global_position + Vector2(44, 0)
		player.facing = 1
		player.joystick_vector = Vector2(0, 1)
		player._perform_dodge_roll()
		await _wait_frames(14)
		if biped.is_downed:
			knockdowns += 1
			stamina_on_knockdown = player.stamina
		if blob.is_downed:
			blob_downs += 1
		await _wait_frames(16)  # let the slide end
	_check("knockdown is a chance, not guaranteed (0 < %d < 30)" % knockdowns,
		knockdowns > 0 and knockdowns < 30)
	_check("legless dummy never tripped (bipedal-only rule)", blob_downs == 0)
	_check("successful knockdown burned +50 stamina (%.0f left of %d)" % [stamina_on_knockdown, player.max_stamina],
		stamina_on_knockdown >= 0.0 and stamina_on_knockdown <= player.max_stamina - 70)
	biped.queue_free()
	blob.queue_free()
	await _wait_frames(45)

	# ── Player gets tripped: downed, blocked, bonus damage, recovers ──────
	_reset_dodge(player)
	player.is_downed = false
	player.trip_immunity_timer = 0.0
	player.global_position.y = get_first_node_in_group("player").global_position.y
	player.velocity = Vector2.ZERO
	await _wait_frames(10)  # ensure grounded
	player.trip(2.0)
	_check("player trips (bipedal) → downed", player.is_downed)
	_check("downed blocks gameplay input", player._gameplay_blocked())
	# Bonus damage while downed vs. a normal hit
	player.health = player.max_health
	var hp0: int = player.health
	player.take_damage(20, player.global_position + Vector2(20, 0))
	var downed_loss: int = hp0 - player.health
	var normal_loss: int = maxi(20 - (player.defense + player.stat_def), 1)
	_check("downed takes BONUS damage (%d > %d)" % [downed_loss, normal_loss], downed_loss > normal_loss)
	_check("downed hit does not grant hurt i-frames", not player.is_hurt)

	# Recover after ~2s
	await _wait_frames(130)
	_check("stands up after ~2s", not player.is_downed)
	_check("brief i-frames on recovery", player.invuln_timer > 0.0 or player.trip_immunity_timer > 0.0)

	# ── i-frames beat a trip (can't be tripped mid-dodge) ─────────────────
	await _wait_frames(20)
	player.is_downed = false
	player.trip_immunity_timer = 0.0
	player.invuln_timer = 1.0
	player.trip(2.0)
	_check("i-frames beat the trip", not player.is_downed)

	print("RESULT: %s (%d failures)" % ["OK" if _fails == 0 else "FAILED", _fails])
	quit(1 if _fails > 0 else 0)
