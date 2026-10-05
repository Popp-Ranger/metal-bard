class_name CharacterSkin
extends Node3D
## Modèle 3D importé d'un PNJ ou d'un ennemi (art/pnj, voir docs/PNJ_3D.md) : maillage à squelette (les
## 17 os de Riffald) et ses propres clips Mixamo, joués par un AnimationTree :
##  - déplacement : repos → marche → course selon la vitesse (style de HeroAnimator.STYLES) ;
##  - par-dessus : une action jouée une fois (coup d'épée...) et un sursaut quand il est touché ;
##  - mort : le clip « die » seul.
## Le modèle regarde vers +Z ; on y accroche des objets avec attach() (épée dans la main...).

const MODELS := {
	"mage": "res://assets/models/pnj/mage.glb",
	"tavernier": "res://assets/models/pnj/tavernier.glb",
	"squelette": "res://assets/models/pnj/squelette.glb",
	"gloubah": "res://assets/models/pnj/gloubah.glb",
	"hibours": "res://assets/models/pnj/hibours.glb",
}
## Hauteur des modèles (m, chapeau compris) : étiquettes, barres de vie.
const HEIGHTS := {"mage": 1.85, "tavernier": 2.05, "squelette": 1.75, "gloubah": 1.84, "hibours": 1.2}
## Agrandissement en jeu (le tavernier orc domine son comptoir) : hauteur et foulée suivent.
const SCALES := {"tavernier": 1.25, "gloubah": 1.5} # Gloubah : 50 % plus grand que les héros
## Hauteur du visage au-dessus de l'os de la tête (m, avant agrandissement) : portrait du dialogue. Gloubah a les yeux
## haut perchés au-dessus de sa grosse tête.
const FACE_OFFSETS := {"gloubah": 0.17}

var skeleton: Skeleton3D
var player: AnimationPlayer
var tree: AnimationTree
var style := "pnj"
var model_id := ""
var height := 1.8
## Matériaux qui clignotent quand le personnage est touché.
var flash_materials: Array[StandardMaterial3D] = []
var lengths := {}
var _walk := 0.0
var _dead := false
## Longueur des jambes / celles de Riffald : la foulée des clips est à la taille du modèle.
var _leg_ratio := 1.0
const RIFFALD_LEG := 0.832


## Modèle `id` (clé de MODELS) animé dans le style `anim_style` ; null si le modèle manque.
static func create(id: String, anim_style: String = "pnj") -> CharacterSkin:
	var path := str(MODELS.get(id, ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var s := CharacterSkin.new()
	s.name = "Skin"
	s.style = anim_style
	s.model_id = id
	var k := float(SCALES.get(id, 1.0))
	s.scale = Vector3.ONE * k
	s.height = float(HEIGHTS.get(id, 1.8)) * k
	s.add_child((load(path) as PackedScene).instantiate())
	return s


func _ready() -> void:
	skeleton = find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	player = find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	for mi in find_children("*", "MeshInstance3D", true, false):
		_style(mi as MeshInstance3D)
	for n in player.get_animation_list():
		lengths[str(n)] = player.get_animation(n).length
	var shin := skeleton.find_bone("shin.L")
	var foot := skeleton.find_bone("foot.L")
	if shin >= 0 and foot >= 0:
		_leg_ratio = (skeleton.get_bone_rest(shin).origin.length() + skeleton.get_bone_rest(foot).origin.length()) / RIFFALD_LEG
	tree = AnimationTree.new()
	tree.name = "AnimationTree"
	player.get_parent().add_child(tree)
	tree.anim_player = tree.get_path_to(player)
	tree.root_node = tree.get_path_to(player.get_node(player.root_node))
	tree.tree_root = _build_tree()
	tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	tree.active = true


## Matériaux mats (sans reflet) qui clignotent quand le personnage est touché.
func _style(mi: MeshInstance3D) -> void:
	for i in mi.mesh.get_surface_count():
		var src := mi.mesh.surface_get_material(i) as StandardMaterial3D
		if src == null:
			continue
		var m := src.duplicate() as StandardMaterial3D
		m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		m.metallic = 0.0
		m.emission_enabled = true
		m.emission = Color.BLACK
		flash_materials.append(m)
		mi.set_surface_override_material(i, m)


func _build_tree() -> AnimationNodeBlendTree:
	var root := AnimationNodeBlendTree.new()
	root.add_node("loco", HeroAnimator.loco_tree(lengths, style))
	var action := AnimationNodeOneShot.new()
	action.fadein_time = 0.08
	action.fadeout_time = 0.2
	root.add_node("action", action)
	root.add_node("action_clip", AnimationNodeAnimation.new())
	var hit := AnimationNodeOneShot.new()
	hit.fadein_time = 0.05
	hit.fadeout_time = 0.2
	root.add_node("hit", hit)
	root.add_node("hit_clip", HeroAnimator.clip(lengths, "hit", false) if lengths.has("hit") else AnimationNodeAnimation.new())
	root.connect_node("action", 0, "loco")
	root.connect_node("action", 1, "action_clip")
	root.connect_node("hit", 0, "action")
	root.connect_node("hit", 1, "hit_clip")
	root.connect_node("output", 0, "hit")
	return root


## Une image : déplacement à `speed` m/s si `moving`.
func step(delta: float, moving: bool, speed: float) -> void:
	if _dead or tree == null:
		return
	_walk = move_toward(_walk, 1.0 if moving else 0.0, delta * 5.0)
	HeroAnimator.drive_loco(tree, "parameters/loco/", _walk, (speed if moving else 0.0) / maxf(_leg_ratio * _size_scale(), 0.01),
		false, delta, style)
	tree.advance(delta)


## Échelle du modèle (la sienne et celle de son parent).
func _size_scale() -> float:
	var p := get_parent() as Node3D
	return scale.y * (p.scale.y if p != null else 1.0)


## Clip joué une fois par-dessus le déplacement, étiré pour durer `duration` secondes.
func action(clip_name: String, duration: float) -> void:
	if _dead or tree == null or not lengths.has(clip_name):
		return
	var n := (tree.tree_root as AnimationNodeBlendTree).get_node("action_clip") as AnimationNodeAnimation
	n.animation = clip_name
	n.use_custom_timeline = true
	n.timeline_length = duration
	n.stretch_time_scale = true
	tree.set("parameters/action/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


## Sursaut quand il est touché.
func hurt() -> void:
	if not _dead and tree != null and lengths.has("hit"):
		tree.set("parameters/hit/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


## Mort : le clip « die » seul (le personnage reste au sol).
func die() -> void:
	_dead = true
	if tree != null:
		tree.active = false
	if player != null and player.has_animation("die"):
		player.play("die")


## Centre du visage (repère du monde) : portraits de la fenêtre de dialogue.
func face_point() -> Vector3:
	var head := skeleton.find_bone("head")
	return skeleton.global_transform * (skeleton.get_bone_global_pose(head).origin + Vector3(0, float(FACE_OFFSETS.get(model_id, 0.08)), 0))


## Accroche `node` à l'os `bone` (il suit l'animation) ; renvoie le point d'attache.
func attach(bone: String, node: Node3D) -> BoneAttachment3D:
	var a := BoneAttachment3D.new()
	a.bone_name = bone
	skeleton.add_child(a)
	a.add_child(node)
	return a


## Place `node` (à accrocher ensuite à l'os `bone` avec attach()) pour qu'à la pose de repos il ait
## l'orientation `model_basis` (repère du modèle), à `along` m le long de l'os, décalé de `offset`
## (repère du modèle) : on raisonne dans le repère du personnage plutôt que dans celui de l'os.
func place(node: Node3D, bone: String, model_basis: Basis, along: float, offset: Vector3) -> void:
	var rest := skeleton.get_bone_global_rest(skeleton.find_bone(bone))
	var rot := rest.basis.orthonormalized()
	node.transform = Transform3D(rot.inverse() * model_basis, Vector3(0, along, 0) + rot.inverse() * offset)
