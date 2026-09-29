class_name HeroModel
extends Node3D
## Apparence de Riffald : longue crinière rousse sombre (clin d'œil à Dave Mustaine),
## manteau de cuir noir, médaillon à cornes (hommage à Ronnie James Dio).
## Il joue d'une réplique de Gibson Flying V, portée bas à la sangle comme un guitariste
## de metal, et se déplace avec la posture voûtée et la démarche claudicante des
## Réprouvés (morts-vivants) de World of Warcraft. Le modèle regarde vers +Z.
##
## Les bras sont pilotés par une petite IK à deux os : la main gauche reste sur le manche,
## la main droite gratte les cordes (ou empoigne le manche pour frapper).

const UPPER_ARM := 0.3
const FOREARM := 0.3
const TORSO_LEAN := 0.32 # dos voûté vers l'avant
const GUITAR_REST := Vector3(-0.38, 0.0, 0.8) # manche vers le haut-gauche, caisse sur la hanche droite, table face au public
const GUITAR_REST_POS := Vector3(0.04, 0.06, 0.26)
const GUITAR_SOLO := Vector3(-0.5, 0.0, 0.5) # manche dressé vers le ciel pour le solo
const GUITAR_WINDUP := Vector3(-0.6, 0.0, 2.9) # guitare levée au-dessus de l'épaule, tenue par le manche
const GUITAR_STRIKE := Vector3(1.2, 0.0, 2.9) # abattue vers l'avant

var _torso: Node3D
var _head: Node3D
var _hip_l: Node3D
var _hip_r: Node3D
var _knee_l: Node3D
var _knee_r: Node3D
var _upper_l: Node3D
var _upper_r: Node3D
var _fore_l: Node3D
var _fore_r: Node3D
var _guitar: Node3D
var _hair_back: MeshInstance3D
var _aura: Node3D
var _aura_light: OmniLight3D
var _strings_mat: StandardMaterial3D
var _flash_mats: Array[StandardMaterial3D] = []

var _t := 0.0
var _walk := 0.0 # 0 = immobile, 1 = marche (lissé)
var _moving := false
var _busy := false
var _soloing := false
var _strum := 0.0 # animation du grattage (0..1)
var _smash := 0.0 # 1 = les deux mains sur le manche (coup de guitare)
var _twitch := 0.0
var _twitch_timer := 2.0


func _ready() -> void:
	var leather := _own_mat(Color(0.09, 0.07, 0.07), 0.6)
	var coat := _own_mat(Color(0.05, 0.045, 0.055), 0.8)
	var skin := _own_mat(Color(0.74, 0.6, 0.52), 0.65) # teint blafard
	var hair := _own_mat(Color(0.42, 0.11, 0.05), 0.75)
	var metal := Visuals.mat(Color(0.78, 0.78, 0.82), 0.25, 0.9)

	# --- Jambes : hanche → genou → pied, genoux fléchis en permanence.
	_hip_l = _pivot(self, Vector3(-0.13, 0.86, 0))
	_hip_r = _pivot(self, Vector3(0.13, 0.86, 0))
	_knee_l = _build_leg(_hip_l, leather, coat)
	_knee_r = _build_leg(_hip_r, leather, coat)

	# --- Torse (pivot au bassin, penché en avant).
	_torso = _pivot(self, Vector3(0, 0.86, 0))
	_torso.rotation.x = TORSO_LEAN
	Visuals.box(_torso, Vector3(0.44, 0.6, 0.26), Vector3(0, 0.32, 0), leather)
	Visuals.box(_torso, Vector3(0.2, 0.95, 0.3), Vector3(-0.18, 0.08, -0.02), coat) # pans du manteau
	Visuals.box(_torso, Vector3(0.2, 0.95, 0.3), Vector3(0.18, 0.08, -0.02), coat)
	Visuals.box(_torso, Vector3(0.52, 0.11, 0.3), Vector3(0, 0.02, 0), coat) # ceinture
	for i in 5:
		Visuals.sphere(_torso, 0.022, Vector3(-0.2 + i * 0.1, 0.02, 0.16), metal)
	Visuals.sphere(_torso, 0.045, Vector3(0, 0.46, 0.14), Visuals.glow_mat(Color(1.0, 0.2, 0.1), 2.5)) # médaillon
	# Épaules haussées et épaulières à pointes.
	for side: float in [-1.0, 1.0]:
		Visuals.sphere(_torso, 0.13, Vector3(0.27 * side, 0.62, 0.02), coat, Vector3(1.2, 0.85, 1.1))
		Visuals.cylinder(_torso, 0.0, 0.035, 0.14, Vector3(0.33 * side, 0.72, 0.0), metal, Vector3(0, 0, -30 * side))
	# Sangle de guitare en travers du torse.
	Visuals.box(_torso, Vector3(0.05, 0.72, 0.02), Vector3(-0.01, 0.32, 0.15), Visuals.mat(Color(0.12, 0.1, 0.1)), Vector3(0, 0, 33))

	# --- Tête projetée en avant (cou tendu), crinière, barbe naissante.
	_head = _pivot(_torso, Vector3(0, 0.64, 0.1))
	_head.rotation.x = -0.2
	Visuals.box(_head, Vector3(0.11, 0.12, 0.11), Vector3(0, 0.04, -0.02), skin) # cou
	Visuals.sphere(_head, 0.155, Vector3(0, 0.2, 0.03), skin, Vector3(0.92, 1.1, 1.0))
	Visuals.sphere(_head, 0.17, Vector3(0, 0.26, -0.01), hair, Vector3(1.05, 0.95, 1.05))
	_hair_back = Visuals.box(_head, Vector3(0.32, 0.62, 0.09), Vector3(0, -0.12, -0.12), hair)
	Visuals.box(_head, Vector3(0.07, 0.5, 0.12), Vector3(-0.16, -0.06, 0.02), hair, Vector3(0, 0, -5))
	Visuals.box(_head, Vector3(0.07, 0.5, 0.12), Vector3(0.16, -0.06, 0.02), hair, Vector3(0, 0, 5))
	Visuals.box(_head, Vector3(0.18, 0.08, 0.05), Vector3(0, 0.1, 0.16), hair)
	var eye_mat := Visuals.glow_mat(Color(0.6, 0.85, 1.0), 1.8)
	Visuals.sphere(_head, 0.022, Vector3(-0.055, 0.23, 0.16), eye_mat)
	Visuals.sphere(_head, 0.022, Vector3(0.055, 0.23, 0.16), eye_mat)

	# --- Guitare Flying V.
	_guitar = _pivot(_torso, GUITAR_REST_POS)
	_guitar.rotation = GUITAR_REST
	_guitar.scale = Vector3.ONE * 1.15 # légèrement surdimensionnée pour rester lisible en vue iso
	_build_flying_v(_guitar, metal)

	# --- Bras (IK à deux os).
	_upper_l = _pivot(_torso, Vector3(-0.28, 0.58, 0.03))
	_upper_r = _pivot(_torso, Vector3(0.28, 0.58, 0.03))
	_fore_l = _build_arm(_upper_l, coat, skin)
	_fore_r = _build_arm(_upper_r, coat, skin)

	# --- Aura dorée du solo (invincibilité).
	_aura = Node3D.new()
	add_child(_aura)
	Visuals.torus(_aura, 0.75, 0.85, Vector3(0, 0.05, 0), Visuals.glow_mat(Color(1.0, 0.8, 0.3), 3.0))
	Visuals.torus(_aura, 0.55, 0.6, Vector3(0, 0.05, 0), Visuals.glow_mat(Color(1.0, 0.9, 0.5), 2.0))
	_aura_light = OmniLight3D.new()
	_aura_light.position = Vector3(0, 1.2, 0.3)
	_aura_light.light_color = Color(1.0, 0.8, 0.4)
	_aura_light.light_energy = 2.5
	_aura_light.omni_range = 4.0
	_aura.add_child(_aura_light)
	_aura.visible = false
	_update_arms()


func _build_leg(hip: Node3D, leather: Material, coat: Material) -> Node3D:
	Visuals.capsule(hip, 0.1, 0.46, Vector3(0, -0.22, 0), leather)
	var knee := _pivot(hip, Vector3(0, -0.43, 0))
	Visuals.capsule(knee, 0.085, 0.44, Vector3(0, -0.2, 0), leather)
	Visuals.box(knee, Vector3(0.16, 0.13, 0.3), Vector3(0, -0.4, 0.05), coat) # botte
	return knee


func _build_arm(upper: Node3D, sleeve: Material, skin: Material) -> Node3D:
	Visuals.capsule(upper, 0.075, UPPER_ARM + 0.05, Vector3(0, -UPPER_ARM * 0.5, 0), sleeve)
	var fore := _pivot(upper, Vector3(0, -UPPER_ARM, 0))
	Visuals.capsule(fore, 0.065, FOREARM, Vector3(0, -FOREARM * 0.5, 0), sleeve)
	Visuals.sphere(fore, 0.06, Vector3(0, -FOREARM, 0), skin, Vector3(0.9, 1.1, 0.8))
	return fore


## Réplique de Gibson Flying V (finition cerise, plaque de protection blanche,
## deux micros double bobinage, chevalet Tune-o-matic, cordier en V, 3 boutons en ligne).
## Repère local : manche vers +Y, face avant vers +Z, pointe du V à l'origine.
func _build_flying_v(g: Node3D, chrome: Material) -> void:
	var cherry := Visuals.mat(Color(0.5, 0.04, 0.05), 0.22, 0.1)
	var pickguard := Visuals.mat(Color(0.92, 0.9, 0.85), 0.4)
	var mahogany := Visuals.mat(Color(0.33, 0.14, 0.06), 0.5)
	var rosewood := Visuals.mat(Color(0.1, 0.05, 0.03), 0.6)
	var black := Visuals.mat(Color(0.03, 0.03, 0.03), 0.4)
	var pearl := Visuals.mat(Color(0.95, 0.93, 0.88), 0.2)
	# Corps en V : deux ailes qui s'écartent depuis la jonction du manche.
	Visuals.box(g, Vector3(0.12, 0.48, 0.045), Vector3(-0.1, -0.21, 0), cherry, Vector3(0, 0, -24))
	Visuals.box(g, Vector3(0.12, 0.48, 0.045), Vector3(0.1, -0.21, 0), cherry, Vector3(0, 0, 24))
	Visuals.box(g, Vector3(0.17, 0.2, 0.045), Vector3(0, -0.07, 0), cherry)
	Visuals.sphere(g, 0.085, Vector3(0, 0.0, 0), cherry, Vector3(1.0, 0.7, 0.26))
	# Plaque de protection blanche (épouse le haut du V).
	Visuals.box(g, Vector3(0.15, 0.18, 0.006), Vector3(0, -0.07, 0.025), pickguard)
	Visuals.box(g, Vector3(0.06, 0.18, 0.006), Vector3(-0.085, -0.17, 0.025), pickguard, Vector3(0, 0, -24))
	Visuals.box(g, Vector3(0.06, 0.18, 0.006), Vector3(0.085, -0.17, 0.025), pickguard, Vector3(0, 0, 24))
	# Micros humbucker (cadres chromés).
	for y: float in [-0.03, -0.12]:
		Visuals.box(g, Vector3(0.085, 0.045, 0.012), Vector3(0, y, 0.03), chrome)
		Visuals.box(g, Vector3(0.075, 0.035, 0.018), Vector3(0, y, 0.032), black)
	# Chevalet Tune-o-matic + cordier en V.
	Visuals.box(g, Vector3(0.085, 0.014, 0.018), Vector3(0, -0.18, 0.03), chrome)
	Visuals.box(g, Vector3(0.012, 0.09, 0.006), Vector3(-0.022, -0.25, 0.026), chrome, Vector3(0, 0, -25))
	Visuals.box(g, Vector3(0.012, 0.09, 0.006), Vector3(0.022, -0.25, 0.026), chrome, Vector3(0, 0, 25))
	# Trois boutons alignés sur l'aile droite.
	for i in 3:
		Visuals.cylinder(g, 0.014, 0.014, 0.02, Vector3(0.1 + i * 0.03, -0.27 - i * 0.06, 0.03), black, Vector3(90, 0, 0), 8)
	# Manche en acajou, touche en palissandre, repères nacrés.
	Visuals.box(g, Vector3(0.05, 0.62, 0.035), Vector3(0, 0.33, -0.005), mahogany)
	Visuals.box(g, Vector3(0.048, 0.6, 0.008), Vector3(0, 0.33, 0.016), rosewood)
	for y: float in [0.1, 0.17, 0.23, 0.29, 0.38, 0.47, 0.53]:
		Visuals.sphere(g, 0.006, Vector3(0, y, 0.021), pearl)
	# Tête en flèche, légèrement renversée, avec 6 mécaniques.
	var head := _pivot(g, Vector3(0, 0.64, -0.005))
	head.rotation.x = deg_to_rad(-12)
	Visuals.box(head, Vector3(0.07, 0.17, 0.018), Vector3(0, 0.085, 0), black)
	Visuals.box(head, Vector3(0.04, 0.05, 0.02), Vector3(-0.03, 0.17, 0), black, Vector3(0, 0, 20))
	Visuals.box(head, Vector3(0.04, 0.05, 0.02), Vector3(0.03, 0.17, 0), black, Vector3(0, 0, -20))
	for i in 3:
		for s: float in [-1.0, 1.0]:
			Visuals.cylinder(head, 0.008, 0.008, 0.035, Vector3(0.045 * s, 0.04 + i * 0.045, -0.005), chrome, Vector3(0, 0, 90), 6)
	# Cordes (légère lueur magique).
	_strings_mat = Visuals.glow_mat(Color(0.55, 0.85, 1.0), 0.8)
	Visuals.box(g, Vector3(0.03, 0.84, 0.003), Vector3(0, 0.23, 0.036), _strings_mat)


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
	_walk = move_toward(_walk, 1.0 if _moving else 0.0, delta * 5.0)
	_strings_mat.emission_energy_multiplier = (3.0 if _soloing else 0.8) + sin(_t * 6.0) * 0.3

	# Démarche de Réprouvé : pas traînants et irréguliers, balancement, genoux fléchis.
	var phase := _t * 7.0
	var step := sin(phase) + 0.3 * sin(phase * 2.0) # boiterie
	var knee_base := 0.55
	_hip_l.rotation.x = -0.3 + step * 0.45 * _walk
	_hip_r.rotation.x = -0.3 - step * 0.45 * _walk
	_knee_l.rotation.x = knee_base + maxf(0.0, -cos(phase)) * 0.5 * _walk
	_knee_r.rotation.x = knee_base + maxf(0.0, cos(phase)) * 0.5 * _walk
	var bob := absf(sin(phase)) * 0.05 * _walk + sin(_t * 1.7) * 0.01 * (1.0 - _walk)
	_torso.position.y = 0.8 + bob
	_hip_l.position.y = 0.8 + bob
	_hip_r.position.y = 0.8 + bob
	_torso.rotation.z = sin(phase) * 0.09 * _walk + sin(_t * 0.9) * 0.02
	var lean := TORSO_LEAN + 0.06 * _walk
	if _soloing:
		lean = -0.12 # cambré en arrière pour le solo
	_torso.rotation.x = lerpf(_torso.rotation.x, lean, delta * 8.0)

	# Tête : saccades nerveuses, headbang pendant le solo.
	_twitch_timer -= delta
	if _twitch_timer <= 0.0:
		_twitch_timer = randf_range(1.5, 4.0)
		_twitch = randf_range(-0.35, 0.35)
	_twitch = move_toward(_twitch, 0.0, delta * 1.5)
	_head.rotation.y = _twitch
	if _soloing:
		_head.rotation.x = -0.1 + absf(sin(_t * 9.0)) * 0.55
	else:
		_head.rotation.x = lerpf(_head.rotation.x, -0.2 + sin(phase) * 0.05 * _walk, delta * 8.0)
	_hair_back.rotation.x = -0.1 - _walk * 0.15 - (absf(sin(_t * 9.0)) * 0.3 if _soloing else 0.0)

	# Grattage permanent pendant le solo.
	if _soloing:
		_strum = absf(sin(_t * 18.0))
	else:
		_strum = move_toward(_strum, 0.0, delta * 4.0)
	_aura.visible = _soloing
	if _soloing:
		_aura.rotation.y += delta * 2.0
		_aura_light.light_energy = 2.2 + sin(_t * 10.0) * 0.5
	_update_arms()


# --- IK des bras ---------------------------------------------------------------

func _update_arms() -> void:
	var gt := _guitar.transform
	var fret := 0.42
	if _soloing:
		fret = 0.3 + 0.18 * (0.5 + 0.5 * sin(_t * 5.0)) # la main gauche court sur le manche
	var left_target := gt * Vector3(0, fret, 0.035)
	var pick := gt * Vector3(0.0, -0.1 + _strum * 0.06, 0.07 + _strum * 0.03)
	var right_target := pick.lerp(gt * Vector3(0, 0.3, 0.03), _smash)
	_solve_arm(_upper_l, _fore_l, left_target, Vector3(-1.0, -0.4, -0.3))
	_solve_arm(_upper_r, _fore_r, right_target, Vector3(1.0, -0.6, -0.4))


## IK analytique à deux segments dans l'espace du torse.
func _solve_arm(upper: Node3D, fore: Node3D, target: Vector3, pole: Vector3) -> void:
	var s := upper.position
	var to := target - s
	var d := clampf(to.length(), 0.05, (UPPER_ARM + FOREARM) * 0.999)
	var dir := to.normalized()
	var cos_a := clampf((UPPER_ARM * UPPER_ARM + d * d - FOREARM * FOREARM) / (2.0 * UPPER_ARM * d), -1.0, 1.0)
	var a := acos(cos_a)
	var perp := (pole - dir * pole.dot(dir)).normalized()
	var elbow := s + (dir * cos(a) + perp * sin(a)) * UPPER_ARM
	var hand := s + dir * d
	upper.basis = _basis_pointing(elbow - s)
	fore.basis = upper.basis.inverse() * _basis_pointing(hand - elbow)


## Base dont l'axe -Y pointe vers `v` (les segments de membres pendent le long de -Y).
func _basis_pointing(v: Vector3) -> Basis:
	var y := -v.normalized()
	var ref := Vector3(0, 0, 1) if absf(y.z) < 0.9 else Vector3(1, 0, 0)
	var x := ref.cross(y).normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z)


# --- Actions ---------------------------------------------------------------------

## Coup de guitare : empoignée par le manche, levée au-dessus de l'épaule puis abattue.
func swing() -> void:
	if _busy or _soloing:
		return
	_busy = true
	var tw := create_tween()
	tw.tween_property(self, "_smash", 1.0, 0.05)
	tw.parallel().tween_property(_guitar, "rotation", GUITAR_WINDUP, 0.09)
	tw.parallel().tween_property(_guitar, "position", Vector3(0.1, 0.45, 0.2), 0.09)
	tw.tween_property(_guitar, "rotation", GUITAR_STRIKE, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_guitar, "position", Vector3(0.05, 0.3, 0.45), 0.09)
	tw.tween_interval(0.07)
	tw.tween_property(_guitar, "rotation", GUITAR_REST, 0.2)
	tw.parallel().tween_property(_guitar, "position", GUITAR_REST_POS, 0.2)
	tw.parallel().tween_property(self, "_smash", 0.0, 0.2)
	tw.tween_callback(func() -> void: _busy = false)


## Accord rageur (lancement de sort) : la guitare se relève, grattage appuyé.
func strum() -> void:
	if _soloing:
		return
	var tw := create_tween()
	tw.tween_property(_guitar, "rotation", GUITAR_SOLO, 0.06)
	tw.parallel().tween_property(self, "_strum", 1.0, 0.06)
	tw.tween_property(self, "_strum", 0.0, 0.12)
	tw.tween_property(_guitar, "rotation", GUITAR_REST, 0.25)


## Posture de solo (pendant le mini-jeu) : cambré, manche levé, headbang, aura dorée.
func solo_pose(active: bool) -> void:
	_soloing = active
	var tw := create_tween()
	tw.tween_property(_guitar, "rotation", GUITAR_SOLO if active else GUITAR_REST, 0.15)
	_strings_mat.emission = Color(1.0, 0.9, 0.55) if active else Color(0.55, 0.85, 1.0)


func flash(color: Color = Color(1.0, 0.1, 0.05)) -> void:
	for m in _flash_mats:
		m.emission = color
	await get_tree().create_timer(0.1, false).timeout
	for m in _flash_mats:
		m.emission = Color.BLACK


func die() -> void:
	_soloing = false
	_moving = false
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "rotation:x", -PI * 0.5, 0.6).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position:y", 0.25, 0.6)
