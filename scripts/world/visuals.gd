class_name Visuals
extends RefCounted
## Fabrique de formes, matériaux et éclairages. Tous les décors et personnages
## de ce prototype sont construits à partir de primitives : il suffira plus tard de
## remplacer ces constructions par des modèles .glb (Blender, Kenney, Synty...).

const STONE_SHADER := preload("res://shaders/stone_wall.gdshader")
const PORTAL_SHADER := preload("res://shaders/portal.gdshader")

static var _mat_cache := {}


static func mat(color: Color, roughness: float = 0.85, metallic: float = 0.0) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f" % [color.to_html(), roughness, metallic]
	if _mat_cache.has(key):
		var cached: StandardMaterial3D = _mat_cache[key]
		return cached
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	_mat_cache[key] = m
	return m


## Matériau lumineux (non mis en cache : souvent animé).
static func glow_mat(color: Color, energy: float = 2.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color.darkened(0.3)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


static func transparent_mat(color: Color, emission_energy: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if emission_energy > 0.0:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		m.emission_enabled = true
		m.emission = Color(color.r, color.g, color.b)
		m.emission_energy_multiplier = emission_energy
	return m


static func stone_material(cut_enabled: bool, stone: Color = Color(0.23, 0.22, 0.25)) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = STONE_SHADER
	m.set_shader_parameter("stone_color", stone)
	m.set_shader_parameter("cut_radius", 3.4 if cut_enabled else 0.0)
	return m


static func portal_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = PORTAL_SHADER
	return m


static func _add(parent: Node3D, mesh: Mesh, pos: Vector3, material: Material, rot_deg: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.material_override = material
	parent.add_child(mi)
	return mi


static func box(parent: Node3D, size: Vector3, pos: Vector3, material: Material,
		rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	return _add(parent, m, pos, material, rot_deg)


static func cylinder(parent: Node3D, top_radius: float, bottom_radius: float, height: float,
		pos: Vector3, material: Material, rot_deg: Vector3 = Vector3.ZERO, sides: int = 16) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = top_radius
	m.bottom_radius = bottom_radius
	m.height = height
	m.radial_segments = sides
	return _add(parent, m, pos, material, rot_deg)


static func sphere(parent: Node3D, radius: float, pos: Vector3, material: Material,
		scale: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = 16
	m.rings = 8
	var mi := _add(parent, m, pos, material, Vector3.ZERO)
	mi.scale = scale
	return mi


static func capsule(parent: Node3D, radius: float, height: float, pos: Vector3, material: Material,
		rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = maxf(height, radius * 2.0)
	m.radial_segments = 12
	m.rings = 4
	return _add(parent, m, pos, material, rot_deg)


static func torus(parent: Node3D, inner: float, outer: float, pos: Vector3, material: Material,
		rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var m := TorusMesh.new()
	m.inner_radius = inner
	m.outer_radius = outer
	m.rings = 32
	m.ring_segments = 8
	return _add(parent, m, pos, material, rot_deg)


## Boîte de collision statique (couche « monde »).
static func solid(parent: Node3D, size: Vector3, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = pos
	body.rotation_degrees = rot_deg
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	parent.add_child(body)
	return body


static func solid_cylinder(parent: Node3D, radius: float, height: float, pos: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = pos
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	col.shape = shape
	body.add_child(col)
	parent.add_child(body)
	return body


static func flicker_light(parent: Node3D, pos: Vector3, color: Color, energy: float, light_range: float,
		shadows: bool = false) -> FlickerLight:
	var l := FlickerLight.new()
	l.position = pos
	l.light_color = color
	l.base_energy = energy
	l.light_energy = energy
	l.omni_range = light_range
	l.omni_attenuation = 1.3
	l.shadow_enabled = shadows
	parent.add_child(l)
	return l


static func label(parent: Node3D, text: String, pos: Vector3, color: Color, size: int = 40) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.position = pos
	l.modulate = color
	l.font_size = size
	l.outline_size = 10
	l.outline_modulate = Color(0, 0, 0, 0.85)
	l.pixel_size = 0.008
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = false
	parent.add_child(l)
	return l


## Environnement sombre (« dungeon » ou « tavern »).
static func make_environment(kind: String) -> WorldEnvironment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.015, 0.012, 0.018)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	if kind == "dungeon":
		env.ambient_light_color = Color(0.42, 0.44, 0.55)
		env.ambient_light_energy = 0.65
	else:
		env.ambient_light_color = Color(0.6, 0.55, 0.5)
		env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.3
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 0.9
	env.ssao_enabled = true
	env.ssao_intensity = 2.5
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.1
	env.adjustment_saturation = 0.85
	var we := WorldEnvironment.new()
	we.environment = env
	return we
