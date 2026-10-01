class_name LocoAnimator
extends Node3D
## Posture et déplacement de Riffald pour les personnages procéduraux (HeroModel sans modèle importé :
## héros personnalisés, PNJ, clients de la taverne). Les mêmes clips Mixamo que Riffald (repos, repos
## épuisé, marche, course : voir HeroAnimator.loco_tree) sont joués sur une copie invisible de son
## squelette, sans maillage, puis recopiés à chaque image sur les pivots procéduraux :
##  - bassin, buste, tête et pieds : rotation de l'os par rapport à sa pose de repos ;
##  - jambes et bras : IK à deux segments vers les chevilles et les poignets de Riffald, ramenés à la
##    longueur des membres procéduraux (même direction, même allonge relative) ;
##  - mains libres : paume tournée comme celle de Riffald.
## Correspondance des côtés : pivots « _l » (côté -X) = os « .R » de Riffald (voir RiggedSkin).
## Le squelette de Riffald est à l'origine de sa scène : son repère est celui du modèle.

const SOURCE := "res://assets/models/riffald/riffald.glb"

## Squelette et animations de Riffald sans maillage (construit une seule fois).
static var _rig: PackedScene

var model: HeroModel
var tree: AnimationTree
var skeleton: Skeleton3D
## Durée des clips (s).
var lengths := {}

var _bone := {}
var _rest := {} # nom de l'os -> Quaternion (rotation de repos)
var _hips_rest := Vector3.ZERO
var _leg_k := 1.0 # longueur des jambes procédurales / jambes de Riffald
var _arm_k := 1.0
var _palm := {}


## Ajoute l'animateur au modèle (null si le modèle de Riffald est absent).
static func attach(m: HeroModel) -> LocoAnimator:
	var rig := _rig_scene()
	if rig == null:
		return null
	var a := LocoAnimator.new()
	a.name = "LocoAnimator"
	a.model = m
	a.add_child(rig.instantiate())
	m.add_child(a)
	a._setup()
	return a


static func _rig_scene() -> PackedScene:
	if _rig == null and ResourceLoader.exists(SOURCE):
		var src := (load(SOURCE) as PackedScene).instantiate()
		for mi in src.find_children("*", "MeshInstance3D", true, false):
			mi.get_parent().remove_child(mi)
			mi.free()
		src.scene_file_path = ""
		var packed := PackedScene.new()
		if packed.pack(src) == OK:
			_rig = packed
		src.free()
	return _rig


func _setup() -> void:
	skeleton = find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player := find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	for b in skeleton.get_bone_count():
		var bone_name := skeleton.get_bone_name(b)
		_bone[bone_name] = b
		_rest[bone_name] = skeleton.get_bone_global_rest(b).basis.get_rotation_quaternion()
	for n in player.get_animation_list():
		lengths[str(n)] = player.get_animation(n).length
	_hips_rest = skeleton.get_bone_global_rest(_bone["hips"]).origin
	_leg_k = (HeroModel.THIGH + HeroModel.SHIN) / (_length("shin.L") + _length("foot.L"))
	_arm_k = (HeroModel.UPPER_ARM + HeroModel.FOREARM) / (_length("forearm.L") + _length("hand.L"))
	_palm = HeroAnimator.rest_palms(skeleton)
	tree = AnimationTree.new()
	tree.name = "AnimationTree"
	player.get_parent().add_child(tree)
	tree.anim_player = tree.get_path_to(player)
	tree.root_node = tree.get_path_to(player.get_node(player.root_node))
	tree.tree_root = HeroAnimator.loco_tree(lengths)
	# Avancé par HeroModel juste avant la recopie (pas d'animation pour un modèle figé).
	tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	tree.active = true


## Longueur du segment qui mène à l'os `bone_name` (distance entre la tête de son parent et la sienne).
func _length(bone_name: String) -> float:
	return skeleton.get_bone_rest(_bone[bone_name]).origin.length()


## Avance les clips d'une image : `walk` = 0 immobile → 1 en marche, `speed` = vitesse réelle (m/s).
## La foulée est à la taille du personnage (un ogre fait de plus grands pas) : la vitesse est ramenée
## à l'échelle de Riffald pour choisir et accélérer les cycles, sans que les pieds glissent.
func advance(delta: float, walk: float, speed: float, tired: bool) -> void:
	var size := maxf(_leg_k * model.scale.z, 0.01)
	HeroAnimator.drive_loco(tree, "parameters/", walk, speed / size, tired, delta)
	tree.advance(delta)


## Bassin, buste, tête et jambes du modèle procédural dans la pose courante.
func apply_body() -> void:
	var m := model
	var hips := skeleton.get_bone_global_pose(_bone["hips"])
	var pelvis := Vector3(0.0, HeroModel.HIP_Y, 0.0) + (hips.origin - _hips_rest) * _leg_k
	var hips_rot := _turn("hips")
	m._torso.position = pelvis
	m._torso.basis = _spine(hips.origin)
	m._head.basis = m._torso.basis.inverse() * Basis(Vector3.UP, m.head_turn) * _turn("head")
	var half := hips_rot * Vector3(HeroModel.HIP_HALF_WIDTH, 0.0, 0.0)
	_leg(m._hip_l, m._knee_l, m._ankle_l, ".R", pelvis - half, hips_rot)
	_leg(m._hip_r, m._knee_r, m._ankle_r, ".L", pelvis + half, hips_rot)


## Bras et mains libres (sans guitare en main) dans la pose courante.
func apply_arms() -> void:
	var m := model
	var torso := Transform3D(m._torso.basis, m._torso.position)
	_arm(m._upper_l, m._fore_l, m._hand_l, ".R", torso, Vector3(-0.4, -0.2, -1.0))
	_arm(m._upper_r, m._fore_r, m._hand_r, ".L", torso, Vector3(0.4, -0.2, -1.0))


## Buste procédural (d'un seul bloc, du bassin aux épaules) : dans l'axe bassin → cou de Riffald, qui
## rend la courbure de son dos, et tourné comme son torse.
func _spine(hips: Vector3) -> Basis:
	var y := (skeleton.get_bone_global_pose(_bone["neck"]).origin - hips).normalized()
	var z := _turn("chest") * Vector3.BACK
	z = (z - y * z.dot(y)).normalized()
	return Basis(y.cross(z), y, z)


## Rotation de l'os depuis sa pose de repos.
func _turn(bone_name: String) -> Basis:
	var q := skeleton.get_bone_global_pose(_bone[bone_name]).basis.get_rotation_quaternion()
	return Basis(q * (_rest[bone_name] as Quaternion).inverse())


## Jambe : de la hanche `top` à une cheville placée comme celle de Riffald par rapport à sa hanche.
func _leg(hip: Node3D, knee: Node3D, ankle: Node3D, side: String, top: Vector3, hips_rot: Basis) -> void:
	var thigh_b := skeleton.get_bone_global_pose(_bone["thigh" + side]).origin
	var knee_b := skeleton.get_bone_global_pose(_bone["shin" + side]).origin
	var ankle_b := skeleton.get_bone_global_pose(_bone["foot" + side]).origin
	var target := top + (ankle_b - thigh_b) * _leg_k
	var pole := knee_b - (thigh_b + ankle_b) * 0.5 + hips_rot.z * 0.01 # genou vers l'avant si la jambe est tendue
	var joints := RiggedSkin.ik(top, target, HeroModel.THIGH, HeroModel.SHIN, pole)
	var hinge := (joints[0] - top).cross(joints[1] - joints[0])
	if hinge.length() < 0.0001:
		hinge = hips_rot.x
	var thigh := _segment(joints[0] - top, hinge)
	var shin := _segment(joints[1] - joints[0], hinge)
	hip.position = top
	hip.basis = thigh
	knee.basis = thigh.inverse() * shin
	ankle.basis = shin.inverse() * _turn("foot" + side)


## Bras : poignet placé comme celui de Riffald par rapport à son épaule, coude du même côté.
func _arm(upper: Node3D, fore: Node3D, hand: Node3D, side: String, torso: Transform3D, rest_pole: Vector3) -> void:
	var shoulder_b := skeleton.get_bone_global_pose(_bone["upper_arm" + side]).origin
	var elbow_b := skeleton.get_bone_global_pose(_bone["forearm" + side]).origin
	var hand_b := skeleton.get_bone_global_pose(_bone["hand" + side])
	var wrist := torso * upper.position + (hand_b.origin - shoulder_b) * _arm_k
	var inv := torso.basis.inverse()
	var pole := inv * (elbow_b - (shoulder_b + hand_b.origin) * 0.5) * 10.0 + rest_pole * 0.1
	model._solve_arm(upper, fore, torso.affine_inverse() * wrist, pole)
	var palm: Vector3 = hand_b.basis.orthonormalized() * (_palm[side.substr(1)] as Vector3)
	model._orient_hand(upper, fore, hand, inv * palm, 0.0)


## Base d'un segment de membre procédural (qui pend le long de -Y) orienté selon `v`, axe X sur la
## charnière du genou.
static func _segment(v: Vector3, hinge: Vector3) -> Basis:
	var y := -v.normalized()
	var x := hinge - y * hinge.dot(y)
	x = x.normalized() if x.length() > 0.0001 else y.cross(Vector3.FORWARD).normalized()
	return Basis(x, y, x.cross(y))
