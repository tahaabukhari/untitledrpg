extends SceneTree
## Headless smoke test for Phase 7 (fourblade miniboss).
## Run: godot --headless -s res://tests/test_phase7.gd

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
	for e in get_nodes_in_group("enemy"):
		e.queue_free()
	await process_frame

	var boss_scene: PackedScene = load("res://enemies/boss_fourblade.tscn")
	var boss: CharacterBody2D = boss_scene.instantiate()
	current_scene.add_child(boss)
	boss.global_position = player.global_position + Vector2(600, -60)
	await _wait_frames(30)

	_check("boss spawns on EnemyBase (enemy group)", boss.is_in_group("enemy") and boss.is_in_group("boss"))
	_check("boss starts with 3 swords summoned", boss.active_sword_count() == 3)

	# ── Sword power accrues over time, visibly telegraphed ────────────────
	var p0: float = -1.0
	for s in boss._swords:
		if s["active"]:
			p0 = s["power"]
			break
	await _wait_frames(120)  # ~2s
	var p1: float = -1.0
	var glow_alpha := 0.0
	for s in boss._swords:
		if s["active"]:
			p1 = s["power"]
			glow_alpha = s["glow"].color.a
			break
	_check("sword power accrues over time", p1 > p0)
	_check("power telegraphed via glow", glow_alpha > 0.15)

	# ── Striking spends the sword's power as its damage ───────────────────
	boss._begin_slash()
	var spent_dmg: int = boss.attack_damage
	_check("slash damage taken from accrued power", spent_dmg >= int(boss.power_min))
	var reset_ok := false
	if boss._attacking_sword >= 0:
		reset_ok = boss._swords[boss._attacking_sword]["power"] == boss.power_min
	_check("striking sword resets its power", reset_ok)
	await _wait_frames(70)

	# ── Summon/dismiss changes the active set ─────────────────────────────
	boss._set_active_swords([0])
	_check("dismiss leaves one sword", boss.active_sword_count() == 1)
	boss._set_active_swords([0, 1, 2, 3])
	_check("summon brings all four", boss.active_sword_count() == 4)

	# ── Dash attack damages the player ────────────────────────────────────
	player.global_position = boss.global_position + Vector2(-260, 40)
	player.velocity = Vector2.ZERO
	player.health = player.max_health
	player.invuln_timer = 0.0
	player.is_hurt = false
	var hp0: int = player.health
	boss.state_timer = 99.0
	boss._begin_dash_wind()
	await _wait_frames(3)
	boss.state_timer = 0.0  # skip the telegraph wait
	var dashed := false
	for i in range(90):
		await physics_frame
		if player.health < hp0:
			dashed = true
			break
	_check("telegraphed dash damages the player", dashed)
	await _wait_frames(60)

	# ── Grab: dodge i-frames avoid it ─────────────────────────────────────
	boss.velocity = Vector2.ZERO
	boss.global_position = player.global_position + Vector2(90, -40)
	player.invuln_timer = 1.0  # simulating dodge i-frames
	boss.face_dir = -1 if player.global_position.x < boss.global_position.x else 1
	boss._attempt_grab()
	_check("dodge i-frames beat the grab", not player.is_grabbed)

	# ── Grab connects when vulnerable → throw with airtime damage ─────────
	await _wait_frames(30)
	player.invuln_timer = 0.0
	player.is_hurt = false
	player.health = player.max_health
	hp0 = player.health
	boss.global_position = player.global_position + Vector2(90, -40)
	boss.face_dir = -1
	boss._attempt_grab()
	_check("grab seizes a vulnerable player", player.is_grabbed)
	# Throw happens after the hold; wait through hold + airtime + landing
	var landed_damage := false
	for i in range(240):
		await physics_frame
		if not player.is_grabbed and player.is_on_floor() and player.health < hp0:
			landed_damage = true
			break
	_check("throw deals impact + landing damage", landed_damage and player.health <= hp0 - 2)

	# ── Perfect parry staggers the boss ───────────────────────────────────
	await _wait_frames(30)
	player.is_hurt = false
	player.invuln_timer = 0.0
	player.stamina = player.max_stamina
	player.parry_cooldown_timer = 0.0
	player.parry_recovery_timer = 0.0
	player.facing = 1 if boss.global_position.x > player.global_position.x else -1
	player._perform_parry()
	await _wait_frames(1)
	var negated: bool = not player.take_damage(30, boss.global_position, Vector2.ZERO, boss)
	_check("perfect parry negates a boss hit", negated)
	_check("perfect parry staggers the boss (damage window)", boss.stagger_timer > 1.0)

	# ── Phase 2 below 50% HP ──────────────────────────────────────────────
	boss.take_damage(boss.max_hp / 2 + 10)
	await _wait_frames(5)
	_check("phase 2 triggers below half HP", boss.phase2)

	# ── Killable with scaled EXP ──────────────────────────────────────────
	var exp0: float = player.exp_val
	var lvl0: int = player.level
	boss.take_damage(999999)
	await _wait_frames(2)
	_check("boss dies", boss.is_dead)
	_check("boss grants big EXP", player.level > lvl0 or player.exp_val - exp0 >= 199.0)
	await _wait_frames(30)
	_check("dead boss freed (no orphans)", not is_instance_valid(boss) or boss.is_queued_for_deletion())

	print("RESULT: %s (%d failures)" % ["OK" if _fails == 0 else "FAILED", _fails])
	quit(1 if _fails > 0 else 0)
