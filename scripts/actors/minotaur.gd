class_name Minotaur
extends Enemy
## LE MINOTAURE, gardien du trésor du Labyrinthe du Destin : 3,3 m, tête de taureau aux cornes immenses, anneau dans
## le mufle, torse d'homme, jambes velues à sabots, et une hache à double tranchant. Capacités :
##   • Coup de hache (au contact) et Fendoir (toutes les ~7 s) : un cercle devant lui, puis la hache s'abat ;
##   • Charge (toutes les ~8 s, si le héros est loin) : une traînée de cercles jusqu'au héros, puis il fonce et
##     renverse tout sur son passage (il s'arrête devant les murs) ;
##   • À 5 % de PV, il jette sa hache, sort sa guitare et IMPOSE UN DUEL : le héros doit jouer le solo
##     (audio/riffs/edge_of_the_cliff.mp3) avec au moins 80 % de notes justes. Gagné : le Minotaure s'incline et tombe.
##     Perdu : il ricane, foudroie le héros d'un accord, reprend 35 % de ses PV, et le combat continue (nouveau
##     duel à 5 %). Pendant le duel, il est intouchable.
## Butin : le Pick du Destin (objet de quête).

## Callable() fourni par le niveau : lance le duel (dialogue, puis mini-jeu).
var duel_requested: Callable
var dueling := false
## Seuil du duel : 5 % des PV max.
const DUEL_AT := 0.05
const DUEL_LOSS_HEAL := 0.35

var _torso: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _hip_l: Node3D
var _hip_r: Node3D
var _axe: Node3D
var _guitar: Node3D
var _slam := 0.0
var _cleave_timer := 5.0
var _charge_timer := 6.0
var _busy := false
var _intro_done := false
var _phase := 1
var _eye_mats: Array[StandardMaterial3D] = []


func _configure() -> void:
	var lvl := level - 1
	display_name = "Le Minotaure"
	is_boss = true
	max_hp = 340 + 45 * lvl
	armor_class = 15
	save_bonus = 5
	attack_bonus = 7 + floori(lvl / 2.0)
	damage_dice = Vector3i(2, 10, 4 + lvl)
	attack_range = 2.2
	detect_radius = 11.0
	lose_radius = 34.0
	xp_reward = 1400 + 150 * lvl
	gold_range = Vector2i(120, 200)
	radius = 0.95
	height = 3.3
	wander_radius = 2.0
	move_speed = Balance.HERO_SPEED * 0.3


func _build_model() -> void:
	var fur := own_mat(Color(0.3, 0.18, 0.1), 0.9)
	var hide := own_mat(Color(0.45, 0.28, 0.18), 0.75)
	var dark := own_mat(Color(0.12, 0.08, 0.05), 0.85)
	var horn := own_mat(Color(0.85, 0.8, 0.68), 0.45)
	var iron := Visuals.mat(Color(0.3, 0.29, 0.3), 0.35, 0.8)
	var eye := Visuals.glow_mat(Color(1.0, 0.3, 0.1), 3.5)
	_eye_mats.append(eye)
	for side: float in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(0.28 * side, 1.25, 0)
		model.add_child(hip)
		Visuals.capsule(hip, 0.24, 0.7, Vector3(0, -0.3, 0.06), fur, Vector3(-15, 0, 0))
		Visuals.capsule(hip, 0.15, 0.62, Vector3(0, -0.85, -0.1), fur, Vector3(20, 0, 0)) # jarret vers l'arrière
		Visuals.box(hip, Vector3(0.2, 0.14, 0.26), Vector3(0, -1.18, 0.0), dark) # sabot
		if side < 0.0:
			_hip_l = hip
		else:
			_hip_r = hip
	_torso = Node3D.new()
	_torso.position = Vector3(0, 1.25, 0)
	model.add_child(_torso)
	Visuals.cylinder(_torso, 0.5, 0.56, 0.35, Vector3(0, 0.05, 0), dark, Vector3.ZERO, 10) # pagne de cuir
	Visuals.box(_torso, Vector3(1.0, 0.1, 0.5), Vector3(0, 0.22, 0), iron) # ceinture
	Visuals.capsule(_torso, 0.42, 1.0, Vector3(0, 0.75, 0), hide)
	Visuals.sphere(_torso, 0.46, Vector3(0, 1.0, 0.1), hide, Vector3(1.4, 0.75, 0.75)) # pectoraux
	Visuals.sphere(_torso, 0.5, Vector3(0, 1.25, -0.1), fur, Vector3(1.5, 0.7, 1.0)) # bosse de taureau
	var head := Node3D.new()
	head.position = Vector3(0, 1.6, 0.25)
	_torso.add_child(head)
	Visuals.sphere(head, 0.3, Vector3.ZERO, fur, Vector3(0.95, 1.0, 1.1))
	Visuals.box(head, Vector3(0.32, 0.26, 0.3), Vector3(0, -0.1, 0.27), hide) # mufle
	Visuals.torus(head, 0.05, 0.075, Vector3(0, -0.2, 0.43), iron, Vector3(90, 0, 0)) # anneau dans le nez
	for side: float in [-1.0, 1.0]:
		Visuals.sphere(head, 0.045, Vector3(0.14 * side, 0.08, 0.24), eye)
		DemonParts.horn(head, Vector3(0.22 * side, 0.18, 0.02), side, horn, 0.75, 22.0)
		Visuals.cylinder(head, 0.0, 0.07, 0.22, Vector3(0.32 * side, 0.02, -0.05), fur, Vector3(0, 0, -100 * side), 5)
	for side: float in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.position = Vector3(0.68 * side, 1.25, 0)
		_torso.add_child(arm)
		Visuals.sphere(arm, 0.24, Vector3.ZERO, hide)
		Visuals.capsule(arm, 0.16, 0.65, Vector3(0.04 * side, -0.35, 0), hide)
		Visuals.capsule(arm, 0.14, 0.6, Vector3(0.06 * side, -0.85, 0.08), hide)
		Visuals.torus(arm, 0.13, 0.18, Vector3(0.06 * side, -0.95, 0.08), iron) # bracelet
		Visuals.sphere(arm, 0.14, Vector3(0.07 * side, -1.17, 0.12), hide)
		if side < 0.0:
			_arm_l = arm
		else:
			_arm_r = arm
	# Hache à double tranchant.
	_axe = Node3D.new()
	_axe.position = Vector3(0.07, -1.17, 0.14)
	_arm_r.add_child(_axe)
	Visuals.cylinder(_axe, 0.045, 0.045, 2.1, Vector3(0, 0.0, 0.4), Visuals.mat(Color(0.22, 0.14, 0.07), 0.8), Vector3(90, 0, 0), 6)
	for s: float in [-1.0, 1.0]:
		Visuals.cylinder(_axe, 0.48, 0.48, 0.06, Vector3(0, 0.3 * s, 1.25), iron, Vector3(0, 0, 90), 3)
	Visuals.sphere(_axe, 0.09, Vector3(0, 0, 1.25), iron)
	# Guitare du duel (cachée jusqu'au duel).
	_guitar = Node3D.new()
	_guitar.position = Vector3(0, 0.9, 0.5)
	_guitar.visible = false
	_torso.add_child(_guitar)
	var g := DemonParts.infernal_guitar(_guitar, 1.7)
	g.rotation_degrees = Vector3(0, 0, -60)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.4, 0.15)
	glow.light_energy = 0.9
	glow.omni_range = 4.0
	glow.position = Vector3(0, 3.0, 0.6)
	model.add_child(glow)


func _animate(_delta: float, moving: bool) -> void:
	var stride := sin(_anim_t * 4.0) if moving else 0.0
	_hip_l.rotation.x = stride * 0.45
	_hip_r.rotation.x = -stride * 0.45
	_torso.rotation.z = stride * 0.06
	_torso.position.y = 1.25 + absf(stride) * 0.06
	if dueling:
		# Il joue : headbang et la main droite qui gratte.
		_torso.rotation.x = absf(sin(_anim_t * 9.0)) * 0.25
		_arm_r.rotation.x = -0.9 + sin(_anim_t * 18.0) * 0.25
		_arm_l.rotation.x = -1.2
		return
	_torso.rotation.x = 0.0
	_arm_l.rotation.x = lerpf(-stride * 0.4, -2.4, _slam * 0.8)
	_arm_r.rotation.x = lerpf(stride * 0.4, -2.8, _slam)


func _attack_anim(windup: float) -> void:
	var tw := create_tween()
	tw.tween_property(self, "_slam", 1.0, windup * 0.85).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "_slam", -0.3, 0.1)
	tw.tween_property(self, "_slam", 0.0, 0.4)


func _aggro() -> void:
	var was_wandering := state == State.WANDER
	super._aggro()
	if was_wandering and not _intro_done:
		_intro_done = true
		Sfx.play("croak", 0.0, 0.0)
		Events.camera_shake.emit(0.35, 0.8)
		Events.notify("Le Minotaure : « Le Pick du Destin ? Il faudra me passer sur le corps, petit troubadour. »", Color(1.0, 0.55, 0.35))
		Events.boss_health.emit(display_name, hp, max_hp)


## Seuil du duel (5 % des PV max, au moins 1).
func duel_threshold() -> int:
	return maxi(1, ceili(max_hp * DUEL_AT))


## Pendant le duel, il est intouchable ; le coup qui le ferait passer sous 5 % s'arrête à 5 % et déclenche le duel.
func take_damage(amount: int, from: Vector3, knockback: float = 0.0, crit: bool = false, kind: String = "phys") -> void:
	if state == State.DEAD:
		return
	if dueling:
		DamageNumber.spawn(get_parent(), global_position + Vector3(0, height + 0.3, 0), "Duel !", Color(1.0, 0.8, 0.3))
		return
	var limit := duel_threshold()
	if not remote_controlled and hp > limit and hp - amount <= limit:
		super.take_damage(hp - limit, from, 0.0, crit, kind)
		start_duel()
		return
	super.take_damage(amount, from, knockback, crit, kind)


## Il jette sa hache, sort sa guitare et impose le duel.
func start_duel() -> void:
	if dueling or state == State.DEAD:
		return
	dueling = true
	_busy = true
	state = State.STAGGER
	_stagger = 9999.0
	_slam = 0.0
	_axe.visible = false
	_guitar.visible = true
	Sfx.play("solo_thunder", -2.0)
	Events.camera_shake.emit(0.3, 0.6)
	if duel_requested.is_valid():
		duel_requested.call()


## Le héros a gagné le duel : le Minotaure s'incline et tombe.
func lose_duel() -> void:
	if not dueling:
		return
	dueling = false
	_stagger = 0.0
	hp = 0
	_update_hp_bar()
	_die()


## Le héros a perdu le duel : il reprend des forces (35 % des PV) et le combat reprend.
func win_duel() -> void:
	if not dueling:
		return
	dueling = false
	hp = maxi(hp, roundi(max_hp * DUEL_LOSS_HEAL))
	_update_hp_bar()
	_guitar.visible = false
	_axe.visible = true
	_stagger = 0.0
	state = State.CHASE
	_busy = false
	_charge_timer = 4.0
	_cleave_timer = 3.0


func _update_special(delta: float, dist: float) -> void:
	if state == State.WANDER or state == State.DEAD or dueling:
		return
	if _phase == 1 and hp <= max_hp / 2.0:
		_phase = 2
		for m in _eye_mats:
			m.emission_energy_multiplier = 6.0
		Sfx.play("croak", 0.0, 0.1)
		Events.notify("Le Minotaure gratte le sol de ses sabots, naseaux fumants...", Events.COLOR_BAD)
	if _busy:
		return
	_cleave_timer -= delta
	_charge_timer -= delta
	if _charge_timer <= 0.0 and dist > 4.0 and dist < 16.0:
		_charge()
	elif _cleave_timer <= 0.0 and dist < 5.0:
		_cleave()


## Fendoir : la hache s'abat sur un cercle de 2,5 m devant lui.
func _cleave() -> void:
	_busy = true
	_cleave_timer = 7.0 if _phase == 1 else 5.0
	var front := global_position + Vector3(sin(model.rotation.y), 0, cos(model.rotation.y)) * 2.3
	var tw := create_tween()
	tw.tween_property(self, "_slam", 1.0, 0.9).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "_slam", -0.4, 0.1)
	tw.tween_property(self, "_slam", 0.0, 0.45)
	await BossMoves.strike(self, front, 2.5, 1.0, Vector3i(3, 8, 3 + level), "slam")
	_busy = false


## Charge : traînée de cercles jusqu'au héros (pas au-delà d'un mur), puis il fonce dessus.
func _charge() -> void:
	if hero == null or not is_instance_valid(hero):
		return
	_busy = true
	_charge_timer = 8.0 if _phase == 1 else 6.0
	var start := global_position
	var dir := hero.global_position - start
	dir.y = 0.0
	var length := minf(dir.length() + 2.0, 14.0)
	dir = dir.normalized()
	# On s'arrête avant le premier obstacle.
	var reach := 0.0
	while reach + 0.5 <= length:
		var p := start + dir * (reach + 0.5)
		if walkable_check.is_valid() and not bool(walkable_check.call(p)):
			break
		reach += 0.5
	if reach < 2.0:
		_busy = false
		return
	var steps := maxi(2, ceili(reach / 2.2))
	Sfx.play("croak", -2.0, 0.1)
	for k in steps:
		var t := float(k + 1) / steps
		BossMoves.strike(self, start + dir * reach * t, 1.3, 1.1 + t * 0.35, Vector3i(2, 10, 2 + level), "slam")
	model.rotation.y = atan2(dir.x, dir.z)
	await get_tree().create_timer(1.1, false).timeout
	if state == State.DEAD or dueling:
		_busy = false
		return
	var tw := create_tween()
	tw.tween_property(self, "global_position", start + dir * reach, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	Events.camera_shake.emit(0.25, 0.3)
	await get_tree().create_timer(0.5, false).timeout
	_busy = false


## Le Pick du Destin (et une potion) restent sur son corps.
func _drop_loot() -> void:
	super._drop_loot()
	loot.append({"kind": "quest", "item": "pick_du_destin"})
	loot.append({"kind": "potion"})


func _die() -> void:
	dueling = false
	super._die()
	Events.boss_health.emit(display_name, 0, max_hp)
	Events.boss_defeated.emit("minotaure")


func _death_anim() -> void:
	Sfx.play("boom", 0.0)
	Events.camera_shake.emit(0.5, 1.2)
	_guitar.visible = false
	var tw := create_tween().set_parallel(true)
	tw.tween_property(model, "rotation:x", -PI * 0.5, 1.1).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(model, "position:y", 0.3, 1.1)
	_corpse(3.0)
