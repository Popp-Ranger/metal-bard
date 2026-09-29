class_name Shockwave
extends Node3D
## Onde de choc sonore : anneaux qui s'élargissent autour du héros.

var radius := 5.0
var duration := 0.45


static func spawn(parent: Node, pos: Vector3, wave_radius: float) -> void:
	var w := Shockwave.new()
	w.position = pos + Vector3(0, 0.4, 0)
	w.radius = wave_radius
	parent.add_child(w)


func _ready() -> void:
	for i in 3:
		var mat := Visuals.transparent_mat(Color(0.55, 0.35, 1.0, 0.55), 1.0)
		var ring := Visuals.torus(self, 0.94, 1.0, Vector3.ZERO, mat)
		ring.scale = Vector3(0.3, 0.6, 0.3)
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var tw := create_tween().set_parallel(true)
		var delay := i * 0.07
		tw.tween_property(ring, "scale", Vector3(radius, 0.6, radius), duration).set_delay(delay) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(mat, "albedo_color:a", 0.0, duration).set_delay(delay)
	var light := OmniLight3D.new()
	light.light_color = Color(0.7, 0.5, 1.0)
	light.light_energy = 4.0
	light.omni_range = radius + 2.0
	add_child(light)
	create_tween().tween_property(light, "light_energy", 0.0, duration)
	get_tree().create_timer(duration + 0.3).timeout.connect(queue_free)
