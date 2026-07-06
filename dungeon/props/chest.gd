extends "res://dungeon/interactable.gd"
## One-shot chest that grants an item instance to the player's inventory.

const DungeonArt = preload("res://dungeon/dungeon_art.gd")

@export var reward_item_id: StringName = &"mage_beam_staff"

var _opened := false
var _lid: Polygon2D = null


func _ready() -> void:
	prompt_text = "CHEST"
	super._ready()
	DungeonArt.add_poly(self, PackedVector2Array([
		Vector2(-24, -12),
		Vector2(24, -12),
		Vector2(22, 10),
		Vector2(-22, 10),
	]), Color(0.42, 0.25, 0.14, 1.0), Vector2.ZERO, 1)
	_lid = DungeonArt.add_poly(self, PackedVector2Array([
		Vector2(-22, -20),
		Vector2(22, -20),
		Vector2(18, -10),
		Vector2(-18, -10),
	]), Color(0.59, 0.38, 0.18, 1.0), Vector2.ZERO, 2)
	DungeonArt.add_poly(self, PackedVector2Array([
		Vector2(-4, -15),
		Vector2(4, -15),
		Vector2(4, -8),
		Vector2(-4, -8),
	]), Color(0.74, 0.63, 0.22, 1.0), Vector2.ZERO, 3)


func interact(by: Node) -> void:
	if _opened:
		return
	_opened = true
	super.interact(by)
	if _lid:
		_lid.rotation = -0.45
		_lid.position += Vector2(-4, -4)
	var granted := false
	if by and by.has_node("HUDLayer/InventoryUI"):
		var ui := by.get_node("HUDLayer/InventoryUI")
		if ui and ui.has_method("add_item"):
			var inst := ItemDB.make_instance(reward_item_id)
			if inst:
				granted = ui.add_item(inst)
	if not granted and by != null:
		var max_health = by.get("max_health")
		var health = by.get("health")
		if max_health != null and health != null:
			by.set("health", min(max_health, health + 18))
		var max_mana = by.get("max_mana")
		var mana = by.get("mana")
		if max_mana != null and mana != null:
			by.set("mana", min(max_mana, mana + 18))
	Fx.shatter(global_position + Vector2(0, -20), Color(0.95, 0.85, 0.38, 1.0))
