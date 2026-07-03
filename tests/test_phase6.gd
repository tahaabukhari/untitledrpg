extends SceneTree
## Headless smoke test for Phase 6 (class weapons + mage laser).
## Run: godot --headless -s res://tests/test_phase6.gd

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
	# (autoloads can't be referenced by identifier in -s scripts — fetch at runtime)
	var global_node: Node = root.get_node("/root/Global")
	# Boot as MAGE for the laser showcase
	global_node.set_class("Mage")
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

	# ── Auto-equip + beam staff from inventory ────────────────────────────
	_check("mage auto-equips starter staff", player.equipped_weapon.weapon_name == "Starter Staff")
	# The laser now lives on the Arcane Conduit (carried in inventory); equip it
	var conduit: WeaponData = load("res://weapons/mage_beam_staff.tres")
	player._on_weapon_equipped(conduit)
	await _wait_frames(2)
	_check("beam staff charged style is laser", player.equipped_weapon.charged_style == "laser")

	# Spawn a mannequin down-range
	var mann_scene: PackedScene = load("res://enemies/mannequin.tscn")
	var mann: CharacterBody2D = mann_scene.instantiate()
	current_scene.add_child(mann)
	mann.global_position = player.global_position + Vector2(450, -5)
	var mann_far: CharacterBody2D = mann_scene.instantiate()
	current_scene.add_child(mann_far)
	mann_far.global_position = player.global_position + Vector2(700, -5)
	await _wait_frames(20)

	# ── Weak short beam (low charge) ──────────────────────────────────────
	player.facing = 1
	player.mana = player.max_mana
	var mana0: float = player.mana
	var hp_near0: int = mann.hp
	var hp_far0: int = mann_far.hp
	player.fire_laser_beam(0.2)
	await _wait_frames(5)
	_check("low-charge laser costs mana", player.mana < mana0)
	_check("low-charge beam hits nothing beyond its short range",
		mann.hp == hp_near0 and mann_far.hp == hp_far0)
	await _wait_frames(40)

	# ── Full-charge beam: long + PIERCING (both dummies) ──────────────────
	player.is_attacking = false
	player.attack_cooldown_timer = 0.0
	var mana1: float = player.mana
	hp_near0 = mann.hp
	hp_far0 = mann_far.hp
	player.fire_laser_beam(1.0)
	await _wait_frames(5)
	var near_dmg: int = hp_near0 - mann.hp
	var far_dmg: int = hp_far0 - mann_far.hp
	_check("full-charge beam damages the near dummy", near_dmg > 0)
	_check("full-charge beam PIERCES to the far dummy", far_dmg > 0)
	_check("full charge drains more mana", (mana1 - player.mana) > (mana0 - mana1) - 0.001)
	_check("full-charge damage in expected band", near_dmg >= player.equipped_weapon.laser_max_damage - 5)
	await _wait_frames(40)

	# ── 8-dir: beam straight up hits an overhead dummy ────────────────────
	player.is_attacking = false
	player.attack_cooldown_timer = 0.0
	var mann_up: CharacterBody2D = mann_scene.instantiate()
	current_scene.add_child(mann_up)
	mann_up.global_position = player.global_position + Vector2(0, -250)
	mann_up.gravity = 0.0
	await _wait_frames(3)
	var hp_up0: int = mann_up.hp
	# Aim up via the touch joystick path: feed the input layer directly
	player.get_node("PlayerInput")._joystick_vector = Vector2(0, -1)
	player.get_node("PlayerInput").mode = 0  # TOUCH → joystick aim
	var joystick: Control = player.get_node("TouchControls/JOYSTICK")
	joystick.last_vector = Vector2(0, -1)
	player.fire_laser_beam(1.0)
	await _wait_frames(5)
	_check("upward beam hits the overhead dummy", mann_up.hp < hp_up0)
	joystick.last_vector = Vector2.ZERO
	await _wait_frames(30)

	# ── No mana → no beam ─────────────────────────────────────────────────
	player.is_attacking = false
	player.attack_cooldown_timer = 0.0
	player.mana = 0
	hp_near0 = mann.hp
	player.fire_laser_beam(1.0)
	await _wait_frames(3)
	_check("insufficient mana blocks the beam", mann.hp == hp_near0)

	# ── Ranger: bow fires a projectile that damages an enemy ──────────────
	global_node.set_class("Ranger")
	var w_bow: WeaponData = load("res://weapons/ranger_bow.tres")
	player._on_weapon_equipped(w_bow)
	_check("bow equips with ranged style", player.equipped_weapon.attack_style == "ranged")
	player._attack_aim = Vector2.RIGHT
	var hp2: int = mann.hp
	player.fire_projectile(false)
	await _wait_frames(60)
	_check("arrow damages the dummy down-range", mann.hp < hp2)

	# ── Healer: charged heal restores HP for mana ─────────────────────────
	var w_wand: WeaponData = load("res://weapons/healer_wand.tres")
	player._on_weapon_equipped(w_wand)
	player.is_attacking = false
	player.health = 40
	player.mana = player.max_mana
	var mana2: float = player.mana
	player.channel_heal()
	_check("heal restores HP", player.health == 40 + w_wand.heal_amount)
	_check("heal costs mana", player.mana < mana2)

	# ── Warrior default unchanged ─────────────────────────────────────────
	global_node.set_class("Warrior")
	_check("warrior starter is the sword", global_node.get_starter_weapon_path().ends_with("starter_sword.tres"))

	print("RESULT: %s (%d failures)" % ["OK" if _fails == 0 else "FAILED", _fails])
	quit(1 if _fails > 0 else 0)
