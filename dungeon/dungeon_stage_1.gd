extends Node2D
## Escape-themed Stage 1 built from assembled modules.

const LAYOUT: Array[String] = [
	"res://dungeon/modules/mod_cell.tscn",
	"res://dungeon/modules/mod_corridor_vines.tscn",
	"res://dungeon/modules/mod_chamber_small.tscn",
	"res://dungeon/modules/mod_corridor_pots.tscn",
	"res://dungeon/modules/mod_guardroom.tscn",
	"res://dungeon/modules/mod_corridor_moss.tscn",
	"res://dungeon/modules/mod_chamber_large.tscn",
	"res://dungeon/modules/mod_antechamber.tscn",
	"res://dungeon/modules/mod_boss_chamber.tscn",
]


func _ready() -> void:
	var assembler := $DungeonAssembler
	assembler.layout = LAYOUT
	assembler.assemble()
	_build_hint_ui()


func _build_hint_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	var hint := Label.new()
	hint.text = "ESCAPE THE DUNGEON  [E] INTERACT  [BOSS GATE OPENS ON KILL]"
	var pixel_font := load("res://fonts/PressStart2P.ttf")
	if pixel_font:
		hint.add_theme_font_override("font", pixel_font)
	hint.add_theme_font_size_override("font_size", 8)
	hint.add_theme_color_override("font_color", Color(0.82, 0.86, 0.92, 0.86))
	hint.add_theme_constant_override("outline_size", 3)
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.set_anchors_preset(Control.PRESET_CENTER_TOP)
	hint.anchor_left = 0.0
	hint.anchor_right = 1.0
	hint.offset_top = 18.0
	hint.offset_bottom = 34.0
	layer.add_child(hint)
