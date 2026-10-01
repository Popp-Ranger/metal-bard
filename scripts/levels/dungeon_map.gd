@tool
class_name DungeonMap
extends Node3D
## Donjon fait main, à construire dans l'éditeur de Godot (voir docs/EDITEUR_NIVEAUX.md) :
##  - GridMap « Sol » : on y peint le sol, case par case (cases de 2 m) ; les murs se posent tout seuls
##    autour du sol (aperçu en direct dans l'éditeur) ;
##  - salles (DungeonRoom, enfants directs) : portes, salles dans le noir, départ et salle du boss ;
##  - marqueurs (DungeonMarker, n'importe où dans la scène) : ennemis, coffres, torches, décor.
## En jeu, dungeon.gd lit cette scène (quête : clé "map" de QuestDB) et y branche toute la logique du
## donjon. F6 sur la scène lance directement le donjon pour le tester.

const FLOOR_TILE := 0
## Cases vides gardées autour du sol dans la grille du jeu (les murs s'y posent).
const MARGIN := 3
const DOOR_MAX_CELLS := 5

## Quête jouée quand on teste la scène avec F6.
@export var quest := "plumeau"
## Aperçu des murs automatiques dans l'éditeur.
@export var show_walls := true:
	set(value):
		show_walls = value
		_signature = -1
## Affiche dans la sortie (en bas de l'éditeur) les problèmes qui empêcheraient de jouer ce donjon.
@export_tool_button("Vérifier le donjon") var check_button := _print_check

var _walls: MultiMeshInstance3D
var _signature := -1
var _timer := 0.0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	set_process(false)
	if get_tree().current_scene == self:
		_play_test.call_deferred()


## GridMap où l'on peint le sol.
func floor_map() -> GridMap:
	return get_node_or_null("Sol") as GridMap


func rooms() -> Array[DungeonRoom]:
	var out: Array[DungeonRoom] = []
	for c in get_children():
		if c is DungeonRoom:
			out.append(c as DungeonRoom)
	return out


func markers() -> Array[DungeonMarker]:
	var out: Array[DungeonMarker] = []
	_collect(self, out)
	return out


func _collect(n: Node, out: Array[DungeonMarker]) -> void:
	for c in n.get_children():
		if c is DungeonMarker:
			out.append(c as DungeonMarker)
		_collect(c, out)


## Cases de sol peintes (repère de la GridMap : x, z).
func floor_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var grid := floor_map()
	if grid == null:
		return out
	for c: Vector3i in grid.get_used_cells():
		if c.y == 0 and grid.get_cell_item(c) >= 0:
			out.append(Vector2i(c.x, c.z))
	return out


## Remplit `gen` comme le ferait le générateur : grille de sol, salles, départ et boss.
## Renvoie le décalage à ajouter à une case de `gen` pour retrouver la case de la GridMap.
func read(gen: DungeonGenerator) -> Vector2i:
	var cells := floor_cells()
	var lo := Vector2i(1 << 20, 1 << 20)
	var hi := Vector2i(-(1 << 20), -(1 << 20))
	for c in cells:
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
		hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	for room in rooms():
		var r := room.rect()
		lo = Vector2i(mini(lo.x, r.position.x), mini(lo.y, r.position.y))
		hi = Vector2i(maxi(hi.x, r.end.x - 1), maxi(hi.y, r.end.y - 1))
	if cells.is_empty() and rooms().is_empty():
		lo = Vector2i.ZERO
		hi = Vector2i.ZERO
	var offset := lo - Vector2i(MARGIN, MARGIN)
	gen.width = hi.x - lo.x + 1 + MARGIN * 2
	gen.height = hi.y - lo.y + 1 + MARGIN * 2
	gen.grid.resize(gen.width * gen.height)
	gen.grid.fill(DungeonGenerator.EMPTY)
	for c in cells:
		gen.set_cell(c.x - offset.x, c.y - offset.y, DungeonGenerator.FLOOR)
	gen.rooms.clear()
	gen.ambush_rooms.clear()
	gen.boss_room = 0
	gen.start_room = 0
	for room in rooms():
		var r := room.rect()
		r.position -= offset
		gen.rooms.append(r)
		if room.kind == DungeonRoom.Kind.BOSS:
			gen.boss_room = gen.rooms.size() - 1
		elif room.kind == DungeonRoom.Kind.DEPART:
			gen.start_room = gen.rooms.size() - 1
	return offset


## Problèmes qui empêchent de jouer ce donjon (liste vide = tout va bien).
func check() -> Array[String]:
	var problems: Array[String] = []
	if floor_map() == null:
		return ["Il manque la GridMap « Sol » (enfant direct du donjon)."]
	if floor_cells().is_empty():
		problems.append("Aucune case de sol n'est peinte.")
	var starts := 0
	var bosses := 0
	var all := rooms()
	for i in all.size():
		var r := all[i].rect()
		match all[i].kind:
			DungeonRoom.Kind.DEPART:
				starts += 1
			DungeonRoom.Kind.BOSS:
				bosses += 1
				if r.size.x < 11 or r.size.y < 11:
					problems.append("La salle du boss doit faire au moins 11 × 11 cases (actuellement %d × %d)." % [r.size.x, r.size.y])
		for j in range(i + 1, all.size()):
			if r.intersects(all[j].rect()):
				problems.append("Les salles « %s » et « %s » se chevauchent." % [all[i].name, all[j].name])
		var holes := 0
		var grid := floor_map()
		for z in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				if grid.get_cell_item(Vector3i(x, 0, z)) < 0:
					holes += 1
		if holes > 0:
			problems.append("La salle « %s » a %d case(s) sans sol (bouton « Peindre le sol de la salle »)." % [all[i].name, holes])
	if starts != 1:
		problems.append("Il faut exactement une salle de départ (il y en a %d)." % starts)
	if bosses != 1:
		problems.append("Il faut exactement une salle du boss (il y en a %d)." % bosses)
	var chiefs := 0
	var gen := DungeonGenerator.new()
	var offset := read(gen)
	for m in markers():
		if m.kind == DungeonMarker.Kind.CHEF:
			chiefs += 1
		var p := local_transform(m).origin
		var c := Vector2i(floori(p.x / DungeonDecor.CELL), floori(p.z / DungeonDecor.CELL)) - offset
		if m.kind != DungeonMarker.Kind.TORCHE and not gen.is_floor(c.x, c.y):
			problems.append("« %s » (%s) n'est pas posé sur du sol." % [m.name, DungeonMarker.NAMES[m.kind]])
	if chiefs != 1:
		problems.append("Il faut exactement un chef des squelettes, qui porte la clé de la salle du boss (il y en a %d)." % chiefs)
	if starts == 1 and bosses == 1 and problems.is_empty():
		if not gen.is_start_connected_to_boss():
			problems.append("La salle du boss n'est pas reliée à la salle de départ.")
		elif not gen.all_rooms_reachable_without_boss_room():
			problems.append("Certaines salles ne sont accessibles qu'en traversant la salle du boss (scellée).")
		if not gen.boss_room_sealable(DOOR_MAX_CELLS):
			problems.append("Les entrées de la salle du boss doivent faire au plus %d cases de large (pour la porte scellée)." % DOOR_MAX_CELLS)
	return problems


func _print_check() -> void:
	var problems := check()
	if problems.is_empty():
		print("Donjon « %s » : tout est bon, il est jouable (F6 pour le tester)." % name)
		return
	push_warning("Donjon « %s » : %d problème(s)." % [name, problems.size()])
	for p in problems:
		push_warning(" - " + p)


## F6 dans l'éditeur : nouvelle partie, quête en cours, et ce donjon à la place de celui de la quête.
## (Autoloads lus par leur chemin : ce script sert aussi aux outils lancés hors du jeu.)
func _play_test() -> void:
	var state := get_node("/root/GameState")
	state.call("new_game")
	(state.get("flags") as Dictionary)["intro_done"] = true
	state.call("accept_quest", quest)
	(state.get("flags") as Dictionary)["test_map"] = scene_file_path
	get_tree().change_scene_to_file(str(get_node("/root/Router").get("DUNGEON")))


# --- Aperçu des murs dans l'éditeur ---------------------------------------------------

func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 0.4
	var cells := floor_cells()
	var sig := cells.size() * 7919 + (1 if show_walls else 0)
	for c in cells:
		sig = (sig * 31 + c.x * 92821 + c.y) & 0x7fffffff
	if sig == _signature:
		return
	_signature = sig
	build_walls_preview()


## Aperçu des murs automatiques (appelé par l'éditeur ; public pour les captures de contrôle).
func build_walls_preview() -> void:
	var cells := floor_cells()
	if _walls != null:
		_walls.queue_free()
		_walls = null
	if not show_walls or cells.is_empty():
		return
	var floor_set := {}
	for c in cells:
		floor_set[c] = true
	var walls: Array[Vector2i] = []
	var seen := {}
	for c in cells:
		for oy in range(-1, 2):
			for ox in range(-1, 2):
				var n := c + Vector2i(ox, oy)
				if not floor_set.has(n) and not seen.has(n):
					seen[n] = true
					walls.append(n)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var block := BoxMesh.new()
	block.size = Vector3(DungeonDecor.CELL, DungeonDecor.WALL_HEIGHT, DungeonDecor.CELL)
	mm.mesh = block
	mm.instance_count = walls.size()
	for i in walls.size():
		var p := Vector3((walls[i].x + 0.5) * DungeonDecor.CELL, DungeonDecor.WALL_HEIGHT * 0.5, (walls[i].y + 0.5) * DungeonDecor.CELL)
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, p))
	_walls = MultiMeshInstance3D.new()
	_walls.multimesh = mm
	_walls.material_override = Visuals.mat(Color(0.3, 0.29, 0.32), 0.9)
	add_child(_walls, false, Node.INTERNAL_MODE_FRONT)


## Transform d'un nœud dans le repère du donjon (sans passer par la scène : marche aussi hors de l'arbre).
func local_transform(n: Node3D) -> Transform3D:
	var t := n.transform
	var p := n.get_parent() as Node3D
	while p != null and p != self:
		t = p.transform * t
		p = p.get_parent() as Node3D
	return t
