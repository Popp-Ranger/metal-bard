class_name DamageNumber
extends Label3D
## Chiffre flottant (dégâts, soins, XP, « Raté »...).


static func spawn(parent: Node, pos: Vector3, text_value: String, color: Color, big: bool = false) -> void:
	if parent == null:
		return
	var n := DamageNumber.new()
	n.text = text_value
	n.modulate = color
	n.font_size = 64 if big else 44
	n.outline_size = 12
	n.outline_modulate = Color(0, 0, 0, 0.9)
	n.pixel_size = 0.008
	n.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	n.no_depth_test = true
	n.position = pos + Vector3(randf_range(-0.3, 0.3), 0.0, randf_range(-0.3, 0.3))
	parent.add_child(n)


func _ready() -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "position:y", position.y + 1.3, 0.9).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(self, "modulate:a", 0.0, 0.5).set_delay(0.45)
	tw.chain().tween_callback(queue_free)
