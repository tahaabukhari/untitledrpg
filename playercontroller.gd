extends CharacterBody2D

const SPEED = 350.0
const JUMP_VELOCITY = -400.0
const ATTACK_TEXT_TIME = 0.5

# Dodge roll (replaces the old reversed evade dash)
const ROLL_SPEED := 480.0
const ROLL_TIME := 0.35
const ROLL_COOLDOWN := 0.6
const ROLL_COST := 25

# Parry
const PARRY_WINDOW := 0.2
const PARRY_RECOVERY := 0.25
const PARRY_COOLDOWN := 0.5
const PARRY_COST := 10

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

# Dodge roll state
var is_rolling := false
var roll_timer := 0.0
var roll_cooldown := 0.0
var roll_direction := 1

# Parry state
var is_parrying := false
var parry_timer := 0.0
var parry_recovery_timer := 0.0
var parry_cooldown_timer := 0.0

var fall_timer := 0.0
const LONG_FALL_THRESHOLD := 2.0  # seconds before switching to long_fall anim

# Combat — driven by equipped weapon
@export var equipped_weapon: WeaponData = preload("res://weapons/weapon_fists.tres")
var is_attacking := false
var attack_cooldown_timer := 0.0
var hit_enemies_this_swing: Array = []
var current_attack_knockback := 0.0

# Hurt / death state
var invuln_timer := 0.0        # i-frames (hurt recovery, dodge roll, etc.)
var is_hurt := false           # brief hitstun — movement input suppressed
var hurt_timer := 0.0
var is_dead := false
const HURT_TIME := 0.25
const HURT_IFRAMES := 0.8

# Ranged / laser / charge-telegraph state
var _attack_aim := Vector2.RIGHT     # aim captured when the attack starts
var _charged_shot := false           # bow: charged release fires a heavier arrow
var _charge_orb: Polygon2D = null    # growing laser-charge telegraph on the staff

# Grabbed / thrown state (boss grab-and-throw)
var is_grabbed := false
var _grabber: Node2D = null
var _thrown := false                 # airborne after a throw — landing hurts
var _throw_landing_damage := 0

# Mana regeneration
const MANA_REGEN_RATE := 4.0  # per second
var mana_regen_accum := 0.0

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

	# Auto-equip the class starter weapon
	var starter_path: String = Global.get_starter_weapon_path()
	if starter_path != "":
		var starter: WeaponData = load(starter_path)
		if starter:
			_on_weapon_equipped(starter)
	
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
	_perform_parry()


func _on_attack_released(charge_level: float) -> void:
	if _gameplay_blocked():
		return
	# Laser weapons: any meaningful hold fires a charge-scaled beam;
	# a bare tap stays a normal melee poke.
	if equipped_weapon.charged_style == "laser" and charge_level >= 0.15:
		_fire_laser(charge_level)
		return
	if charge_level >= 1.0:
		_on_attack_charged()
	else:
		_on_attack_button_pressed()


func _gameplay_blocked() -> bool:
	## Combat/movement input is ignored while menus are open, dead, or in hitstun.
	if is_dead or is_hurt:
		return true
	if inventory_ui != null and inventory_ui.is_open:
		return true
	if profile_ui != null:
		return true
	return false

func _perform_jump() -> void:
	## Single jump path shared by keyboard and the touch jump button.
	if is_rolling or is_parrying or is_dead:
		return
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
	# Dead: gravity only, no input
	if is_dead:
		if not is_on_floor():
			velocity.y += ProjectSettings.get_setting("physics/2d/default_gravity") * delta
		velocity.x = move_toward(velocity.x, 0, SPEED * delta * 4.0)
		move_and_slide()
		return

	# Grabbed: the grabber owns our position until we're thrown
	if is_grabbed:
		velocity = Vector2.ZERO
		if _grabber == null or not is_instance_valid(_grabber):
			is_grabbed = false
		return

	# Thrown: landing hurts (airtime damage of the boss grab-and-throw)
	if _thrown and is_on_floor():
		_thrown = false
		if _throw_landing_damage > 0 and not is_dead:
			health -= _throw_landing_damage
			Fx.damage_number(global_position, _throw_landing_damage, Fx.PLAYER_DAMAGE_COLOR)
			Fx.hit_particles(global_position + Vector2(0, 20), Color(0.8, 0.5, 0.3))
			_flash_skin(Color(1, 0.25, 0.25))
			_screen_shake(4.0)
			update_bars()
			if health <= 0:
				die()

	stamina_regen_paused = false

	# Timers: i-frames + hitstun
	if invuln_timer > 0.0:
		invuln_timer -= delta
	if is_hurt:
		hurt_timer -= delta
		if hurt_timer <= 0.0:
			is_hurt = false

	# Parry timers
	if is_parrying:
		stamina_regen_paused = true
		parry_timer -= delta
		if parry_timer <= 0.0:
			is_parrying = false
			parry_recovery_timer = PARRY_RECOVERY
	elif parry_recovery_timer > 0.0:
		parry_recovery_timer -= delta
	if parry_cooldown_timer > 0.0:
		parry_cooldown_timer -= delta

	# Dodge roll: roll-driven movement, i-frames handled via invuln_timer
	if is_rolling:
		stamina_regen_paused = true
		roll_timer -= delta
		velocity.x = roll_direction * ROLL_SPEED
		if not is_on_floor():
			velocity.y += ProjectSettings.get_setting("physics/2d/default_gravity") * delta
		move_and_slide()
		if roll_timer <= 0.0:
			is_rolling = false
			if player_skin:
				player_skin.rotation = 0.0
		update_bars()
		return

	if roll_cooldown > 0.0:
		roll_cooldown -= delta

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

	# Left/right movement via joystick (suppressed during hitstun so
	# knockback impulses aren't immediately overwritten; parry holds ground)
	if is_hurt or is_parrying or parry_recovery_timer > 0.0:
		velocity.x = move_toward(velocity.x, 0, SPEED * delta * 6.0)
	elif abs(joystick_vector.x) > 0.1:
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

	# Mana regeneration (casters need their fuel back)
	if mana < max_mana:
		mana_regen_accum += delta
		while mana_regen_accum >= 1.0:
			mana_regen_accum -= 1.0
			mana = min(mana + MANA_REGEN_RATE, max_mana)
	else:
		mana_regen_accum = 0.0

	# Laser charge telegraph (growing orb at the staff tip while charging)
	_update_charge_telegraph()

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
	if player_skin and player_skin.has_method("play_state") and not is_attacking and not is_hurt \
			and not is_parrying and parry_recovery_timer <= 0.0:
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
			if abs(joystick_vector.x) > 0.6:
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
	if is_attacking or attack_cooldown_timer > 0.0 or is_rolling or is_parrying:
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

	# 8-directional aim: mouse in KBM mode, joystick direction on touch
	var aim: Vector2 = input_ctrl.get_aim_vector() if input_ctrl else Vector2.ZERO
	if aim == Vector2.ZERO:
		aim = Vector2(facing, 0)
	# Attacks face their aim
	if absf(aim.x) > 0.15 and signf(aim.x) != facing:
		facing = int(signf(aim.x))
		if player_skin:
			player_skin.scale.x = abs(player_skin.scale.x) * facing
	_attack_aim = aim
	_charged_shot = false

	attack_label.text = get_direction_name(aim)
	attack_label.visible = true
	attack_text_timer = ATTACK_TEXT_TIME
	if player_skin and player_skin.has_method("play_attack"):
		player_skin.play_attack(aim)


func _on_attack_charged() -> void:
	if is_attacking or is_rolling or is_parrying:
		return
	# Healers channel a blessing instead of a heavy swing
	if equipped_weapon.charged_style == "heal":
		_perform_heal()
		return
	if stamina < equipped_weapon.charged_stamina_cost:
		return  # not enough stamina
	stamina_regen_paused = true
	stamina = max(stamina - equipped_weapon.charged_stamina_cost, 0)
	saturation = max(saturation - SAT_ACTION_COST * 3, 0.0)
	is_attacking = true
	hit_enemies_this_swing.clear()
	current_attack_knockback = equipped_weapon.charged_knockback
	# Ranged charged shots fire a heavier arrow from the animation's method track
	var chg_aim: Vector2 = input_ctrl.get_aim_vector() if input_ctrl else Vector2.ZERO
	_attack_aim = chg_aim if chg_aim != Vector2.ZERO else Vector2(facing, 0)
	_charged_shot = true
	attack_label.text = equipped_weapon.charged_anim.to_upper().replace("_", " ")
	attack_label.visible = true
	attack_text_timer = ATTACK_TEXT_TIME * 2
	if player_skin and player_skin.has_method("play_uppercut"):
		player_skin.play_uppercut()


# ─── Ranged / Laser / Heal actions ───────────────────────────────────────────

func fire_projectile(charged: bool = false) -> void:
	## Called from bow animation method tracks (via player_animator).
	var dmg: int = equipped_weapon.calc_damage(stat_atk)
	if charged or _charged_shot:
		dmg = equipped_weapon.charged_damage + stat_atk
	var dir := _attack_aim
	if dir == Vector2.ZERO:
		dir = Vector2(facing, 0)
	var from := global_position + Vector2(facing * 12.0, -8.0)
	var arrow := PlayerProjectile.spawn(from, dir, dmg, equipped_weapon.projectile_speed)
	if charged or _charged_shot:
		arrow.scale = Vector2(1.4, 1.4)
		arrow.modulate = Color(1.2, 1.1, 0.8)


func _fire_laser(charge_level: float) -> void:
	## SHOWCASE: charge-scaled piercing hitscan beam along the 8-dir aim.
	if is_attacking or attack_cooldown_timer > 0.0 or is_rolling or is_parrying:
		return
	var w := equipped_weapon
	var mana_cost := lerpf(6.0, w.laser_mana_cost, charge_level)
	if mana < mana_cost:
		attack_label.text = "NO MANA"
		attack_label.visible = true
		attack_text_timer = ATTACK_TEXT_TIME
		return
	mana -= mana_cost
	stamina_regen_paused = true
	saturation = max(saturation - SAT_ACTION_COST * 2, 0.0)

	# 8-way quantized aim, matching directional melee
	var aim: Vector2 = input_ctrl.get_aim_vector() if input_ctrl else Vector2.ZERO
	if aim == Vector2.ZERO:
		aim = Vector2(facing, 0)
	var oct := roundf(aim.angle() / (PI / 4.0))
	aim = Vector2.RIGHT.rotated(oct * PI / 4.0)
	if absf(aim.x) > 0.15 and signf(aim.x) != facing:
		facing = int(signf(aim.x))
		if player_skin:
			player_skin.scale.x = abs(player_skin.scale.x) * facing
	_attack_aim = aim

	# Charge-scaled damage / range / width
	var dmg: int = int(lerpf(w.laser_min_damage, w.laser_max_damage, charge_level)) + stat_atk
	var beam_range := lerpf(w.laser_min_range, w.laser_max_range, charge_level)
	var beam_width := lerpf(w.laser_min_width, w.laser_max_width, charge_level)
	var start := global_position + aim * 16.0 + Vector2(0, -8)

	# Walls stop the beam; enemies do not (piercing)
	var space := get_world_2d().direct_space_state
	var end := start + aim * beam_range
	var wall_q := PhysicsRayQueryParameters2D.create(start, end, 1)
	wall_q.exclude = [get_rid()]
	var wall_hit := space.intersect_ray(wall_q)
	if not wall_hit.is_empty():
		end = wall_hit.position

	# Pierce every enemy along the line
	var excludes: Array[RID] = [get_rid()]
	var enemy_q := PhysicsRayQueryParameters2D.create(start, end, 4)
	enemy_q.exclude = excludes
	for i in range(12):
		var hit := space.intersect_ray(enemy_q)
		if hit.is_empty():
			break
		var col: Object = hit.collider
		if col is Node and (col as Node).is_in_group("enemy") and col.has_method("take_damage"):
			col.take_damage(dmg, aim * 260.0 + Vector2(0, -60))
			Fx.hit_particles(hit.position, Color(0.7, 0.85, 1.0))
		excludes.append(hit.rid)
		enemy_q.exclude = excludes

	# Visuals + feel
	Fx.beam(start, end, beam_width)
	velocity -= aim * lerpf(40.0, 170.0, charge_level)  # recoil
	_screen_shake(lerpf(1.5, 6.0, charge_level))

	# Cast animation (staff_charged) drives the attack state/cooldown
	is_attacking = true
	hit_enemies_this_swing.clear()
	current_attack_knockback = 0.0
	attack_label.text = "ARCANE BEAM"
	attack_label.visible = true
	attack_text_timer = ATTACK_TEXT_TIME * 2
	if player_skin and player_skin.has_method("play_uppercut"):
		player_skin.play_uppercut()


func _perform_heal() -> void:
	## Healer charged action: spend mana, restore HP, green channel visuals.
	if mana < equipped_weapon.heal_mana_cost:
		attack_label.text = "NO MANA"
		attack_label.visible = true
		attack_text_timer = ATTACK_TEXT_TIME
		return
	mana -= equipped_weapon.heal_mana_cost
	health = min(health + equipped_weapon.heal_amount, max_health)
	Fx.heal_burst(global_position)
	Fx.damage_number(global_position + Vector2(0, -14), equipped_weapon.heal_amount, Color(0.4, 1.0, 0.5))
	_flash_skin(Color(0.6, 1.4, 0.7))
	update_bars()
	is_attacking = true
	attack_label.text = "MEND"
	attack_label.visible = true
	attack_text_timer = ATTACK_TEXT_TIME * 2
	if player_skin and player_skin.has_method("play_uppercut"):
		player_skin.play_uppercut()  # plays the weapon's charged_anim (wand_heal)


func _screen_shake(amplitude: float) -> void:
	if not camera:
		return
	var tw := create_tween()
	for i in range(4):
		tw.tween_property(camera, "offset",
			Vector2(randf_range(-amplitude, amplitude), randf_range(-amplitude, amplitude)), 0.04)
	tw.tween_property(camera, "offset", Vector2.ZERO, 0.06)


func _update_charge_telegraph() -> void:
	## Growing orb at the staff tip while a laser weapon is charging.
	var charging: bool = input_ctrl != null and input_ctrl.is_charging \
		and equipped_weapon.charged_style == "laser" and not is_attacking and not is_dead
	if charging:
		if _charge_orb == null or not is_instance_valid(_charge_orb):
			_charge_orb = Polygon2D.new()
			var pts := PackedVector2Array()
			for i in range(14):
				var t := TAU * float(i) / 14.0
				pts.append(Vector2(cos(t), sin(t)) * 5.0)
			_charge_orb.polygon = pts
			_charge_orb.z_index = 60
			add_child(_charge_orb)
		var lvl: float = input_ctrl.charge_level
		_charge_orb.position = Vector2(facing * 26.0, -12.0)
		_charge_orb.scale = Vector2.ONE * lerpf(0.25, 1.7, lvl)
		_charge_orb.color = Color(0.55 + 0.45 * lvl, 0.8, 1.0, 0.45 + 0.5 * lvl)
		# Full charge: subtle pulse
		if lvl >= 1.0:
			_charge_orb.scale *= 1.0 + 0.12 * sin(Time.get_ticks_msec() / 40.0)
	elif _charge_orb != null and is_instance_valid(_charge_orb):
		_charge_orb.queue_free()
		_charge_orb = null


# ─── Class switching (boss arena debug + respawn reuse) ─────────────────────

func apply_class(cls: String) -> void:
	## Re-applies class stats and equips the class starter weapon at runtime.
	Global.set_class(cls)
	current_class = cls
	var stats = Global.get_current_class_stats()
	max_health = stats["hp"] * 10
	health = max_health
	max_stamina = stats["sta"] * 10
	stamina = max_stamina
	defense = stats["def"]
	max_mana = stats["mana"] * 10
	mana = max_mana
	var starter_path: String = Global.get_starter_weapon_path()
	if starter_path != "":
		var starter: WeaponData = load(starter_path)
		if starter:
			_on_weapon_equipped(starter)
	attack_label.text = cls.to_upper()
	attack_label.visible = true
	attack_text_timer = ATTACK_TEXT_TIME * 2
	update_bars()


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


# ─── Taking Damage / Death ───────────────────────────────────────────────────

func take_damage(amount: int, source_pos: Vector2, knockback: Vector2 = Vector2.ZERO, attacker: Node = null) -> bool:
	## Called by enemy hitboxes. Returns true if damage was actually applied.
	## Respects i-frames (hurt recovery / dodge roll); parry is checked first
	## and, on success, negates the hit and staggers the attacker.
	if is_dead:
		return false
	if _try_parry(source_pos, attacker):
		return false
	if invuln_timer > 0.0:
		return false

	var mitigated: int = maxi(amount - (defense + stat_def), 1)
	health -= mitigated
	Fx.damage_number(global_position, mitigated, Fx.PLAYER_DAMAGE_COLOR)

	# Hitstun + knockback + i-frames
	is_hurt = true
	hurt_timer = HURT_TIME
	invuln_timer = HURT_IFRAMES
	is_attacking = false
	if player_skin:
		if player_skin.has_method("_disable_hitbox"):
			player_skin._disable_hitbox()  # never leave a hitbox stuck on
		if player_skin.has_method("play_hurt"):
			player_skin.play_hurt()
	if knockback.length() > 0:
		velocity = knockback
	else:
		var away: float = signf(global_position.x - source_pos.x)
		velocity = Vector2((away if away != 0.0 else -facing) * 220.0, -160.0)
	_flash_skin(Color(1, 0.25, 0.25))
	update_bars()

	if health <= 0:
		die()
	return true


# ─── Grab-and-throw (boss) ───────────────────────────────────────────────────

func begin_grabbed(grabber: Node2D) -> void:
	## Seized by a boss grab: control is suspended; the grabber moves us.
	is_grabbed = true
	_grabber = grabber
	is_attacking = false
	is_rolling = false
	is_parrying = false
	velocity = Vector2.ZERO
	if player_skin and player_skin.has_method("_disable_hitbox"):
		player_skin._disable_hitbox()
	if player_skin and player_skin.has_method("play_hurt"):
		player_skin.play_hurt()


func update_grabbed(pos: Vector2) -> void:
	if is_grabbed:
		global_position = pos


func launch_thrown(vel: Vector2, impact_damage: int, landing_damage: int, _source_pos: Vector2 = Vector2.ZERO) -> void:
	## Thrown by the grabber: impact damage now, landing damage on touchdown,
	## control disabled for the airtime.
	is_grabbed = false
	_grabber = null
	_thrown = true
	_throw_landing_damage = landing_damage
	# Impact damage bypasses i-frames (you were caught) but not death checks
	var mitigated: int = maxi(impact_damage - (defense + stat_def), 1)
	health -= mitigated
	Fx.damage_number(global_position, mitigated, Fx.PLAYER_DAMAGE_COLOR)
	_flash_skin(Color(1, 0.25, 0.25))
	velocity = vel
	is_hurt = true
	hurt_timer = 0.6  # control locked through the arc
	invuln_timer = maxf(invuln_timer, 0.4)
	update_bars()
	if player_skin and player_skin.has_method("play_hurt"):
		player_skin.play_hurt()
	if health <= 0:
		die()


func _try_parry(source_pos: Vector2, attacker: Node) -> bool:
	## Perfect parry: inside the window AND the attack comes from the front.
	if not is_parrying:
		return false
	var from_dir: float = signf(source_pos.x - global_position.x)
	if from_dir != 0.0 and int(from_dir) != facing:
		return false  # hit from behind — parry fails

	# Success: consume the window, negate all damage
	is_parrying = false
	parry_timer = 0.0
	parry_recovery_timer = 0.0
	invuln_timer = maxf(invuln_timer, 0.3)  # brief safety after the deflect
	Fx.parry_spark(global_position + Vector2(facing * 14, -6))
	_flash_skin(Color(1.4, 1.4, 1.6))

	# Counter window: next attack is immediately available
	attack_cooldown_timer = 0.0

	if attacker and is_instance_valid(attacker):
		if attacker.has_method("reflect"):
			# Projectiles/beams bounce back at their source
			attacker.reflect()
		elif attacker.has_method("apply_stagger"):
			var push: Vector2 = Vector2(facing * 260.0, -120.0)
			attacker.apply_stagger(1.2, push)
	return true


func _flash_skin(color: Color) -> void:
	if not player_skin:
		return
	player_skin.modulate = color
	var tw := create_tween()
	tw.tween_property(player_skin, "modulate", Color.WHITE, 0.2)


func die() -> void:
	if is_dead:
		return
	is_dead = true
	is_attacking = false
	is_rolling = false
	is_parrying = false
	health = 0
	update_bars()
	if player_skin:
		if player_skin.has_method("_disable_hitbox"):
			player_skin._disable_hitbox()
		if player_skin.has_method("play_death"):
			player_skin.play_death()
	_disable_touch_controls()
	# Let the collapse play out, then show the death screen
	var timer := get_tree().create_timer(1.1)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(self):
			_show_death_screen())


func _show_death_screen() -> void:
	var screen := get_tree().get_first_node_in_group("death_screen")
	if screen == null:
		var scene := load("res://dieo.tscn")
		if scene:
			screen = scene.instantiate()
			get_tree().current_scene.add_child(screen)
	if screen and screen.has_method("show_death_screen"):
		screen.show_death_screen()


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
	# Touch DODGE button + keyboard dodge action both land here
	_perform_dodge_roll()


func _perform_dodge_roll() -> void:
	## Directional roll with i-frames — replaces the old reversed evade dash.
	if _gameplay_blocked() or is_rolling or is_attacking or is_parrying:
		return
	if roll_cooldown > 0.0 or stamina < ROLL_COST:
		return
	stamina_regen_paused = true
	stamina -= ROLL_COST
	saturation = max(saturation - SAT_ACTION_COST, 0.0)

	# Roll toward movement input; fall back to facing
	if absf(joystick_vector.x) > 0.2:
		roll_direction = int(signf(joystick_vector.x))
	else:
		roll_direction = facing
	facing = roll_direction
	if player_skin:
		player_skin.scale.x = abs(player_skin.scale.x) * facing

	is_rolling = true
	roll_timer = ROLL_TIME
	roll_cooldown = ROLL_COOLDOWN
	invuln_timer = maxf(invuln_timer, ROLL_TIME)  # i-frames for the whole roll
	if player_skin and player_skin.has_method("play_roll"):
		player_skin.play_roll()


func _perform_parry() -> void:
	## Short guard window; a hit landing inside it (from the front) is negated
	## and the attacker is staggered (see _try_parry).
	if _gameplay_blocked() or is_rolling or is_attacking or is_parrying:
		return
	if parry_cooldown_timer > 0.0 or parry_recovery_timer > 0.0 or stamina < PARRY_COST:
		return
	stamina_regen_paused = true
	stamina -= PARRY_COST
	saturation = max(saturation - SAT_ACTION_COST, 0.0)
	is_parrying = true
	parry_timer = PARRY_WINDOW
	parry_cooldown_timer = PARRY_COOLDOWN
	if player_skin and player_skin.has_method("play_parry"):
		player_skin.play_parry()

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
