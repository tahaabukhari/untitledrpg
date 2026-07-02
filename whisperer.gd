extends EnemyBase
## Whisperer — a fast, thin creature that patrols until it spots the player,
## rushes them, and swipes. Fully combat-capable: HP, damage, EXP, death.

enum State { PATROL, AGGRO, WINDUP, ATTACK, RECOVER }

@export_group("Movement")
@export var speed: float = 120.0
@export var rush_speed: float = 350.0
@export var patrol_distance: float = 400.0    ## left/right patrol range (pixels)

@export_group("Aggro")
@export var aggro_time: float = 10.0
@export var attack_distance: float = 48.0

@export_group("Attack")
@export var windup_time: float = 0.4          ## Telegraph before the swipe
@export var swipe_time: float = 0.25          ## Active hitbox window
@export var recover_time: float = 0.6

@onready var sprite: Sprite2D = $Sprite2D

var home_position: Vector2
var direction: int = 1                        # 1 = right, -1 = left
var state: State = State.PATROL
var aggro_timer: float = 0.0
var attack_timer: float = 0.0


func _enemy_ready() -> void:
	home_position = global_position
	max_hp = 40
	hp = max_hp
	attack_damage = 12
	exp_value = 15.0
	aggro_range = 30.0 * 64.0  # ~30 meters at 1m=64px

	# Swipe hitbox in front of the body
	setup_attack_hitbox(Vector2(30, 40), Vector2(18, 0))


func _enemy_physics(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta

	match state:
		State.PATROL:
			_patrol(delta)
			if _can_see_player():
				state = State.AGGRO
				aggro_timer = aggro_time
		State.AGGRO:
			aggro_timer -= delta
			if _can_see_player():
				aggro_timer = aggro_time
			_rush_player(delta)
			if aggro_timer <= 0.0:
				state = State.PATROL
			elif _distance_to_player() < attack_distance and is_on_floor():
				state = State.WINDUP
				attack_timer = windup_time
				velocity.x = 0.0
				flash_hit(Color(1.4, 1.2, 0.5))  # telegraph
		State.WINDUP:
			velocity.x = 0.0
			attack_timer -= delta
			_face_player()
			if attack_timer <= 0.0:
				_begin_swipe()
		State.ATTACK:
			velocity.x = move_toward(velocity.x, 0, rush_speed * delta * 2.0)
			attack_timer -= delta
			if attack_timer <= 0.0:
				disable_attack_hitbox()
				state = State.RECOVER
				attack_timer = recover_time
		State.RECOVER:
			velocity.x = 0.0
			attack_timer -= delta
			if attack_timer <= 0.0:
				state = State.AGGRO
				aggro_timer = aggro_time

	move_and_slide()


func _on_staggered() -> void:
	# A parried swipe interrupts the attack entirely
	if state == State.WINDUP or state == State.ATTACK:
		state = State.RECOVER
		attack_timer = recover_time * 1.5


func _begin_swipe() -> void:
	state = State.ATTACK
	attack_timer = swipe_time
	_face_player()
	# Small forward step into the swipe
	velocity.x = direction * rush_speed * 0.5
	enable_attack_hitbox(direction)
	# Directional slash VFX toward the player
	var to_player := Vector2(direction, 0)
	if player and is_instance_valid(player):
		to_player = (player.global_position - global_position).normalized()
	Fx.slash_effect(global_position + Vector2(direction * 14, 0),
		float(direction), true, atan2(to_player.y, to_player.x * direction) * direction, 0.8)


func _patrol(_delta: float) -> void:
	velocity.x = speed * direction
	# Change direction if out of patrol bounds or hit a wall
	if abs(global_position.x - home_position.x) > patrol_distance or _hit_wall():
		direction *= -1
		_flip_sprite()


func _rush_player(_delta: float) -> void:
	if not player or not is_instance_valid(player):
		return
	var to_player := player.global_position - global_position
	direction = 1 if to_player.x > 0 else -1
	_flip_sprite()
	velocity.x = rush_speed * direction
	if _hit_wall():
		direction *= -1
		_flip_sprite()


func _face_player() -> void:
	if player and is_instance_valid(player):
		direction = 1 if player.global_position.x > global_position.x else -1
		_flip_sprite()


func _hit_wall() -> bool:
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		if abs(col.get_normal().x) > 0.7:
			return true
	return false


func _flip_sprite() -> void:
	if sprite:
		sprite.flip_h = direction < 0
