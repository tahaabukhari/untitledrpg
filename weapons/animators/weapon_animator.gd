extends RefCounted
class_name WeaponAnimator
## Base class for per-weapon animation providers.
## Each weapon type (Sword, Staff, etc.) extends this and implements
## its own hold style, attack animations, and teardown logic.
##
## Animators are stateless utilities — they receive everything they need
## as function arguments so they can be freely swapped at runtime.

## The WeaponData this animator is serving. player_animator sets it on equip,
## BEFORE get_hold_positions()/get_attack_animations() are called, so subclasses
## can read per-weapon @export tuning straight off the resource.
var weapon_data: WeaponData = null


## Configure how the weapon sprite looks when held (scale, rotation, offset, z_index, position).
## Override in subclass.
func setup_visual(_weapon_sprite: Sprite2D, _weapon_data: WeaponData, _pivots: Dictionary) -> void:
	pass


## Return a Dictionary of { "anim_name": Animation } for all attacks this weapon provides.
## The player_animator will register these in its AnimationLibrary.
## `pivots` contains: { "base_larm", "base_rarm", "base_torso", "base_head", "base_lleg", "base_rleg" }
## Override in subclass.
func get_attack_animations(_pivots: Dictionary) -> Dictionary:
	return {}


## Return arm position overrides for the weapon's hold pose.
## If non-empty, these will replace base_larm/base_rarm in locomotion animations
## so the character holds the weapon during idle, walk, run, etc.
## Return {} for no overrides (fists use default positions).
func get_hold_positions() -> Dictionary:
	return {}


## Called when the weapon is unequipped. Reset the sprite and hand positions.
## Override in subclass if you need custom teardown beyond the default.
func teardown_visual(_weapon_sprite: Sprite2D, _pivots: Dictionary) -> void:
	if _weapon_sprite:
		_weapon_sprite.visible = false
		_weapon_sprite.texture = null
		_weapon_sprite.scale = Vector2(1, 1)
		_weapon_sprite.rotation = 0
		_weapon_sprite.position = Vector2.ZERO
		_weapon_sprite.offset = Vector2.ZERO
		_weapon_sprite.z_index = 1


# ─── Directional Swing Builder ───────────────────────────────────────────────
## ONE angle-parameterized builder → all 8 attack directions, reused by both
## the player puppet and monsters (pass rig node names via `opts`).
##
## `angle` is the swing plane's aim angle in the RIG's local space (radians,
## 0 = forward along +x, negative = up). The caller is responsible for
## converting world aim into local space (mirror rigs flip x).
##
## opts (all optional):
##   length: float            — animation length (default 0.35)
##   arm_nodes: Array         — pivot node names to swing (default player arms)
##   arm_bases: Array         — matching rest positions (default from pivots)
##   arm_base_rots: Array     — matching rest rotations (default from pivots)
##   weapon_node: String      — weapon sprite node path ("" to skip)
##   body_nodes: Dictionary   — {node_name: rest_pos} kept keyed at rest
##   reach: float             — how far arms push along the aim (default 7.0)
##   windup: float            — wind-up rotation before the sweep (default 0.7)
##   follow: float            — follow-through rotation (default 1.1)
##   hit_start/hit_end: float — hitbox enable window (defaults 0.22/0.62 × length)
##   slash_time: float        — when the slash VFX fires (default 0.3 × length)
##   enable_method/disable_method/slash_method: String — method-track callbacks
##   method_target: String    — node path for method tracks (default ".")
##   with_slash: bool         — fire the slash VFX callback (default true)

static func make_directional_swing(pivots: Dictionary, angle: float, opts: Dictionary = {}) -> Animation:
	var length: float = opts.get("length", 0.35)
	var a := Animation.new()
	a.length = length
	a.step = 0.05

	var dirv := Vector2(cos(angle), sin(angle))
	var arm_nodes: Array = opts.get("arm_nodes", ["LeftArmPivot", "RightArmPivot"])
	var arm_bases: Array = opts.get("arm_bases", [
		pivots.get("base_larm", Vector2(6, -4.5)),
		pivots.get("base_rarm", Vector2(-6, -4.5)),
	])
	var arm_base_rots: Array = opts.get("arm_base_rots", [
		pivots.get("base_larm_rot", 0.0),
		pivots.get("base_rarm_rot", 0.0),
	])
	var reach: float = opts.get("reach", 7.0)
	var windup: float = opts.get("windup", 0.7)
	var follow: float = opts.get("follow", 1.1)

	# Timing landmarks
	var t_wind: float = length * 0.22
	var t_strike: float = length * 0.45
	var t_recover: float = length * 0.75

	# Arms: pull back opposite the aim, then sweep through it
	for i in range(arm_nodes.size()):
		var node_name: String = arm_nodes[i]
		var base: Vector2 = arm_bases[i] if i < arm_bases.size() else Vector2.ZERO
		var base_rot: float = arm_base_rots[i] if i < arm_base_rots.size() else 0.0
		var stagger := 0.9 if i == 0 else 0.75  # rear arm trails slightly

		anim_pos(a, node_name, [
			[0.0, base],
			[t_wind, base - dirv * reach * 0.5],
			[t_strike, base + dirv * reach * stagger],
			[t_recover, base + dirv * reach * 0.4],
			[length, base],
		])
		anim_rot(a, node_name, [
			[0.0, base_rot],
			[t_wind, base_rot + angle - windup],
			[t_strike, base_rot + angle + follow * stagger],
			[t_recover, base_rot + angle + follow * 0.5],
			[length, base_rot],
		])

	# Weapon sprite: sweep an arc through the aim direction
	var weapon_node: String = opts.get("weapon_node", "LeftArmPivot/WeaponSprite")
	if weapon_node != "":
		anim_rot(a, weapon_node, [
			[0.0, 0.0],
			[t_wind, angle - windup - 0.4],
			[t_strike, angle + follow + 0.6],
			[t_recover, angle + follow * 0.4],
			[length, 0.0],
		])

	# Torso/head lean into the swing (only if the rig has them)
	if pivots.has("base_torso"):
		var bt: Vector2 = pivots["base_torso"]
		anim_pos(a, "TorsoPivot", [
			[0.0, bt],
			[t_wind, bt - dirv * 1.5],
			[t_strike, bt + dirv * 2.5],
			[length, bt],
		])
		anim_rot(a, "TorsoPivot", [
			[0.0, 0.0],
			[t_wind, -0.08 * signf(dirv.x if absf(dirv.x) > 0.1 else 1.0)],
			[t_strike, 0.14],
			[length, 0.0],
		])
	if pivots.has("base_head"):
		var bh: Vector2 = pivots["base_head"]
		anim_pos(a, "HeadPivot", [
			[0.0, bh],
			[t_strike, bh + dirv * 1.5],
			[length, bh],
		])
	if pivots.has("base_lleg"):
		anim_pos(a, "LeftLegPivot", [[0.0, pivots["base_lleg"]], [length, pivots["base_lleg"]]])
		anim_rot(a, "LeftLegPivot", [[0.0, 0.0], [length, 0.0]])
	if pivots.has("base_rleg"):
		anim_pos(a, "RightLegPivot", [[0.0, pivots["base_rleg"]], [length, pivots["base_rleg"]]])
		anim_rot(a, "RightLegPivot", [[0.0, 0.0], [length, 0.0]])

	# Extra rig-specific rest holds (enemies with custom bodies)
	var body_nodes: Dictionary = opts.get("body_nodes", {})
	for node_name in body_nodes:
		anim_pos(a, node_name, [[0.0, body_nodes[node_name]], [length, body_nodes[node_name]]])

	# Hitbox window + slash VFX method tracks
	var target: String = opts.get("method_target", ".")
	var hit_start: float = opts.get("hit_start", length * 0.22)
	var hit_end: float = opts.get("hit_end", length * 0.62)
	anim_method(a, target, hit_start, opts.get("enable_method", "_enable_hitbox"))
	if opts.get("with_slash", true):
		anim_method(a, target, opts.get("slash_time", length * 0.3), opts.get("slash_method", "_spawn_directional_slash"))
	anim_method(a, target, hit_end, opts.get("disable_method", "_disable_hitbox"))

	return a


# ─── Track Helpers ───────────────────────────────────────────────────────────
# Shared by all weapon animators for creating smooth keyframed tracks.

static func anim_pos(anim: Animation, node_name: String, keys: Array) -> void:
	var t := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(t, node_name + ":position")
	anim.track_set_interpolation_type(t, Animation.INTERPOLATION_CUBIC)
	for k in keys:
		anim.track_insert_key(t, k[0], k[1])


static func anim_rot(anim: Animation, node_name: String, keys: Array) -> void:
	var t := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(t, node_name + ":rotation")
	anim.track_set_interpolation_type(t, Animation.INTERPOLATION_CUBIC)
	for k in keys:
		anim.track_insert_key(t, k[0], k[1])


static func anim_zidx(anim: Animation, node_name: String, keys: Array) -> void:
	var t := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(t, node_name + ":z_index")
	anim.track_set_interpolation_type(t, Animation.INTERPOLATION_NEAREST)
	for k in keys:
		anim.track_insert_key(t, k[0], k[1])


## Add a method-call track at a specific time.
static func anim_method(anim: Animation, node_path: String, time: float, method: String, args: Array = []) -> void:
	# Find or create the method track for this node
	var track_idx := -1
	for i in anim.get_track_count():
		if anim.track_get_type(i) == Animation.TYPE_METHOD and str(anim.track_get_path(i)) == node_path:
			track_idx = i
			break
	if track_idx == -1:
		track_idx = anim.add_track(Animation.TYPE_METHOD)
		anim.track_set_path(track_idx, node_path)
	anim.track_insert_key(track_idx, time, {"method": method, "args": args})
