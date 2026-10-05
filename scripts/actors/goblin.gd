class_name Goblin
extends Enemy
## Gobelin des montagnes : le modèle 3D fourni par Ulysse (art/pnj « gobelin », 1,15 m : casque de cuir, grandes
## oreilles, long nez, épaulière au crâne), animé avec les clips Mixamo de Riffald (repos d'orc voûté, marche,
## course, coup, sursaut, mort). Plus rapide qu'un squelette, mais fragile. Arme tirée au hasard, tenue dans la
## main droite : gourdin clouté, coutelas ou lance (plus d'allonge).

## 0 = gourdin, 1 = coutelas, 2 = lance.
var weapon := -1
var skin: CharacterSkin
## Moment de l'impact dans le clip « slash » (fraction de sa durée), calé sur la fin de l'élan.
const STRIKE_AT := 0.55


func _configure() -> void:
	var lvl := level - 1
	if weapon < 0:
		weapon = randi() % 3
	display_name = "Gobelin"
	max_hp = 10 + 3 * lvl
	armor_class = 12
	attack_bonus = 4 + floori(lvl / 2.0)
	damage_dice = Vector3i(1, 6, 1 + lvl) if weapon != 1 else Vector3i(1, 4, 2 + lvl)
	save_bonus = 1
	xp_reward = 40 + 10 * lvl
	gold_range = Vector2i(2, 9)
	radius = 0.32
	height = 1.15
	attack_range = 1.6 if weapon == 2 else 1.0
	move_speed = Balance.HERO_SPEED * 0.32
	detect_radius = 5.0


func _build_model() -> void:
	skin = CharacterSkin.create("gobelin")
	model.add_child(skin)
	_flash_mats.append_array(skin.flash_materials)
	# Arme dans la main droite (os « hand.R ») : à la pose de repos, pointée vers l'avant au bout du poing.
	var w := Node3D.new()
	skin.place(w, "hand.R", Basis.IDENTITY, 0.06, Vector3.ZERO)
	var wood := Visuals.mat(Color(0.3, 0.18, 0.08), 0.85)
	var iron := Visuals.mat(Color(0.35, 0.33, 0.32), 0.4, 0.7)
	match weapon:
		0: # gourdin clouté
			Visuals.cylinder(w, 0.06, 0.025, 0.5, Vector3(0, 0, 0.2), wood, Vector3(90, 0, 0), 6)
			for k in 4:
				Visuals.box(w, Vector3(0.02, 0.02, 0.05), Vector3(0.05 * (1 if k % 2 == 0 else -1), 0.025 * (k - 1.5), 0.36), iron)
		1: # coutelas rouillé
			Visuals.box(w, Vector3(0.03, 0.035, 0.09), Vector3(0, 0, 0.03), wood)
			Visuals.box(w, Vector3(0.012, 0.06, 0.28), Vector3(0, 0.01, 0.21), iron)
		_: # lance
			Visuals.cylinder(w, 0.016, 0.016, 1.2, Vector3(0, 0, 0.25), wood, Vector3(90, 0, 0), 6)
			Visuals.cylinder(w, 0.0, 0.035, 0.16, Vector3(0, 0, 0.92), iron, Vector3(90, 0, 0), 4)
	skin.attach("hand.R", w)


func _animate(delta: float, _moving: bool) -> void:
	skin.step(delta, _speed_now > 0.05, _speed_now)


## Coup : le clip « slash » étiré pour que l'impact tombe à la fin de l'élan.
func _attack_anim(windup: float) -> void:
	skin.action("slash", windup / STRIKE_AT)
	Sfx.play("croak", -16.0, 0.4) # ricanement


func _flash() -> void:
	if skin != null:
		skin.hurt()
	super()


func _death_anim() -> void:
	Sfx.play("croak", -12.0, 0.5)
	skin.die()
	_corpse(2.0)
