class_name UiStyle
extends RefCounted
## Styles d'interface partagés : cadres et boutons de fer noirci rendus dans Blender (assets/ui, art/hud/build_hud.py),
## police à empattements.

const BONE := Color(0.93, 0.87, 0.72)
const DIM := Color(0.65, 0.6, 0.52)
const BLOOD := Color(0.7, 0.1, 0.08)
const PANEL_BG := Color(0.06, 0.05, 0.05, 0.92)
const BORDER := Color(0.42, 0.33, 0.22)

static var _serif: SystemFont
static var _theme: Theme


static func serif() -> Font:
	if _serif == null:
		_serif = SystemFont.new()
		_serif.font_names = PackedStringArray(["Cinzel", "Trajan Pro", "Georgia", "Palatino Linotype", "Times New Roman", "serif"])
	return _serif


static func theme() -> Theme:
	if _theme != null:
		return _theme
	_theme = Theme.new()
	_theme.default_font = serif()
	_theme.default_font_size = 18
	_theme.set_color("font_color", "Label", BONE)
	_theme.set_color("font_color", "Button", BONE)
	_theme.set_color("font_hover_color", "Button", Color(1.0, 0.85, 0.5))
	_theme.set_color("font_disabled_color", "Button", Color(0.4, 0.37, 0.33))
	_theme.set_color("default_color", "RichTextLabel", BONE)
	_theme.set_stylebox("normal", "Button", button_box(Color.WHITE))
	_theme.set_stylebox("hover", "Button", button_box(Color(1.5, 1.0, 0.7))) # lueur de forge
	_theme.set_stylebox("pressed", "Button", button_box(Color(1.8, 0.8, 0.5)))
	_theme.set_stylebox("disabled", "Button", button_box(Color(0.55, 0.55, 0.55)))
	_theme.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), Color(0.9, 0.7, 0.4), 1))
	for kind: String in ["OptionButton"]:
		_theme.set_stylebox("normal", kind, button_box(Color.WHITE))
		_theme.set_stylebox("hover", kind, button_box(Color(1.5, 1.0, 0.7)))
		_theme.set_stylebox("pressed", kind, button_box(Color(1.8, 0.8, 0.5)))
	_theme.set_stylebox("panel", "PanelContainer", frame())
	_theme.set_stylebox("panel", "Panel", frame())
	return _theme


## Cadre de fer des panneaux (coins à rivets) ; `dim` : voile sombre sur tout l'écran derrière (fenêtres modales).
static func frame(dim: bool = false, content: float = 22.0) -> IronFrame:
	var f := IronFrame.make(load("res://assets/ui/cadre.png"), 48.0, content)
	f.dim = dim
	return f


## Bouton de fer biseauté (teinte : survol, appui, désactivé).
static func button_box(tint: Color) -> IronFrame:
	var f := IronFrame.make(load("res://assets/ui/bouton.png"), 18.0, 10.0, tint)
	f.content_margin_left = 22.0
	f.content_margin_right = 22.0
	return f


## Plaque de fer sous les réservoirs du HUD (texte des PV et des décibels).
static func plate() -> IronFrame:
	var f := IronFrame.make(load("res://assets/ui/bouton.png"), 18.0, 4.0)
	f.content_margin_left = 14.0
	f.content_margin_right = 14.0
	return f


static func box(bg: Color, border: Color, border_width: int = 2, radius: int = 3) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_width)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	s.shadow_color = Color(0, 0, 0, 0.5)
	s.shadow_size = 4
	return s


static func label(text: String, size: int = 18, color: Color = BONE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 5)
	return l


static func bar(fill: Color, min_size: Vector2) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = min_size
	b.show_percentage = false
	b.add_theme_stylebox_override("background", box(Color(0.04, 0.02, 0.02, 0.9), BORDER, 2, 2))
	var f := box(fill, fill.lightened(0.25), 0, 2)
	f.shadow_size = 0
	f.content_margin_left = 0
	f.content_margin_right = 0
	b.add_theme_stylebox_override("fill", f)
	return b
