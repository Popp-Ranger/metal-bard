class_name Portal
extends Node3D
## Portail magique de Zarathos. Interagir avec [E] pour le traverser.

var interact_radius := 2.4
var target_scene := ""
var prompt := "Traverser le portail"
var on_enter: Callable
## Portail de retour en ville (touche T) : bleu au lieu de violet.
var blue := false

var _ring: Node3D


func _ready() -> void:
	add_to_group("interactable")
	_ring = Node3D.new()
	_ring.position.y = 1.5
	add_child(_ring)
	var disc := CylinderMesh.new()
	disc.top_radius = 1.15
	disc.bottom_radius = 1.15
	disc.height = 0.02
	var disc_mi := MeshInstance3D.new()
	disc_mi.mesh = disc
	disc_mi.rotation_degrees = Vector3(90, 45, 0)
	var disc_mat := Visuals.portal_material()
	var ring_col := Color(0.6, 0.3, 1.0)
	var rune_col := Color(0.5, 0.25, 0.9)
	var light_col := Color(0.6, 0.35, 1.0)
	if blue:
		disc_mat.set_shader_parameter("color_a", Color(0.1, 0.35, 1.0))
		disc_mat.set_shader_parameter("color_b", Color(0.5, 0.9, 1.0))
		ring_col = Color(0.2, 0.55, 1.0)
		rune_col = Color(0.15, 0.45, 1.0)
		light_col = Color(0.3, 0.6, 1.0)
	disc_mi.material_override = disc_mat
	disc_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.add_child(disc_mi)
	Visuals.torus(_ring, 1.1, 1.3, Vector3.ZERO, Visuals.glow_mat(ring_col, 3.0), Vector3(90, 45, 0))
	# Runes au sol.
	Visuals.torus(self, 1.3, 1.45, Vector3(0, 0.03, 0), Visuals.glow_mat(rune_col, 1.5))
	var light := Visuals.flicker_light(self, Vector3(0, 1.6, 0), light_col, 2.5, 7.0)
	light.flicker_amount = 0.15
	var sparks := CPUParticles3D.new()
	sparks.position.y = 1.5
	sparks.amount = 40
	sparks.lifetime = 1.4
	sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sparks.emission_sphere_radius = 1.1
	sparks.gravity = Vector3(0, 0.6, 0)
	sparks.initial_velocity_min = 0.1
	sparks.initial_velocity_max = 0.5
	var spark_mesh := SphereMesh.new()
	spark_mesh.radius = 0.03
	spark_mesh.height = 0.06
	spark_mesh.material = Visuals.glow_mat(Color(0.6, 0.85, 1.0) if blue else Color(0.8, 0.6, 1.0), 2.0)
	sparks.mesh = spark_mesh
	add_child(sparks)
	scale = Vector3.ONE * 0.01
	create_tween().tween_property(self, "scale", Vector3.ONE, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play("portal", -6.0)


func _process(_delta: float) -> void:
	_ring.position.y = 1.5 + sin(Time.get_ticks_msec() * 0.002) * 0.05


func get_prompt() -> String:
	return prompt


func interact(_hero: Node3D) -> void:
	Sfx.play("portal", -4.0)
	if on_enter.is_valid():
		on_enter.call()
	if not target_scene.is_empty():
		Router.go_to(target_scene)
