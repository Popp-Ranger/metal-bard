class_name Telegraph
extends MeshInstance3D
## Zone d'impact rouge au sol, qui se remplit avant qu'une attaque ne frappe.

var radius := 2.5
var duration := 1.0
var _mat: StandardMaterial3D


static func spawn(parent: Node, pos: Vector3, zone_radius: float, time: float) -> Telegraph:
	var t := Telegraph.new()
	t.position = Vector3(pos.x, 0.04, pos.z)
	t.radius = zone_radius
	t.duration = time
	parent.add_child(t)
	return t


func _ready() -> void:
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.02
	disc.radial_segments = 40
	mesh = disc
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mat = Visuals.transparent_mat(Color(1.0, 0.15, 0.1, 0.15), 1.5)
	material_override = _mat
	var tw := create_tween()
	tw.tween_property(_mat, "albedo_color:a", 0.55, duration)
	tw.tween_callback(queue_free)
