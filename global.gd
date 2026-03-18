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

# getter for convenience
func get_current_class_stats() -> Dictionary:
	if class_data.has(current_class):
		return class_data[current_class]
	return class_data["Warrior"] # Fallback

func set_class(cls_name: String) -> void:
	if class_data.has(cls_name):
		current_class = cls_name
		print("Global: Assigned class ", cls_name)
	else:
		push_warning("Global: Attempted to set unknown class '%s'" % cls_name)
