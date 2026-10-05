class_name FrogBoss
extends Enemy
## Gloubah, le Roi Grenouille — roi de tous les squelettes des Catacombes Suintantes (pourquoi ? on évite la question).
## Capacités :
##   • Vague déferlante (toutes les ~6 s) : cône d'eau vers le héros → esquiver sur le côté.
##     En phase 2 : anneau complet avec une brèche → se placer dans la brèche.
##   • Bond écrasant (toutes les ~10 s) : zone rouge au sol, puis impact de zone.
##   • Coup de langue au corps-à-corps (attaque de base, 1 toutes les 2,5 s).
##   • Phase 2 (sous 50 % PV) : rage, vagues plus fréquentes, invoque 2 squelettes.
## Avant le combat : dès que le héros arrive à portée, Gloubah l'interpelle (dialogue
## « gloubah ») ; selon les réponses, il combat, capture le héros ou devient amical.
## Modèle 3D importé (crapaud debout couronné, art/pnj « gloubah », 50 % plus grand que les héros) : repos, marche,
## coup de patte (« slash ») avec la langue qui jaillit, sursaut, mort (CharacterSkin) ; yeux et langue accrochés à
## l'os de la tête.

var spawn_minion: Callable # Callable(pos: Vector3) fourni par le donjon
## Passive tant que le dialogue n'a pas tranché ; amicale si le héros l'a amadouée.
var passive := true
## Dialogue qu'il engage (portrait de la fenêtre de dialogue, voir DialogueBox).
var dialogue_id := "gloubah"
var friendly := false
var _talked := false

var _wave_timer := 4.0
var _leap_timer := 8.0
var _busy := false
var _phase := 1
var skin: CharacterSkin
var _eye_mats: Array[StandardMaterial3D] = []
## Langue (accrochée à la tête) : elle jaillit en s'allongeant (scale.z).
var _tongue: Node3D
const TONGUE_REST := 0.05
## Yeux et bouche dans le repère du modèle préparé (avant l'agrandissement de 50 %), relevés sur ses vues.
const EYE := Vector3(0.146, 1.527, 0.17)
const MOUTH := Vector3(0.0, 1.415, 0.2)


func _configure() -> void:
	display_name = "Gloubah, le Roi Grenouille"
	is_boss = true
	max_hp = 120 + 30 * (level - 1)
	armor_class = 12
	save_bonus = 3
	attack_bonus = 5
	damage_dice = Vector3i(2, 6, 3)
	attack_range = 1.6
	detect_radius = 9.0 # elle surveille toute sa salle du trône
	lose_radius = 30.0
	xp_reward = 450
	gold_range = Vector2i(60, 90)
	radius = 0.9
	height = 2.76 # 1,84 m agrandi de 50 %
	wander_radius = 1.5


func _build_model() -> void:
	skin = CharacterSkin.create("gloubah", "pnj")
	model.add_child(skin)
	_flash_mats.append_array(skin.flash_materials)
	var head_origin := skin.skeleton.get_bone_global_rest(skin.skeleton.find_bone("head")).origin
	# Yeux luisants (jaunes ; rouges en phase 2, roses s'il devient amical).
	for side: float in [-1.0, 1.0]:
		var e := Visuals.glow_mat(Color(1.0, 0.85, 0.2), 0.8)
		_eye_mats.append(e)
		var eye := Node3D.new()
		Visuals.sphere(eye, 0.028, Vector3.ZERO, e)
		skin.place(eye, "head", Basis.IDENTITY, 0.0, Vector3(EYE.x * side, EYE.y, EYE.z) - head_origin)
		skin.attach("head", eye)
	# Langue : rentrée dans la bouche au repos.
	_tongue = Node3D.new()
	Visuals.box(_tongue, Vector3(0.12, 0.04, 1.0), Vector3(0, 0, 0.5), own_mat(Color(0.8, 0.3, 0.35)))
	Visuals.sphere(_tongue, 0.07, Vector3(0, 0, 1.0), own_mat(Color(0.85, 0.35, 0.4)))
	skin.place(_tongue, "head", Basis.IDENTITY, 0.0, MOUTH - head_origin)
	skin.attach("head", _tongue)
	_tongue.scale = Vector3(1, 1, TONGUE_REST)


func _animate(delta: float, moving: bool) -> void:
	skin.step(delta, moving and not _busy, _speed_now)


## Coup de patte et coup de langue (elle jaillit à la fin de l'élan).
func _attack_anim(windup: float) -> void:
	skin.action("slash", windup / 0.55)
	var tw := create_tween()
	tw.tween_interval(windup * 0.8)
	tw.tween_property(_tongue, "scale:z", 1.5, 0.08)
	tw.tween_property(_tongue, "scale:z", TONGUE_REST, 0.25)


func _flash() -> void:
	if skin != null:
		skin.hurt()
	super()


func _update_special(delta: float, dist: float) -> void:
	if state == State.WANDER or state == State.DEAD:
		return
	if _phase == 1 and hp <= max_hp / 2.0:
		_enter_phase_two()
	if _busy:
		return
	_wave_timer -= delta
	_leap_timer -= delta
	if _leap_timer <= 0.0 and dist > 3.0:
		_leap()
	elif _wave_timer <= 0.0:
		_tidal_wave()


func _aggro() -> void:
	var was_wandering := state == State.WANDER
	super._aggro()
	if was_wandering:
		Sfx.play("croak", 0.0)
		Events.notify("Gloubah : « CROOOÂÂÂ ! Tu vas finir en têtard ! »", Color(0.6, 0.95, 0.5))
		Events.boss_health.emit(display_name, hp, max_hp)


func _enter_phase_two() -> void:
	_phase = 2
	for m in _eye_mats:
		m.emission = Color(1.0, 0.15, 0.1)
		m.emission_energy_multiplier = 4.0
	Sfx.play("croak", 2.0, 0.0)
	Events.camera_shake.emit(0.3, 0.6)
	Events.notify("Gloubah entre dans une rage marécageuse !", Events.COLOR_BAD)
	if spawn_minion.is_valid():
		for side: float in [-1.0, 1.0]:
			spawn_minion.call(global_position + Vector3(2.5 * side, 0, 2.5 * -side))


func _tidal_wave() -> void:
	_busy = true
	_wave_timer = 6.0 if _phase == 1 else 4.2
	Sfx.play("croak", -2.0)
	var tw := create_tween()
	tw.tween_property(model, "scale", Vector3(1.1, 1.25, 1.1), 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(model, "scale", Vector3(1.0, 1.0, 1.0), 0.12)
	await get_tree().create_timer(0.72, false).timeout
	if state == State.DEAD:
		return
	var wave := TidalWave.new()
	wave.center = Vector3(global_position.x, 0.0, global_position.z)
	var aim := 0.0
	if hero != null and is_instance_valid(hero):
		var to := hero.global_position - global_position
		aim = atan2(to.z, to.x)
	wave.damage = Dice.roll(2, 8, 2)
	if _phase == 1:
		wave.aim_angle = aim
	else:
		wave.is_ring = true
		wave.aim_angle = aim + randf_range(-1.2, 1.2) # la brèche n'est pas forcément face au héros
	get_parent().add_child(wave)
	Sfx.play("splash", -2.0)
	Events.camera_shake.emit(0.15, 0.3)
	await get_tree().create_timer(0.5, false).timeout
	_busy = false


func _leap() -> void:
	if hero == null or not is_instance_valid(hero):
		return
	_busy = true
	_leap_timer = randf_range(9.0, 12.0)
	var target := hero.global_position
	target.y = 0.0
	var zone := 2.8
	Telegraph.spawn(get_parent(), target, zone, 1.1)
	var start := global_position
	var tw := create_tween()
	tw.tween_property(model, "scale", Vector3(1.2, 0.7, 1.2), 0.25)
	tw.tween_property(model, "scale", Vector3(0.9, 1.2, 0.9), 0.1)
	var hop := func(k: float) -> void:
		global_position = start.lerp(target, k)
		model.position.y = sin(k * PI) * 4.0
	tw.tween_method(hop, 0.0, 1.0, 0.75)
	tw.tween_property(model, "scale", Vector3(1.3, 0.75, 1.3), 0.06)
	tw.tween_property(model, "scale", Vector3.ONE, 0.25)
	await get_tree().create_timer(1.1, false).timeout
	if state == State.DEAD:
		return
	model.position.y = 0.0
	Sfx.play("boom", 0.0)
	Sfx.play("splash", -4.0)
	Events.camera_shake.emit(0.45, 0.4)
	Shockwave.spawn(get_parent(), global_position, zone)
	for h in get_tree().get_nodes_in_group("heroes"):
		var target_hero := h as Node3D
		if is_down(target_hero):
			continue
		var d := Vector2(target_hero.global_position.x - global_position.x, target_hero.global_position.z - global_position.z).length()
		if d <= zone + float(target_hero.get("radius")):
			target_hero.call("take_hit", Dice.roll(2, 8, 2), global_position, self)
	await get_tree().create_timer(0.4, false).timeout
	_busy = false


func _die() -> void:
	super._die()
	Events.boss_health.emit(display_name, 0, max_hp)
	Events.boss_defeated.emit("gloubah")


## Sa couronne (et une potion) restent sur son corps, à fouiller comme les autres.
func _drop_loot() -> void:
	super._drop_loot()
	loot.append({"kind": "item", "item": "couronne_gloubah"})
	loot.append({"kind": "potion"})


func _death_anim() -> void:
	Sfx.play("croak", 0.0, 0.0)
	Events.camera_shake.emit(0.4, 1.0)
	skin.die()
	_corpse(3.2)


func _vanish() -> void:
	var tw := create_tween()
	tw.tween_property(model, "scale", Vector3(1.4, 0.02, 1.4), 1.0)
	tw.tween_callback(queue_free)


func _corpse_center() -> Vector3:
	return global_position # écrasé sur place


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if remote_controlled:
		super._physics_process(delta)
		return
	if passive or friendly:
		if hero == null or not is_instance_valid(hero):
			hero = get_tree().get_first_node_in_group("hero") as Node3D
		if hero != null:
			var to := hero.global_position - global_position
			to.y = 0.0
			if to.length() < 14.0:
				model.rotation.y = lerp_angle(model.rotation.y, atan2(to.x, to.z), 1.0 - exp(-4.0 * delta))
			# Le héros entre à portée : Gloubah l'interpelle.
			if passive and not _talked and to.length() <= detect_radius and not is_down(hero):
				_talked = true
				Sfx.play("croak", 0.0)
				Events.dialogue_requested.emit(dialogue_id)
		_anim_t += delta
		_animate(delta, false)
		return
	super._physics_process(delta)


## Le combat s'engage (dialogue ou attaque surprise du héros).
func start_fight() -> void:
	if not passive:
		return
	passive = false
	_talked = true
	_aggro()


func take_damage(amount: int, from: Vector3, knockback: float = 0.0, crit: bool = false, kind: String = "phys") -> void:
	if friendly:
		return
	if passive:
		start_fight() # frappée avant la fin des palabres : elle se met en colère
	super.take_damage(amount, from, knockback, crit, kind)


## Choix « il est kiki » : Gloubah devient amical (plus un ennemi).
func befriend() -> void:
	passive = false
	friendly = true
	remove_from_group("enemies")
	set_deferred("collision_layer", 1)
	Events.boss_health.emit(display_name, 0, max_hp)
	for m in _eye_mats:
		m.emission = Color(1.0, 0.6, 0.8)
	var heart := Visuals.label(self, "♥", Vector3(0, height + 1.0, 0), Color(1.0, 0.45, 0.65), 120)
	heart.create_tween().set_loops().tween_property(heart, "position:y", height + 1.3, 0.8).from(height + 1.0)
