class_name Goblin
extends Enemy
## Gobelin des montagnes : petit (1,15 m), vert, grandes oreilles pointues, long nez, pagne de peaux. Plus rapide
## qu'un squelette, mais fragile. Arme tirée au hasard : gourdin cloûté, coutelas ou lance (plus d'allonge).

## 0 = gourdin, 1 = coutelas, 2 = lance.
var weapon := -1

var _hip_l: Node3D
var _hip_r: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _torso: Node3D
var _swing := 0.0


func _configure() -> void:
	var lvl := level - 1
	if weapon < 0:
		weapon = randi() % 3
	display_name = "Gobelin"
	max_hp = 10 + 3 * lvl
	armor_class = 12
	attack_bonus = 4 + floori(lvl / 2.0)
	damage_dice = Vector3i(1, 6, 1 + lvl) if weapon != 1 else Vector3i(1, 4, 2 + lvl)
	save_bonus = 1
	xp_reward = 40 + 10 * lvl
	gold_range = Vector2i(2, 9)
	radius = 0.32
	height = 1.15
	attack_range = 1.6 if weapon == 2 else 1.0
	move_speed = Balance.HERO_SPEED * 0.32
	detect_radius = 5.0


func _build_model() -> void:
	var skin := own_mat(Color(0.32, 0.5, 0.18), 0.7)
	var dark := own_mat(Color(0.2, 0.32, 0.1), 0.75)
	var hide := own_mat(Color(0.35, 0.22, 0.12), 0.9)
	var eye := Visuals.glow_mat(Color(1.0, 0.85, 0.1), 3.0)
	for side: float in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(0.09 * side, 0.5, 0)
		model.add_child(hip)
		Visuals.capsule(hip, 0.06, 0.3, Vector3(0, -0.13, 0), skin)
		Visuals.capsule(hip, 0.05, 0.28, Vector3(0, -0.36, 0.02), dark)
		Visuals.box(hip, Vector3(0.08, 0.05, 0.16), Vector3(0, -0.49, 0.05), dark) # grand pied
		if side < 0.0:
			_hip_l = hip
		else:
			_hip_r = hip
	_torso = Node3D.new()
	_torso.position = Vector3(0, 0.5, 0)
	_torso.rotation.x = 0.25 # voûté
	model.add_child(_torso)
	Visuals.box(_torso, Vector3(0.28, 0.14, 0.2), Vector3(0, 0.02, 0), hide) # pagne
	Visuals.sphere(_torso, 0.17, Vector3(0, 0.2, 0.02), skin, Vector3(1.0, 1.1, 0.9)) # ventre rond
	Visuals.capsule(_torso, 0.13, 0.3, Vector3(0, 0.32, 0), skin)
	Visuals.box(_torso, Vector3(0.3, 0.06, 0.24), Vector3(0, 0.42, 0), hide, Vector3(0, 0, 18)) # bandoulière
	var head := Node3D.new()
	head.position = Vector3(0, 0.58, 0.05)
	_torso.add_child(head)
	Visuals.sphere(head, 0.14, Vector3.ZERO, skin, Vector3(1.0, 0.95, 1.0))
	Visuals.cylinder(head, 0.0, 0.04, 0.14, Vector3(0, -0.02, 0.17), skin, Vector3(80, 0, 0), 6) # long nez
	for side: float in [-1.0, 1.0]:
		Visuals.sphere(head, 0.025, Vector3(0.055 * side, 0.03, 0.12), eye)
		# Grandes oreilles pointues, à l'horizontale.
		Visuals.cylinder(head, 0.0, 0.05, 0.26, Vector3(0.2 * side, 0.03, -0.02), skin, Vector3(0, 0, -95 * side), 5)
	Visuals.box(head, Vector3(0.12, 0.02, 0.03), Vector3(0, -0.07, 0.12), Visuals.mat(Color(0.9, 0.85, 0.6)), Vector3.ZERO) # crocs
	for side: float in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.position = Vector3(0.17 * side, 0.42, 0)
		_torso.add_child(arm)
		Visuals.capsule(arm, 0.045, 0.28, Vector3(0.02 * side, -0.13, 0), skin)
		Visuals.capsule(arm, 0.04, 0.26, Vector3(0.03 * side, -0.36, 0.04), skin)
		if side < 0.0:
			_arm_l = arm
		else:
			_arm_r = arm
	var w := Node3D.new()
	w.position = Vector3(0.03, -0.48, 0.06)
	_arm_r.add_child(w)
	var wood := Visuals.mat(Color(0.3, 0.18, 0.08), 0.85)
	var iron := Visuals.mat(Color(0.35, 0.33, 0.32), 0.4, 0.7)
	match weapon:
		0: # gourdin clouté
			Visuals.cylinder(w, 0.07, 0.03, 0.55, Vector3(0, 0, 0.25), wood, Vector3(90, 0, 0), 6)
			for k in 4:
				Visuals.box(w, Vector3(0.02, 0.02, 0.06), Vector3(0.06 * (1 if k % 2 == 0 else -1), 0.03 * (k - 1.5), 0.42), iron)
		1: # coutelas rouillé
			Visuals.box(w, Vector3(0.03, 0.04, 0.1), Vector3(0, 0, 0.04), wood)
			Visuals.box(w, Vector3(0.015, 0.07, 0.32), Vector3(0, 0.01, 0.25), iron)
		_: # lance
			Visuals.cylinder(w, 0.018, 0.018, 1.3, Vector3(0, 0, 0.3), wood, Vector3(90, 0, 0), 6)
			Visuals.cylinder(w, 0.0, 0.04, 0.18, Vector3(0, 0, 1.02), iron, Vector3(90, 0, 0), 4)


func _animate(_delta: float, moving: bool) -> void:
	var stride := sin(_anim_t * 9.0) if moving else 0.0
	_hip_l.rotation.x = stride * 0.6
	_hip_r.rotation.x = -stride * 0.6
	_arm_l.rotation.x = -stride * 0.5
	_torso.position.y = 0.5 + absf(stride) * 0.04
	_arm_r.rotation.x = lerpf(stride * 0.4, -2.4, _swing)


func _attack_anim(windup: float) -> void:
	var tw := create_tween()
	tw.tween_property(self, "_swing", 1.0, windup * 0.85).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "_swing", -0.2, 0.08)
	tw.tween_property(self, "_swing", 0.0, 0.3)
	Sfx.play("croak", -16.0, 0.4) # ricanement


func _death_anim() -> void:
	Sfx.play("croak", -12.0, 0.5)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(model, "rotation:x", -PI * 0.5, 0.4).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(model, "position:y", 0.12, 0.4)
	_corpse(1.8)
