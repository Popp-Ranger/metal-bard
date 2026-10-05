class_name CaveTroll
extends Enemy
## Le troll des cavernes, boss des grottes des gobelins : 3,2 m de peau grise et verdâtre couverte de verrues et de
## mousse, long nez, défenses, pagne et une massue faite d'un tronc d'arbre. Capacités :
##   • Coup de massue (au contact) et Écrasement (toutes les ~7 s) : un cercle devant lui, puis la massue s'abat ;
##   • Régénération : s'il n'a pas été touché depuis 3 s, il récupère 1,5 % de ses PV par seconde (il faut le harceler) ;
##   • À 50 % PV : il appelle ses gobelins à la rescousse (quatre d'un coup).

var spawn_minion: Callable # Callable(pos: Vector3) fourni par le niveau

var _torso: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _hip_l: Node3D
var _hip_r: Node3D
var _slam := 0.0
var _smash_timer := 5.0
var _busy := false
var _called := false
var _intro_done := false
var _since_hit := 0.0
var _regen := 0.0
var _regen_fx: CPUParticles3D


func _configure() -> void:
	var lvl := level - 1
	display_name = "Le Troll des cavernes"
	is_boss = true
	max_hp = 260 + 35 * lvl
	armor_class = 14
	save_bonus = 4
	attack_bonus = 6 + floori(lvl / 2.0)
	damage_dice = Vector3i(2, 10, 3 + lvl)
	attack_range = 2.2
	attack_cooldown = 3.0
	detect_radius = 10.0
	lose_radius = 30.0
	xp_reward = 800 + 90 * lvl
	gold_range = Vector2i(60, 100)
	radius = 0.95
	height = 3.2
	wander_radius = 1.5
	move_speed = Balance.HERO_SPEED * 0.22


func _build_model() -> void:
	var skin := own_mat(Color(0.38, 0.42, 0.34), 0.8)
	var dark := own_mat(Color(0.25, 0.28, 0.22), 0.85)
	var moss := own_mat(Color(0.22, 0.35, 0.12), 0.95)
	var hide := own_mat(Color(0.3, 0.2, 0.12), 0.9)
	var tusk := Visuals.mat(Color(0.88, 0.84, 0.7), 0.5)
	var eye := Visuals.glow_mat(Color(1.0, 0.6, 0.15), 2.5)
	for side: float in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(0.32 * side, 1.1, 0)
		model.add_child(hip)
		Visuals.capsule(hip, 0.26, 0.7, Vector3(0, -0.3, 0), skin)
		Visuals.capsule(hip, 0.22, 0.6, Vector3(0, -0.78, 0.02), dark)
		Visuals.box(hip, Vector3(0.34, 0.14, 0.48), Vector3(0, -1.06, 0.1), dark)
		if side < 0.0:
			_hip_l = hip
		else:
			_hip_r = hip
	_torso = Node3D.new()
	_torso.position = Vector3(0, 1.1, 0)
	_torso.rotation.x = 0.2
	model.add_child(_torso)
	Visuals.cylinder(_torso, 0.55, 0.62, 0.4, Vector3(0, 0.05, 0), hide, Vector3.ZERO, 10) # pagne
	Visuals.sphere(_torso, 0.62, Vector3(0, 0.55, 0.05), skin, Vector3(1.05, 0.95, 1.0)) # bedaine
	Visuals.sphere(_torso, 0.62, Vector3(0, 1.15, -0.05), skin, Vector3(1.3, 0.9, 0.9)) # épaules
	for k in 7:
		Visuals.sphere(_torso, randf_range(0.08, 0.16), Vector3(randf_range(-0.6, 0.6), randf_range(0.9, 1.4), randf_range(-0.45, -0.1)), moss)
	for k in 6:
		Visuals.sphere(_torso, 0.05, Vector3(randf_range(-0.4, 0.4), randf_range(0.4, 1.0), 0.6), dark) # verrues
	var head := Node3D.new()
	head.position = Vector3(0, 1.62, 0.32)
	_torso.add_child(head)
	Visuals.sphere(head, 0.3, Vector3.ZERO, skin, Vector3(1.0, 0.9, 1.05))
	Visuals.cylinder(head, 0.04, 0.11, 0.4, Vector3(0, -0.02, 0.38), skin, Vector3(70, 0, 0), 8) # long nez
	Visuals.sphere(head, 0.07, Vector3(0, -0.12, 0.55), skin)
	Visuals.box(head, Vector3(0.4, 0.14, 0.24), Vector3(0, -0.2, 0.14), dark) # mâchoire
	for side: float in [-1.0, 1.0]:
		Visuals.sphere(head, 0.04, Vector3(0.11 * side, 0.07, 0.26), eye)
		Visuals.cylinder(head, 0.0, 0.05, 0.22, Vector3(0.14 * side, -0.08, 0.27), tusk, Vector3(-15, 0, -10 * side), 6)
		Visuals.cylinder(head, 0.0, 0.06, 0.3, Vector3(0.3 * side, 0.04, 0.0), skin, Vector3(0, 0, -100 * side), 5) # oreilles
	for side: float in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.position = Vector3(0.85 * side, 1.25, 0)
		_torso.add_child(arm)
		Visuals.sphere(arm, 0.28, Vector3.ZERO, skin)
		Visuals.capsule(arm, 0.19, 0.7, Vector3(0.04 * side, -0.4, 0), skin)
		Visuals.capsule(arm, 0.17, 0.65, Vector3(0.06 * side, -0.95, 0.08), dark)
		Visuals.sphere(arm, 0.19, Vector3(0.07 * side, -1.3, 0.12), skin)
		if side < 0.0:
			_arm_l = arm
		else:
			_arm_r = arm
	# Massue : un tronc d'arbre noueux, plus gros au bout.
	var club := Node3D.new()
	club.position = Vector3(0.07, -1.3, 0.12)
	_arm_r.add_child(club)
	var wood := Visuals.mat(Color(0.28, 0.18, 0.1), 0.9)
	Visuals.cylinder(club, 0.26, 0.1, 1.8, Vector3(0, 0.0, 0.75), wood, Vector3(90, 0, 0), 8)
	for k in 4:
		Visuals.sphere(club, 0.1, Vector3(randf_range(-0.2, 0.2), randf_range(-0.2, 0.2), 1.2 + k * 0.12), wood)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.75, 0.4)
	glow.light_energy = 1.2
	glow.omni_range = 5.0
	glow.position = Vector3(0, 3.6, 1.2)
	model.add_child(glow)
	_regen_fx = CPUParticles3D.new()
	_regen_fx.position.y = 1.8
	_regen_fx.amount = 18
	_regen_fx.lifetime = 1.0
	_regen_fx.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_regen_fx.emission_sphere_radius = 1.0
	_regen_fx.gravity = Vector3(0, 1.2, 0)
	var dot := SphereMesh.new()
	dot.radius = 0.05
	dot.height = 0.1
	dot.material = Visuals.glow_mat(Color(0.4, 1.0, 0.35), 2.0)
	_regen_fx.mesh = dot
	_regen_fx.emitting = false
	model.add_child(_regen_fx)


func _animate(_delta: float, moving: bool) -> void:
	var stride := sin(_anim_t * 3.2) if moving else 0.0
	_hip_l.rotation.x = stride * 0.4
	_hip_r.rotation.x = -stride * 0.4
	_torso.rotation.z = stride * 0.07
	_torso.position.y = 1.1 + absf(stride) * 0.06
	_arm_l.rotation.x = -stride * 0.4
	_arm_r.rotation.x = lerpf(stride * 0.3, -2.7, _slam)


func _attack_anim(windup: float) -> void:
	var tw := create_tween()
	tw.tween_property(self, "_slam", 1.0, windup * 0.85).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "_slam", -0.3, 0.12)
	tw.tween_property(self, "_slam", 0.0, 0.45)


func _aggro() -> void:
	var was_wandering := state == State.WANDER
	super._aggro()
	if was_wandering and not _intro_done:
		_intro_done = true
		Sfx.play("croak", 0.0, 0.0)
		Events.camera_shake.emit(0.3, 0.7)
		Events.notify("Le Troll des cavernes : « QUI... FAIT... DU BRUIT... DANS... MA... GROTTE ? »", Color(0.6, 0.85, 0.45))
		Events.boss_health.emit(display_name, hp, max_hp)


func take_damage(amount: int, from: Vector3, knockback: float = 0.0, crit: bool = false, kind: String = "phys") -> void:
	_since_hit = 0.0
	super.take_damage(amount, from, knockback, crit, kind)


func _update_special(delta: float, dist: float) -> void:
	if state == State.WANDER or state == State.DEAD:
		return
	_update_regen(delta)
	if not _called and hp <= max_hp / 2.0:
		_call_goblins()
	if _busy:
		return
	_smash_timer -= delta
	if _smash_timer <= 0.0 and dist < 6.0:
		_smash()


## Régénération du troll : sans coup reçu depuis 3 s, il récupère 1,5 % de ses PV par seconde.
func _update_regen(delta: float) -> void:
	_since_hit += delta
	var healing := _since_hit >= 3.0 and hp < max_hp
	_regen_fx.emitting = healing
	if not healing:
		return
	_regen += max_hp * 0.015 * delta
	if _regen >= 1.0:
		var gain := floori(_regen)
		_regen -= gain
		hp = mini(max_hp, hp + gain)
		_update_hp_bar()


## Écrasement : la massue s'abat devant lui, sur un cercle de 2,4 m.
func _smash() -> void:
	_busy = true
	_smash_timer = 7.0
	var front := global_position + Vector3(sin(model.rotation.y), 0, cos(model.rotation.y)) * 2.4
	var tw := create_tween()
	tw.tween_property(self, "_slam", 1.0, 1.0).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "_slam", -0.4, 0.12)
	tw.tween_property(self, "_slam", 0.0, 0.5)
	await BossMoves.strike(self, front, 2.4, 1.1, Vector3i(3, 8, 3 + level), "rock")
	_busy = false


func _call_goblins() -> void:
	_called = true
	Sfx.play("croak", 0.0, 0.2)
	Events.notify("Le troll beugle : « GOBELINS ! À MOI ! » Des pas précipités résonnent dans la grotte...", Events.COLOR_BAD)
	if spawn_minion.is_valid():
		for k in 4:
			var a := TAU * k / 4.0 + 0.4
			spawn_minion.call(global_position + Vector3(cos(a), 0, sin(a)) * 4.0)


func _drop_loot() -> void:
	super._drop_loot()
	loot.append({"kind": "potion"})


func _die() -> void:
	_regen_fx.emitting = false
	super._die()
	Events.boss_health.emit(display_name, 0, max_hp)
	Events.boss_defeated.emit("troll")


func _death_anim() -> void:
	Sfx.play("boom", 0.0)
	Events.camera_shake.emit(0.5, 1.0)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(model, "rotation:x", -PI * 0.5, 1.0).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(model, "position:y", 0.3, 1.0)
	_corpse(3.0)
