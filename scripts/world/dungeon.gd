extends Level
## Donjon procédural : construit la géométrie à partir du DungeonGenerator,
## peuple les salles de squelettes, place le boss, gère la fin de quête.

const CELL := 2.0
const WALL_HEIGHT := 2.6

var gen := DungeonGenerator.new()
var quest_id := ""
var enemy_level := 1
var boss: FrogBoss
var cub: OwlbearCub
var _cage_bars: Array[Node3D] = []
var _prison_bars: Array[Node3D] = []
var _cage_pos := Vector3.ZERO
var _prison_pos := Vector3.ZERO
var _cage_interact: Interactable
var _has_key := false
var _cage_open := false
var _wall_material: ShaderMaterial
var _rng := RandomNumberGenerator.new()
## État persistant (référence vers GameState.dungeon_state).
var _state := {}
## Portes : [{room, node, body, interact, leaves, locked, open}] (index = identifiant sauvegardé).
var doors: Array[Dictionary] = []
## Voile noir de chaque salle non découverte (index de salle -> MeshInstance3D).
var _covers := {}
## Décor et lumières de chaque salle non découverte, masqués jusqu'à l'ouverture.
var _hidden := {}
var _under: MeshInstance3D
var _room_enemies := {} # index de salle -> Array[Enemy]
var _enemy_uid := 0
var chief: Skeleton
var _town_portal: Portal
const DOOR_MAX_CELLS := 5 # au-delà, l'ouverture est trop large : pas de porte (côté ouvert)


func _ready() -> void:
	quest_id = GameState.active_quest if not GameState.active_quest.is_empty() else "plumeau"
	var cfg: Dictionary = QuestDB.get_quest(quest_id).get("dungeon", {})
	enemy_level = int(cfg.get("enemy_level", 1))
	var seed_value := GameState.dungeon_seed if GameState.dungeon_seed != 0 else randi_range(1, 999999)
	# La salle du boss est fermée à clé : on garde la première graine où toutes les autres
	# salles restent accessibles sans la traverser.
	seed_value = gen.generate_sealed(seed_value, int(cfg.get("rooms", 10)), DOOR_MAX_CELLS)
	GameState.dungeon_seed = seed_value
	_rng.seed = seed_value

	# Donjon persistant tant qu'il n'est pas terminé (ennemis tués, portes, clés...).
	var fresh := GameState.dungeon_state.is_empty()
	if fresh:
		GameState.dungeon_state = {"dead": [], "doors": [], "rooms": [], "chests": []}
		GameState.reset_run()
	_state = GameState.dungeon_state
	GameState.flags["in_dungeon"] = true
	setup_level("dungeon", str(cfg.get("name", "Donjon")))
	hud.show_kill_counter()
	_build_floor()
	_build_walls()
	_decorate()
	_build_doors()
	_spawn_enemies()
	_spawn_boss_room()
	_build_room_covers()
	var start := cell_to_world(gen.center(gen.start_room))
	_spawn_flee_portal(start + Vector3(-3.0, 0.0, -3.0))
	# Retour par le portail bleu : exactement là où on l'avait ouvert.
	var via_portal: bool = GameState.flags.get("via_town_portal", false)
	GameState.flags.erase("via_town_portal")
	var tp: Array = GameState.town_portal.get("pos", [])
	if via_portal and tp.size() == 2:
		start = Vector3(float(tp[0]), 0.0, float(tp[1])) + Vector3(0.0, 0.0, 1.4)
		GameState.town_portal = {} # le portail se referme derrière le héros
	elif tp.size() == 2:
		_spawn_town_portal(Vector3(float(tp[0]), 0.0, float(tp[1]))) # toujours ouvert depuis la dernière visite
	spawn_hero(start)
	_reveal_room_at(hero.global_position)
	Events.boss_defeated.connect(_on_boss_defeated)
	Events.story_action.connect(_on_story_action)
	Events.enemy_killed.connect(_on_enemy_killed)
	Events.town_portal_requested.connect(open_town_portal)
	Sfx.play_music("res://audio/music/dungeon_theme.mp3", -8.0) # musique du donjon
	if GameState.quest_state(quest_id) == QuestDB.State.ACTIVE:
		Events.notify("Trouvez Plumeau au fond des catacombes...", Events.COLOR_DEFAULT)


func _process(_delta: float) -> void:
	if hero != null and _wall_material != null:
		_wall_material.set_shader_parameter("hero_pos", hero.global_position)
	if hero != null:
		_reveal_room_at(hero.global_position) # salle sans porte (côté ouvert) : on la découvre en entrant


func cell_to_world(c: Vector2i) -> Vector3:
	return Vector3((c.x + 0.5) * CELL, 0.0, (c.y + 0.5) * CELL)


func world_to_cell(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / CELL), floori(p.z / CELL))


## Utilisé par les ennemis pour choisir des points d'errance valides.
func is_walkable(p: Vector3) -> bool:
	var margin := 0.5
	for offset: Vector3 in [Vector3(margin, 0, margin), Vector3(-margin, 0, margin),
			Vector3(margin, 0, -margin), Vector3(-margin, 0, -margin)]:
		var c := world_to_cell(p + offset)
		if not gen.is_floor(c.x, c.y):
			return false
	return true


# --- Géométrie ---------------------------------------------------------------

func _build_floor() -> void:
	var cells: Array[Vector2i] = []
	for y in gen.height:
		for x in gen.width:
			if gen.is_floor(x, y):
				cells.append(Vector2i(x, y))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	# 4 dalles de 1 m par case de 2 m, légèrement irrégulières.
	var tile := BoxMesh.new()
	tile.size = Vector3(CELL * 0.5 - 0.05, 0.2, CELL * 0.5 - 0.05)
	mm.mesh = tile
	mm.instance_count = cells.size() * 4
	var quarter := CELL * 0.25
	for i in cells.size():
		for k in 4:
			var off := Vector3(quarter if k % 2 == 1 else -quarter, 0, quarter if k >= 2 else -quarter)
			var p := cell_to_world(cells[i]) + off + Vector3(0, -0.1 + _rng.randf_range(-0.02, 0.02), 0)
			var basis := Basis(Vector3.UP, _rng.randf_range(-0.03, 0.03))
			mm.set_instance_transform(i * 4 + k, Transform3D(basis, p))
			var v := _rng.randf_range(0.8, 1.05)
			var col := Color(0.16 * v, 0.155 * v, 0.16 * v)
			if _rng.randf() < 0.1:
				col = col.lerp(Color(0.1, 0.17, 0.09), 0.6) # mousse
			mm.set_instance_color(i * 4 + k, col)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	Visuals.toon(mat)
	mmi.material_override = mat
	add_child(mmi)
	# Joints sombres entre les dalles.
	var under := Vector3(gen.width * CELL, 0.1, gen.height * CELL)
	_under = Visuals.box(self, under, Vector3(under.x * 0.5, -0.2, under.z * 0.5), Visuals.mat(Color(0.02, 0.02, 0.02)))


func _build_walls() -> void:
	var cells: Array[Vector2i] = []
	for y in gen.height:
		for x in gen.width:
			if gen.is_wall(x, y):
				cells.append(Vector2i(x, y))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var block := BoxMesh.new()
	block.size = Vector3(CELL, WALL_HEIGHT, CELL)
	mm.mesh = block
	mm.instance_count = cells.size()
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	var shape := BoxShape3D.new()
	shape.size = Vector3(CELL, WALL_HEIGHT, CELL)
	for i in cells.size():
		var p := cell_to_world(cells[i]) + Vector3(0, WALL_HEIGHT * 0.5, 0)
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, p))
		var col := CollisionShape3D.new()
		col.shape = shape
		col.position = p
		body.add_child(col)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	_wall_material = Visuals.stone_material(true)
	mmi.material_override = _wall_material
	add_child(mmi)


func _decorate() -> void:
	var wood := Visuals.mat(Color(0.25, 0.15, 0.08))
	var iron := Visuals.mat(Color(0.2, 0.2, 0.22), 0.4, 0.7)
	var bone := Visuals.mat(Color(0.75, 0.72, 0.6))
	var slime := Visuals.glow_mat(Color(0.35, 0.8, 0.25), 0.6)
	_place_torches()
	for i in gen.rooms.size():
		if i == gen.boss_room or i == gen.start_room:
			continue
		# Piles d'os, flaques de bave verte, piliers brisés, tonneaux.
		for k in _rng.randi_range(4, 7):
			var p := cell_to_world(gen.random_cell_in_room(i, 2)) + Vector3(_rng.randf_range(-0.6, 0.6), 0, _rng.randf_range(-0.6, 0.6))
			match _rng.randi_range(0, 3):
				0:
					for b in 5:
						Visuals.capsule(self, 0.04, 0.4, p + Vector3(_rng.randf_range(-0.4, 0.4), 0.05, _rng.randf_range(-0.4, 0.4)),
							bone, Vector3(90, _rng.randf_range(0, 180), 0))
					Visuals.sphere(self, 0.13, p + Vector3(0.2, 0.12, 0.1), bone)
				1:
					Visuals.cylinder(self, 0.7, 0.8, 0.02, p + Vector3(0, 0.02, 0), slime)
				2:
					Visuals.cylinder(self, 0.35, 0.4, 1.2, p + Vector3(0, 0.6, 0), _wall_material, Vector3(0, 0, 0), 8)
					Visuals.solid_cylinder(self, 0.4, 2.0, p + Vector3(0, 1.0, 0))
				_:
					Visuals.cylinder(self, 0.3, 0.3, 0.8, p + Vector3(0, 0.4, 0), wood)
					Visuals.torus(self, 0.28, 0.32, p + Vector3(0, 0.6, 0), iron)
					Visuals.solid_cylinder(self, 0.32, 1.0, p + Vector3(0, 0.5, 0))


# --- Torches -------------------------------------------------------------------

const TORCH_SPACING := 11.0 # distance minimale entre deux torches (m)

## Torches murales réparties sur tout le donjon (salles ET couloirs), bien espacées :
## elles éclairent des zones précises et laissent des passages dans la pénombre.
## Priorité aux murs du fond (nord / ouest), visibles depuis la caméra.
func _place_torches() -> void:
	var candidates: Array[Array] = []
	var dirs: Array[Vector2i] = [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 0)]
	for y in gen.height:
		for x in gen.width:
			if not gen.is_floor(x, y):
				continue
			for d in dirs:
				if gen.is_wall(x + d.x, y + d.y):
					candidates.append([Vector2i(x, y), d])
	# Mélange déterministe (même graine = mêmes torches).
	for i in range(candidates.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp: Array = candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = tmp
	var placed: Array[Vector3] = []
	for pass_index in 2:
		for cand in candidates:
			var cell: Vector2i = cand[0]
			var d: Vector2i = cand[1]
			var on_back_wall := d.y < 0 or d.x < 0
			if on_back_wall != (pass_index == 0):
				continue
			var p := cell_to_world(cell) + Vector3(d.x, 0, d.y) * (CELL * 0.5 - 0.08)
			var too_close := false
			for q in placed:
				if q.distance_to(p) < TORCH_SPACING:
					too_close = true
					break
			if too_close:
				continue
			placed.append(p)
			_torch(p, Vector3(d.x, 0, d.y), placed.size() <= 4)


func _torch(wall_pos: Vector3, wall_dir: Vector3, shadows: bool) -> void:
	var iron := Visuals.mat(Color(0.18, 0.17, 0.17), 0.4, 0.8)
	var torch := Node3D.new()
	torch.position = wall_pos
	torch.rotation.y = atan2(-wall_dir.x, -wall_dir.z) # +Z local = vers l'intérieur de la pièce
	add_child(torch)
	Visuals.box(torch, Vector3(0.22, 0.08, 0.06), Vector3(0, 1.75, 0.02), iron) # applique
	Visuals.box(torch, Vector3(0.05, 0.3, 0.05), Vector3(0, 1.85, 0.14), iron, Vector3(30, 0, 0))
	Visuals.cylinder(torch, 0.05, 0.035, 0.45, Vector3(0, 2.0, 0.22), Visuals.mat(Color(0.25, 0.14, 0.07)), Vector3(25, 0, 0), 8)
	Visuals.sphere(torch, 0.1, Vector3(0, 2.27, 0.33), Visuals.glow_mat(Color(1.0, 0.5, 0.12), 6.0), Vector3(1.0, 1.6, 1.0))
	Visuals.sphere(torch, 0.06, Vector3(0, 2.35, 0.33), Visuals.glow_mat(Color(1.0, 0.85, 0.4), 8.0), Vector3(1.0, 1.5, 1.0))
	var flame := CPUParticles3D.new()
	flame.position = Vector3(0, 2.35, 0.33)
	flame.amount = 10
	flame.lifetime = 0.5
	flame.gravity = Vector3(0, 1.5, 0)
	flame.initial_velocity_min = 0.1
	flame.initial_velocity_max = 0.3
	flame.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	flame.emission_sphere_radius = 0.05
	flame.scale_amount_min = 0.5
	flame.scale_amount_max = 1.0
	var spark := SphereMesh.new()
	spark.radius = 0.035
	spark.height = 0.07
	spark.material = Visuals.glow_mat(Color(1.0, 0.6, 0.2), 5.0)
	flame.mesh = spark
	torch.add_child(flame)
	var light := Visuals.flicker_light(torch, Vector3(0, 2.4, 0.8), Color(1.0, 0.6, 0.3), 3.2, 11.0, shadows)
	light.flicker_amount = 0.2

# --- Population ----------------------------------------------------------------

func _spawn_enemies() -> void:
	# Salle voisine du boss : le chef des squelettes y monte la garde, avec la clé du boss.
	var captain_room := -1
	var best := INF
	for i in gen.rooms.size():
		if i == gen.boss_room or i == gen.start_room or gen.ambush_rooms.has(i):
			continue
		var d := Vector2(gen.center(i)).distance_to(Vector2(gen.center(gen.boss_room)))
		if d < best:
			best = d
			captain_room = i
	for i in gen.rooms.size():
		if i == gen.boss_room or i == gen.start_room:
			continue
		if gen.ambush_rooms.has(i):
			_spawn_ambush(i)
			continue
		var count := _coop_count(_rng.randi_range(2, 4))
		for k in count:
			_spawn_skeleton(cell_to_world(gen.random_cell_in_room(i, 2)), false, i)
		# Premier donjon : des rats grouillent un peu partout.
		if enemy_level <= 1:
			for k in _coop_count(_rng.randi_range(1, 3)):
				_spawn_rat(cell_to_world(gen.random_cell_in_room(i, 1)), i)
		if i == captain_room:
			chief = _spawn_skeleton(cell_to_world(gen.center(i)), true, i, true)
	# Chef déjà vaincu lors d'une visite précédente : sa clé attend peut-être encore au sol.
	var key_pos: Array = _state.get("boss_key_pos", [])
	if chief == null and not bool(_state.get("boss_key", false)) and key_pos.size() == 2:
		_spawn_boss_key(Vector3(float(key_pos[0]), 0.0, float(key_pos[1])))


## Salle cul-de-sac : une douzaine de squelettes (dont 2 capitaines) gardent un coffre.
func _spawn_ambush(room: int) -> void:
	for k in _coop_count(12):
		_spawn_skeleton(cell_to_world(gen.random_cell_in_room(room, 1)), k < 2, room)
	var chest_id := gen.ambush_rooms.find(room)
	var already_open := _state_has("chests", chest_id)
	var c := cell_to_world(gen.center(room))
	var chest := Node3D.new()
	chest.position = c
	add_child(chest)
	var wood := Visuals.mat(Color(0.35, 0.2, 0.1), 0.7)
	var gold := Visuals.mat(Color(0.85, 0.65, 0.2), 0.3, 0.9)
	Visuals.box(chest, Vector3(1.1, 0.6, 0.7), Vector3(0, 0.3, 0), wood)
	var lid := Visuals.box(chest, Vector3(1.15, 0.2, 0.75), Vector3(0, 0.7, 0), wood)
	for x: float in [-0.4, 0.4]:
		Visuals.box(chest, Vector3(0.08, 0.82, 0.78), Vector3(x, 0.41, 0), gold)
	var shine := OmniLight3D.new()
	shine.position = Vector3(0, 1.0, 0)
	shine.light_color = Color(1.0, 0.8, 0.4)
	shine.light_energy = 1.2
	shine.omni_range = 3.0
	chest.add_child(shine)
	if already_open:
		lid.rotation_degrees.x = -100.0
		lid.position += Vector3(0, 0.1, -0.35)
		shine.light_energy = 0.3
		return
	var opened := [false]
	var open_chest := func() -> void:
		if opened[0]:
			return
		opened[0] = true
		_state_add("chests", chest_id)
		lid.create_tween().tween_property(lid, "rotation_degrees:x", -100.0, 0.4)
		lid.position += Vector3(0, 0.1, -0.35)
		Sfx.play("coin", -2.0)
		Pickup.spawn(self, c + Vector3(0, 0, 1.2), "gold", _rng.randi_range(40, 90))
		Pickup.spawn(self, c + Vector3(0.8, 0, 1.0), "potion")
		if _rng.randf() < 0.6:
			var pool: Array[String] = []
			for id: String in ItemDB.common_drops():
				if not GameState.inventory.has(id):
					pool.append(id)
			if not pool.is_empty():
				Pickup.spawn(self, c + Vector3(-0.8, 0, 1.0), "item", 0, pool.pick_random())
		Events.notify("Coffre ouvert !", Events.COLOR_GOLD)
	Interactable.create(self, c + Vector3(0, 0, 0.9), "Ouvrir le coffre", open_chest, 2.0)


## Coop : +33 % d'ennemis par joueur supplémentaire (même calcul chez l'hôte et les clients).
func _coop_count(base: int) -> int:
	return roundi(base * Balance.coop_enemy_count_mult(Net.player_count()))


func _spawn_rat(pos: Vector3, room: int = -1) -> Rat:
	var r := Rat.new()
	r.level = enemy_level
	r.position = pos + Vector3(_rng.randf_range(-0.5, 0.5), 0, _rng.randf_range(-0.5, 0.5))
	r.rotation.y = _rng.randf() * TAU
	r.walkable_check = is_walkable
	return _place_enemy(r, room) as Rat


## `room` >= 0 : ennemi d'origine du donjon (persistant, endormi tant que sa salle est
## fermée) ; -1 : renfort invoqué en cours de combat.
func _spawn_skeleton(pos: Vector3, captain: bool, room: int = -1, is_chief: bool = false) -> Skeleton:
	var s := Skeleton.new()
	s.captain = captain
	s.chief = is_chief
	s.level = enemy_level
	s.position = pos
	s.rotation.y = _rng.randf() * TAU
	s.walkable_check = is_walkable
	return _place_enemy(s, room) as Skeleton


## Ajoute un ennemi au donjon, sauf s'il a déjà été tué lors d'une visite précédente
## (les tirages aléatoires ont quand même eu lieu : le reste du donjon est identique).
func _place_enemy(e: Enemy, room: int) -> Enemy:
	if room < 0:
		add_child(e)
		return e
	var uid := _enemy_uid
	_enemy_uid += 1
	if _state_has("dead", uid):
		e.free()
		return null
	e.set_meta("uid", uid)
	add_child(e)
	if not _room_enemies.has(room):
		_room_enemies[room] = []
	(_room_enemies[room] as Array).append(e)
	return e


# --- État persistant du donjon ---------------------------------------------------------

func _state_has(key: String, value: int) -> bool:
	for v: Variant in _state.get(key, []):
		if int(v) == value:
			return true
	return false


func _state_add(key: String, value: int) -> void:
	if _state_has(key, value):
		return
	if not _state.has(key):
		_state[key] = []
	(_state[key] as Array).append(value)


func _on_enemy_killed(e: Node3D) -> void:
	if e.get_parent() == self and e.has_meta("uid"):
		_state_add("dead", int(e.get_meta("uid")))
	if e == chief:
		# Le chef des squelettes tombe : la clé de la salle du boss roule au sol.
		var p := e.global_position + Vector3(0.6, 0, 0.6)
		_state["boss_key_pos"] = [snappedf(p.x, 0.01), snappedf(p.z, 0.01)]
		_spawn_boss_key(p)
		Events.notify("Le chef des squelettes laisse tomber une grosse clé noire...", Events.COLOR_GOLD)


func _spawn_boss_room() -> void:
	var r := gen.rooms[gen.boss_room]
	var c := cell_to_world(gen.center(gen.boss_room))
	_build_pentagram(c)
	var glow := Visuals.flicker_light(self, c + Vector3(0, 3.5, 0), Color(0.45, 0.9, 0.6), 2.0, 11.0)
	glow.flicker_amount = 0.1
	for k in 4:
		var a := TAU * k / 4.0 + PI * 0.25
		var p := c + Vector3(cos(a), 0, sin(a)) * 6.2
		Visuals.cylinder(self, 0.35, 0.2, 0.9, p + Vector3(0, 0.45, 0), Visuals.mat(Color(0.15, 0.13, 0.12), 0.5, 0.6), Vector3.ZERO, 8)
		Visuals.sphere(self, 0.25, p + Vector3(0, 1.0, 0), Visuals.glow_mat(Color(1.0, 0.5, 0.15), 5.0), Vector3(1, 0.6, 1))
		Visuals.flicker_light(self, p + Vector3(0, 1.6, 0), Color(1.0, 0.55, 0.25), 2.0, 8.0, k == 0)
		Visuals.solid_cylinder(self, 0.35, 2.0, p + Vector3(0, 1.0, 0))
	var corner := Vector3((r.size.x * 0.5 - 2.0) * CELL, 0, (r.size.y * 0.5 - 2.0) * CELL)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var p := c + Vector3(corner.x * sx, 0, corner.z * sz)
			Visuals.cylinder(self, 0.5, 0.6, 3.0, p + Vector3(0, 1.5, 0), _wall_material, Vector3.ZERO, 8)
			Visuals.solid_cylinder(self, 0.6, 3.0, p + Vector3(0, 1.5, 0))
	# Cage de Plumeau (fermée à clé) et cage vide juste à côté.
	_cage_pos = c + Vector3(-corner.x + 2.5, 0, -corner.z + 2.5)
	_prison_pos = _cage_pos + Vector3(2.6, 0, 0)
	cub = OwlbearCub.new()
	cub.position = _cage_pos
	cub.rotation.y = PI * 0.25
	add_child(cub)
	_cage_bars = _build_cage(_cage_pos, true)
	Visuals.label(self, "Plumeau", _cage_pos + Vector3(0, 2.2, 0), Color(0.95, 0.8, 0.5), 32)
	_prison_bars = _build_cage(_prison_pos, false) # porte ouverte : barreaux baissés
	_cage_interact = Interactable.create(self, _cage_pos + Vector3(0.9, 0, 0.9), "Ouvrir la cage de Plumeau", _try_open_cage, 1.8)
	# Le boss (sauf s'il a déjà été vaincu lors d'une visite précédente).
	if bool(_state.get("boss_dead", false)):
		if not bool(_state.get("cage_key", false)):
			_spawn_key(c + Vector3(0.8, 0, 0.8))
	else:
		boss = FrogBoss.new()
		boss.level = enemy_level
		boss.position = c
		boss.rotation.y = PI * 0.25
		boss.walkable_check = is_walkable
		boss.spawn_minion = _spawn_minion.bind(c)
		add_child(boss)
		_room_enemies[gen.boss_room] = [boss]
		if bool(_state.get("boss_friend", false)):
			boss.befriend()
	if bool(_state.get("cage_key", false)):
		_has_key = true
		_cage_interact.prompt = "Ouvrir la cage de Plumeau (clé)"
	if bool(_state.get("cage_open", false)):
		_cage_open = true
		_cage_interact.queue_free()
		for bar in _cage_bars:
			bar.position.y = -1.0
		cub.follow()
		_spawn_victory_portal()


func _spawn_minion(p: Vector3, c: Vector3) -> void:
	var s := _spawn_skeleton(p if is_walkable(p) else c, false)
	s.call_deferred("_aggro")


## Cage ronde en fer. `closed` = barreaux levés ; sinon ils sont rentrés dans le sol.
func _build_cage(pos: Vector3, closed: bool) -> Array[Node3D]:
	var iron := Visuals.mat(Color(0.25, 0.22, 0.2), 0.5, 0.8)
	Visuals.cylinder(self, 1.0, 1.0, 0.1, pos + Vector3(0, 1.7, 0), iron, Vector3.ZERO, 12)
	Visuals.cylinder(self, 1.0, 1.0, 0.06, pos + Vector3(0, 0.03, 0), iron, Vector3.ZERO, 12)
	var bars: Array[Node3D] = []
	for k in 10:
		var a := TAU * k / 10.0
		var bar := Visuals.cylinder(self, 0.03, 0.03, 1.7, pos + Vector3(cos(a) * 0.95, 0.85 if closed else -1.0, sin(a) * 0.95), iron, Vector3.ZERO, 6)
		bars.append(bar)
	return bars


func _set_bars(bars: Array[Node3D], closed: bool) -> void:
	for bar in bars:
		var tw := bar.create_tween()
		tw.tween_property(bar, "position:y", 0.85 if closed else -1.0, 0.6).set_delay(randf() * 0.25)


# --- Fin du donjon : dialogue de Gloubah, clé, cage, récapitulatif ------------------

func _on_story_action(action: String) -> void:
	match action:
		"gloubah_fight":
			boss.start_fight()
		"gloubah_surrender":
			_surrender()
		"gloubah_friend":
			_befriend_gloubah()


func _on_boss_defeated(_boss_id: String) -> void:
	_state["boss_dead"] = true
	# Gloubah laisse tomber la clé de la cage : il faut la ramasser ([E] ou clic).
	var key_pos := boss.global_position + Vector3(0.8, 0, 0.8)
	_spawn_key(key_pos)
	Events.notify("Gloubah a laissé tomber une clé rouillée...", Events.COLOR_GOLD)
	if hero != null:
		hero.model.victory()


func _spawn_key(pos: Vector3) -> void:
	var key := Interactable.create(self, pos, "Ramasser la clé de la cage", Callable(), 1.8)
	var gold := Visuals.glow_mat(Color(1.0, 0.8, 0.3), 2.5)
	var visual := Node3D.new()
	key.add_child(visual)
	Visuals.torus(visual, 0.08, 0.12, Vector3(0, 0.5, 0), gold, Vector3(90, 0, 0))
	Visuals.box(visual, Vector3(0.04, 0.04, 0.35), Vector3(0, 0.5, 0.25), gold)
	Visuals.box(visual, Vector3(0.04, 0.1, 0.04), Vector3(0, 0.45, 0.38), gold)
	var shine := OmniLight3D.new()
	shine.position.y = 0.8
	shine.light_color = Color(1.0, 0.8, 0.4)
	shine.omni_range = 2.5
	key.add_child(shine)
	visual.create_tween().set_loops().tween_property(visual, "rotation:y", TAU, 2.0).from(0.0)
	key.on_interact = func() -> void:
		_take_key()
		key.queue_free()


func _take_key() -> void:
	_has_key = true
	_state["cage_key"] = true
	Sfx.play("coin", 0.0)
	Events.notify("Clé de la cage obtenue ! Allez libérer Plumeau.", Events.COLOR_GOLD)
	_cage_interact.prompt = "Ouvrir la cage de Plumeau (clé)"


func _try_open_cage() -> void:
	if _cage_open:
		return
	if not _has_key:
		Events.notify("La cage est fermée à clé. Gloubah doit l'avoir sur elle...", Events.COLOR_BAD)
		Sfx.play("dud", -8.0)
		return
	_cage_open = true
	_cage_interact.queue_free()
	_set_bars(_cage_bars, false)
	_state["cage_open"] = true
	GameState.complete_objective(quest_id)
	GameState.flags["plumeau_rescued"] = true
	await get_tree().create_timer(0.9, false).timeout
	if cub != null:
		cub.follow()
		cub.celebrate()
	if hero != null:
		hero.model.victory()
	Sfx.play("levelup", -4.0)
	Events.notify("Plumeau est libre ! Hou-hou !", Color(0.95, 0.8, 0.5))
	await get_tree().create_timer(1.2, false).timeout
	_spawn_victory_portal()
	Events.notify("Zarathos : « Beau vacarme, barde ! Je t'ouvre un passage. »", Events.COLOR_MAGIC)


func _spawn_victory_portal() -> void:
	var portal := Portal.new()
	portal.position = cell_to_world(gen.center(gen.boss_room)) + Vector3(2.0, 0, 2.0)
	portal.prompt = "Retourner à la taverne (portail de Zarathos)"
	portal.on_enter = _end_dungeon.bind("Catacombes nettoyées !", true)
	add_child(portal)


## Choix « Bah oui, il est kiki... » : Gloubah devient amicale et donne la clé.
## Récompense : le double de l'XP qu'aurait rapporté sa mort.
func _befriend_gloubah() -> void:
	boss.befriend()
	_state["boss_friend"] = true
	var xp := boss.xp_reward * 2
	GameState.add_xp(xp)
	DamageNumber.spawn(self, boss.global_position + Vector3(0, 3.0, 0), "+%d XP" % xp, Events.COLOR_GOLD, true)
	Events.notify("Gloubah vous confie la clé de la cage, les yeux humides. (+%d XP — victoire sans combat !)" % xp, Events.COLOR_GOLD)
	_take_key()


## Choix « Je me rends » : Gloubah enferme le héros dans la cage vide.
func _surrender() -> void:
	hero.captive = true
	hero.global_position = _prison_pos
	camera.snap_to_target()
	_set_bars(_prison_bars, true)
	Sfx.play("croak", 0.0, 0.0)
	Events.notify("Gloubah : « CROÂ-HA-HA ! Un nouveau bibelot pour ma collection ! »", Color(0.6, 0.95, 0.5))
	await get_tree().create_timer(4.0, false).timeout
	Events.notify("Zarathos : « Tss... je te sors de là. Reviens quand tu auras plus de cran. »", Events.COLOR_MAGIC)
	await get_tree().create_timer(2.0, false).timeout
	_end_dungeon("Capturé par Gloubah...", false)


func _spawn_flee_portal(pos: Vector3) -> void:
	var portal := Portal.new()
	portal.position = pos
	portal.prompt = "Fuir vers la taverne (la quête reste en cours)"
	portal.on_enter = _end_dungeon.bind("Retraite stratégique", false)
	add_child(portal)


## Fin du passage au donjon : récapitulatif (victimes, dégâts) puis retour à la taverne.
func _end_dungeon(title: String, victory: bool) -> void:
	GameState.flags["in_dungeon"] = true
	GameState.location = {"scene": Router.TAVERN}
	if victory:
		# Donjon terminé : le prochain sera un nouveau donjon.
		GameState.dungeon_state = {}
		GameState.dungeon_seed = 0
		GameState.town_portal = {}
		GameState.save_game()
	hud.show_recap(title, func() -> void: Router.go_to(Router.TAVERN))


## Pentagramme tracé à la bave verte luminescente sous Gloubah, cerclé de bave, avec des
## flaques et éclaboussures de sang tout autour (ses « repas »).
func _build_pentagram(c: Vector3) -> void:
	var slime := Visuals.glow_mat(Color(0.3, 0.95, 0.2), 1.6)
	var r := 4.2
	Visuals.torus(self, r - 0.12, r + 0.12, c + Vector3(0, 0.03, 0), slime)
	Visuals.torus(self, r + 0.45, r + 0.6, c + Vector3(0, 0.03, 0), slime)
	var pts: Array[Vector3] = []
	for k in 5:
		var a := -PI * 0.5 + TAU * k / 5.0
		pts.append(c + Vector3(cos(a), 0, sin(a)) * r)
	for k in 5:
		# Étoile à cinq branches : chaque pointe est reliée à l'avant-dernière suivante.
		var a := pts[k]
		var b := pts[(k + 2) % 5]
		var mid := (a + b) * 0.5
		var seg := b - a
		var line := Visuals.box(self, Vector3(0.22, 0.02, seg.length()), mid + Vector3(0, 0.035, 0), slime)
		line.rotation.y = atan2(seg.x, seg.z)
		line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Coulures de bave aux pointes.
		Visuals.sphere(self, 0.28, a + Vector3(0, 0.02, 0), slime, Vector3(1.2, 0.08, 1.0))
	# Petites runes entre les deux cercles.
	for k in 10:
		var a := TAU * k / 10.0
		var rune := Visuals.box(self, Vector3(0.3, 0.02, 0.08), c + Vector3(cos(a), 0, sin(a)) * (r + 0.3) + Vector3(0, 0.035, 0), slime)
		rune.rotation.y = -a + (0.5 if k % 2 == 0 else -0.5)
	# Sang : grandes flaques sombres et éclaboussures.
	var blood := Visuals.mat(Color(0.28, 0.0, 0.01), 0.12)
	var fresh := Visuals.mat(Color(0.45, 0.01, 0.02), 0.08)
	for k in 7:
		var a := _rng.randf() * TAU
		var d := _rng.randf_range(1.5, 6.5)
		var p := c + Vector3(cos(a) * d, 0.02 + k * 0.001, sin(a) * d)
		Visuals.cylinder(self, _rng.randf_range(0.3, 0.9), _rng.randf_range(0.4, 1.0), 0.01, p, blood if k % 2 == 0 else fresh, Vector3.ZERO, 12)
		for s in 4:
			var q := p + Vector3(_rng.randf_range(-1.2, 1.2), 0.004, _rng.randf_range(-1.2, 1.2))
			Visuals.cylinder(self, 0.08, 0.1, 0.01, q, fresh, Vector3.ZERO, 8)
	# Une traînée de sang qui mène au trône.
	for k in 8:
		Visuals.cylinder(self, 0.18 - k * 0.012, 0.2 - k * 0.012, 0.01, c + Vector3(2.0 + k * 0.6, 0.025, 1.0 + k * 0.35), fresh, Vector3.ZERO, 10)
	var glow := Visuals.flicker_light(self, c + Vector3(0, 0.6, 0), Color(0.35, 1.0, 0.3), 1.2, 7.0)
	glow.flicker_amount = 0.25



# =====================================================================================
# Portes, salles plongées dans le noir et clé du chef
# =====================================================================================

## Une porte à deux battants à chaque arrivée de couloir dans une salle. Celles de la salle
## du boss sont scellées : il faut la clé que porte le chef des squelettes.
func _build_doors() -> void:
	for i in gen.rooms.size():
		for o in gen.room_openings(i):
			if int(o["length"]) <= DOOR_MAX_CELLS:
				_build_door(i, o)
	for v: Variant in _state.get("doors", []):
		var idx := int(v)
		if idx >= 0 and idx < doors.size():
			_open_door(idx, false)


func _build_door(room: int, o: Dictionary) -> void:
	var step: Vector2i = o["step"]
	var out: Vector2i = o["out"]
	var n := int(o["length"])
	var along := Vector3(step.x, 0, step.y)
	var inward := -Vector3(out.x, 0, out.y)
	var width := n * CELL
	# Porte dans l'alignement du mur de la salle, au bout du couloir.
	var center := cell_to_world(o["cell"]) + along * (n - 1) * CELL * 0.5 + inward * (CELL * 0.5 - 0.15)
	var x_axis := along if along.cross(Vector3.UP).dot(inward) > 0.0 else -along
	var node := Node3D.new()
	node.transform = Transform3D(Basis(x_axis, Vector3.UP, inward), center)
	add_child(node)
	var locked := room == gen.boss_room
	var wood := Visuals.mat(Color(0.45, 0.28, 0.14) if not locked else Color(0.35, 0.12, 0.08), 0.85)
	var dark := Visuals.mat(Color(0.16, 0.09, 0.05), 0.9)
	var iron := Visuals.mat(Color(0.2, 0.2, 0.22), 0.45, 0.7)
	var h := WALL_HEIGHT
	# Chambranle.
	for side: float in [-1.0, 1.0]:
		Visuals.box(node, Vector3(0.3, h, 0.45), Vector3(side * (width * 0.5 - 0.15), h * 0.5, 0), _wall_material)
	Visuals.box(node, Vector3(width, 0.35, 0.45), Vector3(0, h - 0.175, 0), _wall_material)
	# Deux battants de bois cerclés de fer, pivotant vers l'intérieur de la salle.
	var leaves: Array[Node3D] = []
	var leaf_w := width * 0.5 - 0.3
	var leaf_h := h - 0.4
	for side: float in [-1.0, 1.0]:
		var hinge := Node3D.new()
		hinge.position = Vector3(side * (width * 0.5 - 0.3), 0, 0)
		node.add_child(hinge)
		var mid := -side * leaf_w * 0.5
		Visuals.box(hinge, Vector3(leaf_w - 0.02, leaf_h, 0.12), Vector3(mid, leaf_h * 0.5, 0), wood)
		for k in int(leaf_w / 0.35):
			var x := -side * (0.2 + k * 0.35)
			Visuals.box(hinge, Vector3(0.025, leaf_h - 0.05, 0.13), Vector3(x, leaf_h * 0.5, 0), dark) # planches
		for y: float in [0.45, leaf_h - 0.55]:
			Visuals.box(hinge, Vector3(leaf_w - 0.05, 0.1, 0.15), Vector3(mid, y, 0), iron)
		Visuals.torus(hinge, 0.07, 0.1, Vector3(-side * (leaf_w - 0.25), 1.1, 0.1), iron, Vector3(90, 0, 0)) # anneau
		leaves.append(hinge)
	var lock_parts: Array[Node3D] = []
	if locked:
		# Chaînes en croix, gros cadenas et lueur rouge : scellée par le chef des squelettes.
		for sgn: float in [-1.0, 1.0]:
			lock_parts.append(Visuals.box(node, Vector3(width * 0.9, 0.07, 0.07), Vector3(0, leaf_h * 0.5, -0.12), iron, Vector3(0, 0, 28 * sgn)))
		lock_parts.append(Visuals.box(node, Vector3(0.35, 0.4, 0.15), Vector3(0, leaf_h * 0.5, -0.18), Visuals.mat(Color(0.35, 0.3, 0.1), 0.4, 0.8)))
		lock_parts.append(Visuals.torus(node, 0.1, 0.14, Vector3(0, leaf_h * 0.5 + 0.28, -0.18), iron))
		var glow := Visuals.flicker_light(node, Vector3(0, 1.6, -0.9), Color(1.0, 0.15, 0.1), 1.6, 5.0)
		glow.flicker_amount = 0.4
		lock_parts.append(glow)
	# Collision : la porte fermée bloque le héros et les ennemis.
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, h, 0.3)
	col.shape = shape
	col.position.y = h * 0.5
	body.add_child(col)
	node.add_child(body)
	var idx := doors.size()
	var prompt := "Ouvrir la porte" if not locked else "Porte scellée (clé du chef des squelettes)"
	var interact := Interactable.create(self, center, prompt, _on_door.bind(idx), width * 0.5 + 1.3)
	doors.append({"room": room, "node": node, "body": body, "interact": interact, "leaves": leaves,
		"lock": lock_parts, "locked": locked, "open": false})


func _on_door(idx: int) -> void:
	var d := doors[idx]
	if bool(d["open"]):
		return
	if bool(d["locked"]):
		if not bool(_state.get("boss_key", false)):
			Events.notify("La porte est scellée par des chaînes. Le chef des squelettes doit en avoir la clé...", Events.COLOR_BAD)
			Sfx.play("dud", -8.0)
			return
		Events.notify("La clé du chef tourne dans le cadenas... La salle de Gloubah s'ouvre.", Events.COLOR_GOLD)
		Sfx.play("coin", 0.0)
	_open_door(idx, true)


func _open_door(idx: int, animate: bool) -> void:
	var d := doors[idx]
	if bool(d["open"]):
		return
	d["open"] = true
	_state_add("doors", idx)
	(d["body"] as Node).queue_free()
	(d["interact"] as Node).queue_free()
	for part: Node3D in d["lock"]:
		part.queue_free()
	var leaves: Array[Node3D] = d["leaves"]
	for k in leaves.size():
		var target := deg_to_rad(-95.0 if k == 0 else 95.0)
		if animate:
			leaves[k].create_tween().tween_property(leaves[k], "rotation:y", target, 0.6).set_trans(Tween.TRANS_SINE)
		else:
			leaves[k].rotation.y = target
	if animate:
		Sfx.play("thud", -6.0, 0.2)
	_reveal_room(int(d["room"]))


## Salle encore fermée : sol noir, décor et lumières masqués, occupants endormis ; on ne
## voit que ses murs et ses portes (rien n'est caché devant la porte elle-même).
func _build_room_covers() -> void:
	_state_add("rooms", gen.start_room)
	var props: Array[Node3D] = []
	for c in get_children():
		var n := c as Node3D
		if n != null and not (n is Enemy) and n != _under and not (n is Portal):
			props.append(n)
	for i in gen.rooms.size():
		if _state_has("rooms", i):
			continue
		var r := gen.rooms[i]
		var hidden: Array[Node3D] = []
		for n in props:
			if n.visible and r.has_point(world_to_cell(n.global_position)):
				n.visible = false
				hidden.append(n)
		_hidden[i] = hidden
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(0.0, 0.0, 0.0, 1.0)
		var size := Vector3(r.size.x * CELL, 0.04, r.size.y * CELL)
		var pos := Vector3((r.position.x + r.size.x * 0.5) * CELL, 0.03, (r.position.y + r.size.y * 0.5) * CELL)
		var cover := Visuals.box(self, size, pos, mat)
		cover.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_covers[i] = cover
		for e: Variant in _room_enemies.get(i, []):
			if is_instance_valid(e):
				(e as Enemy).set_dormant(true)


func is_room_revealed(room: int) -> bool:
	return _state_has("rooms", room)


func _reveal_room(room: int) -> void:
	_state_add("rooms", room)
	for e: Variant in _room_enemies.get(room, []):
		if is_instance_valid(e):
			(e as Enemy).set_dormant(false)
	for n: Variant in _hidden.get(room, []):
		if is_instance_valid(n):
			(n as Node3D).visible = true
	_hidden.erase(room)
	if not _covers.has(room):
		return
	var cover: MeshInstance3D = _covers[room]
	_covers.erase(room)
	var mat := cover.material_override as StandardMaterial3D
	var tw := cover.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.7)
	tw.tween_callback(cover.queue_free)


## Salle dont un côté est trop largement ouvert pour une porte : découverte en y entrant.
func _reveal_room_at(p: Vector3) -> void:
	if _covers.is_empty():
		return
	var c := world_to_cell(p)
	for i: int in _covers.keys():
		if gen.rooms[i].has_point(c):
			_reveal_room(i)
			return


func _spawn_boss_key(pos: Vector3) -> void:
	var key := Interactable.create(self, pos, "Ramasser la clé de la salle du boss", Callable(), 1.8)
	var iron := Visuals.glow_mat(Color(0.9, 0.3, 0.15), 1.8)
	var visual := Node3D.new()
	key.add_child(visual)
	Visuals.torus(visual, 0.1, 0.15, Vector3(0, 0.55, 0), iron, Vector3(90, 0, 0))
	Visuals.box(visual, Vector3(0.05, 0.05, 0.45), Vector3(0, 0.55, 0.32), iron)
	Visuals.box(visual, Vector3(0.05, 0.14, 0.05), Vector3(0, 0.49, 0.5), iron)
	Visuals.box(visual, Vector3(0.05, 0.1, 0.05), Vector3(0, 0.5, 0.4), iron)
	var shine := OmniLight3D.new()
	shine.position.y = 0.9
	shine.light_color = Color(1.0, 0.35, 0.2)
	shine.omni_range = 3.0
	key.add_child(shine)
	visual.create_tween().set_loops().tween_property(visual, "rotation:y", TAU, 2.0).from(0.0)
	key.on_interact = _take_boss_key.bind(key)


func _take_boss_key(key: Node) -> void:
	_state["boss_key"] = true
	key.queue_free()
	Sfx.play("coin", 0.0)
	Events.notify("Clé de la salle du boss obtenue ! La porte scellée de Gloubah peut s'ouvrir.", Events.COLOR_GOLD)
	for d in doors:
		if bool(d["locked"]) and not bool(d["open"]):
			(d["interact"] as Interactable).prompt = "Ouvrir la porte scellée (clé du chef)"


# =====================================================================================
# Portail bleu de retour en ville (touche T)
# =====================================================================================

## Ouvre un portail bleu vers la taverne ; un second portail apparaît à côté de celui de
## Zarathos, qui ramène exactement ici (le donjon reste tel quel jusqu'à ce qu'on le finisse).
func open_town_portal() -> void:
	if hero == null or hero.dead or hero.captive or hero.casting_solo:
		return
	if in_combat():
		Events.notify("Impossible d'ouvrir un portail en plein combat !", Events.COLOR_BAD)
		Sfx.play("dud", -8.0)
		return
	var p := hero.global_position + hero.facing * 1.8
	if not is_walkable(p):
		p = hero.global_position
	p.y = 0.0
	_spawn_town_portal(p)
	GameState.town_portal = {"pos": [snappedf(p.x, 0.01), snappedf(p.z, 0.01)]}
	Events.notify("Un portail bleu s'ouvre vers le Crâne Hurlant.", Color(0.5, 0.75, 1.0))


func _spawn_town_portal(p: Vector3) -> void:
	if _town_portal != null and is_instance_valid(_town_portal):
		_town_portal.queue_free()
	_town_portal = Portal.new()
	_town_portal.blue = true
	_town_portal.position = p
	_town_portal.prompt = "Portail bleu : retour à la taverne"
	_town_portal.target_scene = Router.TAVERN
	_town_portal.on_enter = _take_town_portal
	add_child(_town_portal)


func _take_town_portal() -> void:
	GameState.flags["in_dungeon"] = true
	GameState.flags["from_town_portal"] = true
	GameState.location = {"scene": Router.TAVERN}
	GameState.save_game()
