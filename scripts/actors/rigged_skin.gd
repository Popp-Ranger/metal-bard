class_name RiggedSkin
extends Node3D
## Modèle 3D importé de Blender (maillage à squelette). S'il contient ses animations, elles sont
## jouées par HeroAnimator (AnimationTree) ; sinon il est piloté par les pivots procéduraux
## de HeroModel : toutes les animations existantes (marche, course, frappe, solo, glissade,
## saut à la Angus Young, lit...) restent calculées par HeroModel sur son squelette invisible,
## puis recopiées ici os par os à chaque image.
##  - buste et tête : rotation relative à la pose de repos (pivot actuel × pivot au repos⁻¹) ;
##  - bras et jambes : IK à deux os avec les longueurs du modèle importé, pour que les mains
##    restent exactement sur la guitare et que les pieds suivent ceux du squelette procédural ;
##  - mains et pieds : orientation du pivot correspondant.
## Correspondance des côtés : dans HeroModel, « _l » est du côté -X (main du manche) ; dans le
## modèle Blender, les os « .R » sont du côté -X.

## Surfaces sans contour encré (petites pièces : le contour les masquerait ou les grossirait).
const NO_OUTLINE := ["MB_oeil", "MB_iris", "MB_paupiere", "MB_sourcils", "MB_bouche", "MB_gemme", "MB_argent",
	"MB_cheveux_ombre"]
## Surfaces lumineuses (ne clignotent pas en rouge quand le héros est touché).
const GLOWING := {"MB_gemme": [Color(1.0, 0.1, 0.08), 1.6]}
## Teintes très claires assombries pour l'éclairage sombre du jeu (0 = inchangé).
const DARKEN := {"MB_peau": 0.18, "MB_cheveux": 0.12, "MB_cheveux_ombre": 0.1, "MB_oeil": 0.15}

var skeleton: Skeleton3D
var flash_materials: Array[StandardMaterial3D] = []

var _model: HeroModel
var _bone := {} # nom -> index
var _rest_g := {} # index -> Transform3D (pose de repos, espace du squelette)
var _rest_l := {} # index -> Transform3D (pose de repos locale)
var _base := {} # nom du pivot -> Basis au repos (espace du modèle)
var _leg_offset := {} # "l"/"r" -> décalage cheville importée - cheville procédurale au repos
var _desired := {} # index -> Transform3D voulu (espace du squelette)


static func create(model: HeroModel, path: String) -> RiggedSkin:
	var scene := load(path) as PackedScene
	if scene == null:
		return null
	var s := RiggedSkin.new()
	s._model = model
	s.add_child(scene.instantiate())
	return s


func _ready() -> void:
	skeleton = find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	for b in skeleton.get_bone_count():
		_bone[skeleton.get_bone_name(b)] = b
		_rest_g[b] = skeleton.get_bone_global_rest(b)
		_rest_l[b] = skeleton.get_bone_rest(b)
	for mi in find_children("*", "MeshInstance3D", true, false):
		_style(mi as MeshInstance3D)


## Cel shading comme le reste du jeu : lumière en aplats, contour encré sur les grandes pièces.
func _style(mi: MeshInstance3D) -> void:
	for i in mi.mesh.get_surface_count():
		var src := mi.mesh.surface_get_material(i) as StandardMaterial3D
		if src == null:
			continue
		var m := src.duplicate() as StandardMaterial3D
		var mat_name := src.resource_name
		Visuals.toon(m, not NO_OUTLINE.has(mat_name))
		if m.metallic < 0.2:
			# Matières mates (peau, cheveux, tissu, cuir) : pas de reflet toon, qui les brûle
			# en blanc sous les projecteurs ; teintes claires légèrement assombries.
			m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
			if DARKEN.has(mat_name):
				m.albedo_color = m.albedo_color.darkened(float(DARKEN[mat_name]))
		m.emission_enabled = true
		if GLOWING.has(mat_name):
			var g: Array = GLOWING[mat_name]
			m.emission = g[0]
			m.emission_energy_multiplier = float(g[1])
		else:
			m.emission = Color.BLACK
			flash_materials.append(m)
		mi.set_surface_override_material(i, m)


## À appeler une fois le squelette procédural construit, dans sa pose de repos.
func capture_rest() -> void:
	for n: String in ["_torso", "_head", "_ankle_l", "_ankle_r"]:
		_base[n] = _rel(_model.get(n) as Node3D).basis.orthonormalized()
	# Les pieds du modèle importé sont plus écartés et un peu plus hauts que ceux du squelette
	# procédural : on garde cet écart pour que la foulée conserve la posture du modèle.
	_leg_offset["l"] = (_rest_g[_bone["foot.R"]] as Transform3D).origin - _rel(_model._ankle_l).origin
	_leg_offset["r"] = (_rest_g[_bone["foot.L"]] as Transform3D).origin - _rel(_model._ankle_r).origin


## Transform d'un pivot dans l'espace du modèle (HeroModel), sans passer par la scène.
func _rel(n: Node3D) -> Transform3D:
	var t := n.transform
	var p := n.get_parent() as Node3D
	while p != null and p != _model:
		t = p.transform * t
		p = p.get_parent() as Node3D
	return t


func drive() -> void:
	if skeleton == null or _base.is_empty():
		return
	_desired.clear()
	var m := _model
	# Bassin : suit la hauteur du buste procédural (rebond de la foulée, glissade à genoux...).
	var hips: int = _bone["hips"]
	var hip_t: Transform3D = _rest_g[hips]
	hip_t.origin += Vector3(0, m._torso.position.y - HeroModel.HIP_Y, 0)
	_desired[hips] = hip_t
	# Buste et tête : rotation relative au repos.
	var torso_delta := _rel(m._torso).basis.orthonormalized() * (_base["_torso"] as Basis).inverse()
	_chain("spine", torso_delta)
	_chain("chest", Basis.IDENTITY, false)
	_chain("neck", Basis.IDENTITY, false)
	var head_delta := _rel(m._head).basis.orthonormalized() * (_base["_head"] as Basis).inverse()
	_chain("head", head_delta)
	# Bras (IK sur les longueurs du modèle importé).
	_arm(m._upper_l, m._fore_l, m._hand_l, "R")
	_arm(m._upper_r, m._fore_r, m._hand_r, "L")
	# Jambes.
	_leg(m._hip_l, m._knee_l, m._ankle_l, "R", "l")
	_leg(m._hip_r, m._knee_r, m._ankle_r, "L", "r")
	# Application : poses locales à partir des poses voulues.
	for b: int in _desired:
		var parent := skeleton.get_bone_parent(b)
		var local: Transform3D = _desired[b]
		if parent >= 0 and _desired.has(parent):
			local = (_desired[parent] as Transform3D).affine_inverse() * local
		skeleton.set_bone_pose_position(b, local.origin)
		skeleton.set_bone_pose_rotation(b, local.basis.get_rotation_quaternion())


## Os qui suit son parent (pose de repos locale), avec une rotation globale supplémentaire.
func _chain(bone_name: String, delta: Basis, rotate := true) -> void:
	var b: int = _bone[bone_name]
	var parent := skeleton.get_bone_parent(b)
	var parent_t: Transform3D = _desired[parent]
	var parent_rest: Transform3D = _rest_g[parent]
	var t: Transform3D = parent_t * (_rest_l[b] as Transform3D)
	if rotate:
		t.basis = delta * (_rest_g[b] as Transform3D).basis
	else:
		# Même rotation relative que le parent par rapport à son repos.
		t.basis = parent_t.basis * parent_rest.basis.inverse() * (_rest_g[b] as Transform3D).basis
	_desired[b] = t


func _arm(upper: Node3D, fore: Node3D, hand: Node3D, side: String) -> void:
	var bu: int = _bone["upper_arm." + side]
	var bf: int = _bone["forearm." + side]
	var bh: int = _bone["hand." + side]
	var shoulder := (_desired[skeleton.get_bone_parent(bu)] as Transform3D) * (_rest_l[bu] as Transform3D).origin
	var l1 := (_rest_l[bf] as Transform3D).origin.length()
	var l2 := (_rest_l[bh] as Transform3D).origin.length()
	var target := _rel(hand).origin
	var pole := _rel(fore).origin - _rel(upper).origin
	var joints := ik(shoulder, target, l1, l2, pole)
	_desired[bu] = Transform3D(aim((_rest_g[bu] as Transform3D).basis, joints[0] - shoulder), shoulder)
	_desired[bf] = Transform3D(aim((_rest_g[bf] as Transform3D).basis, joints[1] - joints[0]), joints[0])
	# Main : dans le prolongement des doigts du pivot procédural (doigts vers -Y).
	var fingers := -_rel(hand).basis.orthonormalized().y
	_desired[bh] = Transform3D(aim((_rest_g[bh] as Transform3D).basis, fingers), joints[1])


func _leg(hip: Node3D, knee: Node3D, ankle: Node3D, side: String, key: String) -> void:
	var bt: int = _bone["thigh." + side]
	var bs: int = _bone["shin." + side]
	var bfoot: int = _bone["foot." + side]
	var top := (_desired[_bone["hips"]] as Transform3D) * (_rest_l[bt] as Transform3D).origin
	var l1 := (_rest_l[bs] as Transform3D).origin.length()
	var l2 := (_rest_l[bfoot] as Transform3D).origin.length()
	var ankle_t := _rel(ankle)
	var target: Vector3 = ankle_t.origin + (_leg_offset[key] as Vector3)
	var pole := _rel(knee).origin - _rel(hip).origin
	pole += Vector3(0, 0, 0.15) # les genoux plient toujours vers l'avant
	var joints := ik(top, target, l1, l2, pole)
	_desired[bt] = Transform3D(aim((_rest_g[bt] as Transform3D).basis, joints[0] - top), top)
	_desired[bs] = Transform3D(aim((_rest_g[bs] as Transform3D).basis, joints[1] - joints[0]), joints[0])
	var base_key := "_ankle_" + key
	var foot_delta := ankle_t.basis.orthonormalized() * (_base[base_key] as Basis).inverse()
	_desired[bfoot] = Transform3D(foot_delta * (_rest_g[bfoot] as Transform3D).basis, joints[1])


## IK analytique à deux segments : renvoie [coude, extrémité].
static func ik(a: Vector3, target: Vector3, l1: float, l2: float, pole: Vector3) -> Array[Vector3]:
	var to := target - a
	var d := clampf(to.length(), 0.01, (l1 + l2) * 0.999)
	var dir := to.normalized() if to.length() > 0.0001 else Vector3.DOWN
	var cos_a := clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0)
	var ang := acos(cos_a)
	var perp := pole - dir * pole.dot(dir)
	if perp.length() < 0.0001:
		perp = dir.cross(Vector3.RIGHT)
	perp = perp.normalized()
	var mid := a + (dir * cos(ang) + perp * sin(ang)) * l1
	return [mid, a + dir * d]


## Tourne une base de repos pour que son axe +Y (sens de l'os) pointe vers `dir`.
static func aim(rest: Basis, dir: Vector3) -> Basis:
	var from := rest.y.normalized()
	var to := dir.normalized()
	var d := from.dot(to)
	if d > 0.99999:
		return rest
	if d < -0.99999:
		return Basis(rest.x.normalized(), PI) * rest
	return Basis(Quaternion(from, to)) * rest
