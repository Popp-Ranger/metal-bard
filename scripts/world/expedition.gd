class_name Expedition
extends "res://scripts/world/dungeon.gd"
## Chapitre 3 (quête « labyrinthe_destin ») : l'expédition vers le Labyrinthe du Destin, en cinq niveaux qui se
## suivent. Chacun est un donjon généré (et gardé tel quel jusqu'à ce qu'on le termine, comme les autres donjons de
## quête) ; son boss vaincu, un portail d'Ozz mène au niveau suivant :
##   1. La prairie au pied de la montagne (gobelins ; au bout, une bande de gobelins garde le sentier) ;
##   2. Les flancs de la montagne (gobelins, élémentaires de roche ; boss : le Bigfoot) ;
##   3. Les grottes des gobelins, dans la montagne (campements ; boss : le troll des cavernes) ;
##   4. Le col de la montagne : pas de murs, des précipices (élémentaires ; boss : l'élémentaire de glace colossal) ;
##   5. Le Labyrinthe du Destin : un vrai labyrinthe de glace (DungeonGenerator.generate_maze), élémentaires de glace
##      et de roche ; au centre de son arène, le Minotaure, qui impose un duel de guitare à 5 % de PV.
## L'avancée est gardée dans les drapeaux de la quête (QuestDB, « stages ») : on reprend au niveau atteint.

const STAGES := [
	{"flag": "destin_prairie", "name": "La Prairie du Pied-de-Mont", "theme": "prairie", "rooms": 7, "enemy_level": 3},
	{"flag": "destin_bigfoot", "name": "Les Flancs de la Montagne", "theme": "montagne", "rooms": 8, "enemy_level": 4},
	{"flag": "destin_troll", "name": "Les Grottes des Gobelins", "theme": "grotte", "rooms": 9, "enemy_level": 4},
	{"flag": "destin_col", "name": "Le Col du Destin", "theme": "col", "rooms": 8, "enemy_level": 5},
	{"flag": "", "name": "Le Labyrinthe du Destin", "theme": "labyrinthe", "enemy_level": 5},
]
const QUEST := "labyrinthe_destin"
## Taille du labyrinthe (en cases de 6 m : allée de 4 m et mur de 2 m).
const MAZE_SIZE := 14
## Le duel contre le Minotaure : au moins 80 % de notes justes.
const DUEL_PASS := 0.8

## Niveau de l'expédition (0 à 4, voir STAGES).
var stage := 0
var stage_boss: Enemy
var minotaur: Minotaur
var _stage_exit: Portal


## Niveau atteint : le premier dont le drapeau n'est pas encore levé (4 = le labyrinthe).
static func current_stage() -> int:
	for i in STAGES.size() - 1:
		if not bool(GameState.flags.get(str(STAGES[i]["flag"]), false)):
			return i
	return STAGES.size() - 1


static func stage_name(i: int) -> String:
	return str(STAGES[clampi(i, 0, STAGES.size() - 1)]["name"])


func _ready() -> void:
	stage = current_stage()
	super._ready()
	_outdoor_light()
	Events.solo_finished.connect(_on_duel_finished)


func _dungeon_config() -> Dictionary:
	return STAGES[stage]


func _generate(seed_value: int, cfg: Dictionary) -> int:
	match theme:
		"labyrinthe":
			gen.generate_maze(seed_value, MAZE_SIZE, MAZE_SIZE, 6)
			return seed_value
		"col":
			gen.corridor_width = 2 # de simples sentiers entre les précipices
	return super._generate(seed_value, cfg)


func _environment_kind() -> String:
	match theme:
		"prairie", "montagne":
			return "day"
		"col", "labyrinthe":
			return "snow"
	return "cave"


func _arrival_notice() -> void:
	match theme:
		"prairie":
			Events.notify("La prairie au pied de la montagne. Là-haut, quelque part : le Labyrinthe du Destin...", Color(0.75, 0.9, 0.6))
		"montagne":
			Events.notify("Les flancs de la montagne. Des empreintes énormes dans la boue... et une odeur de fauve.", Color(0.9, 0.8, 0.65))
		"grotte":
			Events.notify("Les grottes des gobelins : ça ricane dans le noir. Ça sent le rat grillé.", Color(0.65, 0.85, 0.5))
		"col":
			Events.notify("Le col du Destin. Pas de murs ici : juste le vide. Ne regardez pas en bas.", Color(0.75, 0.85, 1.0))
		"labyrinthe":
			Events.notify("Le Labyrinthe du Destin. Des murs de glace à perte de vue... et, quelque part au centre, un mugissement.", Color(0.7, 0.85, 1.0))


## Soleil (plein air), neige qui tombe autour du héros (col, labyrinthe).
func _outdoor_light() -> void:
	if theme != "grotte":
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-52, -35, 0)
		sun.light_color = Color(1.0, 0.95, 0.85) if theme in ["prairie", "montagne"] else Color(0.85, 0.9, 1.0)
		sun.light_energy = 1.1 if theme in ["prairie", "montagne"] else 0.85
		sun.shadow_enabled = true
		sun.directional_shadow_max_distance = 45.0
		add_child(sun)
	if theme in ["col", "labyrinthe"] and hero != null:
		var snow := CPUParticles3D.new()
		snow.position = Vector3(0, 9.0, 0)
		snow.amount = 220 if theme == "col" else 140
		snow.lifetime = 4.0
		snow.preprocess = 4.0
		snow.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		snow.emission_box_extents = Vector3(16, 0.5, 16)
		snow.direction = Vector3(1, -0.3, 0.2)
		snow.spread = 15.0
		snow.gravity = Vector3(1.5 if theme == "col" else 0.3, -2.5, 0)
		snow.initial_velocity_min = 0.5
		snow.initial_velocity_max = 2.0 if theme == "col" else 0.8
		var flake := SphereMesh.new()
		flake.radius = 0.035
		flake.height = 0.07
		flake.material = Visuals.mat(Color(1, 1, 1), 1.0)
		snow.mesh = flake
		snow.local_coords = false
		hero.add_child(snow)


func _floor_color(_cell: Vector2i, v: float) -> Color:
	match theme:
		"prairie":
			return Color(0.78 * v, 0.84 * v, 0.7 * v)
		"montagne":
			return Color(0.8 * v, 0.8 * v, 0.76 * v)
		"grotte":
			return Color(0.4 * v, 0.39 * v, 0.38 * v)
		"col":
			return Color(0.7 * v, 0.74 * v, 0.82 * v)
	return Color(0.74 * v, 0.8 * v, 0.9 * v)


# --- Géométrie ----------------------------------------------------------------------------------

func _build_floor() -> void:
	super._build_floor()
	# Au-delà des bords : la prairie (ou la montagne, la neige) continue ; dans le col, le vide.
	match theme:
		"prairie":
			_under.material_override = Visuals.textured("herbe", 4.0, Color(0.35, 0.42, 0.28))
		"montagne":
			_under.material_override = Visuals.textured("falaise", 4.0, Color(0.42, 0.4, 0.38))
		"labyrinthe":
			_under.material_override = Visuals.textured("neige", 6.0, Color(0.6, 0.66, 0.75))
		"col":
			_under.visible = false
			_build_precipices()


## Col : chaque case du bord du sentier tombe à pic (falaise de 18 m), la vallée est loin en dessous, dans la brume.
func _build_precipices() -> void:
	var edges: Array[Vector2i] = []
	for y in gen.height:
		for x in gen.width:
			if not gen.is_floor(x, y):
				continue
			if not (gen.is_floor(x + 1, y) and gen.is_floor(x - 1, y) and gen.is_floor(x, y + 1) and gen.is_floor(x, y - 1)):
				edges.append(Vector2i(x, y))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var block := BoxMesh.new()
	block.size = Vector3(CELL, 18.0, CELL)
	mm.mesh = block
	mm.instance_count = edges.size()
	for i in edges.size():
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, cell_to_world(edges[i]) + Vector3(0, -9.2, 0)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = Visuals.textured("falaise", 4.0, Color(0.5, 0.52, 0.58))
	add_child(mmi)
	var size := Vector3(gen.width * CELL + 200.0, 0.2, gen.height * CELL + 200.0)
	Visuals.box(self, size, _grid_origin() + Vector3(gen.width * CELL * 0.5, -34.0, gen.height * CELL * 0.5),
		Visuals.textured("neige", 10.0, Color(0.55, 0.6, 0.7)))


func _build_walls() -> void:
	super._build_walls()
	match theme:
		"prairie":
			_wall_mmi.visible = false
			_hedges()
		"col":
			_wall_mmi.visible = false # rien ne retient le héros... à part le bon sens (et une barrière invisible)


## Prairie : haies de buissons sur le pourtour, et des arbres derrière les salles (côté opposé à la caméra : ils ne
## cachent jamais le héros).
func _hedges() -> void:
	var bushes: Array[Transform3D] = []
	var trunks: Array[Transform3D] = []
	var crowns: Array[Transform3D] = []
	for y in gen.height:
		for x in gen.width:
			if not gen.is_wall(x, y):
				continue
			var p := cell_to_world(Vector2i(x, y))
			var back := gen.is_floor(x, y + 1) or gen.is_floor(x + 1, y)
			if back and _rng.randf() < 0.55:
				var h := _rng.randf_range(3.5, 5.5)
				trunks.append(Transform3D(Basis.from_scale(Vector3(1.0, h * 0.5, 1.0)), p + Vector3(0, h * 0.25, 0)))
				crowns.append(Transform3D(Basis.from_scale(Vector3.ONE * h * 0.42), p + Vector3(_rng.randf_range(-0.3, 0.3), h * 0.68, _rng.randf_range(-0.3, 0.3))))
			for k in 2:
				var s := _rng.randf_range(0.8, 1.25)
				bushes.append(Transform3D(Basis.from_euler(Vector3(0, _rng.randf() * TAU, 0)).scaled(Vector3(s, s * 0.8, s)),
					p + Vector3(_rng.randf_range(-0.5, 0.5), 0.45 * s, _rng.randf_range(-0.5, 0.5))))
	var leaf := SphereMesh.new()
	leaf.radius = 0.85
	leaf.height = 1.7
	leaf.radial_segments = 10
	leaf.rings = 6
	_multimesh(leaf, bushes, Visuals.mat(Color(0.2, 0.34, 0.12), 0.9), true)
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.16
	trunk.bottom_radius = 0.24
	trunk.height = 1.0
	_multimesh(trunk, trunks, Visuals.mat(Color(0.25, 0.16, 0.09), 0.9))
	var crown := SphereMesh.new()
	crown.radius = 0.5
	crown.height = 1.0
	_multimesh(crown, crowns, Visuals.mat(Color(0.2, 0.36, 0.13), 0.9), true)


## Instances d'un même maillage (nuancées au hasard si `tint`).
func _multimesh(mesh: Mesh, xforms: Array[Transform3D], material: StandardMaterial3D, tint: bool = false) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = tint
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		if tint:
			var k := _rng.randf_range(0.8, 1.15)
			mm.set_instance_color(i, Color(k, k * _rng.randf_range(0.95, 1.05), k))
	if tint:
		material = material.duplicate() as StandardMaterial3D # (matériau partagé : on ne le modifie pas)
		material.vertex_color_use_as_albedo = true
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = material
	add_child(mmi)


## Ni portes ni salles cachées : on est dehors (ou dans des grottes ouvertes).
func _build_doors() -> void:
	pass


func _build_room_covers() -> void:
	for i in gen.rooms.size():
		_state_add("rooms", i)


# --- Décor ----------------------------------------------------------------------------------------

func _decorate() -> void:
	if theme == "grotte":
		_place_torches()
	for i in gen.rooms.size():
		if i == gen.start_room:
			continue
		var boss_room := i == gen.boss_room
		match theme:
			"prairie":
				for k in _rng.randi_range(3, 5):
					MountainDecor.flowers(self, _decor_spot(i), _rng)
				for k in _rng.randi_range(3, 6):
					MountainDecor.grass_tuft(self, _decor_spot(i), _rng)
				if not boss_room:
					for k in _rng.randi_range(1, 2):
						MountainDecor.boulder(self, _decor_spot(i), _rng.randf_range(0.5, 0.9), _rng)
					MountainDecor.bush(self, _decor_spot(i), _rng)
					if _rng.randf() < 0.5:
						MountainDecor.tree(self, _decor_spot(i), _rng, _rng.randf_range(3.5, 5.0))
			"montagne":
				for k in _rng.randi_range(2, 3):
					MountainDecor.snow_patch(self, _decor_spot(i), _rng)
				if not boss_room:
					for k in _rng.randi_range(2, 3):
						MountainDecor.boulder(self, _decor_spot(i), _rng.randf_range(0.5, 1.0), _rng)
					MountainDecor.tree(self, _decor_spot(i), _rng, _rng.randf_range(3.5, 5.0), true)
					if _rng.randf() < 0.5:
						MountainDecor.cairn(self, _decor_spot(i), _rng)
			"grotte":
				for k in _rng.randi_range(1, 3):
					MountainDecor.glow_mushrooms(self, _decor_spot(i), _rng)
				if not boss_room:
					for k in _rng.randi_range(1, 3):
						MountainDecor.stalagmite(self, _decor_spot(i), _rng)
					if _rng.randf() < 0.5:
						MountainDecor.crystals(self, _decor_spot(i), _rng, Color(0.7, 0.35, 1.0))
					if _rng.randf() < 0.6:
						_goblin_camp(i)
			"col":
				for k in _rng.randi_range(2, 4):
					MountainDecor.snow_patch(self, _decor_spot(i), _rng)
				if not boss_room:
					MountainDecor.boulder(self, _decor_spot(i), _rng.randf_range(0.5, 0.9), _rng, Color(0.6, 0.62, 0.68), true)
					if _rng.randf() < 0.6:
						var a := _decor_spot(i)
						var dir := Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)).normalized()
						var b := a + dir * _rng.randf_range(4.0, 6.0)
						if is_walkable(b):
							MountainDecor.prayer_flags(self, a, b, _rng)
			"labyrinthe":
				MountainDecor.snow_patch(self, _decor_spot(i), _rng)
				if not boss_room:
					MountainDecor.crystals(self, _decor_spot(i), _rng, Color(0.45, 0.8, 1.0))
					if _rng.randf() < 0.6:
						MountainDecor.frozen_adventurer(self, _decor_spot(i), _rng)


## Point au hasard dans une salle, loin des bords (et du centre de l'arène du boss).
func _decor_spot(room: int) -> Vector3:
	for attempt in 8:
		var p := cell_to_world(gen.random_cell_in_room(room, 2)) + Vector3(_rng.randf_range(-0.6, 0.6), 0, _rng.randf_range(-0.6, 0.6))
		if room != gen.boss_room or p.distance_to(cell_to_world(gen.center(room))) > 6.0:
			return p
	return cell_to_world(gen.random_cell_in_room(room, 1))


## Campement de gobelins : feu de camp au centre de la salle, deux tentes, des os.
func _goblin_camp(room: int) -> void:
	var c := cell_to_world(gen.center(room))
	MountainDecor.campfire(self, c)
	for k in 2:
		var a := _rng.randf() * TAU
		var p := c + Vector3(cos(a), 0, sin(a)) * 4.0
		if is_walkable(p + Vector3(cos(a), 0, sin(a)) * 1.2):
			MountainDecor.tent(self, p, atan2(-cos(a), -sin(a)), _rng)
	DungeonDecor.bones(self, c + Vector3(1.4, 0, -0.8), _rng)


# --- Ennemis ----------------------------------------------------------------------------------------

func _spawn_enemies() -> void:
	for i in gen.rooms.size():
		if i == gen.boss_room or i == gen.start_room:
			continue
		var count := _coop_count(_rng.randi_range(4, 6) if theme == "grotte" else _rng.randi_range(3, 5))
		for k in count:
			_spawn_local(cell_to_world(gen.random_cell_in_room(i, 2)), i)
	if theme == "labyrinthe":
		# Des rôdeurs dans les allées du labyrinthe (éveillés : on tombe dessus au détour d'un mur).
		for k in _coop_count(10):
			var c := Vector2i(_rng.randi_range(0, gen.width - 1), _rng.randi_range(0, gen.height - 1))
			var tries := 0
			while (not gen.is_floor(c.x, c.y) or _room_at(cell_to_world(c)) >= 0) and tries < 200:
				c = Vector2i(_rng.randi_range(0, gen.width - 1), _rng.randi_range(0, gen.height - 1))
				tries += 1
			if tries < 200:
				_spawn_local(cell_to_world(c), -2)


## Un ennemi du coin, selon le niveau : gobelins en bas, élémentaires en haut.
func _spawn_local(pos: Vector3, room: int) -> Enemy:
	var roll := _rng.randf()
	match theme:
		"prairie":
			return _spawn_goblin(pos, room) if roll < 0.85 else _spawn_rock(pos, room)
		"montagne":
			return _spawn_goblin(pos, room) if roll < 0.55 else _spawn_rock(pos, room)
		"grotte":
			return _spawn_goblin(pos, room) if roll < 0.9 else _spawn_rock(pos, room)
		"col":
			if roll < 0.55:
				return _spawn_ice(pos, room)
			return _spawn_rock(pos, room) if roll < 0.8 else _spawn_goblin(pos, room)
	return _spawn_ice(pos, room) if roll < 0.6 else _spawn_rock(pos, room)


func _spawn_goblin(pos: Vector3, room: int = -1) -> Goblin:
	var e := Goblin.new()
	e.weapon = _rng.randi() % 3
	return _setup_enemy(e, pos, room) as Goblin


func _spawn_rock(pos: Vector3, room: int = -1) -> RockElemental:
	return _setup_enemy(RockElemental.new(), pos, room) as RockElemental


func _spawn_ice(pos: Vector3, room: int = -1) -> IceElemental:
	return _setup_enemy(IceElemental.new(), pos, room) as IceElemental


func _setup_enemy(e: Enemy, pos: Vector3, room: int) -> Enemy:
	e.level = enemy_level
	e.position = pos
	e.rotation.y = _rng.randf() * TAU
	e.walkable_check = is_walkable
	return _place_enemy(e, room)


## Renfort appelé par un boss : déjà en chasse.
func _spawn_minion_goblin(pos: Vector3) -> void:
	var e := _spawn_goblin(pos if is_walkable(pos) else cell_to_world(gen.center(gen.boss_room)))
	e.call_deferred("_aggro")


func _spawn_minion_ice(pos: Vector3) -> void:
	var e := _spawn_ice(pos if is_walkable(pos) else cell_to_world(gen.center(gen.boss_room)))
	e.call_deferred("_aggro")


# --- Boss et passage au niveau suivant ------------------------------------------------------------

const BOSS_IDS := {"montagne": "bigfoot", "grotte": "troll", "col": "elementaire_glace", "labyrinthe": "minotaure"}


func _spawn_boss_room() -> void:
	var c := cell_to_world(gen.center(gen.boss_room))
	Events.boss_defeated.connect(_on_stage_boss_defeated)
	if theme == "prairie":
		# Au bout de la prairie, une bande de gobelins garde le sentier qui monte vers la montagne.
		for k in _coop_count(7):
			_spawn_goblin(c + Vector3(_rng.randf_range(-4, 4), 0, _rng.randf_range(-4, 4)), gen.boss_room)
		_spawn_rock(c + Vector3(0, 0, 2.0), gen.boss_room)
		MountainDecor.cairn(self, c + Vector3(-3.0, 0, -5.0), _rng)
		Visuals.label(self, "↑ Montagne du Destin", c + Vector3(-3.0, 2.0, -5.0), Color(0.95, 0.85, 0.6), 34)
		_spawn_stage_exit(c + Vector3(0, 0, -5.0))
		return
	if bool(_state.get("boss_dead", false)):
		if theme != "labyrinthe":
			_spawn_stage_exit(c)
		elif not GameState.quest_items.has("pick_du_destin"):
			Pickup.spawn(self, c, "quest", 0, "pick_du_destin")
		else:
			_spawn_ozz_portal(c + Vector3(2.0, 0, 2.0))
		return
	match theme:
		"montagne":
			var b := Bigfoot.new()
			stage_boss = b
		"grotte":
			# L'antre du troll : deux grands feux et des os partout.
			for s: float in [-1.0, 1.0]:
				MountainDecor.campfire(self, c + Vector3(7.0 * s, 0, -6.0))
			for k in 5:
				DungeonDecor.bones(self, c + Vector3(_rng.randf_range(-8, 8), 0, _rng.randf_range(-8, 8)), _rng)
			var t := CaveTroll.new()
			t.spawn_minion = _spawn_minion_goblin
			stage_boss = t
		"col":
			var ice := IceElemental.new()
			ice.colossal = true
			ice.spawn_minion = _spawn_minion_ice
			stage_boss = ice
		"labyrinthe":
			minotaur = Minotaur.new()
			minotaur.duel_requested = _start_duel
			stage_boss = minotaur
			for k in 6:
				var a := TAU * k / 6.0
				MountainDecor.crystals(self, c + Vector3(cos(a), 0, sin(a)) * 9.0, _rng, Color(0.45, 0.8, 1.0))
	stage_boss.level = enemy_level
	stage_boss.position = c
	stage_boss.rotation.y = PI * 0.25
	stage_boss.walkable_check = is_walkable
	add_child(stage_boss)
	_room_enemies[gen.boss_room] = [stage_boss]


func _on_stage_boss_defeated(boss_id: String) -> void:
	if boss_id != str(BOSS_IDS.get(theme, "")):
		return
	_state["boss_dead"] = true
	if hero != null:
		hero.model.victory()
	match theme:
		"labyrinthe":
			Events.notify("Le Minotaure s'effondre. Sur son corps, un médiator d'or noir bourdonne tout seul...", Events.COLOR_GOLD)
		_:
			Events.notify("%s est vaincu ! Ozz ouvre un portail vers la suite..." % stage_boss.display_name, Events.COLOR_GOLD)
			await get_tree().create_timer(1.5, false).timeout
			var p := cell_to_world(gen.center(gen.boss_room))
			if hero != null and is_walkable(hero.global_position + hero.facing * 2.0):
				p = hero.global_position + hero.facing * 2.0
			_spawn_stage_exit(p)


## Portail vers le niveau suivant de l'expédition.
func _spawn_stage_exit(p: Vector3) -> void:
	if _stage_exit != null and is_instance_valid(_stage_exit):
		return
	_stage_exit = Portal.new()
	_stage_exit.position = Vector3(p.x, 0.0, p.z)
	_stage_exit.prompt = ("Prendre le sentier : %s" if theme == "prairie" else "Portail d'Ozz : %s") % stage_name(stage + 1)
	_stage_exit.on_enter = _next_stage
	_stage_exit.target_scene = Router.EXPEDITION
	add_child(_stage_exit)


## Niveau terminé : le suivant sera un nouveau donjon.
func _next_stage() -> void:
	GameState.flags[str(STAGES[stage]["flag"])] = true
	GameState.dungeon_state = {}
	GameState.dungeon_seed = randi_range(1, 999999)
	GameState.town_portal = {}
	GameState.location = {"scene": Router.EXPEDITION}
	Events.quest_updated.emit(QUEST)
	GameState.save_game()


## Le Pick du Destin ramassé : objectif accompli, Ozz ouvre le portail du retour.
func _on_quest_item_added(id: String) -> void:
	if theme != "labyrinthe" or id != "pick_du_destin":
		return
	GameState.complete_objective(QUEST)
	var p := hero.global_position + hero.facing * 1.8 if hero != null else cell_to_world(gen.center(gen.boss_room))
	_spawn_ozz_portal(p if is_walkable(p) else cell_to_world(gen.center(gen.boss_room)))
	Events.notify("Le Pick du Destin est à vous ! Un portail d'Ozz s'ouvre : retour à la Chèvre Fringante.", Events.COLOR_MAGIC)


func _spawn_ozz_portal(p: Vector3) -> void:
	var portal := Portal.new()
	portal.position = Vector3(p.x, 0.0, p.z)
	portal.prompt = "Retourner à la taverne (portail d'Ozz)"
	portal.on_enter = _end_dungeon.bind("Le Pick du Destin est à vous !", true)
	add_child(portal)


# --- Duel de guitare contre le Minotaure ---------------------------------------------------------

## À 5 % de ses PV, le Minotaure sort sa guitare : il impose le duel (le héros, intouchable, l'écoute d'abord).
func _start_duel() -> void:
	if hero != null:
		hero.casting_solo = true # invincible pendant le duel
	Events.notify("Le Minotaure jette sa hache et sort une guitare !", Color(1.0, 0.55, 0.35))
	Events.dialogue_requested.emit("minotaure_duel")


func _on_story_action(action: String) -> void:
	if action != "duel":
		super._on_story_action(action)
		return
	await Events.dialogue_closed
	_launch_duel()


func _launch_duel() -> void:
	if hero == null or minotaur == null or not minotaur.dueling:
		return
	hero.casting_solo = true
	hero.planted = true
	hero.model.solo_pose(true)
	Events.notify("DUEL ! Tiens le solo du Minotaure : 80 % de notes justes. Touches 1 2 3 4 !", Events.COLOR_GOLD)
	Events.solo_requested.emit("duel", 0) # la partition vient du morceau (data/duel_minotaure.json)


## Résultat du duel : 80 % au moins, le Minotaure s'incline ; sinon il reprend des forces et le combat continue.
func _on_duel_finished(mode: String, hits: int, total: int) -> void:
	if mode != "duel":
		return
	if hero != null:
		hero.planted = false
		hero.casting_solo = false
		hero.model.solo_pose(false)
	if minotaur == null or not is_instance_valid(minotaur):
		return
	var ratio := float(hits) / maxf(1.0, float(total))
	Events.notify("Duel : %d / %d (%d %%) — il en fallait %d %%." % [hits, total, roundi(ratio * 100.0), roundi(DUEL_PASS * 100.0)],
		Events.COLOR_GOLD if ratio >= DUEL_PASS else Events.COLOR_BAD)
	if ratio >= DUEL_PASS:
		Sfx.play("solo_thunder", 0.0)
		Events.screen_flash.emit(Color(1.0, 0.9, 0.6, 0.5), 0.4)
		Events.notify("Le Minotaure lâche sa guitare, les oreilles en sang : « ...Respect. » Il s'effondre.", Events.COLOR_GOLD)
		minotaur.duel_result(true) # coopération : l'hôte l'applique pour tout le groupe
		return
	Sfx.play("solo_thunder", -2.0)
	Events.camera_shake.emit(0.35, 0.6)
	minotaur.duel_result(false)
	if hero != null:
		hero.take_hit(clampi(roundi(GameState.max_hp() * 0.25), 1, maxi(1, GameState.hp - 1)), minotaur.global_position, minotaur)
	Events.notify("Le Minotaure ricane : « Retourne accorder ta guitare ! » Il reprend des forces...", Events.COLOR_BAD)
