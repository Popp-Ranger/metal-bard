class_name DemonBrute
extends Enemy
## Démon cornu : colosse rouge de 2,4 m aux cornes de bélier, sabots fendus et grande hache à deux mains. Lent,
## coriace, il frappe fort. Variante « gardien » (`guardian`) : 30 % plus grand, garde la sortie des Cryptes.

var guardian := false

var _hip_l: Node3D
var _hip_r: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _torso: Node3D
var _axe_arm := 0.0 # 0 = hache portée, 1 = levée au-dessus de la tête


func _configure() -> void:
	var lvl := level - 1
	display_name = "Démon cornu"
	max_hp = 32 + 9 * lvl
	armor_class = 14
	attack_bonus = 5 + floori(lvl / 2.0)
	damage_dice = Vector3i(2, 6, 2 + lvl)
	save_bonus = 3
	xp_reward = 160 + 25 * lvl
	gold_range = Vector2i(8, 20)
	radius = 0.55
	height = 2.4
	attack_range = 1.5
	move_speed = Balance.HERO_SPEED * 0.22
	if guardian:
		display_name = "Gardien des Cryptes"
		is_boss = true
		max_hp = 90 + 20 * lvl
		armor_class = 15
		damage_dice = Vector3i(2, 8, 3 + lvl)
		xp_reward = 450 + 50 * lvl
		gold_range = Vector2i(30, 60)
		radius = 0.7
		height = 2.4 * 1.3
		detect_radius = 7.0


func _build_model() -> void:
	if guardian:
		model.scale = Vector3.ONE * 1.3
	var skin := own_mat(Color(0.55, 0.07, 0.04), 0.55)
	var dark := own_mat(Color(0.2, 0.03, 0.02), 0.7)
	var horn := own_mat(Color(0.18, 0.15, 0.12), 0.4)
	var hoof := own_mat(Color(0.08, 0.06, 0.05), 0.4)
	var iron := own_mat(Color(0.25, 0.24, 0.24), 0.35)
	var eye := Visuals.glow_mat(Color(1.0, 0.55, 0.05), 5.0)
	# Jambes de bouc (cuisse, jarret vers l'arrière, sabot).
	for side: float in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(0.17 * side, 1.05, 0)
		model.add_child(hip)
		Visuals.capsule(hip, 0.12, 0.55, Vector3(0, -0.25, 0.04), skin, Vector3(-12, 0, 0))
		Visuals.capsule(hip, 0.08, 0.5, Vector3(0, -0.72, -0.06), dark, Vector3(15, 0, 0))
		Visuals.box(hip, Vector3(0.14, 0.1, 0.2), Vector3(0, -1.0, 0.02), hoof)
		if side < 0.0:
			_hip_l = hip
		else:
			_hip_r = hip
	# Buste massif, bassin pagne de cuir.
	_torso = Node3D.new()
	_torso.position = Vector3(0, 1.05, 0)
	model.add_child(_torso)
	Visuals.box(_torso, Vector3(0.48, 0.22, 0.3), Vector3(0, 0.02, 0), dark) # pagne
	Visuals.capsule(_torso, 0.3, 0.75, Vector3(0, 0.45, 0), skin, Vector3.ZERO)
	Visuals.sphere(_torso, 0.33, Vector3(0, 0.62, 0.02), skin, Vector3(1.25, 0.8, 0.9)) # pectoraux
	Visuals.box(_torso, Vector3(0.7, 0.06, 0.4), Vector3(0, 0.78, 0), iron, Vector3(0, 0, 0)) # chaîne d'épaules
	# Tête de taureau-démon : mufle, cornes de bélier, yeux de braise.
	var head := Node3D.new()
	head.position = Vector3(0, 1.0, 0.06)
	_torso.add_child(head)
	Visuals.sphere(head, 0.18, Vector3(0, 0.08, 0), skin, Vector3(1.0, 1.0, 1.1))
	Visuals.box(head, Vector3(0.2, 0.13, 0.15), Vector3(0, 0.0, 0.16), skin) # mufle
	Visuals.torus(head, 0.025, 0.04, Vector3(0, -0.04, 0.24), iron, Vector3(90, 0, 0)) # anneau dans le nez
	for side: float in [-1.0, 1.0]:
		Visuals.sphere(head, 0.035, Vector3(0.08 * side, 0.12, 0.15), eye)
		DemonParts.horn(head, Vector3(0.14 * side, 0.18, -0.02), side, horn, 0.42, 55.0)
	# Bras : le gauche ballant, le droit qui porte la grande hache.
	for side: float in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.position = Vector3(0.42 * side, 0.75, 0)
		_torso.add_child(arm)
		Visuals.sphere(arm, 0.16, Vector3.ZERO, skin)
		Visuals.capsule(arm, 0.1, 0.5, Vector3(0.04 * side, -0.25, 0), skin, Vector3(0, 0, 8 * side))
		Visuals.capsule(arm, 0.09, 0.45, Vector3(0.06 * side, -0.68, 0.06), skin, Vector3(-10, 0, 4 * side))
		Visuals.sphere(arm, 0.09, Vector3(0.07 * side, -0.94, 0.1), dark)
		if side < 0.0:
			_arm_l = arm
		else:
			_arm_r = arm
	var axe := Node3D.new()
	axe.position = Vector3(0.07, -0.94, 0.12)
	_arm_r.add_child(axe)
	Visuals.cylinder(axe, 0.035, 0.035, 1.5, Vector3(0, 0.25, 0.0), Visuals.mat(Color(0.2, 0.12, 0.06)), Vector3.ZERO, 6)
	Visuals.box(axe, Vector3(0.05, 0.45, 0.42), Vector3(0, 0.82, 0.18), iron)
	Visuals.box(axe, Vector3(0.03, 0.5, 0.06), Vector3(0, 0.82, 0.4), Visuals.mat(Color(0.8, 0.25, 0.15), 0.3, 0.6))
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.35, 0.1)
	glow.light_energy = 0.7
	glow.omni_range = 3.0
	glow.position = Vector3(0, 2.2, 0.5)
	model.add_child(glow)


func _animate(_delta: float, moving: bool) -> void:
	var stride := sin(_anim_t * 4.5) if moving else 0.0
	_hip_l.rotation.x = stride * 0.45
	_hip_r.rotation.x = -stride * 0.45
	_arm_l.rotation.x = -stride * 0.3
	_torso.rotation.z = stride * 0.05
	_torso.position.y = 1.05 + absf(stride) * 0.05
	_arm_r.rotation.x = lerpf(-stride * 0.15, -2.7, _axe_arm)
	_torso.scale = Vector3.ONE * (1.0 + sin(_anim_t * 1.8) * 0.015) # respiration


func _attack_anim(windup: float) -> void:
	var tw := create_tween()
	tw.tween_property(self, "_axe_arm", 1.0, windup * 0.85).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "_axe_arm", -0.3, 0.1)
	tw.tween_property(self, "_axe_arm", 0.0, 0.35)


func _death_anim() -> void:
	Sfx.play("boom", -10.0)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(model, "rotation:x", -PI * 0.5, 0.6).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(model, "position:y", 0.25, 0.6)
	_corpse(2.0)
