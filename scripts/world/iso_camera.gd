class_name IsoCamera
extends Camera3D
## Caméra isométrique orthographique qui suit le héros (vue « Diablo »).
## Molette : zoom. Secousses via Events.camera_shake.

const OFFSET := Vector3(14.0, 19.8, 14.0) # 45° de lacet, ~45° de tangage
## Directions « écran » projetées au sol (utilisées pour les déplacements ZQSD).
const SCREEN_UP := Vector3(-0.70710678, 0.0, -0.70710678)
const SCREEN_RIGHT := Vector3(0.70710678, 0.0, -0.70710678)

var target: Node3D
var zoom := 16.0
var _shake_time := 0.0
var _shake_strength := 0.0


func _ready() -> void:
	projection = PROJECTION_ORTHOGONAL
	size = zoom
	near = 0.5
	far = 120.0
	current = true
	Events.camera_shake.connect(shake)


func snap_to_target() -> void:
	if target == null:
		return
	global_position = target.global_position + OFFSET
	look_at(target.global_position, Vector3.UP)


func shake(strength: float, duration: float) -> void:
	_shake_strength = maxf(_shake_strength, strength)
	_shake_time = maxf(_shake_time, duration)


func _process(delta: float) -> void:
	size = lerpf(size, zoom, 1.0 - exp(-10.0 * delta))
	if target != null and is_instance_valid(target):
		var desired := target.global_position + OFFSET
		global_position = global_position.lerp(desired, 1.0 - exp(-7.0 * delta))
	if _shake_time > 0.0:
		_shake_time -= delta
		h_offset = randf_range(-1.0, 1.0) * _shake_strength
		v_offset = randf_range(-1.0, 1.0) * _shake_strength
	else:
		_shake_strength = 0.0
		h_offset = 0.0
		v_offset = 0.0


func _unhandled_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed:
		return
	if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
		zoom = clampf(zoom - 1.0, 9.0, 24.0)
	elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		zoom = clampf(zoom + 1.0, 9.0, 24.0)


## Point du sol (y = 0) situé sous le curseur de la souris.
func mouse_ground_point() -> Vector3:
	var mp := get_viewport().get_mouse_position()
	var origin := project_ray_origin(mp)
	var dir := project_ray_normal(mp)
	var hit: Variant = Plane(Vector3.UP, 0.0).intersects_ray(origin, dir)
	if hit == null:
		return target.global_position if target != null else Vector3.ZERO
	return hit as Vector3
