extends CharacterBody2D

enum State { PATROL, AGGRO, ATTACK }

@export var speed: float = 120.0
@export var aggro_speed: float = 350.0
@export var patrol_distance: float = 400.0 # in pixels, left/right patrol range
@export var aggro_range: float = 30.0 * 64.0 # 30 meters, assuming 1m=64px tile
@export var attack_distance: float = 40.0
@export var aggro_time: float = 10.0

@onready var sprite = $Sprite2D

var player: Node2D = null
var home_position: Vector2
var direction: int = 1 # 1=right, -1=left
var state = State.PATROL
var aggro_timer: float = 0.0

func _ready():
	home_position = global_position
	player = get_tree().get_first_node_in_group("player") # Add your player to a "player" group!
	aggro_timer = 0.0

func _physics_process(delta: float) -> void:
	match state:
		State.PATROL:
			_patrol(delta)
			if _can_see_player():
				state = State.AGGRO
				aggro_timer = aggro_time
		State.AGGRO:
			aggro_timer -= delta
			_rush_player(delta)
			if aggro_timer <= 0.0:
				state = State.PATROL
			elif _distance_to_player() < attack_distance:
				state = State.ATTACK
		State.ATTACK:
			_attack_player()
			if _distance_to_player() > attack_distance * 1.2:
				state = State.AGGRO

func _patrol(delta: float) -> void:
	velocity.x = speed * direction
	velocity.y += ProjectSettings.get_setting("physics/2d/default_gravity") * delta
	move_and_slide()
	# Change direction if out of patrol bounds or hit a wall
	if abs(global_position.x - home_position.x) > patrol_distance or _is_on_wall():
		direction *= -1
		_flip_sprite()

func _rush_player(delta: float) -> void:
	if not player:
		return
	var to_player = (player.global_position - global_position).normalized()
	velocity.x = aggro_speed * sign(to_player.x)
	velocity.y += ProjectSettings.get_setting("physics/2d/default_gravity") * delta
	move_and_slide()
	if _is_on_wall():
		direction *= -1
		_flip_sprite()

func _attack_player() -> void:
	# You can add animation or signal here!
	velocity = Vector2.ZERO
	# (Add attack effect or call a function on the player if in range)

func _can_see_player() -> bool:
	if not player:
		return false
	return _distance_to_player() < aggro_range

func _distance_to_player() -> float:
	if not player:
		return 99999.0
	return global_position.distance_to(player.global_position)

func _is_on_wall() -> bool:
	for i in get_slide_collision_count():
		var col = get_slide_collision(i)
		var normal = col.get_normal()
		if abs(normal.x) > 0.7:
			return true
	return false

func _flip_sprite():
	if sprite:
		sprite.flip_h = direction < 0
