class_name HumanoidBody
extends RefCounted
## Corps humanoïde procédural, animé avec la posture et la démarche de Riffald (LocoAnimator) :
## héros personnalisés et PNJ (HeroModel), ennemis humanoïdes (squelettes et futurs ennemis).
##
## Hiérarchie de pivots, dans le repère du `root` (le personnage regarde vers +Z, les membres pendent
## le long de -Y) : buste au bassin et tête sur le buste ; hanche → genou → cheville sous le `root` ;
## épaule → coude → poignet sur le buste. « _l » est le côté -X, « _r » le côté +X.
##
## Nouvel ennemi humanoïde : dans _build_model(), `body = HumanoidBody.build(model, {...})`, accrocher
## ses maillages aux pivots, et Enemy._animate l'anime (voir Skeleton).

var root: Node3D
var torso: Node3D
var head: Node3D
var hip_l: Node3D
var hip_r: Node3D
var knee_l: Node3D
var knee_r: Node3D
var ankle_l: Node3D
var ankle_r: Node3D
var upper_l: Node3D
var upper_r: Node3D
var fore_l: Node3D
var fore_r: Node3D
var hand_l: Node3D
var hand_r: Node3D
## Dimensions (m, repère du root) : hauteur du bassin, demi-écart des hanches, segments des membres.
var hip_y := 0.93
var hip_half := 0.1
var thigh := 0.45
var shin := 0.43
var upper_arm := 0.29
var forearm := 0.26
## Rotation de la tête vers sa gauche (+) ou sa droite (−), pour regarder quelqu'un.
var head_turn := 0.0
## Repos épuisé (vie basse).
var tired := false
## Style de déplacement (HeroAnimator.STYLES) : "" = Riffald, "zombie" = squelettes ennemis.
var style := ""
## Clips de Riffald : créé à la première image animée (null si le modèle de Riffald manque).
var loco: LocoAnimator

var _walk := 0.0
var _loco_tried := false


## Construit les pivots sous `root`. `dims` : "hip_y", "hip_half", "thigh", "shin", "upper_arm",
## "forearm" (voir ci-dessus), "shoulder" (épaule « _r » sur le buste) et "neck" (tête sur le buste).
static func build(r: Node3D, dims := {}) -> HumanoidBody:
	var b := HumanoidBody.new()
	b.root = r
	b.hip_y = float(dims.get("hip_y", b.hip_y))
	b.hip_half = float(dims.get("hip_half", b.hip_half))
	b.thigh = float(dims.get("thigh", b.thigh))
	b.shin = float(dims.get("shin", b.shin))
	b.upper_arm = float(dims.get("upper_arm", b.upper_arm))
	b.forearm = float(dims.get("forearm", b.forearm))
	var shoulder: Vector3 = dims.get("shoulder", Vector3(0.2, 0.48, 0.0))
	b.torso = _pivot(r, Vector3(0.0, b.hip_y, 0.0))
	b.head = _pivot(b.torso, dims.get("neck", Vector3(0.0, 0.6, 0.0)))
	b.hip_l = _pivot(r, Vector3(-b.hip_half, b.hip_y, 0.0))
	b.hip_r = _pivot(r, Vector3(b.hip_half, b.hip_y, 0.0))
	b.knee_l = _pivot(b.hip_l, Vector3(0.0, -b.thigh, 0.0))
	b.knee_r = _pivot(b.hip_r, Vector3(0.0, -b.thigh, 0.0))
	b.ankle_l = _pivot(b.knee_l, Vector3(0.0, -b.shin, 0.0))
	b.ankle_r = _pivot(b.knee_r, Vector3(0.0, -b.shin, 0.0))
	b.upper_l = _pivot(b.torso, Vector3(-shoulder.x, shoulder.y, shoulder.z))
	b.upper_r = _pivot(b.torso, shoulder)
	b.fore_l = _pivot(b.upper_l, Vector3(0.0, -b.upper_arm, 0.0))
	b.fore_r = _pivot(b.upper_r, Vector3(0.0, -b.upper_arm, 0.0))
	b.hand_l = _pivot(b.fore_l, Vector3(0.0, -b.forearm, 0.0))
	b.hand_r = _pivot(b.fore_r, Vector3(0.0, -b.forearm, 0.0))
	return b


static func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var p := Node3D.new()
	p.position = pos
	parent.add_child(p)
	return p


## Crée l'animateur (clips de Riffald) s'il n'existe pas encore ; false s'il est indisponible.
func ensure_loco() -> bool:
	if loco == null and not _loco_tried:
		_loco_tried = true
		loco = LocoAnimator.attach(self)
	return loco != null


## Une image d'animation : posture et déplacement de Riffald à la vitesse `speed` (m/s), bras libres
## compris si `arms` (sinon l'appelant les place lui-même). False si les clips sont indisponibles.
func step(delta: float, moving: bool, speed: float, arms := true) -> bool:
	if not ensure_loco():
		return false
	_walk = move_toward(_walk, 1.0 if moving else 0.0, delta * 5.0)
	loco.advance(delta, _walk, speed if moving else 0.0, tired)
	loco.apply_body()
	if arms:
		loco.apply_arms()
	return true


## Position du poignet `side` ("l"/"r") dans le repère du buste.
func wrist(side: String) -> Vector3:
	var upper := upper_l if side == "l" else upper_r
	var fore := fore_l if side == "l" else fore_r
	var hand := hand_l if side == "l" else hand_r
	return upper.transform * (fore.transform * hand.position)


## Bras `side` amené par IK sur `target` (repère du buste), coude du côté de `pole`.
func reach(side: String, target: Vector3, pole: Vector3) -> void:
	if side == "l":
		solve_limb(upper_l, fore_l, upper_arm, forearm, target, pole, Vector3.RIGHT, false)
	else:
		solve_limb(upper_r, fore_r, upper_arm, forearm, target, pole, Vector3.RIGHT, false)


## IK à deux segments dans le repère du parent de `upper` : extrémité en `target`, articulation du
## côté de `pole`. Axe X des segments sur la charnière (`fallback_x` si le membre est tendu), Z du
## côté vers lequel le membre se plie : la jambe (`knee`) plie vers l'arrière, le bras vers l'avant.
## Seule la rotation des pivots change (leur échelle est conservée).
static func solve_limb(upper: Node3D, lower: Node3D, l1: float, l2: float, target: Vector3, pole: Vector3,
		fallback_x: Vector3, knee: bool) -> void:
	var top := upper.position
	var joints := RiggedSkin.ik(top, target, l1, l2, pole)
	var a := joints[0] - top
	var b := joints[1] - joints[0]
	var hinge := a.cross(b) if knee else b.cross(a)
	if hinge.length() < 0.0001:
		hinge = fallback_x
	var ub := segment(a, hinge)
	upper.quaternion = ub.get_rotation_quaternion()
	lower.quaternion = (ub.inverse() * segment(b, hinge)).get_rotation_quaternion()


## Base d'un segment de membre (qui pend le long de -Y) orienté selon `v`, axe X sur `hinge`.
static func segment(v: Vector3, hinge: Vector3) -> Basis:
	var y := -v.normalized()
	var x := hinge - y * hinge.dot(y)
	x = x.normalized() if x.length() > 0.0001 else y.cross(Vector3.FORWARD).normalized()
	return Basis(x, y, x.cross(y))


## Oriente la main dans le prolongement de l'avant-bras (doigts vers -Y), paume tournée vers `palm_dir`
## (repère du parent de `upper`) ; `wrist_pitch` plie le poignet.
static func orient_hand(upper: Node3D, fore: Node3D, hand: Node3D, palm_dir: Vector3, wrist_pitch: float) -> void:
	var fb := upper.basis.orthonormalized() * fore.basis.orthonormalized()
	var y := fb.y.normalized()
	var z := palm_dir - y * palm_dir.dot(y)
	if z.length() < 0.01:
		return
	z = z.normalized()
	var desired := Basis(y.cross(z), y, z)
	hand.quaternion = (fb.inverse() * desired * Basis(Vector3.RIGHT, wrist_pitch)).get_rotation_quaternion()
