class_name SpellFx
extends RefCounted
## Effets visuels et sonores des sorts des joueurs, visibles par TOUS les joueurs d'une partie.
##
## Le lanceur appelle SpellFx.cast(héros, type, données) : l'effet est joué chez lui, puis
## envoyé aux autres joueurs (Net.send_spell_fx), qui le rejouent sur le personnage distant
## du lanceur (RemoteHero). Seule l'apparence est transmise : les dégâts restent calculés
## par le lanceur (et validés par l'hôte), les soins par chaque joueur.
## Chez les autres joueurs, le son baisse avec la distance.

const HEARING_RANGE := 35.0 # au-delà, on n'entend plus les sorts des autres
const PHOENIX_TIME := 8.0
const AMPS_TIME := 6.0
const SPEAKER_PULSES := 6


## Joue l'effet chez soi puis chez les autres joueurs.
static func cast(caster: Node3D, kind: String, data: Dictionary = {}) -> void:
	play(caster.get_parent(), caster, kind, data, false)
	broadcast(kind, data)


## Envoie l'effet aux autres joueurs seulement (le lanceur l'a déjà joué à sa façon).
static func broadcast(kind: String, data: Dictionary = {}) -> void:
	Net.send_spell_fx(kind, data)


static func play(level: Node, caster: Node3D, kind: String, data: Dictionary, remote: bool) -> void:
	if level == null:
		return
	var model: HeroModel = null
	if caster != null and is_instance_valid(caster):
		model = caster.get("model") as HeroModel
	match kind:
		"swing":
			if model != null:
				model.swing()
		"strum":
			if model != null:
				model.strum()
		"tuning":
			if model != null:
				model.strum()
			var pts: PackedVector3Array = data.get("points", PackedVector3Array())
			for i in pts.size() - 1:
				ArcBolt.spawn(level, pts[i], pts[i + 1])
			_sound(level, "zap", Balance.ZAP_VOLUME_DB, _first(pts), remote)
		"riff":
			if model != null:
				model.strum()
			var stack := int(data.get("stack", 1)) # n° de la note du mini-jeu (1 à 10)
			ArcBolt.spawn(level, data["from"], data["to"], 0.1 + 0.025 * stack, 0.25, data.get("color", Color(0.55, 0.85, 1.0)))
			# Volume réduit de 70 % (×0,3 ≈ -10,5 dB) : le riff couvrait tout le reste.
			_sound(level, "riff", -13.5 + stack * 0.2, data["from"], remote, 0.0)
		"riff_black":
			if model != null:
				model.strum()
			var notes := int(data.get("stack", 1))
			MistTrail.spawn(level, data["from"], data["to"], 0.1 + 0.02 * notes, data.get("color", Color(0.62, 0.3, 1.0)))
			_sound(level, "mist_wind", -9.0 + notes * 0.2, data["from"], remote, 0.05)
		"fireball":
			if model != null:
				model.strum()
			var balls := int(data.get("stack", 1))
			Fireball.spawn(level, data["from"], data["to"], 0.18 + 0.015 * balls)
			_sound(level, "fireball", -8.0 + balls * 0.2, data["from"], remote, 0.08)
		"bolt":
			ArcBolt.spawn(level, data["from"], data["to"], float(data.get("width", 0.12)), float(data.get("life", 0.3)),
				data.get("color", Color(0.55, 0.85, 1.0)))
		"wave":
			if model != null:
				model.act("area")
			Shockwave.spawn(level, data["pos"], float(data["radius"]))
			_sound(level, "wave", -2.0, data["pos"], remote, 0.0)
		"shockwave":
			Shockwave.spawn(level, data["pos"], float(data["radius"]))
			if data.has("sound"):
				_sound(level, str(data["sound"]), float(data.get("volume", 0.0)), data["pos"], remote)
		"storm":
			_storm(level, data, remote)
		"burst":
			var points: PackedVector3Array = data.get("points", PackedVector3Array())
			for p in points:
				burst(level, p, data.get("color", Color.WHITE), int(data.get("amount", 10)))
			if data.has("sound"):
				_sound(level, str(data["sound"]), float(data.get("volume", 0.0)), _first(points), remote, 0.0)
		"phoenix":
			if model != null:
				model.act("cast")
			var zone := phoenix_zone(level, data["pos"])
			zone.get_tree().create_timer(PHOENIX_TIME, false).timeout.connect(zone.queue_free)
			_sound(level, "portal", -6.0, data["pos"], remote)
		"shield":
			if remote and caster != null and caster.has_method("set_shield_visible"):
				caster.call("set_shield_visible", bool(data.get("on", false)))
			if bool(data.get("on", false)):
				if model != null:
					model.act("cast")
				_sound(level, "zap", -10.0, _pos(caster), remote)
				_sound(level, "boom", -14.0, _pos(caster), remote)
		"amps":
			if remote and caster != null:
				var amps := build_amps(caster)
				amps.get_tree().create_timer(AMPS_TIME, false).timeout.connect(amps.queue_free)
			if model != null:
				model.act("cast")
			_sound(level, "thud", -2.0, _pos(caster), remote)
		"wall_of_death":
			if model != null:
				model.swing()
			var origin: Vector3 = data["pos"]
			var dir: Vector3 = data["dir"]
			for k in 3:
				Shockwave.spawn(level, origin + dir * (1.5 + k * 2.0), 1.6 + k * 0.9)
			_sound(level, "boom", 0.0, origin, remote)
		"stage_dive":
			if remote and model != null:
				_remote_dive(model, level, data["to"])
			_sound(level, "swoosh", -2.0, data["from"], remote)
		"growl":
			if model != null:
				model.act("cast")
			var ring := Shockwave.new()
			ring.position = (data["pos"] as Vector3) + Vector3(0, 0.4, 0)
			ring.radius = 6.0
			level.add_child(ring)
			_sound(level, "croak", 2.0, data["pos"], remote, 0.0)
			_sound(level, "boom", -4.0, data["pos"], remote)
		"speaker":
			if model != null:
				model.act("cast")
			var sp := SpeakerFx.new()
			sp.position = data["pos"]
			sp.rotation.y = float(data.get("yaw", 0.0))
			sp.remote = remote
			level.add_child(sp)
		"pyro":
			if model != null:
				model.act("cast")
			var pyro := PyroFx.new()
			pyro.center = data["pos"]
			pyro.yaw = float(data.get("yaw", 0.0))
			pyro.remote = remote
			level.add_child(pyro)


# --- Sons ------------------------------------------------------------------------------

## Son d'un sort : plein volume chez le lanceur, atténué avec la distance chez les autres.
static func _sound(level: Node, id: String, volume_db: float, pos: Vector3, remote: bool, jitter: float = 0.05) -> void:
	if remote:
		var h := level.get_tree().get_first_node_in_group("hero") as Node3D
		if h != null:
			var d := Vector2(h.global_position.x - pos.x, h.global_position.z - pos.z).length()
			if d > HEARING_RANGE:
				return
			volume_db -= d * 0.35
	Sfx.play(id, volume_db, jitter)


static func _first(points: PackedVector3Array) -> Vector3:
	return points[0] if points.size() > 0 else Vector3.ZERO


static func _pos(n: Node3D) -> Vector3:
	return n.global_position if n != null and is_instance_valid(n) else Vector3.ZERO


# --- Effets partagés ---------------------------------------------------------------------

static func particles(color: Color, amount: int, lifetime: float, radius: float) -> CPUParticles3D:
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


## Gerbe d'étincelles (soins, Encore !).
static func burst(level: Node, pos: Vector3, color: Color, amount: int) -> void:
	var p := particles(color, amount, 1.2, 0.6)
	p.position = pos + Vector3(0, 1.0, 0)
	p.one_shot = true
	p.explosiveness = 0.7
	level.add_child(p)
	p.emitting = true
	p.get_tree().create_timer(2.0).timeout.connect(p.queue_free)


## Cercle de flammes de l'Hymne du Phénix.
static func phoenix_zone(level: Node, pos: Vector3) -> Node3D:
	var zone := Node3D.new()
	zone.position = pos
	level.add_child(zone)
	Visuals.torus(zone, 3.8, 4.0, Vector3(0, 0.05, 0), Visuals.glow_mat(Color(1.0, 0.7, 0.2), 3.0))
	Visuals.torus(zone, 1.8, 1.9, Vector3(0, 0.05, 0), Visuals.glow_mat(Color(1.0, 0.5, 0.1), 2.0))
	var flames := particles(Color(1.0, 0.6, 0.15), 60, 1.2, 3.8)
	flames.one_shot = false
	flames.emitting = true
	zone.add_child(flames)
	var light := Visuals.flicker_light(zone, Vector3(0, 1.5, 0), Color(1.0, 0.65, 0.3), 3.0, 8.0)
	light.flicker_amount = 0.3
	return zone


## Deux amplis qui surgissent de part et d'autre du joueur (Pile d'amplis).
static func build_amps(owner: Node3D) -> Node3D:
	var node := Node3D.new()
	owner.add_child(node)
	var cab := Visuals.mat(Color(0.06, 0.06, 0.06), 0.6)
	var grill := Visuals.mat(Color(0.18, 0.16, 0.14), 0.9)
	for side: float in [-1.0, 1.0]:
		var amp := Node3D.new()
		amp.position = Vector3(0.9 * side, 0, -0.3)
		node.add_child(amp)
		Visuals.box(amp, Vector3(0.6, 1.1, 0.4), Vector3(0, 0.55, 0), cab)
		for k in 2:
			Visuals.cylinder(amp, 0.13, 0.13, 0.02, Vector3(0, 0.33 + k * 0.42, 0.2), grill, Vector3(90, 0, 0), 16)
		Visuals.box(amp, Vector3(0.62, 0.12, 0.42), Vector3(0, 1.15, 0), Visuals.glow_mat(Color(0.9, 0.2, 0.1), 1.2))
		amp.scale = Vector3.ONE * 0.05
		amp.create_tween().tween_property(amp, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK)
	return node


## Bulle du Mur de Larsen.
static func shield_bubble(owner: Node3D, height_scale: float) -> MeshInstance3D:
	var bubble := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	bubble.mesh = sphere
	bubble.position.y = 1.0
	bubble.scale = Vector3(0.9, 1.15, 0.9) * height_scale
	bubble.material_override = Visuals.transparent_mat(Color(0.35, 0.65, 1.0, 0.18), 1.2)
	bubble.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	owner.add_child(bubble)
	return bubble


## Stage Diving d'un autre joueur : sa position suit le réseau, on ajoute le vol et l'atterrissage.
static func _remote_dive(model: HeroModel, level: Node, target: Vector3) -> void:
	model.dive(true)
	var tw := model.create_tween()
	tw.tween_method(func(k: float) -> void: model.position.y = sin(k * PI) * 2.5, 0.0, 1.0, 0.55).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void: SpellFx._dive_land(model, level, target))


static func _dive_land(model: HeroModel, level: Node, target: Vector3) -> void:
	model.position.y = 0.0
	model.dive(false)
	Shockwave.spawn(level, target, 4.0)
	_sound(level, "boom", 0.0, target, true)


## Emplacements des 6 colonnes de feu de la Pyrotechnie (mêmes chez tous les joueurs).
static func pyro_spots(center: Vector3, yaw: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for k in 6:
		var a := TAU * k / 6.0 + yaw
		out.append(center + Vector3(cos(a), 0, sin(a)) * 3.0)
	return out


## Pluie d'éclairs du Solo de la Foudre d'un autre joueur : mêmes cibles (identifiants réseau
## des ennemis), sans dégâts (ils sont appliqués par le lanceur et l'hôte).
static func _storm(level: Node, data: Dictionary, remote: bool) -> void:
	if not remote:
		return # le lanceur joue la vraie pluie d'éclairs (LightningStorm avec dégâts)
	var targets: Array[Enemy] = []
	for id in (data.get("ids", PackedInt32Array()) as PackedInt32Array):
		var e := Net.enemy_by_id(id)
		if e != null:
			targets.append(e)
	var storm := LightningStorm.new()
	storm.targets = targets
	storm.center = data.get("center", Vector3.ZERO)
	storm.visual_only = true
	level.add_child(storm)


# --- Effets qui durent ---------------------------------------------------------------------

## Enceinte de concert posée au sol : 6 impulsions (une par seconde), puis elle s'efface.
## Purement visuelle : les dégâts sont appliqués par le lanceur (TalentCaster).
class SpeakerFx extends Node3D:
	var remote := false
	var _cones: Array[MeshInstance3D] = []

	func _ready() -> void:
		var cab := Visuals.mat(Color(0.05, 0.05, 0.05), 0.5)
		Visuals.box(self, Vector3(1.0, 1.4, 0.7), Vector3(0, 0.7, 0), cab)
		var cone_mat := Visuals.mat(Color(0.15, 0.13, 0.12), 0.8)
		for k in 2:
			_cones.append(Visuals.cylinder(self, 0.28, 0.28, 0.04, Vector3(0, 0.4 + k * 0.6, 0.36), cone_mat, Vector3(90, 0, 0), 20))
		Visuals.box(self, Vector3(1.02, 0.1, 0.72), Vector3(0, 1.42, 0), Visuals.glow_mat(Color(1.0, 0.3, 0.1), 2.0))
		scale = Vector3.ONE * 0.05
		create_tween().tween_property(self, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK)
		SpellFx._sound(get_parent(), "thud", -2.0, global_position, remote)
		_run()

	func _run() -> void:
		for pulse in SpellFx.SPEAKER_PULSES:
			await get_tree().create_timer(1.0, false).timeout
			if not is_inside_tree():
				return
			for c in _cones:
				c.scale = Vector3(1.3, 1.3, 1.3)
				c.create_tween().tween_property(c, "scale", Vector3.ONE, 0.25)
			Shockwave.spawn(get_parent(), global_position, 4.0)
			SpellFx._sound(get_parent(), "boom", -8.0, global_position, remote, 0.1)
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector3(1.0, 0.02, 1.0), 0.3)
		tw.tween_callback(queue_free)


## Pyrotechnie : 6 zones marquées au sol autour du lanceur, puis colonnes de feu (0,8 s après).
class PyroFx extends Node3D:
	const DELAY := 0.8
	var center := Vector3.ZERO
	var yaw := 0.0
	var remote := false

	func spots() -> Array[Vector3]:
		return SpellFx.pyro_spots(center, yaw)

	func _ready() -> void:
		var level := get_parent()
		for p in spots():
			Telegraph.spawn(level, p, 1.6, DELAY)
		SpellFx._sound(level, "portal", -10.0, center, remote, 0.0)
		_run()

	func _run() -> void:
		await get_tree().create_timer(DELAY, false).timeout
		if not is_inside_tree():
			return
		var level := get_parent()
		SpellFx._sound(level, "thunder", -4.0, center, remote)
		for p in spots():
			_fire_column(level, p)
		queue_free()

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
