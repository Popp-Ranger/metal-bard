extends "res://scripts/world/dungeon.gd"
## La Nécropole : niveau test, régénéré à chaque passage (portail vert à côté d'Ozz, dans la taverne).
## Tout est construit avec des kits CC0 rangés dans assets/models/kits/ :
##   • Modular Dungeon Kit (Kenney) : dalles, murs, coins arrondis, piliers et arches, sur une grille de 4 m
##     (NecropolisLayout) ;
##   • Graveyard Kit (Kenney, agrandi ×2) : tombes, croix, cercueils, caveaux, autels, bougies, braseros... ;
##   • KayKit Skeletons (Kay Lousberg) : squelettes, guerriers, arbalétriers, mages (KayKitSkeleton) et le boss,
##     le Roi des Os (SkeletonKing).
## Comme les Cryptes : rien n'est gardé (graine tirée en entrant, la même pour toute la coop), ennemis au niveau du
## héros. Le Roi des Os vaincu, un portail vert ramène à la taverne.

const CONFIG := {"name": "La Nécropole (niveau test)", "theme": "necropole", "rooms": 8, "boss_key": false}
const KIT := "res://assets/models/kits/donjon_modulaire/"
const GRAVE := "res://assets/models/kits/cimetiere/"
## Taille d'une case du Modular Dungeon Kit (m).
const KIT_CELL := 4.0
const GRAVE_SCALE := 2.0
## Retrait du mur par rapport au bord de sa case (m) : la collision suit la face du mur.
const WALL_DEPTH := 1.0
## Murs côté caméra (bords sud et est des cases) : abaissés en murets, comme dans la taverne, pour voir la salle.
const LOW_WALL := 0.3
const LOW: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1)]
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
## Décor le long des murs, selon l'ambiance de la salle.
const ROOM_STYLES := {
	"cimetiere": ["gravestone-round", "gravestone-cross", "gravestone-bevel", "gravestone-decorative", "gravestone-roof",
		"gravestone-wide", "gravestone-broken", "cross-column", "grave"],
	"caveau": ["coffin", "coffin-old", "crypt-a", "crypt-b", "urn-round", "urn-square", "coffin"],
	"chapelle": ["bench", "bench-damaged", "pillar-obelisk", "cross", "column-large", "bench"],
	"ossuaire": ["debris", "gravestone-debris", "rocks", "rocks-tall", "coffin-old", "shovel-dirt", "gravestone-broken"],
}

var layout := NecropolisLayout.new()
var king: SkeletonKing
var exit_portal: Portal
var _kit_material: ShaderMaterial
## Instances groupées par pièce du kit : nom -> [Transform3D] (une MultiMesh par pièce).
var _batches := {}
var _solids: StaticBody3D
## Pièces de décor posées (pour les tests et pour ne pas les entasser) : [Vector3].
var props: Array[Vector3] = []
static var _meshes := {}


func _ready() -> void:
	persistent = false
	super._ready()
	Events.boss_defeated.connect(_on_king_defeated)


func _dungeon_config() -> Dictionary:
	return CONFIG


func _enemy_level(_cfg: Dictionary) -> int:
	var lvl := GameState.stats.level
	if Net.is_client():
		lvl = int((Net.players.get(1, {}) as Dictionary).get("level", lvl))
	return clampi(lvl, 1, Balance.MAX_LEVEL)


func _saved_seed() -> int:
	return GameState.necropolis_seed


func _store_seed(seed_value: int) -> void:
	GameState.necropolis_seed = seed_value


func _generate(seed_value: int, cfg: Dictionary) -> int:
	layout.generate(seed_value, int(cfg.get("rooms", 8)))
	layout.to_dungeon_grid(gen)
	return seed_value


func _arrival_notice() -> void:
	Events.notify("La Nécropole : un niveau d'essai, différent à chaque passage. Au fond, le Roi des Os garde la sortie.", Color(0.55, 1.0, 0.6))


## Retour au portail vert de la taverne ; la Nécropole sera tirée à nouveau au prochain passage.
func _exit_scene() -> String:
	GameState.flags["from_necropolis"] = true
	GameState.necropolis_seed = 0
	return Router.TAVERN


# =====================================================================================
# Pièces du Modular Dungeon Kit
# =====================================================================================

## Maillage d'une pièce de kit (fichier .glb chargé une seule fois).
static func kit_mesh(path: String) -> Mesh:
	if not _meshes.has(path):
		var inst := (load(path) as PackedScene).instantiate()
		var mi := inst.find_child("*", true, false) as MeshInstance3D
		if mi == null:
			for n in inst.find_children("*", "MeshInstance3D", true, false):
				mi = n as MeshInstance3D
				break
		_meshes[path] = mi.mesh
		inst.free()
	return _meshes[path]


## Centre (au sol) de la case du kit `c`.
func kit_center(c: Vector2i) -> Vector3:
	return Vector3((c.x + 0.5) * KIT_CELL, 0.0, (c.y + 0.5) * KIT_CELL)


func _put(piece: String, xf: Transform3D) -> void:
	if not _batches.has(piece):
		_batches[piece] = []
	(_batches[piece] as Array).append(xf)


## Lacet (rad) qui tourne l'avant local (-Z) d'une pièce de mur vers l'intérieur d'une case dont le bord manquant
## est dans la direction `d`.
static func _yaw_for(d: Vector2i) -> float:
	return atan2(float(d.x), float(d.y))


func _box(size: Vector3, pos: Vector3, yaw: float = 0.0) -> void:
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	col.transform = Transform3D(Basis(Vector3.UP, yaw), pos)
	_solids.add_child(col)


func _cylinder(radius: float, h: float, pos: Vector3) -> void:
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = h
	col.shape = shape
	col.position = pos
	_solids.add_child(col)


func _build_floor() -> void:
	_solids = StaticBody3D.new()
	_solids.collision_layer = 1
	_solids.collision_mask = 0
	add_child(_solids)
	for y in layout.height:
		for x in layout.width:
			var c := Vector2i(x, y)
			if not layout.is_floor(x, y) or _corner_turn(c) >= 0:
				continue # les coins arrondis ont leur propre dalle
			var roll := _rng.randf()
			var piece := "template-floor"
			if roll < 0.12:
				piece = "template-floor-detail"
			elif roll < 0.22:
				piece = "template-floor-detail-a"
			_put(piece, Transform3D(Basis(Vector3.UP, PI * 0.5 * _rng.randi_range(0, 3)), kit_center(c)))
	# Fond noir sous la nécropole (rien ne transparaît entre les pièces).
	var size := Vector3(layout.width * KIT_CELL, 0.1, layout.height * KIT_CELL)
	_under = Visuals.box(self, size, Vector3(size.x * 0.5, -0.12, size.z * 0.5), Visuals.mat(Color(0.01, 0.01, 0.012)))


## Coin arrondi : la case n'a que deux voisins manquants, côte à côte. Renvoie le nombre de quarts de tour à
## donner à la pièce « template-corner » (murs sur +X et +Z avant rotation), ou -1.
func _corner_turn(c: Vector2i) -> int:
	var missing: Array[Vector2i] = []
	for d in DIRS:
		if not layout.is_floor(c.x + d.x, c.y + d.y):
			missing.append(d)
	if missing.size() != 2 or missing[0] == -missing[1]:
		return -1
	for k in 4:
		var b := Basis(Vector3.UP, PI * 0.5 * k)
		var ax := b * Vector3.RIGHT
		var az := b * Vector3.BACK
		var da := Vector2i(roundi(ax.x), roundi(ax.z))
		var db := Vector2i(roundi(az.x), roundi(az.z))
		if missing.has(da) and missing.has(db):
			return k
	return -1


func _build_walls() -> void:
	var wall_mat := kit_mesh(KIT + "template-wall.glb").surface_get_material(0) as StandardMaterial3D
	_kit_material = ShaderMaterial.new()
	_kit_material.shader = load("res://shaders/kit_cutaway.gdshader")
	_kit_material.set_shader_parameter("albedo_tex", wall_mat.albedo_texture if wall_mat != null else null)
	_wall_material = _kit_material # le donjon lui passe la position du héros (découpe des murs)
	for y in layout.height:
		for x in layout.width:
			var c := Vector2i(x, y)
			if not layout.is_floor(x, y):
				continue
			var center := kit_center(c)
			var turn := _corner_turn(c)
			if turn >= 0:
				var corner_basis := Basis(Vector3.UP, PI * 0.5 * turn)
				if turn == 0:
					corner_basis = corner_basis.scaled(Vector3(1.0, LOW_WALL, 1.0)) # coin sud-est : côté caméra
				_put("template-corner", Transform3D(corner_basis, center))
				_corner_collision(center, turn)
				continue
			for d in DIRS:
				if layout.is_floor(x + d.x, y + d.y):
					continue
				var yaw := _yaw_for(d)
				var edge := center + Vector3(d.x, 0, d.y) * KIT_CELL * 0.5
				var piece := "template-wall-detail-a" if _rng.randf() < 0.3 else "template-wall"
				var wall_basis := Basis(Vector3.UP, yaw)
				if LOW.has(d):
					wall_basis = wall_basis.scaled(Vector3(1.0, LOW_WALL, 1.0))
				_put(piece, Transform3D(wall_basis, edge))
				var inward := -Vector3(d.x, 0, d.y)
				_box(Vector3(KIT_CELL + 0.2, 4.0, WALL_DEPTH), edge + inward * WALL_DEPTH * 0.5 + Vector3(0, 2.0, 0), yaw)
	_pillars()
	_flush_batches()


## Coin arrondi : arc de cercle de rayon 3,5 m centré sur le coin intérieur de la case (côté sol).
func _corner_collision(center: Vector3, turn: int) -> void:
	var b := Basis(Vector3.UP, PI * 0.5 * turn)
	var pivot := center + b * Vector3(-KIT_CELL * 0.5, 0, -KIT_CELL * 0.5)
	for k in 4:
		var a := PI * 0.5 * (k + 0.5) / 4.0
		var dir := b * Vector3(cos(a), 0, sin(a))
		_box(Vector3(1.6, 4.0, WALL_DEPTH), pivot + dir * (3.5 + WALL_DEPTH * 0.3) + Vector3(0, 2.0, 0), atan2(dir.x, dir.z))


## Piliers : à chaque angle rentrant (trois cases de sol autour d'un coin) et, dans les grandes salles, quatre
## colonnes à 4 m des murs.
func _pillars() -> void:
	for y in range(1, layout.height):
		for x in range(1, layout.width):
			var n := 0
			for o: Vector2i in [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(-1, -1)]:
				if layout.is_floor(x + o.x, y + o.y):
					n += 1
			if n == 3:
				# Case manquante au sud-est du coin : ses deux murs sont des murets, le pilier aussi.
				_pillar(Vector3(x * KIT_CELL, 0, y * KIT_CELL), not layout.is_floor(x, y))
	for i in layout.rooms.size():
		var r := layout.rooms[i]
		if r.size.x < 4 or r.size.y < 4 or i == layout.start_room:
			continue
		for vx: int in [r.position.x + 1, r.end.x - 1]:
			for vy: int in [r.position.y + 1, r.end.y - 1]:
				_pillar(Vector3(vx * KIT_CELL, 0, vy * KIT_CELL))


func _pillar(p: Vector3, low: bool = false) -> void:
	_put("template-detail", Transform3D(Basis.IDENTITY.scaled(Vector3(1.0, LOW_WALL if low else 1.0, 1.0)), p))
	_cylinder(0.75, 4.0, p + Vector3(0, 2.0, 0))


## Une MultiMesh par pièce : dalles avec leur matériau, murs et piliers avec la découpe autour du héros.
func _flush_batches() -> void:
	for piece: String in _batches:
		var xforms: Array = _batches[piece]
		if xforms.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = kit_mesh(KIT + piece + ".glb")
		mm.instance_count = xforms.size()
		for i in xforms.size():
			mm.set_instance_transform(i, xforms[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Kit_" + piece
		mmi.multimesh = mm
		if not piece.begins_with("template-floor"):
			mmi.material_override = _kit_material
			if _wall_mmi == null:
				_wall_mmi = mmi
		add_child(mmi)
	_batches.clear()


## Nombre d'instances d'une pièce du kit dans le niveau (tests).
func kit_count(piece: String) -> int:
	var mmi := get_node_or_null("Kit_" + piece) as MultiMeshInstance3D
	return mmi.multimesh.instance_count if mmi != null else 0


# =====================================================================================
# Arches aux entrées des salles
# =====================================================================================

## Une arche (« gate » du kit) à chaque entrée d'une case de large ; ni portes ni salles cachées.
func _build_doors() -> void:
	for i in layout.rooms.size():
		for o in _openings(i):
			if LOW.has(o["dir"]):
				continue # entrée côté caméra : pas d'arche au-dessus des murets
			var yaw := 0.0 if o["dir"].y != 0 else PI * 0.5
			var p: Vector3 = o["pos"]
			_put("gate", Transform3D(Basis(Vector3.UP, yaw), p))
			var along := Basis(Vector3.UP, yaw) * Vector3.RIGHT
			for s: float in [-1.0, 1.0]:
				_box(Vector3(0.5, 4.0, 1.0), p + along * 2.05 * s + Vector3(0, 2.0, 0), yaw)
	_flush_batches()


## Entrées d'une salle : [{pos (milieu du bord), dir (vers l'extérieur)}] où une seule case de sol touche la salle.
func _openings(room: int) -> Array[Dictionary]:
	var r := layout.rooms[room]
	var out: Array[Dictionary] = []
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			for d in DIRS:
				var n := Vector2i(x, y) + d
				if r.has_point(n) or not layout.is_floor(n.x, n.y):
					continue
				# Une entrée d'une case de large : les deux cases voisines le long du bord sont des murs.
				var side := Vector2i(d.y, d.x)
				if layout.is_floor(n.x + side.x, n.y + side.y) or layout.is_floor(n.x - side.x, n.y - side.y):
					continue
				out.append({"pos": kit_center(Vector2i(x, y)) + Vector3(d.x, 0, d.y) * KIT_CELL * 0.5, "dir": d})
	return out


func _build_room_covers() -> void:
	for i in gen.rooms.size():
		_state_add("rooms", i)


# =====================================================================================
# Décor : Graveyard Kit
# =====================================================================================

## Pièce du Graveyard Kit (agrandie ×2) ; les grosses pièces bloquent le passage.
func _prop(piece: String, pos: Vector3, yaw: float, solid: bool = true) -> Node3D:
	var inst := (load(GRAVE + piece + ".glb") as PackedScene).instantiate() as Node3D
	inst.position = Vector3(pos.x, 0.0, pos.z)
	inst.rotation.y = yaw
	inst.scale = Vector3.ONE * GRAVE_SCALE
	add_child(inst)
	props.append(inst.position)
	if solid:
		var aabb := kit_mesh(GRAVE + piece + ".glb").get_aabb()
		var size := aabb.size * GRAVE_SCALE
		if size.y > 0.5 and size.x * size.z > 0.15:
			var mid := (aabb.position + aabb.size * 0.5) * GRAVE_SCALE
			_box(Vector3(size.x, 2.0, size.z), inst.position + Basis(Vector3.UP, yaw) * Vector3(mid.x, 0, mid.z) + Vector3(0, 1.0, 0), yaw)
	return inst


func _light(pos: Vector3, color: Color, energy: float, light_range: float) -> void:
	var l := Visuals.flicker_light(self, pos, color, energy, light_range)
	l.flicker_amount = 0.3


## Brasero (fire-basket) avec ses flammes et sa lumière.
func _brazier(pos: Vector3) -> void:
	_prop("fire-basket", pos, 0.0, false)
	Visuals.sphere(self, 0.22, pos + Vector3(0, 0.5, 0), Visuals.glow_mat(Color(1.0, 0.5, 0.15), 5.0), Vector3(1.2, 1.4, 1.2))
	_light(pos + Vector3(0, 1.4, 0), Color(1.0, 0.55, 0.25), 2.4, 10.0)


## Bougies (posées au sol, devant une tombe), avec une petite lumière.
func _candles(pos: Vector3, lit: bool) -> void:
	_prop("candle-multiple", pos, _rng.randf() * TAU, false)
	if lit:
		_light(pos + Vector3(0, 0.8, 0), Color(1.0, 0.7, 0.35), 1.0, 4.5)


func _decorate() -> void:
	var styles := ROOM_STYLES.keys()
	for i in layout.rooms.size():
		if i == layout.boss_room:
			continue
		var r := layout.rooms[i]
		var style: String = styles[_rng.randi_range(0, styles.size() - 1)]
		var openings := _openings(i)
		# Deux braseros dans des coins opposés.
		var lo := Vector3(r.position.x * KIT_CELL, 0, r.position.y * KIT_CELL)
		var hi := Vector3(r.end.x * KIT_CELL, 0, r.end.y * KIT_CELL)
		if i == layout.start_room:
			# Salle de départ : le portail de retraite est au nord-ouest du centre, on le laisse dégagé.
			_brazier(Vector3(hi.x - 2.0, 0, lo.z + 2.0))
			_brazier(Vector3(lo.x + 2.0, 0, hi.z - 2.0))
			props.append(cell_to_world(gen.center(gen.start_room)) + Vector3(-3.0, 0, -3.0))
		else:
			_brazier(Vector3(lo.x + 2.0, 0, lo.z + 2.0))
			_brazier(Vector3(hi.x - 2.0, 0, hi.z - 2.0))
		# Le long des murs, à 2,4 m des bords de la salle, tournés vers son centre.
		var lit := 0
		for spot in _wall_band(r, 2.4, 2.4):
			if _near_opening(spot, openings, 3.2) or _crowded(spot, 2.0) or _rng.randf() < 0.25:
				continue
			var center := (lo + hi) * 0.5
			var to_center := center - spot
			var yaw := atan2(to_center.x, to_center.z)
			var pool: Array = ROOM_STYLES[style]
			var piece: String = pool[_rng.randi_range(0, pool.size() - 1)]
			if piece in ["coffin", "coffin-old", "crypt-a", "crypt-b", "grave"]:
				yaw += PI * 0.5 # les pièces allongées se rangent le long du mur
			_prop(piece, spot, yaw)
			if style in ["cimetiere", "caveau"] and _rng.randf() < 0.3:
				_candles(spot + Basis(Vector3.UP, yaw) * Vector3(0.6, 0, 0.9), lit < 2)
				lit += 1
		# Grande salle : une pièce maîtresse au milieu (pas dans la salle de départ).
		if i != layout.start_room and r.size.x >= 5 and r.size.y >= 5:
			var c := (lo + hi) * 0.5
			match style:
				"caveau":
					_prop("crypt-small", c, _rng.randi_range(0, 3) * PI * 0.5)
				"chapelle":
					_prop("altar-stone", c, 0.0)
					_candles(c + Vector3(1.4, 0, 0), true)
				_:
					_prop("pillar-obelisk", c, 0.0)
	_corridor_lights()


## Points le long des murs d'une salle, à `inset` m des bords de ses cases, espacés d'environ `spacing` m.
func _wall_band(r: Rect2i, inset: float, spacing: float) -> Array[Vector3]:
	var lo := Vector2(r.position) * KIT_CELL + Vector2(inset, inset)
	var hi := Vector2(r.end) * KIT_CELL - Vector2(inset, inset)
	var out: Array[Vector3] = []
	var nx := maxi(1, floori((hi.x - lo.x) / spacing))
	var nz := maxi(1, floori((hi.y - lo.y) / spacing))
	for k in range(1, nx):
		var x := lo.x + (hi.x - lo.x) * k / nx
		out.append(Vector3(x, 0, lo.y))
		out.append(Vector3(x, 0, hi.y))
	for k in range(1, nz):
		var z := lo.y + (hi.y - lo.y) * k / nz
		out.append(Vector3(lo.x, 0, z))
		out.append(Vector3(hi.x, 0, z))
	return out


func _near_opening(p: Vector3, openings: Array[Dictionary], dist: float) -> bool:
	for o in openings:
		if (o["pos"] as Vector3).distance_to(p) < dist:
			return true
	return false


func _crowded(p: Vector3, dist: float) -> bool:
	for q in props:
		if q.distance_to(p) < dist:
			return true
	return false


## Couloirs : une lanterne à bougie posée contre le mur toutes les quatre cases environ.
func _corridor_lights() -> void:
	var n := 0
	for y in layout.height:
		for x in layout.width:
			var c := Vector2i(x, y)
			if not layout.is_floor(x, y) or layout.room_of(c) >= 0:
				continue
			n += 1
			if n % 4 != 0:
				continue
			for d in DIRS:
				if not layout.is_floor(x + d.x, y + d.y):
					var p := kit_center(c) + Vector3(d.x, 0, d.y) * 0.6
					_prop("lantern-candle", p, 0.0, false)
					_light(p + Vector3(0, 1.2, 0), Color(1.0, 0.7, 0.4), 1.4, 7.0)
					break


# =====================================================================================
# Ennemis et boss : KayKit Skeletons
# =====================================================================================

func _spawn_enemies() -> void:
	for i in gen.rooms.size():
		if i == gen.boss_room or i == gen.start_room:
			continue
		for k in _coop_count(_rng.randi_range(3, 5)):
			var roll := _rng.randf()
			var kind := "minion"
			if roll > 0.85:
				kind = "mage"
			elif roll > 0.7:
				kind = "rogue"
			elif roll > 0.5:
				kind = "warrior"
			spawn_bones(kind, cell_to_world(gen.random_cell_in_room(i, 2)), i)


## Un squelette KayKit (`kind` : minion, warrior, rogue, mage) ; `room` comme pour _place_enemy.
func spawn_bones(kind: String, pos: Vector3, room: int = -1) -> KayKitSkeleton:
	var e := KayKitSkeleton.new()
	e.kind = kind
	e.level = enemy_level
	e.position = pos
	e.rotation.y = _rng.randf() * TAU
	e.walkable_check = is_walkable
	return _place_enemy(e, room) as KayKitSkeleton


## Salle du boss : le Roi des Os au centre, deux guerriers, tombes et cercueils, braseros aux quatre coins,
## caveau et autel au fond (nord).
func _spawn_boss_room() -> void:
	var r := layout.rooms[layout.boss_room]
	var c := kit_center(layout.center(layout.boss_room))
	var lo := Vector3(r.position.x * KIT_CELL, 0, r.position.y * KIT_CELL)
	var hi := Vector3(r.end.x * KIT_CELL, 0, r.end.y * KIT_CELL)
	for corner: Vector3 in [Vector3(lo.x + 2.2, 0, lo.z + 2.2), Vector3(hi.x - 2.2, 0, lo.z + 2.2),
			Vector3(lo.x + 2.2, 0, hi.z - 2.2), Vector3(hi.x - 2.2, 0, hi.z - 2.2)]:
		_brazier(corner)
	var openings := _openings(layout.boss_room)
	var back := Vector3(c.x, 0, lo.z + 3.2)
	if not _near_opening(back, openings, 4.0):
		_prop("crypt-large", back, 0.0)
		_prop("altar-stone", back + Vector3(0, 0, 3.0), 0.0)
		_candles(back + Vector3(-1.6, 0, 3.0), true)
		_candles(back + Vector3(1.6, 0, 3.0), true)
	for spot in _wall_band(r, 2.6, 3.0):
		if _near_opening(spot, openings, 3.5) or _crowded(spot, 2.0) or _rng.randf() < 0.3:
			continue
		var to_c := c - spot
		_prop(["coffin", "gravestone-cross-large", "gravestone-decorative", "urn-round"][_rng.randi_range(0, 3)], spot, atan2(to_c.x, to_c.z))
	var glow := Visuals.flicker_light(self, c + Vector3(0, 4.0, 0), Color(0.9, 0.25, 0.2), 1.6, 14.0)
	glow.flicker_amount = 0.15
	king = SkeletonKing.new()
	king.level = enemy_level
	king.position = c
	king.rotation.y = PI * 0.25
	king.walkable_check = is_walkable
	king.spawn_minion = _raise_minion.bind(c)
	add_child(king)
	_room_enemies[gen.boss_room] = [king]
	for s: float in [-1.0, 1.0]:
		spawn_bones("warrior", c + Vector3(3.5 * s, 0, 2.5), gen.boss_room)


## Squelette relevé par le Roi des Os : il sort de terre, puis charge.
func _raise_minion(p: Vector3, c: Vector3) -> void:
	var e := spawn_bones("minion" if _rng.randf() < 0.75 else "warrior", p if is_walkable(p) else c)
	e.call_deferred("rise_from_ground")
	e.call_deferred("_aggro")


func _on_king_defeated(boss_id: String) -> void:
	if boss_id != "roi_des_os":
		return
	if hero != null:
		hero.model.victory()
	Events.notify("Le Roi des Os s'effondre dans un fracas d'ossements. Un portail vert s'ouvre vers la Chèvre Fringante...", Events.COLOR_GOLD)
	await get_tree().create_timer(1.5, false).timeout
	var p := kit_center(layout.center(layout.boss_room))
	if hero != null and is_walkable(hero.global_position + hero.facing * 2.0):
		p = hero.global_position + hero.facing * 2.0
	exit_portal = Portal.new()
	exit_portal.green = true
	exit_portal.position = Vector3(p.x, 0.0, p.z)
	exit_portal.prompt = "Portail vert : retour à la Chèvre Fringante (la Nécropole se régénérera)"
	exit_portal.on_enter = _end_dungeon.bind("Nécropole nettoyée !", true)
	add_child(exit_portal)
