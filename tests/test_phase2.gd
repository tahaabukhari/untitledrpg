extends SceneTree
## Headless smoke test for Phase 2 (player damage/death + 8-dir attacks).
## Run: godot --headless -s res://tests/test_phase2.gd

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
	if player == null:
		print("FAIL: no player")
		quit(1)
		return

	# Isolate from live enemy AI — damage is injected directly here
	for e in get_nodes_in_group("enemy"):
		e.queue_free()
	await process_frame

	# ── Hurtbox present with correct layer ────────────────────────────────
	var hurtbox: Area2D = player.get_node_or_null("Hurtbox")
	_check("player Hurtbox exists", hurtbox != null)
	_check("hurtbox on PlayerHurtbox layer (bit 4 = 8)", hurtbox != null and hurtbox.collision_layer == 8)

	# ── take_damage: mitigation + hurt state + i-frames ───────────────────
	var hp0: int = player.health
	var applied: bool = player.take_damage(20, player.global_position + Vector2(30, 0))
	_check("take_damage applies", applied)
	var expected_loss: int = maxi(20 - (player.defense + player.stat_def), 1)
	_check("defense mitigates damage (lost %d, expected %d)" % [hp0 - player.health, expected_loss],
		hp0 - player.health == expected_loss)
	_check("hurt state active", player.is_hurt)
	_check("i-frames granted", player.invuln_timer > 0.0)
	_check("knockback pushes away from source", player.velocity.x < 0.0)

	# Second hit during i-frames is ignored
	var hp1: int = player.health
	var applied2: bool = player.take_damage(20, player.global_position + Vector2(30, 0))
	_check("hit during i-frames ignored", not applied2 and player.health == hp1)

	await _wait_frames(40)
	_check("hurt state ends after hitstun", not player.is_hurt)

	# ── 8-directional attacks ─────────────────────────────────────────────
	var skin: Node2D = player.get_node("PlayerSkin")
	var anim_player: AnimationPlayer = skin.get_node("AnimPlayer")
	var hitbox: Area2D = skin.get_node("AttackHitbox")

	# Straight up (is_attacking set first, mirroring the real input flow)
	player.is_attacking = true
	skin.play_attack(Vector2(0, -1))
	await _wait_frames(2)
	_check("up attack uses directional swing", anim_player.current_animation.begins_with("dirswing_-2"))
	_check("up attack rotates hitbox to -90deg", absf(hitbox.rotation - (-PI / 2.0)) < 0.01)
	var fx: Node = Engine.get_main_loop().root.get_node("Fx")
	await _wait_frames(10)
	_check("directional slash VFX spawned under Fx", fx.get_child_count() > 0)
	await _wait_frames(40)
	_check("attack completion resets is_attacking", not player.is_attacking)
	_check("hitbox rotation restored after attack", absf(hitbox.rotation) < 0.01)

	# Diagonal down-forward
	player.is_attacking = true
	skin.play_attack(Vector2(1, 1))
	await _wait_frames(2)
	_check("diagonal attack uses directional swing", anim_player.current_animation.begins_with("dirswing_1"))
	_check("diagonal attack rotates hitbox to 45deg", absf(hitbox.rotation - PI / 4.0) < 0.01)
	await _wait_frames(40)

	# Horizontal keeps the weapon's authored animations (not a generated swing)
	player.is_attacking = true
	skin.play_attack(Vector2(1, 0))
	await _wait_frames(2)
	_check("horizontal attack keeps authored animation",
		anim_player.current_animation != ""
		and not anim_player.current_animation.begins_with("dirswing"))
	await _wait_frames(40)

	# ── Death + death screen ──────────────────────────────────────────────
	while player.health > 0 and not player.is_dead:
		player.invuln_timer = 0.0
		player.is_hurt = false
		player.take_damage(9999, player.global_position + Vector2(10, 0))
		await _wait_frames(1)
	_check("player dies at 0 HP", player.is_dead)

	# Death screen appears after the collapse delay (1.1s ≈ 70 physics frames)
	await _wait_frames(90)
	var screen: Node = get_first_node_in_group("death_screen")
	_check("death screen node exists", screen != null)
	var layer_visible := false
	if screen:
		for child in screen.get_children():
			if child is CanvasLayer and child.visible:
				layer_visible = true
	_check("death screen visible", layer_visible)
	_check("tree paused on death", paused)

	# Single respawn path
	paused = false
	print("RESULT: %s (%d failures)" % ["OK" if _fails == 0 else "FAILED", _fails])
	quit(1 if _fails > 0 else 0)
