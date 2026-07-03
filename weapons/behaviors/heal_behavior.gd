extends WeaponBehavior
class_name HealBehavior
## Charged support channel (healer wand): a full charge spends mana to restore
## HP; anything less is a normal attack.


func on_release(player, level: float, _hold: float) -> void:
	if level >= 1.0:
		player.channel_heal()
	else:
		player.do_normal_attack()
