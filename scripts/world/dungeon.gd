extends Level
## Donjon : construit la géométrie à partir du DungeonGenerator (aléatoire) ou d'un donjon fait main
## dans l'éditeur (scène DungeonMap, clé "map" de la quête dans QuestDB), peuple les salles,
## place le boss, gère la fin de quête.

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
## Torches murales (rouges tant qu'on n'est pas passé près d'elles, voir _update_torches).
var _torches: Array[Node3D] = []
var _torch_check := 0.0
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
## Donjon fait main : décalage entre les cases de `gen` et celles de la GridMap de la scène, et objets
## placés à la main [{kind, pos, basis}] (voir DungeonMap, DungeonMarker).
var _cell_offset := Vector2i.ZERO
var _map_markers: Array[Dictionary] = []
var from_map := false
## Thème : « catacombes » (Plumeau), « crypte » (Cryptes de la Cathédrale, portail à XP) ou « temple » (Temple du
## Dragon). Il règle le sol, les murs, le décor, les ennemis, le boss et les sorties (voir DungeonThemes).
var theme := "catacombes"
## Donjon de quête persistant (GameState.dungeon_state) ou régénéré à chaque passage (cryptes).
var persistent := true
## Porte du boss scellée (clé du chef des squelettes) : catacombes seulement.
var boss_key_door := true


func _ready() -> void:
	quest_id = GameState.active_quest if not GameState.active_quest.is_empty() else "plumeau"
	var cfg := _dungeon_config()
	theme = str(cfg.get("theme", "catacombes"))
	boss_key_door = bool(cfg.get("boss_key", theme == "catacombes"))
	enemy_level = _enemy_level(cfg)
	var seed_value := _saved_seed()
	if seed_value == 0:
		seed_value = randi_range(1, 999999)
	# Donjon fait main (quête, ou scène testée avec F6 dans l'éditeur) ou généré.
	var map_path := str(GameState.flags.get("test_map", cfg.get("map", "")))
	if theme == "catacombes" and not map_path.is_empty() and ResourceLoader.exists(map_path):
		_load_map(map_path)
		seed_value = 1 # décor (os, sang...) toujours tiré de la même façon
	else:
		# La salle du boss est fermée à clé : on garde la première graine où toutes les autres
		# salles restent accessibles sans la traverser.
		seed_value = gen.generate_sealed(seed_value, int(cfg.get("rooms", 10)), DOOR_MAX_CELLS)
	_store_seed(seed_value)
	_rng.seed = seed_value

	if persistent:
		# Donjon de quête, persistant tant qu'il n'est pas terminé (ennemis tués, portes, clés...).
		if GameState.dungeon_state.is_empty():
			GameState.dungeon_state = {"dead": [], "doors": [], "rooms": [], "chests": []}
			GameState.reset_run()
		_state = GameState.dungeon_state
		GameState.flags["in_dungeon"] = true
	else:
		_state = {"dead": [], "doors": [], "rooms": [], "chests": []}
		GameState.reset_run()
	setup_level("dungeon", str(cfg.get("name", "Donjon")))
	hud.show_kill_counter()
	_build_floor()
	_build_walls()
	_decorate()
	_build_doors()
	_spawn_enemies()
	_spawn_boss_room()
	_build_room_covers()
	_assign_torches()
	var start := cell_to_world(gen.center(gen.start_room))
	if theme == "temple":
		start = _nave_entrance()
	_spawn_flee_portal(start + Vector3(-3.0, 0.0, -3.0) if theme != "temple" else start + _nave_side() * 4.2)
	# Retour par le portail bleu : exactement là où on l'avait ouvert.
	var via_portal: bool = GameState.flags.get("via_town_portal", false)
	GameState.flags.erase("via_town_portal")
	var tp: Array = GameState.town_portal.get("pos", []) if persistent else []
	if via_portal and tp.size() == 2:
		start = Vector3(float(tp[0]), 0.0, float(tp[1])) + Vector3(0.0, 0.0, 1.4)
		GameState.town_portal = {} # le portail se referme derrière le héros
	elif tp.size() == 2:
		_spawn_town_portal(Vector3(float(tp[0]), 0.0, float(tp[1]))) # toujours ouvert depuis la dernière visite
	spawn_hero(start)
	_reveal_room_at(hero.global_position)
	if theme == "catacombes":
		Events.boss_defeated.connect(_on_boss_defeated)
	Events.story_action.connect(_on_story_action)
	Events.enemy_killed.connect(_on_enemy_killed)
	Events.town_portal_requested.connect(open_town_portal)
	Events.quest_item_added.connect(_on_quest_item_added)
	Sfx.play_playlist("res://audio/music/donjons", -8.0) # musiques des donjons, au hasard
	_arrival_notice()


## Réglages du donjon (nom, thème, salles, niveau des ennemis...) : ceux de la quête en cours (QuestDB).
func _dungeon_config() -> Dictionary:
	return QuestDB.get_quest(quest_id).get("dungeon", {})


func _enemy_level(cfg: Dictionary) -> int:
	return int(cfg.get("enemy_level", 1))


## Graine du donjon de quête en cours (0 = en tirer une nouvelle).
func _saved_seed() -> int:
	return GameState.dungeon_seed


func _store_seed(seed_value: int) -> void:
	GameState.dungeon_seed = seed_value


func _arrival_notice() -> void:
	if GameState.quest_state(quest_id) != QuestDB.State.ACTIVE:
		return
	match theme:
		"catacombes":
			Events.notify("Trouvez Plumeau au fond des catacombes...", Events.COLOR_DEFAULT)
		"temple":
			Events.notify("Le Temple du Dragon. Quelque part ici : le Pick du Destin... et quelque chose qui joue faux.", Events.COLOR_DEFAULT)


func _process(delta: float) -> void:
	if hero != null and _wall_material != null:
		_wall_material.set_shader_parameter("hero_pos", hero.global_position)
	if hero != null:
		_reveal_room_at(hero.global_position) # salle sans porte (côté ouvert) : on la découvre en entrant
		_update_lava(delta)
		_update_nave_ambush()
	_torch_check -= delta
	if _torch_check <= 0.0:
		_torch_check = 0.4
		_update_torches()


func cell_to_world(c: Vector2i) -> Vector3:
	return Vector3((c.x + _cell_offset.x + 0.5) * CELL, 0.0, (c.y + _cell_offset.y + 0.5) * CELL)


func world_to_cell(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / CELL), floori(p.z / CELL)) - _cell_offset


## Coin de la case (0, 0) de `gen` dans le monde.
func _grid_origin() -> Vector3:
	return Vector3(_cell_offset.x * CELL, 0.0, _cell_offset.y * CELL)


## Donjon fait main : grille, salles et objets lus dans la scène DungeonMap, qui est ensuite retirée
## (le donjon construit lui-même sol, murs, portes, ennemis et décor, comme pour un donjon généré).
func _load_map(path: String) -> void:
	var map := (load(path) as PackedScene).instantiate() as DungeonMap
	add_child(map)
	_cell_offset = map.read(gen)
	for m in map.markers():
		_map_markers.append({"kind": m.kind, "pos": Vector3(m.global_position.x, 0.0, m.global_position.z),
			"basis": m.global_transform.basis.orthonormalized()})
	remove_child(map)
	map.free()
	from_map = true


## Salle qui contient `p` (-1 = couloir).
func _room_at(p: Vector3) -> int:
	var c := world_to_cell(p)
	for i in gen.rooms.size():
		if gen.rooms[i].has_point(c):
			return i
	return -1


## Utilisé par les ennemis pour choisir des points d'errance valides.
func is_walkable(p: Vector3) -> bool:
	if in_lava(p):
		return false
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
	# Une dalle par case de 2 m : la texture du thème (projetée dans le repère du monde) dessine les pierres
	# et se raccorde d'une case à l'autre ; chaque case est à peine nuancée.
	var tile := BoxMesh.new()
	tile.size = Vector3(CELL, 0.2, CELL)
	mm.mesh = tile
	mm.instance_count = cells.size()
	for i in cells.size():
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, cell_to_world(cells[i]) + Vector3(0, -0.1, 0)))
		mm.set_instance_color(i, _floor_color(cells[i], _rng.randf_range(0.88, 1.04)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = DungeonThemes.floor_material(theme)
	add_child(mmi)
	# Joints sombres entre les dalles.
	var under := Vector3(gen.width * CELL, 0.1, gen.height * CELL)
	_under = Visuals.box(self, under, _grid_origin() + Vector3(under.x * 0.5, -0.2, under.z * 0.5), Visuals.mat(Color(0.02, 0.02, 0.02)))


## Teinte d'une case de sol (multiplie la texture du thème : pierre moussue, roche de lave, damier de marbre),
## assombrie pour l'ambiance du donjon et nuancée de `v`.
func _floor_color(_cell: Vector2i, v: float) -> Color:
	match theme:
		"crypte":
			return Color(0.55 * v, 0.5 * v, 0.5 * v)
		"temple":
			return Color(0.62 * v, 0.6 * v, 0.6 * v)
	return Color(0.5 * v, 0.5 * v, 0.52 * v)


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
	_wall_material = DungeonThemes.wall_material(theme)
	mmi.material_override = _wall_material
	add_child(mmi)


func _decorate() -> void:
	if from_map:
		_decorate_from_map()
		return
	_place_torches()
	match theme:
		"crypte":
			_decorate_crypt()
			return
		"temple":
			_decorate_temple()
			return
	for i in gen.rooms.size():
		if i == gen.boss_room or i == gen.start_room:
			continue
		# Piles d'os, flaques de bave verte, piliers brisés, tonneaux.
		for k in _rng.randi_range(4, 7):
			var p := cell_to_world(gen.random_cell_in_room(i, 2)) + Vector3(_rng.randf_range(-0.6, 0.6), 0, _rng.randf_range(-0.6, 0.6))
			_decor(_rng.randi_range(0, 3), p)


## Décor : 0 = tas d'os, 1 = flaque de bave, 2 = pilier brisé, 3 = tonneau.
func _decor(kind: int, p: Vector3) -> void:
	match kind:
		0:
			DungeonDecor.bones(self, p, _rng)
		1:
			DungeonDecor.slime(self, p)
		2:
			DungeonDecor.pillar(self, p, _wall_material, true)
		_:
			DungeonDecor.barrel(self, p, true)


## Donjon fait main : torches et décor posés dans l'éditeur.
func _decorate_from_map() -> void:
	for m in _map_markers:
		var p: Vector3 = m["pos"]
		match int(m["kind"]):
			DungeonMarker.Kind.TORCHE:
				_torches.append(DungeonDecor.torch(self, p, (m["basis"] as Basis).z, false))
			DungeonMarker.Kind.OS:
				_decor(0, p)
			DungeonMarker.Kind.BAVE:
				_decor(1, p)
			DungeonMarker.Kind.PILIER:
				_decor(2, p)
			DungeonMarker.Kind.TONNEAU:
				_decor(3, p)


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
			_torches.append(DungeonDecor.torch(self, p, -Vector3(d.x, 0, d.y), false))


# --- Population ----------------------------------------------------------------

func _spawn_enemies() -> void:
	if from_map:
		_spawn_from_map()
		return
	if theme != "catacombes":
		_spawn_demon_rooms()
		return
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
	_restore_boss_key()


## Chef déjà vaincu lors d'une visite précédente : sa clé attend peut-être encore au sol.
func _restore_boss_key() -> void:
	var key_pos: Array = _state.get("boss_key_pos", [])
	if chief == null and not bool(_state.get("boss_key", false)) and key_pos.size() == 2:
		_spawn_boss_key(Vector3(float(key_pos[0]), 0.0, float(key_pos[1])))


## Donjon fait main : ennemis et coffres posés dans l'éditeur. Un ennemi posé dans un couloir est
## éveillé dès le départ. En coop, des renforts s'ajoutent dans chaque salle (comme pour un donjon généré).
func _spawn_from_map() -> void:
	var chest_id := 0
	var by_room := {} # salle -> positions des ennemis posés (renforts de la coop)
	for m in _map_markers:
		var p: Vector3 = m["pos"]
		var kind := int(m["kind"])
		var room := _room_at(p)
		var yaw := atan2((m["basis"] as Basis).z.x, (m["basis"] as Basis).z.z)
		var e: Enemy = null
		match kind:
			DungeonMarker.Kind.SQUELETTE, DungeonMarker.Kind.CAPITAINE, DungeonMarker.Kind.CHEF:
				e = _spawn_skeleton(p, kind != DungeonMarker.Kind.SQUELETTE, room if room >= 0 else -2, kind == DungeonMarker.Kind.CHEF)
				if kind == DungeonMarker.Kind.CHEF:
					chief = e as Skeleton
			DungeonMarker.Kind.RAT:
				e = _spawn_rat(p, room if room >= 0 else -2)
			DungeonMarker.Kind.COFFRE:
				_spawn_chest(p, chest_id, yaw)
				chest_id += 1
		if e != null:
			e.position = p
			e.rotation.y = yaw
		if kind in [DungeonMarker.Kind.SQUELETTE, DungeonMarker.Kind.RAT] and room >= 0:
			if not by_room.has(room):
				by_room[room] = []
			(by_room[room] as Array).append([kind, p])
	for room: int in by_room:
		var placed: Array = by_room[room]
		for k in _coop_count(placed.size()) - placed.size():
			var src: Array = placed[k % placed.size()]
			var p: Vector3 = src[1] + Vector3(_rng.randf_range(-1.0, 1.0), 0.0, _rng.randf_range(-1.0, 1.0))
			if int(src[0]) == DungeonMarker.Kind.RAT:
				_spawn_rat(p, room)
			else:
				_spawn_skeleton(p, false, room)
	_restore_boss_key()


## Salle cul-de-sac : une douzaine de squelettes (dont 2 capitaines) gardent un coffre.
func _spawn_ambush(room: int) -> void:
	for k in _coop_count(12):
		_spawn_skeleton(cell_to_world(gen.random_cell_in_room(room, 1)), k < 2, room)
	_spawn_chest(cell_to_world(gen.center(room)), gen.ambush_rooms.find(room))


## Coffre (or, potion, parfois un objet) ; `chest_id` = identifiant sauvegardé (ouvert ou non).
func _spawn_chest(c: Vector3, chest_id: int, yaw: float = 0.0) -> void:
	var already_open := _state_has("chests", chest_id)
	var parts := DungeonDecor.chest(self, c, yaw)
	var lid: MeshInstance3D = parts[1]
	var shine: OmniLight3D = parts[2]
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
				if not GameState.owns(id):
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
## fermée) ; -2 : ennemi d'origine posé dans un couloir (persistant, éveillé) ; -1 : renfort
## invoqué en cours de combat.
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
	if room == -1:
		add_child(e)
		return e
	var uid := _enemy_uid
	_enemy_uid += 1
	if _state_has("dead", uid):
		e.free()
		return null
	e.set_meta("uid", uid)
	add_child(e)
	if room < 0:
		return e
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
	match theme:
		"crypte":
			_spawn_crypt_exit()
			return
		"temple":
			_spawn_angel_room()
			return
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
		Events.notify("La cage est fermée à clé. Gloubah doit l'avoir sur lui...", Events.COLOR_BAD)
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
	Events.notify("Un portail s'ouvre juste à côté de vous. Comment ? C'est Zarathos : il est mage, il fait des trucs de mage.", Events.COLOR_MAGIC)


## Le portail de Zarathos s'ouvre à côté du héros (s'il est sur un sol praticable, sinon au centre de la salle).
func _spawn_victory_portal() -> void:
	var portal := Portal.new()
	var p := cell_to_world(gen.center(gen.boss_room)) + Vector3(2.0, 0, 2.0)
	if hero != null:
		var beside := hero.global_position + hero.facing * 1.8
		if is_walkable(beside):
			p = Vector3(beside.x, 0.0, beside.z)
	portal.position = p
	portal.prompt = "Retourner à la taverne (portail de Zarathos)"
	portal.on_enter = _end_dungeon.bind("Catacombes nettoyées !", true)
	add_child(portal)


## Choix « Bah oui, il est kiki... » : Gloubah devient amical et donne la clé.
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
	portal.prompt = {"temple": "Ressortir sur le parvis du temple", "crypte": "Fuir vers la Chèvre Fringante (les cryptes se régénéreront)"}.get(theme, "Fuir vers la taverne (la quête reste en cours)")
	portal.on_enter = _end_dungeon.bind("Retraite stratégique", false)
	add_child(portal)


## Fin du passage au donjon : récapitulatif (victimes, dégâts) puis retour à la taverne.
func _end_dungeon(title: String, victory: bool) -> void:
	var dest := _exit_scene()
	GameState.location = {"scene": dest}
	if victory:
		if persistent:
			# Donjon de quête terminé : le prochain sera un nouveau donjon.
			GameState.dungeon_state = {}
			GameState.dungeon_seed = 0
			GameState.town_portal = {}
		GameState.save_game()
	hud.show_recap(title, func() -> void: Router.go_to(dest))


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

## Une porte à chaque arrivée de couloir dans une salle (art/portes/build_portes.py, à taille réelle) :
## porte de cachot, porte de crypte ou simple ouverture de pierre, au hasard (toujours la même pour une
## porte donnée) ; double porte voûtée au crâne cornu pour la salle du boss, scellée : il faut la clé
## que porte le chef des squelettes. Le reste de l'ouverture du couloir est muré.
const DOOR_MODELS := {
	"cachot": "res://assets/models/portes/cachot.glb",
	"crypte": "res://assets/models/portes/crypte.glb",
	"ouverture": "res://assets/models/portes/ouverture.glb",
	"boss": "res://assets/models/portes/boss.glb",
}
const DOOR_VARIANTS := ["cachot", "crypte", "ouverture"]
const DOOR_WALL_DEPTH := 0.45


func _build_doors() -> void:
	for i in gen.rooms.size():
		for o in gen.room_openings(i):
			if int(o["length"]) <= DOOR_MAX_CELLS:
				_build_door(i, o)
	for v: Variant in _state.get("doors", []):
		var idx := int(v)
		if idx >= 0 and idx < doors.size():
			_open_door(idx, false)


## Modèle d'une porte ordinaire, tiré au hasard mais toujours le même pour cette porte de ce donjon.
func _door_variant(o: Dictionary) -> String:
	var r := RandomNumberGenerator.new()
	r.seed = hash([GameState.dungeon_seed, o["cell"], o["out"]])
	return DOOR_VARIANTS[r.randi() % DOOR_VARIANTS.size()]


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
	var locked := room == gen.boss_room and boss_key_door
	var variant := "boss" if room == gen.boss_room else _door_variant(o)
	var model := (load(DOOR_MODELS[variant]) as PackedScene).instantiate() as Node3D
	model.rotation.y = PI # face décorée côté couloir (-Z local), battants qui s'ouvrent vers la salle
	node.add_child(model)
	var leaves: Array[Node3D] = []
	var frame_size := Vector3(1.6, 2.4, 0.5)
	for c in model.get_children():
		if c.name.contains("battant"):
			leaves.append(c as Node3D)
		elif c.name.contains("cadre") and c is MeshInstance3D:
			frame_size = (c as MeshInstance3D).get_aabb().size
	_door_walls(node, width, frame_size)
	if room != gen.boss_room:
		_door_torches(node, width, frame_size)
	var idx := doors.size()
	if variant == "ouverture":
		# Simple ouverture : rien à ouvrir, la salle se découvre quand on y entre (voir _reveal_room_at).
		doors.append({"room": room, "node": node, "body": null, "interact": null, "leaves": leaves,
			"lock": [], "locked": false, "open": true, "doorway": true})
		return
	var iron := Visuals.mat(Color(0.2, 0.2, 0.22), 0.45, 0.7)
	var lock_parts: Array[Node3D] = []
	if locked:
		# Chaînes en croix, gros cadenas et lueur rouge : scellée par le chef des squelettes.
		var span := minf(frame_size.x, width) * 0.8
		for sgn: float in [-1.0, 1.0]:
			lock_parts.append(Visuals.box(node, Vector3(span, 0.07, 0.07), Vector3(0, 1.1, -0.14), iron, Vector3(0, 0, 28 * sgn)))
		lock_parts.append(Visuals.box(node, Vector3(0.35, 0.4, 0.15), Vector3(0, 1.1, -0.2), Visuals.mat(Color(0.35, 0.3, 0.1), 0.4, 0.8)))
		lock_parts.append(Visuals.torus(node, 0.1, 0.14, Vector3(0, 1.38, -0.2), iron))
		var glow := Visuals.flicker_light(node, Vector3(0, 1.6, -0.9), Color(1.0, 0.15, 0.1), 1.6, 5.0)
		glow.flicker_amount = 0.4
		lock_parts.append(glow)
	# Collision : la porte fermée bloque le héros et les ennemis.
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(minf(frame_size.x, width), WALL_HEIGHT, 0.3)
	col.shape = shape
	col.position.y = WALL_HEIGHT * 0.5
	body.add_child(col)
	node.add_child(body)
	var prompt := "Ouvrir la porte" if not locked else "Porte scellée (clé du chef des squelettes)"
	var interact := Interactable.create(self, center, prompt, _on_door.bind(idx), 1.9)
	doors.append({"room": room, "node": node, "body": body, "interact": interact, "leaves": leaves,
		"lock": lock_parts, "locked": locked, "open": false, "doorway": false})


## Mur autour du cadre de la porte : de chaque côté jusqu'aux bords de l'ouverture du couloir (avec
## collision), et au-dessus du cadre jusqu'en haut du mur.
func _door_walls(node: Node3D, width: float, frame_size: Vector3) -> void:
	var side_w := (width - frame_size.x) * 0.5
	if side_w > 0.02:
		for s: float in [-1.0, 1.0]:
			var size := Vector3(side_w, WALL_HEIGHT, DOOR_WALL_DEPTH)
			var pos := Vector3(s * (frame_size.x * 0.5 + side_w * 0.5), WALL_HEIGHT * 0.5, 0)
			Visuals.box(node, size, pos, _wall_material)
			Visuals.solid(node, size, pos)
	var top := WALL_HEIGHT - frame_size.y
	if top > 0.02:
		Visuals.box(node, Vector3(minf(frame_size.x, width), top, DOOR_WALL_DEPTH),
			Vector3(0, frame_size.y + top * 0.5, 0), _wall_material)


## Une torche de chaque côté de la porte (sauf celle du boss), côté salle, contre le mur : sur le muret qui bouche
## un couloir large, sinon sur le mur de la salle juste à côté. Pas de torche dans un angle de la salle.
func _door_torches(node: Node3D, width: float, frame_size: Vector3) -> void:
	var side_w := (width - frame_size.x) * 0.5
	var on_filler := side_w >= 0.55
	var inward := node.transform.basis.z
	for s: float in [-1.0, 1.0]:
		var x := frame_size.x * 0.5 + 0.45 + (0.0 if on_filler else maxf(side_w, 0.0))
		var z := (DOOR_WALL_DEPTH * 0.5 if on_filler else 0.15) + 0.08
		var p := node.transform * Vector3(s * x, 0.0, z)
		var front := world_to_cell(p + inward * 0.5)
		var back := world_to_cell(p - inward * 0.4)
		if not gen.is_floor(front.x, front.y) or not (on_filler or gen.is_wall(back.x, back.y)):
			continue
		var taken := false
		for t in _torches:
			taken = taken or t.position.distance_to(p) < 1.2
		if not taken:
			_torches.append(DungeonDecor.torch(self, p, inward, false))


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
		# Chaque battant pivote sur ses gonds vers l'intérieur de la salle (selon le côté où il s'étend).
		var mi := leaves[k] as MeshInstance3D
		var extends_right := mi == null or mi.get_aabb().get_center().x > 0.0
		var target := deg_to_rad(95.0 if extends_right else -95.0)
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
		var pos := _grid_origin() + Vector3((r.position.x + r.size.x * 0.5) * CELL, 0.03, (r.position.y + r.size.y * 0.5) * CELL)
		var cover := Visuals.box(self, size, pos, mat)
		cover.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_covers[i] = cover
		for e: Variant in _room_enemies.get(i, []):
			if is_instance_valid(e):
				(e as Enemy).set_dormant(true)


## Torches : rouge orangé tant que le héros n'est pas passé à moins de TORCH_SEEN_RADIUS d'elles, flamme normale
## ensuite (pour de bon, même après un aller-retour en ville) : on sait d'un coup d'œil où l'on est déjà venu.
## Une torche encore cachée dans une salle fermée ne compte pas.
const TORCH_SEEN_RADIUS := 15.0


func _assign_torches() -> void:
	for i in _torches.size():
		DungeonDecor.set_torch_alarm(_torches[i], not _state_has("torches", i))


func _update_torches() -> void:
	if hero == null:
		return
	var h := hero.global_position
	for i in _torches.size():
		var t := _torches[i]
		if not is_instance_valid(t) or not t.is_visible_in_tree() or _state_has("torches", i):
			continue
		if Vector2(t.global_position.x - h.x, t.global_position.z - h.z).length() <= TORCH_SEEN_RADIUS:
			_state_add("torches", i)
			DungeonDecor.set_torch_alarm(t, false, true)


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
	if not persistent:
		# Cryptes : le portail bleu ramène à la taverne, et les cryptes se régénéreront.
		var exit := Portal.new()
		exit.blue = true
		var spot := hero.global_position + hero.facing * 1.8
		exit.position = Vector3(spot.x, 0.0, spot.z) if is_walkable(spot) else hero.global_position
		exit.prompt = "Portail bleu : retour à la taverne (les cryptes se régénéreront)"
		exit.on_enter = _end_dungeon.bind("Retour par le portail bleu", false)
		add_child(exit)
		return
	var p := hero.global_position + hero.facing * 1.8
	if not is_walkable(p):
		p = hero.global_position
	p.y = 0.0
	_spawn_town_portal(p)
	GameState.town_portal = {"pos": [snappedf(p.x, 0.01), snappedf(p.z, 0.01)]}
	Events.notify("Un portail bleu s'ouvre vers la Chèvre Fringante.", Color(0.5, 0.75, 1.0))


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


## Scène où l'on revient en quittant le donjon : la taverne (au cercle de runes), ou le parvis du Temple du Dragon.
func _exit_scene() -> String:
	if theme == "temple":
		GameState.flags["temple_spawn"] = "parvis"
		return Router.TEMPLE
	GameState.flags["in_dungeon"] = true
	return Router.TAVERN


# =====================================================================================
# Thèmes « crypte » et « temple » : lave, démons, nef de l'ange déchu
# =====================================================================================

## Ruisseaux de lave (zones au sol, plan XZ) : on s'y brûle.
var _lava_zones: Array[Rect2] = []
var _burn_timer := 0.0
var angel: FallenAngel
var guardian: DemonBrute
var _ambush: Array[Enemy] = []
var _ambush_state := 0 # 0 = pas encore, 1 = en cours, 2 = terminée


func in_lava(p: Vector3) -> bool:
	for z in _lava_zones:
		if z.has_point(Vector2(p.x, p.z)):
			return true
	return false


## Cryptes : os, piliers brisés, tonneaux, et des ruisseaux de lave en fusion qui traversent les salles d'un mur à
## l'autre (un ou deux ponts de pierre pour passer).
func _decorate_crypt() -> void:
	for i in gen.rooms.size():
		if i == gen.boss_room or i == gen.start_room:
			continue
		if _rng.randf() < 0.75:
			_lava_room(i)
		for k in _rng.randi_range(3, 6):
			var p := cell_to_world(gen.random_cell_in_room(i, 2)) + Vector3(_rng.randf_range(-0.6, 0.6), 0, _rng.randf_range(-0.6, 0.6))
			if not in_lava(p):
				_decor([0, 0, 2, 3][_rng.randi() % 4], p)


func _lava_room(i: int) -> void:
	var r := gen.rooms[i]
	var horizontal := r.size.x >= r.size.y # le ruisseau suit le grand côté de la salle
	# Rangée intérieure qui ne débouche pas devant une porte des deux murs qu'elle touche.
	var blocked := {}
	for o in gen.room_openings(i):
		var out: Vector2i = o["out"]
		if (horizontal and out.x != 0) or (not horizontal and out.y != 0):
			var c: Vector2i = o["cell"]
			var first := c.y if horizontal else c.x
			for k in range(first - 1, first + int(o["length"]) + 1):
				blocked[k] = true
	var lo := (r.position.y if horizontal else r.position.x) + 2
	var hi := (r.end.y if horizontal else r.end.x) - 3
	var rows: Array[int] = []
	for k in range(lo, hi + 1):
		if not blocked.has(k):
			rows.append(k)
	if rows.is_empty():
		return
	var row: int = rows[_rng.randi() % rows.size()]
	var dir := Vector3(1, 0, 0) if horizontal else Vector3(0, 0, 1)
	var a := cell_to_world(Vector2i(r.position.x, row) if horizontal else Vector2i(row, r.position.y)) - dir * (CELL * 0.5)
	var b := cell_to_world(Vector2i(r.end.x - 1, row) if horizontal else Vector2i(row, r.end.y - 1)) + dir * (CELL * 0.5)
	var length := (b - a).length()
	var count := 1 if length < 18.0 else 2
	var stone := Visuals.mat(Color(0.16, 0.13, 0.12), 0.9)
	var t := 0.0
	for k in count:
		var bc := length * (k + 1) / (count + 1) + _rng.randf_range(-1.5, 1.5)
		if bc - 1.1 - t > 0.3:
			_lava_zones.append(DungeonThemes.lava_stream(self, a + dir * t, a + dir * (bc - 1.1)))
		DungeonThemes.bridge(self, a + dir * bc, dir.cross(Vector3.UP), stone)
		t = bc + 1.1
	if length - t > 0.3:
		_lava_zones.append(DungeonThemes.lava_stream(self, a + dir * t, b))


## Le héros marche dans la lave : 1d4 + niveau de brûlure toutes les demi-secondes (pas pendant une glissade).
func _update_lava(delta: float) -> void:
	_burn_timer -= delta
	if _lava_zones.is_empty() or _burn_timer > 0.0 or hero.dead or hero.dashing or hero.leaping:
		return
	var p := Vector2(hero.global_position.x, hero.global_position.z)
	for z in _lava_zones:
		if z.grow(-0.15).has_point(p):
			_burn_timer = 0.5
			hero.take_hit(Dice.roll(1, 4, enemy_level), hero.global_position)
			DamageNumber.spawn(self, hero.global_position + Vector3(0, 2.6, 0), "Lave !", Color(1.0, 0.5, 0.1))
			return


## Temple : vitraux, colonnes, candélabres et restes d'os ; la nef (salle de départ) a sa fontaine et ses bancs.
func _decorate_temple() -> void:
	_place_stained_glass()
	_build_nave()
	var stone := Visuals.mat(Color(0.38, 0.36, 0.34), 0.85)
	for i in gen.rooms.size():
		if i == gen.start_room or i == gen.boss_room:
			continue
		var r := gen.rooms[i]
		var c := cell_to_world(gen.center(i))
		var half := Vector3((r.size.x * 0.5 - 2.0) * CELL, 0, (r.size.y * 0.5 - 2.0) * CELL)
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				DungeonThemes.column(self, c + Vector3(half.x * sx, 0, half.z * sz), stone)
		for k in _rng.randi_range(1, 3):
			DungeonThemes.candelabra(self, cell_to_world(gen.random_cell_in_room(i, 2)) + Vector3(0.5, 0, 0.5))
		for k in _rng.randi_range(1, 3):
			_decor(0, cell_to_world(gen.random_cell_in_room(i, 2)))


## Vitraux sur les murs du fond (visibles depuis la caméra), espacés de 7 m, loin des torches.
func _place_stained_glass() -> void:
	var placed: Array[Vector3] = []
	var dirs: Array[Vector2i] = [Vector2i(0, -1), Vector2i(-1, 0)]
	for y in gen.height:
		for x in gen.width:
			if not gen.is_floor(x, y) or _room_at(cell_to_world(Vector2i(x, y))) < 0:
				continue
			for d in dirs:
				if not gen.is_wall(x + d.x, y + d.y):
					continue
				var p := cell_to_world(Vector2i(x, y)) + Vector3(d.x, 0, d.y) * (CELL * 0.5 - 0.05)
				var ok := true
				for q in placed:
					ok = ok and q.distance_to(p) >= 7.0
				for t in _torches:
					ok = ok and t.position.distance_to(p) >= 1.6
				if ok:
					placed.append(p)
					DungeonThemes.stained_glass(self, p, -Vector3(d.x, 0, d.y), _rng)


## Axe de la nef (salle de départ du temple) : de l'entrée (côté caméra) vers le fond, le long du grand côté.
func _nave_axis() -> Vector3:
	var r := gen.rooms[gen.start_room]
	return Vector3(-1, 0, 0) if r.size.x >= r.size.y else Vector3(0, 0, -1)


func _nave_side() -> Vector3:
	return Vector3(0, 0, 1) if absf(_nave_axis().x) > 0.5 else Vector3(1, 0, 0)


func _nave_half_length() -> float:
	var r := gen.rooms[gen.start_room]
	return maxi(r.size.x, r.size.y) * CELL * 0.5


func _nave_entrance() -> Vector3:
	return cell_to_world(gen.center(gen.start_room)) - _nave_axis() * (_nave_half_length() - 2.5)


## Nef : allée centrale (tapis rouge) avec, au milieu, la fontaine de sang de l'ange déchu ; bancs de part et d'autre
## entre l'entrée et la fontaine, candélabres le long de l'allée.
func _build_nave() -> void:
	var c := cell_to_world(gen.center(gen.start_room))
	var axis := _nave_axis()
	var side := _nave_side()
	var half := _nave_half_length()
	DungeonThemes.blood_fountain(self, c, -axis)
	var carpet := Visuals.box(self, Vector3(1.6, 0.02, half * 2.0 - 1.0), c + Vector3(0, 0.012, 0), Visuals.mat(Color(0.4, 0.03, 0.04), 0.95))
	carpet.rotation.y = atan2(axis.x, axis.z)
	carpet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var d := 4.0
	while d < half - 3.0:
		for s: float in [-1.0, 1.0]:
			DungeonThemes.pew(self, c - axis * d + side * s * 2.1, atan2(axis.x, axis.z))
		d += 1.5
	for k in 3:
		for s: float in [-1.0, 1.0]:
			DungeonThemes.candelabra(self, c + axis * (3.5 + k * 3.0) + side * s * 2.2)


## « Une fois passé la fontaine » : une dizaine de diablotins fondent sur le héros depuis le fond de la nef. Quand le
## dernier tombe, un éclair frappe la fontaine dans un coup de tonnerre.
func _update_nave_ambush() -> void:
	if theme != "temple" or _ambush_state == 2:
		return
	if _ambush_state == 0:
		if bool(_state.get("ambush_done", false)):
			_ambush_state = 2
		elif (hero.global_position - cell_to_world(gen.center(gen.start_room))).dot(_nave_axis()) > -1.0:
			_start_nave_ambush()
		return
	for e in _ambush:
		if is_instance_valid(e) and e.is_alive():
			return
	_ambush_state = 2
	_state["ambush_done"] = true
	_thunderclap(cell_to_world(gen.center(gen.start_room)) + Vector3(0, 6.5, 0))
	Events.notify("Un éclair déchire la voûte et frappe la fontaine dans un coup de tonnerre !", Color(0.75, 0.8, 1.0))


func _start_nave_ambush() -> void:
	_ambush_state = 1
	var far := cell_to_world(gen.center(gen.start_room)) + _nave_axis() * (_nave_half_length() - 2.0)
	var n := _coop_count(10)
	Sfx.play("croak", -2.0, 0.5)
	Events.camera_shake.emit(0.15, 0.6)
	Events.notify("Des ailes claquent sous la voûte... Une nuée de démons fond sur vous, hachettes levées !", Events.COLOR_BAD)
	for k in n:
		var imp := DemonImp.new()
		imp.level = enemy_level
		imp.position = far + _nave_side() * (-4.5 + 9.0 * k / maxf(1.0, n - 1.0)) + _nave_axis() * _rng.randf_range(-1.0, 0.5)
		imp.rotation.y = atan2(-_nave_axis().x, -_nave_axis().z)
		imp.walkable_check = is_walkable
		add_child(imp)
		imp.call_deferred("_aggro")
		_ambush.append(imp)


## Éclair tombé du ciel sur `pos`, avec coup de tonnerre et flash.
func _thunderclap(pos: Vector3) -> void:
	Sfx.play("solo_thunder", 0.0)
	Events.screen_flash.emit(Color(0.85, 0.9, 1.0, 0.7), 0.35)
	Events.camera_shake.emit(0.35, 0.5)
	ArcBolt.spawn(self, pos + Vector3(0.6, 14.0, -0.6), pos, 0.35, 0.6, Color(0.8, 0.85, 1.0))


## Salles des thèmes « crypte » et « temple » : squelettes, diablotins, démons cornus (et rats dans les cryptes).
## Les salles cul-de-sac cachent une embuscade (deux démons cornus et une nuée de diablotins) autour d'un coffre.
func _spawn_demon_rooms() -> void:
	for i in gen.rooms.size():
		if i == gen.boss_room or i == gen.start_room:
			continue
		if gen.ambush_rooms.has(i):
			for k in _coop_count(10):
				var p := cell_to_world(gen.random_cell_in_room(i, 1))
				if k < 2:
					_spawn_brute(p, i)
				else:
					_spawn_imp(p, i)
			_spawn_chest(cell_to_world(gen.center(i)), gen.ambush_rooms.find(i))
			continue
		for k in _coop_count(_rng.randi_range(3, 5)):
			var p := cell_to_world(gen.random_cell_in_room(i, 2))
			var roll := _rng.randf()
			if roll < 0.4:
				_spawn_skeleton(p, roll < 0.06, i)
			elif roll < 0.75:
				_spawn_imp(p, i)
			elif roll < 0.88 and theme == "crypte":
				_spawn_rat(p, i)
			else:
				_spawn_brute(p, i)


func _spawn_imp(pos: Vector3, room: int = -1) -> DemonImp:
	var e := DemonImp.new()
	e.level = enemy_level
	e.position = pos
	e.rotation.y = _rng.randf() * TAU
	e.walkable_check = is_walkable
	return _place_enemy(e, room) as DemonImp


func _spawn_brute(pos: Vector3, room: int = -1, is_guardian: bool = false) -> DemonBrute:
	var e := DemonBrute.new()
	e.guardian = is_guardian
	e.level = enemy_level
	e.position = pos
	e.rotation.y = _rng.randf() * TAU
	e.walkable_check = is_walkable
	return _place_enemy(e, room) as DemonBrute


func _spawn_imp_minion(pos: Vector3) -> void:
	var e := _spawn_imp(pos if is_walkable(pos) else cell_to_world(gen.center(gen.boss_room)))
	e.call_deferred("_aggro")


## Cryptes : au fond, le Gardien des Cryptes (démon cornu géant) et ses diablotins gardent le portail de sortie, qui
## ramène au portail démoniaque de la taverne.
func _spawn_crypt_exit() -> void:
	var c := cell_to_world(gen.center(gen.boss_room))
	for k in 4:
		var a := TAU * k / 4.0 + PI * 0.25
		var p := c + Vector3(cos(a), 0, sin(a)) * 6.2
		Visuals.cylinder(self, 0.35, 0.2, 0.9, p + Vector3(0, 0.45, 0), Visuals.mat(Color(0.15, 0.13, 0.12), 0.5, 0.6), Vector3.ZERO, 8)
		Visuals.sphere(self, 0.25, p + Vector3(0, 1.0, 0), Visuals.glow_mat(Color(1.0, 0.4, 0.1), 5.0), Vector3(1, 0.6, 1))
		Visuals.flicker_light(self, p + Vector3(0, 1.6, 0), Color(1.0, 0.45, 0.15), 2.0, 8.0)
		Visuals.solid_cylinder(self, 0.35, 2.0, p + Vector3(0, 1.0, 0))
	var exit := DemonPortal.new()
	exit.position = c + Vector3(0, 0, -3.0)
	exit.prompt = "Sortie des Cryptes : retour au portail de la Chèvre Fringante"
	exit.on_enter = _end_dungeon.bind("Cryptes traversées !", true)
	add_child(exit)
	guardian = _spawn_brute(c + Vector3(0, 0, 1.5), gen.boss_room, true)
	for k in _coop_count(3):
		_spawn_imp(c + Vector3(-3.0 + 3.0 * k, 0, 3.0), gen.boss_room)


## Temple : la salle de l'ange déchu (colonnes, cercle de candélabres) ; il garde la partition maudite.
func _spawn_angel_room() -> void:
	var r := gen.rooms[gen.boss_room]
	var c := cell_to_world(gen.center(gen.boss_room))
	var stone := Visuals.mat(Color(0.38, 0.36, 0.34), 0.85)
	var half := Vector3((r.size.x * 0.5 - 2.0) * CELL, 0, (r.size.y * 0.5 - 2.0) * CELL)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			DungeonThemes.column(self, c + Vector3(half.x * sx, 0, half.z * sz), stone)
	for k in 6:
		var a := TAU * k / 6.0
		DungeonThemes.candelabra(self, c + Vector3(cos(a), 0, sin(a)) * 6.5)
	Events.boss_defeated.connect(_on_angel_defeated)
	if bool(_state.get("boss_dead", false)):
		if not GameState.quest_items.has("partition_maudite"):
			Pickup.spawn(self, c, "quest", 0, "partition_maudite")
		elif GameState.quest_state(quest_id) == QuestDB.State.OBJECTIVE_DONE:
			_spawn_temple_exit(c + Vector3(2.0, 0, 2.0))
		return
	angel = FallenAngel.new()
	angel.level = enemy_level
	angel.position = c
	angel.rotation.y = PI * 0.25
	angel.walkable_check = is_walkable
	angel.spawn_minion = _spawn_imp_minion
	add_child(angel)
	_room_enemies[gen.boss_room] = [angel]


func _on_angel_defeated(boss_id: String) -> void:
	if boss_id != "ange_dechu":
		return
	_state["boss_dead"] = true
	if hero != null:
		hero.model.victory()
	Events.notify("L'ange déchu s'effondre. Sur son corps, une partition crépite d'éclairs...", Events.COLOR_GOLD)


## La partition maudite est ramassée : objectif accompli, un portail ramène sur le parvis, auprès de Back Jlack.
func _on_quest_item_added(id: String) -> void:
	if theme != "temple" or id != "partition_maudite":
		return
	GameState.complete_objective(quest_id)
	var p := hero.global_position + hero.facing * 1.8 if hero != null else cell_to_world(gen.center(gen.boss_room))
	_spawn_temple_exit(p if is_walkable(p) else cell_to_world(gen.center(gen.boss_room)))
	Events.notify("Un portail s'ouvre : Back Jlack vous attend sur le parvis du temple.", Events.COLOR_MAGIC)


func _spawn_temple_exit(p: Vector3) -> void:
	var portal := Portal.new()
	portal.position = Vector3(p.x, 0.0, p.z)
	portal.prompt = "Rejoindre Back Jlack sur le parvis du temple"
	portal.on_enter = _end_dungeon.bind("Le Temple du Dragon est purifié !", true)
	add_child(portal)
