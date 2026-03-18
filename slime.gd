extends CharacterBody2D
## Slime Monster — hops around with animated sprite, random scale, and aggro behavior.

# ─── State Machine ───────────────────────────────────────────────────────────
enum State { PATROL, AGGRO, ATTACK }

# ─── Exported Tuning Parameters ──────────────────────────────────────────────
@export_group("Movement")
@export var hop_speed: float = 100.0          ## Horizontal speed per hop
@export var hop_jump_force: float = 280.0     ## Upward impulse per hop
@export var hop_cooldown_min: float = 0.8     ## Minimum wait between hops (seconds)
@export var hop_cooldown_max: float = 2.0     ## Maximum wait between hops (seconds)

@export_group("Aggro")
@export var aggro_speed: float = 160.0        ## Horizontal speed when chasing player
@export var aggro_jump_force: float = 340.0   ## Upward impulse when chasing player
@export var aggro_hop_cooldown: float = 0.4   ## Wait between hops while aggro'd
@export var aggro_range: float = 1920.0       ## Detection radius (pixels)
@export var aggro_time: float = 10.0          ## How long aggro lasts after losing sight
@export var attack_distance: float = 40.0     ## Melee range

@export_group("Patrol")
@export var patrol_distance: float = 400.0    ## Max distance from spawn before turning

@export_group("Scale")
@export var min_scale: float = 1.5            ## Minimum random scale multiplier
@export var max_scale: float = 1.7            ## Maximum random scale multiplier

# ─── Node References ─────────────────────────────────────────────────────────
@onready var sprite: Sprite2D = $Sprite2D
@onready var anim_player: AnimationPlayer = $AnimationPlayer

# ─── Internal State ──────────────────────────────────────────────────────────
var player: Node2D = null
var home_position: Vector2 = Vector2.ZERO
var direction: int = 1                        # 1 = right, -1 = left
var state: State = State.PATROL
var aggro_timer: float = 0.0
var hop_timer: float = 0.0
var gravity: float = 0.0
var is_hopping: bool = false

# ─── Lifecycle ───────────────────────────────────────────────────────────────

func _ready() -> void:
	# Cache gravity from project settings
	gravity = ProjectSettings.get_setting("physics/2d/default_gravity", 980.0)

	# Record spawn position for patrol bounds
	home_position = global_position

	# Find the player (make sure the player node is in the "player" group)
	player = get_tree().get_first_node_in_group("player")

	# Apply random scale between min_scale and max_scale
	var random_scale: float = randf_range(min_scale, max_scale)
	scale = Vector2(random_scale, random_scale)

	# Set initial hop cooldown
	hop_timer = randf_range(hop_cooldown_min, hop_cooldown_max)

	# Start idle animation
	if anim_player:
		anim_player.play("idle")


func _physics_process(delta: float) -> void:
	# ── Apply gravity ────────────────────────────────────────────────────
	velocity.y += gravity * delta

	# ── State machine ────────────────────────────────────────────────────
	match state:
		State.PATROL:
			_process_patrol(delta)
		State.AGGRO:
			_process_aggro(delta)
		State.ATTACK:
			_process_attack(delta)

	move_and_slide()

	# ── Landing detection ────────────────────────────────────────────────
	if is_on_floor() and is_hopping:
		is_hopping = false
		velocity.x = 0.0  # Stop sliding after landing

# ─── State: PATROL ───────────────────────────────────────────────────────────

func _process_patrol(delta: float) -> void:
	# Check for player detection → switch to AGGRO
	if _can_see_player():
		state = State.AGGRO
		aggro_timer = aggro_time
		return

	# Hop logic
	if is_on_floor():
		hop_timer -= delta
		if hop_timer <= 0.0:
			_perform_hop(hop_speed, hop_jump_force)
			hop_timer = randf_range(hop_cooldown_min, hop_cooldown_max)

	# Turn around at patrol bounds or walls
	if abs(global_position.x - home_position.x) > patrol_distance:
		direction *= -1
		_flip_sprite()
	elif _hit_wall():
		direction *= -1
		_flip_sprite()

# ─── State: AGGRO ────────────────────────────────────────────────────────────

func _process_aggro(delta: float) -> void:
	aggro_timer -= delta

	# Lost interest → return to patrol
	if aggro_timer <= 0.0:
		state = State.PATROL
		hop_timer = randf_range(hop_cooldown_min, hop_cooldown_max)
		return

	# Close enough to attack
	if _distance_to_player() < attack_distance:
		state = State.ATTACK
		return

	# Face the player
	if player:
		direction = 1 if player.global_position.x > global_position.x else -1
		_flip_sprite()

	# Aggressive hopping toward player
	if is_on_floor():
		hop_timer -= delta
		if hop_timer <= 0.0:
			_perform_hop(aggro_speed, aggro_jump_force)
			hop_timer = aggro_hop_cooldown

# ─── State: ATTACK ───────────────────────────────────────────────────────────

func _process_attack(_delta: float) -> void:
	velocity.x = 0.0

	# Play attacked animation once
	if anim_player and anim_player.current_animation != "attacked":
		anim_player.play("attacked")

	# If player moved out of range, re-enter aggro
	if _distance_to_player() > attack_distance * 1.5:
		state = State.AGGRO
		aggro_timer = aggro_time
		if anim_player:
			anim_player.play("idle")

# ─── Movement Helpers ────────────────────────────────────────────────────────

func _perform_hop(h_speed: float, jump_force: float) -> void:
	velocity.x = h_speed * direction
	velocity.y = -jump_force
	is_hopping = true

	# Ensure idle animation is playing during movement
	if anim_player and anim_player.current_animation != "idle":
		anim_player.play("idle")

func _flip_sprite() -> void:
	if sprite:
		sprite.flip_h = (direction > 0)

# ─── Detection Helpers ──────────────────────────────────────────────────────

func _can_see_player() -> bool:
	if not player:
		return false
	return _distance_to_player() < aggro_range

func _distance_to_player() -> float:
	if not player:
		return 99999.0
	return global_position.distance_to(player.global_position)

func _hit_wall() -> bool:
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		if abs(col.get_normal().x) > 0.7:
			return true
	return false
