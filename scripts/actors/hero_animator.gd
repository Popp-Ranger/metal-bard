class_name HeroAnimator
extends SkeletonModifier3D
## Animations du héros prédéfini (Riffald) : clips Mixamo transférés sur son squelette dans
## Blender (art/riffald/retarget_mixamo.py, voir docs/ANIMATIONS.md) et joués par un AnimationTree :
##  - déplacement : repos (voûté quand la vie est basse) → marche → course selon la vitesse ;
##  - actions : coup de guitare, onde de choc, sorts, glissade, Stage Diving, victoire, mort, lit ;
##  - par-dessus, sur le haut du corps : sursaut quand il est touché, hochement de tête sur les accords.
## C'est aussi un SkeletonModifier3D : une fois l'animation appliquée, il place la guitare
## (à la sangle sur le torse, empoignée par le manche pour frapper, ou dans le dos là où l'on ne
## joue pas) et ramène les mains dessus par IK (main gauche au bout du manche, main droite qui gratte
## au centre de la caisse).

## Vitesse naturelle des cycles transférés sur Riffald (m/s) : au-delà, la course accélère.
const WALK_SPEED := 1.5
const RUN_SPEED := 2.9
const XFADE := 0.15
const LOOPS := ["idle", "idle_tired", "walk", "run", "headbang", "fall", "sleep"]
## États joués une fois puis retour au déplacement : durée à l'écran (s), 0 = durée du clip.
const ONE_SHOTS := {"smash": 0.6, "slash": 0.6, "area": 1.0, "cast": 1.1, "slide": 0.67, "land": 0.55, "victory": 3.2}
## Poids par état : [main du manche sur la guitare, main qui gratte, guitare empoignée].
const HANDS := {
	"loco": [1.0, 1.0, 0.0], "solo": [1.0, 1.0, 0.0], "slide": [1.0, 1.0, 0.0],
	"smash": [0.0, 0.0, 1.0], "slash": [0.0, 0.0, 1.0], "area": [0.0, 0.0, 0.0], "cast": [0.0, 0.0, 0.0],
	"fall": [0.0, 0.0, 0.0], "land": [0.0, 0.0, 0.0], "victory": [0.0, 0.0, 0.0],
	"die": [0.0, 0.0, 0.0], "sleep": [0.0, 0.0, 0.0],
}
## Taille de la guitare par héros (RaceDB.PRESETS, "rig") : Riffald a des mains surdimensionnées (×1,3),
## sa guitare l'est aussi, sinon ses poings couvrent tout le manche. Les positions ci-dessous sont dans le
## repère de la guitare d'origine (avant agrandissement).
const GUITAR_SCALE := 1.3
## Guitare empoignée : distance main → jonction manche/caisse (repère de la guitare).
const GRIP := 0.3
## Point où le médiator gratte les cordes : sur la caisse, entre le micro aigu et le chevalet
## (les micros d'une Flying V sont collés au manche : y gratter revient à tenir la jonction).
const PICK := Vector3(0.0, -0.19, 0.045)
## Main droite : poignet au-dessus des cordes, côté du bord haut de la caisse ; doigts qui descendent
## vers les cordes (vers le sol et le chevalet), paume tournée vers les cordes.
const PICK_WRIST := Vector3(-0.09, -0.16, 0.09)
const PICK_FINGERS := Vector3(1.0, -0.3, -0.15)
## Main gauche au bout du manche (hauteur : HeroModel.FRET_AT) : poignet sous le manche, un peu devant ;
## la paume remonte jusqu'au bord du manche et les doigts se replient sur la touche.
const FRET_WRIST := Vector3(0.16, 0.0, 0.07)
const FRET_FINGERS := Vector3(-1.0, 0.0, -0.2)
## Les deux paumes regardent la table de la guitare (-Z de la guitare).
const PALM_DIR := Vector3(0.0, 0.0, -1.0)
## Position de jeu du modèle importé : point de grattage (repère du squelette, au repos ; valeur de Riffald,
## remplacée par "play_pick" du héros) et inclinaison du manche au-dessus de l'horizontale.
const PLAY_PICK := Vector3(-0.08, 1.06, 0.2)
const PLAY_TILT_DEG := 25.0
## Guitare dans le dos (repère du squelette, au repos) : jonction manche/caisse au milieu du dos,
## par-dessus la cape ; orientation : HeroModel.back_basis().
const BACK_POS := Vector3(0.0, 1.15, -0.25)
## Os filtrés pour les réactions du haut du corps.
const UPPER := ["spine", "chest", "neck", "head"]
const NOD := ["neck", "head"]

var model: HeroModel
var tree: AnimationTree
var state := "loco"
## Longueur des clips (s).
var lengths := {}

var _playback: AnimationNodeStateMachinePlayback
var _bone := {}
var _guitar: Node3D
var _guitar_scale := Vector3.ONE
var _mount := Transform3D.IDENTITY # guitare dans le repère de l'os « chest »
var _back_mount := Transform3D.IDENTITY # guitare dans le dos, même repère
var _palm := {} # "L"/"R" -> normale de la paume dans le repère de l'os « hand »
var _weights := [1.0, 1.0, 0.0]
var _state_time := 0.0
var _state_length := 0.0
var _attack_count := 0
## Réglages du héros prédéfini (RaceDB.PRESETS, "rig"), par défaut ceux de Riffald.
var guitar_scale := GUITAR_SCALE
var play_pick := PLAY_PICK
var back_pos := BACK_POS


## Branche l'animateur sur le modèle importé si celui-ci contient ses animations.
static func attach(m: HeroModel, skin: RiggedSkin) -> HeroAnimator:
	var players := skin.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty() or not (players[0] as AnimationPlayer).has_animation("idle"):
		return null
	var a := HeroAnimator.new()
	a.model = m
	a.name = "HeroAnimator"
	skin.skeleton.add_child(a)
	a._setup(players[0] as AnimationPlayer)
	return a


func _setup(player: AnimationPlayer) -> void:
	var sk := get_skeleton()
	var rig: Dictionary = RaceDB.preset_rig(str(model.appearance.get("preset", "")))
	guitar_scale = float(rig.get("guitar_scale", GUITAR_SCALE))
	play_pick = rig.get("play_pick", PLAY_PICK)
	back_pos = rig.get("back_pos", BACK_POS)
	for b in sk.get_bone_count():
		_bone[sk.get_bone_name(b)] = b
	for n in player.get_animation_list():
		lengths[str(n)] = player.get_animation(n).length
	# Chemin des pistes d'os (« Riffald_rig/Skeleton3D:hips » -> « Riffald_rig/Skeleton3D »).
	var track := str(player.get_animation("idle").track_get_path(0))
	var skel_path := track.substr(0, track.find(":"))
	tree = AnimationTree.new()
	tree.name = "AnimationTree"
	player.get_parent().add_child(tree)
	tree.anim_player = tree.get_path_to(player)
	tree.root_node = tree.get_path_to(player.get_node(player.root_node))
	tree.tree_root = _build_tree(skel_path)
	tree.active = true
	_playback = tree.get("parameters/sm/playback") as AnimationNodeStateMachinePlayback
	_playback.start("loco")
	_palm = rest_palms(sk)
	# Guitare : sortie du torse procédural, portée à la sangle sur l'os « chest ».
	_guitar = model._guitar
	if _guitar != null:
		var guitar_t := _in_model(_guitar)
		_guitar_scale = guitar_t.basis.get_scale() * guitar_scale
		# Position de jeu (repère du squelette, au repos) : caisse devant le ventre côté droit,
		# manche qui monte vers la gauche du héros (+X), table face au public (+Z).
		var tilt := deg_to_rad(PLAY_TILT_DEG)
		var y := Vector3(cos(tilt), sin(tilt), 0.0)
		var z := Vector3(0.0, -0.15, 1.0).normalized()
		z = (z - y * z.dot(y)).normalized()
		var basis := Basis(y.cross(z), y, z)
		var play := Transform3D(basis, play_pick - basis * (PICK * guitar_scale))
		_mount = sk.get_bone_global_rest(_bone["chest"]).affine_inverse() * play
		_fit_mount(sk)
		_back_mount = sk.get_bone_global_rest(_bone["chest"]).affine_inverse() \
			* Transform3D(HeroModel.back_basis(), back_pos)
		_guitar.get_parent().remove_child(_guitar)
		model.add_child(_guitar)


## Normale de la paume de chaque main ("L"/"R") dans le repère de l'os « hand ». Dans Blender
## (build_riffald.py, build_hand), la main est construite doigts le long de l'os, pouce vers w0 et
## paume n = (doigts × w0) × côté ; la conversion glTF (x, z, -y) est une rotation, le produit
## vectoriel est donc le même dans le repère du squelette.
static func rest_palms(sk: Skeleton3D) -> Dictionary:
	var palms := {}
	for side: String in ["L", "R"]:
		var s := 1.0 if side == "L" else -1.0
		var rest := sk.get_bone_global_rest(sk.find_bone("hand." + side)).basis.orthonormalized()
		var w0 := Vector3(-0.55 * s, 0.0, 0.85).normalized()
		palms[side] = rest.inverse() * (rest.y.cross(w0).normalized() * s)
	return palms


## Les bras du modèle importé sont plus courts que ceux du squelette procédural : on remonte la
## guitare vers l'épaule droite juste assez pour que la main droite atteigne les cordes.
func _fit_mount(sk: Skeleton3D) -> void:
	var chest := sk.get_bone_global_rest(_bone["chest"])
	var shoulder := sk.get_bone_global_rest(_bone["upper_arm.R"]).origin
	var reach := (sk.get_bone_rest(_bone["forearm.R"]).origin.length() + sk.get_bone_rest(_bone["hand.R"]).origin.length()) * 0.92
	var wrist := chest * _mount * (PICK_WRIST * guitar_scale)
	var excess := wrist.distance_to(shoulder) - reach
	if excess > 0.0:
		var shift := (shoulder - wrist).normalized() * excess
		_mount.origin += chest.basis.inverse() * shift


func _clip(anim_name: String, loop: bool, timeline := 0.0, offset := 0.0) -> AnimationNodeAnimation:
	return clip(lengths, anim_name, loop, timeline, offset)


## Nœud d'animation : `lengths` = durée des clips (s) ; `timeline` > 0 = durée à l'écran,
## `offset` > 0 = segment du clip joué à sa vitesse d'origine.
static func clip(lengths: Dictionary, anim_name: String, loop: bool, timeline := 0.0, offset := 0.0) -> AnimationNodeAnimation:
	var n := AnimationNodeAnimation.new()
	n.animation = anim_name
	if loop and timeline <= 0.0:
		timeline = float(lengths.get(anim_name, 1.0)) # le mode boucle du nœud exige une timeline propre
	if timeline > 0.0 or offset > 0.0:
		n.use_custom_timeline = true
		n.timeline_length = timeline if timeline > 0.0 else float(lengths.get(anim_name, 1.0))
		n.stretch_time_scale = offset <= 0.0 # segment (offset) : vitesse d'origine
		n.start_offset = offset
	n.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	return n


## Styles de déplacement : clips (repos, repos épuisé, marche, course), vitesse naturelle de la marche
## et de la course (m/s, à l'échelle de Riffald) et cadence minimale (1 = jamais ralentie : en dessous de
## la marche, les pieds glissent un peu ; un cycle unique peut être ralenti pour suivre la vitesse).
##  - "" : Riffald (héros) ;
##  - "pnj_corps" : PNJ à corps procédural (clients, Gérald...) : repos « pnjPose » (bibliothèque « squelettes »),
##    marche et course de Riffald ;
##  - "zombie" : squelettes ennemis, clips de assets/animations/squelettes.glb (bibliothèque « squelettes »,
##    voir LocoAnimator) : repos et course de zombie, qui trottine à 1,6 m/s.
const STYLES := {
	"": {"idle": "idle", "tired": "idle_tired", "walk": "walk", "run": "run",
		"walk_speed": WALK_SPEED, "run_speed": RUN_SPEED, "min_pace": 1.0},
	"pnj_corps": {"idle": "squelettes/idle_pnj", "tired": "squelettes/idle_pnj", "walk": "walk", "run": "run",
		"walk_speed": WALK_SPEED, "run_speed": RUN_SPEED, "min_pace": 1.0},
	"zombie": {"idle": "squelettes/zombie_idle", "tired": "squelettes/zombie_idle", "walk": "squelettes/zombie_run",
		"run": "squelettes/zombie_run", "walk_speed": 1.6, "run_speed": 1.6, "min_pace": 0.6},
	# Modèles importés des PNJ et ennemis (CharacterSkin) : leurs clips sont dans leur propre glb.
	"pnj": {"idle": "idle", "tired": "idle", "walk": "walk", "run": "run",
		"walk_speed": WALK_SPEED, "run_speed": RUN_SPEED, "min_pace": 1.0},
	"zombie_modele": {"idle": "zombie_idle", "tired": "zombie_idle", "walk": "zombie_run", "run": "zombie_run",
		"walk_speed": 1.6, "run_speed": 1.6, "min_pace": 0.6},
}


## Déplacement : repos (normal / épuisé) mélangé avec marche-course selon la vitesse (voir drive_loco).
## Partagé avec LocoAnimator (corps procéduraux), dans le style `style` (voir STYLES).
static func loco_tree(lengths: Dictionary, style := "") -> AnimationNodeBlendTree:
	var st: Dictionary = STYLES[style]
	var loco := AnimationNodeBlendTree.new()
	loco.add_node("idle", clip(lengths, str(st["idle"]), true))
	loco.add_node("tired", clip(lengths, str(st["tired"]), true))
	loco.add_node("tired_mix", AnimationNodeBlend2.new())
	var bs := AnimationNodeBlendSpace1D.new()
	bs.min_space = 0.0
	bs.max_space = maxf(float(st["run_speed"]), 0.1)
	bs.sync = true
	bs.add_blend_point(clip(lengths, str(st["walk"]), true), float(st["walk_speed"]), -1, "walk")
	if float(st["run_speed"]) > float(st["walk_speed"]):
		bs.add_blend_point(clip(lengths, str(st["run"]), true), float(st["run_speed"]), -1, "run")
	loco.add_node("gait", bs)
	loco.add_node("pace", AnimationNodeTimeScale.new())
	loco.add_node("move", AnimationNodeBlend2.new())
	loco.connect_node("tired_mix", 0, "idle")
	loco.connect_node("tired_mix", 1, "tired")
	loco.connect_node("pace", 0, "gait")
	loco.connect_node("move", 0, "tired_mix")
	loco.connect_node("move", 1, "pace")
	loco.connect_node("output", 0, "move")
	return loco


## Paramètres du déplacement (`path` : chemin du BlendTree de loco_tree dans l'AnimationTree) :
## `walk` = 0 immobile → 1 en marche, `speed` = vitesse (m/s, à l'échelle de Riffald), `tired` = épuisé.
static func drive_loco(tree: AnimationTree, path: String, walk: float, speed: float, tired: bool, delta: float,
		style := "") -> void:
	var st: Dictionary = STYLES[style]
	var run_speed := float(st["run_speed"])
	tree.set(path + "move/blend_amount", walk)
	tree.set(path + "gait/blend_position", clampf(speed, float(st["walk_speed"]), run_speed))
	tree.set(path + "pace/scale", maxf(float(st["min_pace"]), speed / run_speed))
	var t := float(tree.get(path + "tired_mix/blend_amount"))
	tree.set(path + "tired_mix/blend_amount", move_toward(t, 1.0 if tired else 0.0, delta * 2.0))


func _build_tree(skel_path: String) -> AnimationNodeBlendTree:
	var sm := AnimationNodeStateMachine.new()
	sm.add_node("loco", loco_tree(lengths))
	sm.add_node("solo", _clip("headbang", true))
	sm.add_node("fall", _clip("fall", true))
	sm.add_node("sleep", _clip("sleep", true))
	sm.add_node("die", _clip("die", false))
	for s: String in ONE_SHOTS:
		sm.add_node(s, _clip(s, false, float(ONE_SHOTS[s])))
	var states := ["loco", "solo", "fall", "sleep", "die"] + ONE_SHOTS.keys()
	for a: String in states:
		for b: String in states:
			if a != b and a != "die":
				var t := AnimationNodeStateMachineTransition.new()
				t.xfade_time = XFADE
				sm.add_transition(a, b, t)

	var root := AnimationNodeBlendTree.new()
	root.add_node("sm", sm)
	root.add_node("hit_clip", _clip("hit", false, 0.0))
	root.add_node("nod_clip", _clip("headbang", false, 0.45, 0.25))
	var hit := AnimationNodeOneShot.new()
	hit.fadein_time = 0.06
	hit.fadeout_time = 0.2
	hit.filter_enabled = true
	for b: String in UPPER:
		hit.set_filter_path(NodePath(skel_path + ":" + b), true)
	var nod := AnimationNodeOneShot.new()
	nod.fadein_time = 0.05
	nod.fadeout_time = 0.15
	nod.filter_enabled = true
	for b: String in NOD:
		nod.set_filter_path(NodePath(skel_path + ":" + b), true)
	root.add_node("hit", hit)
	root.add_node("nod", nod)
	root.connect_node("hit", 0, "sm")
	root.connect_node("hit", 1, "hit_clip")
	root.connect_node("nod", 0, "hit")
	root.connect_node("nod", 1, "nod_clip")
	root.connect_node("output", 0, "nod")
	return root


# --- Commandes (appelées par HeroModel) ---------------------------------------------------

## Passe dans un état : action jouée une fois (ONE_SHOTS) ou état tenu (solo, vol, lit, mort).
func play(s: String) -> void:
	if state == "die":
		return
	if s == state and ONE_SHOTS.has(s):
		_playback.start(s, true) # coups enchaînés : on reprend du début
	else:
		_playback.travel(s)
	state = s
	_state_time = 0.0
	_state_length = float(ONE_SHOTS.get(s, 0.0))


## Coup de guitare : frappe verticale et coup diagonal en alternance.
func attack() -> void:
	_attack_count += 1
	play("smash" if _attack_count % 2 == 1 else "slash")


func is_busy() -> bool:
	return ONE_SHOTS.has(state)


## Sursaut du haut du corps quand il est touché (pas pendant une action ni allongé).
func hurt() -> void:
	if state in ["loco", "solo"]:
		tree.set("parameters/hit/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


## Hochement de tête sur un accord (riff, accordage...).
func nod() -> void:
	if state in ["loco", "solo", "slide"]:
		tree.set("parameters/nod/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func _process(delta: float) -> void:
	if tree == null:
		return
	var m := model
	drive_loco(tree, "parameters/sm/loco/", m._walk, m.move_speed * (1.0 if m._moving else 0.0), m.tired, delta)
	# Fin des actions ; se déplacer interrompt un sort ou une frappe déjà lancés.
	_state_time += delta
	if ONE_SHOTS.has(state):
		var done := _state_time >= _state_length
		if m._moving and state != "slide" and _state_time > 0.25:
			done = true
		if done:
			play("solo" if m._soloing else "loco")
	if m.guitar_slung:
		_weights = [0.0, 0.0, 0.0] # guitare dans le dos : mains libres (animation seule)
		return
	var target: Array = HANDS.get(state, [1.0, 1.0, 0.0])
	for i in 3:
		_weights[i] = move_toward(float(_weights[i]), float(target[i]), delta / XFADE)


# --- Guitare et mains (après l'animation) -------------------------------------------------

func _process_modification_with_delta(_delta: float) -> void:
	var sk := get_skeleton()
	if sk == null or _guitar == null:
		return
	var g := {}
	for n: String in ["chest", "upper_arm.L", "forearm.L", "hand.L", "upper_arm.R", "forearm.R", "hand.R"]:
		g[n] = sk.get_bone_global_pose(_bone[n])
	var chest: Transform3D = g["chest"]
	if model.guitar_slung:
		_place_guitar(chest * _back_mount)
		return
	var mount := chest * _mount
	var t := mount
	if float(_weights[2]) > 0.001:
		t = mount.interpolate_with(_grip_transform(g, chest), float(_weights[2]))
	_place_guitar(t)
	# Guitariste droitier : main gauche (os « .L », côté +X) au bout du manche, main droite qui gratte
	# sur la caisse ; poignets placés par IK, mains orientées vers la guitare.
	var hands := hand_targets(t)
	var gb := t.basis
	_arm(sk, g, "L", hands["L"], float(_weights[0]), chest.basis.x, gb * FRET_FINGERS, gb * PALM_DIR)
	_arm(sk, g, "R", hands["R"], float(_weights[1]), -chest.basis.x, gb * PICK_FINGERS, gb * PALM_DIR)


## Poignets voulus (repère du squelette) pour une guitare placée en `t` (sans échelle) : main gauche au
## bout du manche (elle court sur le manche pendant le solo), main droite qui descend en grattant.
func hand_targets(t: Transform3D) -> Dictionary:
	var nut := HeroModel.PROC_NUT * model._neck_scale
	var fret := HeroModel.FRET_AT * nut
	if model._soloing:
		fret = lerpf(HeroModel.SOLO_FRETS.x, HeroModel.SOLO_FRETS.y, 0.5 + 0.5 * sin(model._t * 5.0)) * nut
	var strum := PICK_FINGERS.normalized() * model._strum * 0.035
	return {"L": t * ((FRET_WRIST + Vector3(0.0, fret, 0.0)) * guitar_scale),
		"R": t * ((PICK_WRIST + strum) * guitar_scale)}


## Guitare : transform `t` (repère du squelette) appliquée au pivot de guitare de HeroModel.
func _place_guitar(t: Transform3D) -> void:
	var model_t := _skel_to_model() * t
	_guitar.transform = Transform3D(model_t.basis.orthonormalized().scaled_local(_guitar_scale), model_t.origin)


## Guitare tenue par le manche comme une hache : dans le prolongement des bras.
func _grip_transform(g: Dictionary, chest: Transform3D) -> Transform3D:
	var hl: Vector3 = (g["hand.L"] as Transform3D).origin
	var hr: Vector3 = (g["hand.R"] as Transform3D).origin
	var mid := (hl + hr) * 0.5
	var shoulders := ((g["upper_arm.L"] as Transform3D).origin + (g["upper_arm.R"] as Transform3D).origin) * 0.5
	var blade := mid - shoulders
	if blade.length() < 0.01:
		blade = chest.basis.z
	blade = blade.normalized()
	var y := -blade # le manche remonte vers les mains, la caisse part devant
	var x := chest.basis.x.normalized()
	x = (x - y * x.dot(y))
	if x.length() < 0.01:
		x = chest.basis.z.normalized().cross(y)
	x = x.normalized()
	var basis := Basis(x, y, x.cross(y))
	return Transform3D(basis, mid - y * GRIP * guitar_scale)


## Bras : IK à deux os qui amène le poignet en `wrist`, main orientée doigts vers `fingers` et paume
## vers `palm` (sinon elle garde sa flexion animée) ; le tout mélangé avec la pose animée selon `weight`.
func _arm(sk: Skeleton3D, g: Dictionary, side: String, wrist: Vector3, weight: float, outward: Vector3,
		fingers := Vector3.ZERO, palm := Vector3.ZERO) -> void:
	if weight <= 0.001:
		return
	var bu: int = _bone["upper_arm." + side]
	var bf: int = _bone["forearm." + side]
	var bh: int = _bone["hand." + side]
	var gu: Transform3D = g["upper_arm." + side]
	var gf: Transform3D = g["forearm." + side]
	var gh: Transform3D = g["hand." + side]
	var shoulder := gu.origin
	var l1 := sk.get_bone_rest(bf).origin.length()
	var l2 := sk.get_bone_rest(bh).origin.length()
	var pole := (gf.origin - (shoulder + wrist) * 0.5).normalized() + outward.normalized() * 0.6 + Vector3.DOWN * 0.3
	var joints := RiggedSkin.ik(shoulder, wrist, l1, l2, pole)
	var upper := RiggedSkin.aim(gu.basis.orthonormalized(), joints[0] - shoulder)
	var turn := upper * gu.basis.orthonormalized().inverse()
	var fore := RiggedSkin.aim(turn * gf.basis.orthonormalized(), joints[1] - joints[0])
	var hand := fore * gf.basis.orthonormalized().inverse() * gh.basis.orthonormalized()
	if fingers != Vector3.ZERO:
		hand = hand_basis(side, fingers, palm)
	upper = gu.basis.orthonormalized().slerp(upper, weight)
	fore = gf.basis.orthonormalized().slerp(fore, weight)
	hand = gh.basis.orthonormalized().slerp(hand, weight)
	var parent := sk.get_bone_global_pose(sk.get_bone_parent(bu)).basis.orthonormalized()
	sk.set_bone_pose_rotation(bu, (parent.inverse() * upper).get_rotation_quaternion())
	sk.set_bone_pose_rotation(bf, (upper.inverse() * fore).get_rotation_quaternion())
	sk.set_bone_pose_rotation(bh, (fore.inverse() * hand).get_rotation_quaternion())


## Orientation (repère du squelette) de l'os « hand.<side> » : doigts (axe +Y de l'os) vers `fingers`,
## paume tournée vers `palm` (ramenée perpendiculaire aux doigts).
func hand_basis(side: String, fingers: Vector3, palm: Vector3) -> Basis:
	var y := fingers.normalized()
	var n := palm - y * palm.dot(y)
	if n.length() < 0.001:
		n = y.cross(Vector3.RIGHT)
	n = n.normalized()
	var nl: Vector3 = _palm[side]
	var bone_frame := Basis(Vector3.UP, nl, Vector3.UP.cross(nl))
	return Basis(y, n, y.cross(n)) * bone_frame.inverse()


## Normale de la paume (repère du squelette) dans la pose actuelle.
func palm_normal(side: String) -> Vector3:
	var sk := get_skeleton()
	return sk.get_bone_global_pose(_bone["hand." + side]).basis.orthonormalized() * (_palm[side] as Vector3)


## Repère du squelette -> repère de HeroModel.
func _skel_to_model() -> Transform3D:
	return _in_model(get_skeleton())


func _in_model(n: Node3D) -> Transform3D:
	var t := n.transform
	var p := n.get_parent() as Node3D
	while p != null and p != model:
		t = p.transform * t
		p = p.get_parent() as Node3D
	return t
