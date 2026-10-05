class_name MistTrail
extends Node3D
## Trait brumeux violet entre deux points (Riff black metal de la Batguitare, à la place de l'éclair du Riff électrique) :
## un filet de brume lumineuse qui se dissipe, et des volutes de brume qui s'en échappent en dérivant.

const LIFE := 1.4
const CORE_LIFE := 0.45

var from := Vector3.ZERO
var to := Vector3.ZERO
## Épaisseur (grossit avec les notes du riff).
var width := 0.12
var color := Color(0.62, 0.3, 1.0)


static func spawn(parent: Node, a: Vector3, b: Vector3, trail_width: float = 0.12, trail_color: Color = Color(0.62, 0.3, 1.0)) -> MistTrail:
	var m := MistTrail.new()
	m.from = a
	m.to = b
	m.width = trail_width
	m.color = trail_color
	parent.add_child(m)
	return m


func _ready() -> void:
	var seg := to - from
	var length := maxf(seg.length(), 0.05)
	global_position = (from + to) * 0.5
	if seg.length() > 0.01:
		look_at(to, Vector3.UP if absf(seg.normalized().y) < 0.95 else Vector3.RIGHT)
	# Filet de brume : un fuseau translucide, lumineux, étiré de `from` à `to`, qui s'estompe vite.
	var core := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = width * 0.5
	cyl.bottom_radius = width * 0.5
	cyl.height = length
	cyl.radial_segments = 10
	cyl.rings = 1
	core.mesh = cyl
	core.rotation_degrees = Vector3(90, 0, 0) # axe du cylindre le long de -Z (direction de look_at)
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var core_mat := Visuals.transparent_mat(Color(color.r, color.g, color.b, 0.55), 2.5)
	core.material_override = core_mat
	add_child(core)
	var tw := create_tween()
	tw.tween_property(core_mat, "albedo_color:a", 0.0, CORE_LIFE).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(core, "scale", Vector3(2.6, 1.0, 2.6), CORE_LIFE)
	# Volutes de brume le long du trait, qui gonflent, dérivent vers le haut et s'évanouissent.
	var puffs := CPUParticles3D.new()
	puffs.one_shot = true
	puffs.explosiveness = 0.85
	puffs.amount = clampi(roundi(length * 12.0), 12, 90)
	puffs.lifetime = 1.1
	puffs.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	puffs.emission_box_extents = Vector3(width * 0.6, width * 0.6, length * 0.5)
	puffs.direction = Vector3.UP
	puffs.spread = 70.0
	puffs.gravity = Vector3(0, 0.35, 0)
	puffs.initial_velocity_min = 0.1
	puffs.initial_velocity_max = 0.45
	puffs.damping_min = 0.3
	puffs.damping_max = 0.6
	puffs.scale_amount_min = 0.8
	puffs.scale_amount_max = 1.6
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.35))
	grow.add_point(Vector2(1.0, 1.0))
	puffs.scale_amount_curve = grow
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.75))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	puffs.color_ramp = fade
	# Volute : un disque flou (dégradé radial) toujours face à la caméra, sans bord net.
	var puff := QuadMesh.new()
	puff.size = Vector2.ONE * (0.55 + width * 1.5)
	puff.material = _puff_material(color)
	puffs.mesh = puff
	puffs.emitting = true
	add_child(puffs)
	var glow := OmniLight3D.new()
	glow.light_color = color
	glow.light_energy = 1.4
	glow.omni_range = minf(6.0, 2.0 + length * 0.4)
	add_child(glow)
	tw.parallel().tween_property(glow, "light_energy", 0.0, LIFE * 0.7)
	get_tree().create_timer(LIFE, false).timeout.connect(queue_free)


static var _puff_tex: GradientTexture2D


## Matériau des volutes : brume violette floue, lumineuse, en billboard (couleur et transparence des particules).
static func _puff_material(c: Color) -> StandardMaterial3D:
	if _puff_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.45, Color(1, 1, 1, 0.45))
		_puff_tex = GradientTexture2D.new()
		_puff_tex.gradient = g
		_puff_tex.fill = GradientTexture2D.FILL_RADIAL
		_puff_tex.fill_from = Vector2(0.5, 0.5)
		_puff_tex.fill_to = Vector2(0.5, 0.0)
		_puff_tex.width = 64
		_puff_tex.height = 64
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _puff_tex
	m.albedo_color = Color(c.r * 1.3, c.g * 1.2, c.b * 1.3, 0.4)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m
