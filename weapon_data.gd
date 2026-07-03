extends Resource
class_name WeaponData
## Base resource for all weapons. Each weapon defines its own stats,
## animation set, and special attack properties.

@export_group("Identity")
## Stable catalog id used by ItemDB / save-load. Leave empty to derive it from
## the .tres filename (e.g. starter_sword.tres → &"starter_sword").
@export var id: StringName = &""
@export var weapon_name: String = "Fists"
@export var weapon_type: String = "Fists" # e.g. "Sword", "Staff", "Fists"
@export var weapon_description: String = "Your bare fists."
@export var weapon_icon: Texture2D  # optional icon for UI
@export var animator_script: GDScript  # e.g. preload("res://weapons/animators/sword_animator.gd")

@export_group("Normal Attack")
## "melee" = animation hitbox swings; "ranged" = fires a projectile toward aim.
@export_enum("melee", "ranged") var attack_style: String = "melee"
@export var atk_min: int = 2
@export var atk_max: int = 4
@export var attack_cooldown: float = 0.0
@export var stamina_cost: float = 0.0  # per normal hit
@export var projectile_speed: float = 700.0  # ranged only

@export_group("Charged Attack")
## "melee" = charged swing anim; "laser" = charge-scaled hitscan beam;
## "heal" = channel that restores HP for mana.
@export_enum("melee", "laser", "heal") var charged_style: String = "melee"
@export var charged_damage: int = 10
@export var charged_knockback: float = 300.0
@export var charged_stamina_cost: float = 15.0
@export var charge_time: float = 1.0  # seconds to fully charge

@export_group("Laser (charged_style = laser)")
@export var laser_min_damage: int = 8
@export var laser_max_damage: int = 42
@export var laser_min_range: float = 220.0
@export var laser_max_range: float = 950.0
@export var laser_min_width: float = 3.0
@export var laser_max_width: float = 11.0
@export var laser_mana_cost: float = 30.0  # at full charge (scales down with charge)

@export_group("Heal (charged_style = heal)")
@export var heal_amount: int = 30
@export var heal_mana_cost: float = 25.0

@export_group("Animations")
## Names of animations this weapon registers in the AnimationPlayer.
## The animator will look for these when building the library.
@export var attack_right_anim: String = "attack_right"
@export var attack_left_anim: String = "attack_left"
@export var charged_anim: String = "uppercut"
## Combo sequence — if non-empty, overrides attack_right/left with an ordered combo chain.
@export var combo_anims: Array[String] = []


## Calculate a random normal attack damage, factoring in the player's ATK stat bonus.
func calc_damage(stat_atk: int) -> int:
	return randi_range(atk_min + stat_atk, atk_max + stat_atk)
