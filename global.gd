extends Node

# scalable dictionary to hold all class definitions
# format: "class_name": { "hp": int, "def": int, "sta": int, "mana": int, "description": String }
var class_data: Dictionary = {
	"Warrior": {
		"hp": 10,
		"def": 7,
		"sta": 14,
		"mana": 7,
		"description": "A seasoned fighter relying on high stamina and balanced defenses to stay in the thick of melee combat."
	},
	"Ranger": {
		"hp": 8,
		"def": 13,
		"sta": 10,
		"mana": 7,
		"description": "A nimble marksman with excellent evasion and defense, striking from afar before dashing away."
	},
	"Mage": {
		"hp": 10,
		"def": 5,
		"sta": 5,
		"mana": 18,
		"description": "A master of the arcane arts, featuring low physical stamina but an enormous pool of mana for casting spells."
	},
	"Healer": {
		"hp": 14,
		"def": 5,
		"sta": 5,
		"mana": 14,
		"description": "A vital support role with high health to survive encounters and deep mana reserves to keep allies alive."
	}
}

# currently selected class string
var current_class: String = "Warrior" # Default

# ─── Character customization (early tool — expand later) ────────────────────
# Applied to the puppet's layered sprites as modulate tints on spawn.
var player_custom: Dictionary = {
	"name": "Adventurer",
	"hair_color": Color(1, 1, 1),    # white = untinted (sprite's own color)
	"skin_tone": Color(1, 1, 1),
	"outfit_color": Color(1, 1, 1),
}

const HAIR_COLORS: Array[Color] = [
	Color(1, 1, 1),               # natural (untinted)
	Color(0.25, 0.18, 0.12),      # dark brown
	Color(0.85, 0.65, 0.25),      # blonde
	Color(0.55, 0.12, 0.1),       # auburn
	Color(0.15, 0.15, 0.18),      # black
	Color(0.75, 0.75, 0.8),       # silver
	Color(0.3, 0.5, 0.85),        # arcane blue
	Color(0.5, 0.8, 0.45),        # forest green
]

const SKIN_TONES: Array[Color] = [
	Color(1, 1, 1),               # natural (untinted)
	Color(1.0, 0.9, 0.8),         # fair
	Color(0.95, 0.8, 0.62),       # tan
	Color(0.8, 0.6, 0.42),        # bronze
	Color(0.6, 0.42, 0.3),        # deep
	Color(0.45, 0.3, 0.22),       # rich
]

const OUTFIT_COLORS: Array[Color] = [
	Color(1, 1, 1),               # natural (untinted)
	Color(0.75, 0.3, 0.3),        # crimson
	Color(0.35, 0.5, 0.8),        # royal blue
	Color(0.4, 0.65, 0.4),        # ranger green
	Color(0.65, 0.55, 0.3),       # gilded
	Color(0.55, 0.4, 0.65),       # violet
	Color(0.35, 0.35, 0.4),       # slate
	Color(0.85, 0.75, 0.6),       # linen
]

# starter weapon auto-equipped on spawn per class
var class_starter_weapon: Dictionary = {
	"Warrior": "res://weapons/starter_sword.tres",
	"Ranger": "res://weapons/ranger_bow.tres",
	"Mage": "res://weapons/starter_staff.tres",
	"Healer": "res://weapons/healer_wand.tres",
}


func get_starter_weapon_path() -> String:
	return class_starter_weapon.get(current_class, "")

# getter for convenience
func get_current_class_stats() -> Dictionary:
	if class_data.has(current_class):
		return class_data[current_class]
	return class_data["Warrior"] # Fallback

func set_class(cls_name: String) -> void:
	if class_data.has(cls_name):
		current_class = cls_name
	else:
		push_warning("Global: Attempted to set unknown class '%s'" % cls_name)


## Single respawn path — used by both the pause menu RETRY and the death screen.
func respawn() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
