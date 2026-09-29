class_name OwlbearCub
extends Node3D
## Plumeau, le bébé ours-hibou. Enfermé dans une cage au fond du donjon ;
## une fois libéré, il suit le héros en sautillant.

var following := false
var _target: Node3D
var _speed := 6.0
var _repath := 0.0
var _walker: NavWalker
var _t := randf() * 10.0
var _visual: Node3D


func _ready() -> void:
	_walker = NavWalker.new()
	add_child(_walker)
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


## Suit une cible (le héros par défaut, ou Gérald à la taverne) en contournant les obstacles.
func follow(target: Node3D = null, speed: float = 6.0) -> void:
	following = true
	_target = target
	_speed = speed


func _process(delta: float) -> void:
	_t += delta
	var moving := _walker != null and _walker.walking
	var hop := absf(sin(_t * (7.0 if moving else 3.0))) * (0.2 if moving else 0.06)
	_visual.position.y = hop
	if not following:
		return
	if _target == null or not is_instance_valid(_target):
		_target = get_tree().get_first_node_in_group("hero") as Node3D
		return
	var to := _target.global_position - global_position
	to.y = 0.0
	var d := to.length()
	_repath -= delta
	if d > 1.6 and _repath <= 0.0:
		_repath = 0.4
		_walker.walk_to(_target.global_position - to.normalized() * 1.2, _speed)
	elif d <= 1.4 and _walker.walking:
		_walker.stop()
	var look := _walker.direction if moving else to
	if look.length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(look.x, look.z), delta * 8.0)
