extends SceneTree
## Headless smoke test for the mage laser hold upgrade (mana circle, stacks,
## overdrive drain, circle break, helix beam, aim stance).
## Run: godot --headless -s res://tests/test_laser_hold.gd

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
	var global_node: Node = root.get_node("/root/Global")
	global_node.set_class("Mage")
	change_scene_to_file("res://boss_arena.tscn")
	await process_frame
	await process_frame
	await _wait_frames(30)

	var player: CharacterBody2D = get_first_node_in_group("player")
	if player == null:
		print("FAIL: no player")
		quit(1)
		return
	# Neutralize the pre-placed boss/mannequin so nothing interrupts the holds
	for e in get_nodes_in_group("enemy"):
		e.queue_free()
	await process_frame

	var input_ctrl: Node = player.get_node("PlayerInput")
	var skin: Node2D = player.get_node("PlayerSkin")
	var anim: AnimationPlayer = skin.get_node("AnimPlayer")

	# Equip the beam staff (the laser now lives on the Arcane Conduit, which
	# the mage carries in inventory rather than wielding by default)
	var beam_staff: WeaponData = load("res://weapons/mage_beam_staff.tres")
	player._on_weapon_equipped(beam_staff)
	await _wait_frames(2)
	_check("beam staff is a laser weapon", player.equipped_weapon.charged_style == "laser")

	# ── Staff resized ─────────────────────────────────────────────────────
	var weapon_sprite: Sprite2D = skin.get_node("LeftArmPivot/WeaponSprite")
	_check("staff sprite resized smaller", weapon_sprite.scale.x < 0.5)

	# ── Hold: charge_hold_time counts past full charge ────────────────────
	player.mana = player.max_mana
	_key(KEY_J, true)
	await _wait_frames(120)  # ~2s (charge_time is 1.2s)
	_check("hold time tracked past full charge", input_ctrl.charge_hold_time > 1.5)
	_check("charge level capped at 1.0", input_ctrl.charge_level == 1.0)

	# ── Battle stance while charging ──────────────────────────────────────
	_check("aim battle stance plays while charging", anim.current_animation == "staff_aim")

	# ── Mana circle appears at full charge, gains stacks ──────────────────
	var circle: Node2D = player._charge_circle
	_check("mana circle appears at full charge", circle != null and is_instance_valid(circle))
	await _wait_frames(150)  # total ~4.5s hold ≈ 3.3s at full → ≥1 stack
	circle = player._charge_circle
	var stacks_mid: int = circle.stacks if circle else -1
	_check("circle gains stacks over the hold", stacks_mid >= 1)
	_check("circle brightness grows", circle != null and circle.brightness > 0.2)

	# ── No drain before 10s ───────────────────────────────────────────────
	_check("no extra drain before 10s (mana regen keeps it full)",
		player.mana >= player.max_mana - 2)

	# ── Overdrive past 10s: drains mana, flags the circle ─────────────────
	await _wait_frames(420)  # push total hold past 10s
	_check("overdrive reached (hold > 10s)", input_ctrl.charge_hold_time > 10.0)
	circle = player._charge_circle
	_check("circle flags overdrive", circle != null and circle.overdrive)
	var mana_before: float = player.mana
	await _wait_frames(120)  # 2s of overdrive drain (8/s vs 4/s regen)
	_check("overdrive drains mana while holding", player.mana < mana_before)

	# ── Release in overdrive → helix beam fires with stack-boosted damage ──
	var mann_scene: PackedScene = load("res://enemies/mannequin.tscn")
	var mann: CharacterBody2D = mann_scene.instantiate()
	current_scene.add_child(mann)
	mann.global_position = player.global_position + Vector2(300, -5)
	mann.regen = false  # keep HP stable across the long hold waits
	await _wait_frames(10)
	var hp0: int = mann.hp
	player.facing = 1
	input_ctrl.mode = 0  # TOUCH aim → falls back to facing (headless mouse sits at origin)
	_key(KEY_J, false)
	await _wait_frames(5)
	var w: WeaponData = player.equipped_weapon
	var dealt: int = hp0 - mann.hp
	_check("overdrive release fires the beam", dealt > 0)
	_check("stacked beam beats base max damage (%d dealt)" % dealt,
		dealt > w.laser_max_damage)
	_check("attack state engaged after firing", player.is_attacking or player.attack_cooldown_timer > 0.0)
	await _wait_frames(60)

	# ── Unlimited overdrive scaling: longer hold = wider RANGE (deterministic) ──
	# A short-overdrive beam (11s) cannot reach a far dummy; a long-overdrive
	# beam (25s) can — proving range grows without a cap. Width stays frozen.
	player.is_attacking = false
	player.attack_cooldown_timer = 0.0
	player.facing = 1
	input_ctrl.mode = 0
	var far: CharacterBody2D = mann_scene.instantiate()
	current_scene.add_child(far)
	far.regen = false
	far.global_position = player.global_position + Vector2(1600, -5)  # ~1600px out
	await _wait_frames(5)
	# 11s hold → overtime 1s → range ≈ 950 + 240 = 1190 (short of 1600)
	player.mana = player.max_mana
	var far_hp0: int = far.hp
	player.fire_laser_beam(1.0, 11.0)
	await _wait_frames(5)
	_check("short-overdrive beam falls short of the far target", far.hp == far_hp0)
	player.is_attacking = false
	player.attack_cooldown_timer = 0.0
	# 25s hold → overtime 15s → range ≈ 950 + 3600 = 4550 (reaches 1600)
	player.mana = player.max_mana
	player.fire_laser_beam(1.0, 25.0)
	await _wait_frames(5)
	_check("long-overdrive beam reaches far target (range grows unbounded)", far.hp < far_hp0)
	far.queue_free()
	player.is_attacking = false
	player.attack_cooldown_timer = 0.0
	await _wait_frames(5)

	# ── Circle break: hold until mana runs dry → NO beam ──────────────────
	player.is_attacking = false
	player.attack_cooldown_timer = 0.0
	player.mana = 45  # just above one full shot; overdrive will eat it
	hp0 = mann.hp
	_key(KEY_J, true)
	# Hold well past 10s and let the drain bleed mana to zero (regen 4/s vs
	# drain 8/s → net -4/s → ~12s after overdrive starts; wait generously)
	var broke := false
	for i in range(2400):  # up to 40s sim
		await physics_frame
		if not input_ctrl.is_charging:
			broke = true
			break
	_check("circle breaks when mana runs dry mid-hold", broke and player.mana <= 0)
	_check("no beam fired on break", mann.hp == hp0)
	_check("break leaves fizzle cooldown", player.attack_cooldown_timer > 0.0)
	# Physical release after the break must NOT fire either
	_key(KEY_J, false)
	await _wait_frames(5)
	_check("releasing after break stays dead", mann.hp == hp0)

	print("RESULT: %s (%d failures)" % ["OK" if _fails == 0 else "FAILED", _fails])
	quit(1 if _fails > 0 else 0)
