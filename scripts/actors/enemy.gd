class_name Enemy
extends CharacterBody3D
## Base de tous les ennemis. Machine à états :
##   ERRANCE  — se promène au hasard autour de son point d'origine ;
##   POURSUITE — dès que le héros est à moins de 4 m (Balance.ENEMY_DETECT_RADIUS) ;
##   ATTAQUE  — au contact : 1 attaque toutes les 2,5 s, précédée d'un élan visible ;
##   SONNÉ    — bref étourdissement après un gros recul ;
##   MORT.
## Vitesse = 0,25 × vitesse du héros (Balance.ENEMY_SPEED_RATIO).

enum State { WANDER, CHASE, ATTACK, STAGGER, DEAD }

var display_name := "Ennemi"
var max_hp := 10
var hp := 10
var armor_class := 12
var save_bonus := 0
var attack_bonus := 3
var damage_dice := Vector3i(1, 6, 1) # (nombre, faces, bonus)
var move_speed := Balance.HERO_SPEED * Balance.ENEMY_SPEED_RATIO
var detect_radius := Balance.ENEMY_DETECT_RADIUS
var lose_radius := Balance.ENEMY_LOSE_RADIUS
var attack_range := 1.0
var attack_cooldown := Balance.ENEMY_ATTACK_COOLDOWN
var xp_reward := 50
var gold_range := Vector2i(2, 8)
var radius := 0.4
var height := 1.8
var wander_radius := 5.0
var level := 1
var is_boss := false
## Callable(pos: Vector3) -> bool fourni par le donjon pour valider les points d'errance.
var walkable_check: Callable

var state: State = State.WANDER
var hero: Hero
var model: Node3D

var _home := Vector3.ZERO
var _wander_target := Vector3.ZERO
var _wander_wait := 0.0
var _stuck := 0.0
var _attack_timer := 0.0
var _stagger := 0.0
var _knock := Vector3.ZERO
var _attacking := false
var _anim_t := randf() * 10.0
var _flash_mats: Array[StandardMaterial3D] = []
var _hp_bar: Node3D
var _hp_fill: MeshInstance3D
var _alert: Label3D


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	_configure()
	hp = max_hp
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = radius
	cap.height = maxf(height, radius * 2.0)
	col.shape = cap
	col.position.y = height * 0.5
	add_child(col)
	model = Node3D.new()
	add_child(model)
	_build_model()
	_build_hp_bar()
	_home = global_position
	_pick_wander_target()


## À surcharger : statistiques de l'ennemi (selon `level`).
func _configure() -> void:
	pass


## À surcharger : construction du modèle 3D dans `model`.
func _build_model() -> void:
	Visuals.capsule(model, radius, height, Vector3(0, height * 0.5, 0), own_mat(Color(0.5, 0.5, 0.5)))


## À surcharger : animation procédurale (marche, élan...).
func _animate(_delta: float, _moving: bool) -> void:
	pass


## À surcharger : animation d'attaque (appelée au début de l'élan).
func _attack_anim(_windup: float) -> void:
	pass


## Matériau « flashable » (clignote en blanc quand l'ennemi est touché).
func own_mat(color: Color, roughness: float = 0.8) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.emission_enabled = true
	m.emission = Color.BLACK
	_flash_mats.append(m)
	return m


func is_alive() -> bool:
	return state != State.DEAD


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if hero == null or not is_instance_valid(hero):
		hero = get_tree().get_first_node_in_group("hero") as Hero
	_attack_timer = maxf(0.0, _attack_timer - delta)
	var dist := INF
	var to_hero := Vector3.ZERO
	if hero != null and not hero.dead:
		to_hero = hero.global_position - global_position
		to_hero.y = 0.0
		dist = to_hero.length()

	var desired := Vector3.ZERO
	match state:
		State.WANDER:
			if dist <= detect_radius:
				_aggro()
			else:
				desired = _wander(delta)
		State.CHASE:
			if dist > lose_radius:
				state = State.WANDER
				_home = global_position
				_pick_wander_target()
			elif dist <= attack_range + radius + 0.35:
				state = State.ATTACK
			else:
				desired = to_hero.normalized() * move_speed
		State.ATTACK:
			if dist > attack_range + radius + 0.35 + 0.5 and not _attacking:
				state = State.CHASE
			elif _attack_timer <= 0.0 and not _attacking:
				_begin_attack()
		State.STAGGER:
			_stagger -= delta
			if _stagger <= 0.0:
				state = State.CHASE

	_update_special(delta, dist)
	velocity = desired + _knock
	_knock = _knock.move_toward(Vector3.ZERO, 20.0 * delta)
	move_and_slide()
	global_position.y = 0.0

	var look := desired
	if state == State.ATTACK and dist < INF:
		look = to_hero
	if look.length() > 0.05:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(look.x, look.z), 1.0 - exp(-10.0 * delta))
	_anim_t += delta
	_animate(delta, desired.length() > 0.05)


## À surcharger : capacités spéciales (boss).
func _update_special(_delta: float, _dist: float) -> void:
	pass


func _aggro() -> void:
	if state != State.WANDER:
		return
	state = State.CHASE
	if _alert == null:
		_alert = Visuals.label(self, "!", Vector3(0, height + 0.6, 0), Color(1.0, 0.3, 0.2), 90)
		var tw := create_tween()
		tw.tween_interval(0.8)
		tw.tween_property(_alert, "modulate:a", 0.0, 0.3)
		tw.tween_callback(_clear_alert)


func _clear_alert() -> void:
	if _alert != null and is_instance_valid(_alert):
		_alert.queue_free()
	_alert = null


func _wander(delta: float) -> Vector3:
	if _wander_wait > 0.0:
		_wander_wait -= delta
		return Vector3.ZERO
	var to := _wander_target - global_position
	to.y = 0.0
	if to.length() < 0.3:
		_wander_wait = randf_range(1.0, 3.0)
		_pick_wander_target()
		return Vector3.ZERO
	# Coincé contre un mur ? On change de destination.
	if get_real_velocity().length() < move_speed * 0.3:
		_stuck += delta
		if _stuck > 0.8:
			_stuck = 0.0
			_pick_wander_target()
	else:
		_stuck = 0.0
	return to.normalized() * move_speed


func _pick_wander_target() -> void:
	for i in 12:
		var p := _home + Vector3(randf_range(-wander_radius, wander_radius), 0.0, randf_range(-wander_radius, wander_radius))
		if not walkable_check.is_valid() or bool(walkable_check.call(p)):
			_wander_target = p
			return
	_wander_target = _home


func _begin_attack() -> void:
	_attacking = true
	_attack_timer = attack_cooldown
	_attack_anim(Balance.ENEMY_ATTACK_WINDUP)
	await get_tree().create_timer(Balance.ENEMY_ATTACK_WINDUP, false).timeout
	_attacking = false
	if state == State.DEAD or hero == null or not is_instance_valid(hero) or hero.dead:
		return
	var to := hero.global_position - global_position
	to.y = 0.0
	if to.length() > attack_range + radius + hero.radius + 0.6:
		return # le héros a esquivé en reculant
	Sfx.play("clack", -10.0)
	if Dice.attack_roll(attack_bonus, GameState.armor_class()) > 0:
		hero.take_hit(Dice.roll(damage_dice.x, damage_dice.y, damage_dice.z), global_position)
	else:
		DamageNumber.spawn(get_parent(), hero.global_position + Vector3(0, 2.2, 0), "Esquive", Color(0.7, 0.8, 1.0))


func saving_throw(dc: int) -> bool:
	return Dice.d20() + save_bonus >= dc


func show_miss() -> void:
	DamageNumber.spawn(get_parent(), global_position + Vector3(0, height + 0.3, 0), "Raté", Color(0.7, 0.7, 0.7))
	_aggro()


func take_damage(amount: int, from: Vector3, knockback: float = 0.0, crit: bool = false, kind: String = "phys") -> void:
	if state == State.DEAD:
		return
	hp -= amount
	var color := Color(1.0, 0.95, 0.85)
	match kind:
		"shock":
			color = Color(0.55, 0.85, 1.0)
		"sound":
			color = Color(0.8, 0.6, 1.0)
	if crit:
		color = Color(1.0, 0.8, 0.2)
	DamageNumber.spawn(get_parent(), global_position + Vector3(0, height + 0.3, 0), "%d%s" % [amount, "!" if crit else ""], color, crit)
	_flash()
	if not is_boss:
		var away := global_position - from
		away.y = 0.0
		if away.length() > 0.01:
			_knock = away.normalized() * knockback
	if state == State.WANDER:
		_aggro()
	_update_hp_bar()
	Sfx.play("clack", -12.0, 0.15)
	if hp <= 0:
		_die()
	elif knockback >= 4.0 and not is_boss:
		state = State.STAGGER
		_stagger = 0.4


func _flash() -> void:
	for m in _flash_mats:
		m.emission = Color(1, 1, 1)
		m.emission_energy_multiplier = 1.5
	await get_tree().create_timer(0.08, false).timeout
	if not is_instance_valid(self):
		return
	for m in _flash_mats:
		m.emission = Color.BLACK


func _die() -> void:
	state = State.DEAD
	remove_from_group("enemies")
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	_hp_bar.visible = false
	GameState.add_xp(xp_reward)
	DamageNumber.spawn(get_parent(), global_position + Vector3(0, height + 0.9, 0), "+%d XP" % xp_reward, Events.COLOR_GOLD)
	_drop_loot()
	Events.enemy_killed.emit(self)
	_death_anim()


func _drop_loot() -> void:
	var parent := get_parent()
	if randf() < Balance.DROP_GOLD_CHANCE:
		Pickup.spawn(parent, global_position, "gold", randi_range(gold_range.x, gold_range.y))
	if randf() < Balance.DROP_POTION_CHANCE:
		Pickup.spawn(parent, global_position, "potion")
	if randf() < Balance.DROP_ITEM_CHANCE:
		var pool: Array[String] = []
		for id: String in ItemDB.COMMON_DROPS:
			if not GameState.inventory.has(id):
				pool.append(id)
		if not pool.is_empty():
			Pickup.spawn(parent, global_position, "item", 0, pool.pick_random())


func _death_anim() -> void:
	Sfx.play("bones", -6.0)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(model, "rotation:x", -PI * 0.5, 0.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(model, "position:y", 0.15, 0.45)
	tw.chain().tween_interval(1.5)
	tw.chain().tween_property(model, "scale", Vector3(1.0, 0.05, 1.0), 0.6)
	tw.chain().tween_callback(queue_free)


# --- Barre de vie -----------------------------------------------------------

func _build_hp_bar() -> void:
	_hp_bar = Node3D.new()
	_hp_bar.position.y = height + 0.25
	add_child(_hp_bar)
	var bg_mat := StandardMaterial3D.new()
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg_mat.albedo_color = Color(0.05, 0.0, 0.0)
	bg_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	bg_mat.billboard_keep_scale = true
	bg_mat.no_depth_test = true
	bg_mat.render_priority = 1
	var fg_mat := bg_mat.duplicate() as StandardMaterial3D
	fg_mat.albedo_color = Color(0.75, 0.08, 0.05)
	fg_mat.render_priority = 2
	var bg := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.9, 0.1)
	bg.mesh = q
	bg.material_override = bg_mat
	_hp_bar.add_child(bg)
	_hp_fill = MeshInstance3D.new()
	var q2 := QuadMesh.new()
	q2.size = Vector2(0.86, 0.07)
	_hp_fill.mesh = q2
	_hp_fill.material_override = fg_mat
	_hp_bar.add_child(_hp_fill)
	_hp_bar.visible = false


func _update_hp_bar() -> void:
	if is_boss:
		Events.boss_health.emit(display_name, maxi(hp, 0), max_hp)
		return
	_hp_bar.visible = hp > 0
	_hp_fill.scale.x = clampf(float(hp) / max_hp, 0.001, 1.0)
