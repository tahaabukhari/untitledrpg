extends CharacterBody2D

const SPEED = 350.0
const JUMP_VELOCITY = -400.0
const ATTACK_TEXT_TIME = 0.5

# Dodge — the variant is chosen from MOVEMENT input at press time:
#   up → evade leap, down → forward slide, else → roll.
enum DodgeVariant { ROLL, LEAP, SLIDE }
const ROLL_SPEED := 480.0
const ROLL_TIME := 0.35
const ROLL_COOLDOWN := 0.6
const ROLL_COST := 25
# Evade leap (dodge while holding up): a hop a bit taller than a jump + i-frames
const LEAP_VELOCITY := -470.0     # ~JUMP_VELOCITY × 1.18
const LEAP_DRIFT := 250.0
const LEAP_IFRAMES := 0.45
# Slide (dodge while holding down): low forward dash that slides under bipeds
const SLIDE_SPEED := 560.0
const SLIDE_TIME := 0.4
const SLIDE_IFRAMES := 0.32
const SLIDE_TRIP_REACH := 48.0
const SLIDE_TRIP_HEIGHT := 42.0
const SLIDE_TRIP_CHANCE := 0.6         # 60% of the player's slide-unders knock down (mirror stays 30%)
const SLIDE_KNOCKDOWN_STAMINA := 50    # extra stamina burned on a SUCCESSFUL knockdown

# Tripping / knockdown (bipeds only)
const TRIP_DURATION := 2.0
const DOWNED_DMG_MULT := 1.35     # knocked-down opponents take bonus damage
const DOWNED_RECOVER_IFRAMES := 0.3
const TRIP_IMMUNITY := 0.5        # brief immunity after standing up

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

# Dodge state (is_rolling covers the grounded roll AND slide dodges)
var is_rolling := false
var roll_timer := 0.0
var roll_cooldown := 0.0
var roll_direction := 1
var dodge_variant: int = DodgeVariant.ROLL
var _slide_tripped: Array = []       # enemies already tripped by the current slide

# Downed / tripped state (bipedal — the player has legs)
var is_downed := false
var downed_timer := 0.0
var trip_immunity_timer := 0.0
var trippable := true

# Parry state
var is_parrying := false
var parry_timer := 0.0
var parry_recovery_timer := 0.0
var parry_cooldown_timer := 0.0

var fall_timer := 0.0
const LONG_FALL_THRESHOLD := 2.0  # seconds before switching to long_fall anim

# Combat — driven by equipped weapon
@export var equipped_weapon: WeaponData = preload("res://weapons/weapon_fists.tres")
var equipped_instance: ItemInstance = null  # unique instance backing equipped_weapon
var _behavior: WeaponBehavior = null   # charged-attack plugin for equipped_weapon
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

# Laser overcharge: hold past full to build mana-circle stacks; past 10s the
# hold drains extra mana — drain it dry and the circle BREAKS (attack fails).
const OVERDRIVE_HOLD_TIME := 10.0    # hold longer than this = overdrive beam
const OVERDRIVE_MANA_DRAIN := 8.0    # extra mana per second past 10s
const STACK_INTERVAL := 2.0          # seconds of full-charge hold per visual stack pip
const MAX_CHARGE_STACKS := 5         # visual pip cap only (damage keeps growing)
const STACK_DAMAGE_BONUS := 0.08     # +8% damage per pip (pre-overdrive)
# Overdrive is UNLIMITED: past OVERDRIVE_HOLD_TIME each extra second grows the
# beam's RANGE by a wide margin and DAMAGE by a light margin — width is frozen.
const OVERDRIVE_RANGE_PER_SEC := 240.0
const OVERDRIVE_DAMAGE_PER_SEC := 4.0
const OVERDRIVE_WIDTH_MULT := 1.6    # one-time width bump on entering overdrive
var _charge_circle: ChargeCircle = null
var _full_hold_time := 0.0           # time spent at 100% charge (visual stacks)
var _overdrive_drain_accum := 0.0

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
	input_ctrl.interact_pressed.connect(_on_interact_pressed)
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
	var starter: WeaponData = Global.get_starter_weapon()
	if starter:
		_on_weapon_equipped(starter)

	# Apply character customization (hair/skin/outfit tints + hero name)
	_apply_customization()
	
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


func _on_interact_pressed() -> void:
	if _gameplay_blocked():
		return
	var nearest: Node = null
	var best_dist := 96.0
	for node in get_tree().get_nodes_in_group("interactable"):
		if not (node is Node2D):
			continue
		if not node.has_method("interact"):
			continue
		var dist := global_position.distance_to((node as Node2D).global_position)
		if dist < best_dist:
			best_dist = dist
			nearest = node
	if nearest:
		nearest.interact(self)


func _on_attack_released(charge_level: float, hold_time: float = 0.0) -> void:
	if _gameplay_blocked():
		return
	# The equipped weapon's behavior plugin owns the release decision
	# (charged beam / heal / melee vs. a normal tap).
	_ensure_behavior().on_release(self, charge_level, hold_time)


func _ensure_behavior() -> WeaponBehavior:
	if _behavior == null:
		_behavior = equipped_weapon.get_behavior()
	return _behavior


func _gameplay_blocked() -> bool:
	## Combat/movement input is ignored while menus are open, dead, downed, or hurt.
	if is_dead or is_hurt or is_downed:
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

	# Downed (tripped): on our knees, no input, wide open — a real punish window
	if is_downed:
		downed_timer -= delta
		if not is_on_floor():
			velocity.y += ProjectSettings.get_setting("physics/2d/default_gravity") * delta
		velocity.x = move_toward(velocity.x, 0, SPEED * delta * 5.0)
		move_and_slide()
		if downed_timer <= 0.0:
			is_downed = false
			trip_immunity_timer = TRIP_IMMUNITY
			invuln_timer = maxf(invuln_timer, DOWNED_RECOVER_IFRAMES)
		return

	if trip_immunity_timer > 0.0:
		trip_immunity_timer -= delta

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

	# Grounded dodge (roll OR slide): dodge-driven movement, i-frames via invuln_timer
	if is_rolling:
		stamina_regen_paused = true
		roll_timer -= delta
		var dodge_speed: float = SLIDE_SPEED if dodge_variant == DodgeVariant.SLIDE else ROLL_SPEED
		velocity.x = roll_direction * dodge_speed
		if not is_on_floor():
			velocity.y += ProjectSettings.get_setting("physics/2d/default_gravity") * delta
		move_and_slide()
		if dodge_variant == DodgeVariant.SLIDE:
			_slide_trip_check()
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

	# Laser charge telegraph (orb + mana circle + overdrive drain while charging)
	_update_charge_telegraph(delta)

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
			and not is_parrying and parry_recovery_timer <= 0.0 and not _laser_stance_active():
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

func do_normal_attack() -> void:
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


func do_charged_melee() -> void:
	if is_attacking or is_rolling or is_parrying:
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


func fire_laser_beam(charge_level: float, hold_time: float = 0.0) -> void:
	## SHOWCASE: charge-scaled piercing hitscan beam along the 8-dir aim.
	## Long holds build mana-circle stacks (bonus damage); holds past
	## OVERDRIVE_HOLD_TIME fire a wider helix-wrapped overdrive beam.
	if is_attacking or attack_cooldown_timer > 0.0 or is_rolling or is_parrying:
		return
	var w := equipped_weapon

	# Stacks/overdrive derived from hold_time (stateless — the telegraph
	# visuals mirror the same math)
	var full_hold: float = maxf(hold_time - w.charge_time, 0.0) if charge_level >= 1.0 else 0.0
	var stacks: int = mini(int(full_hold / STACK_INTERVAL), MAX_CHARGE_STACKS)
	var overdrive: bool = hold_time >= OVERDRIVE_HOLD_TIME
	# Seconds spent in overdrive — drives the unlimited range/damage growth
	var overtime: float = maxf(hold_time - OVERDRIVE_HOLD_TIME, 0.0)

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

	# Charge-scaled damage / range / width. Stacks boost damage pre-overdrive;
	# in overdrive the width is frozen while continued holding grows range
	# (wide margin) and damage (light margin) with NO cap.
	var dmg: int = int(lerpf(w.laser_min_damage, w.laser_max_damage, charge_level) \
		* (1.0 + STACK_DAMAGE_BONUS * stacks)) + stat_atk
	var beam_range := lerpf(w.laser_min_range, w.laser_max_range, charge_level)
	var beam_width := lerpf(w.laser_min_width, w.laser_max_width, charge_level)
	if overdrive:
		beam_width = lerpf(w.laser_min_width, w.laser_max_width, 1.0) * OVERDRIVE_WIDTH_MULT
		beam_range += overtime * OVERDRIVE_RANGE_PER_SEC       # wide range gain
		dmg += int(overtime * OVERDRIVE_DAMAGE_PER_SEC)        # light damage gain
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
		if col is Node and ((col as Node).is_in_group("enemy") or (col as Node).is_in_group("breakable")) and col.has_method("take_damage"):
			col.take_damage(dmg, aim * 260.0 + Vector2(0, -60))
			Fx.hit_particles(hit.position, Color(0.7, 0.85, 1.0))
		excludes.append(hit.rid)
		enemy_q.exclude = excludes

	# Visuals + feel — overdrive gets the white helix-wrapped beam and a harder
	# kick; the helix intensity grows with overtime (longer hold = fiercer)
	if overdrive:
		var intensity := stacks + int(overtime)
		Fx.beam(start, end, beam_width, Color(1.0, 1.0, 1.0, 1.0), Color(0.85, 0.9, 1.0, 0.6), true, intensity)
	else:
		Fx.beam(start, end, beam_width)
	velocity -= aim * lerpf(40.0, 170.0, charge_level) * (1.6 if overdrive else 1.0)  # recoil
	_screen_shake((lerpf(1.5, 6.0, charge_level) + overtime * 0.3) if overdrive else lerpf(1.5, 6.0, charge_level))

	# Cast animation (staff_charged) drives the attack state/cooldown
	is_attacking = true
	hit_enemies_this_swing.clear()
	current_attack_knockback = 0.0
	attack_label.text = ("OVERDRIVE BEAM  %dm" % int(beam_range / 64.0)) if overdrive else "ARCANE BEAM"
	attack_label.visible = true
	attack_text_timer = ATTACK_TEXT_TIME * 2
	if player_skin and player_skin.has_method("play_uppercut"):
		player_skin.play_uppercut()


func channel_heal() -> void:
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


# ─── Prayer (healer's empty-handed default) ──────────────────────────────────

const PRAYER_LIGHTNING_ODDS := 7       # 1-in-7 prayers are answered
const PRAYER_TARGET_RANGE := 520.0     # nearest enemy within this gets struck
const PRAYER_AOE_RADIUS := 90.0        # light splash around the bolt
const PRAYER_AOE_FRACTION := 0.35      # AoE damage = bolt damage × this

func perform_prayer() -> void:
	## Rub hands together in prayer. The 1/7 lightning roll happens at the
	## animation's climax (prayer_rub method track → on_prayer_completed).
	if is_attacking or attack_cooldown_timer > 0.0 or is_rolling or is_parrying:
		return
	stamina_regen_paused = true
	saturation = max(saturation - SAT_ACTION_COST, 0.0)
	is_attacking = true
	hit_enemies_this_swing.clear()
	current_attack_knockback = 0.0
	attack_label.text = "PRAYER"
	attack_label.visible = true
	attack_text_timer = ATTACK_TEXT_TIME
	if player_skin and player_skin.has_method("play_named_attack"):
		player_skin.play_named_attack("prayer_rub")


func on_prayer_completed() -> void:
	## Fired by the prayer_rub animation. Every prayer sparkles; one in seven
	## is ANSWERED — lightning on the closest nearby enemy.
	Fx.prayer_sparkle(global_position + Vector2(facing * 8, -22))
	if randi_range(1, PRAYER_LIGHTNING_ODDS) != 1:
		return
	var target := _closest_enemy(PRAYER_TARGET_RANGE)
	if target == null:
		return  # answered, but no sinner in sight
	_summon_prayer_lightning(target)


func _summon_prayer_lightning(target: Node2D) -> void:
	## Divine bolt: full damage on the target, light AoE splash around the
	## explosion, burning embers linger (visuals in Fx.lightning_strike).
	var strike_pos := target.global_position
	var bolt_damage: int = equipped_weapon.charged_damage + stat_atk
	var aoe_damage: int = maxi(int(bolt_damage * PRAYER_AOE_FRACTION), 1)

	Fx.lightning_strike(strike_pos, PRAYER_AOE_RADIUS)
	_screen_shake(4.5)
	attack_label.text = "ANSWERED!"
	attack_label.visible = true
	attack_text_timer = ATTACK_TEXT_TIME * 2

	if target.has_method("take_damage"):
		target.take_damage(bolt_damage, Vector2(0, -180))
	# Light AoE on everything else near the blast
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy == target or not is_instance_valid(enemy) or not enemy is Node2D:
			continue
		if enemy.global_position.distance_to(strike_pos) <= PRAYER_AOE_RADIUS \
				and enemy.has_method("take_damage"):
			enemy.take_damage(aoe_damage, (enemy.global_position - strike_pos).normalized() * 140.0)


func _closest_enemy(max_range: float) -> Node2D:
	var best: Node2D = null
	var best_dist := max_range
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy) or not enemy is Node2D:
			continue
		if enemy.get("is_dead"):
			continue
		var dist: float = global_position.distance_to(enemy.global_position)
		if dist <= best_dist:
			best_dist = dist
			best = enemy
	return best


func _screen_shake(amplitude: float) -> void:
	if not camera:
		return
	var tw := create_tween()
	for i in range(4):
		tw.tween_property(camera, "offset",
			Vector2(randf_range(-amplitude, amplitude), randf_range(-amplitude, amplitude)), 0.04)
	tw.tween_property(camera, "offset", Vector2.ZERO, 0.06)


func _laser_stance_active() -> bool:
	## True while holding a laser charge — locks the aim battle stance.
	return input_ctrl != null and input_ctrl.is_charging \
		and _ensure_behavior().wants_charge_stance() \
		and not is_attacking and not is_dead and not is_rolling


func _update_charge_telegraph(delta: float) -> void:
	## While a laser weapon is charging: growing orb at the staff muzzle; once
	## FULLY charged a rotating mana circle appears ahead of the orb, gaining
	## brightness + stacks the longer the hold. Past OVERDRIVE_HOLD_TIME the
	## hold drains extra mana — run dry and the circle BREAKS (attack fails).
	if _laser_stance_active():
		# Battle stance: square up to the aim like a rifle
		var aim: Vector2 = input_ctrl.get_aim_vector()
		if absf(aim.x) > 0.15 and int(signf(aim.x)) != facing:
			facing = int(signf(aim.x))
			if player_skin:
				player_skin.scale.x = abs(player_skin.scale.x) * facing
		if player_skin and player_skin.has_method("play_aim_pose"):
			player_skin.play_aim_pose()

		# Shared muzzle point — the orb sits at the CENTER of the mana circle so
		# the two read as one integrated cast, not two stacked circles.
		var muzzle := Vector2(facing * 30.0, -13.0)
		var lvl: float = input_ctrl.charge_level

		# Charge orb (the bright core inside the circle)
		if _charge_orb == null or not is_instance_valid(_charge_orb):
			_charge_orb = Polygon2D.new()
			var pts := PackedVector2Array()
			for i in range(14):
				var t := TAU * float(i) / 14.0
				pts.append(Vector2(cos(t), sin(t)) * 5.0)
			_charge_orb.polygon = pts
			_charge_orb.z_index = 62  # above the circle rings
			add_child(_charge_orb)
		_charge_orb.position = muzzle
		_charge_orb.scale = Vector2.ONE * lerpf(0.25, 1.5, lvl)
		_charge_orb.color = Color(0.7 + 0.3 * lvl, 0.85, 1.0, 0.45 + 0.5 * lvl)
		if lvl >= 1.0:
			_charge_orb.scale *= 1.0 + 0.12 * sin(Time.get_ticks_msec() / 40.0)

		# Mana circle once fully charged: concentric with the orb, brighter +
		# more stacks the longer the hold
		if lvl >= 1.0:
			_full_hold_time += delta
			var stacks: int = mini(int(_full_hold_time / STACK_INTERVAL), MAX_CHARGE_STACKS)
			var overdrive: bool = input_ctrl.charge_hold_time >= OVERDRIVE_HOLD_TIME
			if _charge_circle == null or not is_instance_valid(_charge_circle):
				_charge_circle = ChargeCircle.new()
				_charge_circle.z_index = 61
				add_child(_charge_circle)
			_charge_circle.position = muzzle  # same point as the orb → integrated
			_charge_circle.stacks = stacks
			_charge_circle.brightness = clampf(_full_hold_time / OVERDRIVE_HOLD_TIME, 0.0, 1.0)
			_charge_circle.overdrive = overdrive
			_charge_circle.overtime = maxf(input_ctrl.charge_hold_time - OVERDRIVE_HOLD_TIME, 0.0)

			# Overdrive: the hold itself starts eating mana
			if overdrive:
				_overdrive_drain_accum += OVERDRIVE_MANA_DRAIN * delta
				while _overdrive_drain_accum >= 1.0:
					_overdrive_drain_accum -= 1.0
					mana -= 1
				if mana <= 0:
					mana = 0
					update_bars()
					_break_charge_circle()
	else:
		_full_hold_time = 0.0
		_overdrive_drain_accum = 0.0
		if _charge_orb != null and is_instance_valid(_charge_orb):
			_charge_orb.queue_free()
			_charge_orb = null
		if _charge_circle != null and is_instance_valid(_charge_circle):
			_charge_circle.queue_free()
			_charge_circle = null


func _break_charge_circle() -> void:
	## Held too long on an empty mana pool: the circle shatters, the charge is
	## lost, and NO beam fires. The button is dead until re-pressed.
	if input_ctrl:
		input_ctrl.cancel_charge()
	Fx.circle_break(global_position + Vector2(facing * 30.0, -13.0))
	_flash_skin(Color(0.5, 0.6, 1.3))
	_screen_shake(2.5)
	attack_label.text = "CIRCLE BROKEN"
	attack_label.visible = true
	attack_text_timer = ATTACK_TEXT_TIME * 2
	attack_cooldown_timer = maxf(attack_cooldown_timer, 0.6)  # fizzle recovery


## Rotating rune ring CONCENTRIC with the charge orb (shares its position).
## Dynamic gradient: cyan when fresh, whitening as it charges; pure white in
## overdrive. Rings/runes tighten around the orb; overtime grows the circle
## and sheds orbiting motes. Stack pips arc over the top.
class ChargeCircle:
	extends Node2D
	var stacks := 0
	var brightness := 0.0   # 0..1 over the hold to overdrive
	var overdrive := false
	var overtime := 0.0     # seconds past overdrive (unbounded)
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _grad(edge: float) -> Color:
		# Dynamic gradient cyan→white by charge; fully white in overdrive.
		var w: float = clampf(brightness + (1.0 if overdrive else 0.0), 0.0, 1.0)
		return Color(lerpf(0.55, 1.0, w), lerpf(0.85, 1.0, w), 1.0, edge)

	func _draw() -> void:
		var a := 0.35 + 0.6 * brightness
		# Circle grows with stacks, and keeps widening slowly in overdrive
		var r := 12.0 + 1.4 * stacks + minf(overtime, 12.0) * 0.6
		var col := _grad(a)

		# Concentric rings around the orb (outer, mid, inner)
		draw_arc(Vector2.ZERO, r, 0, TAU, 44, col, 2.0)
		draw_arc(Vector2.ZERO, r * 0.74, 0, TAU, 36, _grad(a * 0.8), 1.5)
		draw_arc(Vector2.ZERO, r * 0.5, 0, TAU, 28, _grad(a * 0.6), 1.0)

		# Rotating rune ticks straddling the outer ring (clockwise)
		var rune_count := 8 + int(minf(overtime, 8.0))
		for i in range(rune_count):
			var ang := _t * 1.6 + TAU * float(i) / float(rune_count)
			var dir := Vector2(cos(ang), sin(ang))
			draw_line(dir * (r - 3.0), dir * (r + 3.0), col, 2.0)

		# Counter-rotating inner motes hugging the orb
		for i in range(6):
			var ang2 := -_t * 2.4 + TAU * float(i) / 6.0
			draw_circle(Vector2(cos(ang2), sin(ang2)) * r * 0.5, 1.7, Color(1, 1, 1, a))

		# Orbiting particle motes in overdrive (further out, faster)
		if overdrive:
			var moccount := 6 + int(minf(overtime, 10.0))
			for i in range(moccount):
				var ang3 := _t * 3.2 + TAU * float(i) / float(moccount)
				var rr := r + 5.0 + 2.0 * sin(_t * 4.0 + i)
				draw_circle(Vector2(cos(ang3), sin(ang3)) * rr, 1.4, Color(1, 1, 1, 0.6 + 0.3 * sin(_t * 6.0 + i)))

		# Stack pips: diamonds arced over the top
		for i in range(stacks):
			var pip_ang := -PI / 2.0 + (float(i) - (stacks - 1) / 2.0) * 0.42
			var c := Vector2(cos(pip_ang), sin(pip_ang)) * (r + 7.0)
			var pip := PackedVector2Array([
				c + Vector2(0, -2.6), c + Vector2(2.2, 0), c + Vector2(0, 2.6), c + Vector2(-2.2, 0),
			])
			draw_colored_polygon(pip, Color(1.0, 1.0, 0.85, 0.6 + 0.4 * brightness))

		# Overdrive: bright WHITE pulsing flare ring (was purple)
		if overdrive:
			var pulse := 0.5 + 0.5 * sin(_t * 7.0)
			draw_arc(Vector2.ZERO, r + 4.0 + 2.5 * pulse, 0, TAU, 44,
				Color(1.0, 1.0, 1.0, 0.4 + 0.4 * pulse), 2.5)


# ─── Character customization ─────────────────────────────────────────────────

func _apply_customization() -> void:
	## Tints the puppet's layered sprites from Global.player_custom.
	## Face is left untinted (eyes/features keep their art colors).
	var custom: Dictionary = Global.player_custom
	player_name = str(custom.get("name", "Adventurer"))
	if not player_skin:
		return
	var hair: Color = custom.get("hair_color", Color(1, 1, 1))
	var skin: Color = custom.get("skin_tone", Color(1, 1, 1))
	var outfit: Color = custom.get("outfit_color", Color(1, 1, 1))
	var tint_map := {
		"HeadPivot/HairPivot/Sprite": hair,
		"HeadPivot/Sprite": skin,
		"LeftArmPivot/Sprite": skin,
		"RightArmPivot/Sprite": skin,
		"TorsoPivot/Sprite": outfit,
		"LeftLegPivot/Sprite": outfit,
		"RightLegPivot/Sprite": outfit,
	}
	for path in tint_map:
		var sprite := player_skin.get_node_or_null(path) as CanvasItem
		if sprite:
			sprite.modulate = tint_map[path]


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
	var starter: WeaponData = Global.get_starter_weapon()
	if starter:
		_on_weapon_equipped(starter)
	attack_label.text = cls.to_upper()
	attack_label.visible = true
	attack_text_timer = ATTACK_TEXT_TIME * 2
	update_bars()


# ─── Weapon Equipping ────────────────────────────────────────────────────────

const DEFAULT_WEAPON: WeaponData = preload("res://weapons/weapon_fists.tres")

func _on_weapon_equipped(w) -> void:
	## Accepts an ItemInstance (from inventory) OR a bare WeaponData template
	## (spawn/class-switch/tests) — a template is wrapped in a fresh instance so
	## the equipped item is always unique. Combat reads stats from
	## equipped_weapon (the definition); per-instance state lives on
	## equipped_instance.
	if w is ItemInstance:
		equipped_instance = w
	else:
		equipped_instance = ItemInstance.make(w)
	equipped_weapon = equipped_instance.def
	_behavior = equipped_weapon.get_behavior()
	if input_ctrl:
		input_ctrl.charge_time = equipped_weapon.charge_time
	if player_skin and player_skin.has_method("equip_weapon_visual"):
		player_skin.equip_weapon_visual(equipped_weapon)

func _on_weapon_unequipped() -> void:
	equipped_instance = ItemInstance.make(DEFAULT_WEAPON)
	equipped_weapon = DEFAULT_WEAPON
	_behavior = DEFAULT_WEAPON.get_behavior()
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
	# Downed: no parry/i-frames — you're on the ground taking BONUS damage.
	if is_downed:
		var down_dmg: int = maxi(int((amount - (defense + stat_def)) * DOWNED_DMG_MULT), 1)
		health -= down_dmg
		Fx.damage_number(global_position, down_dmg, Fx.PLAYER_DAMAGE_COLOR)
		update_bars()
		if health <= 0:
			die()
		return true
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


func trip(duration: float = TRIP_DURATION) -> bool:
	## Swept off our feet: knocked to our knees, no control, wide open. Bipeds
	## only — the player has legs, so this lands (unless we're mid-dodge/i-frame).
	## Returns true if the knockdown actually landed (the slider pays for it).
	if is_dead or is_downed or not trippable:
		return false
	if invuln_timer > 0.0 or is_rolling or trip_immunity_timer > 0.0 or not is_on_floor():
		return false  # dodging / airborne / just-recovered → immune
	is_downed = true
	downed_timer = duration
	is_attacking = false
	is_parrying = false
	velocity.x = 0.0
	if player_skin:
		if player_skin.has_method("_disable_hitbox"):
			player_skin._disable_hitbox()
		if player_skin.has_method("play_knockdown"):
			player_skin.play_knockdown()
	Fx.trip_dust(global_position + Vector2(0, 18))
	return true


func stagger(duration: float = 0.4, push: Vector2 = Vector2.ZERO) -> void:
	## Briefly reeled (no damage) — e.g. when an enemy PARRIES our attack.
	## Symmetric to EnemyBase.apply_stagger that our own parry calls.
	if is_dead or is_downed:
		return
	is_hurt = true
	hurt_timer = maxf(hurt_timer, duration)
	is_attacking = false
	if push.length() > 0.0:
		velocity = push
	if player_skin:
		if player_skin.has_method("_disable_hitbox"):
			player_skin._disable_hitbox()
		if player_skin.has_method("play_hurt"):
			player_skin.play_hurt()


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
	if (body.is_in_group("enemy") or body.is_in_group("breakable")) and body not in hit_enemies_this_swing:
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
	## Directional dodge. The VARIANT is chosen from movement input at press:
	## holding up → evade leap, holding down → forward slide, else → roll.
	if _gameplay_blocked() or is_rolling or is_attacking or is_parrying:
		return
	if roll_cooldown > 0.0 or stamina < ROLL_COST:
		return
	stamina_regen_paused = true
	stamina -= ROLL_COST
	saturation = max(saturation - SAT_ACTION_COST, 0.0)
	roll_cooldown = ROLL_COOLDOWN

	var mv := joystick_vector
	if mv.y < -0.4:
		_start_evade_leap(mv)
	elif mv.y > 0.4:
		_start_slide()
	else:
		_start_roll(mv)


func _start_roll(mv: Vector2) -> void:
	dodge_variant = DodgeVariant.ROLL
	# Roll toward movement input; fall back to facing
	if absf(mv.x) > 0.2:
		roll_direction = int(signf(mv.x))
	else:
		roll_direction = facing
	facing = roll_direction
	if player_skin:
		player_skin.scale.x = abs(player_skin.scale.x) * facing
	is_rolling = true
	roll_timer = ROLL_TIME
	invuln_timer = maxf(invuln_timer, ROLL_TIME)  # i-frames for the whole roll
	if player_skin and player_skin.has_method("play_roll"):
		player_skin.play_roll()


func _start_slide() -> void:
	## Low forward dash in the FACING direction that slides under bipeds (trips).
	dodge_variant = DodgeVariant.SLIDE
	roll_direction = facing
	_slide_tripped.clear()
	is_rolling = true
	roll_timer = SLIDE_TIME
	invuln_timer = maxf(invuln_timer, SLIDE_IFRAMES)  # early invuln — slide through
	if player_skin and player_skin.has_method("play_slide"):
		player_skin.play_slide()


func _start_evade_leap(mv: Vector2) -> void:
	## A nimble hop (a touch taller than a jump) with i-frames + a motion streak.
	## Behaves like a jump (normal air locomotion), so it is NOT a grounded dodge.
	dodge_variant = DodgeVariant.LEAP
	var dir := int(signf(mv.x)) if absf(mv.x) > 0.2 else facing
	velocity.y = LEAP_VELOCITY
	velocity.x = dir * LEAP_DRIFT
	jump_count = 1
	can_double_jump = true
	invuln_timer = maxf(invuln_timer, LEAP_IFRAMES)
	Fx.motion_streak(global_position, Vector2(dir, -1.4))


func _slide_trip_check() -> void:
	## While sliding we always pass THROUGH opponents (the i-frames are the
	## reliable payoff — evade attacks), but only a 30% roll actually sweeps a
	## BIPEDAL enemy's legs. One attempt per enemy per slide; a successful
	## knockdown costs 50 extra stamina.
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e) or e in _slide_tripped or not e is Node2D:
			continue
		var to: Vector2 = e.global_position - global_position
		if signf(to.x) == float(facing) and absf(to.x) <= SLIDE_TRIP_REACH \
				and absf(to.y) <= SLIDE_TRIP_HEIGHT and e.has_method("trip"):
			_slide_tripped.append(e)  # one chance per enemy this slide
			if randf() < SLIDE_TRIP_CHANCE and e.trip(TRIP_DURATION):
				stamina = max(stamina - SLIDE_KNOCKDOWN_STAMINA, 0)
				update_bars()


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
