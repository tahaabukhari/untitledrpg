extends SceneTree
## Headless smoke test for the healer prayer rework.
## Run: godot --headless -s res://tests/test_prayer.gd

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
	var global_node: Node = root.get_node("/root/Global")
	var db: Node = root.get_node("/root/ItemDB")
	global_node.set_class("Healer")
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

	# ── Loadout: empty-handed prayer default, wand in inventory ──────────
	_check("healer starter is the Prayer (empty hands)",
		player.equipped_weapon.id == &"healer_prayer")
	_check("prayer uses PrayerBehavior plugin", player._behavior is PrayerBehavior)
	var skin: Node2D = player.get_node("PlayerSkin")
	var weapon_sprite: Sprite2D = skin.get_node("LeftArmPivot/WeaponSprite")
	_check("no weapon sprite shown (bare hands)", not weapon_sprite.visible)
	var inv: Control = player.get_node("HUDLayer/InventoryUI")
	await _wait_frames(3)  # _add_starting_items is deferred
	var wand_in_inventory := false
	for slot in inv.inventory_slots:
		if slot.item != null and slot.item.def_id() == &"healer_wand":
			wand_in_inventory = true
	_check("healing wand rides in the inventory", wand_in_inventory)
	_check("wand has a synthesized inventory icon",
		db.get_item(&"healer_wand").get_icon() != null)

	# ── Prayer plays the hand-rub animation ───────────────────────────────
	var anim: AnimationPlayer = skin.get_node("AnimPlayer")
	player._on_attack_released(0.0, 0.05)  # tap → behavior → perform_prayer
	await _wait_frames(3)
	_check("prayer release plays the hand-rub", anim.current_animation == "prayer_rub")
	await _wait_frames(50)
	_check("prayer finishes cleanly", not player.is_attacking)

	# ── Deterministic lightning: strike the nearest enemy directly ────────
	var mann_scene: PackedScene = load("res://enemies/mannequin.tscn")
	var near: CharacterBody2D = mann_scene.instantiate()
	current_scene.add_child(near)
	near.regen = false
	near.global_position = player.global_position + Vector2(160, -5)
	var splash: CharacterBody2D = mann_scene.instantiate()
	current_scene.add_child(splash)
	splash.regen = false
	splash.global_position = near.global_position + Vector2(60, 0)   # inside AoE
	var far: CharacterBody2D = mann_scene.instantiate()
	current_scene.add_child(far)
	far.regen = false
	far.global_position = near.global_position + Vector2(400, 0)     # outside AoE
	await _wait_frames(20)

	_check("closest-enemy pick finds the near dummy", player._closest_enemy(520.0) == near)
	var hp_near: int = near.hp
	var hp_splash: int = splash.hp
	var hp_far: int = far.hp
	player._summon_prayer_lightning(near)
	await _wait_frames(3)
	var direct: int = hp_near - near.hp
	var aoe: int = hp_splash - splash.hp
	_check("bolt deals full damage to the target (%d)" % direct,
		direct >= player.equipped_weapon.charged_damage)
	_check("explosion splashes LIGHT AoE damage (%d)" % aoe, aoe > 0 and aoe < direct)
	_check("outside the blast takes nothing", far.hp == hp_far)
	var fx: Node = root.get_node("Fx")
	_check("strike VFX spawned (bolt/explosion/embers)", fx.get_child_count() > 10)
	await _wait_frames(80)

	# ── The 1/7 odds actually connect through real prayers ────────────────
	# 120 prayers: P(zero strikes) = (6/7)^120 ≈ 1e-8; also sanity that it's
	# not firing every time.
	near.hp = near.max_hp
	splash.global_position.y += 4000  # move spares away so only `near` eats bolts
	far.global_position.y += 4000
	var strikes := 0
	for i in range(120):
		var before: int = near.hp
		player.is_attacking = false
		player.attack_cooldown_timer = 0.0
		player.on_prayer_completed()
		await _wait_frames(1)
		if near.hp < before:
			strikes += 1
			near.hp = near.max_hp
	_check("some prayers are answered (%d/120)" % strikes, strikes > 0)
	_check("but not every prayer (odds feel like 1/7)", strikes < 60)

	print("RESULT: %s (%d failures)" % ["OK" if _fails == 0 else "FAILED", _fails])
	quit(1 if _fails > 0 else 0)
