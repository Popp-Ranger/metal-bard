class_name MoveMarker
extends Node3D
## Petite zone lumineuse au sol, à l'endroit cliqué pour se déplacer (façon Diablo) :
## un anneau doré qui se resserre et s'éteint en une demi-seconde.

const LIFE := 0.55

static var _current: MoveMarker

var _ring_mat: StandardMaterial3D
var _disc_mat: StandardMaterial3D
var _light: OmniLight3D
var _t := 0.0


static func spawn(parent: Node, pos: Vector3) -> MoveMarker:
	if _current != null and is_instance_valid(_current):
		_current.queue_free()
	var m := MoveMarker.new()
	m.position = Vector3(pos.x, 0.03, pos.z)
	parent.add_child(m)
	_current = m
	return m


func _ready() -> void:
	_ring_mat = _unshaded(Color(1.0, 0.8, 0.35, 0.95))
	_disc_mat = _unshaded(Color(1.0, 0.7, 0.3, 0.35))
	var ring := Visuals.torus(self, 0.26, 0.34, Vector3.ZERO, _ring_mat)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var disc := Visuals.cylinder(self, 0.26, 0.26, 0.005, Vector3.ZERO, _disc_mat, Vector3.ZERO, 20)
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_light = OmniLight3D.new()
	_light.position.y = 0.4
	_light.light_color = Color(1.0, 0.75, 0.35)
	_light.light_energy = 1.4
	_light.omni_range = 1.6
	add_child(_light)


func _unshaded(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = color
	return m


func _process(delta: float) -> void:
	_t += delta
	var k := clampf(_t / LIFE, 0.0, 1.0)
	# Apparition en éclat (légèrement plus grand), puis l'anneau se resserre en s'éteignant.
	var s := lerpf(1.35, 0.55, ease(k, 0.6))
	scale = Vector3(s, 1.0, s)
	_ring_mat.albedo_color.a = 0.95 * (1.0 - k)
	_disc_mat.albedo_color.a = 0.35 * (1.0 - k)
	_light.light_energy = 1.4 * (1.0 - k)
	if k >= 1.0:
		queue_free()
