extends SceneTree
## Crée les ressources de l'éditeur de donjon et convertit un donjon généré en scène modifiable :
##  - assets/levels/donjon_tuiles.tres : tuiles de la GridMap (sol) ;
##  - scenes/levels/pieces/donjon/*.tscn : pièces à glisser-déposer (salle, ennemis, coffre, torche, décor) ;
##  - scenes/levels/catacombes.tscn (seulement avec l'argument « catacombes ») : le premier donjon, tiré du
##    générateur puis converti (sol, salles, ennemis, coffres, torches, décor), à retoucher dans l'éditeur.
##    ATTENTION : écrase la scène existante.
## Usage : Godot --headless --path . -s res://tools/levels/build_dungeon_assets.gd [-- catacombes]

const TILES := "res://assets/levels/donjon_tuiles.tres"
const PIECES := "res://scenes/levels/pieces/donjon/"
const CATACOMBES := "res://scenes/levels/catacombes.tscn"
const SEED := 4242
const CELL := 2.0

var _rng := RandomNumberGenerator.new()


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/levels"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PIECES))
	_save(_tiles(), TILES)
	_pieces()
	if "catacombes" in OS.get_cmdline_user_args():
		_catacombes()
	quit()


func _save(res: Resource, path: String) -> void:
	var err := ResourceSaver.save(res, path)
	print("%s %s" % ["ÉCRIT" if err == OK else "ÉCHEC", path])


## Tuile de sol : dalle de pierre de 2 × 2 m, dessus à hauteur 0.
func _tiles() -> MeshLibrary:
	var lib := MeshLibrary.new()
	var slab := BoxMesh.new()
	slab.size = Vector3(CELL, 0.2, CELL)
	slab.material = Visuals.textured("pierre_moussue", 4.0, Color(0.6, 0.6, 0.62))
	lib.create_item(0)
	lib.set_item_name(0, "Sol (dalles)")
	lib.set_item_mesh(0, slab)
	lib.set_item_mesh_transform(0, Transform3D(Basis.IDENTITY, Vector3(0, -0.1, 0)))
	return lib


func _pieces() -> void:
	var files := ["squelette", "capitaine", "chef_des_squelettes", "rat", "coffre", "torche", "os", "bave", "pilier", "tonneau"]
	for k in files.size():
		var m := DungeonMarker.new()
		m.name = str(DungeonMarker.NAMES[k]).get_slice(" (", 0)
		m.kind = k
		var packed := PackedScene.new()
		packed.pack(m)
		_save(packed, PIECES + str(files[k]) + ".tscn")
		m.free()
	var room := DungeonRoom.new()
	room.name = "Salle"
	var packed_room := PackedScene.new()
	packed_room.pack(room)
	_save(packed_room, PIECES + "salle.tscn")
	room.free()


func _own(n: Node, root: Node) -> void:
	n.owner = root
	for c in n.get_children():
		_own(c, root)


func _add(parent: Node, child: Node, root: Node) -> Node:
	parent.add_child(child, true)
	_own(child, root)
	return child


func _world(c: Vector2i) -> Vector3:
	return Vector3((c.x + 0.5) * CELL, 0.0, (c.y + 0.5) * CELL)


func _marker(parent: Node, root: Node, kind: int, pos: Vector3, yaw: float = 0.0) -> void:
	var m := DungeonMarker.new()
	m.name = str(DungeonMarker.NAMES[kind]).get_slice(" (", 0)
	m.kind = kind
	m.position = pos
	m.rotation.y = yaw
	_add(parent, m, root)


## Premier donjon : généré une fois (graine fixe), puis converti en scène à retoucher à la main.
func _catacombes() -> void:
	var gen := DungeonGenerator.new()
	gen.generate_sealed(SEED, 10, DungeonMap.DOOR_MAX_CELLS)
	_rng.seed = SEED
	var root := DungeonMap.new()
	root.name = "Catacombes"
	var grid := GridMap.new()
	grid.name = "Sol"
	grid.mesh_library = load(TILES)
	grid.cell_size = Vector3(CELL, 0.2, CELL)
	grid.cell_center_y = false
	_add(root, grid, root)
	for y in gen.height:
		for x in gen.width:
			if gen.is_floor(x, y):
				grid.set_cell_item(Vector3i(x, 0, y), DungeonMap.FLOOR_TILE)
	for i in gen.rooms.size():
		var r := gen.rooms[i]
		var room := DungeonRoom.new()
		room.kind = DungeonRoom.Kind.BOSS if i == gen.boss_room else (DungeonRoom.Kind.DEPART if i == gen.start_room else DungeonRoom.Kind.NORMALE)
		room.name = ["Salle", "Depart", "Salle_du_boss"][room.kind]
		room.size = r.size
		room.position = Vector3(r.position.x * CELL, 0.0, r.position.y * CELL)
		_add(root, room, root)
	var enemies := _add(root, Node3D.new(), root)
	enemies.name = "Ennemis"
	var decor := _add(root, Node3D.new(), root)
	decor.name = "Decor"
	var torches := _add(root, Node3D.new(), root)
	torches.name = "Torches"
	# Ennemis : comme le générateur (2 à 4 squelettes et 1 à 3 rats par salle, chef près du boss,
	# salles cul-de-sac gardées par une douzaine de squelettes autour d'un coffre).
	var chief_room := -1
	var best := INF
	for i in gen.rooms.size():
		if i == gen.boss_room or i == gen.start_room or gen.ambush_rooms.has(i):
			continue
		var d := Vector2(gen.center(i)).distance_to(Vector2(gen.center(gen.boss_room)))
		if d < best:
			best = d
			chief_room = i
	for i in gen.rooms.size():
		if i == gen.boss_room or i == gen.start_room:
			continue
		if gen.ambush_rooms.has(i):
			for k in 12:
				_marker(enemies, root, DungeonMarker.Kind.CAPITAINE if k < 2 else DungeonMarker.Kind.SQUELETTE,
					_world(gen.random_cell_in_room(i, 1)), _rng.randf() * TAU)
			_marker(enemies, root, DungeonMarker.Kind.COFFRE, _world(gen.center(i)))
			continue
		for k in _rng.randi_range(2, 4):
			_marker(enemies, root, DungeonMarker.Kind.SQUELETTE, _world(gen.random_cell_in_room(i, 2)), _rng.randf() * TAU)
		for k in _rng.randi_range(1, 3):
			_marker(enemies, root, DungeonMarker.Kind.RAT, _world(gen.random_cell_in_room(i, 1)), _rng.randf() * TAU)
		if i == chief_room:
			_marker(enemies, root, DungeonMarker.Kind.CHEF, _world(gen.center(i)), _rng.randf() * TAU)
		for k in _rng.randi_range(4, 7):
			var p := _world(gen.random_cell_in_room(i, 2)) + Vector3(_rng.randf_range(-0.6, 0.6), 0, _rng.randf_range(-0.6, 0.6))
			_marker(decor, root, DungeonMarker.Kind.OS + _rng.randi_range(0, 3), p)
	_torches(gen, torches, root)
	var packed := PackedScene.new()
	packed.pack(root)
	_save(packed, CATACOMBES)
	var problems := root.check()
	print("Vérification : ", "OK" if problems.is_empty() else str(problems))
	root.free()


## Torches murales espacées d'au moins 11 m, en priorité sur les murs du fond (comme dungeon.gd).
func _torches(gen: DungeonGenerator, parent: Node, root: Node) -> void:
	var candidates: Array[Array] = []
	var dirs: Array[Vector2i] = [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 0)]
	for y in gen.height:
		for x in gen.width:
			if not gen.is_floor(x, y):
				continue
			for d in dirs:
				if gen.is_wall(x + d.x, y + d.y):
					candidates.append([Vector2i(x, y), d])
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
			if (d.y < 0 or d.x < 0) != (pass_index == 0):
				continue
			var p := _world(cell) + Vector3(d.x, 0, d.y) * (CELL * 0.5 - 0.08)
			var too_close := false
			for q in placed:
				if q.distance_to(p) < 11.0:
					too_close = true
					break
			if too_close:
				continue
			placed.append(p)
			_marker(parent, root, DungeonMarker.Kind.TORCHE, p, atan2(-float(d.x), -float(d.y)))
