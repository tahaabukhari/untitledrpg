extends Node
## ItemDB — central catalog of every item, keyed by a stable StringName `id`.
##
## Scans the item directories at boot and maps id → resource so ALL discovery
## (class starter weapons, inventory seeding, drops, and eventually save/load)
## goes through here instead of hardcoded `res://…` paths. Saving inventory
## stores ids, never resource paths (paths break on rename/move).
##
## Today it holds WeaponData; the ItemData hierarchy (armor/consumable/trinket)
## will register the same way — see docs/WEAPON_ITEM_ARCHITECTURE.md.

# Directories scanned for `.tres` item resources (top level, non-recursive so we
# don't pick up animator/behavior scripts living in subfolders).
const SCAN_DIRS: Array[String] = [
	"res://weapons",
]

var _items: Dictionary = {}     # StringName → Resource (WeaponData for now)
var _by_kind: Dictionary = {}   # String → Array[Resource]


func _ready() -> void:
	rescan()


## (Re)build the catalog from disk. Safe to call again in the editor.
func rescan() -> void:
	_items.clear()
	_by_kind.clear()
	for dir_path in SCAN_DIRS:
		_scan_dir(dir_path)


func _scan_dir(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir():
			# Exported builds may present resources as "<file>.tres.remap"
			var clean := fname.trim_suffix(".remap")
			if clean.ends_with(".tres"):
				var res: Resource = load(dir_path.path_join(clean))
				if res is WeaponData:
					_register(res, clean)
		fname = dir.get_next()
	dir.list_dir_end()


func _register(item: WeaponData, filename: String) -> void:
	var item_id: StringName = item.id
	if item_id == &"":
		# Derive a stable id from the filename when the resource omits one
		item_id = StringName(filename.trim_suffix(".tres"))
		item.id = item_id
	if _items.has(item_id):
		push_warning("ItemDB: duplicate item id '%s' (%s)" % [item_id, filename])
	_items[item_id] = item

	var kind := "weapon"  # ItemData.item_kind arrives with the hierarchy (step 6)
	if not _by_kind.has(kind):
		_by_kind[kind] = []
	_by_kind[kind].append(item)


# ─── Lookup API ──────────────────────────────────────────────────────────────

func get_item(item_id) -> WeaponData:
	## Returns the catalogued resource for `id`, or null. Accepts String or
	## StringName. This is the shared (flyweight) instance — do not mutate it;
	## per-item state (affixes/durability) will be layered later.
	return _items.get(StringName(item_id), null)


func has_item(item_id) -> bool:
	return _items.has(StringName(item_id))


func all_of_kind(kind: String) -> Array:
	return _by_kind.get(kind, [])


func all_ids() -> Array:
	return _items.keys()


func count() -> int:
	return _items.size()
