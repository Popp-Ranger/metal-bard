class_name OwlbearCub
extends Node3D
## Plumeau, le bébé hibours de Gérald. Enfermé dans une cage au fond du donjon ;
## une fois libéré, il suit le héros. Modèle 3D importé (bébé hibours debout, art/pnj « hibours », 1,2 m) : repos,
## marche et course selon sa vitesse (CharacterSkin).

var following := false
var _target: Node3D
var _speed := 6.0
var _repath := 0.0
var _walker: NavWalker
var _t := randf() * 10.0
var skin: CharacterSkin


func _ready() -> void:
	_walker = NavWalker.new()
	add_child(_walker)
	skin = CharacterSkin.create("hibours", "pnj")
	add_child(skin)


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
	if skin != null:
		skin.step(delta, moving, _speed if moving else 0.0)
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
		# Destination ramenée sur la zone praticable : jamais dans un tonneau ou sous une table.
		_walker.walk_to(_walker.snap(_target.global_position - to.normalized() * 1.2), _speed)
	elif d <= 1.4 and _walker.walking:
		_walker.stop()
	elif not _walker.walking and _repath <= 0.0:
		_repath = 0.4
		var free := _walker.snap(global_position)
		if Vector2(free.x - global_position.x, free.z - global_position.z).length() > 0.15:
			_walker.walk_to(free, _speed) # posé dans un meuble (apparition) : il en sort
	var look := _walker.direction if moving else to
	if look.length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(look.x, look.z), delta * 8.0)
