class_name KayKitSkeleton
extends Skeleton
## Squelettes de la Nécropole (niveau test), modèles et animations du pack KayKit Skeletons (voir KayKitSkin) :
##   • « minion »  — Squelette : lame rouillée, le gros de la troupe ;
##   • « warrior » — Guerrier squelette : hache et grand bouclier, lent et coriace ;
##   • « rogue »   — Arbalétrier squelette : tire des carreaux de loin (7 m) ;
##   • « mage »    — Mage squelette : bâton, orbes de magie violette (6,5 m).
## Ce sont des squelettes (classe Skeleton) : le trait « Un des leurs » des héros squelettes s'applique.
## Le Roi des Os (SkeletonKing) en dérive.

## Taille en jeu par rapport au modèle (2,17 m) : un petit squelette de 0,87 m (réduits de moitié le 13 oct. 2026).
const SCALE := 0.4
## Part du clip « Throw » avant l'impact (le clip est étiré pour que l'impact tombe à la fin de l'élan).
const THROW_AT := 0.45

var kind := "minion"
var kskin: KayKitSkin
var ranged := false
var _hand: Node3D


func _configure() -> void:
	var lvl := level - 1
	radius = 0.25
	height = KayKitSkin.HEIGHT * SCALE
	save_bonus = 2
	match kind:
		"warrior":
			display_name = "Guerrier squelette"
			max_hp = 28 + 7 * lvl
			armor_class = 15
			attack_bonus = 5 + floori(lvl / 2.0)
			damage_dice = Vector3i(1, 10, 2 + lvl)
			xp_reward = 120 + 20 * lvl
			gold_range = Vector2i(6, 16)
			radius = 0.3
			attack_range = 1.0
			move_speed = Balance.HERO_SPEED * 0.22
		"rogue":
			display_name = "Arbalétrier squelette"
			max_hp = 10 + 3 * lvl
			armor_class = 13
			attack_bonus = 5 + floori(lvl / 2.0)
			damage_dice = Vector3i(1, 8, 1 + lvl)
			xp_reward = 60 + 10 * lvl
			gold_range = Vector2i(3, 10)
			attack_range = 7.0
			detect_radius = 8.0
			lose_radius = 12.0
			ranged = true
		"mage":
			display_name = "Mage squelette"
			max_hp = 11 + 3 * lvl
			armor_class = 12
			attack_bonus = 5 + floori(lvl / 2.0)
			damage_dice = Vector3i(2, 4, 1 + lvl)
			xp_reward = 70 + 10 * lvl
			gold_range = Vector2i(4, 12)
			attack_range = 6.5
			detect_radius = 8.0
			lose_radius = 12.0
			ranged = true
		_:
			display_name = "Squelette"
			max_hp = 12 + 4 * lvl
			armor_class = 12
			attack_bonus = 4 + floori(lvl / 2.0)
			damage_dice = Vector3i(1, 6, 1 + lvl)
			xp_reward = 45 + 10 * lvl
			gold_range = Vector2i(2, 9)
			move_speed = Balance.HERO_SPEED * 0.28


func _build_model() -> void:
	kskin = KayKitSkin.create(kind)
	kskin.scale = Vector3.ONE * SCALE
	model.add_child(kskin)
	_equip()
	_flash_mats.append_array(kskin.flash_materials)


## Armes du pack : lame, hache et bouclier, arbalète et carquois, bâton.
func _equip() -> void:
	match kind:
		"warrior":
			_hand = kskin.equip("Skeleton_Axe", "handslot.r")
			kskin.equip("Skeleton_Shield_Large_A", "handslot.l")
		"rogue":
			_hand = kskin.equip("Skeleton_Crossbow", "handslot.r")
			var quiver := (load(KayKitSkin.DIR + "armes/Skeleton_Quiver.gltf") as PackedScene).instantiate() as Node3D
			quiver.position = Vector3(0.0, 0.25, -0.35)
			quiver.rotation_degrees = Vector3(0, 0, 25)
			kskin.attach("chest", quiver)
		"mage":
			_hand = kskin.equip("Skeleton_Staff", "handslot.r")
		_:
			_hand = kskin.equip("Skeleton_Blade", "handslot.r")


func _animate(delta: float, _moving: bool) -> void:
	kskin.step(delta, _speed_now > 0.05, _speed_now)


func _attack_anim(windup: float) -> void:
	kskin.action("Throw", windup / THROW_AT)
	if ranged:
		_shoot(windup)


## Tir (arbalète ou bâton) : le projectile part à mi-élan et touche à la fin, quand le coup est résolu.
func _shoot(windup: float) -> void:
	var target := hero
	await get_tree().create_timer(windup * 0.4, false).timeout
	if not is_alive() or target == null or not is_instance_valid(target) or not is_inside_tree():
		return
	var from := global_position + Vector3(0, height * 0.6, 0)
	if _hand != null and is_instance_valid(_hand):
		from = _hand.global_position
	var to := target.global_position + Vector3(0, 1.1, 0)
	var bolt := Node3D.new()
	get_parent().add_child(bolt)
	bolt.global_position = from
	if kind == "rogue":
		var arrow := (load(KayKitSkin.DIR + "armes/Skeleton_Arrow.gltf") as PackedScene).instantiate() as Node3D
		arrow.rotation_degrees = Vector3(90, 0, 0) # le carreau (le long de Y) pointe vers l'avant
		bolt.add_child(arrow)
		Sfx.play("clack", -12.0, 0.3)
	else:
		var glow := Color(0.7, 0.35, 1.0)
		Visuals.sphere(bolt, 0.18, Vector3.ZERO, Visuals.glow_mat(glow, 5.0))
		var light := OmniLight3D.new()
		light.light_color = glow
		light.light_energy = 1.5
		light.omni_range = 3.0
		bolt.add_child(light)
		Sfx.play("zap", -14.0, 0.2)
	if from.distance_to(to) > 0.1:
		bolt.look_at(to, Vector3.UP, true)
	var tw := bolt.create_tween()
	tw.tween_property(bolt, "global_position", to, windup * 0.6)
	tw.tween_callback(bolt.queue_free)


func _flash() -> void:
	if kskin != null:
		kskin.hurt()
	super()


func _death_anim() -> void:
	Sfx.play("bones", -6.0)
	kskin.die()
	_corpse(2.5)


## Renfort qui sort de terre (invoqué par le Roi des Os) : il s'extirpe du sol avant de charger.
func rise_from_ground() -> void:
	kskin.action("Spawn_Ground", 1.3)
	_stagger = 1.3
	state = State.STAGGER
