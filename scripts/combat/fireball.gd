class_name Fireball
extends Node3D
## Boule de feu (FIREBALL de la Xplode, à la place de l'éclair du Riff électrique) : un cœur incandescent qui file
## de la guitare jusqu'à l'ennemi en laissant une traînée de flammes et d'étincelles, puis éclate à l'impact.

const FLIGHT := 0.28
const COLOR := Color(1.0, 0.5, 0.12)

var from := Vector3.ZERO
var to := Vector3.ZERO
## Taille (grossit avec les notes du riff).
var size := 0.22
var _t := 0.0
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
	Visuals.sphere(self, size, Vector3.ZERO, Visuals.glow_mat(Color(1.0, 0.85, 0.4), 6.0))
	Visuals.sphere(self, size * 1.6, Vector3.ZERO, Visuals.transparent_mat(Color(1.0, 0.4, 0.05, 0.45), 3.0))
	_light = OmniLight3D.new()
	_light.light_color = COLOR
	_light.light_energy = 2.2
	_light.omni_range = 4.5
	add_child(_light)
	# Traînée : flammes qui restent en arrière (repère du monde) et s'éteignent.
	_trail = CPUParticles3D.new()
	_trail.local_coords = false
	_trail.amount = 48
	_trail.lifetime = 0.45
	_trail.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_trail.emission_sphere_radius = size * 0.8
	_trail.gravity = Vector3(0, 1.2, 0)
	_trail.initial_velocity_max = 0.4
	_trail.scale_amount_min = 0.6
	_trail.scale_amount_max = 1.3
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 0.55, 0.08, 0.9))
	fade.add_point(0.35, Color(0.95, 0.22, 0.0, 0.7))
	fade.set_color(1, Color(0.25, 0.02, 0.0, 0.0))
	_trail.color_ramp = fade
	var flame := SphereMesh.new()
	flame.radius = size * 0.7
	flame.height = size * 1.4
	flame.radial_segments = 8
	flame.rings = 4
	# Flammes en mélange additif : la couleur de chaque particule (dégradé jaune → orange → rouge sombre) s'ajoute.
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	flame.material = m
	_trail.mesh = flame
	add_child(_trail)


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	var k := minf(1.0, _t / FLIGHT)
	global_position = from.lerp(to, k) + Vector3(0, sin(k * PI) * 0.4, 0) # léger arc
	if k >= 1.0:
		_explode()


## Impact : gerbe de braises, éclair de lumière, puis la boule disparaît (la traînée finit de s'éteindre).
func _explode() -> void:
	_done = true
	for c in get_children():
		if c is MeshInstance3D:
			c.visible = false
	_trail.emitting = false
	var burst := CPUParticles3D.new()
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.amount = 28
	burst.lifetime = 0.6
	burst.direction = Vector3.UP
	burst.spread = 180.0
	burst.initial_velocity_min = 2.0
	burst.initial_velocity_max = 4.5
	burst.gravity = Vector3(0, -6.0, 0)
	burst.scale_amount_min = 0.5
	burst.scale_amount_max = 1.2
	var ember := SphereMesh.new()
	ember.radius = 0.05
	ember.height = 0.1
	ember.material = Visuals.glow_mat(Color(1.0, 0.6, 0.15), 5.0)
	burst.mesh = ember
	burst.emitting = true
	add_child(burst)
	var tw := create_tween()
	tw.tween_property(_light, "light_energy", 5.0, 0.05)
	tw.tween_property(_light, "light_energy", 0.0, 0.4)
	get_tree().create_timer(0.9, false).timeout.connect(queue_free)
