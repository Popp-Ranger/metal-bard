class_name HeroAnimator
extends SkeletonModifier3D
## Animations du héros prédéfini (Riffald) : clips Mixamo transférés sur son squelette dans
## Blender (art/riffald/retarget_mixamo.py, voir docs/ANIMATIONS.md) et joués par un AnimationTree :
##  - déplacement : repos (voûté quand la vie est basse) → marche → course selon la vitesse ;
##  - actions : coup de guitare, onde de choc, sorts, glissade, Stage Diving, victoire, mort, lit ;
##  - par-dessus, sur le haut du corps : sursaut quand il est touché, hochement de tête sur les accords.
## C'est aussi un SkeletonModifier3D : une fois l'animation appliquée, il place la guitare
## (à la sangle sur le torse, ou empoignée par le manche pour frapper) et ramène les mains
## dessus par IK (main du manche sur les cases, l'autre qui gratte les cordes).

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
## Guitare empoignée : distance main → jonction manche/caisse (repère de la guitare).
const GRIP := 0.3
## Point où la main droite gratte les cordes (repère de la guitare, comme HeroModel._update_arms).
const PICK := Vector3(0.0, -0.1, 0.08)
## Position de jeu du modèle importé : point de grattage (repère du squelette, au repos) et
## inclinaison du manche au-dessus de l'horizontale.
const PLAY_PICK := Vector3(-0.08, 1.1, 0.21)
const PLAY_TILT_DEG := 25.0
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
var _weights := [1.0, 1.0, 0.0]
var _state_time := 0.0
var _state_length := 0.0
var _attack_count := 0


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
	# Guitare : sortie du torse procédural, portée à la sangle sur l'os « chest ».
	_guitar = model._guitar
	if _guitar != null:
		var guitar_t := _in_model(_guitar)
		_guitar_scale = guitar_t.basis.get_scale()
		# Position de jeu (repère du squelette, au repos) : caisse devant le ventre côté droit,
		# manche qui monte vers la gauche du héros (+X), table face au public (+Z).
		var tilt := deg_to_rad(PLAY_TILT_DEG)
		var y := Vector3(cos(tilt), sin(tilt), 0.0)
		var z := Vector3(0.0, -0.15, 1.0).normalized()
		z = (z - y * z.dot(y)).normalized()
		var basis := Basis(y.cross(z), y, z)
		var play := Transform3D(basis, PLAY_PICK - basis * PICK)
		_mount = sk.get_bone_global_rest(_bone["chest"]).affine_inverse() * play
		_fit_mount(sk)
		_guitar.get_parent().remove_child(_guitar)
		model.add_child(_guitar)


## Les bras du modèle importé sont plus courts que ceux du squelette procédural : on remonte la
## guitare vers l'épaule droite juste assez pour que la main droite atteigne les cordes.
func _fit_mount(sk: Skeleton3D) -> void:
	var chest := sk.get_bone_global_rest(_bone["chest"])
	var shoulder := sk.get_bone_global_rest(_bone["upper_arm.R"]).origin
	var reach := (sk.get_bone_rest(_bone["forearm.R"]).origin.length() + sk.get_bone_rest(_bone["hand.R"]).origin.length()) * 0.92
	var pick := chest * _mount * PICK
	var excess := pick.distance_to(shoulder) - reach
	if excess > 0.0:
		var shift := (shoulder - pick).normalized() * excess
		_mount.origin += chest.basis.inverse() * shift


func _clip(anim_name: String, loop: bool, timeline := 0.0, offset := 0.0) -> AnimationNodeAnimation:
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


func _build_tree(skel_path: String) -> AnimationNodeBlendTree:
	# Déplacement : repos (normal / épuisé) mélangé avec marche-course selon la vitesse.
	var loco := AnimationNodeBlendTree.new()
	loco.add_node("idle", _clip("idle", true))
	loco.add_node("tired", _clip("idle_tired", true))
	loco.add_node("tired_mix", AnimationNodeBlend2.new())
	var bs := AnimationNodeBlendSpace1D.new()
	bs.min_space = 0.0
	bs.max_space = RUN_SPEED
	bs.sync = true
	bs.add_blend_point(_clip("walk", true), WALK_SPEED, -1, "walk")
	bs.add_blend_point(_clip("run", true), RUN_SPEED, -1, "run")
	loco.add_node("gait", bs)
	loco.add_node("pace", AnimationNodeTimeScale.new())
	loco.add_node("move", AnimationNodeBlend2.new())
	loco.connect_node("tired_mix", 0, "idle")
	loco.connect_node("tired_mix", 1, "tired")
	loco.connect_node("pace", 0, "gait")
	loco.connect_node("move", 0, "tired_mix")
	loco.connect_node("move", 1, "pace")
	loco.connect_node("output", 0, "move")

	var sm := AnimationNodeStateMachine.new()
	sm.add_node("loco", loco)
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
	var speed := m.move_speed * (1.0 if m._moving else 0.0)
	tree.set("parameters/sm/loco/move/blend_amount", m._walk)
	tree.set("parameters/sm/loco/gait/blend_position", clampf(speed, WALK_SPEED, RUN_SPEED))
	tree.set("parameters/sm/loco/pace/scale", maxf(1.0, speed / RUN_SPEED))
	var tired := float(tree.get("parameters/sm/loco/tired_mix/blend_amount"))
	tree.set("parameters/sm/loco/tired_mix/blend_amount", move_toward(tired, 1.0 if m.tired else 0.0, delta * 2.0))
	# Fin des actions ; se déplacer interrompt un sort ou une frappe déjà lancés.
	_state_time += delta
	if ONE_SHOTS.has(state):
		var done := _state_time >= _state_length
		if m._moving and state != "slide" and _state_time > 0.25:
			done = true
		if done:
			play("solo" if m._soloing else "loco")
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
	var mount := chest * _mount
	var t := mount
	if float(_weights[2]) > 0.001:
		t = mount.interpolate_with(_grip_transform(g, chest), float(_weights[2]))
	var model_t := _skel_to_model() * t
	_guitar.transform = Transform3D(model_t.basis.orthonormalized().scaled_local(_guitar_scale), model_t.origin)
	# Cibles des mains (même placement que l'animation procédurale de HeroModel).
	var ns := model._neck_scale
	var fret := 0.42 * ns
	if model._soloing:
		fret = (0.3 + 0.18 * (0.5 + 0.5 * sin(model._t * 5.0))) * ns
	var strum := model._strum
	var fret_target := t * Vector3(0.02, fret, -0.025)
	var pick_target := t * (PICK + Vector3(0.0, strum * 0.06, strum * 0.03))
	# Guitariste droitier : main gauche (os « .L », côté +X) sur le manche, main droite qui gratte.
	_arm(sk, g, "L", fret_target, float(_weights[0]), chest.basis.x)
	_arm(sk, g, "R", pick_target, float(_weights[1]), -chest.basis.x)


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
	return Transform3D(basis, mid - y * GRIP)


## Bras : IK à deux os vers `target`, mélangée avec la pose animée selon `weight`.
func _arm(sk: Skeleton3D, g: Dictionary, side: String, target: Vector3, weight: float, outward: Vector3) -> void:
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
	var pole := (gf.origin - (shoulder + target) * 0.5).normalized() + outward.normalized() * 0.6 + Vector3.DOWN * 0.3
	var joints := RiggedSkin.ik(shoulder, target, l1, l2, pole)
	var upper := RiggedSkin.aim(gu.basis.orthonormalized(), joints[0] - shoulder)
	var turn := upper * gu.basis.orthonormalized().inverse()
	var fore := RiggedSkin.aim(turn * gf.basis.orthonormalized(), joints[1] - joints[0])
	var hand := fore * gf.basis.orthonormalized().inverse() * gh.basis.orthonormalized()
	upper = gu.basis.orthonormalized().slerp(upper, weight)
	fore = gf.basis.orthonormalized().slerp(fore, weight)
	hand = gh.basis.orthonormalized().slerp(hand, weight)
	var parent := sk.get_bone_global_pose(sk.get_bone_parent(bu)).basis.orthonormalized()
	sk.set_bone_pose_rotation(bu, (parent.inverse() * upper).get_rotation_quaternion())
	sk.set_bone_pose_rotation(bf, (upper.inverse() * fore).get_rotation_quaternion())
	sk.set_bone_pose_rotation(bh, (fore.inverse() * hand).get_rotation_quaternion())


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
