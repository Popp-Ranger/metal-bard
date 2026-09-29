class_name OwlbearCub
extends Node3D
## Plumeau, le bébé ours-hibou. Enfermé dans une cage au fond du donjon ;
## une fois libéré, il suit le héros en sautillant.

var following := false
var _hero: Node3D
var _t := randf() * 10.0
var _visual: Node3D


func _ready() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	var fur := Visuals.mat(Color(0.45, 0.3, 0.18), 0.95)
	var feathers := Visuals.mat(Color(0.85, 0.8, 0.7), 0.9)
	Visuals.sphere(_visual, 0.35, Vector3(0, 0.4, 0), fur, Vector3(1.0, 1.05, 0.95))
	Visuals.sphere(_visual, 0.24, Vector3(0, 0.35, 0.2), feathers, Vector3(1.0, 1.1, 0.5))
	Visuals.sphere(_visual, 0.26, Vector3(0, 0.85, 0.03), fur)
	Visuals.sphere(_visual, 0.2, Vector3(0, 0.84, 0.17), feathers, Vector3(1.1, 1.0, 0.5)) # disque facial
	for s: float in [-1.0, 1.0]:
		Visuals.sphere(_visual, 0.075, Vector3(0.08 * s, 0.88, 0.25), Visuals.mat(Color(0.95, 0.75, 0.2), 0.3))
		Visuals.sphere(_visual, 0.04, Vector3(0.08 * s, 0.88, 0.3), Visuals.mat(Color.BLACK, 0.2))
		Visuals.cylinder(_visual, 0.0, 0.05, 0.16, Vector3(0.15 * s, 1.1, 0.0), fur, Vector3(0, 0, -20 * s)) # aigrettes
		Visuals.sphere(_visual, 0.1, Vector3(0.3 * s, 0.45, 0.05), fur, Vector3(0.6, 1.2, 0.8)) # petites ailes
	Visuals.cylinder(_visual, 0.0, 0.04, 0.1, Vector3(0, 0.8, 0.3), Visuals.mat(Color(0.9, 0.6, 0.2)), Vector3(90, 0, 0)) # bec


func celebrate() -> void:
	var hearts := CPUParticles3D.new()
	hearts.position.y = 1.2
	hearts.amount = 12
	hearts.one_shot = true
	hearts.explosiveness = 0.8
	hearts.lifetime = 1.5
	hearts.gravity = Vector3(0, 1.0, 0)
	hearts.initial_velocity_min = 0.5
	hearts.initial_velocity_max = 1.5
	hearts.direction = Vector3.UP
	hearts.spread = 60.0
	var m := SphereMesh.new()
	m.radius = 0.06
	m.height = 0.12
	m.material = Visuals.glow_mat(Color(1.0, 0.35, 0.5), 3.0)
	hearts.mesh = m
	add_child(hearts)
	hearts.emitting = true


func _process(delta: float) -> void:
	_t += delta
	var hop := absf(sin(_t * (7.0 if following else 3.0))) * (0.2 if following else 0.06)
	_visual.position.y = hop
	if not following:
		return
	if _hero == null or not is_instance_valid(_hero):
		_hero = get_tree().get_first_node_in_group("hero") as Node3D
		return
	var to := _hero.global_position - global_position
	to.y = 0.0
	var d := to.length()
	if d > 1.6:
		global_position += to.normalized() * minf(d - 1.6, delta * 6.0)
	if d > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), delta * 8.0)
