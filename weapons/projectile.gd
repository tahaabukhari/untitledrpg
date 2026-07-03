extends Area2D
class_name PlayerProjectile
## Simple hitscan-free projectile (ranger arrow). Spawned under the Fx
## autoload so scene changes never orphan it. Visual is code-drawn.
## Supports reflect() so a parried arrow flies back (used by enemy shots too).

const LAYER_PROJECTILE := 32   # bit 6
const MASK_ENEMY := 4          # bit 3 EnemyHurtbox (bodies)
const MASK_ENVIRONMENT := 1    # bit 1

var direction := Vector2.RIGHT
var speed := 700.0
var damage := 6
var lifetime := 1.4
var _reflected := false


static func spawn(from: Vector2, dir: Vector2, dmg: int, spd: float) -> PlayerProjectile:
	var p := PlayerProjectile.new()
	p.direction = dir.normalized()
	p.speed = spd
	p.damage = dmg
	Fx.add_child(p)
	p.global_position = from
	p.rotation = p.direction.angle()
	return p


func _ready() -> void:
	collision_layer = LAYER_PROJECTILE
	collision_mask = MASK_ENEMY | MASK_ENVIRONMENT
	monitorable = true

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 4.0
	shape.shape = circle
	add_child(shape)

	# Code-drawn arrow: shaft + bright head
	var shaft := Line2D.new()
	shaft.width = 2.0
	shaft.default_color = Color(0.75, 0.6, 0.4, 1.0)
	shaft.add_point(Vector2(-8, 0))
	shaft.add_point(Vector2(4, 0))
	add_child(shaft)
	var head := Polygon2D.new()
	head.polygon = PackedVector2Array([Vector2(4, -2.5), Vector2(9, 0), Vector2(4, 2.5)])
	head.color = Color(0.9, 0.9, 0.95, 1.0)
	add_child(head)
	z_index = 60

	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func reflect() -> void:
	## Parried: fly back the way we came and hit enemies instead.
	if _reflected:
		return
	_reflected = true
	direction = -direction
	rotation = direction.angle()
	speed *= 1.2
	collision_mask = MASK_ENEMY | MASK_ENVIRONMENT
	Fx.parry_spark(global_position)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy") and body.has_method("take_damage"):
		body.take_damage(damage, direction * 180.0 + Vector2(0, -60))
		Fx.hit_particles(global_position)
		queue_free()
	elif body is StaticBody2D:
		# Stuck in a wall — brief fade
		set_physics_process(false)
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.25)
		tw.tween_callback(func() -> void:
			if is_instance_valid(self):
				queue_free())
