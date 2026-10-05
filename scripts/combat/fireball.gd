class_name Fireball
extends Node3D
## Boule de feu (FIREBALL de la Xplode, à la place de l'éclair du Riff électrique), faite avec les textures de feu
## d'Ulysse (assets/textures/feu, pack « GAP Fire Textures ») :
##   • un cœur où bouillonnent des cellules de feu (texture de Voronoi, shaders/fireball_core.gdshader) ;
##   • un halo (halo.png) et des flammes (flamme_1.png, flamme_2.png) qui tourbillonnent autour ;
##   • une traînée de flammes qui reste en arrière et s'éteint ;
##   • à l'impact : une gerbe de flammes, des braises et un éclair de lumière.
## Les flammes sont des sprites blancs (forme dans la transparence) teintés jaune → orange → rouge, en mélange additif.

const FLIGHT := 0.28
const COLOR := Color(1.0, 0.5, 0.12)
const TEX_DIR := "res://assets/textures/feu/"

var from := Vector3.ZERO
var to := Vector3.ZERO
## Taille (grossit avec les notes du riff).
var size := 0.22
var _t := 0.0
var _body: Node3D
var _trail: CPUParticles3D
var _light: OmniLight3D
var _done := false


static func spawn(parent: Node, a: Vector3, b: Vector3, ball_size: float = 0.22) -> Fireball:
	var f := Fireball.new()
	f.from = a
	f.to = b
	f.size = ball_size
	parent.add_child(f)
	return f


func _ready() -> void:
	global_position = from
	_body = Node3D.new()
	add_child(_body)
	# Cœur : cellules de feu qui bouillonnent.
	var core := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = size
	sphere.height = size * 2.0
	core.mesh = sphere
	core.material_override = core_material()
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_body.add_child(core)
	# Halo lumineux, toujours face à la caméra.
	var halo := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * size * 7.0
	halo.mesh = quad
	halo.material_override = sprite_material("halo.png", Color(0.9, 0.32, 0.05, 0.55), BaseMaterial3D.BILLBOARD_ENABLED)
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_body.add_child(halo)
	# Flammes qui tourbillonnent autour du cœur (elles suivent la boule).
	_body.add_child(_flames("flamme_1.png", size * 3.2, 14, 0.22, true, _ramp(Color(1.0, 0.55, 0.12, 0.7), Color(0.9, 0.2, 0.02, 0.35))))
	# Traînée : des flammes qui restent en arrière (repère du monde), gonflent et s'éteignent.
	_trail = _flames("flamme_2.png", size * 2.6, 40, 0.5, false, _ramp(Color(1.0, 0.55, 0.1, 0.85), Color(0.6, 0.08, 0.0, 0.0)))
	_trail.gravity = Vector3(0, 1.4, 0)
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.6))
	grow.add_point(Vector2(1.0, 1.3))
	_trail.scale_amount_curve = grow
	add_child(_trail)
	_light = OmniLight3D.new()
	_light.light_color = COLOR
	_light.light_energy = 2.2
	_light.omni_range = 4.5
	add_child(_light)


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	var k := minf(1.0, _t / FLIGHT)
	global_position = from.lerp(to, k) + Vector3(0, sin(k * PI) * 0.4, 0) # léger arc
	if k >= 1.0:
		_explode()


## Impact : gerbe de flammes et de braises, éclair de lumière ; la boule disparaît (la traînée finit de s'éteindre).
func _explode() -> void:
	_done = true
	_body.visible = false
	_trail.emitting = false
	var blast := _flames("flamme_1.png", size * 4.0, 12, 0.45, true, _ramp(Color(1.0, 0.5, 0.12, 0.75), Color(0.6, 0.08, 0.0, 0.0)))
	blast.one_shot = true
	blast.explosiveness = 1.0
	blast.emission_sphere_radius = size
	blast.direction = Vector3.UP
	blast.spread = 180.0
	blast.initial_velocity_min = 1.0
	blast.initial_velocity_max = 2.5
	blast.gravity = Vector3(0, 2.0, 0)
	add_child(blast)
	blast.emitting = true
	var embers := CPUParticles3D.new()
	embers.one_shot = true
	embers.explosiveness = 1.0
	embers.amount = 24
	embers.lifetime = 0.6
	embers.direction = Vector3.UP
	embers.spread = 180.0
	embers.initial_velocity_min = 2.0
	embers.initial_velocity_max = 4.5
	embers.gravity = Vector3(0, -6.0, 0)
	embers.scale_amount_min = 0.5
	embers.scale_amount_max = 1.2
	var ember := SphereMesh.new()
	ember.radius = 0.04
	ember.height = 0.08
	ember.material = Visuals.glow_mat(Color(1.0, 0.6, 0.15), 5.0)
	embers.mesh = ember
	add_child(embers)
	embers.emitting = true
	var tw := create_tween()
	tw.tween_property(_light, "light_energy", 5.0, 0.05)
	tw.tween_property(_light, "light_energy", 0.0, 0.45)
	get_tree().create_timer(1.0, false).timeout.connect(queue_free)


## Émetteur de sprites de flamme (texture `tex`), tournés au hasard et qui tournoient.
func _flames(tex: String, sprite: float, count: int, life: float, local: bool, ramp: Gradient) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.local_coords = local
	p.amount = count
	p.lifetime = life
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = size * 0.6
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = 0.3
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.angular_velocity_min = -220.0
	p.angular_velocity_max = 220.0
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.2
	p.color_ramp = ramp
	var q := QuadMesh.new()
	q.size = Vector2.ONE * sprite
	q.material = sprite_material(tex, Color.WHITE, BaseMaterial3D.BILLBOARD_PARTICLES)
	p.mesh = q
	return p


static func _ramp(start: Color, end: Color) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, start)
	g.add_point(0.45, start.lerp(end, 0.5))
	g.set_color(1, end)
	return g


static var _mats := {}


## Sprite de feu (assets/textures/feu) en mélange additif, teinté par `tint` et par la couleur des particules.
static func sprite_material(tex: String, tint: Color, billboard: BaseMaterial3D.BillboardMode) -> StandardMaterial3D:
	var key := "%s|%s|%d" % [tex, tint.to_html(), billboard]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.billboard_mode = billboard
		m.vertex_color_use_as_albedo = true
		m.albedo_texture = load(TEX_DIR + tex)
		m.albedo_color = tint
		_mats[key] = m
	return _mats[key]


static var _core_mat: ShaderMaterial


static func core_material() -> ShaderMaterial:
	if _core_mat == null:
		_core_mat = ShaderMaterial.new()
		_core_mat.shader = load("res://shaders/fireball_core.gdshader")
		_core_mat.set_shader_parameter("noise_tex", load(TEX_DIR + "voronoi.png"))
	return _core_mat
