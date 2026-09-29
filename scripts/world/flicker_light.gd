class_name FlickerLight
extends OmniLight3D
## Lumière de torche / lanterne / cheminée qui vacille.

var base_energy := 1.5
var flicker_amount := 0.25
var _t := randf() * 100.0
var _speed := randf_range(7.0, 11.0)


func _process(delta: float) -> void:
	_t += delta * _speed
	var n := sin(_t) * 0.5 + sin(_t * 2.3 + 1.7) * 0.3 + sin(_t * 5.1) * 0.2
	light_energy = base_energy * (1.0 + n * flicker_amount)
