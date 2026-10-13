extends "res://scripts/world/dungeon.gd"
## Le Cimetière maudit : niveau test, régénéré à chaque passage (portail vert à côté d'Ozz, dans la taverne).
## Plan : CemeteryLayout. Trois parties, toutes faites avec les kits CC0 de assets/models/kits/ (voir LISEZMOI.md) :
##   1. le cimetière, à l'air libre sous la lune : sol de terre, allées pavées, carrés de tombes, fosses ouvertes,
##      caveaux, bosquets d'arbres morts, chapelles et leurs offrandes, fontaine asséchée ; clôture de fer au fond,
##      haies basses côté caméra, grille d'entrée au sud, grand mausolée au nord. Les squelettes y sortent de terre
##      quand on approche (KayKit Halloween Bits, Graveyard Kit, Fantasy Town Kit, Food Kit) ;
##   2. les catacombes, sous le mausolée : salles et couloirs du Modular Dungeon Kit ou cavernes du Modular Cave Kit,
##      meublés avec le KayKit Dungeon Pack (torches, tonneaux, caisses, coffres) et des ossements ;
##   3. la crypte du Roi des Os (salle du boss), bâtie avec les murs, sols, piliers et bannières du KayKit Dungeon Pack.
## Ennemis : KayKit Skeletons (KayKitSkeleton, SkeletonKing). Comme les Cryptes : rien n'est gardé (graine tirée en
## entrant, la même pour toute la coop), ennemis au niveau du héros. Le Roi vaincu, un portail vert ramène à la taverne.

const CONFIG := {"name": "Le Cimetière maudit (niveau test)", "theme": "necropole", "boss_key": false}
const KITS := "res://assets/models/kits/"
const DK := "donjon_modulaire/"
const CAVE := "grotte/"
const KK := "donjon_kaykit/"
const HW := "halloween/"
const GY := "cimetiere/"
const TOWN := "ville/"
const FOOD := "nourriture/"
## Case du plan (m) : celle du Modular Dungeon Kit, du KayKit Dungeon Pack et des pièces du KayKit Halloween.
const CELL4 := 4.0
## Retrait des murs du Modular Dungeon / Cave Kit par rapport au bord de leur case (m).
const WALL_DEPTH := 1.0
## Murs côté caméra (bords sud et est) : abaissés en murets.
const LOW_WALL := 0.3
const LOW: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1)]
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
## Distance à laquelle les morts du cimetière sortent de terre.
const WAKE_RADIUS := 7.5
## Échelles : Graveyard Kit ×2, Fantasy Town Kit ×4 (cases d'1 m), Food Kit ×0,7 (offrandes).
const GY_SCALE := 2.0
const TOWN_SCALE := 4.0
const FOOD_SCALE := 0.7
const GRAVES := [HW + "grave_A.gltf", HW + "grave_B.gltf", HW + "gravestone.gltf", HW + "gravemarker_A.gltf",
	HW + "gravemarker_B.gltf", HW + "grave_A_destroyed.gltf"]
const SMALL_GRAVES := ["gravestone-round", "gravestone-cross", "gravestone-decorative", "gravestone-roof",
	"gravestone-bevel", "gravestone-broken", "cross-column"]
const OFFERINGS := ["bread", "loaf-round", "wine-red", "grapes", "apple", "cheese", "pie", "glass-wine", "pumpkin-basic", "whole-ham"]

var layout := CemeteryLayout.new()
var king: SkeletonKing
var exit_portal: Portal
var crypt_door: Interactable
var catacomb_stairs: Interactable
## Pièces de décor posées : [Vector3] (pour ne pas les entasser, et pour les tests).
var props: Array[Vector3] = []
## Squelettes encore sous terre (cimetière) : ils sortent quand un héros approche.
var buried: Array[KayKitSkeleton] = []
## Cases de fosse ouverte (cimetière).
var open_graves: Array[Vector2i] = []
## Style des salles des catacombes : index de salle (cata_rooms) -> « donjon » ou « grotte ».
var _room_style := {}
var _batches := {}
var _cut_materials := {}
var _solids: StaticBody3D
var _wake_check := 0.0


func _ready() -> void:
	persistent = false
	super._ready()
	Events.boss_defeated.connect(_on_king_defeated)
	_moonlight()
	_night()


func _dungeon_config() -> Dictionary:
	return CONFIG


func _environment_kind() -> String:
	return "night"


func _enemy_level(_cfg: Dictionary) -> int:
	var lvl := GameState.stats.level
	if Net.is_client():
		lvl = int((Net.players.get(1, {}) as Dictionary).get("level", lvl))
	return clampi(lvl, 1, Balance.MAX_LEVEL)


func _saved_seed() -> int:
	return GameState.necropolis_seed


func _store_seed(seed_value: int) -> void:
	GameState.necropolis_seed = seed_value


func _generate(seed_value: int, _cfg: Dictionary) -> int:
	layout.generate(seed_value)
	layout.to_dungeon_grid(gen)
	for i in layout.cata_rooms.size():
		_room_style[i] = "grotte" if layout.rng.randf() < 0.5 else "donjon"
	return seed_value


func _arrival_notice() -> void:
	Events.notify("Le Cimetière maudit : un niveau d'essai, différent à chaque passage. Les morts dorment mal ici... Le mausolée, au nord, descend aux catacombes.", Color(0.55, 1.0, 0.6))


## Retour au portail vert de la taverne ; le cimetière sera tiré à nouveau au prochain passage.
func _exit_scene() -> String:
	GameState.flags["from_necropolis"] = true
	GameState.necropolis_seed = 0
	return Router.TAVERN


## Portail de retraite : dans l'allée, juste à l'ouest de la grille d'entrée.
func _spawn_flee_portal(_pos: Vector3) -> void:
	super._spawn_flee_portal(cell_center(Vector2i(layout.main_x - 1, layout.ch - 2)))


## Nuit noire et brumeuse (plus sombre que l'ambiance « night » des autres niveaux).
func _night() -> void:
	for c in get_children():
		var we := c as WorldEnvironment
		if we == null:
			continue
		var env := we.environment
		env.background_color = Color(0.01, 0.012, 0.025)
		env.ambient_light_color = Color(0.42, 0.48, 0.75)
		env.ambient_light_energy = 0.32
		env.fog_enabled = true
		env.fog_light_color = Color(0.06, 0.07, 0.12)
		env.fog_density = 0.012


## Clair de lune bleuté, avec ombres.
func _moonlight() -> void:
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.55, 0.62, 1.0)
	moon.light_energy = 0.4
	moon.shadow_enabled = true
	moon.rotation_degrees = Vector3(-50, -35, 0)
	add_child(moon)


func _process(delta: float) -> void:
	super._process(delta)
	if hero != null:
		for m: ShaderMaterial in _cut_materials.values():
			m.set_shader_parameter("hero_pos", hero.global_position)
	_wake_check -= delta
	if _wake_check <= 0.0:
		_wake_check = 0.25
		_wake_the_dead()


# =====================================================================================
# Pièces des kits
# =====================================================================================

## Centre (au sol) d'une case du plan.
func cell_center(c: Vector2i) -> Vector3:
	return Vector3((c.x + 0.5) * CELL4, 0.0, (c.y + 0.5) * CELL4)


## Maillage d'une pièce (chemin relatif à kits/) et son repère dans le fichier : [Mesh, Transform3D] (KitProps).
static func piece(path: String) -> Array:
	return KitProps.piece(path)


## Emprise d'une pièce (toutes ses parties, échelle 1).
static func piece_aabb(path: String) -> AABB:
	return KitProps.aabb(path)


## Pièce d'architecture regroupée (une MultiMesh par pièce) ; `cut` : avec la découpe autour du héros.
func _put(path: String, xf: Transform3D, cut: bool = false) -> void:
	var key := path + ("|cut" if cut else "")
	if not _batches.has(key):
		_batches[key] = []
	(_batches[key] as Array).append(xf * (piece(path)[1] as Transform3D))


## Matériau à découpe (shaders/kit_cutaway.gdshader) avec la texture d'un maillage de kit.
func _cut_material(mesh: Mesh) -> ShaderMaterial:
	var src := mesh.surface_get_material(0) as BaseMaterial3D
	var tex: Texture2D = src.albedo_texture if src != null else null
	var key: Variant = tex if tex != null else "none"
	if not _cut_materials.has(key):
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/kit_cutaway.gdshader")
		m.set_shader_parameter("albedo_tex", tex)
		_cut_materials[key] = m
		if _wall_material == null:
			_wall_material = m
	return _cut_materials[key]


func _flush() -> void:
	for key: String in _batches:
		var xforms: Array = _batches[key]
		var path := key.get_slice("|", 0)
		var mesh: Mesh = piece(path)[0]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = xforms.size()
		for i in xforms.size():
			mm.set_instance_transform(i, xforms[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Kit_" + path.replace("/", "_").get_basename()
		mmi.multimesh = mm
		if key.ends_with("|cut"):
			mmi.material_override = _cut_material(mesh)
			if _wall_mmi == null:
				_wall_mmi = mmi
		add_child(mmi, true)
	_batches.clear()


## Nombre d'instances d'une pièce d'architecture (tests) : `path` relatif à kits/, sans extension.
func kit_count(path: String) -> int:
	var n := 0
	for c in get_children():
		if c is MultiMeshInstance3D and str(c.name).begins_with("Kit_" + path.replace("/", "_")):
			n += (c as MultiMeshInstance3D).multimesh.instance_count
	return n


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
	col.position = pos + Vector3(0, h * 0.5, 0)
	_solids.add_child(col)


## Pièce de décor (chemin relatif à kits/) posée en `pos`, tournée de `yaw`, à l'échelle `s`. `centered` : l'emprise
## de la pièce est centrée sur `pos`. `solid` : une boîte de collision suit son emprise (si elle dépasse 0,5 m).
func _prop(path: String, pos: Vector3, yaw: float = 0.0, s: float = 1.0, solid: bool = true, centered: bool = false) -> Node3D:
	var inst := (load(KITS + path) as PackedScene).instantiate() as Node3D
	var aabb := piece_aabb(path)
	var basis := Basis(Vector3.UP, yaw)
	var mid := (aabb.position + aabb.size * 0.5) * s
	var origin := pos
	if centered:
		origin -= basis * Vector3(mid.x, 0, mid.z)
	inst.transform = Transform3D(basis.scaled(Vector3.ONE * s), Vector3(origin.x, pos.y, origin.z))
	add_child(inst)
	props.append(Vector3(pos.x, 0.0, pos.z))
	var size := aabb.size * s
	if solid and size.y > 0.5 and size.x * size.z > 0.1:
		_box(Vector3(size.x, 2.4, size.z), Vector3(origin.x, 1.2, origin.z) + basis * Vector3(mid.x, 0, mid.z), yaw)
	return inst


func _light(pos: Vector3, color: Color, energy: float, light_range: float, flicker: float = 0.3) -> void:
	var l := Visuals.flicker_light(self, pos, color, energy, light_range)
	l.flicker_amount = flicker


func _crowded(p: Vector3, dist: float) -> bool:
	for q in props:
		if Vector2(q.x - p.x, q.z - p.z).length() < dist:
			return true
	return false


# =====================================================================================
# Sols
# =====================================================================================

func _build_floor() -> void:
	_solids = StaticBody3D.new()
	_solids.collision_layer = 1
	_solids.collision_mask = 0
	add_child(_solids)
	# Fosses ouvertes : quelques cases (6 au plus) des carrés « fosses ».
	for plot in layout.plots:
		if str(plot["kind"]) != "fosses":
			continue
		var n := 0
		for c: Vector2i in plot["cells"]:
			if n < 6 and _rng.randf() < 0.35 and not layout.start_rect.has_point(c):
				open_graves.append(c)
				n += 1
	# Cimetière : terre partout (et un liseré de terre autour, pour les arbres du dehors) ; allées pavées.
	for y in range(-3, layout.ch + 2):
		for x in range(-3, layout.cw + 2):
			var c := Vector2i(x, y)
			var turn := Basis(Vector3.UP, PI * 0.5 * _rng.randi_range(0, 3))
			if open_graves.has(c):
				_put(HW + "floor_dirt_grave.gltf", Transform3D(Basis.IDENTITY, cell_center(c)))
				continue
			_put(HW + "floor_dirt.gltf", Transform3D(turn, cell_center(c)))
			if layout.is_alley(x, y):
				for q: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
					var path_tile: String = [HW + "path_A.gltf", HW + "path_B.gltf", HW + "path_C.gltf", HW + "path_D.gltf"][_rng.randi_range(0, 3)]
					_put(path_tile, Transform3D(Basis(Vector3.UP, PI * 0.5 * _rng.randi_range(0, 3)),
						cell_center(c) + Vector3(q.x, 0.02, q.y)))
	# Catacombes : dalles du Modular Dungeon Kit ou du Modular Cave Kit ; crypte royale : dalles KayKit.
	for y in layout.height:
		for x in layout.width:
			var c := Vector2i(x, y)
			if layout.zone_at(x, y) != 2:
				continue
			if layout.boss_rect.has_point(c):
				var tile := KK + ("floor_tile_large_rocks.gltf" if _rng.randf() < 0.15 else "floor_tile_large.gltf")
				_put(tile, Transform3D(Basis.IDENTITY, cell_center(c)))
				continue
			if _corner_turn(c) >= 0:
				continue # les coins arrondis ont leur dalle
			var kit := _kit_of(c)
			var roll := _rng.randf()
			var floor_piece := "template-floor.glb"
			if roll < 0.12:
				floor_piece = "template-floor-detail.glb"
			elif roll < 0.22:
				floor_piece = "template-floor-detail-a.glb"
			_put(kit + floor_piece, Transform3D(Basis(Vector3.UP, PI * 0.5 * _rng.randi_range(0, 3)), cell_center(c)))
	var o := Vector3(layout.cata_offset.x * CELL4, 0, 0)
	var size := Vector3(layout.cata.width * CELL4, 0.1, layout.cata.height * CELL4)
	_under = Visuals.box(self, size, o + Vector3(size.x * 0.5, -0.12, size.z * 0.5), Visuals.mat(Color(0.01, 0.01, 0.012)))


## Kit d'une case des catacombes : celui de sa salle (donjon ou grotte), le donjon pour les couloirs.
func _kit_of(c: Vector2i) -> String:
	var r := layout.cata_room_of(c)
	return CAVE if r >= 0 and str(_room_style.get(r, "donjon")) == "grotte" else DK


## Coin arrondi (catacombes) : deux voisins manquants côte à côte. Quarts de tour de « template-corner », ou -1.
func _corner_turn(c: Vector2i) -> int:
	if layout.zone_at(c.x, c.y) != 2 or layout.boss_rect.has_point(c):
		return -1
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
		if missing.has(Vector2i(roundi(ax.x), roundi(ax.z))) and missing.has(Vector2i(roundi(az.x), roundi(az.z))):
			return k
	return -1


# =====================================================================================
# Murs, clôtures, mausolée
# =====================================================================================

func _build_walls() -> void:
	_cemetery_bounds()
	_mausoleum()
	_catacomb_walls()
	_royal_crypt_walls()
	_flush()


## Clôture de fer (KayKit Halloween) au nord et à l'ouest ; haies basses (Fantasy Town Kit) au sud et à l'est,
## côté caméra ; arche d'entrée au sud, sur l'allée principale.
func _cemetery_bounds() -> void:
	var w := layout.cw * CELL4
	var h := layout.ch * CELL4
	for x in layout.cw:
		var top := Vector3((x + 0.5) * CELL4, 0, 0)
		_put(HW + ("fence_broken.gltf" if _rng.randf() < 0.2 else "fence.gltf"), Transform3D(Basis.IDENTITY, top), true)
		_put(HW + "fence_pillar.gltf", Transform3D(Basis.IDENTITY, Vector3(x * CELL4, 0, 0)), true)
		_box(Vector3(CELL4, 3.0, 0.5), top + Vector3(0, 1.5, 0))
		var bottom := Vector3((x + 0.5) * CELL4, 0, h)
		if x == layout.main_x:
			_put(HW + "arch.gltf", Transform3D(Basis.IDENTITY, bottom), true)
			for s: float in [-1.0, 1.0]:
				_box(Vector3(0.6, 3.0, 0.8), bottom + Vector3(2.0 * s, 1.5, 0))
			continue
		_hedge(bottom, 0.0)
	for y in layout.ch:
		var left := Vector3(0, 0, (y + 0.5) * CELL4)
		_put(HW + ("fence_broken.gltf" if _rng.randf() < 0.2 else "fence.gltf"), Transform3D(Basis(Vector3.UP, PI * 0.5), left), true)
		_put(HW + "fence_pillar.gltf", Transform3D(Basis.IDENTITY, Vector3(0, 0, y * CELL4)), true)
		_box(Vector3(0.5, 3.0, CELL4), left + Vector3(0, 1.5, 0))
		_hedge(Vector3(w, 0, (y + 0.5) * CELL4), PI * 0.5)
	_put(HW + "fence_pillar.gltf", Transform3D(Basis.IDENTITY, Vector3(0, 0, h)), true)
	_put(HW + "fence_pillar.gltf", Transform3D(Basis.IDENTITY, Vector3(w, 0, 0)), true)


## Haie basse de 4 m (Fantasy Town Kit « hedge », ×4) centrée sur `pos`, le long de X (yaw 0) ou de Z (yaw π/2).
## Collision invisible de 3 m, comme les murets de la taverne.
func _hedge(pos: Vector3, yaw: float) -> void:
	var aabb := piece_aabb(TOWN + "hedge.glb")
	var mid := (aabb.position + aabb.size * 0.5) * TOWN_SCALE
	# La haie du kit est posée le long de Z : un quart de tour la met le long de X.
	var basis := Basis(Vector3.UP, yaw + PI * 0.5).scaled(Vector3.ONE * TOWN_SCALE)
	var origin := pos - Basis(Vector3.UP, yaw + PI * 0.5) * Vector3(mid.x, 0, mid.z)
	_put(TOWN + "hedge.glb", Transform3D(basis, origin))
	_box(Vector3(CELL4, 3.0, 1.0), pos + Vector3(0, 1.5, 0), yaw)


## Le grand mausolée (KayKit Halloween « crypt ») au nord de l'allée principale : sa porte descend aux catacombes.
func _mausoleum() -> void:
	var cx := (layout.main_x + 0.5) * CELL4
	var origin := Vector3(cx, 0, 4.0)
	_put(HW + "crypt.gltf", Transform3D(Basis.IDENTITY, origin), true)
	_box(Vector3(6.0, 6.0, 7.6), origin + Vector3(0, 3.0, -0.2))
	var door := Vector3(cx, 0, 8.6)
	crypt_door = Interactable.create(self, door, "Descendre dans les catacombes (porte du mausolée)",
		_go_down, 2.2)
	for s: float in [-1.0, 1.0]:
		_prop(HW + "post_lantern.gltf", Vector3(cx + 4.2 * s, 0, 7.4), 0.0, 1.0, false)
		_light(Vector3(cx + 4.2 * s, 2.6, 8.6), Color(1.0, 0.6, 0.3), 2.2, 9.0)
		_prop(HW + "candle_triple.gltf", Vector3(cx + 1.9 * s, 0, 9.0), 0.0, 1.0, false)
		_prop(HW + "pumpkin_orange_jackolantern.gltf", Vector3(cx + 5.0 * s, 0, 2.0), PI, 1.0)
	_light(door + Vector3(0, 1.2, 0.6), Color(1.0, 0.65, 0.35), 1.2, 5.0)


func _go_down() -> void:
	travel(cell_center(layout.cata_start_rect.position + layout.cata_start_rect.size / 2) + Vector3(0, 0, 2.0), "Les catacombes")


func _go_up() -> void:
	travel(Vector3((layout.main_x + 0.5) * CELL4, 0, 10.4), "Le Cimetière maudit")


## Catacombes : murs, coins arrondis et piliers du Modular Dungeon Kit, ou du Modular Cave Kit dans les cavernes.
func _catacomb_walls() -> void:
	for y in layout.height:
		for x in layout.width:
			var c := Vector2i(x, y)
			if layout.zone_at(x, y) != 2 or layout.boss_rect.has_point(c):
				continue
			var kit := _kit_of(c)
			var center := cell_center(c)
			var turn := _corner_turn(c)
			if turn >= 0:
				var b := Basis(Vector3.UP, PI * 0.5 * turn)
				_put(kit + "template-corner.glb", Transform3D(b.scaled(Vector3(1.0, LOW_WALL, 1.0)) if turn == 0 else b, center), true)
				_corner_collision(center, turn)
				continue
			for d in DIRS:
				if layout.is_floor(x + d.x, y + d.y):
					continue
				var yaw := atan2(float(d.x), float(d.y))
				var edge := center + Vector3(d.x, 0, d.y) * CELL4 * 0.5
				var wall := kit + ("template-wall-detail-a.glb" if _rng.randf() < 0.3 else "template-wall.glb")
				var b := Basis(Vector3.UP, yaw)
				if LOW.has(d):
					b = b.scaled(Vector3(1.0, LOW_WALL, 1.0))
				_put(wall, Transform3D(b, edge), true)
				_box(Vector3(CELL4 + 0.2, 4.0, WALL_DEPTH), edge - Vector3(d.x, 0, d.y) * WALL_DEPTH * 0.5 + Vector3(0, 2.0, 0), yaw)
	# Piliers aux angles rentrants (trois cases de sol autour d'un coin), hors crypte royale.
	for y in range(1, layout.height):
		for x in range(1, layout.width):
			var n := 0
			var royal := false
			for o: Vector2i in [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(-1, -1)]:
				var c := Vector2i(x + o.x, y + o.y)
				if layout.zone_at(c.x, c.y) == 2:
					n += 1
				royal = royal or layout.boss_rect.has_point(c)
			if n == 3 and not royal:
				var p := Vector3(x * CELL4, 0, y * CELL4)
				var low := not layout.is_floor(x, y)
				_put(_kit_of(Vector2i(x - 1, y - 1)) + "template-detail.glb", Transform3D(Basis.IDENTITY.scaled(Vector3(1.0, LOW_WALL if low else 1.0, 1.0)), p), true)
				_cylinder(0.75, 4.0, p)


## Coin arrondi : arc de rayon 3,5 m centré sur le coin intérieur de la case.
func _corner_collision(center: Vector3, turn: int) -> void:
	var b := Basis(Vector3.UP, PI * 0.5 * turn)
	var pivot := center + b * Vector3(-CELL4 * 0.5, 0, -CELL4 * 0.5)
	for k in 4:
		var a := PI * 0.5 * (k + 0.5) / 4.0
		var dir := b * Vector3(cos(a), 0, sin(a))
		_box(Vector3(1.6, 4.0, WALL_DEPTH), pivot + dir * (3.5 + WALL_DEPTH * 0.3) + Vector3(0, 2.0, 0), atan2(dir.x, dir.z))


## Crypte royale : murs du KayKit Dungeon Pack (centrés sur le bord des cases), piliers aux angles.
func _royal_crypt_walls() -> void:
	var r := layout.boss_rect
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var c := Vector2i(x, y)
			for d in DIRS:
				var n := c + d
				if r.has_point(n) or layout.is_floor(n.x, n.y):
					continue
				var edge := cell_center(c) + Vector3(d.x, 0, d.y) * CELL4 * 0.5
				var yaw := atan2(float(-d.x), float(-d.y)) # face décorée (+Z local) vers l'intérieur
				var roll := _rng.randf()
				var wall := "wall.gltf"
				if roll < 0.2:
					wall = "wall_cracked.gltf"
				elif roll < 0.35 and d.y == -1:
					wall = "wall_archedwindow_gated.gltf"
				var b := Basis(Vector3.UP, yaw)
				if LOW.has(d):
					b = b.scaled(Vector3(1.0, LOW_WALL, 1.0))
				_put(KK + wall, Transform3D(b, edge), true)
				_box(Vector3(CELL4 + 0.2, 4.0, 1.0), edge + Vector3(0, 2.0, 0), yaw)
	for vx: int in [r.position.x, r.end.x]:
		for vy: int in [r.position.y, r.end.y]:
			var p := Vector3(vx * CELL4, 0, vy * CELL4)
			var low := vx == r.end.x or vy == r.end.y
			_put(KK + "pillar.gltf", Transform3D(Basis.IDENTITY.scaled(Vector3(1.0, LOW_WALL if low else 1.0, 1.0)), p), true)


# =====================================================================================
# Arches des catacombes ; ni portes ni salles cachées
# =====================================================================================

func _build_doors() -> void:
	for i in layout.cata_rooms.size():
		var room := layout.cata_rooms[i]
		if room == layout.boss_rect:
			continue
		for o in _openings(room):
			if LOW.has(o["dir"]):
				continue # entrée côté caméra : pas d'arche au-dessus des murets
			var yaw := 0.0 if (o["dir"] as Vector2i).y != 0 else PI * 0.5
			var p: Vector3 = o["pos"]
			var gate := (CAVE + "gate-rock.glb") if str(_room_style.get(i, "donjon")) == "grotte" else (DK + "gate.glb")
			_put(gate, Transform3D(Basis(Vector3.UP, yaw), p), true)
			var along := Basis(Vector3.UP, yaw) * Vector3.RIGHT
			for s: float in [-1.0, 1.0]:
				_box(Vector3(0.5, 4.0, 1.0), p + along * 2.05 * s + Vector3(0, 2.0, 0), yaw)
	_flush()


## Entrées d'une case de large d'une salle : [{pos (milieu du bord), dir (vers l'extérieur)}].
func _openings(r: Rect2i) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			for d in DIRS:
				var n := Vector2i(x, y) + d
				if r.has_point(n) or not layout.is_floor(n.x, n.y):
					continue
				var side := Vector2i(d.y, d.x)
				if layout.is_floor(n.x + side.x, n.y + side.y) or layout.is_floor(n.x - side.x, n.y - side.y):
					continue
				out.append({"pos": cell_center(Vector2i(x, y)) + Vector3(d.x, 0, d.y) * CELL4 * 0.5, "dir": d})
	return out


func _build_room_covers() -> void:
	for i in gen.rooms.size():
		_state_add("rooms", i)


# =====================================================================================
# Décor du cimetière
# =====================================================================================

func _decorate() -> void:
	for plot in layout.plots:
		_decorate_plot(plot)
	_outside_trees()
	_alley_lights()
	_entrance()
	_catacomb_decor()


func _decorate_plot(plot: Dictionary) -> void:
	var group: Array = plot["cells"]
	var kind := str(plot["kind"])
	var rect: Rect2i = plot["rect"]
	var centre := Vector2i(rect.position + rect.size / 2)
	var big := rect.size.x >= 2 and rect.size.y >= 2 and group.has(centre)
	if kind in ["caveau", "fontaine"] and big:
		var p := cell_center(centre) - Vector3(2.0, 0, 2.0) if rect.size.x % 2 == 0 and rect.size.y % 2 == 0 else cell_center(centre)
		if kind == "caveau":
			_prop(GY + ("crypt-large.glb" if _rng.randf() < 0.6 else "crypt-small.glb"), p, 0.0, GY_SCALE, true, true)
			for s: float in [-1.0, 1.0]:
				_prop(GY + "lightpost-single.glb", p + Vector3(3.0 * s, 0, 3.2), 0.0, GY_SCALE, false)
				_light(p + Vector3(3.0 * s, 2.4, 3.4), Color(1.0, 0.75, 0.4), 1.4, 6.0)
				_prop(GY + "iron-fence.glb", p + Vector3(3.6 * s, 0, 0.0), PI * 0.5, GY_SCALE, true, true)
		else:
			_prop(TOWN + "fountain-round-detail.glb", p, 0.0, 3.0, true, true) # la fontaine asséchée
			_prop(HW + "tree_dead_large_decorated.gltf", p + Vector3(0, 0.6, 0), 0.0, 0.8, false)
			for k in 4:
				var a := TAU * k / 4.0 + PI * 0.25
				_prop(HW + "bench.gltf", p + Vector3(cos(a), 0, sin(a)) * 4.6, -a + PI * 0.5, 1.0)
			_light(p + Vector3(0, 3.0, 0), Color(0.5, 0.8, 1.0), 1.2, 9.0, 0.5)
		# Les cases voisines laissent la place à la pièce maîtresse.
		for c: Vector2i in group:
			if cell_center(c).distance_to(p) < 4.5:
				props.append(cell_center(c))
	for c: Vector2i in group:
		if layout.start_rect.has_point(c) or _crowded(cell_center(c), 2.2):
			continue
		var p := cell_center(c)
		match kind:
			"bosquet":
				_grove_cell(p)
			"chapelle":
				if c == centre or _rng.randf() < 0.3:
					_chapel_cell(p)
				else:
					_graves_cell(p, c)
			"fosses":
				if open_graves.has(c):
					_open_grave_cell(p, c)
				else:
					_graves_cell(p, c)
			_:
				_graves_cell(p, c)


## Deux tombes côte à côte (ou une seule et une décoration), tournées vers le sud ; un mort sous chacune, parfois.
func _graves_cell(p: Vector3, c: Vector2i) -> void:
	var spots: Array[float] = [0.0]
	if _rng.randf() < 0.6:
		spots = [-1.0, 1.0]
	for sx in spots:
		var at := p + Vector3(sx, 0, -0.6)
		if _rng.randf() < 0.75:
			_prop(GRAVES[_rng.randi_range(0, GRAVES.size() - 1)], at, _rng.randf_range(-0.12, 0.12), 0.9 if sx != 0.0 else 1.0)
		else:
			_prop(GY + SMALL_GRAVES[_rng.randi_range(0, SMALL_GRAVES.size() - 1)] + ".glb", at, _rng.randf_range(-0.2, 0.2), GY_SCALE)
		_mark_grave(at + Vector3(0, 0, 1.4), c)
	if spots.size() == 1:
		var roll := _rng.randf()
		var side := p + Vector3(1.4 * (1 if _rng.randf() < 0.5 else -1), 0, 0.8)
		if roll < 0.3:
			_prop(HW + "pumpkin_orange_jackolantern.gltf", side, _rng.randf() * TAU, 0.8)
			_light(side + Vector3(0, 0.8, 0), Color(1.0, 0.55, 0.15), 1.0, 4.0, 0.5)
		elif roll < 0.5:
			_prop(HW + "skull_candle.gltf", side, _rng.randf() * TAU, 0.8, false)
		elif roll < 0.7:
			_prop(HW + "candle_melted.gltf", side, 0.0, 1.0, false)
	elif _rng.randf() < 0.25:
		_prop(HW + "candle_thin.gltf", p + Vector3(0, 0, 0.6), 0.0, 1.0, false)


## Fosse ouverte : un cercueil sorti de terre, la pelle du fossoyeur, des os.
func _open_grave_cell(p: Vector3, c: Vector2i) -> void:
	_box(Vector3(2.4, 2.0, 2.8), p + Vector3(0, 1.0, 0)) # on ne tombe pas dans la fosse
	_prop(HW + ("coffin.gltf" if _rng.randf() < 0.5 else "coffin_decorated.gltf"), p + Vector3(1.4, 0, 0.6), PI * 0.5 + _rng.randf_range(-0.3, 0.3), 0.6)
	_prop(GY + "shovel-dirt.glb", p + Vector3(-1.5, 0, 1.2), _rng.randf() * TAU, GY_SCALE, false)
	_prop(HW + ["bone_A.gltf", "bone_B.gltf", "bone_C.gltf"][_rng.randi_range(0, 2)], p + Vector3(-0.8, 0.05, 1.6), _rng.randf() * TAU, 1.0, false)
	_mark_grave(p + Vector3(0, 0, 1.7), c)


## Bosquet : arbres morts, citrouilles, rochers.
func _grove_cell(p: Vector3) -> void:
	var tree: String = [HW + "tree_dead_large.gltf", HW + "tree_dead_medium.gltf", HW + "tree_dead_small.gltf", HW + "tree_dead_large_decorated.gltf"][_rng.randi_range(0, 3)]
	var at := p + Vector3(_rng.randf_range(-0.8, 0.8), 0, _rng.randf_range(-0.8, 0.8))
	_prop(tree, at, _rng.randf() * TAU, 1.0, false)
	_cylinder(0.45, 3.0, at)
	var roll := _rng.randf()
	var side := p + Vector3(_rng.randf_range(-1.4, 1.4), 0, 1.3)
	if roll < 0.35:
		_prop(HW + ["pumpkin_orange.gltf", "pumpkin_yellow.gltf", "pumpkin_orange_small.gltf", "pumpkin_yellow_jackolantern.gltf"][_rng.randi_range(0, 3)], side, _rng.randf() * TAU, 1.0)
	elif roll < 0.65:
		_prop(TOWN + ["rock-large.glb", "rock-small.glb", "rock-wide.glb"][_rng.randi_range(0, 2)], side, _rng.randf() * TAU, 1.6, true, true)
	else:
		_prop(HW + "ribcage.gltf", side + Vector3(0, 0.4, 0), _rng.randf() * TAU, 1.0, false)


## Chapelle : petit sanctuaire aux bougies et ses offrandes (Food Kit) sur une dalle, un banc.
func _chapel_cell(p: Vector3) -> void:
	_prop(HW + "shrine_candles.gltf", p + Vector3(0, 0, -1.0), 0.0, 1.0)
	_prop(HW + "plaque.gltf", p + Vector3(0, 0, 0.6), 0.0, 0.8, false)
	for k in 3:
		var item: String = OFFERINGS[_rng.randi_range(0, OFFERINGS.size() - 1)]
		_prop(FOOD + item + ".glb", p + Vector3(-0.5 + 0.5 * k, 0.33, 0.6 + _rng.randf_range(-0.2, 0.2)), _rng.randf() * TAU, FOOD_SCALE, false, true)
	_prop(HW + "bench_decorated.gltf", p + Vector3(0, 0, 1.7), PI, 0.8)
	_light(p + Vector3(0, 1.8, -0.4), Color(1.0, 0.7, 0.35), 1.3, 5.0, 0.4)


## Arbres du dehors, au nord et à l'ouest (loin de la caméra) : pins d'automne et arbres morts.
func _outside_trees() -> void:
	for x in range(-3, layout.cw + 2):
		for y in range(-3, layout.ch + 2):
			var outside := x < 0 or y < 0
			if not outside or _rng.randf() < 0.35:
				continue
			var p := cell_center(Vector2i(x, y)) + Vector3(_rng.randf_range(-1.2, 1.2), 0, _rng.randf_range(-1.2, 1.2))
			var trees := [HW + "tree_pine_orange_large.gltf", HW + "tree_pine_yellow_medium.gltf", HW + "tree_pine_orange_medium.gltf",
				HW + "tree_dead_large.gltf", HW + "tree_pine_yellow_large.gltf", GY + "pine-crooked.glb"]
			var t: String = trees[_rng.randi_range(0, trees.size() - 1)]
			_prop(t, p, _rng.randf() * TAU, GY_SCALE if t.begins_with(GY) else 1.0, false)


## Lanternes : sur poteau le long de l'allée principale, posées au sol aux croisements.
func _alley_lights() -> void:
	var k := 0
	for y in range(3, layout.ch - 1):
		k += 1
		if k % 2 != 0:
			continue
		var side := 1.0 if (k / 2) % 2 == 0 else -1.0
		var p := cell_center(Vector2i(layout.main_x, y)) + Vector3(1.75 * side, 0, 0)
		_prop(HW + "post_lantern.gltf", p, PI * 0.5 * -side, 1.0, false)
		_cylinder(0.25, 3.0, p)
		_light(p + Vector3(-1.2 * side, 2.6, 0), Color(1.0, 0.62, 0.3), 2.0, 9.0)
	for y in layout.ch:
		for x in layout.cw:
			if x == layout.main_x or not layout.is_alley(x, y):
				continue
			var links := 0
			for d in DIRS:
				if layout.is_alley(x + d.x, y + d.y):
					links += 1
			if links >= 3 and _rng.randf() < 0.7:
				var p := cell_center(Vector2i(x, y)) + Vector3(1.5, 0, -1.5)
				_prop(HW + "lantern_standing.gltf", p, 0.0, 1.0, false)
				_light(p + Vector3(0, 1.0, 0), Color(1.0, 0.65, 0.3), 1.5, 7.0)


## L'entrée : réverbères (Fantasy Town Kit) de part et d'autre de l'arche, la charrette du fossoyeur et son cercueil.
func _entrance() -> void:
	var gate := Vector3((layout.main_x + 0.5) * CELL4, 0, layout.ch * CELL4)
	for s: float in [-1.0, 1.0]:
		_prop(TOWN + "lantern.glb", gate + Vector3(3.2 * s, 0, 1.4), 0.0, 2.0, false, true)
		_light(gate + Vector3(3.2 * s, 3.0, 1.6), Color(1.0, 0.7, 0.4), 1.8, 8.0)
	var cart := gate + Vector3(-6.5, 0, 2.6)
	_prop(TOWN + "cart-high.glb", cart, PI * 0.5, 2.6, true, true)
	_prop(HW + "coffin.gltf", cart + Vector3(0, 1.3, 0), PI * 0.5, 0.55, false)
	_prop(HW + "post_skull.gltf", gate + Vector3(6.0, 0, 2.2), PI, 1.0, false)


# =====================================================================================
# Décor des catacombes (KayKit Dungeon Pack, ossements)
# =====================================================================================

func _catacomb_decor() -> void:
	# Arrivée : l'escalier qui remonte au cimetière, contre le mur nord de la salle.
	var s := layout.cata_start_rect
	var stair := Vector3((s.position.x + s.size.x * 0.5) * CELL4, 0, s.position.y * CELL4 + 1.2)
	_prop(KK + "stairs_walled.gltf", stair + Vector3(0, 0, 1.0), PI, 0.8, true, true)
	catacomb_stairs = Interactable.create(self, stair + Vector3(0, 0, 3.4), "Remonter au cimetière", _go_up, 2.2)
	_light(stair + Vector3(0, 2.5, 3.0), Color(0.6, 0.7, 1.0), 1.6, 8.0, 0.1)
	for i in layout.cata_rooms.size():
		var r := layout.cata_rooms[i]
		if r == layout.boss_rect:
			continue
		var cave := str(_room_style.get(i, "donjon")) == "grotte"
		var openings := _openings(r)
		var lo := Vector3(r.position.x * CELL4, 0, r.position.y * CELL4)
		var hi := Vector3(r.end.x * CELL4, 0, r.end.y * CELL4)
		# Torches murales sur le mur du fond (nord).
		for k in 2:
			var tx := lo.x + (hi.x - lo.x) * (k + 1) / 3.0
			var t := Vector3(tx, 2.2, lo.z + WALL_DEPTH + 0.05)
			if _near(t, openings, 2.5):
				continue
			_prop(KK + "torch_mounted.gltf", t, 0.0, 1.0, false)
			_light(t + Vector3(0, 0.5, 0.8), Color(1.0, 0.55, 0.25), 2.4, 10.0)
		for spot in _wall_band(r, 2.4, 2.0):
			if _near(spot, openings, 3.2) or _crowded(spot, 1.7) or _rng.randf() < 0.15:
				continue
			if r == layout.cata_start_rect and spot.distance_to(stair) < 4.5:
				continue
			var to_c := (lo + hi) * 0.5 - spot
			var yaw := atan2(to_c.x, to_c.z)
			var roll := _rng.randf()
			if cave:
				if roll < 0.35:
					_prop(TOWN + ["rock-large.glb", "rock-wide.glb", "rock-small.glb"][_rng.randi_range(0, 2)], spot, _rng.randf() * TAU, 1.6, true, true)
				elif roll < 0.6:
					_prop(HW + "skull_candle.gltf", spot, yaw, 0.9, false)
					_light(spot + Vector3(0, 1.0, 0), Color(1.0, 0.6, 0.3), 1.0, 4.5)
				elif roll < 0.8:
					_prop(HW + "ribcage.gltf", spot + Vector3(0, 0.4, 0), _rng.randf() * TAU, 1.0, false)
				else:
					_prop(GY + "coffin-old.glb", spot, yaw + PI * 0.5, GY_SCALE)
			else:
				var pool := [KK + "barrel_large.gltf", KK + "barrel_small_stack.gltf", KK + "crates_stacked.gltf", KK + "box_large.gltf",
					KK + "trunk_medium_A.gltf", KK + "keg.gltf", GY + "coffin.glb", KK + "candle_triple.gltf", HW + "bone_C.gltf"]
				var item: String = pool[_rng.randi_range(0, pool.size() - 1)]
				_prop(item, spot, yaw + (PI * 0.5 if item.ends_with("coffin.glb") else 0.0), GY_SCALE if item.begins_with(GY) else 0.8, not item.contains("candle") and not item.contains("bone"), true)
				if item.contains("candle"):
					_light(spot + Vector3(0, 1.0, 0), Color(1.0, 0.7, 0.35), 1.0, 4.5)


## Points le long des murs d'une salle, à `inset` m des bords de ses cases.
func _wall_band(r: Rect2i, inset: float, spacing: float) -> Array[Vector3]:
	var lo := Vector2(r.position) * CELL4 + Vector2(inset, inset)
	var hi := Vector2(r.end) * CELL4 - Vector2(inset, inset)
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


func _near(p: Vector3, openings: Array[Dictionary], dist: float) -> bool:
	for o in openings:
		var q: Vector3 = o["pos"]
		if Vector2(q.x - p.x, q.z - p.z).length() < dist:
			return true
	return false


# =====================================================================================
# Ennemis : les morts du cimetière, les catacombes ; le Roi des Os
# =====================================================================================

## Points de réveil des morts du cimetière (devant les tombes) : [{pos, cell}].
var _grave_spots: Array[Dictionary] = []


func _mark_grave(pos: Vector3, c: Vector2i) -> void:
	_grave_spots.append({"pos": pos, "cell": c})


func _spawn_enemies() -> void:
	# Cimetière : un mort sous une tombe sur trois environ, endormi sous terre.
	for i in range(_grave_spots.size() - 1, 0, -1): # mélange tiré de la graine (même cimetière en coop)
		var j := _rng.randi_range(0, i)
		var tmp: Dictionary = _grave_spots[i]
		_grave_spots[i] = _grave_spots[j]
		_grave_spots[j] = tmp
	var budget := _coop_count(_rng.randi_range(12, 16))
	for g in _grave_spots:
		if budget <= 0:
			break
		var pos: Vector3 = g["pos"]
		if pos.distance_to(cell_center(Vector2i(layout.main_x, layout.ch - 1))) < 9.0:
			continue # pas sur la grille d'entrée
		var roll := _rng.randf()
		var kind := "minion"
		if roll > 0.9:
			kind = "mage"
		elif roll > 0.78:
			kind = "rogue"
		elif roll > 0.6:
			kind = "warrior"
		var e := spawn_bones(kind, pos, -2)
		if e != null:
			buried.append(e)
			e.call_deferred("set_dormant", true)
		budget -= 1
	# Catacombes : des groupes éveillés dans chaque salle (sauf l'arrivée et la crypte royale).
	for i in gen.rooms.size():
		if i == gen.boss_room or i == gen.start_room:
			continue
		var r := gen.rooms[i]
		if Rect2i(r.position / 2, r.size / 2) == layout.cata_start_rect:
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
	e.rotation.y = _rng.randf() * TAU if room != -2 else 0.0
	e.walkable_check = is_walkable
	return _place_enemy(e, room) as KayKitSkeleton


## Les morts sortent de terre quand un héros passe à moins de WAKE_RADIUS m.
func _wake_the_dead() -> void:
	if buried.is_empty():
		return
	var heroes := get_tree().get_nodes_in_group("heroes")
	for e in buried.duplicate():
		if not is_instance_valid(e) or not e.is_alive():
			buried.erase(e)
			continue
		for h in heroes:
			var hn := h as Node3D
			if hn != null and not Enemy.is_down(hn) and hn.global_position.distance_to(e.global_position) < WAKE_RADIUS:
				wake(e)
				break


func wake(e: KayKitSkeleton) -> void:
	buried.erase(e)
	e.set_dormant(false)
	e.rise_from_ground()
	e._aggro()
	BossMoves.burst(self, e.global_position, Color(0.35, 0.26, 0.2), 12)
	Sfx.play("bones", -10.0, 0.25)


## La crypte royale : dalles, murs et piliers du KayKit Dungeon Pack, bannières rouges au fond, torches, le
## sarcophage du Roi et son trésor ; le Roi des Os et deux guerriers.
func _spawn_boss_room() -> void:
	var r := layout.boss_rect
	var c := cell_center(r.position + r.size / 2) - Vector3(2.0, 0, 2.0)
	var lo := Vector3(r.position.x * CELL4, 0, r.position.y * CELL4)
	var hi := Vector3(r.end.x * CELL4, 0, r.end.y * CELL4)
	var openings := _openings(r)
	# Bannières et torches sur le mur du fond (face décorée vers la salle).
	for k in 4:
		var x := lo.x + (hi.x - lo.x) * (k + 0.5) / 4.0
		var p := Vector3(x, 0, lo.z + 0.5) # face intérieure du mur
		if _near(p, openings, 2.5):
			continue
		if k == 1 or k == 2:
			_prop(KK + "banner_patternA_red.gltf", p - Vector3(0, 0, 0.5), 0.0, 1.0, false) # (accrochée au milieu du mur)
		else:
			_prop(KK + "torch_mounted.gltf", p + Vector3(0, 2.2, 0), 0.0, 1.0, false)
			_light(p + Vector3(0, 2.7, 0.9), Color(1.0, 0.45, 0.2), 2.6, 11.0)
	# Torches sur les murs latéraux.
	for z: float in [lo.z + (hi.z - lo.z) * 0.35, lo.z + (hi.z - lo.z) * 0.7]:
		var west := Vector3(lo.x + 0.5, 2.2, z)
		if not _near(west, openings, 2.5):
			_prop(KK + "torch_mounted.gltf", west, PI * 0.5, 1.0, false)
			_light(west + Vector3(0.9, 0.5, 0), Color(1.0, 0.45, 0.2), 2.2, 10.0)
	# Quatre colonnes ornées, le sarcophage du Roi au fond, son trésor.
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var p := c + Vector3(6.0 * sx, 0, 6.0 * sz)
			_prop(KK + "pillar_decorated.gltf", p, 0.0, 1.0, false, true)
			_cylinder(0.8, 4.0, p)
	var back := Vector3(c.x, 0, lo.z + 3.0)
	if not _near(back, openings, 4.0):
		_prop(HW + "coffin_decorated.gltf", back, 0.0, 1.0, true, true)
		_prop(KK + "chest_gold.gltf", back + Vector3(3.0, 0, 0.4), -0.3, 0.9, true, true)
		_prop(KK + "coin_stack_large.gltf", back + Vector3(4.4, 0, 1.6), 0.4, 0.8, false, true)
		_prop(KK + "coin_stack_medium.gltf", back + Vector3(-3.6, 0, 1.4), 0.0, 0.8, false, true)
		for s: float in [-1.0, 1.0]:
			_prop(KK + "candle_triple.gltf", back + Vector3(1.8 * s, 0, 1.8), 0.0, 1.0, false)
			_light(back + Vector3(1.8 * s, 1.3, 1.8), Color(1.0, 0.7, 0.35), 1.4, 5.0)
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
	var p := cell_center(layout.boss_rect.position + layout.boss_rect.size / 2) - Vector3(2.0, 0, 2.0)
	if hero != null and is_walkable(hero.global_position + hero.facing * 2.0):
		p = hero.global_position + hero.facing * 2.0
	exit_portal = Portal.new()
	exit_portal.green = true
	exit_portal.position = Vector3(p.x, 0.0, p.z)
	exit_portal.prompt = "Portail vert : retour à la Chèvre Fringante (le cimetière se régénérera)"
	exit_portal.on_enter = _end_dungeon.bind("Cimetière purifié !", true)
	add_child(exit_portal)
