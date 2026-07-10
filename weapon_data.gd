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
## Optional explicit behavior plugin (a WeaponBehavior subclass). When set it
## wins over charged_style — this is how new attack kinds are added without
## touching the player. Leave null to derive the behavior from charged_style.
@export var behavior_script: GDScript
## Legacy selector kept as a fallback when behavior_script is null:
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

@export_group("Sword Hold & Visual")
## Read by SwordAnimator (one-handed short sword). Rig-local units, before the
## PlayerSkin 2× scale. Tweak these in the Inspector to place/shape the blade.
## The sword is held by the hilt in the FORWARD hand (LeftArmPivot).
@export var sword_blade_scale: float = 0.42        ## sprite scale of the blade
@export var sword_hilt_to_hand: float = 4.0        ## px the grip pokes past the sprite bottom (hilt pivot)
@export var sword_weapon_pos := Vector2(-5, 3)     ## blade sprite position relative to the forward hand
@export var sword_blade_rest_deg: float = -45.0    ## blade angle at rest — up & forward (degrees)
@export var sword_hand_grip := Vector2(7, -3)      ## forward-hand grip position at rest
@export var sword_hand_grip_rot: float = -0.15     ## forward-hand tilt at rest (radians)
@export var sword_back_hand := Vector2(-6, -4.5)   ## free back-hand rest position
@export var sword_move_swing_mul: float = 0.35     ## damp the sword arm's swing while moving (0..1)
@export var sword_charge_blade_deg: float = 60.0   ## blade leveled forward during the charged thrust (deg)
@export var sword_charge_offhand := Vector2(9, -1) ## back-hand grip offset during the two-handed thrust
@export var sword_parry_blade_deg: float = -88.0   ## blade angle in the parry guard (deg)


var _runtime_icon: Texture2D = null


## UI icon: the exported texture, or one synthesized by the animator
## (code-generated weapons like the wand/bow implement static make_icon()).
func get_icon() -> Texture2D:
	if weapon_icon:
		return weapon_icon
	if _runtime_icon == null and animator_script:
		var anim = animator_script.new()
		if anim and anim.has_method("make_icon"):
			_runtime_icon = anim.make_icon()
	return _runtime_icon


const _MELEE_BEHAVIOR := preload("res://weapons/behaviors/weapon_behavior.gd")
const _LASER_BEHAVIOR := preload("res://weapons/behaviors/laser_behavior.gd")
const _HEAL_BEHAVIOR := preload("res://weapons/behaviors/heal_behavior.gd")


## Instantiate this weapon's charged-attack behavior plugin. Explicit
## behavior_script wins; otherwise derive from the legacy charged_style.
func get_behavior() -> WeaponBehavior:
	if behavior_script:
		return behavior_script.new()
	match charged_style:
		"laser":
			return _LASER_BEHAVIOR.new()
		"heal":
			return _HEAL_BEHAVIOR.new()
		_:
			return _MELEE_BEHAVIOR.new()


## Calculate a random normal attack damage, factoring in the player's ATK stat bonus.
func calc_damage(stat_atk: int) -> int:
	return randi_range(atk_min + stat_atk, atk_max + stat_atk)
