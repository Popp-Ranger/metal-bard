class_name TidalWave
extends MeshInstance3D
## Vague déferlante de Gloubah : un mur d'eau en arc de cercle qui s'élargit.
## Phase 1 : cône de 110° orienté vers le héros (esquive latérale).
## Phase 2 : anneau complet avec une brèche de 70° (il faut trouver la brèche).

var center := Vector3.ZERO
var aim_angle := 0.0 # angle (radians, plan XZ) du centre de l'arc / de la brèche
var arc_width := deg_to_rad(110.0)
var is_ring := false
var gap_width := deg_to_rad(70.0)
var speed := 6.5
var max_radius := 13.0
var damage := 10
var height := 1.0

var _radius := 0.6
var _hit := false
var _im := ImmediateMesh.new()
var _mat: StandardMaterial3D


func _ready() -> void:
	mesh = _im
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mat = Visuals.transparent_mat(Color(0.25, 0.75, 0.7, 0.6), 1.2)
	_mat.vertex_color_use_as_albedo = true


func _physics_process(delta: float) -> void:
	_radius += speed * delta
	if _radius >= max_radius:
		queue_free()
		return
	_check_hit()
	_draw()


func _covers(angle: float) -> bool:
	var diff := absf(angle_difference(aim_angle, angle))
	if is_ring:
		return diff > gap_width * 0.5
	return diff < arc_width * 0.5


func _check_hit() -> void:
	if _hit:
		return
	for n in get_tree().get_nodes_in_group("hero"):
		var h := n as Hero
		if h == null or h.dead:
			continue
		var to := h.global_position - center
		to.y = 0.0
		if absf(to.length() - _radius) < 0.55 and _covers(atan2(to.z, to.x)):
			_hit = true
			h.take_hit(damage, center)
			Events.notify("Emporté par la vague !", Events.COLOR_BAD)


func _draw() -> void:
	_im.clear_surfaces()
	var fade := 1.0 - _radius / max_radius
	var segments := 48
	var start := aim_angle - arc_width * 0.5
	var span := arc_width
	if is_ring:
		start = aim_angle + gap_width * 0.5
		span = TAU - gap_width
	_im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, _mat)
	for i in segments + 1:
		var a := start + span * float(i) / segments
		var dir := Vector3(cos(a), 0.0, sin(a))
		var crest := 0.8 + 0.2 * sin(a * 9.0 + _radius * 3.0)
		_im.surface_set_color(Color(0.1, 0.35, 0.4, 0.75 * fade))
		_im.surface_add_vertex(center + dir * (_radius - 0.5) + Vector3(0, 0.05, 0))
		_im.surface_set_color(Color(0.7, 1.0, 0.95, 0.9 * fade))
		_im.surface_add_vertex(center + dir * (_radius + 0.2) + Vector3(0, height * crest, 0))
	_im.surface_end()
