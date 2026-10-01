extends SceneTree
## Crée les ressources de l'éditeur de taverne et convertit la taverne d'origine en scène modifiable :
##  - assets/levels/taverne_sols.tres et taverne_murs.tres : tuiles des GridMap (cases de 1 m) ;
##  - scenes/levels/pieces/taverne/*.tscn : pièces à glisser-déposer (mobilier, décor, points du jeu) ;
##  - scenes/levels/taverne.tscn (seulement avec l'argument « taverne ») : le Crâne Hurlant tel qu'il était
##    construit par le code (rez-de-chaussée, étage, sous-sol). ATTENTION : écrase la scène existante.
## Usage : Godot --headless --path . -s res://tools/levels/build_tavern_assets.gd [-- taverne]

const FLOORS := "res://assets/levels/taverne_sols.tres"
const WALLS := "res://assets/levels/taverne_murs.tres"
const PIECES := "res://scenes/levels/pieces/taverne/"
const TAVERNE := "res://scenes/levels/taverne.tscn"
const PLANK := 0
const TILES := 1

var _root: TavernMap
var _floor: GridMap
var _walls: GridMap


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/levels"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PIECES))
	_save(_floor_tiles(), FLOORS)
	_save(_wall_tiles(), WALLS)
	_pieces()
	if "taverne" in OS.get_cmdline_user_args():
		_taverne()
	quit()


func _save(res: Resource, path: String) -> void:
	var err := ResourceSaver.save(res, path)
	print("%s %s" % ["ÉCRIT" if err == OK else "ÉCHEC", path])


# --- Tuiles --------------------------------------------------------------------------------

## Maillage fait de boîtes [taille, position, matériau] (une surface par matériau).
func _merged(parts: Array) -> ArrayMesh:
	var tools := {}
	for part: Array in parts:
		var box := BoxMesh.new()
		box.size = part[0]
		var m: Material = part[2]
		if not tools.has(m):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			st.set_material(m)
			tools[m] = st
		(tools[m] as SurfaceTool).append_from(box, 0, Transform3D(Basis.IDENTITY, part[1]))
	var mesh := ArrayMesh.new()
	for st: SurfaceTool in tools.values():
		st.commit(mesh)
	return mesh


func _item(lib: MeshLibrary, id: int, item_name: String, parts: Array, shape_size: Vector3, shape_pos: Vector3) -> void:
	lib.create_item(id)
	lib.set_item_name(id, item_name)
	lib.set_item_mesh(id, _merged(parts))
	var shape := BoxShape3D.new()
	shape.size = shape_size
	lib.set_item_shapes(id, [shape, Transform3D(Basis.IDENTITY, shape_pos)])


func _floor_tiles() -> MeshLibrary:
	var lib := MeshLibrary.new()
	var a := Visuals.mat(Color(0.18, 0.135, 0.1), 0.8)
	var b := Visuals.mat(Color(0.22, 0.165, 0.12), 0.8)
	_item(lib, PLANK, "Plancher", [[Vector3(1.0, 0.1, 0.47), Vector3(0, -0.05, -0.25), a],
		[Vector3(1.0, 0.1, 0.47), Vector3(0, -0.05, 0.25), b], [Vector3(1.0, 0.08, 1.0), Vector3(0, -0.07, 0), Visuals.mat(Color(0.03, 0.02, 0.02))]],
		Vector3(1, 0.2, 1), Vector3(0, -0.1, 0))
	_item(lib, TILES, "Dalles", [[Vector3(0.96, 0.1, 0.96), Vector3(0, -0.05, 0), Visuals.mat(Color(0.2, 0.19, 0.19), 0.9)],
		[Vector3(1.0, 0.08, 1.0), Vector3(0, -0.07, 0), Visuals.mat(Color(0.08, 0.08, 0.08))]],
		Vector3(1, 0.2, 1), Vector3(0, -0.1, 0))
	return lib


## Murs posés sur le bord nord de leur case (z = -0,5), à tourner avec la touche S.
func _wall_tiles() -> MeshLibrary:
	var lib := MeshLibrary.new()
	var stone := Visuals.stone_material(false, Color(0.3, 0.27, 0.25))
	var cut := Visuals.stone_material(true, Color(0.32, 0.28, 0.25))
	var wood := Visuals.mat(Color(0.2, 0.11, 0.06), 0.8)
	var z := -0.5
	var cap := [Vector3(1.0, 0.2, 0.45), Vector3(0, 3.9, z), wood]
	_item(lib, TavernMap.WALL, "Mur", [[Vector3(1.0, 4.0, 0.4), Vector3(0, 2.0, z), stone], cap],
		Vector3(1.0, 4.0, 0.4), Vector3(0, 2.0, z))
	var pane := Visuals.glow_mat(Color(0.25, 0.35, 0.65), 0.9)
	_item(lib, TavernMap.WINDOW, "Fenêtre", [[Vector3(1.0, 1.1, 0.4), Vector3(0, 0.55, z), stone],
		[Vector3(1.0, 1.4, 0.4), Vector3(0, 3.3, z), stone], cap, [Vector3(1.0, 1.5, 0.04), Vector3(0, 1.85, z), pane],
		[Vector3(1.0, 0.08, 0.12), Vector3(0, 1.1, z), wood], [Vector3(1.0, 0.08, 0.12), Vector3(0, 1.85, z), wood],
		[Vector3(1.0, 0.08, 0.12), Vector3(0, 2.6, z), wood], [Vector3(0.08, 1.5, 0.12), Vector3(0.46, 1.85, z), wood],
		[Vector3(0.08, 1.5, 0.12), Vector3(-0.46, 1.85, z), wood]], Vector3(1.0, 4.0, 0.4), Vector3(0, 2.0, z))
	_item(lib, TavernMap.LOW_WALL, "Muret", [[Vector3(1.0, 0.9, 0.4), Vector3(0, 0.45, z), stone],
		[Vector3(1.0, 0.08, 0.45), Vector3(0, 0.9, z), wood]], Vector3(1.0, 3.0, 0.4), Vector3(0, 1.5, z))
	_item(lib, TavernMap.PARTITION, "Cloison", [[Vector3(1.0, 3.0, 0.25), Vector3(0, 1.5, z), cut]],
		Vector3(1.0, 3.0, 0.25), Vector3(0, 1.5, z))
	return lib


# --- Pièces à glisser-déposer ----------------------------------------------------------------

func _pieces() -> void:
	var files := ["table", "chaise", "comptoir", "etagere_bouteilles", "cheminee", "tonneau", "caisse", "pilier_lanterne",
		"lanterne", "tableau_des_quetes", "banniere", "tapis", "lit", "table_de_chevet", "malle", "grimoires", "orbe",
		"dormeur", "fantome", "ratelier", "torche", "ecriteau", "arrivee_du_heros", "cercle_de_runes", "portail_bleu",
		"portes_entree", "escalier_qui_monte", "escalier_qui_descend", "arrivee_escalier", "zone_entrainement",
		"mannequin", "mannequin_allie", "portail_demoniaque", "pnj"]
	for k in files.size():
		var m := TavernMarker.new()
		m.name = str(TavernMarker.NAMES[k])
		m.kind = k
		match k:
			TavernMarker.Kind.COMPTOIR:
				m.size = Vector2(11.0, 0.8)
			TavernMarker.Kind.ETAGERE:
				m.size = Vector2(4.0, 0.4)
			TavernMarker.Kind.TAPIS:
				m.size = Vector2(3.0, 2.0)
			TavernMarker.Kind.ZONE_ENTRAINEMENT:
				m.size = Vector2(10.0, 8.0)
			TavernMarker.Kind.ESCALIER_MONTANT:
				m.variant = 10
				m.text = "Monter"
			TavernMarker.Kind.ESCALIER_DESCENDANT:
				m.text = "Descendre"
			TavernMarker.Kind.ARRIVEE:
				m.text = "Nom du lieu"
			TavernMarker.Kind.ECRITEAU:
				m.text = "Écriteau"
				m.color = Color(0.9, 0.8, 0.6)
		var packed := PackedScene.new()
		packed.pack(m)
		_save(packed, PIECES + str(files[k]) + ".tscn")
		m.free()


# --- Conversion du Crâne Hurlant ---------------------------------------------------------------

func _own(n: Node) -> void:
	n.owner = _root
	for c in n.get_children():
		_own(c)


func _folder(folder_name: String) -> Node3D:
	var n := Node3D.new()
	n.name = folder_name
	_root.add_child(n)
	_own(n)
	return n


func _m(parent: Node3D, kind: int, pos: Vector3, yaw_deg: float = 0.0, props: Dictionary = {}) -> TavernMarker:
	var m := TavernMarker.new()
	m.name = str(props.get("name", TavernMarker.NAMES[kind]))
	m.kind = kind
	m.position = pos
	m.rotation_degrees.y = yaw_deg
	for key: String in props:
		if key != "name":
			m.set(key, props[key])
	parent.add_child(m, true)
	_own(m)
	return m


func _floor_rect(x0: int, x1: int, z0: int, z1: int, item: int) -> void:
	for z in range(z0, z1 + 1):
		for x in range(x0, x1 + 1):
			_floor.set_cell_item(Vector3i(x, 0, z), item)


## Mur sur le bord `side` ("n", "s", "e", "o") de la case (x, z).
func _wall(x: int, z: int, side: String, item: int) -> void:
	var yaw: float = {"n": 0.0, "o": PI * 0.5, "s": PI, "e": -PI * 0.5}[side]
	_walls.set_cell_item(Vector3i(x, 0, z), item, _walls.get_orthogonal_index_from_basis(Basis(Vector3.UP, yaw)))


## Rangée de murs le long de X (case z fixe) ou de Z (case x fixe), avec des cases de fenêtre.
func _row_x(z: int, x0: int, x1: int, side: String, item: int, windows: Array = [], skip: Array = []) -> void:
	for x in range(x0, x1 + 1):
		if not skip.has(x):
			_wall(x, z, side, TavernMap.WINDOW if windows.has(x) else item)


func _row_z(x: int, z0: int, z1: int, side: String, item: int, windows: Array = []) -> void:
	for z in range(z0, z1 + 1):
		_wall(x, z, side, TavernMap.WINDOW if windows.has(z) else item)


func _taverne() -> void:
	_root = TavernMap.new()
	_root.name = "Taverne"
	_floor = GridMap.new()
	_floor.name = "Sol"
	_floor.mesh_library = load(FLOORS)
	_floor.cell_size = Vector3(1, 1, 1)
	_floor.cell_center_y = false
	_root.add_child(_floor)
	_own(_floor)
	_walls = GridMap.new()
	_walls.name = "Murs"
	_walls.mesh_library = load(WALLS)
	_walls.cell_size = Vector3(1, 1, 1)
	_walls.cell_center_y = false
	_root.add_child(_walls)
	_own(_walls)
	# Murs d'enceinte dans les cases extérieures (ils ne se disputent jamais une case d'angle).
	# Rez-de-chaussée : 30 × 22 m, centré sur l'origine.
	_floor_rect(-15, 14, -11, 10, PLANK)
	_row_x(-12, -15, 14, "s", TavernMap.WALL, [-11, -10, 9, 10])
	_row_z(-16, -11, 10, "e", TavernMap.WALL, [-7, -6, 5, 6])
	_row_x(11, -15, 14, "n", TavernMap.LOW_WALL, [], [-2, -1, 0, 1]) # porte d'entrée
	_row_z(15, -11, 10, "o", TavernMap.LOW_WALL)
	# Étage : 26 × 12 m, décalé de 70 m vers le nord ; quatre chambres au fond.
	_floor_rect(-13, 12, -79, -68, PLANK)
	_row_x(-80, -13, 12, "s", TavernMap.WALL, [-10, -9, -4, -3, 2, 3, 8, 9])
	_row_z(-14, -79, -68, "e", TavernMap.WALL)
	_row_x(-67, -13, 12, "n", TavernMap.LOW_WALL)
	_row_z(13, -79, -68, "o", TavernMap.LOW_WALL)
	for x: int in [-6, 0, 6]:
		_row_z(x, -79, -74, "o", TavernMap.PARTITION)
	_row_x(-73, -13, 12, "n", TavernMap.LOW_WALL, [], [-10, -9, -4, -3, 2, 3, 8, 9]) # portes des chambres
	# Sous-sol : 26 × 16 m, décalé de 70 m vers l'est.
	_floor_rect(57, 82, -8, 7, TILES)
	_row_x(-9, 57, 82, "s", TavernMap.WALL)
	_row_z(56, -8, 7, "e", TavernMap.WALL)
	_row_x(8, 57, 82, "n", TavernMap.LOW_WALL)
	_row_z(83, -8, 7, "o", TavernMap.LOW_WALL)
	_ground(_folder("Rez-de-chaussee"))
	var up := _folder("Etage")
	var cellar := _folder("Sous-sol")
	_upstairs(up)
	_cellar(cellar)
	_link_stairs()
	var packed := PackedScene.new()
	packed.pack(_root)
	_save(packed, TAVERNE)
	_root.free()


var _stairs := {} # nom de l'escalier -> nom de son arrivée


func _ground(g: Node3D) -> void:
	_m(g, TavernMarker.Kind.APPARITION, Vector3(0, 0, 9.5), 180.0)
	_m(g, TavernMarker.Kind.PORTES, Vector3(0, 0, 11))
	_m(g, TavernMarker.Kind.CHEMINEE, Vector3(-14.3, 0, 0), 90.0)
	_m(g, TavernMarker.Kind.COMPTOIR, Vector3(1.0, 0, -7.5), 0.0, {"size": Vector2(11.0, 0.8)})
	_m(g, TavernMarker.Kind.ETAGERE, Vector3(1.0, 0, -10.6), 0.0, {"size": Vector2(9.0, 0.4)})
	for p: Vector3 in [Vector3(7.8, 0, -9.8), Vector3(8.8, 0, -9.8), Vector3(7.8, 0, -8.8)]:
		_m(g, TavernMarker.Kind.TONNEAU, p).scale = Vector3.ONE * 1.125
	var tables := [Vector3(-9.0, 0, -4.0), Vector3(-9.5, 0, 5.0), Vector3(-3.0, 0, 1.0),
		Vector3(3.0, 0, 1.5), Vector3(-2.5, 0, 7.0), Vector3(7.5, 0, 6.0)]
	for i in tables.size():
		_m(g, TavernMarker.Kind.TABLE, tables[i], 0.0, {"option": i == 3})
	for p: Vector3 in [Vector3(-6.0, 0, -1.5), Vector3(6.5, 0, -2.5), Vector3(0.5, 0, 5.0)]:
		_m(g, TavernMarker.Kind.PILIER_LANTERNE, p)
	_m(g, TavernMarker.Kind.LANTERNE, Vector3(-4.5, 2.8, -10.55))
	_m(g, TavernMarker.Kind.LANTERNE, Vector3(-14.55, 2.8, -3.0))
	_m(g, TavernMarker.Kind.LANTERNE, Vector3(-14.55, 2.8, 3.0))
	_m(g, TavernMarker.Kind.ESCALIER_MONTANT, Vector3(13.4, 0, -4.4), 0.0,
		{"name": "Escalier_vers_etage", "variant": 10, "text": "Monter à l'étage (chambres)"})
	_m(g, TavernMarker.Kind.ESCALIER_DESCENDANT, Vector3(-12.0, 0, 6.4), 180.0,
		{"name": "Escalier_vers_sous_sol", "text": "Descendre au sous-sol (salle d'entraînement)"})
	_m(g, TavernMarker.Kind.ECRITEAU, Vector3(-12.0, 1.5, 7.0), 0.0, {"text": "Sous-sol — entraînement", "color": Color(0.9, 0.7, 0.4)})
	_m(g, TavernMarker.Kind.ARRIVEE, Vector3(12.4, 0, -3.2), 0.0, {"name": "Arrivee_depuis_etage", "text": "Le Crâne Hurlant"})
	_m(g, TavernMarker.Kind.ARRIVEE, Vector3(-10.2, 0, 5.8), 0.0, {"name": "Arrivee_depuis_sous_sol", "text": "Le Crâne Hurlant"})
	for p: Vector3 in [Vector3(-13.8, 0, 9.8), Vector3(-13.9, 0, 3.8), Vector3(10.0, 0, 9.8), Vector3(11.0, 0, 9.9)]:
		_m(g, TavernMarker.Kind.TONNEAU, p)
	_m(g, TavernMarker.Kind.CAISSE, Vector3(12.2, 0, 9.6), 20.0)
	_m(g, TavernMarker.Kind.TABLEAU, Vector3(-8.0, 0, -10.7))
	_m(g, TavernMarker.Kind.BANNIERE, Vector3(-14.75, 2.8, -9.0), 90.0)
	_m(g, TavernMarker.Kind.CERCLE_RUNES, Vector3(10.5, 0, -1.0))
	_m(g, TavernMarker.Kind.PORTAIL_BLEU, Vector3(6.9, 0, -1.6))
	_m(g, TavernMarker.Kind.PNJ, Vector3(1.0, 0, -9.1), 0.0, {"name": "Tavernier", "npc": 0})
	_m(g, TavernMarker.Kind.PNJ, Vector3(12.8, 0, 1.8), -120.0, {"name": "Zarathos", "npc": 1})
	_m(g, TavernMarker.Kind.PNJ, Vector3(-13.5, 0, -9.3), 45.0, {"name": "Inconnue", "npc": 2})
	_m(g, TavernMarker.Kind.PNJ, Vector3(-6.5, 0, 7.5), 80.0, {"name": "Gerald", "npc": 3})
	_stairs["Escalier_vers_etage"] = "Arrivee_etage"
	_stairs["Escalier_vers_sous_sol"] = "Arrivee_sous_sol"


func _upstairs(u: Node3D) -> void:
	var o := Vector3(0, 0, -70)
	_m(u, TavernMarker.Kind.TAPIS, o, 0.0, {"size": Vector2(22.0, 1.4), "color": Color(0.3, 0.07, 0.06)})
	for x: float in [-9.0, -1.0, 7.0]:
		_m(u, TavernMarker.Kind.LANTERNE, o + Vector3(x, 2.6, -3.3))
	_m(u, TavernMarker.Kind.ESCALIER_DESCENDANT, o + Vector3(10.2, 0, 0.5), -90.0,
		{"name": "Escalier_etage_vers_salle", "text": "Descendre à la salle commune"})
	_m(u, TavernMarker.Kind.ARRIVEE, o + Vector3(10.0, 0, 0.5), 0.0, {"name": "Arrivee_etage", "text": "L'étage — Chambres"})
	_stairs["Escalier_etage_vers_salle"] = "Arrivee_depuis_etage"
	var names := ["Chambre 1 — Zarathos", "Chambre 2 — la vôtre", "Chambre 3 — occupée", "Chambre 4 — hantée ?"]
	for i in 4:
		var cx := -9.0 + i * 6.0
		var c := o + Vector3(cx, 0, -6.0)
		var bed := c + Vector3(-1.3, 0, -1.6)
		_m(u, TavernMarker.Kind.LIT, bed, 0.0, {"variant": i, "option": i == 1})
		_m(u, TavernMarker.Kind.MALLE, c + Vector3(1.6, 0, -2.2))
		_m(u, TavernMarker.Kind.CHEVET, c + Vector3(0.0, 0, -2.4))
		_m(u, TavernMarker.Kind.TAPIS, c + Vector3(0.6, 0, 0.6), 0.0,
			{"size": Vector2(2.0, 1.4), "color": (TavernDecor.BLANKETS[(i + 1) % 4] as Color).darkened(0.3)})
		_m(u, TavernMarker.Kind.ECRITEAU, o + Vector3(cx, 1.6, -2.7), 0.0, {"text": names[i], "color": Color(0.9, 0.8, 0.6)})
		match i:
			0:
				_m(u, TavernMarker.Kind.GRIMOIRES, c + Vector3(1.5, 0.62, -2.2))
				_m(u, TavernMarker.Kind.ORBE, c + Vector3(1.9, 0.75, 1.0))
			2:
				_m(u, TavernMarker.Kind.DORMEUR, bed, 0.0, {"variant": 2})
			3:
				_m(u, TavernMarker.Kind.FANTOME, c + Vector3(0.5, 0, 0.0))


func _cellar(s: Node3D) -> void:
	var o := Vector3(70, 0, 0)
	_m(s, TavernMarker.Kind.ZONE_ENTRAINEMENT, o, 0.0, {"size": Vector2(28.0, 18.0)})
	for p: Vector3 in [Vector3(-7, 2.2, -7.7), Vector3(1, 2.2, -7.7), Vector3(9, 2.2, -7.7)]:
		_m(s, TavernMarker.Kind.TORCHE, o + p)
	_m(s, TavernMarker.Kind.TORCHE, o + Vector3(-12.7, 2.2, 2.0), 90.0)
	for k in 4:
		_m(s, TavernMarker.Kind.TONNEAU, o + Vector3(-12.0, 0, 3.5 + k * 1.0)).scale = Vector3.ONE * 1.05
	for k in 3:
		_m(s, TavernMarker.Kind.RATELIER, o + Vector3(-9.0 + k * 1.6, 0, -7.4))
	_m(s, TavernMarker.Kind.ESCALIER_MONTANT, o + Vector3(-10.8, 0, -2.4), 0.0,
		{"name": "Escalier_sous_sol_vers_salle", "variant": 5, "text": "Remonter à la salle commune"})
	_m(s, TavernMarker.Kind.ARRIVEE, o + Vector3(-9.0, 0, -3.0), 0.0, {"name": "Arrivee_sous_sol", "text": "Le sous-sol — Salle d'entraînement"})
	_stairs["Escalier_sous_sol_vers_salle"] = "Arrivee_depuis_sous_sol"
	for p: Vector3 in [Vector3(-3.0, 0, -3.0), Vector3(-1.3, 0, -3.9), Vector3(-1.3, 0, -2.1), Vector3(10.0, 0, -3.0)]:
		_m(s, TavernMarker.Kind.MANNEQUIN, o + p, 45.0)
	_m(s, TavernMarker.Kind.ECRITEAU, o + Vector3(-2.0, 3.0, -3.0), 0.0, {"text": "Cibles groupées — sorts de zone", "color": Color(1.0, 0.8, 0.45)})
	_m(s, TavernMarker.Kind.ECRITEAU, o + Vector3(10.0, 3.0, -3.0), 0.0, {"text": "Cible isolée", "color": Color(1.0, 0.8, 0.45)})
	_m(s, TavernMarker.Kind.MANNEQUIN_AMI, o + Vector3(3.5, 0, 4.0))
	_m(s, TavernMarker.Kind.ECRITEAU, o + Vector3(3.5, 3.1, 4.0), 0.0,
		{"text": "Les soins de groupe soignent tous les alliés proches", "color": Color(0.6, 1.0, 0.6)})
	_m(s, TavernMarker.Kind.PORTAIL_DEMONIAQUE, o + Vector3(9.5, 0, 4.2), -35.0)


## Relie chaque escalier à son arrivée (chemins relatifs, enregistrés dans la scène).
func _link_stairs() -> void:
	var by_name := {}
	for m in _root.markers():
		by_name[str(m.name)] = m
	for stairs: String in _stairs:
		var from: TavernMarker = by_name[stairs]
		var to: TavernMarker = by_name[_stairs[stairs]]
		from.destination = from.get_path_to(to)
