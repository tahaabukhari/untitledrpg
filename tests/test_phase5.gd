extends SceneTree
## Headless smoke test for Phase 5 (mannequin training dummy).
## Run: godot --headless -s res://tests/test_phase5.gd

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
	change_scene_to_file("res://DemoMap.tscn")
	await process_frame
	await process_frame
	await _wait_frames(20)

	var player: CharacterBody2D = get_first_node_in_group("player")
	if player == null:
		print("FAIL: no player")
		quit(1)
		return

	# Clear other enemies; spawn a mannequin next to the player
	for e in get_nodes_in_group("enemy"):
		e.queue_free()
	await process_frame

	var mann_scene: PackedScene = load("res://enemies/mannequin.tscn")
	var mann: CharacterBody2D = mann_scene.instantiate()
	current_scene.add_child(mann)
	mann.global_position = player.global_position + Vector2(60, 0)
	await _wait_frames(30)

	_check("mannequin in enemy group (player attacks can find it)", mann.is_in_group("enemy"))
	_check("mannequin on EnemyHurtbox layer", mann.collision_layer == 4)

	# ── Wail on it: damage + DPS readout ──────────────────────────────────
	var readout: Label = null
	for child in mann.get_children():
		if child is Label:
			readout = child
	_check("DPS readout label exists", readout != null)

	mann.take_damage(25)
	mann.take_damage(40)
	await _wait_frames(2)
	_check("hits tracked in readout", readout != null and "LAST 40" in readout.text)
	_check("DPS computed", readout != null and readout.text.begins_with("DPS") and not readout.text.begins_with("DPS 0.0"))
	_check("dummy takes damage but survives", mann.hp < mann.max_hp and not mann.is_dead)

	# Effectively unkillable
	mann.take_damage(99999999)
	_check("unkillable dummy clamps at 1 HP", mann.hp == 1 and not mann.is_dead)

	# Regen after quiet period (regen_delay 4s ≈ 240 frames + margin)
	await _wait_frames(280)
	_check("HP regenerates after quiet period", mann.hp == mann.max_hp)

	# ── Player hitbox actually connects with the dummy ────────────────────
	player.global_position = mann.global_position + Vector2(-40, -5)
	player.velocity = Vector2.ZERO
	var hp0: int = mann.hp
	player.facing = 1
	player.get_node("PlayerSkin").scale.x = abs(player.get_node("PlayerSkin").scale.x)
	player.is_attacking = true
	player.get_node("PlayerSkin").play_attack(Vector2(1, 0))
	await _wait_frames(30)
	_check("player swing damages the mannequin", mann.hp < hp0)

	# ── Parry practice mode ───────────────────────────────────────────────
	mann.attacks = true
	mann.swing_interval = 0.4  # fast for testing
	player.health = player.max_health
	player.invuln_timer = 0.0
	player.is_hurt = false
	var hp_player: int = player.health
	var got_hit := false
	for i in range(300):
		await physics_frame
		if not is_instance_valid(mann):
			break
		player.global_position = mann.global_position + Vector2(mann._face_dir * 26, -5)
		player.velocity = Vector2.ZERO
		if player.health < hp_player:
			got_hit = true
			break
	_check("practice swing damages the player (dodgeable telegraph)", got_hit)

	# Parry the next swing → mannequin staggers, swing interrupted
	player.invuln_timer = 0.0
	player.is_hurt = false
	player.stamina = player.max_stamina
	player.parry_cooldown_timer = 0.0
	player.parry_recovery_timer = 0.0
	player.facing = 1 if mann.global_position.x > player.global_position.x else -1
	player._perform_parry()
	await _wait_frames(1)
	var negated: bool = not player.take_damage(10, mann.global_position, Vector2.ZERO, mann)
	_check("parrying the dummy negates the hit", negated)
	_check("parried dummy staggers (swing interrupted)", mann.stagger_timer > 0.0 and not mann._swinging)

	print("RESULT: %s (%d failures)" % ["OK" if _fails == 0 else "FAILED", _fails])
	quit(1 if _fails > 0 else 0)
