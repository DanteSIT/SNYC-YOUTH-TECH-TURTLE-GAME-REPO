extends RefCounted
## OceanTheme — central factory for the shared underwater UI theme.
##
## Menus, the pause panel, settings and controls all reuse the same
## StyleBoxFlat + font colors so the game feels consistent. If the look
## changes here it changes everywhere.


const FONT_COLOR := Color(0.9, 0.98, 1, 1)
const FONT_PRESSED := Color(0.8, 0.95, 1, 1)
const FONT_HOVER := Color(1, 1, 1, 1)

const BG_NORMAL := Color(0.04, 0.32, 0.45, 0.78)
const BG_PRESSED := Color(0.03, 0.2, 0.32, 0.95)
const BG_HOVER := Color(0.1, 0.48, 0.62, 0.92)
const BG_FOCUS := Color(0.1, 0.48, 0.62, 0.6)

const BORDER_TOP := Color(0.45, 0.85, 0.95, 0.45)
const BORDER_BRIGHT := Color(0.75, 0.98, 1, 0.9)
const BORDER_HOVER := Color(0.6, 0.95, 1, 0.8)

const FONT_SIZE := 24


## Builds the standard button Theme used by pause/settings/controls panels.
static func build_button_theme() -> Theme:
	var theme := Theme.new()

	var normal := _stylebox(BG_NORMAL, BORDER_TOP, 4.0, Vector2(0, 2))
	var pressed := _stylebox(BG_PRESSED, BORDER_BRIGHT, 1.0, Vector2(0, 1))
	var hover := _stylebox(BG_HOVER, BORDER_HOVER, 5.0, Vector2(0, 2))
	var focus := _stylebox(BG_FOCUS, BORDER_BRIGHT, 0.0, Vector2.ZERO)

	theme.set_stylebox("normal", "Button", normal)
	theme.set_stylebox("pressed", "Button", pressed)
	theme.set_stylebox("hover", "Button", hover)
	theme.set_stylebox("focus", "Button", focus)
	theme.set_color("font_color", "Button", FONT_COLOR)
	theme.set_color("font_pressed_color", "Button", FONT_PRESSED)
	theme.set_color("font_hover_color", "Button", FONT_HOVER)
	theme.set_color("font_focus_color", "Button", FONT_COLOR)
	theme.set_font_size("font_size", "Button", FONT_SIZE)
	return theme


static func _stylebox(bg: Color, border: Color, shadow_size: float, shadow_offset: Vector2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_border_width_all(2)
	sb.border_color = border
	sb.set_corner_radius_all(12)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = int(shadow_size)
	sb.shadow_offset = shadow_offset
	return sb