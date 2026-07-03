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

	# ── Unique instances: distinct objects sharing one definition ─────────
	var a: ItemInstance = db.make_instance(&"starter_sword")
	var b: ItemInstance = db.make_instance(&"starter_sword")
	_check("make_instance returns an ItemInstance", a != null and a is ItemInstance)
	_check("two instances are DISTINCT objects", a != b)
	_check("instances have unique uids", a.uid != b.uid)
	_check("instances SHARE the definition (flyweight def)", a.def == b.def and a.def == db.get_item(&"starter_sword"))
	_check("instance exposes def stats", a.def.weapon_type == "Sword")
	_check("make_instance of unknown id → null", db.make_instance(&"nope") == null)

	# ── Per-instance state is independent ─────────────────────────────────
	a.durability = 50.0
	_check("mutating one instance doesn't touch the other", b.durability != 50.0)

	# ── Save round-trip via id + state ────────────────────────────────────
	a.affixes = ["sharp"]
	var dict := a.to_dict()
	_check("to_dict stores the def id", dict.get("id") == "starter_sword")
	var restored: ItemInstance = db.instance_from_dict(dict)
	_check("instance_from_dict rebuilds the same def", restored != null and restored.def == a.def)
	_check("instance_from_dict restores state", restored.durability == 50.0 and restored.affixes == ["sharp"])
	_check("instance_from_dict of unknown id → null", db.instance_from_dict({"id": "nope"}) == null)

	print("RESULT: %s (%d failures)" % ["OK" if _fails == 0 else "FAILED", _fails])
	quit(1 if _fails > 0 else 0)
