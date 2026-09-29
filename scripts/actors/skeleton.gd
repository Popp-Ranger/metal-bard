class_name Skeleton
extends Enemy
## Squelette guerrier (FP 1/4 en D&D 5e : CA 13, 13 PV, épée courte 1d6+2).
## Variante « capitaine » : plus grand, casque, plus de PV.

var captain := false

var _arm_r: Node3D
var _arm_l: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _torso: Node3D
var _jaw: MeshInstance3D


func _configure() -> void:
	var lvl := level - 1
	display_name = "Squelette"
	max_hp = 13 + 4 * lvl
	armor_class = 13
	attack_bonus = 4 + floori(lvl / 2.0)
	damage_dice = Vector3i(1, 6, 2 + lvl)
	save_bonus = 2
	xp_reward = 50 + 10 * lvl
	gold_range = Vector2i(2, 9)
	radius = 0.35
	height = 1.7
	if captain:
		display_name = "Capitaine squelette"
		max_hp = 30 + 8 * lvl
		armor_class = 15
		attack_bonus += 1
		damage_dice = Vector3i(1, 10, 3 + lvl)
		xp_reward = 150 + 20 * lvl
		gold_range = Vector2i(10, 25)
		radius = 0.45
		height = 2.1


func _build_model() -> void:
	var s := 1.25 if captain else 1.0
	model.scale = Vector3.ONE * s
	var bone := own_mat(Color(0.82, 0.78, 0.66), 0.7)
	var dark_bone := own_mat(Color(0.55, 0.5, 0.4), 0.8)
	var rust := own_mat(Color(0.38, 0.26, 0.2), 0.6)
	var eye := Visuals.glow_mat(Color(1.0, 0.15, 0.05), 5.0)

	_leg_l = _pivot(model, Vector3(-0.12, 0.8, 0))
	_leg_r = _pivot(model, Vector3(0.12, 0.8, 0))
	for leg: Node3D in [_leg_l, _leg_r]:
		Visuals.capsule(leg, 0.045, 0.4, Vector3(0, -0.2, 0), bone)
		Visuals.capsule(leg, 0.04, 0.4, Vector3(0, -0.58, 0), bone)
		Visuals.box(leg, Vector3(0.1, 0.05, 0.18), Vector3(0, -0.78, 0.04), dark_bone)

	Visuals.box(model, Vector3(0.3, 0.1, 0.14), Vector3(0, 0.82, 0), dark_bone) # bassin
	_torso = _pivot(model, Vector3(0, 0.85, 0))
	Visuals.cylinder(_torso, 0.035, 0.035, 0.5, Vector3(0, 0.25, -0.03), dark_bone) # colonne
	for i in 4: # côtes
		Visuals.torus(_torso, 0.1, 0.13, Vector3(0, 0.3 + i * 0.07, 0.0), bone, Vector3(0, 0, 0)).scale = Vector3(1.1 - i * 0.05, 0.4, 0.8)
	Visuals.box(_torso, Vector3(0.44, 0.06, 0.1), Vector3(0, 0.56, 0), bone) # clavicules

	# Tête : crâne, mâchoire, orbites rougeoyantes.
	Visuals.sphere(_torso, 0.14, Vector3(0, 0.76, 0.01), bone, Vector3(0.95, 1.05, 1.05))
	_jaw = Visuals.box(_torso, Vector3(0.16, 0.06, 0.12), Vector3(0, 0.63, 0.06), dark_bone)
	Visuals.sphere(_torso, 0.03, Vector3(-0.05, 0.77, 0.12), eye)
	Visuals.sphere(_torso, 0.03, Vector3(0.05, 0.77, 0.12), eye)
	if captain:
		Visuals.sphere(_torso, 0.16, Vector3(0, 0.82, 0), rust, Vector3(1.0, 0.7, 1.0)) # casque
		Visuals.cylinder(_torso, 0.0, 0.03, 0.2, Vector3(-0.13, 0.95, 0), rust, Vector3(0, 0, 30))
		Visuals.cylinder(_torso, 0.0, 0.03, 0.2, Vector3(0.13, 0.95, 0), rust, Vector3(0, 0, -30))

	_arm_l = _pivot(_torso, Vector3(-0.22, 0.54, 0))
	_arm_r = _pivot(_torso, Vector3(0.22, 0.54, 0))
	for arm: Node3D in [_arm_l, _arm_r]:
		Visuals.capsule(arm, 0.035, 0.34, Vector3(0, -0.17, 0), bone)
		Visuals.capsule(arm, 0.03, 0.32, Vector3(0, -0.46, 0.04), bone, Vector3(-15, 0, 0))
	# Épée rouillée (bras droit) et bouclier (bras gauche).
	var sword := _pivot(_arm_r, Vector3(0, -0.6, 0.08))
	Visuals.box(sword, Vector3(0.05, 0.05, 0.14), Vector3.ZERO, dark_bone)
	Visuals.box(sword, Vector3(0.18, 0.03, 0.04), Vector3(0, 0, 0.08), rust)
	Visuals.box(sword, Vector3(0.05, 0.02, 0.6 if captain else 0.5), Vector3(0, 0, 0.4), rust)
	Visuals.cylinder(_arm_l, 0.2, 0.2, 0.04, Vector3(0.0, -0.45, 0.12), rust, Vector3(90, 0, 0))


func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var p := Node3D.new()
	p.position = pos
	parent.add_child(p)
	return p


func _animate(delta: float, moving: bool) -> void:
	if moving:
		var swing := sin(_anim_t * 6.0) * 0.5
		_leg_l.rotation.x = swing
		_leg_r.rotation.x = -swing
		_arm_l.rotation.x = -swing * 0.6
		if not _attacking:
			_arm_r.rotation.x = swing * 0.6
		model.position.y = absf(sin(_anim_t * 6.0)) * 0.04
	else:
		_leg_l.rotation.x = lerpf(_leg_l.rotation.x, 0.0, delta * 8.0)
		_leg_r.rotation.x = lerpf(_leg_r.rotation.x, 0.0, delta * 8.0)
	# Petit cliquetis permanent de la mâchoire et du torse.
	_jaw.position.y = 0.63 - absf(sin(_anim_t * 9.0)) * 0.02
	_torso.rotation.z = sin(_anim_t * 2.3) * 0.04


func _attack_anim(windup: float) -> void:
	var tw := create_tween()
	tw.tween_property(_arm_r, "rotation:x", -2.6, windup * 0.85).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_arm_r, "rotation:x", 0.9, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(_arm_r, "rotation:x", 0.0, 0.35)
