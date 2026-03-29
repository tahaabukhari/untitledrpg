extends RefCounted
class_name WeaponAnimator
## Base class for per-weapon animation providers.
## Each weapon type (Sword, Staff, etc.) extends this and implements
## its own hold style, attack animations, and teardown logic.
##
## Animators are stateless utilities — they receive everything they need
## as function arguments so they can be freely swapped at runtime.


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
