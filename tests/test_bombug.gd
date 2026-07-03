extends SceneTree
## Headless smoke test for the BOMBUG (flying kamikaze centipede).
## Run: godot --headless -s res://tests/test_bombug.gd

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


func _spawn_bug(scene: PackedScene, pos: Vector2) -> CharacterBody2D:
	var bug: CharacterBody2D = scene.instantiate()
	current_scene.add_child(bug)
	bug.global_position = pos
	return bug


func _run() -> void:
	root.get_node("/root/Global").set_class("Warrior")
	change_scene_to_file("res://boss_arena.tscn")
	await process_frame
	await process_frame
	await _wait_frames(30)

	var player: CharacterBody2D = get_first_node_in_group("player")
	if player == null:
		print("FAIL: no player")
		quit(1)
		return
	for e in get_nodes_in_group("enemy"):
		e.queue_free()
	await process_frame

	var bug_scene: PackedScene = load("res://enemies/bombug.tscn")

	# ── Framework integration + damage scaling ────────────────────────────
	var bug := _spawn_bug(bug_scene, player.global_position + Vector2(420, -160))
	await _wait_frames(5)
	_check("bombug on EnemyBase (enemy group, hurtbox layer)",
		bug.is_in_group("enemy") and bug.collision_layer == 4)
	_check("size factor varies in the expected range", bug.size_factor >= 0.72 and bug.size_factor <= 1.42)
	_check("HP scales with size (14..30)", bug.max_hp >= 14 and bug.max_hp <= 30)
	_check("explosion damage scales (10..22)",
		bug.explosion_damage >= 10 and bug.explosion_damage <= 22)
	_check("blast radius scales with size", bug.blast_radius_scaled >= 76.0 and bug.blast_radius_scaled <= 128.5)
	_check("EXP scales (8..18)", bug.exp_value >= 8.0 and bug.exp_value <= 18.0)

	var sizes: Array[float] = []
	var damages: Array[int] = []
	var radii: Array[float] = []
	for i in range(10):
		var sample := _spawn_bug(bug_scene, player.global_position + Vector2(900 + i * 20, -200))
		await _wait_frames(2)
		sizes.append(sample.size_factor)
		damages.append(sample.explosion_damage)
		radii.append(sample.blast_radius_scaled)
		sample.queue_free()
	await process_frame
	var min_size: float = sizes[0]
	var max_size: float = sizes[0]
	var min_damage: int = damages[0]
	var max_damage: int = damages[0]
	var min_radius: float = radii[0]
	var max_radius: float = radii[0]
	for s in sizes:
		min_size = minf(min_size, s)
		max_size = maxf(max_size, s)
	for d in damages:
		min_damage = mini(min_damage, d)
		max_damage = maxi(max_damage, d)
	for r in radii:
		min_radius = minf(min_radius, r)
		max_radius = maxf(max_radius, r)
	_check("multiple bombugs roll visibly different sizes", max_size - min_size > 0.18)
	_check("bigger bombugs can roll bigger damage", max_damage > min_damage)
	_check("bigger bombugs can roll bigger blast radii", max_radius > min_radius)

	# ── It FLIES: no gravity plummet, closes distance to the player ───────
	var y0: float = bug.global_position.y
	var d0: float = bug.global_position.distance_to(player.global_position)
	await _wait_frames(60)
	_check("stays airborne (no gravity fall)", bug.global_position.y < y0 + 60.0)
	_check("flies toward the player", bug.global_position.distance_to(player.global_position) < d0 - 60.0)

	# ── Arms in range: rolls up, sits still (easy target), 1s fuse ────────
	var armed := false
	for i in range(300):
		await physics_frame
		if bug.state == 2:  # ARM
			armed = true
			break
	_check("rolls up (ARM) when it reaches the player", armed)
	var fuse_frames := 0
	if armed:
		await _wait_frames(10)
		_check("armed bug sits still — the free-hit window", bug.velocity.length() < 30.0)
		var exp_before: float = player.exp_val
		player.invuln_timer = 0.0
		player.is_hurt = false
		player.health = player.max_health
		var hp_before: int = player.health
		while is_instance_valid(bug) and not bug.is_dead and fuse_frames < 200:
			await physics_frame
			fuse_frames += 1
		fuse_frames += 10  # the pre-measure settle above
		_check("fuse is ~1s between charging and boom (%d frames)" % fuse_frames,
			fuse_frames >= 45 and fuse_frames <= 90)
		await _wait_frames(3)
		_check("explosion damages the nearby player", player.health < hp_before)
		_check("self-destruction grants NO exp", player.exp_val == exp_before)

	# ── Defusal: kill it during the fuse → full EXP, no blast ─────────────
	await _wait_frames(30)
	var bug2 := _spawn_bug(bug_scene, player.global_position + Vector2(200, -80))
	await _wait_frames(5)
	var armed2 := false
	for i in range(300):
		await physics_frame
		if not is_instance_valid(bug2):
			break
		if bug2.state == 2:
			armed2 = true
			break
	_check("second bug arms", armed2)
	if armed2:
		var exp2: float = player.exp_val
		var lvl2: int = player.level
		player.health = player.max_health
		var hp2: int = player.health
		bug2.take_damage(999)  # free hit during the window = defused
		await _wait_frames(90)
		_check("killing it mid-fuse DEFUSES it (no blast damage)", player.health == hp2)
		_check("defusal grants the scaled EXP", player.exp_val > exp2 or player.level > lvl2)

	# ── Counterplay: dodge i-frames beat the blast ────────────────────────
	var bug3 := _spawn_bug(bug_scene, player.global_position + Vector2(160, -60))
	await _wait_frames(5)
	var armed3 := false
	for i in range(300):
		await physics_frame
		if not is_instance_valid(bug3):
			break
		if bug3.state == 2:
			armed3 = true
			break
	if armed3:
		player.health = player.max_health
		var hp3: int = player.health
		while is_instance_valid(bug3) and not bug3.is_dead:
			player.invuln_timer = 1.0  # rolling through the boom
			await physics_frame
		await _wait_frames(3)
		_check("dodge i-frames beat the explosion", player.health == hp3)
	else:
		_check("dodge i-frames beat the explosion", false)

	print("RESULT: %s (%d failures)" % ["OK" if _fails == 0 else "FAILED", _fails])
	quit(1 if _fails > 0 else 0)
