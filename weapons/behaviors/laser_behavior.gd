extends WeaponBehavior
class_name LaserBehavior
## Charged hitscan beam (mage Arcane Conduit). Any meaningful hold fires a
## charge-scaled beam; a bare tap falls back to a normal poke. Holding locks
## the aim battle stance + mana-circle telegraph (driven by the player while
## wants_charge_stance() is true).


func on_release(player, level: float, hold: float) -> void:
	if level >= 0.15:
		player.fire_laser_beam(level, hold)
	else:
		player.do_normal_attack()


func wants_charge_stance() -> bool:
	return true
