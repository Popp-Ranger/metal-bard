class_name Enemy
extends CharacterBody3D
## Base de tous les ennemis. Machine à états :
##   ERRANCE  — se promène au hasard autour de son point d'origine ;
##   POURSUITE — dès que le héros est à moins de 4 m (Balance.ENEMY_DETECT_RADIUS) ;
##   ATTAQUE  — au contact : 1 attaque toutes les 2,5 s, précédée d'un élan visible ;
##   SONNÉ    — étourdissement (gros recul, Pogo, Growl sur un boss) ;
##   TRANSE   — figé, en plein headbang (Solo endiablé) ;
##   PEUR     — fuit le héros (Growl de l'Abîme) ;
##   MORT.
## Vitesse = 0,25 × vitesse du héros (Balance.ENEMY_SPEED_RATIO).
## Ennemi humanoïde : construire son corps avec HumanoidBody.build(model, ...) dans _build_model() et le
## ranger dans `body` ; il prend alors la posture et la démarche de Riffald (voir _animate et Skeleton).

enum State { WANDER, CHASE, ATTACK, STAGGER, TRANCE, FEAR, DEAD }

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
## Cible : le héros le plus proche (le héros local ou, en coop chez l'hôte, un autre joueur).
var hero: Node3D
## Coopération : identifiant réseau (ordre d'apparition) et pilotage par l'hôte chez les clients.
var net_id := -1
var remote_controlled := false
var _net_pos := Vector3.ZERO
var _net_yaw := 0.0
var _retarget := 0.0
var model: Node3D
## Corps articulé des ennemis humanoïdes (null pour les autres) : voir HumanoidBody.
var body: HumanoidBody
## Vitesse de déplacement de l'image en cours (m/s), pour la cadence de la marche.
var _speed_now := 0.0

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
var _slow_factor := 1.0
var _slow_time := 0.0
var _fear_time := 0.0
## Transe limitée dans le temps (Onde de choc) ; 0 = transe sans fin (Solo endiablé, jusqu'à exit_trance).
var _trance_time := 0.0
var _trance_label: Label3D


func _ready() -> void:
	add_to_group("enemies")
	net_id = Net.register_enemy(self)
	remote_controlled = Net.is_client() and not (self is TrainingDummy)
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	_configure()
	# Coop : les ennemis sont plus résistants quand il y a plus de joueurs.
	if not (self is TrainingDummy):
		max_hp = roundi(max_hp * Balance.coop_enemy_hp_mult(Net.player_count()))
	hp = max_hp
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = radius
	cap.height = maxf(height, radius * 2.0)
	col.shape = cap
	col.position.y = height * 0.5
	add_child(col)
	# L'orientation de départ passe au modèle : le corps reste droit, car le regard du modèle
	# (model.rotation.y) est calculé comme un angle du monde. Sinon il marcherait de travers.
	var spawn_yaw := rotation.y
	rotation.y = 0.0
	model = Node3D.new()
	model.rotation.y = spawn_yaw
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


## Animation (marche, élan...) : un ennemi humanoïde (`body`) a la posture et la démarche de Riffald ;
## les autres surchargent cette fonction (les humanoïdes l'appellent avec super() puis ajoutent leurs gestes).
func _animate(delta: float, moving: bool) -> void:
	if body != null:
		body.step(delta, moving, _speed_now)


## À surcharger : animation d'attaque (appelée au début de l'élan).
func _attack_anim(_windup: float) -> void:
	pass


## Matériau « flashable » (clignote en blanc quand l'ennemi est touché).
func own_mat(color: Color, roughness: float = 0.8) -> StandardMaterial3D:
	var m := Visuals.char_mat(color, roughness)
	m.emission_enabled = true
	m.emission = Color.BLACK
	_flash_mats.append(m)
	return m


func is_alive() -> bool:
	return state != State.DEAD


## Donjon : un ennemi dans une salle encore fermée (porte close, pièce plongée dans le noir)
## est « endormi » : invisible, immobile et impossible à cibler jusqu'à ce qu'on ouvre.
var dormant := false


func set_dormant(value: bool) -> void:
	if value == dormant or not is_alive():
		return
	dormant = value
	visible = not value
	process_mode = Node.PROCESS_MODE_DISABLED if value else Node.PROCESS_MODE_INHERIT
	if value:
		remove_from_group("enemies")
	else:
		add_to_group("enemies")


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if remote_controlled:
		_net_follow(delta)
		return
	_retarget -= delta
	if hero == null or not is_instance_valid(hero) or _retarget <= 0.0:
		_retarget = 0.5
		hero = nearest_hero(self)
	_attack_timer = maxf(0.0, _attack_timer - delta)
	_slow_time = maxf(0.0, _slow_time - delta)
	if _slow_time <= 0.0:
		_slow_factor = 1.0
	var speed := move_speed * _slow_factor
	var dist := INF
	var to_hero := Vector3.ZERO
	if hero != null and not is_down(hero):
		to_hero = hero.global_position - global_position
		to_hero.y = 0.0
		dist = to_hero.length()

	var desired := Vector3.ZERO
	match state:
		State.WANDER:
			if dist <= effective_detect_radius():
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
				desired = to_hero.normalized() * speed
		State.ATTACK:
			if dist > attack_range + radius + 0.35 + 0.5 and not _attacking:
				state = State.CHASE
			elif _attack_timer <= 0.0 and not _attacking:
				_begin_attack()
		State.STAGGER:
			_stagger -= delta
			if _stagger <= 0.0:
				state = State.CHASE
		State.TRANCE:
			# Headbang : tout le corps bat la mesure, plus aucune action.
			model.rotation.x = absf(sin(_anim_t * 11.0)) * 0.45
			if _trance_time > 0.0:
				_trance_time -= delta
				if _trance_time <= 0.0:
					exit_trance()
		State.FEAR:
			_fear_time -= delta
			if dist < INF:
				desired = -to_hero.normalized() * speed * 1.4
			if _fear_time <= 0.0:
				state = State.CHASE

	if state != State.TRANCE:
		_update_special(delta, dist)
	velocity = desired + _knock
	_knock = _knock.move_toward(Vector3.ZERO, 20.0 * delta)
	move_and_slide()
	global_position.y = 0.0

	# Une fois le héros repéré, l'ennemi garde toujours le regard braqué sur lui (même en reculant).
	var look := desired
	if state in [State.CHASE, State.ATTACK, State.STAGGER, State.FEAR] and dist < INF:
		look = to_hero
	if look.length() > 0.05:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(look.x, look.z), 1.0 - exp(-10.0 * delta))
	_anim_t += delta
	_speed_now = desired.length()
	if state != State.TRANCE:
		_animate(delta, _speed_now > 0.05)


## Rayon de détection réel (trait « Un des leurs » des héros squelettes).
func effective_detect_radius() -> float:
	if GameState.race() == "squelette" and self is Skeleton:
		return minf(detect_radius, 3.0)
	return detect_radius


# --- Contrôle de foule (talents) ---------------------------------------------

## Solo endiablé : l'ennemi se fige et headbangue jusqu'à exit_trance().
func enter_trance() -> void:
	if state == State.DEAD or state == State.TRANCE:
		return
	state = State.TRANCE
	_knock = Vector3.ZERO
	_attacking = false
	if _trance_label == null:
		_trance_label = Visuals.label(self, "♫", Vector3(0, height + 0.7, 0), Color(0.85, 0.6, 1.0), 70)


func exit_trance() -> void:
	if state != State.TRANCE:
		return
	_trance_time = 0.0
	state = State.CHASE
	model.rotation.x = 0.0
	if _trance_label != null:
		_trance_label.queue_free()
		_trance_label = null


## Onde de choc : l'ennemi headbangue `duration` secondes (les boss ne sont que sonnés). Sans effet sur une
## transe déjà en cours (Solo endiablé).
func headbang(duration: float) -> void:
	if state == State.DEAD or state == State.TRANCE:
		return
	if is_boss:
		stun(duration)
		return
	enter_trance()
	_trance_time = duration


func is_in_trance() -> bool:
	return state == State.TRANCE


## Growl : fuite (les boss ne sont que sonnés).
func fear(duration: float) -> void:
	if state == State.DEAD or state == State.TRANCE:
		return
	if is_boss:
		stun(0.6)
		return
	state = State.FEAR
	_fear_time = duration
	DamageNumber.spawn(get_parent(), global_position + Vector3(0, height + 0.5, 0), "Terrifié !", Color(0.8, 0.5, 1.0))


func stun(duration: float) -> void:
	if state == State.DEAD or state == State.TRANCE:
		return
	state = State.STAGGER
	_stagger = maxf(_stagger, duration)


func slow(factor: float, duration: float) -> void:
	_slow_factor = minf(_slow_factor, factor)
	_slow_time = maxf(_slow_time, duration)


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
	if state == State.DEAD or state == State.TRANCE or state == State.FEAR or hero == null or not is_instance_valid(hero) or is_down(hero):
		return
	var to := hero.global_position - global_position
	to.y = 0.0
	var dmg := Dice.roll(damage_dice.x, damage_dice.y, damage_dice.z)
	if to.length() > attack_range + radius + float(hero.get("radius")) + 0.6:
		GameState.run_add("avoided", dmg) # le héros a esquivé en reculant
		return
	Sfx.play("clack", -10.0)
	if Dice.attack_roll(attack_bonus, GameState.armor_class()) > 0:
		hero.call("take_hit", dmg, global_position, self)
	else:
		GameState.run_add("avoided", dmg)
		DamageNumber.spawn(get_parent(), hero.global_position + Vector3(0, 2.2, 0), "Esquive", Color(0.7, 0.8, 1.0))
		if hero.has_method("dodged"):
			hero.call("dodged")


func saving_throw(dc: int) -> bool:
	return Dice.d20() + save_bonus >= dc


func show_miss() -> void:
	DamageNumber.spawn(get_parent(), global_position + Vector3(0, height + 0.3, 0), "Raté", Color(0.7, 0.7, 0.7))
	_aggro()


func take_damage(amount: int, from: Vector3, knockback: float = 0.0, crit: bool = false, kind: String = "phys") -> void:
	if state == State.DEAD:
		return
	if remote_controlled:
		# Coop (client) : l'hôte fait autorité, on lui transmet le coup.
		GameState.run_add("dealt", mini(amount, maxi(hp, 0)))
		DamageNumber.spawn(get_parent(), global_position + Vector3(0, height + 0.3, 0), "%d%s" % [amount, "!" if crit else ""], Color(1.0, 0.95, 0.85), crit)
		Net.send_enemy_damage(net_id, amount, from, knockback, crit, kind)
		return
	GameState.run_add("dealt", mini(amount, maxi(hp, 0)))
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
	if not is_boss and state != State.TRANCE: # en transe, rien ne les fait bouger
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
	elif knockback >= 4.0 and not is_boss and state != State.TRANCE:
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
		m.emission = LOOT_GLOW if _glow_tween != null else Color.BLACK # mort entre-temps : lueur du butin


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


## Butin tiré à la mort, gardé sur le corps : médiators, potion, équipement (ramassé en fouillant le corps).
func _drop_loot() -> void:
	if randf() < ItemDB.money_drop_chance():
		loot.append({"kind": "gold", "value": randi_range(gold_range.x, gold_range.y)})
	if randf() < ItemDB.potion_drop_chance():
		loot.append({"kind": "potion"})
	if randf() < Balance.DROP_ITEM_CHANCE:
		var pool: Array[String] = []
		for id: String in ItemDB.common_drops():
			if not GameState.owns(id):
				pool.append(id)
		if not pool.is_empty():
			loot.append({"kind": "item", "item": pool.pick_random()})


func _death_anim() -> void:
	Sfx.play("bones", -6.0)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(model, "rotation:x", -PI * 0.5, 0.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(model, "position:y", 0.15, 0.45)
	_corpse(1.95)


# --- Corps et butin ------------------------------------------------------------------------
# Le butin reste sur le corps : on le ramasse en cliquant dessus (ou [E] à côté). Tant qu'il y a quelque chose à
# prendre, le corps reste au sol ; s'il porte un équipement, il « respire » en doré (1 s pour s'allumer, 1 s pour
# s'éteindre).

const LOOT_GLOW := Color(1.0, 0.78, 0.25)
const LOOT_GLOW_FADE := 1.0

## Butin du corps : [{kind: "gold" | "potion" | "item", value, item}].
var loot: Array[Dictionary] = []
var _loot_spot: Interactable
var _glow_tween: Tween
var _glow_light: OmniLight3D


## Après la chute : sans butin, le corps s'efface au bout de `linger` secondes ; sinon il attend d'être fouillé.
func _corpse(linger: float) -> void:
	if not loot.is_empty():
		_make_lootable()
		return
	await get_tree().create_timer(linger, false).timeout
	if is_instance_valid(self):
		_vanish()


## Le corps s'efface (écrasé puis retiré).
func _vanish() -> void:
	var tw := create_tween()
	tw.tween_property(model, "scale", Vector3(model.scale.x, 0.05, model.scale.z), 0.6)
	tw.tween_callback(queue_free)


## Milieu du corps couché (tombé en arrière) : c'est là qu'on clique pour le fouiller.
func _corpse_center() -> Vector3:
	var yaw := model.rotation.y
	return global_position - Vector3(sin(yaw), 0.0, cos(yaw)) * height * 0.4


func _make_lootable() -> void:
	_loot_spot = Interactable.create(get_parent(), _corpse_center(), loot_prompt(), loot_all, 1.8)
	_loot_spot.click_height = 0.6
	_loot_spot.click_radius = maxf(0.6, radius * 2.0)
	if has_equipment_loot():
		_start_gold_glow()


func has_equipment_loot() -> bool:
	for l in loot:
		if str(l["kind"]) == "item":
			return true
	return false


func loot_prompt() -> String:
	var parts: PackedStringArray = []
	for l in loot:
		match str(l["kind"]):
			"gold":
				parts.append("%d médiators" % int(l["value"]))
			"potion":
				parts.append("potion de soin")
			_:
				parts.append(str(ItemDB.get_item(str(l["item"])).get("name", l["item"])))
	return "Fouiller le corps : %s" % ", ".join(parts)


## Fouille le corps : tout son butin va au héros, puis le corps s'efface.
func loot_all() -> void:
	for l in loot:
		Pickup.grant(get_parent(), global_position, str(l["kind"]), int(l.get("value", 0)), str(l.get("item", "")))
	loot.clear()
	if _loot_spot != null and is_instance_valid(_loot_spot):
		_loot_spot.queue_free()
	if _glow_tween != null:
		_glow_tween.kill()
	_set_glow(0.0)
	_vanish()


func _start_gold_glow() -> void:
	_glow_light = OmniLight3D.new()
	_glow_light.light_color = LOOT_GLOW
	_glow_light.omni_range = 3.0
	_glow_light.light_energy = 0.0
	_glow_light.position = _corpse_center() - global_position + Vector3(0, 0.6, 0)
	add_child(_glow_light)
	for m in _flash_mats:
		m.emission = LOOT_GLOW
	_set_glow(0.0)
	_glow_tween = create_tween().set_loops()
	_glow_tween.tween_method(_set_glow, 0.0, 1.0, LOOT_GLOW_FADE).set_trans(Tween.TRANS_SINE)
	_glow_tween.tween_method(_set_glow, 1.0, 0.0, LOOT_GLOW_FADE).set_trans(Tween.TRANS_SINE)


## Intensité de la lueur dorée (0 à 1).
func _set_glow(k: float) -> void:
	for m in _flash_mats:
		m.emission_energy_multiplier = 1.4 * k
	if _glow_light != null:
		_glow_light.light_energy = 1.8 * k


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
	Visuals.set_bar_fill(_hp_fill, float(hp) / max_hp, 0.86) # se vide de la droite vers la gauche


# --- Cibles et coopération ----------------------------------------------------------

## Héros (local ou distant) le plus proche et encore debout.
static func nearest_hero(from: Node3D) -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for n in from.get_tree().get_nodes_in_group("heroes"):
		var h := n as Node3D
		if h == null or is_down(h):
			continue
		var d := h.global_position.distance_squared_to(from.global_position)
		if d < best_d:
			best_d = d
			best = h
	return best


static func is_down(h: Node3D) -> bool:
	return h == null or not is_instance_valid(h) or bool(h.get("dead"))


## Chez un client : l'ennemi suit l'état envoyé par l'hôte (position, orientation, PV).
func apply_net_state(pos: Vector3, yaw: float, net_hp: int, net_state: int) -> void:
	_net_pos = pos
	_net_yaw = yaw
	if net_hp < hp and hp > 0:
		_flash()
	hp = net_hp
	_update_hp_bar()
	if hp <= 0 and state != State.DEAD:
		_die()
	elif state != State.DEAD:
		if net_state == State.TRANCE and state != State.TRANCE:
			enter_trance()
		elif net_state != State.TRANCE and state == State.TRANCE:
			exit_trance()
		elif state != State.TRANCE:
			state = net_state as State


func _net_follow(delta: float) -> void:
	if state == State.DEAD:
		return
	var prev := global_position
	global_position = global_position.lerp(Vector3(_net_pos.x, 0.0, _net_pos.z), 1.0 - exp(-12.0 * delta))
	model.rotation.y = lerp_angle(model.rotation.y, _net_yaw, 1.0 - exp(-12.0 * delta))
	_anim_t += delta
	_speed_now = prev.distance_to(global_position) / maxf(delta, 0.001)
	if state == State.TRANCE:
		model.rotation.x = absf(sin(_anim_t * 11.0)) * 0.45
	else:
		_animate(delta, _speed_now > 0.2)
