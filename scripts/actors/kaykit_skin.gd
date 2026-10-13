class_name KayKitSkin
extends Node3D
## Personnage du pack KayKit Skeletons (Kay Lousberg, CC0, assets/models/kits/squelettes) : un modèle sur le squelette
## « Rig_Medium » et les animations du même squelette, rangées dans deux fichiers à part :
##  - Rig_Medium_General : repos, coups reçus, morts, apparition (Spawn_Ground : il sort de terre), Throw... ;
##  - Rig_Medium_MovementBasic : marche et course.
## Elles sont recopiées une fois pour toutes dans une bibliothèque partagée et jouées par un AnimationPlayer, avec
## des fondus : repos → marche → course selon la vitesse, et par-dessus une action jouée une fois.
## Le pack gratuit n'a pas de clip d'attaque : le coup est « Throw » (le bras armé ramené par-dessus l'épaule).
## Le modèle regarde vers +Z ; armes et boucliers vont dans les os « handslot.r » / « handslot.l ».

const DIR := "res://assets/models/kits/squelettes/"
const MODELS := {"minion": "Skeleton_Minion.glb", "rogue": "Skeleton_Rogue.glb", "warrior": "Skeleton_Warrior.glb",
	"mage": "Skeleton_Mage.glb"}
const ANIM_FILES := ["Rig_Medium_General.glb", "Rig_Medium_MovementBasic.glb"]
## Clips qui tournent en boucle (ils sont fournis sans boucle).
const LOOPED := ["Idle_A", "Idle_B", "Walking_A", "Walking_B", "Walking_C", "Running_A", "Running_B"]
## Hauteur du sommet du crâne à l'échelle 1 (m).
const HEIGHT := 2.17
## Vitesse (m/s, échelle 1) à laquelle la marche et la course sont jouées à leur cadence d'origine.
const WALK_SPEED := 1.9
const RUN_SPEED := 4.6
const FADE := 0.18

static var _library: AnimationLibrary

var model: Node3D
var skeleton: Skeleton3D
var player: AnimationPlayer
## Matériaux (propres à ce personnage) qui clignotent quand il est touché.
var flash_materials: Array[StandardMaterial3D] = []
var _action_left := 0.0
var _current := ""
var _dead := false


## Squelette `kind` (minion, rogue, warrior, mage).
static func create(kind: String) -> KayKitSkin:
	var s := KayKitSkin.new()
	s.name = "Skin"
	s.model = (load(DIR + str(MODELS.get(kind, MODELS["minion"]))) as PackedScene).instantiate() as Node3D
	s.add_child(s.model)
	s.skeleton = s.model.find_child("Skeleton3D", true, false) as Skeleton3D
	s.player = AnimationPlayer.new()
	s.player.name = "AnimationPlayer"
	s.model.add_child(s.player) # racine des pistes « Rig_Medium/Skeleton3D:os » = le modèle
	s.player.add_animation_library("", library())
	for mi in s.model.find_children("*", "MeshInstance3D", true, false):
		s._own_materials(mi as MeshInstance3D)
	return s


## Bibliothèque des clips KayKit (construite au premier usage).
static func library() -> AnimationLibrary:
	if _library != null:
		return _library
	_library = AnimationLibrary.new()
	for f: String in ANIM_FILES:
		var inst := (load(DIR + f) as PackedScene).instantiate()
		var ap := inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
		for n in ap.get_animation_list():
			if str(n).contains("Pose") or _library.has_animation(n):
				continue
			var a := ap.get_animation(n).duplicate() as Animation
			if str(n) in LOOPED:
				a.loop_mode = Animation.LOOP_LINEAR
			_library.add_animation(n, a)
		inst.free()
	return _library


## Matériaux propres au personnage (pour le faire clignoter seul) ; les yeux lumineux gardent le leur.
func _own_materials(mi: MeshInstance3D) -> void:
	for i in mi.mesh.get_surface_count():
		var m := mi.mesh.surface_get_material(i) as StandardMaterial3D
		if m == null or m.resource_name == "Glow":
			continue
		var own := m.duplicate() as StandardMaterial3D
		own.emission_enabled = true
		own.emission = Color.BLACK
		mi.set_surface_override_material(i, own)
		flash_materials.append(own)


## Teinte des yeux lumineux (rouges pour le boss...).
func set_eye_color(c: Color) -> void:
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D).mesh.surface_get_material(0) as StandardMaterial3D
		if m != null and m.resource_name == "Glow":
			var own := m.duplicate() as StandardMaterial3D
			own.albedo_color = c
			own.emission_enabled = true
			own.emission = c
			own.emission_energy_multiplier = 3.0
			(mi as MeshInstance3D).set_surface_override_material(0, own)


func _ready() -> void:
	_play("Idle_A", 1.0)
	player.seek(randf() * player.current_animation_length, true) # pas tous en même temps


## Accroche `node` à l'os `bone` (« handslot.r », « handslot.l », « head », « chest »...).
func attach(bone: String, node: Node3D) -> void:
	var ba := BoneAttachment3D.new()
	ba.bone_name = bone
	skeleton.add_child(ba)
	ba.add_child(node)


## Arme ou bouclier du pack (assets/models/kits/squelettes/armes/<nom>.gltf) dans l'os `bone`.
func equip(item: String, bone: String) -> Node3D:
	var w := (load(DIR + "armes/" + item + ".gltf") as PackedScene).instantiate() as Node3D
	attach(bone, w)
	for mi in w.find_children("*", "MeshInstance3D", true, false):
		_own_materials(mi as MeshInstance3D)
	return w


## Déplacement : repos, marche ou course selon `speed` (m/s), à la taille du modèle.
func step(delta: float, moving: bool, speed: float) -> void:
	if _dead:
		return
	if _action_left > 0.0:
		_action_left -= delta
		if _action_left > 0.0:
			return
	var k := maxf(scale.x * get_parent_scale(), 0.01)
	if not moving:
		_play("Idle_A", 1.0)
	elif speed > 3.0 * k:
		_play("Running_A", clampf(speed / (RUN_SPEED * k), 0.6, 1.8))
	else:
		_play("Walking_A", clampf(speed / (WALK_SPEED * k), 0.5, 1.8))


func get_parent_scale() -> float:
	var p := get_parent() as Node3D
	return p.scale.x if p != null else 1.0


## Action jouée une fois en `duration` secondes (« Throw » pour un coup, « Spawn_Ground » pour sortir de terre...).
func action(clip: String, duration: float) -> void:
	if _dead or not player.has_animation(clip):
		return
	var length := player.get_animation(clip).length
	player.play(clip, 0.08)
	player.speed_scale = length / maxf(duration, 0.05)
	_current = clip
	_action_left = duration


## Sursaut quand il est touché (sauf en pleine action).
func hurt() -> void:
	if _action_left <= 0.0 and not _dead:
		action("Hit_A", 0.45)


func die(clip: String = "Death_A", duration: float = 0.9) -> void:
	action(clip, duration)
	_dead = true


func is_busy() -> bool:
	return _action_left > 0.0


func _play(clip: String, speed: float) -> void:
	if _current != clip:
		player.play(clip, FADE)
		_current = clip
	player.speed_scale = speed
