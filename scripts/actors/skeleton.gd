class_name Skeleton
extends Enemy
## Squelette guerrier (FP 1/4 en D&D 5e : CA 13, 13 PV, épée courte 1d6+2).
## Variante « capitaine » : plus grand, casque, plus de PV.
## Variante « chef » : 25 % plus grand, capuche en tête de loup, porte la clé du boss.
## Modèle 3D importé (squelette paysan, art/pnj) : repos et course de zombie, coup d'épée (Great Sword
## Slash), sursaut et mort (clips Mixamo, voir CharacterSkin) ; épée, bouclier, casque et peau de loup
## accrochés à ses os.

var captain := false
## Chef des squelettes (garde la clé de la salle du boss).
var chief := false
const CHIEF_SCALE := 1.25
## Part du coup d'épée avant l'impact (le clip est étiré pour que l'impact tombe à la fin de l'élan).
const STRIKE_AT := 0.55

var skin: CharacterSkin


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
	skin = CharacterSkin.create("squelette", "zombie_modele")
	model.add_child(skin)
	_flash_mats.append_array(skin.flash_materials)
	var dark_bone := own_mat(Color(0.55, 0.5, 0.4), 0.8)
	var rust := own_mat(Color(0.38, 0.26, 0.2), 0.6)
	# Épée rouillée dans la main droite (os « hand.R », côté -X), bouclier sur l'avant-bras gauche.
	# Orientations données dans le repère du modèle, pour la pose de repos (bras le long du corps) : lame
	# vers l'avant au bout du poing ; bouclier face à l'avant, au milieu de l'avant-bras.
	var sword := Node3D.new()
	skin.place(sword, "hand.R", Basis.IDENTITY, 0.08, Vector3.ZERO)
	Visuals.box(sword, Vector3(0.05, 0.05, 0.14), Vector3.ZERO, dark_bone)
	Visuals.box(sword, Vector3(0.18, 0.03, 0.04), Vector3(0, 0, 0.08), rust)
	Visuals.box(sword, Vector3(0.05, 0.02, (0.6 if captain or chief else 0.5)), Vector3(0, 0, 0.4), rust)
	skin.attach("hand.R", sword)
	var shield := Node3D.new()
	Visuals.cylinder(shield, 0.2, 0.2, 0.04, Vector3.ZERO, rust, Vector3(90, 0, 0))
	skin.place(shield, "forearm.L", Basis.IDENTITY, 0.13, Vector3(0.0, 0.0, 0.08))
	skin.attach("forearm.L", shield)
	if captain and not chief:
		var helmet := Node3D.new()
		Visuals.sphere(helmet, 0.16, Vector3(0, 0.17, 0), rust, Vector3(1.0, 0.7, 1.0)) # casque
		Visuals.cylinder(helmet, 0.0, 0.03, 0.2, Vector3(-0.13, 0.3, 0), rust, Vector3(0, 0, 30))
		Visuals.cylinder(helmet, 0.0, 0.03, 0.2, Vector3(0.13, 0.3, 0), rust, Vector3(0, 0, -30))
		skin.attach("head", helmet)
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
	var head := Node3D.new()
	head.position = Vector3(0, -0.04, 0)
	skin.attach("head", head)
	var torso := Node3D.new()
	torso.position = Vector3(0, -0.42, 0) # repère de l'ancien buste (au bassin)
	skin.attach("chest", torso)
	var hips := Node3D.new()
	hips.position = Vector3(0, -0.1, 0)
	skin.attach("hips", hips)
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
	Visuals.capsule(hips, 0.05, 0.45, Vector3(0, -0.1, -0.19), dark_fur, Vector3(-15, 0, 0)) # queue
	# Clé de la salle du boss à la ceinture.
	var gold := Visuals.glow_mat(Color(1.0, 0.8, 0.3), 1.5)
	Visuals.torus(hips, 0.035, 0.05, Vector3(0.17, -0.02, 0.06), gold, Vector3(0, 0, 90))
	Visuals.box(hips, Vector3(0.02, 0.14, 0.02), Vector3(0.17, -0.12, 0.06), gold)


func _animate(delta: float, _moving: bool) -> void:
	skin.step(delta, _speed_now > 0.05, _speed_now)


## Coup d'épée : le clip « slash » étiré pour que l'impact tombe à la fin de l'élan.
func _attack_anim(windup: float) -> void:
	skin.action("slash", windup / STRIKE_AT)


func _flash() -> void:
	if skin != null:
		skin.hurt()
	super()


func _death_anim() -> void:
	Sfx.play("bones", -6.0)
	skin.die()
	_corpse(2.5)
