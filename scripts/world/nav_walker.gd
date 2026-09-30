class_name NavWalker
extends NavigationAgent3D
## Fait marcher son parent (Node3D) vers une destination en suivant le maillage de
## navigation (les tables sont contournées). S'il n'y a pas de navigation (donjon),
## il avance tout droit.
## Le chemin est demandé directement au serveur de navigation puis suivi « à plat » :
## le maillage est cuit au-dessus du plancher (y ≈ 0,5) alors que les personnages marchent
## à y = 0, et le suivi intégré de NavigationAgent3D, qui compare les distances en 3D,
## restait bloqué sur le premier point.

signal arrived

var speed := 1.4
var walking := false
## Direction du dernier pas (pour orienter le personnage).
var direction := Vector3.ZERO

var _body: Node3D
var _straight := false
var _target := Vector3.ZERO
var _path: PackedVector3Array = PackedVector3Array()
var _index := 0
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
	_path = PackedVector3Array()
	_index = 0
	_no_path_frames = 0


func stop() -> void:
	walking = false
	direction = Vector3.ZERO


## Chemin courant (points ramenés au sol).
func current_path() -> PackedVector3Array:
	return _path


func _request_path() -> bool:
	var map := get_navigation_map()
	if not map.is_valid() or NavigationServer3D.map_get_iteration_id(map) == 0:
		return false
	var from := _body.global_position
	var raw := NavigationServer3D.map_get_path(map, from + Vector3(0, 0.5, 0), _target + Vector3(0, 0.5, 0), true)
	if raw.is_empty():
		return false
	_path = PackedVector3Array()
	for p in raw:
		_path.append(Vector3(p.x, 0.0, p.z))
	_path.append(_target) # la destination exacte (le chemin s'arrête au bord du maillage)
	_index = 0
	return true


func _physics_process(delta: float) -> void:
	if not walking or _body == null:
		return
	var here := Vector3(_body.global_position.x, 0.0, _body.global_position.z)
	var next := _target
	if not _straight:
		if _path.is_empty() and not _request_path():
			# Pas de maillage de navigation (ou pas encore prêt) : ligne droite.
			_no_path_frames += 1
			if _no_path_frames > 10:
				_straight = true
			return
		if not _straight:
			while _index < _path.size() - 1 and here.distance_to(_path[_index]) <= (0.1 if _index == 0 else path_desired_distance):
				_index += 1
			next = _path[mini(_index, _path.size() - 1)]
	var to := next - here
	if here.distance_to(_target) <= target_desired_distance and (_straight or _index >= _path.size() - 1):
		_finish()
		return
	if to.length() < 0.001:
		_index += 1
		return
	direction = to.normalized()
	_body.global_position += direction * minf(to.length(), speed * delta)
	_body.global_position.y = 0.0


func _finish() -> void:
	walking = false
	direction = Vector3.ZERO
	arrived.emit()
