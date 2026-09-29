class_name HeroModel
extends Node3D
## Apparence de Riffald : longue crinière rousse sombre (clin d'œil à Dave Mustaine),
## manteau de cuir noir, médaillon à cornes (hommage à Ronnie James Dio)
## et luth électrique aux cordes lumineuses. Le modèle regarde vers +Z.

const LUTE_IDLE := Vector3(2.75, 0.0, -0.25)
const LUTE_WINDUP := Vector3(-0.7, 0.0, -0.2)
const LUTE_STRIKE := Vector3(1.75, 0.0, 0.15)
const LUTE_PLAY := Vector3(1.35, -0.2, 1.25)

var _body: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _arm_l: Node3D
var _lute_pivot: Node3D
var _hair_back: MeshInstance3D
var _strings_mat: StandardMaterial3D
var _flash_mats: Array[StandardMaterial3D] = []
var _t := 0.0
var _moving := false
var _busy := false


func _ready() -> void:
	var leather := _own_mat(Color(0.09, 0.07, 0.07), 0.6)
	var coat := _own_mat(Color(0.04, 0.035, 0.045), 0.8)
	var skin := _own_mat(Color(0.82, 0.64, 0.52), 0.6)
	var hair := _own_mat(Color(0.38, 0.1, 0.05), 0.75)
	var metal := Visuals.mat(Color(0.75, 0.75, 0.8), 0.25, 0.9)
	var wood := Visuals.mat(Color(0.28, 0.12, 0.06), 0.5)

	_body = Node3D.new()
	add_child(_body)

	# Jambes (pivot à la hanche pour les animer).
	_leg_l = _pivot(_body, Vector3(-0.13, 0.9, 0))
	_leg_r = _pivot(_body, Vector3(0.13, 0.9, 0))
	for leg: Node3D in [_leg_l, _leg_r]:
		Visuals.capsule(leg, 0.1, 0.85, Vector3(0, -0.42, 0), leather)
		Visuals.box(leg, Vector3(0.17, 0.14, 0.3), Vector3(0, -0.84, 0.05), coat) # bottes

	# Torse, manteau long, ceinture cloutée.
	Visuals.box(_body, Vector3(0.5, 0.62, 0.28), Vector3(0, 1.22, 0), leather)
	Visuals.box(_body, Vector3(0.2, 1.0, 0.32), Vector3(-0.2, 1.0, -0.01), coat)
	Visuals.box(_body, Vector3(0.2, 1.0, 0.32), Vector3(0.2, 1.0, -0.01), coat)
	Visuals.box(_body, Vector3(0.56, 0.12, 0.32), Vector3(0, 0.92, 0), coat)
	for i in 5:
		Visuals.sphere(_body, 0.025, Vector3(-0.2 + i * 0.1, 0.92, 0.17), metal)
	# Épaulières à pointes.
	for side: float in [-1.0, 1.0]:
		Visuals.sphere(_body, 0.13, Vector3(0.3 * side, 1.5, 0), coat, Vector3(1.2, 0.8, 1.1))
		Visuals.cylinder(_body, 0.0, 0.04, 0.14, Vector3(0.36 * side, 1.6, 0), metal, Vector3(0, 0, -30 * side))
	# Médaillon à cornes, lumineux.
	Visuals.sphere(_body, 0.05, Vector3(0, 1.36, 0.16), Visuals.glow_mat(Color(1.0, 0.2, 0.1), 2.5))

	# Bras gauche (libre) et bras droit (tient le luth par le manche).
	_arm_l = _pivot(_body, Vector3(-0.33, 1.45, 0))
	Visuals.capsule(_arm_l, 0.08, 0.62, Vector3(0, -0.3, 0), coat)
	Visuals.sphere(_arm_l, 0.07, Vector3(0, -0.62, 0), skin)
	var arm_r := _pivot(_body, Vector3(0.33, 1.45, 0))
	Visuals.capsule(arm_r, 0.08, 0.62, Vector3(0, -0.3, 0.05), coat, Vector3(-15, 0, 0))

	# Tête, crinière, barbe naissante.
	Visuals.box(_body, Vector3(0.12, 0.1, 0.12), Vector3(0, 1.58, 0), skin)
	Visuals.sphere(_body, 0.16, Vector3(0, 1.74, 0.02), skin, Vector3(0.95, 1.1, 1.0))
	Visuals.sphere(_body, 0.175, Vector3(0, 1.8, -0.02), hair, Vector3(1.05, 0.95, 1.05))
	_hair_back = Visuals.box(_body, Vector3(0.42, 0.75, 0.14), Vector3(0, 1.45, -0.14), hair)
	Visuals.box(_body, Vector3(0.1, 0.6, 0.16), Vector3(-0.19, 1.5, 0.0), hair, Vector3(0, 0, -6))
	Visuals.box(_body, Vector3(0.1, 0.6, 0.16), Vector3(0.19, 1.5, 0.0), hair, Vector3(0, 0, 6))
	Visuals.box(_body, Vector3(0.2, 0.08, 0.05), Vector3(0, 1.64, 0.15), hair)
	var eye_mat := Visuals.glow_mat(Color(0.6, 0.85, 1.0), 1.5)
	Visuals.sphere(_body, 0.022, Vector3(-0.06, 1.77, 0.15), eye_mat)
	Visuals.sphere(_body, 0.022, Vector3(0.06, 1.77, 0.15), eye_mat)

	# Luth électrique : pivot dans la main droite, le manche part de la main.
	_lute_pivot = _pivot(_body, Vector3(0.36, 0.85, 0.12))
	_lute_pivot.rotation = LUTE_IDLE
	Visuals.box(_lute_pivot, Vector3(0.07, 0.8, 0.05), Vector3(0, 0.35, 0), wood) # manche
	Visuals.box(_lute_pivot, Vector3(0.12, 0.16, 0.06), Vector3(0, 0.78, 0), Visuals.mat(Color(0.08, 0.05, 0.04))) # tête
	Visuals.sphere(_lute_pivot, 0.28, Vector3(0, -0.05, 0), Visuals.mat(Color(0.45, 0.2, 0.08), 0.35),
		Vector3(0.85, 1.15, 0.3)) # caisse en poire
	Visuals.sphere(_lute_pivot, 0.08, Vector3(0, -0.02, 0.07), Visuals.mat(Color(0.03, 0.02, 0.02)), Vector3(1, 1, 0.3))
	_strings_mat = Visuals.glow_mat(Color(0.45, 0.85, 1.0), 2.5)
	Visuals.box(_lute_pivot, Vector3(0.04, 1.05, 0.01), Vector3(0, 0.25, 0.09), _strings_mat)
	for s: float in [-1.0, 1.0]:
		Visuals.cylinder(_lute_pivot, 0.0, 0.03, 0.12, Vector3(0.12 * s, -0.3, 0.0), metal, Vector3(0, 0, 120 * s))


func _own_mat(color: Color, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.emission_enabled = true
	m.emission = Color.BLACK
	_flash_mats.append(m)
	return m


func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var p := Node3D.new()
	p.position = pos
	parent.add_child(p)
	return p


func set_moving(moving: bool) -> void:
	_moving = moving


func _process(delta: float) -> void:
	_t += delta
	var strings_pulse := 2.0 + sin(_t * 6.0) * 0.8
	_strings_mat.emission_energy_multiplier = strings_pulse
	if _moving:
		var swing := sin(_t * 11.0) * 0.6
		_leg_l.rotation.x = swing
		_leg_r.rotation.x = -swing
		_arm_l.rotation.x = -swing * 0.7
		_body.position.y = absf(sin(_t * 11.0)) * 0.05
		_hair_back.rotation.x = -0.15 - absf(swing) * 0.1
	else:
		_leg_l.rotation.x = lerpf(_leg_l.rotation.x, 0.0, delta * 10.0)
		_leg_r.rotation.x = lerpf(_leg_r.rotation.x, 0.0, delta * 10.0)
		_arm_l.rotation.x = lerpf(_arm_l.rotation.x, 0.0, delta * 10.0)
		_body.position.y = sin(_t * 2.0) * 0.012
		_hair_back.rotation.x = lerpf(_hair_back.rotation.x, 0.0, delta * 5.0)


## Coup de luth tenu par le manche : élan au-dessus de l'épaule puis frappe.
func swing() -> void:
	if _busy:
		return
	_busy = true
	var tw := create_tween()
	tw.tween_property(_lute_pivot, "rotation", LUTE_WINDUP, 0.08)
	tw.tween_property(_lute_pivot, "rotation", LUTE_STRIKE, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_interval(0.08)
	tw.tween_property(_lute_pivot, "rotation", LUTE_IDLE, 0.22)
	tw.tween_callback(func() -> void: _busy = false)


## Accord rapide (lancement de sort).
func strum() -> void:
	var tw := create_tween()
	tw.tween_property(_lute_pivot, "rotation", LUTE_PLAY, 0.07)
	tw.tween_property(_arm_l, "rotation:x", -1.2, 0.05)
	tw.tween_interval(0.18)
	tw.tween_property(_arm_l, "rotation:x", 0.0, 0.1)
	tw.tween_property(_lute_pivot, "rotation", LUTE_IDLE, 0.2)


## Posture de solo (tenue pendant le mini-jeu).
func solo_pose(active: bool) -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_lute_pivot, "rotation", LUTE_PLAY if active else LUTE_IDLE, 0.15)
	tw.tween_property(_arm_l, "rotation:x", -1.3 if active else 0.0, 0.15)
	tw.tween_property(_body, "rotation:x", -0.25 if active else 0.0, 0.15)
	_strings_mat.emission = Color(1.0, 0.95, 0.6) if active else Color(0.45, 0.85, 1.0)


func flash(color: Color = Color(1.0, 0.1, 0.05)) -> void:
	for m in _flash_mats:
		m.emission = color
	await get_tree().create_timer(0.1, false).timeout
	for m in _flash_mats:
		m.emission = Color.BLACK


func die() -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "rotation:x", -PI * 0.5, 0.6).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position:y", 0.25, 0.6)
