extends SceneTree
## Headless smoke test for migration step 2/3: weapon behavior plugins.
## Verifies charged-attack dispatch is polymorphic (no charged_style branch in
## the player) and that behavior_script overrides the legacy style selector.
## Run: godot --headless -s res://tests/test_behavior.gd

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
	var db: Node = root.get_node("/root/ItemDB")

	# ── get_behavior resolves the right plugin per weapon ─────────────────
	_check("beam staff → LaserBehavior", db.get_item(&"mage_beam_staff").get_behavior() is LaserBehavior)
	_check("wand → HealBehavior", db.get_item(&"healer_wand").get_behavior() is HealBehavior)
	_check("sword → plain WeaponBehavior (melee)", _is_plain(db.get_item(&"starter_sword").get_behavior()))
	_check("basic staff → plain melee behavior", _is_plain(db.get_item(&"starter_staff").get_behavior()))

	# ── behavior_script overrides the legacy charged_style ────────────────
	var w := WeaponData.new()
	w.charged_style = "melee"  # legacy says melee...
	w.behavior_script = preload("res://weapons/behaviors/laser_behavior.gd")  # ...plugin says laser
	_check("explicit behavior_script wins over charged_style", w.get_behavior() is LaserBehavior)
	_check("laser behavior wants the charge stance", LaserBehavior.new().wants_charge_stance())
	_check("melee behavior has no charge stance", not WeaponBehavior.new().wants_charge_stance())

	# ── Live dispatch through the player, no style branch ─────────────────
	root.get_node("/root/Global").set_class("Warrior")
	change_scene_to_file("res://boss_arena.tscn")
	await process_frame
	await process_frame
	await _wait_frames(30)
	var player: CharacterBody2D = get_first_node_in_group("player")
	for e in get_nodes_in_group("enemy"):
		e.queue_free()
	await process_frame

	# Melee weapon: full-charge release does a charged swing
	player._on_weapon_equipped(db.get_item(&"starter_sword"))
	await _wait_frames(2)
	player.stamina = player.max_stamina
	player._on_attack_released(1.0, 1.2)
	await _wait_frames(2)
	_check("melee behavior: full charge → charged swing", player.is_attacking)
	await _wait_frames(40)

	# Laser weapon: the equipped behavior drives the stance gate
	player._on_weapon_equipped(db.get_item(&"mage_beam_staff"))
	await _wait_frames(2)
	_check("player behavior swaps to laser on equip", player._behavior is LaserBehavior)

	# Heal weapon: full-charge release restores HP (behavior → channel_heal)
	player._on_weapon_equipped(db.get_item(&"healer_wand"))
	await _wait_frames(2)
	player.is_attacking = false
	player.health = 30
	player.mana = player.max_mana
	player._on_attack_released(1.0, 1.0)
	await _wait_frames(2)
	_check("heal behavior: full charge → HP restored", player.health > 30)

	print("RESULT: %s (%d failures)" % ["OK" if _fails == 0 else "FAILED", _fails])
	quit(1 if _fails > 0 else 0)


func _is_plain(b) -> bool:
	# A plain melee behavior is a WeaponBehavior that is NOT one of the subclasses
	return b is WeaponBehavior and not (b is LaserBehavior) and not (b is HealBehavior)
