class_name ArcBolt
extends MeshInstance3D
## Éclair électrique en zigzag entre deux points (ruban face caméra, qui crépite).

const VIEW_DIR := Vector3(0.577, 0.577, 0.577) # direction approximative vers la caméra iso

var from := Vector3.ZERO
var to := Vector3.ZERO
var width := 0.12
var life := 0.3
var jitter := 0.45
var color := Color(0.55, 0.85, 1.0)

var _im := ImmediateMesh.new()
var _mat: StandardMaterial3D
var _t := 0.0
var _redraw := 0.0


static func spawn(parent: Node, a: Vector3, b: Vector3, bolt_width: float = 0.12,
		duration: float = 0.3, bolt_color: Color = Color(0.55, 0.85, 1.0)) -> ArcBolt:
	var bolt := ArcBolt.new()
	bolt.from = a
	bolt.to = b
	bolt.width = bolt_width
	bolt.life = duration
	bolt.color = bolt_color
	parent.add_child(bolt)
	return bolt


func _ready() -> void:
	mesh = _im
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	_mat.vertex_color_use_as_albedo = true
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var flash := OmniLight3D.new()
	flash.light_color = color
	flash.light_energy = 3.0
	flash.omni_range = 5.0
	flash.position = to
	add_child(flash)
	create_tween().tween_property(flash, "light_energy", 0.0, life)
	_build()


func _process(delta: float) -> void:
	_t += delta
	_redraw -= delta
	if _t >= life:
		queue_free()
		return
	if _redraw <= 0.0:
		_redraw = 0.04
		_build()
	_mat.albedo_color.a = 1.0 - _t / life


func _build() -> void:
	_im.clear_surfaces()
	var seg := to - from
	var length := seg.length()
	if length < 0.01:
		return
	var steps := maxi(3, int(length / 0.6))
	var side := seg.normalized().cross(VIEW_DIR).normalized()
	var up := seg.normalized().cross(side).normalized()
	var points: Array[Vector3] = []
	for i in steps + 1:
		var k := float(i) / steps
		var p := from.lerp(to, k)
		if i > 0 and i < steps:
			p += side * randf_range(-jitter, jitter) + up * randf_range(-jitter, jitter) * 0.5
		points.append(p)
	_draw_strip(points, width * 0.45, 1.0, true) # cœur blanc
	_draw_strip(points, width, 0.8)
	_draw_strip(points, width * 2.6, 0.12) # halo
	# Ramification aléatoire.
	if points.size() > 3:
		var start := points[randi_range(1, points.size() - 2)]
		var branch: Array[Vector3] = [start]
		for i in 3:
			branch.append(branch[-1] + side * randf_range(-0.5, 0.5) + seg.normalized() * 0.35 + Vector3(0, -0.2, 0))
		_draw_strip(branch, width * 0.6, 0.7)


func _draw_strip(points: Array[Vector3], w: float, alpha: float, core: bool = false) -> void:
	var c := Color(0.9, 0.95, 1.0, alpha) if core else Color(color.r * 0.6, color.g * 0.8, color.b, alpha)
	_im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, _mat)
	for i in points.size():
		var dir := (points[mini(i + 1, points.size() - 1)] - points[maxi(i - 1, 0)]).normalized()
		var off := dir.cross(VIEW_DIR).normalized() * w * 0.5
		_im.surface_set_color(c)
		_im.surface_add_vertex(points[i] - off)
		_im.surface_set_color(c)
		_im.surface_add_vertex(points[i] + off)
	_im.surface_end()
