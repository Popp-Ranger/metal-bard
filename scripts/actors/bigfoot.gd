class_name Bigfoot
extends Enemy
## Le Bigfoot, boss des flancs de la montagne : 3 m de fourrure brune, épaules de gorille, bras qui traînent
## presque au sol, visage gris et grands pieds nus. Capacités :
##   • Lancer de rocher (toutes les ~6 s, si le héros est loin) : un cercle au sol, puis le rocher s'écrase dessus ;
##   • Coup de massue des poings (au contact) et Martèlement (toutes les ~8 s) : il frappe le sol, onde de 4 m ;
##   • Rage (sous 50 % PV) : il se frappe la poitrine, puis il est plus rapide et frappe plus souvent.

var _torso: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _hip_l: Node3D
var _hip_r: Node3D
var _slam := 0.0
var _throw := 0.0
var _rock_timer := 4.0
var _pound_timer := 7.0
var _busy := false
var _enraged := false
var _intro_done := false
var _eye_mats: Array[StandardMaterial3D] = []


func _configure() -> void:
	var lvl := level - 1
	display_name = "Le Bigfoot"
	is_boss = true
	max_hp = 210 + 32 * lvl
	armor_class = 13
	save_bonus = 3
	attack_bonus = 6 + floori(lvl / 2.0)
	damage_dice = Vector3i(2, 8, 3 + lvl)
	attack_range = 1.8
	detect_radius = 10.0
	lose_radius = 30.0
	xp_reward = 700 + 80 * lvl
	gold_range = Vector2i(50, 90)
	radius = 0.9
	height = 3.0
	wander_radius = 2.0
	move_speed = Balance.HERO_SPEED * 0.3


func _build_model() -> void:
	var fur := own_mat(Color(0.33, 0.22, 0.13), 0.95)
	var fur_dark := own_mat(Color(0.22, 0.14, 0.08), 0.95)
	var skin := own_mat(Color(0.42, 0.38, 0.36), 0.7)
	var eye := Visuals.glow_mat(Color(1.0, 0.75, 0.3), 2.5)
	_eye_mats.append(eye)
	for side: float in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(0.3 * side, 1.05, 0)
		model.add_child(hip)
		Visuals.capsule(hip, 0.24, 0.65, Vector3(0, -0.28, 0), fur)
		Visuals.capsule(hip, 0.19, 0.55, Vector3(0, -0.72, 0.03), fur_dark)
		Visuals.box(hip, Vector3(0.3, 0.12, 0.5), Vector3(0, -1.0, 0.12), skin) # grand pied nu
		if side < 0.0:
			_hip_l = hip
		else:
			_hip_r = hip
	_torso = Node3D.new()
	_torso.position = Vector3(0, 1.05, 0)
	_torso.rotation.x = 0.3 # penché en avant comme un gorille
	model.add_child(_torso)
	Visuals.sphere(_torso, 0.5, Vector3(0, 0.25, 0), fur_dark, Vector3(1.1, 0.9, 0.9))
	Visuals.sphere(_torso, 0.66, Vector3(0, 0.95, 0), fur, Vector3(1.25, 1.05, 0.95)) # torse énorme
	Visuals.sphere(_torso, 0.36, Vector3(0, 0.95, 0.38), skin, Vector3(1.4, 1.0, 0.4)) # poitrail
	var head := Node3D.new()
	head.position = Vector3(0, 1.62, 0.32)
	_torso.add_child(head)
	Visuals.sphere(head, 0.3, Vector3.ZERO, fur, Vector3(1.0, 1.15, 1.0))
	Visuals.cylinder(head, 0.1, 0.25, 0.3, Vector3(0, 0.3, -0.06), fur_dark, Vector3(-20, 0, 0), 8) # crâne pointu
	Visuals.sphere(head, 0.22, Vector3(0, -0.05, 0.16), skin, Vector3(1.0, 0.95, 0.7)) # visage gris
	Visuals.box(head, Vector3(0.34, 0.06, 0.08), Vector3(0, 0.08, 0.27), fur_dark) # arcade sourcilière
	for side: float in [-1.0, 1.0]:
		Visuals.sphere(head, 0.035, Vector3(0.08 * side, 0.03, 0.31), eye)
	Visuals.box(head, Vector3(0.16, 0.04, 0.05), Vector3(0, -0.14, 0.31), Visuals.mat(Color(0.12, 0.05, 0.05)))
	for side: float in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.position = Vector3(0.82 * side, 1.25, 0.05)
		_torso.add_child(arm)
		Visuals.sphere(arm, 0.3, Vector3.ZERO, fur)
		Visuals.capsule(arm, 0.2, 0.75, Vector3(0.05 * side, -0.4, 0), fur)
		Visuals.capsule(arm, 0.18, 0.75, Vector3(0.07 * side, -1.0, 0.1), fur_dark)
		Visuals.sphere(arm, 0.2, Vector3(0.08 * side, -1.42, 0.15), skin, Vector3(1.0, 0.8, 1.1)) # poing
		if side < 0.0:
			_arm_l = arm
		else:
			_arm_r = arm


func _animate(_delta: float, moving: bool) -> void:
	var stride := sin(_anim_t * (5.0 if _enraged else 3.6)) if moving else 0.0
	_hip_l.rotation.x = stride * 0.4
	_hip_r.rotation.x = -stride * 0.4
	_torso.rotation.z = stride * 0.08
	_torso.position.y = 1.05 + absf(stride) * 0.06
	_arm_l.rotation.x = lerpf(-stride * 0.5, -2.6, _slam)
	_arm_r.rotation.x = lerpf(stride * 0.5, -2.8, maxf(_slam, _throw))


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
		Events.camera_shake.emit(0.3, 0.7)
		Events.notify("Un rugissement fait trembler la montagne... LE BIGFOOT ! Il n'aime pas les guitares.", Color(0.95, 0.7, 0.45))
		Events.boss_health.emit(display_name, hp, max_hp)


func _update_special(delta: float, dist: float) -> void:
	if state == State.WANDER or state == State.DEAD:
		return
	if not _enraged and hp <= max_hp / 2.0:
		_rage()
	if _busy:
		return
	_rock_timer -= delta
	_pound_timer -= delta
	if _pound_timer <= 0.0 and dist < 5.0:
		_pound()
	elif _rock_timer <= 0.0 and dist > 4.0 and dist < 18.0:
		_throw_rock()


## Il arrache un rocher et le lance : un cercle au sol là où se tient le héros, puis le rocher s'écrase.
func _throw_rock() -> void:
	if hero == null or not is_instance_valid(hero):
		return
	_busy = true
	_rock_timer = 4.5 if _enraged else 6.0
	var target := hero.global_position
	var tw := create_tween()
	tw.tween_property(self, "_throw", 1.0, 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "_throw", -0.2, 0.12)
	tw.tween_property(self, "_throw", 0.0, 0.3)
	# Le rocher : il part de sa main et décrit un arc jusqu'au point visé.
	var rock := Node3D.new()
	get_parent().add_child(rock)
	Visuals.sphere(rock, 0.45, Vector3.ZERO, Visuals.textured("falaise", 1.5, Color(0.6, 0.56, 0.5)), Vector3(1.0, 0.85, 1.1))
	var from := global_position + Vector3(0, 3.2, 0)
	rock.global_position = from
	var fly := rock.create_tween()
	fly.tween_interval(0.55)
	fly.tween_method(_fly_rock.bind(rock, from, target), 0.0, 1.0, 0.75)
	fly.tween_callback(rock.queue_free)
	await BossMoves.strike(self, target, 1.8, 1.3, Vector3i(2, 10, 2 + level), "rock")
	_busy = false


## Position du rocher lancé à l'instant `t` (0 à 1) de son vol en arc.
func _fly_rock(t: float, rock: Node3D, from: Vector3, target: Vector3) -> void:
	rock.global_position = from.lerp(target, t) + Vector3(0, sin(t * PI) * 4.0, 0)
	rock.rotation.x = t * 8.0


## Martèlement : il abat ses deux poings sur le sol, onde de 4 m autour de lui.
func _pound() -> void:
	_busy = true
	_pound_timer = 6.0 if _enraged else 8.0
	var tw := create_tween()
	tw.tween_property(self, "_slam", 1.0, 0.8).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "_slam", -0.4, 0.12)
	tw.tween_property(self, "_slam", 0.0, 0.4)
	await BossMoves.strike(self, global_position, 4.0, 0.95, Vector3i(2, 6, 3 + level), "slam")
	_busy = false


## Rage : il se frappe la poitrine en rugissant, puis il est plus rapide.
func _rage() -> void:
	_enraged = true
	move_speed *= 1.35
	attack_cooldown *= 0.75
	for m in _eye_mats:
		m.emission = Color(1.0, 0.15, 0.05)
		m.albedo_color = Color(1.0, 0.15, 0.05)
	Sfx.play("croak", 2.0, 0.0)
	Events.camera_shake.emit(0.4, 0.9)
	Events.notify("Le Bigfoot se frappe la poitrine en rugissant : il entre en RAGE !", Events.COLOR_BAD)
	var tw := create_tween()
	for k in 3:
		tw.tween_property(self, "_slam", 0.5, 0.12)
		tw.tween_property(self, "_slam", 0.1, 0.12)


func _drop_loot() -> void:
	super._drop_loot()
	loot.append({"kind": "potion"})


func _die() -> void:
	super._die()
	Events.boss_health.emit(display_name, 0, max_hp)
	Events.boss_defeated.emit("bigfoot")


func _death_anim() -> void:
	Sfx.play("boom", 0.0)
	Events.camera_shake.emit(0.45, 1.0)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(model, "rotation:x", -PI * 0.5, 0.9).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(model, "position:y", 0.3, 0.9)
	_corpse(3.0)
