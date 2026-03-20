extends Resource
class_name WeaponData
## Base resource for all weapons. Each weapon defines its own stats,
## animation set, and special attack properties.

@export_group("Identity")
@export var weapon_name: String = "Fists"
@export var weapon_icon: Texture2D  # optional icon for UI

@export_group("Normal Attack")
@export var atk_min: int = 2
@export var atk_max: int = 4
@export var attack_cooldown: float = 0.0
@export var stamina_cost: float = 0.0  # per normal hit

@export_group("Charged Attack")
@export var charged_damage: int = 10
@export var charged_knockback: float = 300.0
@export var charged_stamina_cost: float = 15.0
@export var charge_time: float = 1.0  # seconds to fully charge

@export_group("Animations")
## Names of animations this weapon registers in the AnimationPlayer.
## The animator will look for these when building the library.
@export var attack_right_anim: String = "attack_right"
@export var attack_left_anim: String = "attack_left"
@export var charged_anim: String = "uppercut"


## Calculate a random normal attack damage, factoring in the player's ATK stat bonus.
func calc_damage(stat_atk: int) -> int:
	return randi_range(atk_min + stat_atk, atk_max + stat_atk)
