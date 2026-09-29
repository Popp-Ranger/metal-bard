class_name NavWalker
extends NavigationAgent3D
## Fait marcher son parent (Node3D) vers une destination en suivant le maillage de
## navigation (les tables sont contournées). S'il n'y a pas de navigation (donjon),
## il avance tout droit.

signal arrived

var speed := 1.4
var walking := false
## Direction du dernier pas (pour orienter le personnage).
var direction := Vector3.ZERO

var _body: Node3D
var _straight := false
var _target := Vector3.ZERO
var _no_path_frames := 0


func _ready() -> void:
	_body = get_parent() as Node3D
	path_desired_distance = 0.45
	target_desired_distance = 0.35
	avoidance_enabled = false


func walk_to(target: Vector3, walk_speed: float = 1.4) -> void:
	_target = Vector3(target.x, 0.0, target.z)
	target_position = _target
	speed = walk_speed
	walking = true
	_straight = false
	_no_path_frames = 0


func stop() -> void:
	walking = false
	direction = Vector3.ZERO


func _physics_process(delta: float) -> void:
	if not walking or _body == null:
		return
	var next := _target
	if not _straight:
		if is_navigation_finished():
			_finish()
			return
		next = get_next_path_position()
		# Pas de maillage de navigation (ou pas encore prêt) : ligne droite.
		if get_current_navigation_path().is_empty():
			_no_path_frames += 1
			if _no_path_frames > 10:
				_straight = true
			return
	var to := next - _body.global_position
	to.y = 0.0
	if _straight and to.length() <= target_desired_distance:
		_finish()
		return
	if to.length() < 0.001:
		return
	direction = to.normalized()
	_body.global_position += direction * minf(to.length(), speed * delta)
	_body.global_position.y = 0.0


func _finish() -> void:
	walking = false
	direction = Vector3.ZERO
	arrived.emit()
