class_name IceElemental
extends Enemy
## Élémentaire de glace : silhouette de cristaux de glace translucides qui flotte au-dessus de la neige, autour d'un
## cœur bleu lumineux ; des éclats tournent autour de lui. Rapide, il frappe de ses bras-lames.
## Variante « colossale » (`colossal`) : le boss du col de la montagne, 2,6 fois plus grand :
##   • Pics de glace (toutes les ~5 s) : trois cercles au sol (sur le héros et autour), puis des pics en jaillissent ;
##   • Blizzard (sous 50 % PV) : il invoque deux élémentaires de glace et ses pics tombent plus souvent.

var colossal := false
var spawn_minion: Callable # Callable(pos: Vector3) fourni par le niveau

var _core: Node3D
var _shards: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _swing := 0.0
var _spike_timer := 3.0
var _busy := false
var _phase := 1
var _intro_done := false
var _heart: StandardMaterial3D


func _configure() -> void:
	var lvl := level - 1
	display_name = "Élémentaire de glace"
	max_hp = 20 + 6 * lvl
	armor_class = 13
	attack_bonus = 5 + floori(lvl / 2.0)
	damage_dice = Vector3i(1, 8, 2 + lvl)
	save_bonus = 2
	xp_reward = 110 + 15 * lvl
	gold_range = Vector2i(4, 12)
	radius = 0.45
	height = 1.9
	attack_range = 1.2
	move_speed = Balance.HERO_SPEED * 0.28
	detect_radius = 5.0
	if colossal:
		display_name = "Élémentaire de glace colossal"
		is_boss = true
		max_hp = 230 + 35 * lvl
		armor_class = 15
		attack_bonus = 6 + floori(lvl / 2.0)
		damage_dice = Vector3i(2, 8, 3 + lvl)
		xp_reward = 800 + 90 * lvl
		gold_range = Vector2i(60, 110)
		radius = 1.1
		height = 1.9 * 2.6
		attack_range = 2.2
		detect_radius = 11.0
		lose_radius = 30.0
		wander_radius = 1.5
		move_speed = Balance.HERO_SPEED * 0.24


func _build_model() -> void:
	if colossal:
		model.scale = Vector3.ONE * 2.6
	var ice := own_mat(Color(0.62, 0.82, 1.0), 0.15)
	ice.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ice.albedo_color.a = 0.82
	ice.metallic_specular = 0.9
	ice.rim_enabled = true
	ice.rim = 0.6
	var frost := own_mat(Color(0.88, 0.95, 1.0), 0.4)
	_heart = Visuals.glow_mat(Color(0.35, 0.75, 1.0), 4.0)
	_core = Node3D.new()
	_core.position.y = 0.25
	model.add_child(_core)
	# Bas en pointe de cristal, torse de blocs de glace, tête couronnée d'aiguilles.
	Visuals.cylinder(_core, 0.32, 0.02, 0.8, Vector3(0, 0.4, 0), ice, Vector3.ZERO, 6)
	Visuals.cylinder(_core, 0.42, 0.3, 0.7, Vector3(0, 1.05, 0), ice, Vector3(0, 30, 0), 6)
	Visuals.sphere(_core, 0.16, Vector3(0, 1.05, 0.0), _heart)
	Visuals.box(_core, Vector3(0.75, 0.16, 0.36), Vector3(0, 1.42, 0), frost, Vector3(0, 0, 4))
	var head := Node3D.new()
	head.position = Vector3(0, 1.68, 0.02)
	_core.add_child(head)
	Visuals.cylinder(head, 0.12, 0.17, 0.3, Vector3.ZERO, ice, Vector3(0, 45, 0), 5)
	for side: float in [-1.0, 1.0]:
		Visuals.box(head, Vector3(0.06, 0.03, 0.03), Vector3(0.065 * side, 0.02, 0.15), _heart)
	for k in 5:
		var a := -60.0 + 30.0 * k
		Visuals.cylinder(head, 0.0, 0.045, 0.32, Vector3(sin(deg_to_rad(a)) * 0.12, 0.25, -0.02), frost, Vector3(0, 0, -a), 4)
	for side: float in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.position = Vector3(0.45 * side, 1.4, 0)
		_core.add_child(arm)
		Visuals.cylinder(arm, 0.1, 0.07, 0.45, Vector3(0.03 * side, -0.2, 0), ice, Vector3(0, 0, 8 * side), 5)
		# Avant-bras en lame de glace.
		Visuals.cylinder(arm, 0.0, 0.1, 0.75, Vector3(0.06 * side, -0.75, 0.12), frost, Vector3(170, 0, 0), 4)
		if side < 0.0:
			_arm_l = arm
		else:
			_arm_r = arm
	# Éclats qui tournoient autour de lui.
	_shards = Node3D.new()
	_shards.position.y = 1.1
	_core.add_child(_shards)
	for k in 6:
		var a := TAU * k / 6.0
		Visuals.cylinder(_shards, 0.0, 0.05, 0.22, Vector3(cos(a) * 0.7, sin(a * 2.0) * 0.2, sin(a) * 0.7), ice, Vector3(randf() * 90, 0, randf() * 90), 4)
	var light := OmniLight3D.new()
	light.light_color = Color(0.5, 0.8, 1.0)
	light.light_energy = 1.0
	light.omni_range = 3.5
	light.position = Vector3(0, 1.4, 0.4)
	model.add_child(light)
	# Brume givrée qui tombe de lui.
	var mist := CPUParticles3D.new()
	mist.position.y = 0.6
	mist.amount = 14
	mist.lifetime = 1.6
	mist.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	mist.emission_sphere_radius = 0.4
	mist.gravity = Vector3(0, -0.6, 0)
	mist.initial_velocity_max = 0.2
	var flake := SphereMesh.new()
	flake.radius = 0.03
	flake.height = 0.06
	flake.material = Visuals.glow_mat(Color(0.8, 0.92, 1.0), 1.0)
	mist.mesh = flake
	model.add_child(mist)


func _animate(delta: float, moving: bool) -> void:
	var sway := sin(_anim_t * 5.0) if moving else 0.0
	_core.position.y = 0.25 + sin(_anim_t * 2.0) * 0.08
	_core.rotation.z = sway * 0.08
	_shards.rotation.y += delta * 1.8
	_arm_l.rotation.x = lerpf(-sway * 0.4, -2.0, _swing * 0.6)
	_arm_r.rotation.x = lerpf(sway * 0.4, -2.4, _swing)


func _attack_anim(windup: float) -> void:
	var tw := create_tween()
	tw.tween_property(self, "_swing", 1.0, windup * 0.85).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "_swing", -0.3, 0.08)
	tw.tween_property(self, "_swing", 0.0, 0.3)


func _aggro() -> void:
	var was_wandering := state == State.WANDER
	super._aggro()
	if colossal and was_wandering and not _intro_done:
		_intro_done = true
		Sfx.play("boom", -2.0)
		Events.camera_shake.emit(0.3, 0.7)
		Events.notify("Le vent hurle sur le col... L'Élémentaire de glace colossal se dresse devant vous !", Color(0.7, 0.85, 1.0))
		Events.boss_health.emit(display_name, hp, max_hp)


func _update_special(delta: float, dist: float) -> void:
	if not colossal or state == State.WANDER or state == State.DEAD:
		return
	if _phase == 1 and hp <= max_hp / 2.0:
		_blizzard()
	if _busy:
		return
	_spike_timer -= delta
	if _spike_timer <= 0.0 and dist < 18.0:
		_ice_spikes()


## Pics de glace : trois cercles (sur le héros et autour), puis la glace jaillit du sol.
func _ice_spikes() -> void:
	if hero == null or not is_instance_valid(hero):
		return
	_busy = true
	_spike_timer = 5.0 if _phase == 1 else 3.6
	var center := hero.global_position
	for k in 3:
		var p := center
		if k > 0:
			var a := randf() * TAU
			p += Vector3(cos(a), 0, sin(a)) * randf_range(2.0, 3.5)
		BossMoves.strike(self, p, 1.7, 1.0, Vector3i(2, 8, 1 + level), "ice")
	await get_tree().create_timer(1.4, false).timeout
	_busy = false


## Sous 50 % : tempête de neige, deux élémentaires de glace en renfort, pics plus fréquents.
func _blizzard() -> void:
	_phase = 2
	_heart.emission = Color(0.8, 0.95, 1.0)
	Sfx.play("boom", 0.0)
	Events.camera_shake.emit(0.35, 0.8)
	Events.notify("Le colosse rugit : une tempête de neige s'abat sur le col !", Events.COLOR_BAD)
	if spawn_minion.is_valid():
		for k in 2:
			var a := TAU * k / 2.0 + 0.7
			spawn_minion.call(global_position + Vector3(cos(a), 0, sin(a)) * 3.0)


func _die() -> void:
	super._die()
	if colossal:
		Events.boss_health.emit(display_name, 0, max_hp)
		Events.boss_defeated.emit("elementaire_glace")


func _drop_loot() -> void:
	super._drop_loot()
	if colossal:
		loot.append({"kind": "potion"})


func _death_anim() -> void:
	Sfx.play("clack", -2.0, 0.6)
	for k in (8 if colossal else 4):
		BossMoves.ice_spike(get_parent(), global_position + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * (2.0 if colossal else 0.8), randf_range(0.5, 1.2))
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_core, "position:y", -0.3, 0.6).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(_core, "rotation:x", -1.2, 0.6)
	_corpse(2.5 if colossal else 1.8)
