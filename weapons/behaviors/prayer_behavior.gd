extends WeaponBehavior
class_name PrayerBehavior
## Healer's empty-handed prayer: every release (tap OR hold) rubs the hands
## together in prayer. Each prayer has a 1-in-7 chance to be answered with a
## lightning bolt on the closest nearby enemy (rolled at the animation's
## climax via the prayer_rub method track).


func on_release(player, _level: float, _hold: float) -> void:
	player.perform_prayer()
