extends SceneTree
## Headless smoke test for the Mirror Warrior duel partner.
## Run: godot --headless -s res://tests/test_mirror.gd

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

	var scene: PackedScene = load("res://enemies/mirror_warrior.tscn")
	var mirror: CharacterBody2D = scene.instantiate()
	current_scene.add_child(mirror)
	mirror.global_position = player.global_position + Vector2(200, 0)
	await _wait_frames(10)

	# ── Identity: reuses the player puppet, blue, bipedal, bleeds ─────────
	_check("mirror is an enemy on EnemyBase", mirror.is_in_group("enemy") and mirror.collision_layer == 4)
	_check("mirror reuses the player puppet (Skin child w/ animator)",
		mirror.get_node_or_null("Skin") != null and mirror._skin.has_method("play_attack"))
	_check("mirror is tinted blue", mirror.modulate.b > mirror.modulate.r)
	_check("mirror is bipedal (trippable)", mirror.trippable)
	_check("mirror bleeds (flesh hit_fx)", mirror.hit_fx == "flesh")

	# ── Weapon-aware stance: defensive vs sword, aggressive vs ranged ─────
	var db: Node = root.get_node("/root/ItemDB")
	player._on_weapon_equipped(db.get_item(&"starter_sword"))
	await _wait_frames(2)
	mirror._aggressive = mirror._player_ranged()
	_check("plays DEFENSIVE vs a sword", not mirror._aggressive)
	player._on_weapon_equipped(db.get_item(&"ranger_bow"))
	await _wait_frames(2)
	_check("rushes (aggressive) vs a bow", mirror._player_ranged())
	player._on_weapon_equipped(db.get_item(&"starter_staff"))
	await _wait_frames(2)
	_check("rushes (aggressive) vs a staff", mirror._player_ranged())
	# Back to the sword for the rest of the duel checks
	player._on_weapon_equipped(db.get_item(&"starter_sword"))
	await _wait_frames(2)

	# ── Blood on hit ──────────────────────────────────────────────────────
	var fx: Node = root.get_node("Fx")
	var fx0: int = fx.get_child_count()
	mirror.take_damage(10, Vector2(-100, -40))
	await _wait_frames(2)
	_check("hitting the mirror sprays blood", fx.get_child_count() > fx0)

	# ── Parry: a mirror parry negates + staggers the player ──────────────
	mirror.iframe = 0.0
	mirror.parry_win = 0.3
	mirror._face = -1 if player.global_position.x < mirror.global_position.x else 1
	# put player on the mirror's facing side so _player_in_front() is true
	player.global_position = mirror.global_position + Vector2(mirror._face * 40, 0)
	player.is_hurt = false
	var hp_m: int = mirror.hp
	mirror.take_damage(30, Vector2(-100, 0))
	await _wait_frames(2)
	_check("mirror PARRIES (no damage taken)", mirror.hp == hp_m)
	_check("parry staggers the player", player.is_hurt)
	await _wait_frames(30)

	# ── i-frames: a dodging mirror ignores a hit ─────────────────────────
	mirror.parry_win = 0.0
	mirror.iframe = 0.5
	var hp_m2: int = mirror.hp
	mirror.take_damage(20, Vector2(-100, 0))
	_check("dodging (i-frames) mirror takes no damage", mirror.hp == hp_m2)
	mirror.iframe = 0.0

	# ── It fights: attacks the player when adjacent ──────────────────────
	player.global_position = mirror.global_position + Vector2(50, 0)
	player.health = player.max_health
	player.invuln_timer = 0.0
	player.is_hurt = false
	var hp_p: int = player.health
	var hit := false
	for i in range(240):
		await physics_frame
		if not is_instance_valid(mirror):
			break
		player.global_position.x = mirror.global_position.x + 50
		player.invuln_timer = 0.0
		player.is_hurt = false
		player.is_downed = false
		if player.health < hp_p:
			hit = true
			break
	_check("mirror attacks the player like the player would", hit)

	# ── Mirror can trip the player (30% chance-based slide, costs it stamina) ─
	var tripped := false
	var mirror_sta_on_trip := -1.0
	for attempt in range(25):
		player.is_downed = false
		player.downed_timer = 0.0
		player.invuln_timer = 0.0
		player.is_rolling = false
		player.trip_immunity_timer = 0.0
		player.global_position = mirror.global_position + Vector2(40, 0)
		await _wait_frames(2)
		mirror._face = 1 if player.global_position.x > mirror.global_position.x else -1
		mirror.stamina = mirror.max_stamina
		mirror._enter_slide()
		for i in range(20):
			await physics_frame
			if player.is_downed:
				tripped = true
				mirror_sta_on_trip = mirror.stamina
				break
		if tripped:
			break
		await _wait_frames(6)
	_check("mirror slide CAN trip the player (chance-based)", tripped)
	_check("a successful mirror knockdown costs it stamina",
		mirror_sta_on_trip >= 0.0 and mirror_sta_on_trip < mirror.max_stamina - 30.0)
	await _wait_frames(10)

	# ── Killable with big EXP ─────────────────────────────────────────────
	var exp0: float = player.exp_val
	var lvl0: int = player.level
	mirror.parry_win = 0.0
	mirror.iframe = 0.0
	mirror.take_damage(99999)
	await _wait_frames(2)
	_check("mirror dies", mirror.is_dead)
	_check("mirror grants big EXP", player.exp_val > exp0 or player.level > lvl0)

	print("RESULT: %s (%d failures)" % ["OK" if _fails == 0 else "FAILED", _fails])
	quit(1 if _fails > 0 else 0)
