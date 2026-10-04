class_name DemonImp
extends Enemy
## Diablotin : petit démon rouge cornu aux ailes de chauve-souris, qui vole droit sur le héros, une hachette à la
## main. Il plane à un demi-mètre du sol en battant des ailes. Rapide (0,45 × le héros) mais fragile.
## Cryptes de la Cathédrale et Temple du Dragon (l'embuscade de la nef en lâche une dizaine).

const HOVER := 0.5

var _wing_l: Node3D
var _wing_r: Node3D
var _arm: Node3D
var _tail: Node3D


func _configure() -> void:
	var lvl := level - 1
	display_name = "Diablotin"
	max_hp = 9 + 3 * lvl
	armor_class = 12
	attack_bonus = 4 + floori(lvl / 2.0)
	damage_dice = Vector3i(1, 6, 1 + lvl)
	save_bonus = 1
	xp_reward = 40 + 10 * lvl
	gold_range = Vector2i(1, 7)
	radius = 0.35
	height = 1.75
	attack_range = 0.9
	detect_radius = 6.0
	move_speed = Balance.HERO_SPEED * 0.45


func _build_model() -> void:
	var skin := own_mat(Color(0.62, 0.08, 0.05), 0.6)
	var dark := own_mat(Color(0.25, 0.03, 0.03), 0.7)
	var horn := own_mat(Color(0.12, 0.1, 0.08), 0.4)
	var membrane := own_mat(Color(0.35, 0.04, 0.05), 0.8)
	var eye := Visuals.glow_mat(Color(1.0, 0.85, 0.1), 4.0)
	var body := Node3D.new()
	body.position.y = HOVER
	model.add_child(body)
	# Corps, ventre, tête.
	Visuals.capsule(body, 0.16, 0.5, Vector3(0, 0.62, 0), skin)
	Visuals.sphere(body, 0.15, Vector3(0, 0.55, 0.05), dark, Vector3(1.0, 1.1, 0.8))
	Visuals.sphere(body, 0.15, Vector3(0, 0.98, 0.03), skin, Vector3(1.0, 0.95, 1.05))
	Visuals.box(body, Vector3(0.12, 0.06, 0.1), Vector3(0, 0.92, 0.15), skin) # museau
	for side: float in [-1.0, 1.0]:
		Visuals.sphere(body, 0.028, Vector3(0.06 * side, 1.02, 0.13), eye)
		Visuals.cylinder(body, 0.0, 0.012, 0.04, Vector3(0.035 * side, 0.89, 0.19), Visuals.mat(Color(0.95, 0.9, 0.8)), Vector3(180, 0, 0), 4) # crocs
		DemonParts.horn(body, Vector3(0.09 * side, 1.08, 0.0), side, horn, 0.22)
		Visuals.cylinder(body, 0.0, 0.035, 0.1, Vector3(0.15 * side, 1.0, -0.01), skin, Vector3(0, 0, -70 * side), 5) # oreilles pointues
		# Jambes repliées et sabots (il vole).
		Visuals.capsule(body, 0.05, 0.28, Vector3(0.08 * side, 0.3, 0.05), skin, Vector3(35, 0, 0))
		Visuals.capsule(body, 0.04, 0.24, Vector3(0.08 * side, 0.14, -0.03), skin, Vector3(-25, 0, 0))
		Visuals.box(body, Vector3(0.07, 0.05, 0.1), Vector3(0.08 * side, 0.02, -0.06), horn)
	# Bras gauche ballant, bras droit qui tient la hachette.
	Visuals.capsule(body, 0.04, 0.34, Vector3(-0.2, 0.68, 0.04), skin, Vector3(15, 0, -15))
	_arm = Node3D.new()
	_arm.position = Vector3(0.19, 0.82, 0.0)
	body.add_child(_arm)
	Visuals.capsule(_arm, 0.04, 0.34, Vector3(0, -0.15, 0.04), skin, Vector3(20, 0, 10))
	var axe := DemonParts.hatchet(_arm, 0.9)
	axe.position = Vector3(0.04, -0.3, 0.12)
	axe.rotation_degrees = Vector3(-60, 0, 0)
	# Ailes de chauve-souris et queue fourchue.
	_wing_l = DemonParts.bat_wing(body, Vector3(-0.07, 0.82, -0.13), -1.0, dark, membrane, 0.75)
	_wing_r = DemonParts.bat_wing(body, Vector3(0.07, 0.82, -0.13), 1.0, dark, membrane, 0.75)
	_tail = Node3D.new()
	_tail.position = Vector3(0, 0.42, -0.12)
	body.add_child(_tail)
	Visuals.cylinder(_tail, 0.012, 0.03, 0.5, Vector3(0, -0.12, -0.22), skin, Vector3(-60, 0, 0), 6)
	Visuals.cylinder(_tail, 0.0, 0.06, 0.1, Vector3(0, -0.26, -0.45), dark, Vector3(-120, 0, 0), 3) # pointe en flèche
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.3, 0.1)
	glow.light_energy = 0.5
	glow.omni_range = 2.0
	glow.position = Vector3(0, 1.2, 0.3)
	body.add_child(glow)


func _animate(_delta: float, moving: bool) -> void:
	var flap := sin(_anim_t * (16.0 if moving else 10.0))
	_wing_l.rotation.y = -0.2 + flap * 0.7
	_wing_r.rotation.y = 0.2 - flap * 0.7
	_tail.rotation.y = sin(_anim_t * 3.0) * 0.4
	model.position.y = sin(_anim_t * 4.0) * 0.08 + (0.1 if moving else 0.0)
	model.rotation.x = 0.25 if moving else 0.0 # penché en avant quand il fonce


func _attack_anim(windup: float) -> void:
	var tw := create_tween()
	tw.tween_property(_arm, "rotation:x", -2.4, windup * 0.85)
	tw.tween_property(_arm, "rotation:x", 0.6, 0.08)
	tw.tween_property(_arm, "rotation:x", 0.0, 0.25)


func _death_anim() -> void:
	Sfx.play("croak", -10.0, 0.4)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(model, "position:y", -HOVER + 0.05, 0.35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(model, "rotation:x", -PI * 0.5, 0.45)
	_corpse(1.5)
