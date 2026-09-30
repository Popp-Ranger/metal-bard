class_name LightningStorm
extends Node3D
## Pluie d'éclairs du Solo : frappe tous les ennemis à l'écran.

var targets: Array = [] # peut contenir des ennemis libérés entre-temps : on vérifie à chaque éclair
var power := 1.0
var center := Vector3.ZERO
## Pluie d'éclairs d'un autre joueur (coop) : mêmes éclairs, sans dégâts, flash seulement si proche.
var visual_only := false


static func spawn(parent: Node, storm_center: Vector3, hit_targets: Array[Enemy], multiplier: float) -> void:
	var s := LightningStorm.new()
	s.targets = hit_targets
	s.power = multiplier
	s.center = storm_center
	parent.add_child(s)


func _ready() -> void:
	_run()


func _run() -> void:
	var near := true
	if visual_only:
		var h := get_tree().get_first_node_in_group("hero") as Node3D
		near = h != null and h.global_position.distance_to(center) < 20.0
	if near:
		Events.screen_flash.emit(Color(0.75, 0.85, 1.0, 0.55 if not visual_only else 0.3), 0.35)
		Events.camera_shake.emit(0.35 if not visual_only else 0.15, 0.8)
	Sfx.play("solo_thunder", -2.0 if near else -12.0, 0.0) # short_thunder
	# Éclairs décoratifs autour du héros.
	for i in 6:
		var p := center + Vector3(randf_range(-9, 9), 0, randf_range(-9, 9))
		ArcBolt.spawn(get_parent(), p + Vector3(randf_range(-2, 2), 16, randf_range(-2, 2)), p, 0.2, 0.35)
	await get_tree().create_timer(0.15, false).timeout
	var cha := GameState.mod("CHA")
	for obj: Variant in targets:
		if not is_instance_valid(obj):
			continue
		var e := obj as Enemy
		if e == null or not e.is_alive():
			continue
		var top := e.global_position + Vector3(randf_range(-1.5, 1.5), 16.0, randf_range(-1.5, 1.5))
		ArcBolt.spawn(get_parent(), top, e.global_position + Vector3(0, 0.5, 0), 0.28, 0.45, Color(0.7, 0.8, 1.0))
		if not visual_only:
			var dmg := roundi(Dice.roll(4, 10, cha) * power)
			e.take_damage(maxi(1, dmg), e.global_position + Vector3(0.01, 0, 0), 0.0, false, "shock")
		await get_tree().create_timer(0.09, false).timeout
	await get_tree().create_timer(0.6, false).timeout
	queue_free()
