extends Node2D
## Boss arena — flat walled test arena, quick-launchable without going
## through title → class select (a class is auto-assigned).
## Debug controls (see the on-screen hint):
##   1-4  switch class at runtime (re-equips the class starter weapon)
##   B    spawn the FOURBLADE miniboss

const BOSS_SCENE := preload("res://enemies/boss_fourblade.tscn")

@onready var player: CharacterBody2D = $Player

var boss: Node = null
var pixel_font: Font = null


func _ready() -> void:
	pixel_font = load("res://fonts/PressStart2P.ttf")
	_build_hint_ui()
	# Adopt a boss placed directly in the scene so B doesn't stack a second one
	if boss == null or not is_instance_valid(boss):
		boss = get_tree().get_first_node_in_group("boss")


func _unhandled_input(event: InputEvent) -> void:
	if not player or not is_instance_valid(player):
		return
	if event.is_action_pressed("dbg_class_1"):
		player.apply_class("Warrior")
	elif event.is_action_pressed("dbg_class_2"):
		player.apply_class("Ranger")
	elif event.is_action_pressed("dbg_class_3"):
		player.apply_class("Mage")
	elif event.is_action_pressed("dbg_class_4"):
		player.apply_class("Healer")
	elif event.is_action_pressed("dbg_spawn_boss"):
		spawn_boss()


func spawn_boss() -> void:
	if boss != null and is_instance_valid(boss):
		return  # one at a time
	boss = BOSS_SCENE.instantiate()
	add_child(boss)
	boss.global_position = player.global_position + Vector2(520, -120)
	# Arrival slam
	Fx.parry_spark(boss.global_position)
	if player.has_method("_screen_shake"):
		player._screen_shake(4.0)


func _build_hint_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	var hint := Label.new()
	hint.text = "[1-4] CLASS   [B] SPAWN BOSS   [HOLD ATK] CHARGE   [SHIFT] DODGE   [K] PARRY"
	if pixel_font:
		hint.add_theme_font_override("font", pixel_font)
	hint.add_theme_font_size_override("font_size", 8)
	hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8, 0.8))
	hint.add_theme_constant_override("outline_size", 3)
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_top = -28.0
	hint.offset_bottom = -12.0
	hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	layer.add_child(hint)
