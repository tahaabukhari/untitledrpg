extends RefCounted

# Utility class to apply RPG-styled themes to touch control buttons
# Uses icons from game-icons.net (CC BY 3.0 — Lorc, Delapouite, et al.)

const COLORS := {
	"attack": {
		"bg": Color(0.2, 0.06, 0.06, 0.85),
		"border": Color(0.85, 0.2, 0.2, 0.8),
		"hover_border": Color(1.0, 0.35, 0.35, 1.0),
		"font": Color(0.95, 0.3, 0.3, 1.0),
	},
	"jump": {
		"bg": Color(0.06, 0.15, 0.06, 0.85),
		"border": Color(0.2, 0.75, 0.3, 0.8),
		"hover_border": Color(0.35, 0.9, 0.45, 1.0),
		"font": Color(0.3, 0.9, 0.4, 1.0),
	},
	"evade": {
		"bg": Color(0.18, 0.15, 0.04, 0.85),
		"border": Color(0.85, 0.7, 0.2, 0.8),
		"hover_border": Color(1.0, 0.85, 0.35, 1.0),
		"font": Color(0.95, 0.8, 0.3, 1.0),
	},
	"pause": {
		"bg": Color(0.1, 0.1, 0.12, 0.85),
		"border": Color(0.5, 0.5, 0.55, 0.7),
		"hover_border": Color(0.7, 0.7, 0.75, 0.9),
		"font": Color(0.8, 0.8, 0.85, 1.0),
	}
}

# Map button types to icon file paths (keeping empty so we revert to text, except for pause logic)
const ICON_PATHS := {}

static func apply(button: Button, color_key: String, font: Font = null) -> void:
	var c = COLORS.get(color_key, COLORS["pause"])
	
	button.add_theme_stylebox_override("normal", _make_style(c["bg"], c["border"]))
	button.add_theme_stylebox_override("hover", _make_style(c["bg"], c["hover_border"]))
	button.add_theme_stylebox_override("pressed", _make_style(Color(c["bg"].r + 0.05, c["bg"].g + 0.05, c["bg"].b + 0.05, 0.95), c["hover_border"]))
	button.add_theme_stylebox_override("focus", _make_style(c["bg"], c["border"]))
	
	button.add_theme_color_override("font_color", c["font"])
	button.add_theme_color_override("font_hover_color", c["font"])
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	
	# Load and apply icon
	if ICON_PATHS.has(color_key):
		var icon_tex = load(ICON_PATHS[color_key])
		if icon_tex:
			button.icon = icon_tex
			button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			button.expand_icon = true
			# Remove text since we have an icon now
			button.text = ""
	elif color_key == "pause":
		# Pause icon: create programmatically (two vertical bars)
		var img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		var bar_color = Color.WHITE
		# Left bar
		for y in range(6, 26):
			for x in range(9, 15):
				img.set_pixel(x, y, bar_color)
		# Right bar
		for y in range(6, 26):
			for x in range(17, 23):
				img.set_pixel(x, y, bar_color)
		var tex = ImageTexture.create_from_image(img)
		button.icon = tex
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.expand_icon = true
		button.text = ""
	
	if font:
		button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", 10)

static func _make_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.shadow_color = Color(0, 0, 0, 0.3)
	style.shadow_size = 2
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style
