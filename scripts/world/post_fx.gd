class_name PostFx
extends CanvasLayer
## Applique le shader de post-traitement plein écran (sous l'interface).

const SHADER := preload("res://shaders/post_fx.gdshader")


func _ready() -> void:
	layer = 1
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = SHADER
	rect.material = m
	add_child(rect)
