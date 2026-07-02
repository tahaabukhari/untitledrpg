extends Node
class_name PlayerInput
## Unified input layer — merges the virtual joystick / touch buttons and
## keyboard+mouse into ONE canonical stream the player consumes.
## The playercontroller never reads raw input sources directly; it only
## listens to this node's signals and queries get_aim_vector().
##
## Mode rules:
## - Starts in TOUCH mode (touch controls visible, mouse acts as emulated touch).
## - Any physical KEY press switches to KBM mode (touch buttons hide, mouse
##   becomes attack/parry + aim).
## - Any real (non-emulated) screen touch switches back to TOUCH mode.

signal move_changed(move_vector: Vector2)
signal jump_pressed
signal dodge_pressed
signal parry_pressed
signal interact_pressed
signal attack_pressed
signal attack_released(charge_level: float)
signal inventory_toggle_pressed
signal profile_toggle_pressed

enum Mode { TOUCH, KBM }
enum ChargeSource { NONE, RING, ACTION }

var mode: int = Mode.TOUCH

## Continuous charge state (0.0 .. 1.0). Set charge_time from the equipped weapon.
var charge_time: float = 1.0
var charge_level: float = 0.0
var is_charging: bool = false
var _charge_source: int = ChargeSource.NONE

var _player: CharacterBody2D = null
var _joystick: Control = null
var _attack_ring: Control = null
var _touch_controls: Control = null
var _pause_menu: Panel = null

var _joystick_vector := Vector2.ZERO
var _last_emitted_move := Vector2.ZERO
var _force_move_emit := false

const TOUCH_BUTTON_NAMES: Array[String] = ["JOYSTICK", "AttackButton", "JumpButton", "EvadeButton", "PauseButton"]


func _ready() -> void:
	# Keep receiving input while the tree is paused so Esc can unpause.
	process_mode = Node.PROCESS_MODE_ALWAYS


func setup(player: CharacterBody2D, joystick: Control, attack_ring: Control, touch_controls: Control) -> void:
	_player = player
	_joystick = joystick
	_attack_ring = attack_ring
	_touch_controls = touch_controls
	if _touch_controls:
		_pause_menu = _touch_controls.get_node_or_null("PAUSEMENU") as Panel
	if _joystick and _joystick.has_signal("joystick_moved"):
		_joystick.joystick_moved.connect(_on_joystick_moved)
	if _attack_ring:
		if _attack_ring.has_signal("attack_pressed"):
			_attack_ring.attack_pressed.connect(_on_ring_pressed)
		if _attack_ring.has_signal("attack_released"):
			_attack_ring.attack_released.connect(_on_ring_released)


# ─── Per-frame processing ────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if get_tree().paused:
		return

	# Movement: keyboard vector in KBM mode, virtual joystick in TOUCH mode.
	var v: Vector2
	if mode == Mode.KBM:
		v = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	else:
		v = _joystick_vector
	if v != _last_emitted_move or _force_move_emit:
		_force_move_emit = false
		_last_emitted_move = v
		move_changed.emit(v)

	# Jump — edge triggered; ui_accept kept working alongside the new action.
	if Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("ui_accept"):
		jump_pressed.emit()

	# Continuous charge accumulation while the attack input is held.
	if is_charging:
		charge_level = minf(charge_level + delta / maxf(charge_time, 0.05), 1.0)
		if _attack_ring and _attack_ring.has_method("set_charge"):
			_attack_ring.set_charge(charge_level)
		# Safety: if the action-driven release was consumed by GUI, poll it.
		if _charge_source == ChargeSource.ACTION and not Input.is_action_pressed("attack"):
			_release_charge()


# ─── Event handling ──────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	# Mode switching
	if event is InputEventKey and event.pressed and not event.echo:
		_set_mode(Mode.KBM)
	elif event is InputEventScreenTouch and event.pressed \
			and event.device != InputEvent.DEVICE_ID_EMULATION:
		_set_mode(Mode.TOUCH)

	# Pause works even while paused (toggles the pause menu).
	if event.is_action_pressed("pause"):
		_toggle_pause_menu()
		return
	if get_tree().paused:
		return

	# In TOUCH mode, mouse buttons stay emulated-touch only (the on-screen ring
	# handles them) — otherwise one click would fire both paths.
	if event.is_action_pressed("attack"):
		if not _mouse_gated(event):
			_begin_charge(ChargeSource.ACTION)
	elif event.is_action_released("attack"):
		if not _mouse_gated(event) and _charge_source == ChargeSource.ACTION:
			_release_charge()
	elif event.is_action_pressed("dodge"):
		if not _mouse_gated(event):
			dodge_pressed.emit()
	elif event.is_action_pressed("parry"):
		if not _mouse_gated(event):
			parry_pressed.emit()
	elif event.is_action_pressed("interact"):
		interact_pressed.emit()
	elif event.is_action_pressed("open_inventory"):
		inventory_toggle_pressed.emit()
	elif event.is_action_pressed("open_profile"):
		profile_toggle_pressed.emit()


func _mouse_gated(event: InputEvent) -> bool:
	## Mouse-button events only count as combat input in KBM mode.
	return event is InputEventMouseButton and mode != Mode.KBM


# ─── Charge handling (shared by ring + keyboard/mouse) ───────────────────────

func _begin_charge(source: int) -> void:
	if is_charging:
		return
	is_charging = true
	charge_level = 0.0
	_charge_source = source
	attack_pressed.emit()


func _release_charge() -> void:
	if not is_charging:
		return
	is_charging = false
	_charge_source = ChargeSource.NONE
	var level := charge_level
	charge_level = 0.0
	if _attack_ring and _attack_ring.has_method("set_charge"):
		_attack_ring.set_charge(0.0)
	attack_released.emit(level)


func _on_ring_pressed() -> void:
	_begin_charge(ChargeSource.RING)


func _on_ring_released() -> void:
	if _charge_source == ChargeSource.RING:
		_release_charge()


# ─── Touch source feeds ──────────────────────────────────────────────────────

func _on_joystick_moved(movement: Vector2) -> void:
	_joystick_vector = movement


# ─── Aiming ──────────────────────────────────────────────────────────────────

func get_aim_vector() -> Vector2:
	## 8-dir-capable aim: mouse direction in KBM mode, joystick direction on touch.
	## Returns ZERO when there is no meaningful aim (caller falls back to facing).
	if mode == Mode.KBM and _player:
		var to_mouse: Vector2 = _player.get_global_mouse_position() - _player.global_position
		if to_mouse.length() > 4.0:
			return to_mouse.normalized()
		return Vector2.ZERO
	if _joystick and _joystick.has_method("get_attack_direction"):
		return _joystick.get_attack_direction()
	return Vector2.ZERO


# ─── Mode / touch-control visibility ─────────────────────────────────────────

func _set_mode(new_mode: int) -> void:
	if mode == new_mode:
		return
	mode = new_mode
	_force_move_emit = true
	refresh_touch_visibility()


func refresh_touch_visibility() -> void:
	## Show/hide the on-screen buttons to match the current mode.
	## (PAUSEMENU is intentionally left alone — it must stay reachable.)
	if not _touch_controls:
		return
	var show_touch := mode == Mode.TOUCH
	for node_name in TOUCH_BUTTON_NAMES:
		var n := _touch_controls.get_node_or_null(node_name)
		if n:
			n.visible = show_touch
	if _joystick:
		_joystick.set_process_input(show_touch)
		if not show_touch and _joystick.has_method("_end_touch"):
			_joystick._end_touch()


# ─── Pause menu ──────────────────────────────────────────────────────────────

func _toggle_pause_menu() -> void:
	if not _pause_menu:
		return
	if get_tree().paused:
		if _pause_menu.has_method("_close_menu"):
			_pause_menu._close_menu()
	else:
		if _pause_menu.has_method("_on_pause_button_pressed"):
			_pause_menu._on_pause_button_pressed()
