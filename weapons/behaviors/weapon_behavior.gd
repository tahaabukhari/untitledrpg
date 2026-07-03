extends RefCounted
class_name WeaponBehavior
## How a weapon's CHARGED action executes, and whether it has a charge stance.
##
## The player forwards charge events here instead of switching on a hardcoded
## style enum — so adding a new attack KIND is a new subclass, never an edit to
## playercontroller. Behaviors compose PUBLIC player verbs
## (do_normal_attack / do_charged_melee / fire_laser_beam / channel_heal) rather
## than reaching into player internals. See docs/WEAPON_ITEM_ARCHITECTURE.md §4.2.
##
## Base behaviour = plain melee: a full charge does the weapon's charged swing,
## anything less is a normal attack.

## Handle attack-button release at charge `level` (0..1) held `hold` seconds.
func on_release(player, level: float, _hold: float) -> void:
	if level >= 1.0:
		player.do_charged_melee()
	else:
		player.do_normal_attack()


## True if HOLDING the attack should lock the aim/charge stance + telegraph.
func wants_charge_stance() -> bool:
	return false
