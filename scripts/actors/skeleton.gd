class_name Skeleton
extends Enemy
## Squelette guerrier (FP 1/4 en D&D 5e : CA 13, 13 PV, épée courte 1d6+2).
## Variante « capitaine » : plus grand, casque, plus de PV.
## Variante « chef » : 25 % plus grand, capuche en tête de loup, porte la clé du boss.
## Corps articulé (HumanoidBody) : repos et course de zombie (clips Mixamo) ; le bras de l'épée frappe par IK.

var captain := false
## Chef des squelettes (garde la clé de la salle du boss).
var chief := false
const CHIEF_SCALE := 1.25
## Proportions du corps (avant l'échelle du capitaine ou du chef), voir HumanoidBody.build.
const BODY := {"hip_y": 0.8, "hip_half": 0.11, "thigh": 0.38, "shin": 0.39, "upper_arm": 0.3, "forearm": 0.28,
	"shoulder": Vector3(0.22, 0.59, 0.0), "neck": Vector3(0.0, 0.66, 0.0)}
## Coup d'épée (poignet du bras « _r », repère du buste) : levée au-dessus de l'épaule, puis abattue devant.
const SWORD_RAISED := Vector3(0.3, 0.95, -0.05)
const SWORD_STRUCK := Vector3(0.12, 0.3, 0.5)
## Coup de poignet à l'impact (rad) : la lame passe de perpendiculaire à presque dans l'axe du bras.
const SWORD_FLICK := 1.2
const JAW_Y := 0.02

var _jaw: MeshInstance3D
var _sword: Node3D
## Coup d'épée en cours : 0 = aucun, 0 → 1 élan, 1 → 2 frappe, 2 → 3 retour (voir _attack_anim).
var _strike := 0.0


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
	if chief:
		# Chef des squelettes : un squelette comme les autres, 25 % plus grand, coiffé d'une
		# peau de loup ; il porte la clé de la salle du boss.
		display_name = "Chef des squelettes"
		is_boss = true
		max_hp = 55 + 10 * lvl
		armor_class = 15
		attack_bonus += 2
		damage_dice = Vector3i(1, 10, 3 + lvl)
		xp_reward = 250 + 30 * lvl
		gold_range = Vector2i(20, 40)
		radius = 0.45
		height = 1.7 * CHIEF_SCALE


func _build_model() -> void:
	var s := CHIEF_SCALE if chief else (1.25 if captain else 1.0)
	model.scale = Vector3.ONE * s
	var bone := own_mat(Color(0.82, 0.78, 0.66), 0.7)
	var dark_bone := own_mat(Color(0.55, 0.5, 0.4), 0.8)
	var rust := own_mat(Color(0.38, 0.26, 0.2), 0.6)
	var eye := Visuals.glow_mat(Color(1.0, 0.15, 0.05), 5.0)
	body = HumanoidBody.build(model, BODY)
	body.style = "zombie" # repos et course de zombie (Mixamo), voir HeroAnimator.STYLES
	var b := body

	# Jambes : fémur, rotule, tibia, pied.
	for leg: Array in [[b.hip_l, b.knee_l, b.ankle_l], [b.hip_r, b.knee_r, b.ankle_r]]:
		Visuals.capsule(leg[0], 0.045, 0.4, Vector3(0, -0.19, 0), bone)
		Visuals.sphere(leg[1], 0.042, Vector3.ZERO, bone)
		Visuals.capsule(leg[1], 0.04, 0.4, Vector3(0, -0.19, 0), bone)
		Visuals.box(leg[2], Vector3(0.1, 0.05, 0.18), Vector3(0, -0.005, 0.045), dark_bone)

	# Buste : bassin, colonne, côtes, clavicules, cou.
	Visuals.box(b.torso, Vector3(0.3, 0.1, 0.14), Vector3(0, 0.02, 0), dark_bone) # bassin
	Visuals.cylinder(b.torso, 0.035, 0.035, 0.5, Vector3(0, 0.3, -0.03), dark_bone) # colonne
	for i in 4: # côtes
		Visuals.torus(b.torso, 0.1, 0.13, Vector3(0, 0.35 + i * 0.07, 0.0), bone, Vector3(0, 0, 0)).scale = Vector3(1.1 - i * 0.05, 0.4, 0.8)
	Visuals.box(b.torso, Vector3(0.44, 0.06, 0.1), Vector3(0, 0.61, 0), bone) # clavicules
	Visuals.cylinder(b.torso, 0.025, 0.025, 0.1, Vector3(0, 0.66, -0.01), dark_bone) # cou

	# Tête : crâne, mâchoire, orbites rougeoyantes.
	Visuals.sphere(b.head, 0.14, Vector3(0, 0.15, 0.01), bone, Vector3(0.95, 1.05, 1.05))
	_jaw = Visuals.box(b.head, Vector3(0.16, 0.06, 0.12), Vector3(0, JAW_Y, 0.06), dark_bone)
	Visuals.sphere(b.head, 0.03, Vector3(-0.05, 0.16, 0.12), eye)
	Visuals.sphere(b.head, 0.03, Vector3(0.05, 0.16, 0.12), eye)
	if captain and not chief:
		Visuals.sphere(b.head, 0.16, Vector3(0, 0.21, 0), rust, Vector3(1.0, 0.7, 1.0)) # casque
		Visuals.cylinder(b.head, 0.0, 0.03, 0.2, Vector3(-0.13, 0.34, 0), rust, Vector3(0, 0, 30))
		Visuals.cylinder(b.head, 0.0, 0.03, 0.2, Vector3(0.13, 0.34, 0), rust, Vector3(0, 0, -30))

	# Bras : humérus, coude, avant-bras, main osseuse.
	for arm: Array in [[b.upper_l, b.fore_l, b.hand_l], [b.upper_r, b.fore_r, b.hand_r]]:
		Visuals.capsule(arm[0], 0.035, 0.32, Vector3(0, -0.15, 0), bone)
		Visuals.sphere(arm[1], 0.034, Vector3.ZERO, bone)
		Visuals.capsule(arm[1], 0.03, 0.3, Vector3(0, -0.14, 0), bone)
		Visuals.box(arm[2], Vector3(0.05, 0.08, 0.03), Vector3(0, -0.04, 0), dark_bone)
	# Épée rouillée au poing (côté +X) : lame selon l'axe X de la main, vers l'avant quand le bras
	# pend ; bouclier sanglé sur l'avant-bras (côté -X).
	_sword = Node3D.new()
	var sword := _sword
	sword.position = Vector3(0, -0.04, 0)
	sword.rotation.y = PI * 0.5
	b.hand_r.add_child(sword)
	Visuals.box(sword, Vector3(0.05, 0.05, 0.14), Vector3.ZERO, dark_bone)
	Visuals.box(sword, Vector3(0.18, 0.03, 0.04), Vector3(0, 0, 0.08), rust)
	Visuals.box(sword, Vector3(0.05, 0.02, (0.6 if captain or chief else 0.5)), Vector3(0, 0, 0.4), rust)
	Visuals.cylinder(b.fore_l, 0.2, 0.2, 0.04, Vector3(0.0, -0.14, 0.1), rust, Vector3(90, 0, 0))
	if chief:
		_build_wolf_pelt()


## Peau de loup du chef : tête de loup portée en capuche, pelisse sur les épaules,
## pattes croisées sur la poitrine et queue dans le dos ; la clé pend à la ceinture.
func _build_wolf_pelt() -> void:
	var fur := own_mat(Color(0.46, 0.43, 0.4), 0.95)
	var dark_fur := own_mat(Color(0.26, 0.24, 0.23), 0.95)
	var pale := own_mat(Color(0.72, 0.68, 0.62), 0.9)
	var fang := own_mat(Color(0.95, 0.93, 0.85), 0.4)
	var black := Visuals.mat(Color(0.03, 0.03, 0.03), 0.3)
	var head := body.head
	var torso := body.torso
	# Tête de loup en capuche, posée sur le crâne, museau vers l'avant.
	Visuals.sphere(head, 0.17, Vector3(0, 0.23, -0.01), fur, Vector3(1.08, 0.78, 1.15))
	Visuals.box(head, Vector3(0.13, 0.09, 0.2), Vector3(0, 0.25, 0.17), fur, Vector3(8, 0, 0)) # museau
	Visuals.box(head, Vector3(0.1, 0.035, 0.16), Vector3(0, 0.205, 0.19), pale, Vector3(8, 0, 0)) # mâchoire
	Visuals.sphere(head, 0.028, Vector3(0, 0.275, 0.275), black) # truffe
	for side: float in [-1.0, 1.0]:
		Visuals.cylinder(head, 0.0, 0.05, 0.12, Vector3(0.09 * side, 0.38, -0.03), dark_fur, Vector3(0, 0, -12 * side), 6) # oreilles
		Visuals.cylinder(head, 0.0, 0.012, 0.045, Vector3(0.035 * side, 0.175, 0.24), fang, Vector3(180, 0, 0), 5) # crocs
		Visuals.sphere(head, 0.018, Vector3(0.06 * side, 0.29, 0.13), Visuals.glow_mat(Color(1.0, 0.65, 0.15), 1.5)) # yeux vitreux
		# Pelisse sur les épaules et pattes avant croisées sur la poitrine.
		Visuals.sphere(torso, 0.13, Vector3(0.17 * side, 0.63, -0.01), fur, Vector3(1.2, 0.55, 1.1))
		Visuals.capsule(torso, 0.045, 0.34, Vector3(0.07 * side, 0.51, 0.12), fur, Vector3(0, 0, 38 * side))
		Visuals.sphere(torso, 0.045, Vector3(-0.03 * side, 0.41, 0.14), dark_fur) # pattes
	# Peau qui tombe dans le dos jusqu'aux genoux, avec la queue.
	Visuals.box(torso, Vector3(0.46, 0.72, 0.05), Vector3(0, 0.35, -0.14), fur, Vector3(-6, 0, 0))
	Visuals.box(torso, Vector3(0.3, 0.12, 0.2), Vector3(0, 0.71, -0.06), dark_fur) # nuque
	Visuals.capsule(torso, 0.05, 0.45, Vector3(0, -0.1, -0.19), dark_fur, Vector3(-15, 0, 0)) # queue
	# Clé de la salle du boss à la ceinture.
	var gold := Visuals.glow_mat(Color(1.0, 0.8, 0.3), 1.5)
	Visuals.torus(torso, 0.035, 0.05, Vector3(0.17, -0.02, 0.06), gold, Vector3(0, 0, 90))
	Visuals.box(torso, Vector3(0.02, 0.14, 0.02), Vector3(0.17, -0.12, 0.06), gold)


func _animate(delta: float, moving: bool) -> void:
	super(delta, moving) # repos et course de zombie
	if _strike > 0.0:
		_strike_arm()
	# Poing de l'épée paume vers le corps : la lame pointe devant lui, perpendiculaire à l'avant-bras ;
	# pendant la frappe, le poignet la rabat dans le prolongement du bras (coup de taille vers le bas).
	HumanoidBody.orient_hand(body.upper_r, body.fore_r, body.hand_r, Vector3(-1, 0, 0), 0.0)
	var flick := clampf(_strike - 1.0, 0.0, 1.0) if _strike <= 2.0 else clampf(3.0 - _strike, 0.0, 1.0)
	_sword.basis = Basis(Vector3.BACK, -SWORD_FLICK * flick) * Basis(Vector3.UP, PI * 0.5)
	# Petit cliquetis permanent de la mâchoire.
	_jaw.position.y = JAW_Y - absf(sin(_anim_t * 9.0)) * 0.02


## Bras de l'épée pendant le coup, mélangé avec la pose animée à l'élan et au retour.
func _strike_arm() -> void:
	var target := SWORD_RAISED
	var weight := 1.0
	if _strike <= 1.0:
		weight = _strike
	elif _strike <= 2.0:
		target = SWORD_RAISED.lerp(SWORD_STRUCK, _strike - 1.0)
	else:
		target = SWORD_STRUCK
		weight = 3.0 - _strike
	body.reach("r", body.wrist("r").lerp(target, weight), Vector3(1.0, -0.2, -0.8))


func _attack_anim(windup: float) -> void:
	_strike = 0.0
	var tw := create_tween()
	tw.tween_property(self, "_strike", 1.0, windup * 0.85).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "_strike", 2.0, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "_strike", 3.0, 0.35)
	tw.tween_callback(func() -> void: _strike = 0.0)
