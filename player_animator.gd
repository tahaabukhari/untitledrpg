extends Node2D

## Code-driven puppet animator for the layered player character.
## Attach to the PlayerSkin node. Creates Idle, Walk, and Run animations
## programmatically so any skin/equipment swap works automatically.

@onready var anim_player: AnimationPlayer = $AnimPlayer

var current_state: String = ""
var next_punch: String = "attack_right"  # alternates between right and left

signal attack_finished

# ─── Adjustable Pivot Positions (tweak these in the Inspector) ───────────────
@export_group("Upper Body")
@export var base_torso := Vector2(0, 0.5)
@export var base_head  := Vector2(0, -5.5)
@export var base_larm  := Vector2(6, -4.5)
@export var base_rarm  := Vector2(-6, -4.5)

@export_group("Lower Body")
@export var base_lleg  := Vector2(-1, 4)
@export var base_rleg  := Vector2(0, 4)


func _ready() -> void:
	_build_all_animations()
	play_state("idle")


func play_state(new_state: String) -> void:
	if new_state == current_state:
		return
	current_state = new_state
	anim_player.play(new_state)


func play_attack() -> void:
	current_state = next_punch
	anim_player.play(next_punch)
	# Alternate for next press
	next_punch = "attack_left" if next_punch == "attack_right" else "attack_right"
	if not anim_player.animation_finished.is_connected(_on_attack_done):
		anim_player.animation_finished.connect(_on_attack_done, CONNECT_ONE_SHOT)


func play_uppercut() -> void:
	current_state = "uppercut"
	anim_player.play("uppercut")
	if not anim_player.animation_finished.is_connected(_on_attack_done):
		anim_player.animation_finished.connect(_on_attack_done, CONNECT_ONE_SHOT)


func _on_attack_done(_anim_name: String) -> void:
	current_state = ""
	attack_finished.emit()


# ─── Animation Library Builder ──────────────────────────────────────────────

func _build_all_animations() -> void:
	var lib = AnimationLibrary.new()
	lib.add_animation("idle", _make_idle())
	lib.add_animation("walk", _make_walk())
	lib.add_animation("run",  _make_run())
	lib.add_animation("jump", _make_jump())
	lib.add_animation("fall", _make_fall())
	lib.add_animation("long_fall", _make_long_fall())
	lib.add_animation("attack_right", _make_attack_right())
	lib.add_animation("attack_left", _make_attack_left())
	lib.add_animation("uppercut", _make_uppercut())
	anim_player.add_animation_library("", lib)


# ─── IDLE: Gentle breathing rhythm ──────────────────────────────────────────
# Subtle 1px up/down bob on torso, head, and arms.
# Legs stay perfectly still.

func _make_idle() -> Animation:
	var a = Animation.new()
	a.length = 1.2
	a.loop_mode = Animation.LOOP_LINEAR

	# Torso: gentle breathing bob
	_pos(a, "TorsoPivot", [
		[0.0,  base_torso],
		[0.3,  base_torso + Vector2(0, -0.5)],
		[0.6,  base_torso],
		[0.9,  base_torso + Vector2(0,  0.5)],
		[1.2,  base_torso],
	])

	# Head: follows torso, slightly delayed for organic feel
	_pos(a, "HeadPivot", [
		[0.0,   base_head],
		[0.35,  base_head + Vector2(0, -0.5)],
		[0.65,  base_head],
		[0.95,  base_head + Vector2(0,  0.5)],
		[1.2,   base_head],
	])

	# Left arm: breathing sway
	_pos(a, "LeftArmPivot", [
		[0.0,  base_larm],
		[0.3,  base_larm + Vector2(0, -0.5)],
		[0.6,  base_larm],
		[0.9,  base_larm + Vector2(0,  0.5)],
		[1.2,  base_larm],
	])

	# Right arm: breathing sway
	_pos(a, "RightArmPivot", [
		[0.0,  base_rarm],
		[0.3,  base_rarm + Vector2(0, -0.5)],
		[0.6,  base_rarm],
		[0.9,  base_rarm + Vector2(0,  0.5)],
		[1.2,  base_rarm],
	])

	# Legs: reset to rest (in case transitioning from walk/run)
	_rot(a, "LeftLegPivot",  [[0.0, 0.0], [1.2, 0.0]])
	_rot(a, "RightLegPivot", [[0.0, 0.0], [1.2, 0.0]])
	_rot(a, "LeftArmPivot",  [[0.0, 0.0], [1.2, 0.0]])
	_rot(a, "RightArmPivot", [[0.0, 0.0], [1.2, 0.0]])

	# Legs position: lock to base (same as attack)
	_pos(a, "LeftLegPivot",  [[0.0, base_lleg], [1.2, base_lleg]])
	_pos(a, "RightLegPivot", [[0.0, base_rleg], [1.2, base_rleg]])

	# Torso rotation: reset
	_rot(a, "TorsoPivot", [[0.0, 0.0], [1.2, 0.0]])

	# Z-index: reset to normal layering
	_zidx(a, "TorsoPivot/Sprite",    [[0.0, 0]])
	_zidx(a, "LeftLegPivot/Sprite",  [[0.0, -2]])
	_zidx(a, "RightLegPivot/Sprite", [[0.0, -2]])
	_zidx(a, "LeftArmPivot/Sprite",  [[0.0, 2]])
	_zidx(a, "RightArmPivot/Sprite", [[0.0, 2]])

	return a


# ─── WALK: Light step cycle ─────────────────────────────────────────────────
# Legs alternate forward/back via rotation from the hip pivot.
# Arms swing opposite to legs for natural gait.
# Torso bobs twice per cycle (once per step).

func _make_walk() -> Animation:
	var a = Animation.new()
	a.length = 0.6
	a.loop_mode = Animation.LOOP_LINEAR

	# Legs: alternating swing — tight gap (±3.4°)
	_rot(a, "LeftLegPivot", [
		[0.0,   -0.06],
		[0.15,   0.0],
		[0.3,    0.06],
		[0.45,   0.0],
		[0.6,   -0.06],
	])
	_rot(a, "RightLegPivot", [
		[0.0,    0.06],
		[0.15,   0.0],
		[0.3,   -0.06],
		[0.45,   0.0],
		[0.6,    0.06],
	])

	# Arms: opposite swing to legs (natural gait, ±5.7°)
	_rot(a, "LeftArmPivot", [
		[0.0,    0.1],
		[0.15,   0.0],
		[0.3,   -0.1],
		[0.45,   0.0],
		[0.6,    0.1],
	])
	_rot(a, "RightArmPivot", [
		[0.0,   -0.1],
		[0.15,   0.0],
		[0.3,    0.1],
		[0.45,   0.0],
		[0.6,   -0.1],
	])

	# Torso: step bob (two bounces per full cycle, one per step)
	_pos(a, "TorsoPivot", [
		[0.0,   base_torso],
		[0.15,  base_torso + Vector2(0, -0.5)],
		[0.3,   base_torso],
		[0.45,  base_torso + Vector2(0, -0.5)],
		[0.6,   base_torso],
	])

	# Head: follows torso bob
	_pos(a, "HeadPivot", [
		[0.0,   base_head],
		[0.15,  base_head + Vector2(0, -0.5)],
		[0.3,   base_head],
		[0.45,  base_head + Vector2(0, -0.5)],
		[0.6,   base_head],
	])

	# Arms position: keep at rest
	_pos(a, "LeftArmPivot",  [[0.0, base_larm], [0.6, base_larm]])
	_pos(a, "RightArmPivot", [[0.0, base_rarm], [0.6, base_rarm]])

	# Legs position: lock to base (same as attack)
	_pos(a, "LeftLegPivot",  [[0.0, base_lleg], [0.6, base_lleg]])
	_pos(a, "RightLegPivot", [[0.0, base_rleg], [0.6, base_rleg]])

	# Torso rotation: reset to upright
	_rot(a, "TorsoPivot", [[0.0, 0.0], [0.6, 0.0]])

	return a


# ─── RUN: Faster, wider, with forward lean ──────────────────────────────────
# Same structure as walk but with bigger rotation angles, faster tempo,
# larger vertical bob, and a slight forward torso lean.

func _make_run() -> Animation:
	var a = Animation.new()
	a.length = 0.28
	a.loop_mode = Animation.LOOP_LINEAR

	var q: float = a.length / 4.0  # quarter-cycle time

	# Legs: tighter swing — max 1px gap (±5.7°)
	_rot(a, "LeftLegPivot", [
		[0.0,      -0.1],
		[q,         0.0],
		[q * 2.0,   0.1],
		[q * 3.0,   0.0],
		[a.length, -0.1],
	])
	_rot(a, "RightLegPivot", [
		[0.0,       0.1],
		[q,         0.0],
		[q * 2.0,  -0.1],
		[q * 3.0,   0.0],
		[a.length,  0.1],
	])

	# Arms: wider swing (±11.5°)
	_rot(a, "LeftArmPivot", [
		[0.0,       0.2],
		[q,         0.0],
		[q * 2.0,  -0.2],
		[q * 3.0,   0.0],
		[a.length,  0.2],
	])
	_rot(a, "RightArmPivot", [
		[0.0,      -0.2],
		[q,         0.0],
		[q * 2.0,   0.2],
		[q * 3.0,   0.0],
		[a.length, -0.2],
	])

	# Torso: pronounced step bob (1px)
	_pos(a, "TorsoPivot", [
		[0.0,      base_torso],
		[q,        base_torso + Vector2(0, -1)],
		[q * 2.0,  base_torso],
		[q * 3.0,  base_torso + Vector2(0, -1)],
		[a.length, base_torso],
	])

	# Torso: slight forward lean for urgency
	_rot(a, "TorsoPivot", [
		[0.0, 0.05],
		[a.length, 0.05],
	])

	# Head: follows torso bob
	_pos(a, "HeadPivot", [
		[0.0,      base_head],
		[q,        base_head + Vector2(0, -1)],
		[q * 2.0,  base_head],
		[q * 3.0,  base_head + Vector2(0, -1)],
		[a.length, base_head],
	])

	# Arms position: keep at rest
	_pos(a, "LeftArmPivot",  [[0.0, base_larm], [a.length, base_larm]])
	_pos(a, "RightArmPivot", [[0.0, base_rarm], [a.length, base_rarm]])

	# Legs position: lock to base (same as attack)
	_pos(a, "LeftLegPivot",  [[0.0, base_lleg], [a.length, base_lleg]])
	_pos(a, "RightLegPivot", [[0.0, base_rleg], [a.length, base_rleg]])

	return a


# ─── JUMP: Rising pose ───────────────────────────────────────────────────────
# Legs pull together and tuck, arms reach upward, torso lifts.
# Subtle float bob keeps it feeling alive.

func _make_jump() -> Animation:
	var a = Animation.new()
	a.length = 0.5
	a.loop_mode = Animation.LOOP_LINEAR

	# Legs: pull together — very tight (max 0.5px gap)
	_rot(a, "LeftLegPivot", [
		[0.0,  -0.05],
		[0.25, -0.08],
		[0.5,  -0.05],
	])
	_rot(a, "RightLegPivot", [
		[0.0,  -0.05],
		[0.25, -0.08],
		[0.5,  -0.05],
	])
	# Legs position: pull inward toward center (0.5px each side)
	_pos(a, "LeftLegPivot", [
		[0.0,  base_lleg + Vector2(0.5, -1)],
		[0.25, base_lleg + Vector2(0.5, -1.5)],
		[0.5,  base_lleg + Vector2(0.5, -1)],
	])
	_pos(a, "RightLegPivot", [
		[0.0,  base_rleg + Vector2(-0.5, -1)],
		[0.25, base_rleg + Vector2(-0.5, -1.5)],
		[0.5,  base_rleg + Vector2(-0.5, -1)],
	])

	# Arms: reach upward
	_rot(a, "LeftArmPivot", [
		[0.0,  -0.2],
		[0.25, -0.25],
		[0.5,  -0.2],
	])
	_rot(a, "RightArmPivot", [
		[0.0,   0.2],
		[0.25,  0.25],
		[0.5,   0.2],
	])
	_pos(a, "LeftArmPivot", [
		[0.0,  base_larm + Vector2(0, -1)],
		[0.25, base_larm + Vector2(0, -1.5)],
		[0.5,  base_larm + Vector2(0, -1)],
	])
	_pos(a, "RightArmPivot", [
		[0.0,  base_rarm + Vector2(0, -1)],
		[0.25, base_rarm + Vector2(0, -1.5)],
		[0.5,  base_rarm + Vector2(0, -1)],
	])

	# Torso: lift upward with float bob
	_pos(a, "TorsoPivot", [
		[0.0,  base_torso + Vector2(0, -1.5)],
		[0.25, base_torso + Vector2(0, -2)],
		[0.5,  base_torso + Vector2(0, -1.5)],
	])
	_rot(a, "TorsoPivot", [[0.0, 0.0], [0.5, 0.0]])

	# Head: lift with torso
	_pos(a, "HeadPivot", [
		[0.0,  base_head + Vector2(0, -1.5)],
		[0.25, base_head + Vector2(0, -2)],
		[0.5,  base_head + Vector2(0, -1.5)],
	])

	return a


# ─── FALL: Default short fall ─────────────────────────────────────────────────
# Legs pull up slightly, arms spread outward (not curled).
# Torso and head duck down.

func _make_fall() -> Animation:
	var a = Animation.new()
	a.length = 0.4
	a.loop_mode = Animation.LOOP_LINEAR

	# Legs: pull up slightly — only 1px rise
	_rot(a, "LeftLegPivot", [
		[0.0,  -0.05],
		[0.2,  -0.06],
		[0.4,  -0.05],
	])
	_rot(a, "RightLegPivot", [
		[0.0,  -0.05],
		[0.2,  -0.06],
		[0.4,  -0.05],
	])
	_pos(a, "LeftLegPivot", [
		[0.0,  base_lleg + Vector2(0.5, -1)],
		[0.2,  base_lleg + Vector2(0.5, -1)],
		[0.4,  base_lleg + Vector2(0.5, -1)],
	])
	_pos(a, "RightLegPivot", [
		[0.0,  base_rleg + Vector2(-0.5, -1)],
		[0.2,  base_rleg + Vector2(-0.5, -1)],
		[0.4,  base_rleg + Vector2(-0.5, -1)],
	])

	# Arms: spread outward slightly (matching legs style, NOT curling in)
	_rot(a, "LeftArmPivot", [
		[0.0,  -0.15],
		[0.2,  -0.2],
		[0.4,  -0.15],
	])
	_rot(a, "RightArmPivot", [
		[0.0,   0.15],
		[0.2,   0.2],
		[0.4,   0.15],
	])
	_pos(a, "LeftArmPivot", [
		[0.0,  base_larm + Vector2(1.5, -1)],
		[0.2,  base_larm + Vector2(2, -1.5)],
		[0.4,  base_larm + Vector2(1.5, -1)],
	])
	_pos(a, "RightArmPivot", [
		[0.0,  base_rarm + Vector2(-1.5, -1)],
		[0.2,  base_rarm + Vector2(-2, -1.5)],
		[0.4,  base_rarm + Vector2(-1.5, -1)],
	])

	# Torso: compress down slightly
	_pos(a, "TorsoPivot", [
		[0.0,  base_torso + Vector2(0, 0.5)],
		[0.2,  base_torso + Vector2(0, 1)],
		[0.4,  base_torso + Vector2(0, 0.5)],
	])
	_rot(a, "TorsoPivot", [[0.0, -0.03], [0.4, -0.03]])

	# Head: duck down
	_pos(a, "HeadPivot", [
		[0.0,  base_head + Vector2(0, 0.5)],
		[0.2,  base_head + Vector2(0, 1)],
		[0.4,  base_head + Vector2(0, 0.5)],
	])

	# Z-index: torso behind, legs above, hands on top
	_zidx(a, "TorsoPivot/Sprite",    [[0.0, -1]])
	_zidx(a, "LeftLegPivot/Sprite",  [[0.0, 1]])
	_zidx(a, "RightLegPivot/Sprite", [[0.0, 1]])
	_zidx(a, "LeftArmPivot/Sprite",  [[0.0, 3]])
	_zidx(a, "RightArmPivot/Sprite", [[0.0, 3]])

	return a


# ─── LONG FALL: Dramatic high fall (>4s) ──────────────────────────────────────
# Player curls up tight AND the entire body rotates 360° while falling.

func _make_long_fall() -> Animation:
	var a = Animation.new()
	a.length = 1.0
	a.loop_mode = Animation.LOOP_LINEAR

	# Legs: curl up tight
	_rot(a, "LeftLegPivot", [
		[0.0,  -0.2],
		[0.5,  -0.25],
		[1.0,  -0.2],
	])
	_rot(a, "RightLegPivot", [
		[0.0,  -0.2],
		[0.5,  -0.25],
		[1.0,  -0.2],
	])
	_pos(a, "LeftLegPivot", [
		[0.0,  base_lleg + Vector2(1.5, -3)],
		[0.5,  base_lleg + Vector2(1.5, -3.5)],
		[1.0,  base_lleg + Vector2(1.5, -3)],
	])
	_pos(a, "RightLegPivot", [
		[0.0,  base_rleg + Vector2(-1.5, -3)],
		[0.5,  base_rleg + Vector2(-1.5, -3.5)],
		[1.0,  base_rleg + Vector2(-1.5, -3)],
	])

	# Arms: curl inward protectively
	_rot(a, "LeftArmPivot", [
		[0.0,   0.4],
		[0.5,   0.45],
		[1.0,   0.4],
	])
	_rot(a, "RightArmPivot", [
		[0.0,  -0.4],
		[0.5,  -0.45],
		[1.0,  -0.4],
	])
	_pos(a, "LeftArmPivot", [
		[0.0,  base_larm + Vector2(-2, 2)],
		[0.5,  base_larm + Vector2(-2, 1.5)],
		[1.0,  base_larm + Vector2(-2, 2)],
	])
	_pos(a, "RightArmPivot", [
		[0.0,  base_rarm + Vector2(2, 2)],
		[0.5,  base_rarm + Vector2(2, 1.5)],
		[1.0,  base_rarm + Vector2(2, 2)],
	])

	# Torso: compress
	_pos(a, "TorsoPivot", [
		[0.0,  base_torso + Vector2(0, 1)],
		[0.5,  base_torso + Vector2(0, 1.5)],
		[1.0,  base_torso + Vector2(0, 1)],
	])
	_rot(a, "TorsoPivot", [[0.0, -0.05], [1.0, -0.05]])

	# Head: duck down
	_pos(a, "HeadPivot", [
		[0.0,  base_head + Vector2(0, 1)],
		[0.5,  base_head + Vector2(0, 1.5)],
		[1.0,  base_head + Vector2(0, 1)],
	])

	# FULL BODY 360° rotation via the root "." (PlayerSkin node)
	var rt := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(rt, ".:rotation")
	a.track_set_interpolation_type(rt, Animation.INTERPOLATION_LINEAR)
	a.track_insert_key(rt, 0.0, 0.0)
	a.track_insert_key(rt, 1.0, TAU)

	# Z-index: same as regular fall
	_zidx(a, "TorsoPivot/Sprite",    [[0.0, -1]])
	_zidx(a, "LeftLegPivot/Sprite",  [[0.0, 1]])
	_zidx(a, "RightLegPivot/Sprite", [[0.0, 1]])
	_zidx(a, "LeftArmPivot/Sprite",  [[0.0, 3]])
	_zidx(a, "RightArmPivot/Sprite", [[0.0, 3]])

	return a


# ─── ATTACK RIGHT: Single right fist punch ─────────────────────────────────

func _make_attack_right() -> Animation:
	var a = Animation.new()
	a.length = 0.2
	a.loop_mode = Animation.LOOP_NONE

	# Right arm: punch forward 8px then snap back
	_pos(a, "RightArmPivot", [
		[0.0,   base_rarm],
		[0.05,  base_rarm + Vector2(8, -1)],
		[0.12,  base_rarm + Vector2(2, 0)],
		[0.17,  base_rarm],
	])
	_rot(a, "RightArmPivot", [
		[0.0,   0.0],
		[0.03, -0.2],
		[0.08, -0.15],
		[0.17,  0.0],
	])

	# Left arm: stays at rest
	_pos(a, "LeftArmPivot", [[0.0, base_larm], [0.2, base_larm]])
	_rot(a, "LeftArmPivot", [[0.0, 0.0], [0.2, 0.0]])

	# Torso: lunge forward (4px)
	_pos(a, "TorsoPivot", [
		[0.0,   base_torso],
		[0.05,  base_torso + Vector2(4, -0.5)],
		[0.12,  base_torso + Vector2(1, 0)],
		[0.17,  base_torso],
		[0.2,   base_torso],
	])
	_rot(a, "TorsoPivot", [
		[0.0,  0.0],
		[0.05, 0.06],
		[0.17, 0.0],
		[0.2,  0.0],
	])

	# Head: follows body (3px)
	_pos(a, "HeadPivot", [
		[0.0,   base_head],
		[0.05,  base_head + Vector2(3, -0.5)],
		[0.12,  base_head + Vector2(0.5, 0)],
		[0.17,  base_head],
		[0.2,   base_head],
	])

	# Legs: stay at rest
	_rot(a, "LeftLegPivot",  [[0.0, 0.0], [0.2, 0.0]])
	_rot(a, "RightLegPivot", [[0.0, 0.0], [0.2, 0.0]])
	_pos(a, "LeftLegPivot",  [[0.0, base_lleg], [0.2, base_lleg]])
	_pos(a, "RightLegPivot", [[0.0, base_rleg], [0.2, base_rleg]])

	# Hitbox + swing particle
	var mt := a.add_track(Animation.TYPE_METHOD)
	a.track_set_path(mt, ".")
	a.track_insert_key(mt, 0.03, {"method": "_enable_hitbox", "args": []})
	a.track_insert_key(mt, 0.05, {"method": "_spawn_swing_arc", "args": []})
	a.track_insert_key(mt, 0.13, {"method": "_disable_hitbox", "args": []})

	return a


# ─── ATTACK LEFT: Single left fist punch ──────────────────────────────────

func _make_attack_left() -> Animation:
	var a = Animation.new()
	a.length = 0.2
	a.loop_mode = Animation.LOOP_NONE

	# Left arm: punch forward 8px then snap back
	_pos(a, "LeftArmPivot", [
		[0.0,   base_larm],
		[0.05,  base_larm + Vector2(8, -1)],
		[0.12,  base_larm + Vector2(2, 0)],
		[0.17,  base_larm],
	])
	_rot(a, "LeftArmPivot", [
		[0.0,   0.0],
		[0.03, -0.2],
		[0.08, -0.15],
		[0.17,  0.0],
	])

	# Right arm: stays at rest
	_pos(a, "RightArmPivot", [[0.0, base_rarm], [0.2, base_rarm]])
	_rot(a, "RightArmPivot", [[0.0, 0.0], [0.2, 0.0]])

	# Torso: lunge forward (4px)
	_pos(a, "TorsoPivot", [
		[0.0,   base_torso],
		[0.05,  base_torso + Vector2(4, -0.5)],
		[0.12,  base_torso + Vector2(1, 0)],
		[0.17,  base_torso],
		[0.2,   base_torso],
	])
	_rot(a, "TorsoPivot", [
		[0.0,  0.0],
		[0.05, 0.06],
		[0.17, 0.0],
		[0.2,  0.0],
	])

	# Head: follows body (3px)
	_pos(a, "HeadPivot", [
		[0.0,   base_head],
		[0.05,  base_head + Vector2(3, -0.5)],
		[0.12,  base_head + Vector2(0.5, 0)],
		[0.17,  base_head],
		[0.2,   base_head],
	])

	# Legs: stay at rest
	_rot(a, "LeftLegPivot",  [[0.0, 0.0], [0.2, 0.0]])
	_rot(a, "RightLegPivot", [[0.0, 0.0], [0.2, 0.0]])
	_pos(a, "LeftLegPivot",  [[0.0, base_lleg], [0.2, base_lleg]])
	_pos(a, "RightLegPivot", [[0.0, base_rleg], [0.2, base_rleg]])

	# Hitbox + swing particle
	var mt := a.add_track(Animation.TYPE_METHOD)
	a.track_set_path(mt, ".")
	a.track_insert_key(mt, 0.03, {"method": "_enable_hitbox", "args": []})
	a.track_insert_key(mt, 0.05, {"method": "_spawn_swing_arc", "args": []})
	a.track_insert_key(mt, 0.13, {"method": "_disable_hitbox", "args": []})

	return a


# ─── UPPERCUT: Charged sweeping upward punch ─────────────────────────────────

func _make_uppercut() -> Animation:
	var a = Animation.new()
	a.length = 0.35
	a.loop_mode = Animation.LOOP_NONE

	# Right arm: start low, sweep upward 18px (wide x-reach)
	_pos(a, "RightArmPivot", [
		[0.0,   base_rarm + Vector2(0, 6)],
		[0.08,  base_rarm + Vector2(7, 3)],
		[0.16,  base_rarm + Vector2(11, -10)],
		[0.22,  base_rarm + Vector2(7, -18)],
		[0.3,   base_rarm + Vector2(0, -6)],
		[0.35,  base_rarm],
	])
	_rot(a, "RightArmPivot", [
		[0.0,   0.3],
		[0.08,  0.1],
		[0.16, -0.3],
		[0.22, -0.4],
		[0.3,  -0.1],
		[0.35,  0.0],
	])

	# Left arm: brace slightly
	_pos(a, "LeftArmPivot", [
		[0.0,   base_larm],
		[0.1,   base_larm + Vector2(-1.4, 1)],
		[0.25,  base_larm + Vector2(-1.4, 0)],
		[0.35,  base_larm],
	])
	_rot(a, "LeftArmPivot", [
		[0.0,  0.0],
		[0.1,  0.15],
		[0.25, 0.1],
		[0.35, 0.0],
	])

	# Torso: crouch then lift upward (3px)
	_pos(a, "TorsoPivot", [
		[0.0,   base_torso + Vector2(0, 2)],
		[0.08,  base_torso + Vector2(1.4, 1)],
		[0.16,  base_torso + Vector2(2.8, -2)],
		[0.22,  base_torso + Vector2(1.4, -3)],
		[0.3,   base_torso + Vector2(0, -1)],
		[0.35,  base_torso],
	])
	_rot(a, "TorsoPivot", [
		[0.0,  -0.05],
		[0.08, -0.02],
		[0.16,  0.08],
		[0.22,  0.06],
		[0.3,   0.02],
		[0.35,  0.0],
	])

	# Head: follow torso arc
	_pos(a, "HeadPivot", [
		[0.0,   base_head + Vector2(0, 2)],
		[0.08,  base_head + Vector2(0.7, 1)],
		[0.16,  base_head + Vector2(2.1, -3)],
		[0.22,  base_head + Vector2(1.4, -4)],
		[0.3,   base_head + Vector2(0, -1)],
		[0.35,  base_head],
	])

	# Legs: slight crouch then push up
	_rot(a, "LeftLegPivot", [
		[0.0,  0.08],
		[0.1,  0.04],
		[0.2,  -0.04],
		[0.35, 0.0],
	])
	_rot(a, "RightLegPivot", [
		[0.0,  0.08],
		[0.1,  0.04],
		[0.2,  -0.04],
		[0.35, 0.0],
	])
	_pos(a, "LeftLegPivot",  [[0.0, base_lleg], [0.35, base_lleg]])
	_pos(a, "RightLegPivot", [[0.0, base_rleg], [0.35, base_rleg]])

	# Hitbox + big swing arc
	var mt := a.add_track(Animation.TYPE_METHOD)
	a.track_set_path(mt, ".")
	a.track_insert_key(mt, 0.06, {"method": "_enable_hitbox", "args": []})
	a.track_insert_key(mt, 0.10, {"method": "_spawn_swing_arc", "args": []})
	a.track_insert_key(mt, 0.14, {"method": "_spawn_swing_arc", "args": []})
	a.track_insert_key(mt, 0.24, {"method": "_disable_hitbox", "args": []})

	return a


func _enable_hitbox() -> void:
	var hitbox = get_node_or_null("AttackHitbox/HitShape")
	if hitbox:
		hitbox.disabled = false


func _disable_hitbox() -> void:
	var hitbox = get_node_or_null("AttackHitbox/HitShape")
	if hitbox:
		hitbox.disabled = true


func _spawn_swing_arc() -> void:
	## Spawns a visible swoosh arc (Line2D) at the player's position.
	var player_node = get_parent()  # Player (CharacterBody2D)
	if not player_node:
		return
	var dir: float = sign(scale.x) if scale.x != 0 else 1.0
	var origin: Vector2 = player_node.global_position

	# Create the swoosh arc
	var arc = Line2D.new()
	arc.width = 4.0
	arc.default_color = Color(1.0, 1.0, 0.8, 0.95)
	arc.z_index = 100
	arc.begin_cap_mode = Line2D.LINE_CAP_ROUND
	arc.end_cap_mode = Line2D.LINE_CAP_ROUND

	# Build a semicircle arc of points
	var arc_radius := 20.0
	for i in range(9):
		var t: float = float(i) / 8.0
		var angle: float = lerpf(-PI * 0.4, PI * 0.4, t)
		var pt := Vector2(cos(angle) * arc_radius * dir, sin(angle) * arc_radius)
		pt += Vector2(dir * 14, 0)  # offset forward from player center
		arc.add_point(pt)

	arc.global_position = origin
	player_node.get_parent().add_child(arc)

	# Animate: shrink width + fade out
	var tw = arc.create_tween()
	tw.set_parallel(true)
	tw.tween_property(arc, "width", 0.0, 0.2).set_ease(Tween.EASE_IN)
	tw.tween_property(arc, "modulate:a", 0.0, 0.22)
	tw.chain().tween_callback(arc.queue_free)

	# Spark particles alongside
	for i in range(5):
		var p = ColorRect.new()
		p.size = Vector2(3, 3)
		p.color = Color(1.0, 0.9, 0.5, 0.9)
		p.global_position = origin + Vector2(dir * randf_range(10, 28), randf_range(-12, 12))
		p.z_index = 100
		player_node.get_parent().add_child(p)
		var tw2 = p.create_tween()
		tw2.set_parallel(true)
		tw2.tween_property(p, "global_position", p.global_position + Vector2(dir * randf_range(6, 16), randf_range(-8, 8)), 0.22)
		tw2.tween_property(p, "modulate:a", 0.0, 0.22)
		tw2.chain().tween_callback(p.queue_free)




# ─── Track Helpers ───────────────────────────────────────────────────────────
# These create smooth cubic-interpolated tracks for buttery animation.

func _pos(anim: Animation, node_name: String, keys: Array) -> void:
	var t := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(t, node_name + ":position")
	anim.track_set_interpolation_type(t, Animation.INTERPOLATION_CUBIC)
	for k in keys:
		anim.track_insert_key(t, k[0], k[1])


func _rot(anim: Animation, node_name: String, keys: Array) -> void:
	var t := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(t, node_name + ":rotation")
	anim.track_set_interpolation_type(t, Animation.INTERPOLATION_CUBIC)
	for k in keys:
		anim.track_insert_key(t, k[0], k[1])


func _zidx(anim: Animation, node_name: String, keys: Array) -> void:
	var t := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(t, node_name + ":z_index")
	anim.track_set_interpolation_type(t, Animation.INTERPOLATION_NEAREST)
	for k in keys:
		anim.track_insert_key(t, k[0], k[1])
