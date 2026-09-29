class_name DungeonGenerator
extends RefCounted
## Génération procédurale d'un donjon sur une grille (logique pure, sans nœuds : testable).
##
## Algorithme :
##  1. Place la salle du boss (grande, 11×11) puis des salles aléatoires sans chevauchement.
##  2. Relie les salles normales par un arbre couvrant minimal (Prim) → tout est accessible.
##  3. Ajoute 1 ou 2 couloirs en boucle pour éviter un donjon trop linéaire.
##  4. Raccorde la salle du boss à UNE seule salle voisine (cul-de-sac final).
##  5. La salle de départ est la salle la plus éloignée du boss (distance de parcours BFS).

const EMPTY := 0
const FLOOR := 1

var width := 64
var height := 64
var grid := PackedByteArray()
var rooms: Array[Rect2i] = []
var boss_room := 0
var start_room := 0
var rng := RandomNumberGenerator.new()


func generate(seed_value: int, room_count: int = 10) -> void:
	rng.seed = seed_value
	grid.resize(width * height)
	grid.fill(EMPTY)
	rooms.clear()
	_place_rooms(room_count)
	for r in rooms:
		_carve_rect(r)
	_connect_rooms()
	start_room = _farthest_room_from_boss()


func _place_rooms(room_count: int) -> void:
	var attempts := 0
	while rooms.size() < room_count and attempts < 2000:
		attempts += 1
		var is_boss := rooms.is_empty()
		var w := 11 if is_boss else rng.randi_range(5, 9)
		var h := 11 if is_boss else rng.randi_range(5, 8)
		var r := Rect2i(rng.randi_range(2, width - w - 3), rng.randi_range(2, height - h - 3), w, h)
		var ok := true
		for other in rooms:
			if other.grow(3).intersects(r):
				ok = false
				break
		if ok:
			rooms.append(r)
	boss_room = 0


func _connect_rooms() -> void:
	# Arbre couvrant minimal (Prim) entre les salles normales (index 1..n).
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
		_carve_corridor(center(best_a), center(best_b))
		connected.append(best_b)
		remaining.erase(best_b)
	# Quelques boucles supplémentaires.
	if rooms.size() > 4:
		for i in 2:
			var a := rng.randi_range(1, rooms.size() - 1)
			var b := rng.randi_range(1, rooms.size() - 1)
			if a != b:
				_carve_corridor(center(a), center(b))
	# Salle du boss : reliée à la salle normale la plus proche.
	var nearest := 1
	var nd := INF
	for i in range(1, rooms.size()):
		var d := Vector2(center(i)).distance_to(Vector2(center(boss_room)))
		if d < nd:
			nd = d
			nearest = i
	_carve_corridor(center(nearest), center(boss_room))


func _carve_rect(r: Rect2i) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			set_cell(x, y, FLOOR)


## Couloir en L, large de 2 cases.
func _carve_corridor(a: Vector2i, b: Vector2i) -> void:
	var horizontal_first := rng.randf() < 0.5
	var corner := Vector2i(b.x, a.y) if horizontal_first else Vector2i(a.x, b.y)
	_carve_line(a, corner)
	_carve_line(corner, b)


func _carve_line(a: Vector2i, b: Vector2i) -> void:
	var p := a
	var step := Vector2i(signi(b.x - a.x), signi(b.y - a.y))
	while true:
		for oy in 2:
			for ox in 2:
				set_cell(p.x + ox, p.y + oy, FLOOR)
		if p == b:
			break
		p += step


func _farthest_room_from_boss() -> int:
	var dist := distance_field(center(boss_room))
	var best := 1
	var best_d := -1
	for i in range(1, rooms.size()):
		var c := center(i)
		var d := dist[c.y * width + c.x]
		if d > best_d:
			best_d = d
			best = i
	return best


## Distances de parcours (BFS, 4-voisinage) depuis une case. -1 = inaccessible.
func distance_field(from: Vector2i) -> PackedInt32Array:
	var dist := PackedInt32Array()
	dist.resize(width * height)
	dist.fill(-1)
	if not is_floor(from.x, from.y):
		return dist
	var queue: Array[Vector2i] = [from]
	dist[from.y * width + from.x] = 0
	var head := 0
	var dirs: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]
	while head < queue.size():
		var p := queue[head]
		head += 1
		var d := dist[p.y * width + p.x]
		for dir in dirs:
			var n := p + dir
			if is_floor(n.x, n.y) and dist[n.y * width + n.x] == -1:
				dist[n.y * width + n.x] = d + 1
				queue.append(n)
	return dist


func is_start_connected_to_boss() -> bool:
	var dist := distance_field(center(start_room))
	var b := center(boss_room)
	return dist[b.y * width + b.x] >= 0


# --- Accès à la grille ---------------------------------------------------------

func center(room_index: int) -> Vector2i:
	var r := rooms[room_index]
	return r.position + r.size / 2


func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < width and y < height


func is_floor(x: int, y: int) -> bool:
	return in_bounds(x, y) and grid[y * width + x] == FLOOR


func set_cell(x: int, y: int, value: int) -> void:
	if in_bounds(x, y):
		grid[y * width + x] = value


## Case vide touchant du sol (8-voisinage) → doit recevoir un bloc de mur.
func is_wall(x: int, y: int) -> bool:
	if is_floor(x, y):
		return false
	for oy in range(-1, 2):
		for ox in range(-1, 2):
			if is_floor(x + ox, y + oy):
				return true
	return false


func random_cell_in_room(room_index: int, margin: int = 1) -> Vector2i:
	var r := rooms[room_index]
	return Vector2i(rng.randi_range(r.position.x + margin, r.end.x - 1 - margin),
		rng.randi_range(r.position.y + margin, r.end.y - 1 - margin))
