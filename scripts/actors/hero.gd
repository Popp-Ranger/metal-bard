class_name Hero
extends CharacterBody3D
## Riffald, le barde métal. Déplacement ZQSD/WASD relatif à la caméra iso,
## visée à la souris, coup de luth + 3 sorts + potion + interaction.

var camera: IsoCamera
var model: HeroModel
var dead := false
var casting_solo := false
var facing := Vector3(0, 0, 1)
var aim_point := Vector3.ZERO
var cooldowns := {"attack": 0.0, "arc": 0.0, "wave": 0.0, "solo": 0.0, "potion": 0.0}
var radius := 0.35

var _invuln := 0.0
var _interact_target: Node3D
var _prompt_text := ""


func _ready() -> void:
	add_to_group("hero")
	collision_layer = 2
	collision_mask = 1 | 4
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = radius
	cap.height = 1.8
	col.shape = cap
	col.position.y = 0.9
	add_child(col)
	model = HeroModel.new()
	add_child(model)
	# Halo de lumière chaude qui suit le héros (la « torche » façon Darkest Dungeon).
	var halo := OmniLight3D.new()
	halo.position = Vector3(1.3, 3.0, 1.3) # décalée vers la caméra pour éclairer le héros de face
	halo.light_color = Color(1.0, 0.78, 0.55)
	halo.light_energy = 1.8
	halo.omni_range = 10.0
	halo.omni_attenuation = 1.2
	halo.shadow_enabled = true
	add_child(halo)
	Events.solo_finished.connect(_on_solo_finished)


func _physics_process(delta: float) -> void:
	for k: String in cooldowns:
		cooldowns[k] = maxf(0.0, float(cooldowns[k]) - delta)
	_invuln = maxf(0.0, _invuln - delta)
	if dead:
		velocity = Vector3.ZERO
		return
	GameState.regen_mana(delta)

	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var move := IsoCamera.SCREEN_RIGHT * input.x + IsoCamera.SCREEN_UP * -input.y
	velocity = move * Balance.HERO_SPEED
	move_and_slide()
	global_position.y = 0.0

	if camera != null:
		aim_point = camera.mouse_ground_point()
	var to_aim := aim_point - global_position
	to_aim.y = 0.0
	if to_aim.length() > 0.3:
		facing = to_aim.normalized()
	elif move.length() > 0.1:
		facing = move.normalized()
	model.rotation.y = lerp_angle(model.rotation.y, atan2(facing.x, facing.z), 1.0 - exp(-20.0 * delta))
	model.set_moving(move.length() > 0.1)

	if Input.is_action_pressed("attack"):
		melee()
	_update_interaction()


func _unhandled_input(event: InputEvent) -> void:
	if dead or get_tree().paused:
		return
	if event.is_action_pressed("spell_arc"):
		cast_arc()
	elif event.is_action_pressed("spell_wave"):
		cast_wave()
	elif event.is_action_pressed("spell_solo"):
		cast_solo()
	elif event.is_action_pressed("potion"):
		drink_potion()
	elif event.is_action_pressed("interact") and _interact_target != null:
		_interact_target.call("interact", self)


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
	return float(cooldowns[skill]) <= 0.0 and not casting_solo


# --- Compétences -----------------------------------------------------------

## Coup de luth au corps-à-corps : jet d'attaque d20 + maîtrise + FOR contre la CA.
func melee() -> void:
	if not _ready_skill("attack"):
		return
	_cooldown("attack", Balance.MELEE_COOLDOWN)
	model.swing()
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
		var dmg := Dice.roll(2 if crit else 1, 8, GameState.mod("FOR"))
		e.take_damage(maxi(1, dmg), global_position, Balance.MELEE_KNOCKBACK, crit, "phys")
	Sfx.play("thud" if hit_any else "swoosh", -4.0 if hit_any else -10.0)


## Sort 1 — Riff électrique : arc qui rebondit sur jusqu'à 5 ennemis.
func cast_arc() -> void:
	if not _ready_skill("arc"):
		return
	var targets := _arc_targets()
	if targets.is_empty():
		Events.notify("Aucune cible à portée pour le Riff électrique", Events.COLOR_BAD)
		return
	if not GameState.spend_mana(Balance.ARC_COST):
		_no_mana()
		return
	_cooldown("arc", Balance.ARC_COOLDOWN)
	model.strum()
	Sfx.play("zap", Balance.ARC_VOLUME_DB)
	var from := global_position + Vector3(0, 1.1, 0) + facing * 0.4
	var cha := GameState.mod("CHA")
	for i in targets.size():
		var e := targets[i]
		var to := e.global_position + Vector3(0, 0.9, 0)
		ArcBolt.spawn(get_parent(), from, to)
		var dmg := roundi(Dice.roll(2, 6, cha) * (1.0 - Balance.ARC_FALLOFF * i))
		e.take_damage(maxi(1, dmg), global_position, 0.8, false, "shock")
		from = to


func _arc_targets() -> Array[Enemy]:
	var all := enemies()
	var result: Array[Enemy] = []
	# Première cible : l'ennemi le plus proche du curseur (sinon du héros).
	var first: Enemy = null
	var best := INF
	for e in all:
		if _flat_dist(e.global_position, global_position) > Balance.ARC_FIRST_RANGE:
			continue
		var score := _flat_dist(e.global_position, aim_point)
		if score < best:
			best = score
			first = e
	if first == null:
		return result
	result.append(first)
	while result.size() < Balance.ARC_MAX_TARGETS:
		var last := result[-1]
		var next: Enemy = null
		var nd := Balance.ARC_JUMP_RANGE
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
	if not _ready_skill("wave"):
		return
	if not GameState.spend_mana(Balance.WAVE_COST):
		_no_mana()
		return
	_cooldown("wave", Balance.WAVE_COOLDOWN)
	model.strum()
	Shockwave.spawn(get_parent(), global_position, Balance.WAVE_RADIUS)
	Sfx.play("boom", -2.0)
	Events.camera_shake.emit(0.2, 0.25)
	var dc := GameState.spell_dc()
	for e in enemies():
		if _flat_dist(e.global_position, global_position) > Balance.WAVE_RADIUS + e.radius:
			continue
		var dmg := Dice.roll(2, 8, GameState.mod("CHA"))
		if e.saving_throw(dc):
			dmg = floori(dmg / 2.0)
		e.take_damage(maxi(1, dmg), global_position, Balance.WAVE_KNOCKBACK, false, "sound")


## Sort 3 — Solo de la Foudre : lance le mini-jeu ; le résultat arrive via Events.solo_finished.
func cast_solo() -> void:
	if not _ready_skill("solo"):
		return
	if GameState.mana < Balance.SOLO_COST:
		_no_mana()
		return
	casting_solo = true
	model.solo_pose(true)
	Events.solo_requested.emit()


func _on_solo_finished(hits: int, total: int) -> void:
	if not casting_solo:
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
	LightningStorm.spawn(get_parent(), global_position, targets, power)


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
	var heal := roundi(GameState.max_hp() * Balance.POTION_HEAL_RATIO)
	GameState.heal_hero(heal)
	Sfx.play("potion", -4.0)
	DamageNumber.spawn(get_parent(), global_position + Vector3(0, 2.2, 0), "+%d" % heal, Events.COLOR_GOOD)


func _no_mana() -> void:
	Events.notify("Pas assez de décibels !", Events.COLOR_MAGIC)
	Sfx.play("dud", -12.0)


# --- Dégâts ----------------------------------------------------------------

func take_hit(amount: int, _from: Vector3) -> void:
	if dead or _invuln > 0.0:
		return
	_invuln = 0.2
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
	if best != null:
		text = "[%s] %s" % [Controls.key_label("interact"), str(best.call("get_prompt"))]
	if text != _prompt_text:
		_prompt_text = text
		Events.interaction_prompt.emit(text)
