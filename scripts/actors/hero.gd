class_name Hero
extends CharacterBody3D
## Le barde métal (personnage créé par le joueur). Déplacement à la souris uniquement (clic au sol ; maintenu : il suit la
## souris), visée à la souris, coup de guitare + 4 sorts de base + talents (touches 4-7)
## + potion + interaction.

var camera: IsoCamera
var model: HeroModel
var talents_caster: TalentCaster
var dead := false
var casting_solo := false
var leaping := false # Stage Diving en cours
## Enfermé (capturé par Gloubah) ou figé par une cinématique : ni déplacement ni action.
var captive := false
## Planté sur place sans être invincible (Ballade réparatrice).
var planted := false
## Glissade sur les genoux en cours : aucune attaque ne touche.
var dashing := false
## Allongé sur un lit de la taverne : la vie remonte progressivement ; bouger fait se lever.
var resting := false
## Assis à une table de la taverne (arrivée de l'intro) : on se lève en bougeant.
var sitting := false
var _rest_from := Vector3.ZERO
var _rest_heal := 0.0
var _regen_tick := 0.0
var facing := Vector3(0, 0, 1)
var aim_point := Vector3.ZERO
var cooldowns := {"attack": 0.0, "dash": 0.0, "tuning": 0.0, "riff": 0.0, "wave": 0.0, "solo": 0.0, "potion": 0.0}
## Ennemis touchés par le dernier Accordage de cordes, dans l'ordre des rebonds.
var _tuning_chain: Array[Enemy] = []
var radius := 0.35
## Peut-on jouer ici ? Non dans la taverne hors du sous-sol : ni sorts ni coups de guitare,
## guitare portée dans le dos (voir Level.spells_allowed_at).
var spells_allowed := true
## Après SLING_AFTER secondes de marche sans s'arrêter, le héros range sa guitare dans son dos ; il la reprend
## en main dès qu'il frappe ou joue un sort.
const SLING_AFTER := 4.0
var travel_slung := false
## Clic droit maintenu : temps avant le prochain Riff électrique (voir _update_riff_hold).
var _riff_held := false
var _riff_hold := 0.0
var _travel_time := 0.0
var _blocked_notice := 0.0

var _invuln := 0.0
var _interact_target: Node3D
var _prompt_text := ""


func _ready() -> void:
	add_to_group("hero")
	add_to_group("heroes") # tous les joueurs (le héros local + les autres joueurs en coop)
	collision_layer = 2
	collision_mask = 1 | 4
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	model = HeroModel.new()
	model.move_speed = Balance.HERO_SPEED # foulée de course
	if GameState.has_guitar():
		model.guitar_model = GameState.guitar_model() # guitare équipée (Flying V, Batguitare...)
	model.guitar_shown = GameState.has_guitar()
	add_child(model)
	Events.stats_changed.connect(_on_gear_changed)
	# Collision adaptée à la taille de la race (1,8 m à 2,5 m).
	var h := model.height()
	radius = 0.35 * model.scale.x
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = radius
	cap.height = maxf(h, radius * 2.0)
	col.shape = cap
	col.position.y = h * 0.5
	add_child(col)
	talents_caster = TalentCaster.new()
	add_child(talents_caster)
	# Halo de lumière chaude qui suit le héros (la « torche » façon Darkest Dungeon).
	var halo := OmniLight3D.new()
	halo.position = Vector3(1.3, 3.0, 1.3) # décalée vers la caméra pour éclairer le héros de face
	halo.light_color = Color(1.0, 0.78, 0.55)
	halo.light_energy = 2.0
	halo.omni_range = 11.0
	halo.omni_attenuation = 1.2
	halo.shadow_enabled = false # ombres courtes : seule la lumière du dessus en projette
	add_child(halo)
	Events.solo_finished.connect(_on_solo_finished)
	_update_zone()


## Équipement changé : la guitare équipée passe dans les mains du héros.
func _on_gear_changed() -> void:
	model.set_guitar_model(GameState.guitar_model())


## Zone où l'on ne joue pas : guitare dans le dos (mise à jour à chaque image, escaliers compris).
func _update_zone() -> void:
	var level := Level.of(self)
	spells_allowed = level == null or level.spells_allowed_at(global_position)
	model.set_guitar_slung(not spells_allowed or travel_slung)


## Sorts et coups de guitare : refusés (avec un message, pas plus d'une fois par seconde et demie) sans guitare équipée,
## ou là où l'on ne joue pas.
func can_cast() -> bool:
	if not GameState.has_guitar():
		var t := Time.get_ticks_msec() / 1000.0
		if t - _blocked_notice > 1.5:
			_blocked_notice = t
			Events.notify("Pas de guitare équipée : impossible d'attaquer ! Équipez-en une dans l'inventaire [%s]." % Controls.key_label("inventory"), Events.COLOR_BAD)
		return false
	if spells_allowed:
		_draw_guitar()
		return true
	var now := Time.get_ticks_msec() / 1000.0
	if now - _blocked_notice > 1.5:
		_blocked_notice = now
		Events.notify("Pas de musique dans la taverne : descendez au sous-sol pour vous entraîner.", Events.COLOR_BAD)
	return false


func _physics_process(delta: float) -> void:
	for k: String in cooldowns:
		cooldowns[k] = maxf(0.0, float(cooldowns[k]) - delta)
	_invuln = maxf(0.0, _invuln - delta)
	_update_zone()
	if dead:
		velocity = Vector3.ZERO
		return
	GameState.regen_mana(delta)
	if GameState.race() == "troll":
		_regen_tick -= delta
		if _regen_tick <= 0.0:
			_regen_tick = 2.0
			if GameState.hp < GameState.max_hp():
				GameState.heal_hero(1) # Régénération trollesque

	# Déplacement à la souris uniquement (plus de touches ZQSD / flèches depuis le 6 oct. 2026).
	if DialogueBox.active or InventoryWindow.active:
		# En pleine conversation (le jeu continue) : le héros écoute, sans bouger ni agir.
		_click_mode = ClickMode.NONE
	if sitting:
		velocity = Vector3.ZERO # un clic le relève (voir _unhandled_input)
		_update_interaction()
		return
	if resting:
		_rest_tick(delta)
		return
	var move := Vector3.ZERO
	if camera != null:
		aim_point = camera.mouse_ground_point()
	if not (casting_solo or leaping or captive or planted or dashing):
		move = _click_move(delta)
	if casting_solo or leaping or captive or planted or dashing:
		move = Vector3.ZERO # planté sur place en plein solo (ou en plein vol, ou en cage)
	var speed := Balance.HERO_SPEED * (0.6 if talents_caster.in_frenzy else 1.0)
	if dashing:
		pass # la glissade déplace le héros elle-même (voir dash())
	elif not leaping:
		velocity = move * speed
		move_and_slide()
		global_position.y = 0.0
	if captive:
		model.set_moving(false)
		_update_interaction()
		return

	var to_aim := aim_point - global_position
	to_aim.y = 0.0
	if _click_mode == ClickMode.ENEMY and is_instance_valid(_click_node):
		var to_enemy := _click_node.global_position - global_position
		to_enemy.y = 0.0
		if to_enemy.length() > 0.1:
			facing = to_enemy.normalized() # on regarde sa cible
	elif _click_mode != ClickMode.NONE and move.length() > 0.1:
		facing = move.normalized() # on regarde où l'on marche
	elif to_aim.length() > 0.3:
		facing = to_aim.normalized()
	elif move.length() > 0.1:
		facing = move.normalized()
	model.rotation.y = lerp_angle(model.rotation.y, atan2(facing.x, facing.z), 1.0 - exp(-20.0 * delta))
	model.set_moving(move.length() > 0.1)
	_update_travel(delta, move.length() > 0.1 and not dashing)
	model.tired = GameState.hp <= GameState.max_hp() * 0.3 # posture épuisée (modèle animé)

	_update_riff_hold(delta)
	# Maj + clic : frapper sur place (sans bouger), comme dans Diablo.
	if Input.is_action_pressed("attack") and Input.is_key_pressed(KEY_SHIFT) and not (DialogueBox.active or InventoryWindow.active):
		melee()
	_update_interaction()


## Clic droit maintenu : le Riff électrique (FIREBALL, Riff black metal) repart toutes les 0,30 s.
func _update_riff_hold(delta: float) -> void:
	if not _riff_held:
		return
	if not Input.is_action_pressed("spell_riff") or dead or captive or DialogueBox.active or InventoryWindow.active:
		_riff_held = false
		return
	_riff_hold -= delta
	if _riff_hold <= 0.0:
		_riff_hold += Balance.RIFF_REPEAT
		cast_riff(true)


## Marche continue : au-delà de SLING_AFTER secondes, la guitare passe dans le dos (le compteur repart à chaque arrêt).
func _update_travel(delta: float, moving: bool) -> void:
	_travel_time = _travel_time + delta if moving else 0.0
	if _travel_time >= SLING_AFTER and not travel_slung:
		travel_slung = true
		model.set_guitar_slung(true)


## Le héros reprend sa guitare en main (pour frapper ou jouer).
func _draw_guitar() -> void:
	_travel_time = 0.0
	if travel_slung:
		travel_slung = false
		model.set_guitar_slung(not spells_allowed)


# --- Déplacement à la souris (façon Diablo / Path of Exile) ------------------------------
# Clic sur le sol : le héros y va (petite zone lumineuse au sol). Clic maintenu : il suit
# la souris. Clic sur un ennemi : il va le frapper (et continue tant que le clic est tenu).
# Clic sur un personnage ou un objet : il y va puis interagit. Maj + clic : frappe sur place.

enum ClickMode { NONE, GROUND, ENEMY, INTERACT }
var _click_mode := ClickMode.NONE
var _click_node: Node3D
var _click_hold := false
var move_target := Vector3.ZERO
var _stuck_time := 0.0


func _on_left_click(shift: bool) -> void:
	if camera != null:
		aim_point = camera.mouse_ground_point()
	if shift:
		_click_mode = ClickMode.NONE
		melee()
		return
	_click_hold = true
	_stuck_time = 0.0
	var enemy := _enemy_under_cursor()
	if enemy != null:
		_click_mode = ClickMode.ENEMY
		_click_node = enemy
		return
	var target := _interactable_under_cursor()
	if target != null:
		_click_mode = ClickMode.INTERACT
		_click_node = target
		return
	_click_mode = ClickMode.GROUND
	move_target = Vector3(aim_point.x, 0.0, aim_point.z)
	MoveMarker.spawn(get_parent(), move_target)


## Direction de marche imposée par le dernier clic (ou vecteur nul une fois arrivé).
func _click_move(delta: float) -> Vector3:
	if _click_hold and not Input.is_action_pressed("attack"):
		_click_hold = false
	var dest := Vector3.ZERO
	var stop_at := 0.2
	match _click_mode:
		ClickMode.NONE:
			return Vector3.ZERO
		ClickMode.GROUND:
			if _click_hold:
				move_target = Vector3(aim_point.x, 0.0, aim_point.z) # clic maintenu : on suit la souris
			dest = move_target
		ClickMode.ENEMY:
			var e := _click_node as Enemy
			if e == null or not is_instance_valid(e) or not e.is_alive() or e.dormant:
				_click_mode = ClickMode.NONE
				return Vector3.ZERO
			dest = e.global_position
			stop_at = Balance.MELEE_RANGE + e.radius - 0.3
			if _flat_dist(dest, global_position) <= stop_at:
				# À portée : on frappe (une fois, ou en continu tant que le clic est maintenu).
				var to := dest - global_position
				to.y = 0.0
				if to.length() > 0.05:
					facing = to.normalized()
				if _ready_skill("attack"):
					melee()
					if not _click_hold:
						_click_mode = ClickMode.NONE
				return Vector3.ZERO
		ClickMode.INTERACT:
			if _click_node == null or not is_instance_valid(_click_node) or not _click_node.is_visible_in_tree():
				_click_mode = ClickMode.NONE
				return Vector3.ZERO
			dest = _click_node.global_position
			stop_at = minf(float(_click_node.get("interact_radius")) * 0.8, 1.8)
			if _flat_dist(dest, global_position) <= stop_at:
				_click_mode = ClickMode.NONE
				_click_node.call("interact", self)
				return Vector3.ZERO
	var to_dest := dest - global_position
	to_dest.y = 0.0
	if to_dest.length() <= stop_at:
		if not _click_hold:
			_click_mode = ClickMode.NONE
		return Vector3.ZERO
	# Bloqué contre un mur ou une table : on abandonne au bout d'un moment.
	if get_real_velocity().length() < Balance.HERO_SPEED * 0.2:
		_stuck_time += delta
		if _stuck_time > 0.6 and not _click_hold:
			_click_mode = ClickMode.NONE
			return Vector3.ZERO
	else:
		_stuck_time = 0.0
	return to_dest.normalized()


## Ennemi sous le curseur : distance écran au segment pieds → tête de chaque ennemi.
func _enemy_under_cursor() -> Enemy:
	var best: Enemy = null
	var best_d := INF
	for e in enemies():
		var d := _cursor_distance(e.global_position, e.height, e.radius)
		if d < best_d:
			best_d = d
			best = e
	return best if best_d <= 0.0 else null


func _interactable_under_cursor() -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for n in get_tree().get_nodes_in_group("interactable"):
		var n3 := n as Node3D
		if n3 == null or not n3.is_visible_in_tree():
			continue
		var h: Variant = n3.get("click_height") # zone cliquable propre (corps à fouiller, couchés au sol)
		var r: Variant = n3.get("click_radius")
		var d := _cursor_distance(n3.global_position, float(h) if h != null else 1.7, float(r) if r != null else 0.5)
		if d < best_d:
			best_d = d
			best = n3
	return best if best_d <= 0.0 else null


## Distance (en pixels, négative = sous le curseur) entre la souris et la silhouette
## verticale d'un objet (des pieds à `height`, de demi-largeur `radius` en mètres).
func _cursor_distance(feet: Vector3, height: float, radius: float) -> float:
	if camera == null or camera.is_position_behind(feet):
		return INF
	var mouse := get_viewport().get_mouse_position()
	var a := camera.unproject_position(feet)
	var b := camera.unproject_position(feet + Vector3(0, height, 0))
	var px_per_m := get_viewport().get_visible_rect().size.y / maxf(camera.size, 0.01)
	var closest := Geometry2D.get_closest_point_to_segment(mouse, a, b)
	return mouse.distance_to(closest) - (radius * px_per_m + 10.0)


func _unhandled_input(event: InputEvent) -> void:
	if dead or get_tree().paused or captive or DialogueBox.active or InventoryWindow.active:
		return
	var mb := event as InputEventMouseButton
	var left_click := mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
	if resting:
		if left_click:
			get_up() # un clic pour se lever du lit
			get_viewport().set_input_as_handled()
		return
	if sitting and left_click:
		stand_up() # un clic pour se lever de table
	if left_click:
		_on_left_click(mb.shift_pressed)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("dash"):
		dash()
	elif event.is_action_pressed("spell_tuning"):
		cast_tuning()
	elif event.is_action_pressed("spell_riff"):
		cast_riff()
		_riff_held = true # maintenu : il repart toutes les 0,30 s (_update_riff_hold)
		_riff_hold = Balance.RIFF_REPEAT
	elif event.is_action_pressed("spell_wave"):
		cast_wave()
	elif event.is_action_pressed("spell_solo"):
		cast_solo()
	elif event.is_action_pressed("potion"):
		drink_potion()
	elif event.is_action_pressed("interact") and _interact_target != null:
		_interact_target.call("interact", self)
	else:
		for slot in TalentDB.SLOT_COUNT:
			if event.is_action_pressed("talent_%d" % (slot + 1)):
				talents_caster.cast_slot(slot)
				return


# --- Ciblage ---------------------------------------------------------------

func enemies() -> Array[Enemy]:
	var out: Array[Enemy] = []
	for n in get_tree().get_nodes_in_group("enemies"):
		var e := n as Enemy
		if e != null and e.is_alive():
			out.append(e)
	return out


func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _cooldown(skill: String, base: float) -> void:
	var d := base * GameState.cooldown_multiplier()
	cooldowns[skill] = d
	Events.cooldown_started.emit(skill, d)


func _ready_skill(skill: String) -> bool:
	return float(cooldowns.get(skill, 0.0)) <= 0.0 and not casting_solo and not leaping and not captive and not resting \
		and not planted and not dashing and not talents_caster.blocks_actions()


# API utilisée par TalentCaster.
func skill_ready(skill: String) -> bool:
	return _ready_skill(skill)


func start_cooldown(skill: String, base: float) -> void:
	_cooldown(skill, base)


func no_mana() -> void:
	_no_mana()


## Inflige des dégâts de sort à un ennemi : bonus racial (Démon), recul, et talent Pogo
## (les ennemis fortement repoussés restent assommés). Un sort touche sa cible 8 fois sur 10
## (GameState.spell_hit_chance) ; ceux joués en mini-jeu (`sure`) touchent toujours. Renvoie false si raté.
func hit_enemy(e: Enemy, dmg: int, knockback: float, kind: String, from: Vector3 = Vector3.INF, sure: bool = false) -> bool:
	if e == null or not e.is_alive():
		return false
	if not sure and randf() >= GameState.spell_hit_chance():
		e.show_miss()
		return false
	var origin := global_position if from == Vector3.INF else from
	e.take_damage(maxi(1, roundi(dmg * GameState.spell_power())), origin, knockback, false, kind)
	if knockback >= 4.0 and GameState.has_talent("pogo") and e.is_alive():
		e.stun(1.5)
	return true


# --- Compétences -----------------------------------------------------------

## Coup de guitare au corps-à-corps : touche à coup sûr (pas de jet d'attaque), 1d6 + FOR (1 chance sur 20 de
## coup critique : 2d6 + FOR).
func melee() -> void:
	if not _ready_skill("attack") or not can_cast():
		return
	_cooldown("attack", Balance.MELEE_COOLDOWN)
	SpellFx.cast(self, "swing") # visible aussi chez les autres joueurs
	await get_tree().create_timer(Balance.MELEE_HIT_DELAY, false).timeout
	if dead:
		return
	var hit_any := false
	for e in enemies():
		var to := e.global_position - global_position
		to.y = 0.0
		var d := to.length()
		if d > Balance.MELEE_RANGE + e.radius:
			continue
		if d > 0.4 and facing.dot(to / d) < 0.3:
			continue
		hit_any = true
		var crit := Dice.d20() == 20
		var dmg := Dice.roll(2 if crit else 1, Balance.MELEE_DICE, GameState.mod("FOR") + (2 if GameState.race() == "orc" else 0))
		e.take_damage(maxi(1, roundi(dmg * GameState.damage_bonus())), global_position, Balance.MELEE_KNOCKBACK, crit, "phys")
	Sfx.play("thud" if hit_any else "swoosh", -4.0 if hit_any else -10.0)


## Accordage de cordes (touche 1) : un arc électrique frappe l'ennemi visé (11 m) et rebondit d'un coup sur les suivants
## (6 m d'un ennemi à l'autre), jusqu'à 5 cibles (6 avec Distorsion), -12 % de dégâts à chaque rebond, avec le son
## riff electrique.wav (celui de l'ancien Riff électrique). Sans mini-jeu (retiré le 6 oct. 2026) : chaque cible est
## touchée 8 fois sur 10, comme les autres sorts.
func cast_tuning() -> void:
	if not _ready_skill("tuning") or not can_cast():
		return
	var target := _tuning_target()
	if target == null:
		Events.notify("Aucune cible à portée pour l'Accordage de cordes", Events.COLOR_BAD)
		return
	if not GameState.spend_mana(Balance.TUNING_COST):
		_no_mana()
		return
	_cooldown("tuning", Balance.TUNING_COOLDOWN)
	_tuning_chain.clear()
	while target != null and _tuning_chain.size() < tuning_targets():
		_tuning_chain.append(target)
		target = _tuning_next()
	var points := PackedVector3Array([global_position + Vector3(0, 1.1, 0) + facing * 0.4])
	for e in _tuning_chain:
		points.append(e.global_position + Vector3(0, 0.9, 0))
	SpellFx.cast(self, "tuning", {"points": points}) # arcs et son du riff, vus et entendus par tous
	var bonus := 1.15 if GameState.has_talent("distorsion") else 1.0
	for i in _tuning_chain.size():
		var e := _tuning_chain[i]
		var dmg := roundi(Dice.roll(2, 6, GameState.mod("CHA")) * (1.0 - Balance.TUNING_FALLOFF * i) * bonus)
		if hit_enemy(e, dmg, 0.8, "shock") and GameState.has_talent("tempo_hypnotique") and e.is_alive():
			e.slow(0.6, 2.0)


## Nombre de cibles de l'Accordage : 5, 6 avec Distorsion.
func tuning_targets() -> int:
	return Balance.TUNING_MAX_TARGETS + (1 if GameState.has_talent("distorsion") else 0)


## Rebond suivant de l'Accordage : l'ennemi le plus proche du précédent (à 6 m au plus) pas encore touché, sinon null.
func _tuning_next() -> Enemy:
	var last: Enemy = _tuning_chain[-1]
	var best: Enemy = null
	var best_d := Balance.TUNING_JUMP_RANGE
	for e in enemies():
		var d := _flat_dist(e.global_position, last.global_position)
		if d < best_d and not _tuning_chain.has(e):
			best_d = d
			best = e
	return best


## 1re cible de l'Accordage : l'ennemi le plus proche du curseur, à 11 m du héros au plus.
func _tuning_target() -> Enemy:
	return _aimed_enemy(Balance.TUNING_FIRST_RANGE)


## Riff électrique (clic droit) : un éclair sur l'ennemi visé, sans recharge : un éclair par clic, et clic droit maintenu,
## un éclair toutes les 0,30 s (Balance.RIFF_REPEAT) ; seuls les dB le limitent. Plus de mini-jeu : il est passé à
## l'Accordage de cordes, qui a pris le son du riff ; l'éclair a pris le grésillement de l'Accordage. Selon la guitare
## équipée : Riff black metal (Batguitare, trait brumeux violet) ou FIREBALL (Xplode, boule de feu).
## `held` : tir répété du clic maintenu (pas de message à chaque tir s'il n'y a plus de cible ou de dB).
func cast_riff(held: bool = false) -> void:
	if not _ready_skill("riff") or not can_cast():
		return
	var target := _riff_target()
	if target == null:
		if held:
			return
		Events.notify("Aucune cible à portée pour le %s" % riff_name(), Events.COLOR_BAD)
		return
	if not GameState.spend_mana(Balance.RIFF_COST):
		if not held:
			_no_mana()
		return
	var from := global_position + Vector3(0, 1.1, 0) + facing * 0.4
	var to := target.global_position + Vector3(0, 0.9, 0)
	var variant := GameState.riff_variant()
	if variant == "fireball":
		# Xplode : une boule de feu crépitante part de la guitare vers l'ennemi, vue et entendue par tous.
		SpellFx.cast(self, "fireball", {"from": from, "to": to, "stack": 1})
	elif variant == "black_metal":
		# Batguitare : trait brumeux violet et vent brumeux, vus et entendus par tous.
		SpellFx.cast(self, "riff_black", {"from": from, "to": to, "stack": 1, "color": Color(0.62, 0.3, 1.0)})
	else:
		SpellFx.cast(self, "riff", {"from": from, "to": to, "stack": 1, "color": Color(0.55, 0.85, 1.0)})
	var dmg := maxi(1, roundi(Dice.roll(1, 10, GameState.mod("CHA")) * Balance.RIFF_DAMAGE)) # -33 %
	if GameState.has_talent("overdrive"):
		dmg = roundi(dmg * 1.25)
	hit_enemy(target, dmg, 0.4, str({"black_metal": "sound", "fireball": "fire"}.get(variant, "shock")), global_position)


## Nom du sort du clic droit : Riff électrique, Riff black metal (Batguitare) ou FIREBALL (Xplode).
static func riff_name() -> String:
	return str(GameState.riff_style()["name"])


func _riff_target() -> Enemy:
	return _aimed_enemy(Balance.RIFF_RANGE)


## L'ennemi le plus proche du curseur, à `reach` m du héros au plus.
func _aimed_enemy(reach: float) -> Enemy:
	var best: Enemy = null
	var best_score := INF
	for e in enemies():
		if _flat_dist(e.global_position, global_position) > reach:
			continue
		var score := _flat_dist(e.global_position, aim_point)
		if score < best_score:
			best_score = score
			best = e
	return best


## Sort 2 — Onde de choc sonore : tous les ennemis dans un rayon (jet de sauvegarde CON pour moitié).
func cast_wave() -> void:
	if not _ready_skill("wave") or not can_cast():
		return
	if not GameState.spend_mana(Balance.WAVE_COST):
		_no_mana()
		return
	_cooldown("wave", Balance.WAVE_COOLDOWN)
	var wave_radius := Balance.WAVE_RADIUS + (2.0 if GameState.has_talent("larsen_persistant") else 0.0)
	var wave_knock := Balance.WAVE_KNOCKBACK * (1.5 if GameState.has_talent("larsen_persistant") else 1.0)
	SpellFx.cast(self, "wave", {"pos": global_position, "radius": wave_radius}) # ondes de chocs.wav
	Events.camera_shake.emit(0.2, 0.25)
	var dc := GameState.spell_dc()
	for e in enemies():
		if _flat_dist(e.global_position, global_position) > wave_radius + e.radius:
			continue
		var dmg := Dice.roll(2, 8, GameState.mod("CHA"))
		if e.saving_throw(dc):
			dmg = floori(dmg / 2.0)
		if hit_enemy(e, dmg, wave_knock, "sound") and e.is_alive():
			e.headbang(Balance.WAVE_HEADBANG)


## Sort 3 — Solo de la Foudre : lance le mini-jeu ; le résultat arrive via Events.solo_finished.
func cast_solo() -> void:
	if not _ready_skill("solo") or not can_cast():
		return
	if GameState.mana < Balance.SOLO_COST:
		_no_mana()
		return
	casting_solo = true
	model.solo_pose(true)
	Events.notify("SOLO ! Invincible le temps du solo — touches 1 2 3 4", Events.COLOR_GOLD)
	Events.solo_requested.emit("foudre", Balance.SOLO_NOTES)


func _on_solo_finished(mode: String, hits: int, total: int) -> void:
	if mode != "foudre" or not casting_solo:
		return
	casting_solo = false
	model.solo_pose(false)
	_cooldown("solo", Balance.SOLO_COOLDOWN)
	var power := 0.0
	if hits >= total:
		power = 1.0
	elif hits >= total - 1:
		power = 0.7
	elif hits >= 3:
		power = 0.45
	if hits < total:
		# Notes mal jouées : la recharge du sort est 2,5 fois plus longue.
		_cooldown("solo", Balance.SOLO_COOLDOWN * Balance.MINIGAME_FAIL_COOLDOWN_MULT)
	if power <= 0.0:
		GameState.spend_mana(Balance.SOLO_COST * 0.5)
		Sfx.play("dud", -2.0)
		Events.notify("Fausse note ! Le solo s'effondre... (%d/%d)" % [hits, total], Events.COLOR_BAD)
		return
	GameState.spend_mana(Balance.SOLO_COST)
	var label := "SOLO PARFAIT !" if power >= 1.0 else "Solo réussi (%d/%d)" % [hits, total]
	Events.notify(label, Events.COLOR_GOLD)
	var targets: Array[Enemy] = []
	for e in enemies():
		if _flat_dist(e.global_position, global_position) <= Balance.SOLO_SCREEN_RADIUS:
			targets.append(e)
	LightningStorm.spawn(get_parent(), global_position, targets, power * GameState.spell_power())
	# Les autres joueurs voient la même pluie d'éclairs, sur les mêmes ennemis.
	var ids := PackedInt32Array()
	for e in targets:
		ids.append(e.net_id)
	SpellFx.broadcast("storm", {"center": global_position, "ids": ids})


func drink_potion() -> void:
	if not _ready_skill("potion"):
		return
	if GameState.potions <= 0:
		Events.notify("Plus de potion !", Events.COLOR_BAD)
		return
	if GameState.hp >= GameState.max_hp():
		Events.notify("Vous êtes déjà en pleine forme.")
		return
	_cooldown("potion", 1.0)
	GameState.potions -= 1
	Events.potions_changed.emit(GameState.potions)
	var heal := roundi(GameState.max_hp() * ItemDB.potion_heal_ratio())
	GameState.heal_hero(heal)
	Sfx.play("potion", -4.0)
	DamageNumber.spawn(get_parent(), global_position + Vector3(0, 2.2, 0), "+%d" % heal, Events.COLOR_GOOD)


func _no_mana() -> void:
	Events.notify("Pas assez de décibels !", Events.COLOR_MAGIC)
	Sfx.play("dud", -12.0)


# --- Dégâts ----------------------------------------------------------------

## Glissade sur les genoux (Espace) : 5 m dans la direction du déplacement (ou du regard),
## le héros est intouchable pendant toute la glissade. Recharge : 20 s.
func dash() -> void:
	if not _ready_skill("dash"):
		return
	# Dans le sens de la marche (clic), sinon vers la souris, sinon droit devant.
	var dir := Vector3(velocity.x, 0.0, velocity.z)
	if dir.length() < 0.1:
		dir = aim_point - global_position
		dir.y = 0.0
	if dir.length() < 0.3:
		dir = facing
	dir.y = 0.0
	dir = dir.normalized()
	var from := global_position
	var target := from + dir * Balance.DASH_DISTANCE
	# On s'arrête avant les murs.
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from + Vector3(0, 0.6, 0), target + Vector3(0, 0.6, 0), 1)
	var hit := space.intersect_ray(query)
	if not hit.is_empty():
		var p: Vector3 = hit["position"]
		target = Vector3(p.x, 0, p.z) - dir * (radius + 0.15)
	_cooldown("dash", Balance.DASH_COOLDOWN)
	dashing = true
	facing = dir
	model.rotation.y = atan2(dir.x, dir.z)
	model.knee_slide(Balance.DASH_DURATION + 0.25)
	Sfx.play("swoosh", -2.0, 0.0)
	var tw := create_tween()
	tw.tween_method(_dash_step.bind(from, target), 0.0, 1.0, Balance.DASH_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_interval(0.2)
	tw.tween_callback(func() -> void: dashing = false)


func _dash_step(k: float, from: Vector3, target: Vector3) -> void:
	global_position = from.lerp(target, k)


## Esquive passive réussie (l'ennemi rate son jet d'attaque) : petit saut sur une jambe
## façon Angus Young.
func dodged() -> void:
	if not dead and not casting_solo and not dashing:
		model.angus_hop()


func take_hit(amount: int, _from: Vector3, attacker: Node3D = null) -> void:
	if dead or _invuln > 0.0 or leaping:
		return
	get_up() # un coup réveille le dormeur
	if dashing:
		GameState.run_add("avoided", amount)
		DamageNumber.spawn(get_parent(), global_position + Vector3(0, 2.2, 0), "Glissade !", Color(0.7, 0.85, 1.0))
		return
	if casting_solo:
		GameState.run_add("avoided", amount)
		# Invincible pendant le solo : les coups ricochent sur l'aura dorée.
		_invuln = 0.35
		DamageNumber.spawn(get_parent(), global_position + Vector3(0, 2.2, 0), "Invincible", Color(1.0, 0.85, 0.4))
		return
	_invuln = 0.2
	# Talents de protection : Pile d'amplis, Sustain, Mur de Larsen, Encore !
	if talents_caster.amps_active():
		amount = ceili(amount * 0.5)
		talents_caster.retaliate(attacker)
	if GameState.has_talent("sustain"):
		amount = ceili(amount * 0.9)
	var before_shield := amount
	amount = talents_caster.absorb(amount)
	GameState.run_add("avoided", before_shield - amount)
	if amount <= 0:
		return
	if amount >= GameState.hp and talents_caster.try_encore():
		return
	GameState.run_add("taken", mini(amount, GameState.hp))
	GameState.damage_hero(amount)
	model.flash()
	DamageNumber.spawn(get_parent(), global_position + Vector3(0, 2.2, 0), str(amount), Events.COLOR_BAD)
	Sfx.play("hurt", -6.0)
	Events.camera_shake.emit(0.12, 0.15)
	Events.screen_flash.emit(Color(0.6, 0.0, 0.0, 0.25), 0.2)
	if GameState.hp <= 0:
		_die()


func _die() -> void:
	dead = true
	casting_solo = false
	model.die()
	Events.interaction_prompt.emit("")
	Events.hero_died.emit()


# --- Interaction -----------------------------------------------------------

func _update_interaction() -> void:
	var best: Node3D = null
	var best_d := INF
	for n in get_tree().get_nodes_in_group("interactable"):
		var n3 := n as Node3D
		if n3 == null or not n3.is_visible_in_tree():
			continue
		var r: float = n3.get("interact_radius")
		var d := _flat_dist(n3.global_position, global_position)
		if d <= r and d < best_d:
			best = n3
			best_d = d
	_interact_target = best
	var text := ""
	if best != null and not (DialogueBox.active or InventoryWindow.active): # pas d'invite par-dessus la conversation
		text = "[%s] %s" % [Controls.key_label("interact"), str(best.call("get_prompt"))]
	if text != _prompt_text:
		_prompt_text = text
		Events.interaction_prompt.emit(text)


# --- Repos dans un lit (chambre louée à la taverne) ----------------------------------------



## S'asseoir sur la chaise `seat` (regard `yaw`, vers la table).
func sit_at(seat: Vector3, yaw: float) -> void:
	if dead or resting:
		return
	sitting = true
	velocity = Vector3.ZERO
	_click_mode = ClickMode.NONE
	global_position = Vector3(seat.x, 0.0, seat.z)
	facing = Vector3(sin(yaw), 0.0, cos(yaw))
	model.rotation = Vector3(0, yaw, 0)
	model.set_moving(false)
	model.set_seated(true)


## Se lever de table : un pas en arrière, loin de la table.
func stand_up() -> void:
	if not sitting:
		return
	sitting = false
	model.set_seated(false)
	global_position -= facing * 0.55
## S'allonge sur le lit (centre `bed_center`, tête vers -Z tourné de `yaw`).
func lie_down(bed_center: Vector3, yaw: float = 0.0) -> void:
	if resting or dead:
		return
	resting = true
	_rest_from = global_position
	_rest_heal = 0.0
	velocity = Vector3.ZERO
	global_position = Vector3(bed_center.x, 0.0, bed_center.z)
	model.set_moving(false)
	# Allongé sur le dos : pieds au bout du lit, tête sur l'oreiller.
	if model.lie(true):
		# Modèle animé : animation « sleep », tournée pour que la tête soit sur l'oreiller.
		model.rotation = Vector3(0, yaw + HeroModel.SLEEP_YAW, 0.0)
		model.position = Basis(Vector3.UP, yaw) * HeroModel.SLEEP_OFFSET
	else:
		model.rotation = Vector3(-PI * 0.5, yaw, 0.0)
		model.position = Basis(Vector3.UP, yaw) * Vector3(0, 0.62, 0.95)
	Events.notify("Vous vous allongez... (bougez pour vous lever)", Events.COLOR_GOOD)


func get_up() -> void:
	if not resting:
		return
	resting = false
	model.lie(false)
	model.rotation = Vector3(0, atan2(facing.x, facing.z), 0)
	model.position = Vector3.ZERO
	global_position = _rest_from


## 10 s pour passer de 1 PV à la vie pleine (les dB remontent au même rythme).
func _rest_tick(delta: float) -> void:
	velocity = Vector3.ZERO
	var max_hp := GameState.max_hp()
	_rest_heal += max_hp / Balance.BED_FULL_HEAL_TIME * delta
	var whole := int(_rest_heal)
	if whole > 0:
		_rest_heal -= whole
		GameState.heal_hero(whole)
	GameState.mana = minf(GameState.max_mana(), GameState.mana + GameState.max_mana() / Balance.BED_FULL_HEAL_TIME * delta)
	Events.hero_mana_changed.emit(GameState.mana, GameState.max_mana())
	if GameState.hp >= max_hp and GameState.mana >= GameState.max_mana():
		GameState.flags.erase("room_paid") # une nuit par location
		Events.notify("Vous vous levez frais comme un roadie après un concert. PV et dB au maximum !", Events.COLOR_GOOD)
		get_up()
