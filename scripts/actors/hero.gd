class_name Hero
extends CharacterBody3D
## Le barde métal (personnage créé par le joueur). Déplacement ZQSD/WASD relatif à la
## caméra iso, visée à la souris, coup de guitare + 4 sorts de base + talents (touches 4-7)
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
var _rest_from := Vector3.ZERO
var _rest_heal := 0.0
var _regen_tick := 0.0
var facing := Vector3(0, 0, 1)
var aim_point := Vector3.ZERO
var cooldowns := {"attack": 0.0, "dash": 0.0, "tuning": 0.0, "riff": 0.0, "wave": 0.0, "solo": 0.0, "potion": 0.0}
## Combo du Riff électrique : nombre d'appuis consécutifs en rythme (1..RIFF_MAX_STACKS).
var riff_stack := 0
var _riff_last := -100.0
var radius := 0.35
## Peut-on jouer ici ? Non dans la taverne hors du sous-sol : ni sorts ni coups de guitare,
## guitare portée dans le dos (voir Level.spells_allowed_at).
var spells_allowed := true
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
	add_child(model)
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


## Zone où l'on ne joue pas : guitare dans le dos (mise à jour à chaque image, escaliers compris).
func _update_zone() -> void:
	var level := Level.of(self)
	spells_allowed = level == null or level.spells_allowed_at(global_position)
	model.set_guitar_slung(not spells_allowed)


## Sorts et coups de guitare : refusés (avec un message, pas plus d'une fois par seconde et demie)
## là où l'on ne joue pas.
func can_cast() -> bool:
	if spells_allowed:
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

	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if DialogueBox.active or InventoryWindow.active:
		# En pleine conversation (le jeu continue) : le héros écoute, sans bouger ni agir.
		input = Vector2.ZERO
		_click_mode = ClickMode.NONE
	if resting:
		_rest_tick(delta, input)
		return
	var move := IsoCamera.SCREEN_RIGHT * input.x + IsoCamera.SCREEN_UP * -input.y
	if camera != null:
		aim_point = camera.mouse_ground_point()
	if input.length() > 0.1:
		_click_mode = ClickMode.NONE # le clavier reprend la main
	elif not (casting_solo or leaping or captive or planted or dashing):
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
	model.tired = GameState.hp <= GameState.max_hp() * 0.3 # posture épuisée (modèle animé)

	# Maj + clic : frapper sur place (sans bouger), comme dans Diablo.
	if Input.is_action_pressed("attack") and Input.is_key_pressed(KEY_SHIFT) and not (DialogueBox.active or InventoryWindow.active):
		melee()
	_update_interaction()


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
		var d := _cursor_distance(n3.global_position, 1.7, 0.5)
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
## (les ennemis fortement repoussés restent assommés).
func hit_enemy(e: Enemy, dmg: int, knockback: float, kind: String, from: Vector3 = Vector3.INF) -> void:
	if e == null or not e.is_alive():
		return
	var origin := global_position if from == Vector3.INF else from
	e.take_damage(maxi(1, roundi(dmg * GameState.spell_power())), origin, knockback, false, kind)
	if knockback >= 4.0 and GameState.has_talent("pogo") and e.is_alive():
		e.stun(1.5)


# --- Compétences -----------------------------------------------------------

## Coup de luth au corps-à-corps : jet d'attaque d20 + maîtrise + FOR contre la CA.
func melee() -> void:
	if not _ready_skill("attack") or not can_cast():
		return
	_cooldown("attack", Balance.MELEE_COOLDOWN)
	SpellFx.cast(self, "swing") # visible aussi chez les autres joueurs
	await get_tree().create_timer(0.15, false).timeout
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
		var result := Dice.attack_roll(GameState.proficiency() + GameState.mod("FOR"), e.armor_class)
		if result == 0:
			e.show_miss()
			continue
		var crit := result == 2
		var dmg := Dice.roll(2 if crit else 1, 8, GameState.mod("FOR") + (2 if GameState.race() == "orc" else 0))
		e.take_damage(maxi(1, dmg), global_position, Balance.MELEE_KNOCKBACK, crit, "phys")
	Sfx.play("thud" if hit_any else "swoosh", -4.0 if hit_any else -10.0)


## Accordage de cordes (clic droit) : arc électrique qui rebondit sur jusqu'à 5 ennemis.
func cast_tuning() -> void:
	if not _ready_skill("tuning") or not can_cast():
		return
	var targets := _arc_targets()
	if targets.is_empty():
		Events.notify("Aucune cible à portée pour l'Accordage de cordes", Events.COLOR_BAD)
		return
	if not GameState.spend_mana(Balance.TUNING_COST):
		_no_mana()
		return
	_cooldown("tuning", Balance.TUNING_COOLDOWN)
	var points := PackedVector3Array([global_position + Vector3(0, 1.1, 0) + facing * 0.4])
	for e in targets:
		points.append(e.global_position + Vector3(0, 0.9, 0))
	SpellFx.cast(self, "tuning", {"points": points}) # arc électrique visible par tous
	var cha := GameState.mod("CHA")
	var bonus := 1.15 if GameState.has_talent("distorsion") else 1.0
	for i in targets.size():
		var dmg := roundi(Dice.roll(2, 6, cha) * (1.0 - Balance.TUNING_FALLOFF * i) * bonus)
		hit_enemy(targets[i], dmg, 0.8, "shock")


## Riff électrique (touche 1) : éclair sur UNE cible. Chaque appui en rythme
## (dès la fin de la recharge de 3 s, dans les 0,4 s) fait monter le combo : ×1 → ×1,67 → ×2,33 → ×3.
## Au maximum, le riff reste à ×3 tant qu'on garde le rythme ; un contretemps remet à ×1.
func cast_riff() -> void:
	if not _ready_skill("riff") or not can_cast():
		return
	var target := _riff_target()
	if target == null:
		Events.notify("Aucune cible à portée pour le Riff électrique", Events.COLOR_BAD)
		return
	if not GameState.spend_mana(Balance.RIFF_COST):
		_no_mana()
		return
	var now := Time.get_ticks_msec() / 1000.0
	var on_beat := absf((now - _riff_last) - Balance.RIFF_BEAT) <= Balance.RIFF_BEAT_TOLERANCE
	var max_stacks := riff_max_stacks()
	riff_stack = mini(riff_stack + 1, max_stacks) if on_beat else 1
	_riff_last = now
	var mult := riff_multiplier(riff_stack, max_stacks, riff_max_mult())
	# Délai fixe (non réduit par l'INT) : le tempo doit rester stable.
	cooldowns["riff"] = Balance.RIFF_MIN_INTERVAL
	Events.cooldown_started.emit("riff", Balance.RIFF_MIN_INTERVAL)
	Events.riff_combo.emit(riff_stack, mult)
	var k := float(riff_stack - 1) / float(max_stacks - 1)
	var color := Color(0.55, 0.85, 1.0).lerp(Color(1.0, 0.8, 0.3), k)
	# Éclair et son riff electrique.wav, visibles et audibles par tous les joueurs.
	SpellFx.cast(self, "riff", {"from": global_position + Vector3(0, 1.1, 0) + facing * 0.4,
		"to": target.global_position + Vector3(0, 0.9, 0), "stack": riff_stack, "color": color})
	var dmg := roundi(Dice.roll(1, 10, GameState.mod("CHA")) * mult)
	target.take_damage(maxi(1, roundi(dmg * GameState.spell_power())), global_position, 0.4, riff_stack >= max_stacks, "shock")
	if GameState.has_talent("tempo_hypnotique") and target.is_alive():
		target.slow(0.6, 2.0)
	if riff_stack > 1:
		var label := "RYTHME ×%.1f" % mult if riff_stack < max_stacks else "EN RYTHME ×%d !" % roundi(mult)
		DamageNumber.spawn(get_parent(), global_position + Vector3(0, 2.4, 0), label, color)


static func riff_multiplier(stack: int, max_stacks: int = Balance.RIFF_MAX_STACKS, max_mult: float = Balance.RIFF_MAX_MULT) -> float:
	var steps := float(max_stacks - 1)
	return 1.0 + (max_mult - 1.0) * float(clampi(stack, 1, max_stacks) - 1) / steps


## Overdrive : 5 paliers et ×4 au lieu de 4 paliers et ×3.
func riff_max_stacks() -> int:
	return Balance.RIFF_MAX_STACKS + (1 if GameState.has_talent("overdrive") else 0)


func riff_max_mult() -> float:
	return Balance.RIFF_MAX_MULT + (1.0 if GameState.has_talent("overdrive") else 0.0)


func _riff_target() -> Enemy:
	var best: Enemy = null
	var best_score := INF
	for e in enemies():
		if _flat_dist(e.global_position, global_position) > Balance.RIFF_RANGE:
			continue
		var score := _flat_dist(e.global_position, aim_point)
		if score < best_score:
			best_score = score
			best = e
	return best

func _arc_targets() -> Array[Enemy]:
	var all := enemies()
	var result: Array[Enemy] = []
	# Première cible : l'ennemi le plus proche du curseur (sinon du héros).
	var first: Enemy = null
	var best := INF
	for e in all:
		if _flat_dist(e.global_position, global_position) > Balance.TUNING_FIRST_RANGE:
			continue
		var score := _flat_dist(e.global_position, aim_point)
		if score < best:
			best = score
			first = e
	if first == null:
		return result
	result.append(first)
	var max_targets := Balance.TUNING_MAX_TARGETS + (1 if GameState.has_talent("distorsion") else 0)
	while result.size() < max_targets:
		var last := result[-1]
		var next: Enemy = null
		var nd := Balance.TUNING_JUMP_RANGE
		for e in all:
			if result.has(e):
				continue
			var d := _flat_dist(e.global_position, last.global_position)
			if d < nd:
				nd = d
				next = e
		if next == null:
			break
		result.append(next)
	return result


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
		hit_enemy(e, dmg, wave_knock, "sound")
		if e.is_alive():
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
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var dir := IsoCamera.SCREEN_RIGHT * input.x + IsoCamera.SCREEN_UP * -input.y
	if dir.length() < 0.1:
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
func _rest_tick(delta: float, input: Vector2) -> void:
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
	elif input.length() > 0.1:
		Events.notify("Vous vous levez avant d'être complètement reposé.", Events.COLOR_DEFAULT)
		get_up()
