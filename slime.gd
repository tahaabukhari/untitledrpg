extends EnemyBase
## Slime Monster — hops around with animated sprite, random scale, and aggro
## behavior. Attacks with a telegraphed lunge that damages the player.

# ─── State Machine ───────────────────────────────────────────────────────────
enum State { PATROL, AGGRO, WINDUP, LUNGE, RECOVER }

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
@export var aggro_time: float = 10.0          ## How long aggro lasts after losing sight
@export var attack_distance: float = 60.0     ## Melee range

@export_group("Attack")
@export var windup_time: float = 0.45         ## Telegraph before the lunge
@export var lunge_speed: float = 320.0        ## Horizontal lunge velocity
@export var lunge_jump: float = 220.0         ## Upward lunge impulse
@export var recover_time: float = 0.8         ## Vulnerable pause after a lunge

@export_group("Patrol")
@export var patrol_distance: float = 400.0    ## Max distance from spawn before turning

@export_group("Scale")
@export var min_scale: float = 1.5            ## Minimum random scale multiplier
@export var max_scale: float = 1.7            ## Maximum random scale multiplier

# ─── Node References ─────────────────────────────────────────────────────────
@onready var sprite: Sprite2D = $Sprite2D
@onready var anim_player: AnimationPlayer = $AnimationPlayer

# ─── Internal State ──────────────────────────────────────────────────────────
var home_position: Vector2 = Vector2.ZERO
var direction: int = 1                        # 1 = right, -1 = left
var state: State = State.PATROL
var aggro_timer: float = 0.0
var hop_timer: float = 0.0
var is_hopping: bool = false
var attack_timer: float = 0.0
var _lunge_airborne: bool = false

# ─── Lifecycle ───────────────────────────────────────────────────────────────

func _enemy_ready() -> void:
	# Record spawn position for patrol bounds
	home_position = global_position

	# Apply random scale between min_scale and max_scale
	var random_scale: float = randf_range(min_scale, max_scale)
	scale = Vector2(random_scale, random_scale)

	# HP + EXP scale with size: small=20hp/6xp, big=100hp/30xp
	var size_ratio: float = (random_scale - min_scale) / maxf(max_scale - min_scale, 0.01)
	max_hp = int(lerpf(20.0, 100.0, size_ratio))
	hp = max_hp
	exp_value = lerpf(6.0, 30.0, size_ratio)
	attack_damage = int(lerpf(6.0, 14.0, size_ratio))

	# Lunge bite hitbox in front of the body
	setup_attack_hitbox(Vector2(26, 18), Vector2(10, 0))

	# Set initial hop cooldown
	hop_timer = randf_range(hop_cooldown_min, hop_cooldown_max)

	# Start idle animation
	if anim_player:
		anim_player.play("idle")


func _enemy_physics(delta: float) -> void:
	# ── Apply gravity ────────────────────────────────────────────────────
	velocity.y += gravity * delta

	# ── State machine ────────────────────────────────────────────────────
	match state:
		State.PATROL:
			_process_patrol(delta)
		State.AGGRO:
			_process_aggro(delta)
		State.WINDUP:
			_process_windup(delta)
		State.LUNGE:
			_process_lunge(delta)
		State.RECOVER:
			_process_recover(delta)

	move_and_slide()

	# ── Landing detection ────────────────────────────────────────────────
	if is_on_floor() and is_hopping:
		is_hopping = false
		velocity.x = 0.0  # Stop sliding after landing


func _on_staggered() -> void:
	# A parried lunge is fully interrupted
	if state == State.WINDUP or state == State.LUNGE:
		state = State.RECOVER
		attack_timer = recover_time * 1.5
		if sprite:
			sprite.modulate = Color(1, 1, 1, 1)

# ─── State: PATROL ───────────────────────────────────────────────────────────

func _process_patrol(delta: float) -> void:
	# Player detection now requires line of sight, not just distance
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
	if _can_see_player():
		aggro_timer = aggro_time

	# Lost interest → return to patrol
	if aggro_timer <= 0.0:
		state = State.PATROL
		hop_timer = randf_range(hop_cooldown_min, hop_cooldown_max)
		return

	# Close enough to attack → telegraphed windup
	if _distance_to_player() < attack_distance * scale.x and is_on_floor():
		state = State.WINDUP
		attack_timer = windup_time
		velocity.x = 0.0
		# Telegraph: yellow flash pulse
		if sprite:
			sprite.modulate = Color(1.4, 1.2, 0.5)
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

# ─── State: WINDUP → LUNGE → RECOVER ────────────────────────────────────────

func _process_windup(delta: float) -> void:
	velocity.x = 0.0
	attack_timer -= delta

	# Track the player during the telegraph so the lunge is honest but dodgeable
	if player:
		direction = 1 if player.global_position.x > global_position.x else -1
		_flip_sprite()

	if attack_timer <= 0.0:
		# Lunge!
		state = State.LUNGE
		_lunge_airborne = false
		if sprite:
			sprite.modulate = Color(1, 1, 1, 1)
		if anim_player:
			anim_player.play("attacked")
		velocity.x = direction * lunge_speed
		velocity.y = -lunge_jump
		enable_attack_hitbox(direction)


func _process_lunge(delta: float) -> void:
	attack_timer += delta  # safety clock
	if not is_on_floor():
		_lunge_airborne = true
	# Lunge ends on landing (or after 1s as a fallback)
	if (_lunge_airborne and is_on_floor()) or attack_timer > 1.0:
		disable_attack_hitbox()
		velocity.x = 0.0
		state = State.RECOVER
		attack_timer = recover_time
		if anim_player:
			anim_player.play("idle")


func _process_recover(delta: float) -> void:
	velocity.x = 0.0
	attack_timer -= delta
	if attack_timer <= 0.0:
		state = State.AGGRO
		aggro_timer = aggro_time
		hop_timer = aggro_hop_cooldown

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


func _hit_wall() -> bool:
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		if abs(col.get_normal().x) > 0.7:
			return true
	return false
