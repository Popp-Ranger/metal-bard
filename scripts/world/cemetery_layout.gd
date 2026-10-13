class_name CemeteryLayout
extends RefCounted
## Plan du Cimetière maudit (niveau test), sur une grille de cases de 4 m (logique pure, testable) :
##  • le cimetière, à l'air libre (cases x de 0 à cw - 1) : une allée principale de la grille d'entrée (sud) au
##    grand mausolée (nord), des allées secondaires tirées au hasard, et entre elles des carrés (plots) ;
##  • les catacombes sous le mausolée (NecropolisLayout, décalées vers l'est de CATA_GAP cases) : salles, couloirs et
##    la crypte du Roi des Os (salle du boss). On y descend par la porte du mausolée.
## Coordonnées « globales » : une même grille pour les deux zones (cases hors zone = vide).

const CATA_GAP := 10
## Sud = vers la caméra : la grille d'entrée est au sud, le mausolée au nord.

var cw := 13
var ch := 11
## Colonne de l'allée principale (de la grille d'entrée au mausolée).
var main_x := 6
## Cases d'allée (cimetière) : 1 = allée.
var alley := PackedByteArray()
## Carrés entre les allées : [{cells: Array[Vector2i], rect: Rect2i, kind: String}].
var plots: Array[Dictionary] = []
## Emplacement réservé au mausolée (cases), au nord de l'allée principale.
var mausoleum := Rect2i()
var cata := NecropolisLayout.new()
var cata_offset := Vector2i.ZERO
var width := 0
var height := 0
var cells := PackedByteArray()
## 1 = cimetière, 2 = catacombes.
var zone := PackedByteArray()
## Salles des catacombes en coordonnées globales ; `boss_rect`, `cata_start_rect` en font partie.
var cata_rooms: Array[Rect2i] = []
var boss_rect := Rect2i()
var cata_start_rect := Rect2i()
## Arrivée au cimetière (devant la grille d'entrée).
var start_rect := Rect2i()
var rng := RandomNumberGenerator.new()

const PLOT_KINDS := ["tombes", "tombes", "tombes", "fosses", "caveau", "bosquet", "chapelle", "fontaine"]


func generate(seed_value: int) -> void:
	rng.seed = seed_value
	cw = rng.randi_range(12, 15)
	ch = rng.randi_range(10, 12)
	main_x = cw / 2
	alley.resize(cw * ch)
	alley.fill(0)
	mausoleum = Rect2i(main_x - 1, 0, 3, 2)
	_alleys()
	_plots()
	start_rect = Rect2i(main_x - 1, ch - 2, 3, 2)
	# Catacombes : 6 salles (dont la crypte du boss).
	cata.width = 24
	cata.height = 24
	cata.generate(rng.randi_range(1, 999999), 6)
	cata_offset = Vector2i(cw + CATA_GAP, 0)
	width = cata_offset.x + cata.width
	height = maxi(ch, cata.height)
	cells.resize(width * height)
	cells.fill(0)
	zone.resize(width * height)
	zone.fill(0)
	for y in ch:
		for x in cw:
			cells[y * width + x] = 1
			zone[y * width + x] = 1
	for y in cata.height:
		for x in cata.width:
			if cata.is_floor(x, y):
				var g := Vector2i(x, y) + cata_offset
				cells[g.y * width + g.x] = 1
				zone[g.y * width + g.x] = 2
	cata_rooms.clear()
	for r in cata.rooms:
		cata_rooms.append(Rect2i(r.position + cata_offset, r.size))
	boss_rect = cata_rooms[cata.boss_room]
	cata_start_rect = cata_rooms[cata.start_room]


## Allées : l'allée principale, celle qui longe le mausolée, puis des allées tous les 3 ou 4 carreaux ; quelques
## tronçons sont retirés (sans jamais couper le réseau en deux).
func _alleys() -> void:
	var cols: Array[int] = [main_x]
	var x := main_x - rng.randi_range(3, 4)
	while x >= 1:
		cols.append(x)
		x -= rng.randi_range(3, 4)
	x = main_x + rng.randi_range(3, 4)
	while x <= cw - 2:
		cols.append(x)
		x += rng.randi_range(3, 4)
	var rows: Array[int] = [2, ch - 2]
	var y := 2 + rng.randi_range(3, 4)
	while y <= ch - 4:
		rows.append(y)
		y += rng.randi_range(3, 4)
	for c in cols:
		for yy in range(2, ch - 1):
			_set_alley(c, yy)
	for r in rows:
		var x0: int = cols.min()
		var x1: int = cols.max()
		for xx in range(x0, x1 + 1):
			_set_alley(xx, r)
	for yy in range(2, ch):
		_set_alley(main_x, yy) # jusqu'à la grille d'entrée
	# Quelques tronçons retirés (jamais l'allée principale ni celle du mausolée).
	var segments: Array[Array] = []
	for c in cols:
		if c == main_x:
			continue
		var sorted := rows.duplicate()
		sorted.sort()
		for i in range(sorted.size() - 1):
			segments.append([Vector2i(c, int(sorted[i]) + 1), Vector2i(c, int(sorted[i + 1]) - 1)])
	for i in range(segments.size() - 1, 0, -1): # mélange tiré de la graine
		var j := rng.randi_range(0, i)
		var tmp: Array = segments[i]
		segments[i] = segments[j]
		segments[j] = tmp
	var removed := 0
	for s: Array in segments:
		if removed >= segments.size() / 3:
			break
		var a: Vector2i = s[0]
		var b: Vector2i = s[1]
		var backup := alley.duplicate()
		for yy in range(a.y, b.y + 1):
			alley[yy * cw + a.x] = 0
		if _alleys_connected():
			removed += 1
		else:
			alley = backup


func _set_alley(x: int, y: int) -> void:
	if x >= 0 and y >= 0 and x < cw and y < ch:
		alley[y * cw + x] = 1


func is_alley(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < cw and y < ch and alley[y * cw + x] == 1


func _alleys_connected() -> bool:
	var start := Vector2i(main_x, ch - 1)
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := c + d
			if is_alley(n.x, n.y) and not seen.has(n):
				seen[n] = true
				queue.append(n)
	var total := 0
	for v in alley:
		total += v
	return seen.size() == total


## Carrés : composantes connexes des cases qui ne sont ni allée ni mausolée, chacune avec son ambiance.
func _plots() -> void:
	plots.clear()
	var seen := {}
	for y in ch:
		for x in cw:
			var c := Vector2i(x, y)
			if is_alley(x, y) or mausoleum.has_point(c) or seen.has(c):
				continue
			var group: Array[Vector2i] = []
			var queue: Array[Vector2i] = [c]
			seen[c] = true
			while not queue.is_empty():
				var p: Vector2i = queue.pop_front()
				group.append(p)
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var n := p + d
					if n.x < 0 or n.y < 0 or n.x >= cw or n.y >= ch or seen.has(n) or is_alley(n.x, n.y) or mausoleum.has_point(n):
						continue
					seen[n] = true
					queue.append(n)
			var rect := Rect2i(group[0], Vector2i.ONE)
			for p in group:
				rect = rect.expand(p).expand(p + Vector2i.ONE)
			plots.append({"cells": group, "rect": rect, "kind": ""})
	# Ambiances : d'abord une de chaque (chapelle, fosses, caveau, bosquet, fontaine), puis au hasard.
	var order := ["chapelle", "fosses", "caveau", "bosquet", "fontaine"]
	for i in range(order.size() - 1, 0, -1): # mélange tiré de la graine (même cimetière pour toute la coop)
		var j := rng.randi_range(0, i)
		var tmp: String = order[i]
		order[i] = order[j]
		order[j] = tmp
	for i in plots.size():
		plots[i]["kind"] = order[i] if i < order.size() else PLOT_KINDS[rng.randi_range(0, PLOT_KINDS.size() - 1)]


func is_floor(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < width and y < height and cells[y * width + x] == 1


func zone_at(x: int, y: int) -> int:
	return zone[y * width + x] if x >= 0 and y >= 0 and x < width and y < height else 0


## Salle des catacombes qui contient la case globale (-1 = couloir ou hors catacombes).
func cata_room_of(c: Vector2i) -> int:
	for i in cata_rooms.size():
		if cata_rooms[i].has_point(c):
			return i
	return -1


## Tout est accessible : les allées du cimetière forment un seul réseau, les catacombes aussi.
func all_reachable() -> bool:
	return _alleys_connected() and cata.all_reachable()


## Recopie le plan dans `gen` (cases de 2 m). Salles : 0 = crypte du boss, 1 = arrivée au cimetière, puis les
## autres salles des catacombes.
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
	gen.rooms.append(Rect2i(boss_rect.position * 2, boss_rect.size * 2))
	gen.rooms.append(Rect2i(start_rect.position * 2, start_rect.size * 2))
	for r in cata_rooms:
		if r != boss_rect:
			gen.rooms.append(Rect2i(r.position * 2, r.size * 2))
	gen.ambush_rooms.clear()
	gen.boss_room = 0
	gen.start_room = 1
