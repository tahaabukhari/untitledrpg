extends EnemyBase
## MIRROR WARRIOR — a glowing blue reflection of the player, fought with the
## player's own warrior kit: directional sword combos, a parry that staggers
## you, evasive rolls, and a slide that trips you (it's bipedal → trippable,
## and it bleeds). Reuses the actual player puppet (mirror_skin.tscn) tinted
## blue rather than a bespoke rig.

enum MState { IDLE, APPROACH, ATTACK, PARRY, DODGE, SLIDE, RECOVER }

@export_group("Duel")
@export var move_speed: float = 190.0
@export var attack_range: float = 120.0
@export var react_range: float = 260.0     ## reads player attacks within this
@export var parry_chance: float = 0.4       ## vs. dodge, when reacting
@export var slide_chance: float = 0.3       ## slide-to-trip instead of a swing

const TINT := Color(0.5, 0.78, 1.7)         ## bright blue glow

var mstate: int = MState.IDLE
var mstate_timer := 0.0
var action_cd := 0.0
var react_cd := 0.0
var iframe := 0.0
var parry_win := 0.0
var _attack_elapsed := 0.0
var _hitbox_live := false
var _face := 1
var _skin: Node2D = null
var _t := 0.0


func _enemy_ready() -> void:
	max_hp = 90
	hp = max_hp
	attack_damage = 14
	exp_value = 120.0
	aggro_range = 1100.0
	trippable = true          # bipedal — the slide-trip works both ways
	hit_fx = "flesh"          # it bleeds

	# Reuse the player puppet, tinted a glowing blue
	var skin_scene: PackedScene = load("res://enemies/mirror_skin.tscn")
	_skin = skin_scene.instantiate()
	add_child(_skin)
	_flash_sprite = _skin     # hit-flash tints the skin, not the body
	modulate = TINT           # blue glow lives on the body (survives flash/blood)

	# Wield the warrior's starter sword and idle
	var sword: WeaponData = ItemDB.get_item(&"starter_sword")
	if sword and _skin.has_method("equip_weapon_visual"):
		_skin.equip_weapon_visual(sword)
	if _skin.has_method("play_state"):
		_skin.play_state("idle")

	# Sword-swing hitbox (scaled to the 2× puppet), in front at torso height
	setup_attack_hitbox(Vector2(46, 52), Vector2(32, -30))


func _on_tripped() -> void:
	mstate = MState.IDLE
	_hitbox_live = false
	if _skin and _skin.has_method("play_knockdown"):
		_skin.play_knockdown()


func _on_staggered() -> void:
	mstate = MState.RECOVER
	mstate_timer = 0.6
	_hitbox_live = false
	if _skin and _skin.has_method("play_hurt"):
		_skin.play_hurt()


# ─── AI ───────────────────────────────────────────────────────────────────

func _enemy_physics(delta: float) -> void:
	_t += delta
	if not is_on_floor():
		velocity.y += gravity * delta

	# Blue glow pulse (only while alive — death fade owns modulate after)
	modulate = TINT * (0.88 + 0.12 * sin(_t * 4.0))

	action_cd = maxf(action_cd - delta, 0.0)
	react_cd = maxf(react_cd - delta, 0.0)
	iframe = maxf(iframe - delta, 0.0)
	mstate_timer -= delta

	_face_player()

	# Reactive defense: read a telegraphed player attack and parry or dodge
	if react_cd <= 0.0 and _player_attacking() and _dist() < react_range \
			and mstate in [MState.IDLE, MState.APPROACH]:
		react_cd = 1.1
		if randf() < parry_chance:
			_enter_parry()
		else:
			_enter_dodge()

	match mstate:
		MState.IDLE, MState.APPROACH:
			_process_approach(delta)
		MState.ATTACK:
			_process_attack(delta)
		MState.PARRY:
			velocity.x = move_toward(velocity.x, 0, 800 * delta)
			if mstate_timer <= 0.0:
				_to_recover(0.2)
		MState.DODGE:
			# hop away from the player during i-frames
			if mstate_timer <= 0.0:
				_to_recover(0.15)
		MState.SLIDE:
			_process_slide(delta)
		MState.RECOVER:
			velocity.x = move_toward(velocity.x, 0, 700 * delta)
			if mstate_timer <= 0.0:
				mstate = MState.IDLE

	move_and_slide()


func _process_approach(delta: float) -> void:
	var d := _dist()
	if d < attack_range and action_cd <= 0.0:
		# In range: slide-to-trip (esp. if they're grounded) or swing
		if randf() < slide_chance and _player_grounded():
			_enter_slide()
		else:
			_enter_attack()
		return
	if _skin and _skin.has_method("play_state"):
		_skin.play_state("run" if d > attack_range else "idle")
	if d > attack_range * 0.9:
		velocity.x = _face * move_speed
	else:
		velocity.x = move_toward(velocity.x, 0, 700 * delta)


func _enter_attack() -> void:
	mstate = MState.ATTACK
	mstate_timer = 0.6
	action_cd = 0.9
	_attack_elapsed = 0.0
	_hitbox_live = false
	velocity.x = 0.0
	if _skin and _skin.has_method("play_attack"):
		_skin.play_attack(_aim_at_player())


func _process_attack(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, 900 * delta)
	_attack_elapsed += delta
	# Active window ~0.12–0.32s into the swing (matches the sword combo timing)
	if not _hitbox_live and _attack_elapsed >= 0.12:
		_hitbox_live = true
		enable_attack_hitbox(_face)
	elif _hitbox_live and _attack_elapsed >= 0.34:
		_hitbox_live = false
		disable_attack_hitbox()
	if mstate_timer <= 0.0:
		disable_attack_hitbox()
		_to_recover(0.25)


func _enter_parry() -> void:
	mstate = MState.PARRY
	mstate_timer = 0.35
	parry_win = 0.28
	velocity.x = 0.0
	if _skin and _skin.has_method("play_parry"):
		_skin.play_parry()


func _enter_dodge() -> void:
	mstate = MState.DODGE
	mstate_timer = 0.4
	iframe = 0.4
	# Roll away from the player
	velocity.x = -_face * 360.0
	if _skin and _skin.has_method("play_roll"):
		_skin.play_roll()


func _enter_slide() -> void:
	mstate = MState.SLIDE
	mstate_timer = 0.42
	action_cd = 1.2
	iframe = 0.3
	velocity.x = _face * 520.0
	if _skin and _skin.has_method("play_slide"):
		_skin.play_slide()


func _process_slide(delta: float) -> void:
	velocity.x = move_toward(velocity.x, _face * 520.0, 200 * delta)
	# Sweep the player's legs if we pass under them
	if player and is_instance_valid(player) and player.has_method("trip"):
		var to: Vector2 = player.global_position - global_position
		if signf(to.x) == float(_face) and absf(to.x) < 52.0 and absf(to.y) < 46.0:
			player.trip(2.0)  # no-ops if the player is airborne / i-framed
	if mstate_timer <= 0.0:
		_to_recover(0.25)


func _to_recover(t: float) -> void:
	mstate = MState.RECOVER
	mstate_timer = t


# ─── Parry / i-frame resolution (override) ──────────────────────────────────

func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO) -> void:
	if is_dead:
		return
	if iframe > 0.0:
		return  # rolled/slid through it
	if parry_win > 0.0 and _player_in_front():
		# Perfect parry — negate, stagger the player, and counter
		parry_win = 0.0
		Fx.parry_spark(global_position + Vector2(_face * 12, -22))
		if player and is_instance_valid(player) and player.has_method("stagger"):
			player.stagger(0.5, Vector2(_face * 240.0, -120.0))
		_enter_attack()  # riposte
		return
	super.take_damage(amount, knockback)


func _physics_process(delta: float) -> void:
	# Tick the parry window down even though the base drives the rest
	if parry_win > 0.0:
		parry_win -= delta
	super._physics_process(delta)


# ─── Helpers ─────────────────────────────────────────────────────────────────

func _dist() -> float:
	return _distance_to_player()


func _face_player() -> void:
	if mstate in [MState.ATTACK, MState.SLIDE, MState.DODGE]:
		return
	if player and is_instance_valid(player):
		_face = 1 if player.global_position.x > global_position.x else -1
		if _skin:
			_skin.scale.x = abs(_skin.scale.x) * _face


func _aim_at_player() -> Vector2:
	if player and is_instance_valid(player):
		return (player.global_position - global_position).normalized()
	return Vector2(_face, 0)


func _player_in_front() -> bool:
	if not player or not is_instance_valid(player):
		return false
	return signf(player.global_position.x - global_position.x) == float(_face)


func _player_attacking() -> bool:
	return player and is_instance_valid(player) and player.get("is_attacking")


func _player_grounded() -> bool:
	return player and is_instance_valid(player) and not player.get("is_downed") \
		and player.has_method("is_on_floor") and player.is_on_floor()
