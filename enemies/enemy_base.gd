extends CharacterBody2D
class_name EnemyBase
## Shared enemy foundation: HP / damage / death with scaled EXP, hit flash,
## damage numbers (via Fx), knockback, parry-stagger, an attack hitbox that
## damages the player (honoring parry/i-frames on the player side), and
## line-of-sight aggro checks.
##
## Subclasses implement _enemy_physics(delta) instead of _physics_process —
## the base handles death/stagger states first.

signal died

@export_group("Stats")
@export var max_hp: int = 50
@export var attack_damage: int = 10
@export var exp_value: float = 10.0        ## EXP granted on death (scale with size/level)
@export var aggro_range: float = 900.0
@export var flash_sprite_path: NodePath = ^"Sprite2D"
## Only creatures that stand on two legs can be TRIPPED (slide-under knockdown).
## Default false — slimes/bombugs/etc. are immune; set true on humanoids.
@export var trippable: bool = false
## Hit reaction kind: "goo" (default flash+number only), "flesh" (adds blood).
@export var hit_fx: String = "goo"

const TRIP_DOWN_DMG_MULT := 1.35   # a downed enemy takes bonus damage
const TRIP_DOWN_RECOVER := 0.0

# Collision constants (see project.godot [layer_names])
const LAYER_ENEMY_HURTBOX := 4    # bit 3 — player attacks mask this
const LAYER_ENEMY_HITBOX := 16    # bit 5 — enemy attack areas
const MASK_PLAYER_HURTBOX := 8    # bit 4 — the player's Hurtbox area
const MASK_ENVIRONMENT := 1       # bit 1 — terrain (for LOS rays)

var hp: int
var is_dead := false
var stagger_timer := 0.0
var is_downed := false
var downed_timer := 0.0
var player: Node2D = null
var gravity: float = 980.0

var _attack_hitbox: Area2D = null
var _attack_shape: CollisionShape2D = null
var _attack_offset := Vector2.ZERO
var _hit_player_this_swing := false
var _flash_sprite: CanvasItem = null


func _ready() -> void:
	add_to_group("enemy")
	collision_layer = LAYER_ENEMY_HURTBOX
	collision_mask = MASK_ENVIRONMENT
	gravity = ProjectSettings.get_setting("physics/2d/default_gravity", 980.0)
	hp = max_hp
	player = get_tree().get_first_node_in_group("player")
	_flash_sprite = get_node_or_null(flash_sprite_path) as CanvasItem
	_enemy_ready()


## Subclass hook — called at the end of _ready().
func _enemy_ready() -> void:
	pass


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	# Downed (tripped): on the ground, no AI, wide open — same freeze as stagger
	# but longer and reset via _on_tripped. Bipeds only (see trip()).
	if is_downed:
		downed_timer -= delta
		if not is_on_floor():
			velocity.y += gravity * delta
		velocity.x = move_toward(velocity.x, 0, 700.0 * delta)
		move_and_slide()
		if downed_timer <= 0.0:
			is_downed = false
		return
	if stagger_timer > 0.0:
		# Staggered: no AI, just knockback physics winding down
		stagger_timer -= delta
		if not is_on_floor():
			velocity.y += gravity * delta
		velocity.x = move_toward(velocity.x, 0, 600.0 * delta)
		move_and_slide()
		return
	_enemy_physics(delta)


## Subclass hook — normal AI/movement (replaces _physics_process).
func _enemy_physics(_delta: float) -> void:
	pass


# ─── Taking damage / dying ───────────────────────────────────────────────────

func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO) -> void:
	if is_dead:
		return
	var dmg := amount
	if is_downed:
		dmg = int(amount * TRIP_DOWN_DMG_MULT)  # bonus damage while knocked down
	hp -= dmg
	flash_hit()
	Fx.damage_number(global_position, dmg)
	if hit_fx == "flesh":
		var bdir := knockback.normalized() if knockback.length() > 0.0 else Vector2(0, -1)
		Fx.blood_spray(global_position, bdir, dmg)
	# Knockback ignored while downed (stay grounded for the punish)
	if knockback.length() > 0 and not is_downed:
		velocity = knockback
	if hp <= 0:
		hp = 0
		_die()


func trip(duration: float = 2.0) -> void:
	## Swept off its feet — knocked to its knees for `duration`, wide open.
	## HARD RULE: only bipedal enemies can be tripped; everything else no-ops.
	if not trippable or is_dead or is_downed:
		return
	is_downed = true
	downed_timer = duration
	disable_attack_hitbox()
	velocity.x = 0.0
	flash_hit(Color(1.0, 0.9, 0.5))
	Fx.trip_dust(global_position + Vector2(0, 12))
	_on_tripped()


## Subclass hook — interrupt the attack state machine when tripped.
func _on_tripped() -> void:
	pass


func flash_hit(color: Color = Color(1, 0.2, 0.2)) -> void:
	var target: CanvasItem = _flash_sprite if _flash_sprite else self
	target.modulate = color
	var tw := create_tween()
	tw.tween_property(target, "modulate", Color(1, 1, 1, 1), 0.15)


func apply_stagger(duration: float, push: Vector2 = Vector2.ZERO) -> void:
	## Called on a perfect parry (and boss stagger windows). Interrupts the
	## current attack and freezes AI briefly.
	if is_dead:
		return
	stagger_timer = maxf(stagger_timer, duration)
	if push.length() > 0:
		velocity = push
	disable_attack_hitbox()
	flash_hit(Color(1.0, 1.0, 0.4))
	_on_staggered()


## Subclass hook — reset attack state when staggered mid-swing.
func _on_staggered() -> void:
	pass


func _die() -> void:
	if is_dead:
		return
	is_dead = true
	disable_attack_hitbox()
	died.emit()
	# Scaled EXP to the player
	if player and is_instance_valid(player) and player.has_method("add_exp"):
		player.add_exp(exp_value)
	# Fade out and free
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func() -> void:
		if is_instance_valid(self):
			queue_free())


# ─── Attack hitbox (damages the player) ──────────────────────────────────────

func setup_attack_hitbox(size: Vector2, offset: Vector2) -> void:
	## Creates an EnemyHitbox Area2D (layer 5, masks PlayerHurtbox). Enable it
	## during attack active frames with enable_attack_hitbox(facing).
	_attack_offset = offset
	_attack_hitbox = Area2D.new()
	_attack_hitbox.name = "EnemyHitbox"
	_attack_hitbox.collision_layer = LAYER_ENEMY_HITBOX
	_attack_hitbox.collision_mask = MASK_PLAYER_HURTBOX
	_attack_hitbox.monitorable = false
	var rect := RectangleShape2D.new()
	rect.size = size
	_attack_shape = CollisionShape2D.new()
	_attack_shape.shape = rect
	_attack_shape.position = offset
	_attack_shape.disabled = true
	_attack_hitbox.add_child(_attack_shape)
	add_child(_attack_hitbox)
	_attack_hitbox.area_entered.connect(_on_attack_hitbox_hit)


func enable_attack_hitbox(dir: int = 1) -> void:
	## One damage attempt per swing; `dir` mirrors the hitbox horizontally.
	_hit_player_this_swing = false
	if _attack_shape:
		_attack_shape.position = Vector2(_attack_offset.x * dir, _attack_offset.y)
		_attack_shape.set_deferred("disabled", false)


func disable_attack_hitbox() -> void:
	if _attack_shape:
		_attack_shape.set_deferred("disabled", true)


func _on_attack_hitbox_hit(area: Area2D) -> void:
	if _hit_player_this_swing or is_dead:
		return
	var body := area.get_parent()
	if body and body.is_in_group("player") and body.has_method("take_damage"):
		_hit_player_this_swing = true
		var kb := Vector2(signf(body.global_position.x - global_position.x) * 260.0, -140.0)
		# The player resolves parry (staggers us) and i-frames internally
		body.take_damage(attack_damage, global_position, kb, self)


# ─── Detection helpers ───────────────────────────────────────────────────────

func _distance_to_player() -> float:
	if not player or not is_instance_valid(player):
		return INF
	return global_position.distance_to(player.global_position)


func _has_line_of_sight() -> bool:
	## True when no Environment geometry blocks the way to the player.
	if not player or not is_instance_valid(player):
		return false
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(
		global_position, player.global_position, MASK_ENVIRONMENT)
	# Exclude ourselves and the player's body (it sits on the terrain layer)
	var excludes: Array[RID] = [get_rid()]
	if player is CollisionObject2D:
		excludes.append((player as CollisionObject2D).get_rid())
	query.exclude = excludes
	return space.intersect_ray(query).is_empty()


func _can_see_player() -> bool:
	return _distance_to_player() < aggro_range and _has_line_of_sight()
