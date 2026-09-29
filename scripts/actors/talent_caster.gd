class_name TalentCaster
extends Node
## Sorts et effets de l'arbre de talents (voir TalentDB). Enfant du héros.
## Les talents actifs se lancent depuis les touches 4 à 7 (GameState.spell_slots).

const FRENZY_RADIUS := 12.0
const FRENZY_NOTES := 12
const FRENZY_NOTES_MASTER := 16
const ENCORE_COOLDOWN := 120.0
## Rayon des soins de groupe (Ballade réparatrice) : tous les alliés proches sont soignés.
const GROUP_HEAL_RADIUS := 10.0

var hero: Hero
var in_frenzy := false # Solo endiablé en cours

var _encore_cd := 0.0
var _hot_time := 0.0
var _hot_tick := 0.0
var _zone_time := 0.0
var _zone_tick := 0.0
var _zone_pos := Vector3.ZERO
var _zone_node: Node3D
var _shield_time := 0.0
var _shield_node: MeshInstance3D
var _amps_time := 0.0
var _amps_node: Node3D


func _ready() -> void:
	hero = get_parent() as Hero
	Events.enemy_killed.connect(_on_enemy_killed)
	Events.solo_note_hit.connect(_on_solo_note_hit)
	Events.solo_finished.connect(_on_solo_finished)
	# Bulle du Mur de Larsen.
	_shield_node = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	_shield_node.mesh = sphere
	_shield_node.position.y = 1.0
	_shield_node.scale = Vector3(0.9, 1.15, 0.9) * hero.model.scale.y
	_shield_node.material_override = Visuals.transparent_mat(Color(0.35, 0.65, 1.0, 0.18), 1.2)
	_shield_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shield_node.visible = false
	hero.add_child.call_deferred(_shield_node)


func _physics_process(delta: float) -> void:
	_encore_cd = maxf(0.0, _encore_cd - delta)
	# Ballade réparatrice : soin continu.
	if _hot_time > 0.0:
		_hot_time -= delta
		_hot_tick -= delta
		if _hot_tick <= 0.0:
			_hot_tick = 1.0
			_heal_group(hero.global_position, GROUP_HEAL_RADIUS, 0.05)
	# Hymne du Phénix : zone de soin.
	if _zone_time > 0.0:
		_zone_time -= delta
		_zone_tick -= delta
		if _zone_tick <= 0.0:
			_zone_tick = 1.0
			_heal_group(_zone_pos, 4.0, 0.06)
		if _zone_time <= 0.0 and is_instance_valid(_zone_node):
			_zone_node.queue_free()
	# Mur de Larsen.
	if _shield_time > 0.0:
		_shield_time -= delta
		_shield_node.rotation.y += delta
		if _shield_time <= 0.0:
			set_shield(0)
	# Pile d'amplis.
	if _amps_time > 0.0:
		_amps_time -= delta
		if _amps_time <= 0.0 and is_instance_valid(_amps_node):
			_amps_node.queue_free()
	# Solo endiablé : tout ennemi qui entre dans le rayon tombe en transe.
	if in_frenzy:
		for e in hero.enemies():
			if _flat(e.global_position, hero.global_position) <= FRENZY_RADIUS:
				e.enter_trance()


# --- Lancement ------------------------------------------------------------------

func cast_slot(slot: int) -> void:
	var id: String = GameState.spell_slots[slot]
	if id.is_empty():
		Events.notify("Aucun sort sur la touche %s — ouvrez l'arbre de talents [%s]" % [
			Controls.key_label("talent_%d" % (slot + 1)), Controls.key_label("talents")], Events.COLOR_BAD)
		return
	cast(id)


func cast(id: String) -> bool:
	var t := TalentDB.get_talent(id)
	if not GameState.has_talent(id) or not bool(t.get("active", false)):
		return false
	if not hero.skill_ready(id):
		return false
	var cost := float(t.get("cost", 0.0))
	if GameState.mana < cost:
		hero.no_mana()
		return false
	var ok: bool = call("_cast_" + id)
	if not ok:
		return false
	GameState.spend_mana(cost)
	hero.start_cooldown(id, float(t.get("cooldown", 1.0)))
	return true


func blocks_actions() -> bool:
	return in_frenzy


# --- Ballade (soins) --------------------------------------------------------------

func _cast_ballade_reparatrice() -> bool:
	hero.model.strum()
	var amount := roundi(Dice.roll(2, 8, GameState.mod("CHA")) * GameState.spell_power())
	_heal(amount)
	for ally in _allies_near(hero.global_position, GROUP_HEAL_RADIUS):
		ally.call("receive_heal", amount)
		_burst(ally.global_position, Color(0.45, 1.0, 0.5), 10)
	_hot_time = 4.0
	_hot_tick = 1.0
	_burst(hero.global_position, Color(0.45, 1.0, 0.5), 18)
	Sfx.play("levelup", -8.0, 0.0)
	return true


func _cast_hymne_phenix() -> bool:
	hero.model.strum()
	_zone_pos = hero.global_position
	_zone_time = 8.0
	_zone_tick = 0.0
	if is_instance_valid(_zone_node):
		_zone_node.queue_free()
	_zone_node = Node3D.new()
	_zone_node.position = _zone_pos
	hero.get_parent().add_child(_zone_node)
	Visuals.torus(_zone_node, 3.8, 4.0, Vector3(0, 0.05, 0), Visuals.glow_mat(Color(1.0, 0.7, 0.2), 3.0))
	Visuals.torus(_zone_node, 1.8, 1.9, Vector3(0, 0.05, 0), Visuals.glow_mat(Color(1.0, 0.5, 0.1), 2.0))
	var flames := _particles(Color(1.0, 0.6, 0.15), 60, 1.2, 3.8)
	flames.one_shot = false
	flames.emitting = true
	_zone_node.add_child(flames)
	var light := Visuals.flicker_light(_zone_node, Vector3(0, 1.5, 0), Color(1.0, 0.65, 0.3), 3.0, 8.0)
	light.flicker_amount = 0.3
	Sfx.play("portal", -6.0)
	Events.notify("Hymne du Phénix : restez dans le cercle !", Color(1.0, 0.75, 0.3))
	return true


func _on_enemy_killed(_enemy: Node3D) -> void:
	if GameState.has_talent("rappel") and not hero.dead:
		_heal(3, false)
		GameState.mana = minf(GameState.max_mana(), GameState.mana + 4.0)
		Events.hero_mana_changed.emit(GameState.mana, GameState.max_mana())


## Encore ! : appelé par le héros avant un coup mortel. Renvoie true si le héros survit.
func try_encore() -> bool:
	if not GameState.has_talent("encore") or _encore_cd > 0.0:
		return false
	_encore_cd = ENCORE_COOLDOWN
	GameState.hp = 1
	_heal(roundi(GameState.max_hp() * 0.5))
	_burst(hero.global_position, Color(1.0, 0.85, 0.3), 30)
	Sfx.play("levelup", 0.0, 0.0)
	Events.screen_flash.emit(Color(1.0, 0.85, 0.4, 0.4), 0.5)
	Events.notify("ENCORE ! Le public refuse que vous quittiez la scène !", Events.COLOR_GOLD)
	return true


# --- Mur du Son (protection) --------------------------------------------------------

func _cast_mur_larsen() -> bool:
	hero.model.strum()
	set_shield(10 + 3 * GameState.mod("CHA") + 2 * GameState.stats.level)
	_shield_time = 8.0
	Sfx.play("zap", -10.0)
	Sfx.play("boom", -14.0)
	return true


func set_shield(amount: int) -> void:
	GameState.shield = maxi(0, amount)
	_shield_node.visible = GameState.shield > 0
	Events.shield_changed.emit(GameState.shield)


## Absorbe des dégâts avec le bouclier ; renvoie les dégâts restants.
func absorb(amount: int) -> int:
	if GameState.shield <= 0:
		return amount
	var absorbed := mini(amount, GameState.shield)
	set_shield(GameState.shield - absorbed)
	DamageNumber.spawn(hero.get_parent(), hero.global_position + Vector3(0, 2.4, 0), "Absorbé %d" % absorbed, Color(0.5, 0.75, 1.0))
	if GameState.shield <= 0:
		_shield_time = 0.0
		Sfx.play("dud", -8.0)
		if GameState.has_talent("sustain"):
			# Le larsen explose : onde qui repousse.
			Shockwave.spawn(hero.get_parent(), hero.global_position, 4.0)
			for e in hero.enemies():
				if _flat(e.global_position, hero.global_position) <= 4.0 + e.radius:
					hero.hit_enemy(e, Dice.roll(1, 8, GameState.mod("CHA")), 6.0, "sound")
	return amount - absorbed


func _cast_pile_amplis() -> bool:
	hero.model.strum()
	_amps_time = 6.0
	if is_instance_valid(_amps_node):
		_amps_node.queue_free()
	_amps_node = Node3D.new()
	hero.add_child(_amps_node)
	var cab := Visuals.mat(Color(0.06, 0.06, 0.06), 0.6)
	var grill := Visuals.mat(Color(0.18, 0.16, 0.14), 0.9)
	for side: float in [-1.0, 1.0]:
		var amp := Node3D.new()
		amp.position = Vector3(0.9 * side, 0, -0.3)
		_amps_node.add_child(amp)
		Visuals.box(amp, Vector3(0.6, 1.1, 0.4), Vector3(0, 0.55, 0), cab)
		for k in 2:
			Visuals.cylinder(amp, 0.13, 0.13, 0.02, Vector3(0, 0.33 + k * 0.42, 0.2), grill, Vector3(90, 0, 0), 16)
		Visuals.box(amp, Vector3(0.62, 0.12, 0.42), Vector3(0, 1.15, 0), Visuals.glow_mat(Color(0.9, 0.2, 0.1), 1.2))
		amp.scale = Vector3.ONE * 0.05
		amp.create_tween().tween_property(amp, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK)
	Sfx.play("thud", -2.0)
	return true


## Pile d'amplis active : dégâts divisés par 2 et riposte sur l'attaquant.
func amps_active() -> bool:
	return _amps_time > 0.0


func retaliate(attacker: Node3D) -> void:
	var e := attacker as Enemy
	if e == null or not e.is_alive():
		return
	ArcBolt.spawn(hero.get_parent(), hero.global_position + Vector3(0, 1.2, 0), e.global_position + Vector3(0, 1.0, 0), 0.1, 0.2, Color(1.0, 0.4, 0.3))
	hero.hit_enemy(e, Dice.roll(1, 6, GameState.mod("CHA")), 1.5, "sound")


# --- Mosh Pit (repoussement) -----------------------------------------------------------

func _cast_wall_of_death() -> bool:
	hero.model.swing()
	var origin := hero.global_position
	for k in 3:
		Shockwave.spawn(hero.get_parent(), origin + hero.facing * (1.5 + k * 2.0), 1.6 + k * 0.9)
	Sfx.play("boom", 0.0)
	Events.camera_shake.emit(0.3, 0.3)
	for e in hero.enemies():
		var to := e.global_position - origin
		to.y = 0.0
		var d := to.length()
		if d > 7.0 + e.radius:
			continue
		if d > 0.3 and hero.facing.dot(to / d) < 0.5: # cône de 120°
			continue
		hero.hit_enemy(e, Dice.roll(1, 8, GameState.mod("CHA")), 9.0, "sound")
	return true


func _cast_stage_diving() -> bool:
	var from := hero.global_position
	var target := hero.aim_point
	target.y = 0.0
	var dir := target - from
	dir.y = 0.0
	if dir.length() > 8.0:
		target = from + dir.normalized() * 8.0
	# On ne traverse pas les murs : on s'arrête avant l'obstacle.
	var space := hero.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from + Vector3(0, 1.0, 0), target + Vector3(0, 1.0, 0), 1)
	var hit := space.intersect_ray(query)
	if not hit.is_empty():
		var p: Vector3 = hit["position"]
		target = Vector3(p.x, 0, p.z) - dir.normalized() * 0.8
	hero.leaping = true
	hero.model.solo_pose(true)
	Sfx.play("swoosh", -2.0)
	var tw := hero.create_tween()
	var hop := func(k: float) -> void:
		hero.global_position = from.lerp(target, k)
		hero.model.position.y = sin(k * PI) * 2.5
	tw.tween_method(hop, 0.0, 1.0, 0.55).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(_land_stage_dive)
	return true


func _land_stage_dive() -> void:
	hero.leaping = false
	hero.model.position.y = 0.0
	hero.model.solo_pose(false)
	Shockwave.spawn(hero.get_parent(), hero.global_position, 4.0)
	Sfx.play("boom", 0.0)
	Events.camera_shake.emit(0.4, 0.35)
	for e in hero.enemies():
		if _flat(e.global_position, hero.global_position) <= 4.0 + e.radius:
			hero.hit_enemy(e, Dice.roll(2, 6, GameState.mod("CHA")), 6.0, "phys")


# --- Transe (contrôle) --------------------------------------------------------------

func _cast_solo_endiable() -> bool:
	in_frenzy = true
	hero.model.solo_pose(true)
	var notes := FRENZY_NOTES_MASTER if GameState.has_talent("maitre_tempo") else FRENZY_NOTES
	Events.notify("SOLO ENDIABLÉ ! Ne ratez aucune note — touches 1 2 3 4", Color(0.85, 0.6, 1.0))
	Events.solo_requested.emit("endiable", notes)
	return true


func _on_solo_note_hit(mode: String, _hits: int) -> void:
	if mode != "endiable" or not in_frenzy:
		return
	Sfx.play("zap", -16.0)
	if GameState.has_talent("maitre_tempo"):
		for e in hero.enemies():
			if e.is_in_trance():
				hero.hit_enemy(e, Dice.roll(1, 6, GameState.mod("CHA")), 0.0, "sound")


func _on_solo_finished(mode: String, hits: int, total: int) -> void:
	if mode != "endiable" or not in_frenzy:
		return
	in_frenzy = false
	hero.model.solo_pose(false)
	for n in get_tree().get_nodes_in_group("enemies"):
		var e := n as Enemy
		if e != null:
			e.exit_trance()
	if hits >= total:
		Events.notify("TRANSE TOTALE ! (%d/%d)" % [hits, total], Events.COLOR_GOLD)
	else:
		Sfx.play("dud", -4.0)
		Events.notify("Fausse note : la transe se brise (%d/%d)" % [hits, total], Events.COLOR_BAD)


func _cast_growl() -> bool:
	hero.model.strum()
	var ring := Shockwave.new()
	ring.position = hero.global_position + Vector3(0, 0.4, 0)
	ring.radius = 6.0
	hero.get_parent().add_child(ring)
	Sfx.play("croak", 2.0, 0.0)
	Sfx.play("boom", -4.0)
	Events.camera_shake.emit(0.25, 0.5)
	Events.screen_flash.emit(Color(0.4, 0.0, 0.1, 0.25), 0.4)
	for e in hero.enemies():
		if _flat(e.global_position, hero.global_position) <= 6.0 + e.radius:
			e.fear(3.5)
	return true


# --- Thrash (destruction) --------------------------------------------------------------

func _cast_enceinte() -> bool:
	var pos := hero.aim_point
	var dir := pos - hero.global_position
	dir.y = 0.0
	if dir.length() > 8.0:
		pos = hero.global_position + dir.normalized() * 8.0
	pos.y = 0.0
	hero.model.strum()
	_run_speaker(pos)
	return true


func _run_speaker(pos: Vector3) -> void:
	var level := hero.get_parent()
	var speaker := Node3D.new()
	speaker.position = pos
	level.add_child(speaker)
	var cab := Visuals.mat(Color(0.05, 0.05, 0.05), 0.5)
	Visuals.box(speaker, Vector3(1.0, 1.4, 0.7), Vector3(0, 0.7, 0), cab)
	var cone_mat := Visuals.mat(Color(0.15, 0.13, 0.12), 0.8)
	var cones: Array[MeshInstance3D] = []
	for k in 2:
		cones.append(Visuals.cylinder(speaker, 0.28, 0.28, 0.04, Vector3(0, 0.4 + k * 0.6, 0.36), cone_mat, Vector3(90, 0, 0), 20))
	Visuals.box(speaker, Vector3(1.02, 0.1, 0.72), Vector3(0, 1.42, 0), Visuals.glow_mat(Color(1.0, 0.3, 0.1), 2.0))
	speaker.rotation.y = atan2(hero.global_position.x - pos.x, hero.global_position.z - pos.z) + PI
	speaker.scale = Vector3.ONE * 0.05
	speaker.create_tween().tween_property(speaker, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK)
	Sfx.play("thud", -2.0)
	for pulse in 6:
		await get_tree().create_timer(1.0, false).timeout
		if not is_instance_valid(speaker) or not is_instance_valid(hero):
			return
		for c in cones:
			c.scale = Vector3(1.3, 1.3, 1.3)
			c.create_tween().tween_property(c, "scale", Vector3.ONE, 0.25)
		Shockwave.spawn(level, pos, 4.0)
		Sfx.play("boom", -8.0, 0.1)
		for e in hero.enemies():
			if _flat(e.global_position, pos) <= 4.0 + e.radius:
				hero.hit_enemy(e, Dice.roll(1, 8, GameState.mod("CHA")), 2.0, "sound", pos)
	var tw := speaker.create_tween()
	tw.tween_property(speaker, "scale", Vector3(1.0, 0.02, 1.0), 0.3)
	tw.tween_callback(speaker.queue_free)


func _cast_pyrotechnie() -> bool:
	hero.model.strum()
	_run_pyro(hero.global_position)
	return true


func _run_pyro(center: Vector3) -> void:
	var level := hero.get_parent()
	var spots: Array[Vector3] = []
	for k in 6:
		var a := TAU * k / 6.0 + hero.model.rotation.y
		spots.append(center + Vector3(cos(a), 0, sin(a)) * 3.0)
	for p in spots:
		Telegraph.spawn(level, p, 1.6, 0.8)
	Sfx.play("portal", -10.0, 0.0)
	await get_tree().create_timer(0.8, false).timeout
	if not is_instance_valid(hero):
		return
	Sfx.play("thunder", -4.0)
	Events.camera_shake.emit(0.35, 0.5)
	for p in spots:
		_fire_column(level, p)
		for e in hero.enemies():
			if _flat(e.global_position, p) <= 1.6 + e.radius:
				hero.hit_enemy(e, Dice.roll(4, 6, 0), 1.5, "fire", p)


func _fire_column(level: Node, pos: Vector3) -> void:
	var col := Node3D.new()
	col.position = pos
	level.add_child(col)
	var flame := Visuals.cylinder(col, 0.35, 0.6, 4.0, Vector3(0, 2.0, 0), Visuals.glow_mat(Color(1.0, 0.45, 0.1), 5.0), Vector3.ZERO, 12)
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var light := OmniLight3D.new()
	light.position.y = 1.5
	light.light_color = Color(1.0, 0.55, 0.2)
	light.light_energy = 5.0
	light.omni_range = 6.0
	col.add_child(light)
	col.scale = Vector3(1.0, 0.05, 1.0)
	var tw := col.create_tween()
	tw.tween_property(col, "scale", Vector3.ONE, 0.12)
	tw.tween_interval(0.35)
	tw.tween_property(col, "scale", Vector3(0.1, 1.2, 0.1), 0.35)
	tw.tween_callback(col.queue_free)


# --- Utilitaires ---------------------------------------------------------------------

func _heal(amount: int, display: bool = true) -> void:
	if amount <= 0 or hero.dead:
		return
	GameState.heal_hero(amount)
	if display:
		DamageNumber.spawn(hero.get_parent(), hero.global_position + Vector3(0, 2.3, 0), "+%d" % amount, Events.COLOR_GOOD)


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _particles(color: Color, amount: int, lifetime: float, radius: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius
	p.gravity = Vector3(0, 2.0, 0)
	p.initial_velocity_min = 0.2
	p.initial_velocity_max = 0.8
	var m := SphereMesh.new()
	m.radius = 0.05
	m.height = 0.1
	m.material = Visuals.glow_mat(color, 3.0)
	p.mesh = m
	return p


func _burst(pos: Vector3, color: Color, amount: int) -> void:
	var p := _particles(color, amount, 1.2, 0.6)
	p.position = pos + Vector3(0, 1.0, 0)
	p.one_shot = true
	p.explosiveness = 0.7
	hero.get_parent().add_child(p)
	p.emitting = true
	get_tree().create_timer(2.0).timeout.connect(p.queue_free)


## Autres membres du groupe à portée (hors héros) : cible amicale, et plus tard les
## joueurs en coopération. Tout nœud du groupe « allies » ayant receive_heal().
func _allies_near(center: Vector3, radius: float) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for n in get_tree().get_nodes_in_group("allies"):
		var ally := n as Node3D
		if ally != null and ally.has_method("receive_heal") and _flat(ally.global_position, center) <= radius:
			out.append(ally)
	return out


## Soin de groupe en pourcentage des PV max de chacun (héros compris s'il est dans la zone).
func _heal_group(center: Vector3, radius: float, ratio: float) -> void:
	if _flat(hero.global_position, center) <= radius:
		_heal(roundi(GameState.max_hp() * ratio))
	for ally in _allies_near(center, radius):
		ally.call("receive_heal", maxi(1, roundi(float(ally.get("max_hp")) * ratio)))
