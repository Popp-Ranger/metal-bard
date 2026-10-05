class_name Reservoir
extends Control
## Réservoir du HUD : une image rendue dans Blender (la main cornue pour la vie, l'enceinte pour les décibels, voir
## art/hud/build_hud.py) dont le creux se remplit d'un liquide animé (shaders/reservoir.gdshader), au niveau de
## `ratio`. En dessous, une plaque de fer porte le texte (« VIE 85 % · 38 / 45 »).

const SHADER := preload("res://shaders/reservoir.gdshader")

var ratio := 1.0
var _liquid: TextureRect
var _mat: ShaderMaterial
var _label: Label
var _shown := 1.0
var _flash := 0.0


## `image` : nom dans assets/ui (avec son masque <image>_masque.png) ; `size_px` : taille affichée de l'image.
static func create(image: String, size_px: Vector2, deep: Color, bright: Color, foam: Color) -> Reservoir:
	var r := Reservoir.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.custom_minimum_size = size_px + Vector2(0, 34)
	r.size = r.custom_minimum_size
	var art := TextureRect.new()
	art.texture = load("res://assets/ui/%s.png" % image)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.size = size_px
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_child(art)
	r._liquid = TextureRect.new()
	var mask := load("res://assets/ui/%s_masque.png" % image) as Texture2D
	r._liquid.texture = mask
	r._liquid.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r._liquid.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r._liquid.size = size_px
	r._liquid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r._mat = ShaderMaterial.new()
	r._mat.shader = SHADER
	r._mat.set_shader_parameter("deep_color", deep)
	r._mat.set_shader_parameter("bright_color", bright)
	r._mat.set_shader_parameter("foam_color", foam)
	var span := _mask_span(mask)
	r._mat.set_shader_parameter("top", span.x)
	r._mat.set_shader_parameter("bottom", span.y)
	r._liquid.material = r._mat
	r.add_child(r._liquid)
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", UiStyle.plate())
	plate.position = Vector2(-10, size_px.y - 4)
	plate.custom_minimum_size = Vector2(size_px.x + 20, 34)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_child(plate)
	r._label = UiStyle.label("", 15)
	r._label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	r._label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plate.add_child(r._label)
	return r


## Haut et bas de la zone blanche du masque (UV verticales) : le liquide monte de l'un à l'autre.
static func _mask_span(mask: Texture2D) -> Vector2:
	if mask == null:
		return Vector2(0.0, 1.0)
	var img := mask.get_image()
	if img == null:
		return Vector2(0.0, 1.0)
	if img.is_compressed():
		img.decompress()
	var h := img.get_height()
	var w := img.get_width()
	var first := -1
	var last := -1
	for y in range(0, h, 2):
		for x in range(0, w, 3):
			if img.get_pixel(x, y).a > 0.5:
				if first < 0:
					first = y
				last = y
				break
	if first < 0:
		return Vector2(0.0, 1.0)
	return Vector2(float(first) / h, float(last + 2) / h)


func set_value(value: float, max_value: float, text: String) -> void:
	var r := clampf(value / maxf(max_value, 1.0), 0.0, 1.0)
	if r < ratio - 0.001:
		_flash = 1.0
	ratio = r
	_label.text = text


func _process(delta: float) -> void:
	_shown = move_toward(_shown, ratio, delta * 1.5) # le liquide descend / monte en douceur
	_flash = maxf(0.0, _flash - delta * 3.0)
	_mat.set_shader_parameter("fill", _shown)
	_mat.set_shader_parameter("flash", _flash)
