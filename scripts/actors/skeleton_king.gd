class_name SkeletonKing
extends KayKitSkeleton
## Le Roi des Os : boss de la Nécropole (niveau test). Le guerrier squelette du pack KayKit, 1,9 fois plus grand
## que ses squelettes (environ 1,65 m), lame et grand bouclier, yeux rouges.
##   • coups d'épée au contact ;
##   • Fracas d'os : toutes les 8 s, il abat sa lame devant lui (cercle rouge de 2,2 m au sol, puis l'impact) ;
##   • Levée des morts : à 66 % et à 33 % de ses PV, trois squelettes sortent de terre autour de lui.
## Sa mort ouvre le portail de sortie (Events.boss_defeated « roi_des_os »).

const KING_SCALE := 1.9
const SMASH_EVERY := 8.0

## Callable(pos: Vector3) fourni par le niveau : un squelette sort de terre en `pos`.
var spawn_minion: Callable
var _smash_timer := 4.0
var _busy := false
var _calls := 0
var _intro_done := false


func _configure() -> void:
	kind = "warrior"
	super._configure()
	var lvl := level - 1
	display_name = "Le Roi des Os"
	is_boss = true
	max_hp = 110 + 22 * lvl
	armor_class = 15
	attack_bonus = 6 + floori(lvl / 2.0)
	damage_dice = Vector3i(2, 8, 3 + lvl)
	save_bonus = 4
	xp_reward = 500 + 60 * lvl
	gold_range = Vector2i(40, 80)
	radius = 0.5
	height = KayKitSkin.HEIGHT * KayKitSkeleton.SCALE * KING_SCALE
	attack_range = 1.3
	detect_radius = 8.0
	lose_radius = 30.0
	move_speed = Balance.HERO_SPEED * 0.24


func _build_model() -> void:
	model.scale = Vector3.ONE * KING_SCALE
	kskin = KayKitSkin.create("warrior")
	kskin.scale = Vector3.ONE * KayKitSkeleton.SCALE
	model.add_child(kskin)
	_hand = kskin.equip("Skeleton_Blade", "handslot.r")
	kskin.equip("Skeleton_Shield_Large_B", "handslot.l")
	kskin.set_eye_color(Color(1.0, 0.15, 0.1))
	_flash_mats.append_array(kskin.flash_materials)
	# Couronne d'or sur le casque.
	var crown := Node3D.new()
	crown.position = Vector3(0, 0.95, 0)
	kskin.attach("head", crown)
	var gold := Visuals.glow_mat(Color(1.0, 0.75, 0.2), 0.6)
	Visuals.torus(crown, 0.32, 0.4, Vector3.ZERO, gold)
	for k in 6:
		var a := TAU * k / 6.0
		Visuals.cylinder(crown, 0.0, 0.07, 0.24, Vector3(cos(a) * 0.36, 0.14, sin(a) * 0.36), gold, Vector3.ZERO, 5)
	var aura := Visuals.flicker_light(self, Vector3(0, 2.6, 0.4), Color(1.0, 0.25, 0.15), 1.6, 6.0)
	aura.flicker_amount = 0.3


func _aggro() -> void:
	var was_wandering := state == State.WANDER
	super._aggro()
	if was_wandering and not _intro_done:
		_intro_done = true
		Sfx.play("bones", 0.0)
		Events.camera_shake.emit(0.3, 0.6)
		Events.notify("Le Roi des Os : « UN VIVANT... DANS MA NÉCROPOLE ? Mes os vont jouer de tes os ! »", Color(1.0, 0.5, 0.4))
		Events.boss_health.emit(display_name, hp, max_hp)


func _update_special(delta: float, dist: float) -> void:
	if state == State.WANDER or state == State.DEAD:
		return
	if _calls < 2 and hp <= max_hp * (0.66 if _calls == 0 else 0.33):
		_raise_dead()
		return
	if _busy or _attacking:
		return
	_smash_timer -= delta
	if _smash_timer <= 0.0 and dist < 7.0:
		_smash()


## Fracas d'os : la lame s'abat devant lui, sur un cercle de 2,2 m.
func _smash() -> void:
	_busy = true
	_smash_timer = SMASH_EVERY
	var front := global_position + Vector3(sin(model.rotation.y), 0, cos(model.rotation.y)) * 2.0
	kskin.action("Throw", 1.2 / KayKitSkeleton.THROW_AT)
	await BossMoves.strike(self, front, 2.2, 1.2, Vector3i(3, 8, 3 + level), "slam")
	_busy = false


## Levée des morts : trois squelettes sortent de terre autour de lui.
func _raise_dead() -> void:
	_calls += 1
	kskin.action("Use_Item", 1.4) # il brandit sa lame vers le ciel
	Sfx.play("bones", 0.0, 0.2)
	Events.camera_shake.emit(0.2, 0.5)
	Events.notify("Le Roi des Os frappe le sol : « LEVEZ-VOUS ! » La terre se fend...", Events.COLOR_BAD)
	if spawn_minion.is_valid():
		for k in 3:
			var a := TAU * k / 3.0 + randf() * 0.6
			spawn_minion.call(global_position + Vector3(cos(a), 0, sin(a)) * 3.5)


func _drop_loot() -> void:
	super._drop_loot()
	loot.append({"kind": "potion"})


func _die() -> void:
	super._die()
	Events.boss_health.emit(display_name, 0, max_hp)
	Events.boss_defeated.emit("roi_des_os")


func _death_anim() -> void:
	Sfx.play("boom", 0.0)
	Events.camera_shake.emit(0.5, 1.0)
	kskin.die("Death_B", 2.0)
	_corpse(3.5)
