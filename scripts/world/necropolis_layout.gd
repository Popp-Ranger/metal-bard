class_name NecropolisLayout
extends RefCounted
## Plan de la Nécropole (niveau test) sur une grille de cases de 4 m, la taille des pièces du Modular Dungeon Kit
## (Kenney) : logique pure, sans nœuds (testable). Une case = une dalle du kit ; les murs se posent sur les bords.
##
##  1. La salle du boss (6 × 6 cases, 24 m) puis des salles de 3 à 5 cases de côté, espacées d'au moins 2 cases.
##  2. Arbre couvrant minimal (Prim) entre les salles normales, plus une ou deux boucles.
##  3. La salle du boss n'est reliée qu'à la salle normale la plus proche (cul-de-sac final).
##  4. Couloirs en L larges d'une case (4 m).
##  5. Départ : la salle la plus éloignée du boss (distance de parcours).
## to_dungeon_grid() recopie le plan dans un DungeonGenerator (cases de 2 m) : le donjon s'en sert pour placer le
## héros, les ennemis, les portails et l'errance des monstres.

const BOSS_SIZE := 6

var width := 30
var height := 30
var cells := PackedByteArray()
var rooms: Array[Rect2i] = []
var boss_room := 0
var start_room := 0
var rng := RandomNumberGenerator.new()


func generate(seed_value: int, room_count: int = 8) -> void:
	rng.seed = seed_value
	cells.resize(width * height)
	cells.fill(0)
	rooms.clear()
	var attempts := 0
	while rooms.size() < room_count and attempts < 3000:
		attempts += 1
		var boss := rooms.is_empty()
		var w := BOSS_SIZE if boss else rng.randi_range(3, 5)
		var h := BOSS_SIZE if boss else rng.randi_range(3, 5)
		var r := Rect2i(rng.randi_range(1, width - w - 1), rng.randi_range(1, height - h - 1), w, h)
		var ok := true
		for other in rooms:
			if other.grow(2).intersects(r):
				ok = false
				break
		if ok:
			rooms.append(r)
	boss_room = 0
	for r in rooms:
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				_mark(x, y)
	_connect()
	start_room = _farthest_from_boss()


func _connect() -> void:
	var connected: Array[int] = [1]
	var remaining: Array[int] = []
	for i in range(2, rooms.size()):
		remaining.append(i)
	while not remaining.is_empty():
		var best_a := -1
		var best_b := -1
		var best_d := INF
		for a in connected:
			for b in remaining:
				var d := Vector2(center(a)).distance_to(Vector2(center(b)))
				if d < best_d:
					best_d = d
					best_a = a
					best_b = b
		_corridor(center(best_a), center(best_b))
		connected.append(best_b)
		remaining.erase(best_b)
	if rooms.size() > 4:
		for k in 2:
			var a := rng.randi_range(1, rooms.size() - 1)
			var b := rng.randi_range(1, rooms.size() - 1)
			if a != b:
				_corridor(center(a), center(b))
	var nearest := 1
	var nd := INF
	for i in range(1, rooms.size()):
		var d := Vector2(center(i)).distance_to(Vector2(center(boss_room)))
		if d < nd:
			nd = d
			nearest = i
	_corridor(center(nearest), center(boss_room))


## Couloir en L d'une case de large.
func _corridor(a: Vector2i, b: Vector2i) -> void:
	var corner := Vector2i(b.x, a.y) if rng.randf() < 0.5 else Vector2i(a.x, b.y)
	_line(a, corner)
	_line(corner, b)


func _line(a: Vector2i, b: Vector2i) -> void:
	var p := a
	var step := Vector2i(signi(b.x - a.x), signi(b.y - a.y))
	_mark(p.x, p.y)
	while p != b:
		p += step
		_mark(p.x, p.y)


func _farthest_from_boss() -> int:
	var dist := distances(center(boss_room))
	var best := 1
	var best_d := -1
	for i in range(1, rooms.size()):
		var c := center(i)
		var d := dist[c.y * width + c.x]
		if d > best_d:
			best_d = d
			best = i
	return best


## Distance de parcours (en cases) depuis `from` ; -1 = inaccessible.
func distances(from: Vector2i) -> PackedInt32Array:
	var dist := PackedInt32Array()
	dist.resize(width * height)
	dist.fill(-1)
	dist[from.y * width + from.x] = 0
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := c + d
			if is_floor(n.x, n.y) and dist[n.y * width + n.x] < 0:
				dist[n.y * width + n.x] = dist[c.y * width + c.x] + 1
				queue.append(n)
	return dist


## Toutes les cases de sol sont-elles accessibles depuis la salle de départ ?
func all_reachable() -> bool:
	var dist := distances(center(start_room))
	for i in cells.size():
		if cells[i] == 1 and dist[i] < 0:
			return false
	return true


func center(i: int) -> Vector2i:
	var r := rooms[i]
	return r.position + r.size / 2


func is_floor(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < width and y < height and cells[y * width + x] == 1


func _mark(x: int, y: int) -> void:
	if x >= 0 and y >= 0 and x < width and y < height:
		cells[y * width + x] = 1


## Salle qui contient la case (-1 = couloir).
func room_of(c: Vector2i) -> int:
	for i in rooms.size():
		if rooms[i].has_point(c):
			return i
	return -1


## Recopie le plan dans `gen` (cases de 2 m : une case du kit = 2 × 2 cases).
func to_dungeon_grid(gen: DungeonGenerator) -> void:
	gen.width = width * 2
	gen.height = height * 2
	gen.grid.resize(gen.width * gen.height)
	gen.grid.fill(DungeonGenerator.EMPTY)
	for y in height:
		for x in width:
			if is_floor(x, y):
				for oy in 2:
					for ox in 2:
						gen.set_cell(x * 2 + ox, y * 2 + oy, DungeonGenerator.FLOOR)
	gen.rooms.clear()
	for r in rooms:
		gen.rooms.append(Rect2i(r.position * 2, r.size * 2))
	gen.ambush_rooms.clear()
	gen.boss_room = boss_room
	gen.start_room = start_room
