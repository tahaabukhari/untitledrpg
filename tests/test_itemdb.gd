extends SceneTree
## Headless smoke test for ItemDB (migration step 1: registry + stable ids).
## Run: godot --headless -s res://tests/test_itemdb.gd

var _fails := 0


func _init() -> void:
	call_deferred("_run")


func _check(name: String, ok: bool) -> void:
	if ok:
		print("PASS: " + name)
	else:
		_fails += 1
		print("FAIL: " + name)


func _run() -> void:
	await process_frame
	var db: Node = root.get_node("/root/ItemDB")
	var global_node: Node = root.get_node("/root/Global")

	# ── Catalog populated by directory scan ───────────────────────────────
	_check("ItemDB scanned weapons", db.count() >= 6)
	for wid in ["weapon_fists", "starter_sword", "starter_staff",
			"mage_beam_staff", "ranger_bow", "healer_wand"]:
		_check("catalog has '%s'" % wid, db.has_item(wid))

	# ── Lookup returns the right resource, id backfilled ──────────────────
	var sword: WeaponData = db.get_item(&"starter_sword")
	_check("get_item resolves a WeaponData", sword != null and sword is WeaponData)
	_check("resolved weapon is the sword", sword != null and sword.weapon_type == "Sword")
	_check("id backfilled from filename", sword != null and sword.id == &"starter_sword")
	_check("String and StringName lookups agree",
		db.get_item("mage_beam_staff") == db.get_item(&"mage_beam_staff"))
	_check("unknown id returns null", db.get_item(&"no_such_item") == null)

	# ── Flyweight: same instance every lookup ─────────────────────────────
	_check("lookups return the shared instance", db.get_item(&"ranger_bow") == db.get_item(&"ranger_bow"))

	# ── Global starter resolution now goes through the catalog ────────────
	global_node.set_class("Warrior")
	var w_starter: WeaponData = global_node.get_starter_weapon()
	_check("Warrior starter resolves to the sword",
		w_starter != null and w_starter.id == &"starter_sword")
	global_node.set_class("Mage")
	_check("Mage starter resolves to the staff",
		global_node.get_starter_weapon() != null and global_node.get_starter_weapon().id == &"starter_staff")
	_check("deprecated path shim still works",
		global_node.get_starter_weapon_path().ends_with("starter_staff.tres"))

	# ── all_of_kind / all_ids sanity ──────────────────────────────────────
	_check("all_of_kind('weapon') lists them", db.all_of_kind("weapon").size() >= 6)
	_check("all_ids matches count", db.all_ids().size() == db.count())

	print("RESULT: %s (%d failures)" % ["OK" if _fails == 0 else "FAILED", _fails])
	quit(1 if _fails > 0 else 0)
