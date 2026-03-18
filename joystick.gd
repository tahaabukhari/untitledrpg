extends Control
## Virtual Joystick — fixed position, left-half touch zone.
## All math is done in the base panel's LOCAL coordinate space,
## so compound parent scaling (TouchControls × JOYSTICK) is handled
## automatically via get_global_transform().affine_inverse().

@onready var base: Panel = $Base
@onready var thumb: Panel = $Thumb

var joystick_active: bool = false
var base_radius: float = 150.0
var thumb_radius: float = 50.0
var touch_index: int = -1
var last_vector: Vector2 = Vector2.ZERO

signal joystick_moved(movement: Vector2)

# ─── Lifecycle ───────────────────────────────────────────────────────────────

func _ready() -> void:
	# RPG-styled joystick — dark slate base with border
	var base_style := StyleBoxFlat.new()
	base_style.bg_color = Color(0.08, 0.08, 0.12, 0.75)
	base_style.border_color = Color(0.35, 0.35, 0.5, 0.6)
	base_style.set_border_width_all(2)
	base_style.corner_radius_top_left = 999
	base_style.corner_radius_top_right = 999
	base_style.corner_radius_bottom_left = 999
	base_style.corner_radius_bottom_right = 999
	base.add_theme_stylebox_override("panel", base_style)

	# Glowing cyan thumb
	var thumb_style := StyleBoxFlat.new()
	thumb_style.bg_color = Color(0.15, 0.5, 0.65, 0.9)
	thumb_style.border_color = Color(0.3, 0.8, 1.0, 0.8)
	thumb_style.set_border_width_all(2)
	thumb_style.corner_radius_top_left = 999
	thumb_style.corner_radius_top_right = 999
	thumb_style.corner_radius_bottom_left = 999
	thumb_style.corner_radius_bottom_right = 999
	thumb.add_theme_stylebox_override("panel", thumb_style)

	base.custom_minimum_size = Vector2(base_radius * 2, base_radius * 2)
	thumb.custom_minimum_size = Vector2(thumb_radius * 2, thumb_radius * 2)
	base.size = base.custom_minimum_size
	thumb.size = thumb.custom_minimum_size
	base.show()
	_reset_thumb()

# ─── Local-space Helpers ─────────────────────────────────────────────────────

func _screen_to_base_local(screen_pos: Vector2) -> Vector2:
	## Convert a screen-space touch position into the base panel's local coords.
	## Using _with_canvas() ensures that camera zoom/movement does not break mapping.
	return base.get_global_transform_with_canvas().affine_inverse() * screen_pos

func _reset_thumb() -> void:
	thumb.position = (base.size / 2.0) - (thumb.size / 2.0)

# ─── Joystick Update (local-space) ──────────────────────────────────────────

func _update_joystick(screen_pos: Vector2) -> void:
	var local_touch: Vector2 = _screen_to_base_local(screen_pos)
	var local_center: Vector2 = base.size / 2.0
	var vector: Vector2 = local_touch - local_center
	var clamped_length: float = min(vector.length(), base_radius)

	if vector.length() > 0.0:
		last_vector = vector.normalized()
	else:
		last_vector = Vector2.ZERO

	# Move the thumb (all in local coords — no scaling issues)
	var thumb_offset: Vector2 = last_vector * clamped_length
	thumb.position = thumb_offset + local_center - (thumb.size / 2.0)

	# Emit a normalized movement vector (magnitude 0.0 – 1.0)
	emit_signal("joystick_moved", last_vector * (clamped_length / base_radius))

# ─── Touch End ───────────────────────────────────────────────────────────────

func _end_touch() -> void:
	touch_index = -1
	joystick_active = false
	_reset_thumb()
	last_vector = Vector2.ZERO
	emit_signal("joystick_moved", Vector2.ZERO)

# ─── Input Handling ──────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	var screen_w: float = get_viewport().get_visible_rect().size.x

	# ── Screen Touch ─────────────────────────────────────────────────────
	if event is InputEventScreenTouch:
		if event.pressed:
			# Activate only on left-half touches when no touch is tracked
			if touch_index == -1 and event.position.x < screen_w * 0.5:
				touch_index = event.index
				joystick_active = true
				_update_joystick(event.position)
		else:
			# ALWAYS release if this is our tracked finger — even if the
			# finger slid to the right half of the screen.
			if event.index == touch_index:
				_end_touch()

	# ── Screen Drag ──────────────────────────────────────────────────────
	elif event is InputEventScreenDrag:
		if event.index == touch_index and joystick_active:
			_update_joystick(event.position)

	# ── Mouse fallback (desktop testing) ─────────────────────────────────
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if not joystick_active and event.position.x < screen_w * 0.5:
				touch_index = 0
				joystick_active = true
				_update_joystick(event.position)
		else:
			if joystick_active:
				_end_touch()

	elif event is InputEventMouseMotion and joystick_active:
		_update_joystick(event.position)

# ─── Public API ──────────────────────────────────────────────────────────────

func get_attack_direction() -> Vector2:
	## Returns the current joystick direction for 8-directional aiming.
	if last_vector.length() < 0.3:
		return Vector2.ZERO
	return last_vector.normalized()
