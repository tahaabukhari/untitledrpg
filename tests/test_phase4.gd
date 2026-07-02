extends SceneTree
## Headless smoke test for Phase 4 (enemy combat framework).
## Run: godot --headless -s res://tests/test_phase4.gd

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
	await _wait_frames(30)

	var player: CharacterBody2D = get_first_node_in_group("player")
	var slime: Node = current_scene.get_node_or_null("slime")
	var whisperer: Node = current_scene.get_node_or_null("Whisperer")
	_check("player exists", player != null)
	_check("slime exists", slime != null)
	_check("whisperer exists in DemoMap", whisperer != null)
	if player == null or slime == null or whisperer == null:
		quit(1)
		return

	# ── EnemyBase integration (duck-typed to avoid -s load-order artifacts) ──
	_check("slime is EnemyBase", slime.has_method("apply_stagger") and slime.has_method("_has_line_of_sight"))
	_check("whisperer is EnemyBase", whisperer.has_method("apply_stagger") and whisperer.has_method("_has_line_of_sight"))
	_check("slime EXP scales with size (not fixed 10)",
		slime.exp_value >= 6.0 and slime.exp_value <= 30.0)
	_check("slime on EnemyHurtbox layer", slime.collision_layer == 4)
	_check("whisperer on EnemyHurtbox layer", whisperer.collision_layer == 4)
	_check("whisperer has HP now", whisperer.hp > 0)
	var slime_hitbox: Node = slime.get_node_or_null("EnemyHitbox")
	_check("slime has an EnemyHitbox area", slime_hitbox != null and slime_hitbox is Area2D)
	_check("enemy hitbox masks PlayerHurtbox", slime_hitbox != null and slime_hitbox.collision_mask == 8)

	# ── Line of sight ─────────────────────────────────────────────────────
	var old_player_pos: Vector2 = player.global_position
	player.global_position = slime.global_position + Vector2(120, 0)
	await _wait_frames(2)
	_check("LOS clear in the open", slime._has_line_of_sight())
	# Bury the player below the floor: the ray must now hit terrain
	player.global_position = slime.global_position + Vector2(0, 500)
	await _wait_frames(2)
	_check("LOS blocked through the floor", not slime._has_line_of_sight())

	# ── Slime lunge damages the player ────────────────────────────────────
	player.global_position = slime.global_position + Vector2(50, -5)
	player.velocity = Vector2.ZERO
	player.health = player.max_health
	player.invuln_timer = 0.0
	player.is_hurt = false
	var hp0: int = player.health
	var got_hit := false
	for i in range(240):  # up to ~4s for windup+lunge to land
		await physics_frame
		player.global_position.x = slime.global_position.x + 50  # stay in range
		if player.health < hp0:
			got_hit = true
			break
	_check("slime lunge damages the player", got_hit)

	# ── Parry staggers the attacker ───────────────────────────────────────
	player.stamina = player.max_stamina
	player.invuln_timer = 0.0
	player.is_hurt = false
	player.parry_cooldown_timer = 0.0
	player.parry_recovery_timer = 0.0
	player.facing = 1 if slime.global_position.x > player.global_position.x else -1
	player._perform_parry()
	await _wait_frames(1)
	var negated: bool = not player.take_damage(20, slime.global_position, Vector2.ZERO, slime)
	_check("parried enemy hit is negated", negated)
	_check("parried attacker is staggered", slime.stagger_timer > 0.0)

	# ── Killing enemies grants scaled EXP ─────────────────────────────────
	var exp0: float = player.exp_val
	var lvl0: int = player.level
	var slime_exp: float = slime.exp_value
	slime.take_damage(99999)
	await _wait_frames(2)
	_check("slime dies", slime.is_dead)
	var gained: float = player.exp_val - exp0
	_check("death granted scaled EXP (level-up safe)",
		lvl0 != player.level or absf(gained - slime_exp) < 0.01)
	await _wait_frames(30)
	_check("dead slime freed after fade", not is_instance_valid(slime) or slime.is_queued_for_deletion())

	# ── Whisperer damages the player too ──────────────────────────────────
	player.global_position = whisperer.global_position + Vector2(40, -5)
	player.velocity = Vector2.ZERO
	player.health = player.max_health
	player.invuln_timer = 0.0
	player.is_hurt = false
	var hp1: int = player.health
	var whisperer_hit := false
	for i in range(240):
		await physics_frame
		if not is_instance_valid(whisperer):
			break
		player.global_position.x = whisperer.global_position.x + 40
		if player.health < hp1:
			whisperer_hit = true
			break
	_check("whisperer attack damages the player", whisperer_hit)

	# Whisperer killable with EXP
	if is_instance_valid(whisperer):
		var exp1: float = player.exp_val
		var lvl1: int = player.level
		whisperer.take_damage(99999)
		await _wait_frames(2)
		_check("whisperer dies and grants EXP",
			whisperer.is_dead and (player.exp_val > exp1 or player.level > lvl1))
	else:
		_check("whisperer dies and grants EXP", false)

	player.global_position = old_player_pos
	print("RESULT: %s (%d failures)" % ["OK" if _fails == 0 else "FAILED", _fails])
	quit(1 if _fails > 0 else 0)
