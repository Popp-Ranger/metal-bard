class_name DemonPortal
extends Node3D
## Portail démoniaque rouge sang (sous-sol de la taverne) : anneau de fer hérissé de pointes,
## tourbillon écarlate, brume sombre au ras du sol et cinq tentacules qui en sortent en
## ondulant. Il ne mène nulle part... pour l'instant.

const TENTACLES := 5
const SEGMENTS := 9
const SEG_LEN := 0.3

var interact_radius := 3.0
var _tentacles: Array[Array] = [] # chaque tentacule = liste de pivots
var _phases: Array[float] = []
var _t := 0.0
var _swirl: MeshInstance3D


func _ready() -> void:
	add_to_group("interactable")
	var iron := Visuals.mat(Color(0.08, 0.06, 0.06), 0.45, 0.8)
	var blood_glow := Visuals.glow_mat(Color(0.85, 0.02, 0.02), 3.5)
	var center := Vector3(0, 2.0, 0)
	# Tourbillon rouge sang (shader du portail, recoloré).
	var disc := CylinderMesh.new()
	disc.top_radius = 1.45
	disc.bottom_radius = 1.45
	disc.height = 0.02
	_swirl = MeshInstance3D.new()
	_swirl.mesh = disc
	_swirl.position = center
	_swirl.rotation_degrees = Vector3(90, 0, 0)
	var swirl_mat := Visuals.portal_material()
	swirl_mat.set_shader_parameter("color_a", Color(0.75, 0.0, 0.02))
	swirl_mat.set_shader_parameter("color_b", Color(1.0, 0.3, 0.05))
	swirl_mat.set_shader_parameter("intensity", 0.9)
	_swirl.material_override = swirl_mat
	_swirl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_swirl)
	Visuals.sphere(self, 1.35, center + Vector3(0, 0, -0.05), Visuals.mat(Color(0.02, 0.0, 0.0), 1.0), Vector3(1.0, 1.0, 0.05))
	# Anneau de fer et pointes.
	Visuals.torus(self, 1.4, 1.7, center, iron, Vector3(90, 0, 0))
	Visuals.torus(self, 1.38, 1.46, center + Vector3(0, 0, 0.06), blood_glow, Vector3(90, 0, 0))
	for k in 12:
		var a := TAU * k / 12.0
		var dir := Vector3(cos(a), sin(a), 0)
		var spike := Visuals.cylinder(self, 0.0, 0.1, 0.55, center + dir * 1.9, iron, Vector3.ZERO, 6)
		spike.basis = Basis(Vector3(0, 0, 1).cross(dir).normalized(), dir, Vector3(0, 0, 1))
	# Socle : deux pieds en os et une flaque de sang.
	for side: float in [-1.0, 1.0]:
		Visuals.box(self, Vector3(0.35, 0.9, 0.5), Vector3(1.2 * side, 0.45, 0), iron)
		Visuals.sphere(self, 0.22, Vector3(1.2 * side, 0.95, 0.2), Visuals.mat(Color(0.8, 0.75, 0.62)))
	Visuals.cylinder(self, 2.2, 2.4, 0.02, Vector3(0, 0.015, 1.2), Visuals.mat(Color(0.25, 0.0, 0.01), 0.15), Vector3.ZERO, 28)
	Visuals.cylinder(self, 0.6, 0.7, 0.02, Vector3(1.8, 0.02, 2.6), Visuals.mat(Color(0.3, 0.01, 0.02), 0.1), Vector3.ZERO, 14)
	_build_tentacles(center)
	_build_fog()
	var light := Visuals.flicker_light(self, center + Vector3(0, 0, 1.4), Color(1.0, 0.08, 0.04), 4.0, 9.0)
	light.flicker_amount = 0.45
	var under := OmniLight3D.new()
	under.position = Vector3(0, 0.3, 1.5)
	under.light_color = Color(0.7, 0.0, 0.0)
	under.light_energy = 1.5
	under.omni_range = 5.0
	add_child(under)


func _build_tentacles(center: Vector3) -> void:
	var skin := Visuals.mat(Color(0.22, 0.03, 0.07), 0.3)
	var sucker := Visuals.mat(Color(0.75, 0.45, 0.5), 0.5)
	for i in TENTACLES:
		var a := TAU * i / TENTACLES + 0.4
		var root := Node3D.new()
		root.position = center + Vector3(cos(a) * 0.85, sin(a) * 0.85, 0.05)
		# Sortent vers l'avant (+Z) en s'écartant du centre.
		root.basis = Basis.looking_at(Vector3(cos(a) * 0.6, sin(a) * 0.6, 1.0).normalized(), Vector3.UP) \
			* Basis(Vector3.RIGHT, -PI * 0.5)
		add_child(root)
		var chain: Array = []
		var parent: Node3D = root
		for s in SEGMENTS:
			var pivot := Node3D.new()
			pivot.position = Vector3(0, SEG_LEN if s > 0 else 0.0, 0)
			parent.add_child(pivot)
			var r := lerpf(0.2, 0.04, float(s) / SEGMENTS)
			Visuals.capsule(pivot, r, SEG_LEN + r, Vector3(0, SEG_LEN * 0.5, 0), skin)
			if s % 2 == 0:
				Visuals.sphere(pivot, r * 0.45, Vector3(0, SEG_LEN * 0.5, r * 0.85), sucker, Vector3(1, 1, 0.5))
			chain.append(pivot)
			parent = pivot
		_tentacles.append(chain)
		_phases.append(randf() * TAU)


## Brume sombre et rougeoyante qui rampe au sol autour du portail.
func _build_fog() -> void:
	for layer in 2:
		var fog := CPUParticles3D.new()
		fog.position = Vector3(0, 0.4 + layer * 0.5, 1.2)
		fog.amount = 26
		fog.lifetime = 6.0
		fog.preprocess = 6.0
		fog.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		fog.emission_box_extents = Vector3(4.5, 0.2, 3.5)
		fog.gravity = Vector3.ZERO
		fog.initial_velocity_min = 0.05
		fog.initial_velocity_max = 0.25
		fog.direction = Vector3(1, 0, 0.3)
		fog.spread = 180.0
		fog.scale_amount_min = 2.5
		fog.scale_amount_max = 4.5
		var quad := QuadMesh.new()
		quad.size = Vector2(1.0, 1.0)
		var m := StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.albedo_color = Color(0.12, 0.0, 0.02, 0.22) if layer == 0 else Color(0.05, 0.02, 0.03, 0.28)
		m.albedo_texture = _soft_texture()
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		quad.material = m
		fog.mesh = quad
		fog.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(fog)
		fog.emitting = true


static var _soft: GradientTexture2D


## Tache ronde et floue (pour la brume).
static func _soft_texture() -> GradientTexture2D:
	if _soft == null:
		_soft = GradientTexture2D.new()
		_soft.fill = GradientTexture2D.FILL_RADIAL
		_soft.fill_from = Vector2(0.5, 0.5)
		_soft.fill_to = Vector2(1.0, 0.5)
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		_soft.gradient = g
		_soft.width = 64
		_soft.height = 64
	return _soft


func _process(delta: float) -> void:
	_t += delta
	_swirl.rotation.y += delta * 0.3
	for i in _tentacles.size():
		var chain: Array = _tentacles[i]
		var ph: float = _phases[i]
		for s in chain.size():
			var p: Node3D = chain[s]
			var k := float(s + 1) / chain.size()
			p.rotation.x = sin(_t * 1.6 + ph + s * 0.55) * 0.28 * k + 0.08
			p.rotation.z = cos(_t * 1.1 + ph * 1.3 + s * 0.45) * 0.22 * k


func get_prompt() -> String:
	return "Observer le portail démoniaque"


func interact(_by: Node3D) -> void:
	Sfx.play("croak", -10.0, 0.0)
	Events.camera_shake.emit(0.15, 0.4)
	Events.notify("Une chaleur infernale s'échappe du portail. Les tentacules frémissent à votre approche... Il ne s'ouvrira pas aujourd'hui.", Color(1.0, 0.35, 0.3))
