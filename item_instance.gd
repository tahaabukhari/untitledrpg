extends RefCounted
class_name ItemInstance
## A UNIQUE runtime item = a shared DEFINITION (template) + per-instance state.
##
## Weapons are unique per drop: two "Arcane Conduit"s are distinct objects that
## share one `def` (the catalogued WeaponData template from ItemDB) but carry
## their own durability / rolled affixes / enchant state. Inventory and equip
## slots hold ItemInstances; combat reads immutable stats straight from `.def`
## (so the player/animator code never had to change), while per-instance state
## lives here. Serialize with to_dict()/from_dict() — saves store the def `id`
## plus state, never a resource path.
##
## `def` is typed WeaponData today; it widens to ItemData when the armor/
## consumable hierarchy lands (see docs/WEAPON_ITEM_ARCHITECTURE.md §4.1, step 6).

var def: WeaponData = null       # shared template (definition) — do NOT mutate
var uid: int = 0                 # unique per-session runtime id
var durability: float = -1.0     # -1 = indestructible / system not in use yet
var max_durability: float = -1.0
var affixes: Array = []          # reserved for the modifier/rarity layer (step 7)

static var _next_uid: int = 1


## Mint a fresh unique instance of a definition. Rolls (affixes/durability) will
## initialize here once those systems exist.
static func make(definition: WeaponData) -> ItemInstance:
	var inst := ItemInstance.new()
	inst.def = definition
	inst.uid = _next_uid
	_next_uid += 1
	return inst


func display_name() -> String:
	return def.weapon_name if def else "?"


func def_id() -> StringName:
	return def.id if def else &""


# ─── Save (store id + state, never paths). Rehydrate via ItemDB.instance_from_dict ──
## Deserialization lives on ItemDB (it owns the id→definition lookup and, unlike
## a static method here, can reference the catalog without an autoload-at-compile
## dependency).

func to_dict() -> Dictionary:
	return {
		"id": String(def_id()),
		"durability": durability,
		"affixes": affixes.duplicate(),
	}


## Apply saved state (durability/affixes) onto this instance. Used by
## ItemDB.instance_from_dict after it resolves the definition.
func apply_state(d: Dictionary) -> void:
	durability = d.get("durability", -1.0)
	affixes = (d.get("affixes", []) as Array).duplicate()
