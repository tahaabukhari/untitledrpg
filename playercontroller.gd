extends CharacterBody2D

const SPEED = 350.0
const JUMP_VELOCITY = -400.0
const DASH_VELOCITY = 2000.0
const DASH_TIME = 0.02
const DASH_COOLDOWN = 0.5
const ATTACK_TEXT_TIME = 0.5

@onready var joystick = $TouchControls/JOYSTICK
@onready var attack_button = $TouchControls/AttackButton
@onready var evade_button = $TouchControls/EvadeButton
@onready var camera = %Camera
@onready var attack_label = $AttackDirection
@onready var player_skin = $PlayerSkin
@onready var ground_ray: RayCast2D = $GroundRay
@onready var input_ctrl: PlayerInput = $PlayerInput

var player_hud: Control = null
var profile_ui = null
var inventory_ui = null

var max_health := 100
var health := 100

var max_stamina := 100
var stamina := 100

var defense := 5
var max_mana := 100
var mana := 0
var current_class := "Warrior"

const DASH_COST := 33

var can_double_jump := false
var double_jump_lockout := 0.0
const DOUBLE_JUMP_COST := 20
var jump_count := 0

const STAMINA_REGEN_RATE := 7.0 # 7 per second
var stamina_regen_time_accum := 0.0
var stamina_regen_paused := false

var joystick_vector := Vector2.ZERO
var facing := 1
var attack_text_timer := 0.0

var dash_timer := 0.0
var dash_cooldown := 0.0
var is_dashing := false
var dash_direction := Vector2.ZERO
var fall_timer := 0.0
const LONG_FALL_THRESHOLD := 2.0  # seconds before switching to long_fall anim

# Combat — driven by equipped weapon
@export var equipped_weapon: WeaponData = preload("res://weapons/weapon_fists.tres")
var is_attacking := false
var attack_cooldown_timer := 0.0
var hit_enemies_this_swing: Array = []
var current_attack_knockback := 0.0

# Level, EXP, and Identity system
var player_name := "Player"
var player_title := "Novice"
var player_uuid := "1A2B-3C4D"
var level := 1
var exp_val := 0.0
var max_exp := 100.0

# Base Stats & Progression
var stat_points := 4
var stat_def := 0
var stat_atk := 0
var stat_evasion := 0

# Saturation system
var saturation := 100.0
const SAT_MOVE_COST := 0.003  # per 10 meters (reduced 70%)
const SAT_ACTION_COST := 0.03  # per attack/jump/evade (reduced 70%)
const SAT_REGEN_THRESHOLD := 60.0  # HP regen only when saturation > 60%
const HP_REGEN_RATE := 1.0  # 1 HP per second when saturation > threshold
var distance_accumulator := 0.0
var hp_regen_accum := 0.0

func _ready():
	add_to_group("player")
	if not evade_button.pressed.is_connected(_on_evade_button_pressed):
		evade_button.pressed.connect(_on_evade_button_pressed)
	attack_label.text = ""
	attack_label.visible = false

	# Unified input layer — touch and keyboard/mouse both route through it
	input_ctrl.setup(self, joystick, $TouchControls/AttackButton/RingUI, $TouchControls)
	input_ctrl.move_changed.connect(_on_move_input)
	input_ctrl.jump_pressed.connect(_on_jump_input)
	input_ctrl.dodge_pressed.connect(_on_evade_button_pressed)
	input_ctrl.parry_pressed.connect(_on_parry_pressed)
	input_ctrl.attack_released.connect(_on_attack_released)
	input_ctrl.inventory_toggle_pressed.connect(_on_inv_button_pressed)
	input_ctrl.profile_toggle_pressed.connect(_toggle_profile)
	input_ctrl.charge_time = equipped_weapon.charge_time

	# Wire attack hitbox detection
	if player_skin:
		var hitbox = player_skin.get_node_or_null("AttackHitbox")
		if hitbox:
			hitbox.body_entered.connect(_on_attack_hit)
		player_skin.attack_finished.connect(_on_attack_finished)
	
	# Load class stats from Global Autoload
	var stats = Global.get_current_class_stats()
	current_class = Global.current_class
	
	# Apply stats (Scaling them up slightly for the actual game bars logic)
	max_health = stats["hp"] * 10
	health = max_health
	max_stamina = stats["sta"] * 10
	stamina = max_stamina
	defense = stats["def"]
	max_mana = stats["mana"] * 10
	mana = max_mana
	
	# Setup the new PlayerHUD via CanvasLayer
	player_hud = $HUDLayer/PlayerHUD
	if player_hud:
		player_hud.set_immediate(health, max_health, stamina, max_stamina, mana, max_mana, current_class, saturation, exp_val, max_exp, level)
		player_hud.inv_button_pressed.connect(_on_inv_button_pressed)
		player_hud.profile_button_pressed.connect(_toggle_profile)
	
	# Setup the Inventory UI
	inventory_ui = $HUDLayer/InventoryUI
	if inventory_ui:
		inventory_ui.inventory_closed.connect(_on_inventory_closed)
		if inventory_ui.has_signal("weapon_equipped"):
			inventory_ui.weapon_equipped.connect(_on_weapon_equipped)
		if inventory_ui.has_signal("weapon_unequipped"):
			inventory_ui.weapon_unequipped.connect(_on_weapon_unequipped)
	
	# Style the touch buttons with RPG theme
	var pixel_font = load("res://fonts/PressStart2P.ttf")
	var TouchStyle = load("res://touch_button_style.gd")
	
	var atk_vis = get_node_or_null("TouchControls/AttackButton/Button")
	if atk_vis:
		TouchStyle.apply(atk_vis, "attack", pixel_font)

	var jump_vis = get_node_or_null("TouchControls/JumpButton/Button")
	if jump_vis:
		TouchStyle.apply(jump_vis, "jump", pixel_font)

	var evade_vis = get_node_or_null("TouchControls/EvadeButton/Button")
	if evade_vis:
		TouchStyle.apply(evade_vis, "evade", pixel_font)

	var pause_vis = get_node_or_null("TouchControls/PauseButton/Button")
	if pause_vis:
		TouchStyle.apply(pause_vis, "pause", pixel_font)

func _on_inv_button_pressed():
	if inventory_ui:
		if inventory_ui.is_open:
			inventory_ui.close_inventory()
		else:
			inventory_ui.open_inventory()
			_disable_touch_controls()

func open_inventory() -> void:
	if profile_ui != null:
		close_profile()
		
	if inventory_ui == null:
		print("Error: Inventory UI reference is null in PlayerController! It may need to be instantiated via script if it's not pre-existing in the scene.")

func close_inventory() -> void:
	if inventory_ui != null and inventory_ui.has_method("close_inventory"):
		inventory_ui.close_inventory()

func _toggle_profile() -> void:
	if profile_ui == null:
		open_profile()
	else:
		close_profile()

func open_profile() -> void:
	if inventory_ui != null and inventory_ui.is_open:
		if inventory_ui.has_method("close_inventory"):
			inventory_ui.close_inventory()
	
	if profile_ui == null:
		var profile_scene = load("res://player_profile_ui.tscn")
		if profile_scene:
			profile_ui = profile_scene.instantiate()
			$HUDLayer.add_child(profile_ui)

func close_profile() -> void:
	if profile_ui != null:
		if profile_ui.has_method("close"):
			profile_ui.close()
		else:
			profile_ui.queue_free()
		profile_ui = null

func _on_inventory_closed():
	_enable_touch_controls()


func _disable_touch_controls() -> void:
	var tc = $TouchControls
	if tc:
		tc.visible = false
		tc.set_process_input(false)
	if joystick:
		joystick.set_process_input(false)
		joystick._end_touch()

func _enable_touch_controls() -> void:
	var tc = $TouchControls
	if tc:
		tc.visible = true
		tc.set_process_input(true)
	if joystick:
		joystick.set_process_input(true)
	# Respect the current input mode (KBM keeps the buttons hidden)
	if input_ctrl:
		input_ctrl.refresh_touch_visibility()

func _on_move_input(movement: Vector2):
	joystick_vector = movement
	if abs(movement.x) > 0.1:
		facing = sign(movement.x)
		if player_skin:
			player_skin.scale.x = abs(player_skin.scale.x) * facing


func _on_jump_input() -> void:
	if _gameplay_blocked():
		return
	_perform_jump()


func _on_parry_pressed() -> void:
	# Parry lands in Phase 3 — wired now so the input layer stays stable.
	pass


func _on_attack_released(charge_level: float) -> void:
	if _gameplay_blocked():
		return
	if charge_level >= 1.0:
		_on_attack_charged()
	else:
		_on_attack_button_pressed()


func _gameplay_blocked() -> bool:
	## Combat/movement input is ignored while menus are open.
	if inventory_ui != null and inventory_ui.is_open:
		return true
	if profile_ui != null:
		return true
	return false

func _perform_jump() -> void:
	## Single jump path shared by keyboard and the touch jump button.
	stamina_regen_paused = true
	if is_on_floor():
		velocity.y = JUMP_VELOCITY
		jump_count = 1
		can_double_jump = true
		saturation = max(saturation - SAT_ACTION_COST, 0.0)
	elif can_wall_jump() and stamina >= DOUBLE_JUMP_COST:
		velocity.y = JUMP_VELOCITY
		var wall_push := get_wall_push_direction()
		if wall_push != 0:
			velocity.x = wall_push * SPEED
		stamina -= DOUBLE_JUMP_COST
		jump_count = 2
		can_double_jump = false
		double_jump_lockout = 1.0
		saturation = max(saturation - SAT_ACTION_COST, 0.0)
	elif can_double_jump and jump_count == 1 and stamina >= DOUBLE_JUMP_COST and touching_wall_vertically():
		velocity.y = JUMP_VELOCITY
		stamina -= DOUBLE_JUMP_COST
		jump_count = 2
		can_double_jump = false
		double_jump_lockout = 1.0
		saturation = max(saturation - SAT_ACTION_COST, 0.0)


func _physics_process(delta: float) -> void:
	stamina_regen_paused = false

	# Dash logic
	if is_dashing:
		stamina_regen_paused = true
		dash_timer -= delta
		velocity = dash_direction * DASH_VELOCITY
		move_and_slide()
		if dash_timer <= 0.0:
			is_dashing = false
		update_bars()
		return

	if dash_cooldown > 0.0:
		dash_cooldown -= delta

	# Wall sliding logic: reduce falling speed by 30% only if has stamina
	var is_wall_slide := false
	if is_on_wall() and not is_on_floor() and velocity.y > 0 and stamina > 0.0:
		velocity.y *= 0.7
		is_wall_slide = true
		stamina_regen_paused = true
	# Prevent wall sliding across wall if no stamina
	if is_on_wall() and not is_on_floor() and stamina <= 0.0:
		velocity.x = 0

	# Add gravity
	if not is_on_floor():
		velocity.y += ProjectSettings.get_setting("physics/2d/default_gravity") * delta

	# Double Jump Lockout
	if double_jump_lockout > 0.0:
		double_jump_lockout -= delta
		if double_jump_lockout <= 0:
			double_jump_lockout = 0
			can_double_jump = false

	# (Jump input arrives via the PlayerInput layer → _on_jump_input)

	# Left/right movement via joystick
	if abs(joystick_vector.x) > 0.1:
		velocity.x = joystick_vector.x * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
	move_and_slide()

	# Hide attack text after timer
	if attack_text_timer > 0:
		attack_text_timer -= delta
		if attack_text_timer <= 0:
			attack_label.visible = false

	# Pause stamina regen during attacks, jumps, wallslide, dash
	if is_wall_slide:
		stamina_regen_paused = true

	# Stamina Regen (discrete 7 per second, only if not paused)
	if not stamina_regen_paused:
		stamina_regen_time_accum += delta
		while stamina_regen_time_accum >= 1.0:
			stamina_regen_time_accum -= 1.0
			if stamina < max_stamina:
				stamina += STAMINA_REGEN_RATE
				if stamina > max_stamina:
					stamina = max_stamina
	else:
		stamina_regen_time_accum = 0.0

	# Saturation-based HP regeneration (1 HP/sec when saturation > 60%)
	if saturation > SAT_REGEN_THRESHOLD and health < max_health:
		hp_regen_accum += delta
		while hp_regen_accum >= 1.0:
			hp_regen_accum -= 1.0
			health = min(health + HP_REGEN_RATE, max_health)
	else:
		hp_regen_accum = 0.0

	# Track distance moved for saturation depletion
	var move_speed = abs(velocity.x) + abs(velocity.y)
	if move_speed > 10.0:
		distance_accumulator += move_speed * delta
		# Every 10 pixels (~1 meter), deplete 0.01% saturation
		while distance_accumulator >= 10.0:
			distance_accumulator -= 10.0
			saturation = max(saturation - SAT_MOVE_COST, 0.0)

	update_bars()

	# ── Animation state ──────────────────────────────────────────────────
	if attack_cooldown_timer > 0.0:
		attack_cooldown_timer -= delta
	if player_skin and player_skin.has_method("play_state") and not is_attacking:
		if not is_on_floor() and velocity.y < 0:
			fall_timer = 0.0
			player_skin.play_state("jump")
		elif not is_on_floor() and velocity.y >= 0:
			fall_timer += delta
			var ground_dist := _get_ground_distance()
			if ground_dist > 300.0:
				player_skin.play_state("long_fall")
			else:
				player_skin.play_state("fall")
		elif is_on_floor():
			# Reset rotation when landing (long_fall rotates the skin)
			if fall_timer > 0.0 and player_skin:
				player_skin.rotation = 0.0
			fall_timer = 0.0
			if is_dashing:
				player_skin.play_state("run")
			elif abs(joystick_vector.x) > 0.6:
				player_skin.play_state("run")
			elif abs(joystick_vector.x) > 0.1:
				player_skin.play_state("walk")
			else:
				player_skin.play_state("idle")


func _get_ground_distance() -> float:
	## Returns pixel distance to the ground below, or 9999 if no ground detected.
	if not ground_ray or not ground_ray.is_colliding():
		return 9999.0
	var ground_point := ground_ray.get_collision_point()
	var dist := ground_point.y - global_position.y
	return maxf(dist, 0.0)

func touching_wall_vertically() -> bool:
	for i in get_slide_collision_count():
		var col = get_slide_collision(i)
		var normal = col.get_normal()
		if abs(normal.x) > 0.7 and abs(normal.y) < 0.3 and col.get_collider() is PhysicsBody2D:
			return true
	return false

func allocate_stat(stat_name: String) -> void:
	if stat_points <= 0:
		return
	stat_points -= 1
	match stat_name:
		"HP": max_health += 10.0; health += 10.0
		"MP": max_mana += 5.0; mana += 5.0
		"STA": max_stamina += 5.0; stamina += 5.0
		"ATK": stat_atk += 1
		"DEF": stat_def += 1
		"EVA": stat_evasion += 1
	update_bars()

func add_exp(amount: float) -> void:
	exp_val += amount
	while exp_val >= max_exp:
		exp_val -= max_exp
		level += 1
		stat_points += 4
		max_exp = 100.0 * pow(2.0, level - 1)
		# Refill stats on level up
		health = max_health
		stamina = max_stamina
		mana = max_mana
		saturation = 100.0
	update_bars()

func update_bars():
	health = clamp(health, 0, max_health)
	stamina = clamp(stamina, 0, max_stamina)
	mana = clamp(mana, 0, max_mana)
	saturation = clamp(saturation, 0.0, 100.0)
	if player_hud:
		player_hud.update_hud(health, max_health, stamina, max_stamina, mana, max_mana, current_class, saturation, exp_val, max_exp, level)

func can_wall_jump() -> bool:
	if is_on_floor():
		return false
	for i in get_slide_collision_count():
		var col = get_slide_collision(i)
		var normal = col.get_normal()
		if abs(normal.x) > 0.7 and col.get_collider() is PhysicsBody2D and normal.y == 0:
			return true
	return false

func get_wall_push_direction() -> int:
	for i in get_slide_collision_count():
		var col = get_slide_collision(i)
		var normal = col.get_normal()
		if abs(normal.x) > 0.7 and col.get_collider() is PhysicsBody2D and normal.y == 0:
			return int(normal.x)
	return 0

func _on_attack_button_pressed() -> void:
	if is_attacking or attack_cooldown_timer > 0.0:
		return
	if equipped_weapon.stamina_cost > 0 and stamina < equipped_weapon.stamina_cost:
		return
	stamina_regen_paused = true
	if equipped_weapon.stamina_cost > 0:
		stamina = max(stamina - equipped_weapon.stamina_cost, 0)
	saturation = max(saturation - SAT_ACTION_COST, 0.0)
	is_attacking = true
	hit_enemies_this_swing.clear()
	current_attack_knockback = 0.0
	var dir = joystick_vector.normalized()
	if dir.length() < 0.3:
		dir = Vector2(facing, 0)
	var text = get_direction_name(dir)
	attack_label.text = text
	attack_label.visible = true
	attack_text_timer = ATTACK_TEXT_TIME
	if player_skin and player_skin.has_method("play_attack"):
		player_skin.play_attack()


func _on_attack_charged() -> void:
	if is_attacking:
		return
	if stamina < equipped_weapon.charged_stamina_cost:
		return  # not enough stamina
	stamina_regen_paused = true
	stamina = max(stamina - equipped_weapon.charged_stamina_cost, 0)
	saturation = max(saturation - SAT_ACTION_COST * 3, 0.0)
	is_attacking = true
	hit_enemies_this_swing.clear()
	current_attack_knockback = equipped_weapon.charged_knockback
	attack_label.text = equipped_weapon.charged_anim.to_upper().replace("_", " ")
	attack_label.visible = true
	attack_text_timer = ATTACK_TEXT_TIME * 2
	if player_skin and player_skin.has_method("play_uppercut"):
		player_skin.play_uppercut()


# ─── Weapon Equipping ────────────────────────────────────────────────────────

const DEFAULT_WEAPON: WeaponData = preload("res://weapons/weapon_fists.tres")

func _on_weapon_equipped(weapon: WeaponData) -> void:
	equipped_weapon = weapon
	if input_ctrl:
		input_ctrl.charge_time = weapon.charge_time
	if player_skin and player_skin.has_method("equip_weapon_visual"):
		player_skin.equip_weapon_visual(weapon)

func _on_weapon_unequipped() -> void:
	equipped_weapon = DEFAULT_WEAPON
	if input_ctrl:
		input_ctrl.charge_time = DEFAULT_WEAPON.charge_time
	if player_skin and player_skin.has_method("unequip_weapon_visual"):
		player_skin.unequip_weapon_visual()


func _on_attack_finished() -> void:
	is_attacking = false
	attack_cooldown_timer = equipped_weapon.attack_cooldown


func trigger_weapon_dash(strength: float) -> void:
	## Called by weapon animations to apply a forward velocity boost (e.g. sword thrust).
	velocity.x = facing * strength


func _on_attack_hit(body: Node2D) -> void:
	if body.is_in_group("enemy") and body not in hit_enemies_this_swing:
		hit_enemies_this_swing.append(body)
		var dmg: int
		if current_attack_knockback > 0:
			dmg = equipped_weapon.charged_damage
		else:
			dmg = equipped_weapon.calc_damage(stat_atk)
		var kb_dir := Vector2(facing, -0.3).normalized()
		if body.has_method("take_damage"):
			body.take_damage(dmg, kb_dir * current_attack_knockback)
		Fx.hit_particles(body.global_position)


func calc_attack_damage() -> int:
	return equipped_weapon.calc_damage(stat_atk)


func _on_jump_button_pressed() -> void:
	_perform_jump()

func _on_evade_button_pressed() -> void:
	stamina_regen_paused = true
	saturation = max(saturation - SAT_ACTION_COST, 0.0)
	if dash_cooldown > 0.0 or is_dashing:
		return
	if stamina < DASH_COST:
		return

	var dash_vec = joystick_vector
	if dash_vec.length() < 0.2:
		dash_vec = Vector2(-facing, 0)
	else:
		dash_vec = -dash_vec.normalized()
	dash_direction = dash_vec
	is_dashing = true
	dash_timer = DASH_TIME
	dash_cooldown = DASH_COOLDOWN

	stamina -= DASH_COST

func get_direction_name(vec: Vector2) -> String:
	if vec.length() < 0.3:
		if facing > 0:
			return "Forward"
		else:
			return "Behind"
	if vec.y < -0.7:
		if vec.x < -0.3:
			return "Top Left"
		elif vec.x > 0.3:
			return "Top Right"
		else:
			return "Top"
	elif vec.y > 0.7:
		if vec.x < -0.3:
			return "Bottom Left"
		elif vec.x > 0.3:
			return "Bottom Right"
		else:
			return "Bottom"
	else:
		if (facing > 0 and vec.x > 0) or (facing < 0 and vec.x < 0):
			return "Forward"
		else:
			return "Behind"
