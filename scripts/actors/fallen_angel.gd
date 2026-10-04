class_name FallenAngel
extends Enemy
## L'ange déchu, boss du Temple du Dragon : 3 m, peau de cendre, grandes ailes de plumes noires, auréole brisée et
## guitare électrique infernale. Il flotte au-dessus des dalles.
## Capacités :
##   • Coup de guitare (attaque de base) : il abat sa guitare comme une hache.
##   • Riff infernal (toutes les ~6 s) : trois cercles au sol (sur le héros et autour), puis la foudre y tombe.
##   • Phase 2 (sous 50 % PV) : ailes déployées, yeux rouges, riffs plus rapides ; il invoque trois diablotins.
## Butin : la partition maudite du Riff Ultime (objet de quête), sur son corps.

var spawn_minion: Callable # Callable(pos: Vector3) fourni par le donjon
var _riff_timer := 4.0
var _busy := false
var _phase := 1
var _wing_l: Node3D
var _wing_r: Node3D
var _guitar_arm: Node3D
var _halo: Node3D
var _eye_mats: Array[StandardMaterial3D] = []
var _smash := 0.0
var _intro_done := false

const STRIKE_RADIUS := 1.6


func _configure() -> void:
	var lvl := level - 1
	display_name = "L'Ange déchu"
	is_boss = true
	max_hp = 260 + 40 * lvl
	armor_class = 14
	save_bonus = 4
	attack_bonus = 6 + floori(lvl / 2.0)
	damage_dice = Vector3i(2, 8, 2 + lvl)
	attack_range = 2.0
	detect_radius = 10.0
	lose_radius = 30.0
	xp_reward = 900 + 100 * lvl
	gold_range = Vector2i(80, 140)
	radius = 0.9
	height = 3.1
	wander_radius = 1.5
	move_speed = Balance.HERO_SPEED * 0.3


func _build_model() -> void:
	var ash := own_mat(Color(0.5, 0.48, 0.5), 0.6)
	var robe := own_mat(Color(0.07, 0.05, 0.07), 0.8)
	var trim := own_mat(Color(0.35, 0.05, 0.05), 0.5)
	var feather := own_mat(Color(0.04, 0.035, 0.04), 0.7)
	var hair := own_mat(Color(0.85, 0.85, 0.88), 0.6)
	var gold := Visuals.glow_mat(Color(1.0, 0.75, 0.3), 1.2)
	var body := Node3D.new()
	body.position.y = 0.3 # il flotte
	model.add_child(body)
	# Robe sombre qui s'effiloche au-dessus du sol, buste en armure, ceinture rouge sang.
	Visuals.cylinder(body, 0.32, 0.55, 1.5, Vector3(0, 0.75, 0), robe, Vector3.ZERO, 14)
	Visuals.box(body, Vector3(0.62, 0.1, 0.42), Vector3(0, 1.5, 0), trim)
	Visuals.capsule(body, 0.33, 0.95, Vector3(0, 1.95, 0), robe)
	Visuals.box(body, Vector3(0.5, 0.5, 0.36), Vector3(0, 2.05, 0.04), Visuals.mat(Color(0.15, 0.13, 0.15), 0.35, 0.7)) # cuirasse
	# Tête : visage de cendre, longs cheveux blancs, yeux luisants, auréole d'or brisée.
	var head := Node3D.new()
	head.position = Vector3(0, 2.62, 0.02)
	body.add_child(head)
	Visuals.sphere(head, 0.2, Vector3.ZERO, ash, Vector3(0.9, 1.1, 0.95))
	Visuals.box(head, Vector3(0.36, 0.55, 0.12), Vector3(0, -0.12, -0.12), hair)
	Visuals.sphere(head, 0.21, Vector3(0, 0.06, -0.02), hair, Vector3(1.0, 0.85, 1.0))
	for side: float in [-1.0, 1.0]:
		var e := Visuals.glow_mat(Color(0.75, 0.85, 1.0), 4.0)
		_eye_mats.append(e)
		Visuals.sphere(head, 0.03, Vector3(0.075 * side, 0.03, 0.17), e)
	_halo = Node3D.new()
	_halo.position = Vector3(0, 0.42, -0.05)
	_halo.rotation_degrees = Vector3(-15, 0, 0)
	head.add_child(_halo)
	for k in 10:
		if k == 3 or k == 4:
			continue # brisée
		var a := TAU * k / 10.0
		Visuals.box(_halo, Vector3(0.12, 0.035, 0.035), Vector3(cos(a), 0, sin(a)) * 0.24, gold, Vector3(0, -rad_to_deg(a) + 90, 0))
	# Grandes ailes de plumes noires.
	_wing_l = DemonParts.feather_wing(body, Vector3(-0.15, 2.25, -0.25), -1.0, feather, 1.7)
	_wing_r = DemonParts.feather_wing(body, Vector3(0.15, 2.25, -0.25), 1.0, feather, 1.7)
	# Bras : la guitare infernale tenue en travers du corps.
	for side: float in [-1.0, 1.0]:
		Visuals.sphere(body, 0.13, Vector3(0.36 * side, 2.28, 0), robe)
		Visuals.capsule(body, 0.07, 0.6, Vector3(0.42 * side, 1.98, 0.12), ash, Vector3(-35, 0, 15 * side))
	_guitar_arm = Node3D.new()
	_guitar_arm.position = Vector3(0, 2.15, 0.25)
	body.add_child(_guitar_arm)
	var g := DemonParts.infernal_guitar(_guitar_arm, 1.5)
	g.position = Vector3(-0.1, -0.2, 0.15)
	g.rotation_degrees = Vector3(0, 0, -60)
	var aura := OmniLight3D.new()
	aura.light_color = Color(0.6, 0.55, 1.0)
	aura.light_energy = 1.5
	aura.omni_range = 6.0
	aura.position = Vector3(0, 3.0, 0.5)
	body.add_child(aura)


func _animate(_delta: float, moving: bool) -> void:
	var beat := sin(_anim_t * (3.0 if _phase == 2 else 1.6))
	var spread := 0.6 if _phase == 2 else 0.0
	_wing_l.rotation.y = -0.3 - spread + beat * 0.15
	_wing_r.rotation.y = 0.3 + spread - beat * 0.15
	model.position.y = sin(_anim_t * 1.3) * 0.12 + (0.05 if moving else 0.0)
	_halo.rotation.y += 0.01
	_guitar_arm.rotation.x = lerpf(sin(_anim_t * 6.0) * 0.04, -2.2, _smash)


func _attack_anim(windup: float) -> void:
	var tw := create_tween()
	tw.tween_property(self, "_smash", 1.0, windup * 0.85).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "_smash", -0.4, 0.1)
	tw.tween_property(self, "_smash", 0.0, 0.4)


func _aggro() -> void:
	var was_wandering := state == State.WANDER
	super._aggro()
	if was_wandering and not _intro_done:
		_intro_done = true
		Sfx.play("solo_thunder", -2.0)
		Events.camera_shake.emit(0.3, 0.6)
		Events.notify("L'Ange déchu : « Encore un petit barde qui croit savoir jouer... Écoute un VRAI riff. »", Color(0.75, 0.8, 1.0))
		Events.boss_health.emit(display_name, hp, max_hp)


func _update_special(delta: float, dist: float) -> void:
	if state == State.WANDER or state == State.DEAD:
		return
	if _phase == 1 and hp <= max_hp / 2.0:
		_enter_phase_two()
	if _busy:
		return
	_riff_timer -= delta
	if _riff_timer <= 0.0 and dist < 18.0:
		_infernal_riff()


func _enter_phase_two() -> void:
	_phase = 2
	for m in _eye_mats:
		m.emission = Color(1.0, 0.1, 0.05)
		m.albedo_color = Color(1.0, 0.1, 0.05)
	Sfx.play("solo_thunder", 0.0)
	Events.camera_shake.emit(0.35, 0.8)
	Events.notify("L'Ange déchu déploie ses ailes : « Venez, mes enfants ! »", Events.COLOR_BAD)
	if spawn_minion.is_valid():
		for k in 3:
			var a := TAU * k / 3.0
			spawn_minion.call(global_position + Vector3(cos(a), 0, sin(a)) * 3.0)


## Riff infernal : trois zones (sur le héros et autour) marquées au sol, puis la foudre tombe dessus.
func _infernal_riff() -> void:
	if hero == null or not is_instance_valid(hero):
		return
	_busy = true
	_riff_timer = 6.0 if _phase == 1 else 4.5
	var center := hero.global_position
	center.y = 0.0
	var spots: Array[Vector3] = [center]
	for k in 2:
		var a := randf() * TAU
		spots.append(center + Vector3(cos(a), 0, sin(a)) * randf_range(2.0, 3.5))
	for p in spots:
		Telegraph.spawn(get_parent(), p, STRIKE_RADIUS, 1.0)
	_smash = 0.0
	var tw := create_tween()
	tw.tween_property(_guitar_arm, "rotation:z", 0.4, 0.3)
	tw.tween_property(_guitar_arm, "rotation:z", 0.0, 0.3)
	Sfx.play("riff", -8.0, 0.0)
	await get_tree().create_timer(1.0, false).timeout
	if state == State.DEAD:
		return
	Sfx.play("solo_thunder", -3.0)
	Events.camera_shake.emit(0.25, 0.3)
	for p in spots:
		ArcBolt.spawn(get_parent(), p + Vector3(randf_range(-1, 1), 14.0, randf_range(-1, 1)), p + Vector3(0, 0.1, 0), 0.25, 0.35, Color(0.7, 0.75, 1.0))
		for h in get_tree().get_nodes_in_group("heroes"):
			var target_hero := h as Node3D
			if is_down(target_hero):
				continue
			var d := Vector2(target_hero.global_position.x - p.x, target_hero.global_position.z - p.z).length()
			if d <= STRIKE_RADIUS + float(target_hero.get("radius")):
				target_hero.call("take_hit", Dice.roll(2, 6, 2 + level - 1), p, self)
	await get_tree().create_timer(0.5, false).timeout
	_busy = false


## La partition maudite (et une potion) restent sur son corps.
func _drop_loot() -> void:
	super._drop_loot()
	loot.append({"kind": "quest", "item": "partition_maudite"})
	loot.append({"kind": "potion"})


func _die() -> void:
	super._die()
	Events.boss_health.emit(display_name, 0, max_hp)
	Events.boss_defeated.emit("ange_dechu")


func _death_anim() -> void:
	Sfx.play("solo_thunder", 0.0)
	Events.camera_shake.emit(0.5, 1.2)
	Events.screen_flash.emit(Color(0.85, 0.9, 1.0, 0.6), 0.4)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(model, "position:y", -0.25, 1.0)
	tw.tween_property(model, "rotation:x", -PI * 0.42, 1.2).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_halo.visible = false
	_corpse(3.0)


func _corpse_center() -> Vector3:
	var yaw := model.rotation.y
	return global_position - Vector3(sin(yaw), 0.0, cos(yaw)) * 1.2
