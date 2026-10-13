extends Level
## Introduction : une nuit de Lune de Sang (encore un truc cliché de métalleux).
##   1. Cinématique : une lune sanglante dans la brume, puis le cimetière près de la
##      chapelle — tombes déterrées et vides, cadavres de toutes les races amicales.
##   2. Le héros, au sortir de la messe noire : les morts se sont ENCORE échappés ; il fait mine de rien et file
##      boire un thé glacé à la goyave à la Chèvre Fringante (dialogue « intro_hero »).
##   3. Environ 20 s de marche sur une route pavée sinueuse, entre champs et
##      prairies, cadavres ensanglantés et chauves-souris ; orage sans pluie : des éclairs
##      frappent le décor hors de la route (flash + légers tremblements d'écran).
##   4. Au bout de la route, la Chèvre Fringante : on entre, et les portes se referment.
## La route part vers le « haut de l'écran » de la caméra isométrique puis serpente.

const ROAD_LENGTH := 110.0 # ≈ 20 s de marche à 5,5 m/s (longueur réelle du tracé sinueux)
const ROAD_HALF_WIDTH := 1.7
const ROAM_HALF_WIDTH := 13.0 # on peut s'écarter un peu dans les champs, pas plus
const START_S := 3.0
const TAVERN_S := ROAD_LENGTH + 6.0
## Kits d'assets (KitProps, chemins relatifs à assets/models/kits/).
const HW := "halloween/"
const GY := "cimetiere/"
const TOWN := "ville/"

var _rng := RandomNumberGenerator.new()
var _moon_light: DirectionalLight3D
var _bats: Array[Node3D] = []
var _bat_data: Array[Vector4] = [] # (rayon, vitesse, phase, hauteur)
var _cine_cam: Camera3D
var _cine_tween: Tween
var _cine_layer: CanvasLayer
var _cinematic := true
var _entered := false
var _t := 0.0


func _ready() -> void:
	_rng.seed = 666
	setup_level("night", "")
	_build_sky_and_light()
	_build_ground()
	_build_road()
	_build_fields()
	_build_cemetery()
	_build_road_side()
	_build_tavern_exterior()
	_spawn_bats()
	spawn_hero(road_point(START_S) + road_right(START_S) * 0.5)
	hero.captive = true
	hero.facing = road_dir(START_S)
	hero.model.rotation.y = atan2(hero.facing.x, hero.facing.z)
	Sfx.play_storm_music() # musique d'orage pendant toute l'intro
	Sfx.music_strike.connect(_on_music_strike)
	_play_cinematic()


# =====================================================================================
# Géométrie de la route : s = distance réellement parcourue le long du tracé. La route
# sort tout droit du cimetière puis serpente en virages marqués (jusqu'à ~70°) entre les
# champs, avant de se redresser devant la taverne.
# =====================================================================================

const PATH_STEP := 1.0
const PATH_START := -30.0
var _path := PackedVector3Array()


## Cap de la route (radians, par rapport au « haut de l'écran ») selon la distance.
func _heading(s: float) -> float:
	var k := smoothstep(14.0, 26.0, s) * (1.0 - smoothstep(ROAD_LENGTH - 16.0, ROAD_LENGTH - 4.0, s))
	return (sin((s - 14.0) / 11.0) * 1.05 + sin(s / 4.5 + 1.3) * 0.22) * k


func _build_path() -> void:
	_path.clear()
	var p := IsoCamera.SCREEN_UP * PATH_START
	var s := PATH_START
	while s <= TAVERN_S + 30.0:
		_path.append(p)
		p += IsoCamera.SCREEN_UP.rotated(Vector3.UP, _heading(s)) * PATH_STEP
		s += PATH_STEP


func road_point(s: float) -> Vector3:
	if _path.is_empty():
		_build_path()
	var f := (s - PATH_START) / PATH_STEP
	var last := _path.size() - 1
	if f <= 0.0:
		return _path[0] + (_path[1] - _path[0]) * f
	if f >= last:
		return _path[last] + (_path[last] - _path[last - 1]) * (f - last)
	var i := int(f)
	return _path[i].lerp(_path[i + 1], f - i)


func road_dir(s: float) -> Vector3:
	return (road_point(s + 0.5) - road_point(s - 0.5)).normalized()


func road_right(s: float) -> Vector3:
	return road_dir(s).cross(Vector3.UP).normalized() * -1.0


## Distance parcourue au point du tracé le plus proche de `p`.
func road_s(p: Vector3) -> float:
	if _path.is_empty():
		_build_path()
	var flat := Vector3(p.x, 0.0, p.z)
	var best := INF
	var best_s := 0.0
	for i in _path.size() - 1:
		var a := _path[i]
		var ab := _path[i + 1] - a
		var t := clampf((flat - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var d := flat.distance_squared_to(a + ab * t)
		if d < best:
			best = d
			best_s = PATH_START + (i + t) * PATH_STEP
	# Au-delà des extrémités : on prolonge (pour borner le héros avant le cimetière).
	if best_s <= PATH_START + 0.01:
		best_s = PATH_START + (flat - _path[0]).dot(road_dir(PATH_START))
	return best_s


## Distance du point au bord de la chaussée la plus proche (pour placer le décor).
func dist_to_road(p: Vector3) -> float:
	var s := road_s(p)
	return Vector3(p.x, 0.0, p.z).distance_to(road_point(s))


# =====================================================================================
# Ciel, lune de sang, sol
# =====================================================================================

func _build_sky_and_light() -> void:
	_moon_light = DirectionalLight3D.new()
	_moon_light.light_color = Color(0.9, 0.62, 0.62)
	_moon_light.light_energy = 1.4
	_moon_light.rotation_degrees = Vector3(-70, 150, 0) # haute dans le ciel : ombres courtes
	_moon_light.shadow_enabled = true
	add_child(_moon_light)
	# La lune de sang, très loin au-dessus du bout de la route (vue pendant la cinématique).
	var moon_pos := _moon_position()
	Visuals.sphere(self, 22.0, moon_pos, Visuals.glow_mat(Color(0.95, 0.1, 0.05), 3.0))
	# Cratères plus sombres, tournés vers la caméra de la cinématique.
	var toward := (road_point(-8.0) + Vector3(0, 3, 0) - moon_pos).normalized()
	for k in 7:
		var off := Vector3(_rng.randf_range(-13, 13), _rng.randf_range(-13, 13), _rng.randf_range(-13, 13))
		off -= toward * off.dot(toward)
		Visuals.sphere(self, _rng.randf_range(2.0, 4.5), moon_pos + toward * 20.5 + off * 0.8, Visuals.glow_mat(Color(0.55, 0.03, 0.02), 2.0), Vector3(1, 1, 0.3))
	for k in 2:
		var halo := Visuals.sphere(self, 27.0 + k * 10.0, moon_pos, Visuals.transparent_mat(Color(0.8, 0.08, 0.04, 0.08 - k * 0.035), 1.5))
		halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Brume devant la lune : grands voiles sombres qui dérivent.
	for k in 14:
		var veil := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(_rng.randf_range(30.0, 60.0), _rng.randf_range(8.0, 16.0))
		veil.mesh = q
		var m := StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.albedo_texture = DemonPortal._soft_texture()
		m.albedo_color = Color(0.4, 0.14, 0.14, _rng.randf_range(0.25, 0.45))
		veil.material_override = m
		veil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		veil.position = moon_pos + Vector3(_rng.randf_range(-35, 35), _rng.randf_range(-18, 14), _rng.randf_range(10, 30))
		veil.set_meta("drift", _rng.randf_range(0.8, 2.5))
		veil.add_to_group("intro_veils")
		add_child(veil)


func _moon_position() -> Vector3:
	return road_point(40.0) + IsoCamera.SCREEN_UP * 160.0 + Vector3(0, 110.0, 0)


func _build_ground() -> void:
	var center := road_point(ROAD_LENGTH * 0.5)
	var grass := Visuals.textured("herbe_terre", 6.0, Color(0.3, 0.34, 0.28), 0.95)
	var ground := Visuals.box(self, Vector3(420, 0.1, 420), center + Vector3(0, -0.06, 0), grass)
	ground.rotation.y = PI * 0.25
	# Touffes d'herbe et fleurs fanées (MultiMesh).
	var tuft := CylinderMesh.new()
	tuft.top_radius = 0.0
	tuft.bottom_radius = 0.12
	tuft.height = 0.35
	tuft.radial_segments = 4
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = tuft
	mm.instance_count = 2600
	for i in mm.instance_count:
		var s := _rng.randf_range(-20.0, ROAD_LENGTH + 20.0)
		var side := _rng.randf_range(ROAD_HALF_WIDTH + 0.3, 40.0) * (1.0 if _rng.randf() < 0.5 else -1.0)
		var p := road_point(s) + road_right(s) * side
		if dist_to_road(p) < ROAD_HALF_WIDTH + 0.3:
			p.y = -5.0 # dans un virage, la touffe tomberait sur la chaussée : on l'enterre
		if in_cemetery(p):
			p.y = -5.0 # le cimetière est en terre battue
		var sc := _rng.randf_range(0.6, 1.5)
		mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(sc, sc * _rng.randf_range(0.8, 1.6), sc)), p + Vector3(0, 0.15 * sc, 0)))
		var v := _rng.randf_range(0.7, 1.2)
		mm.set_instance_color(i, Color(0.16 * v, 0.23 * v, 0.1 * v))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	mmi.material_override = m
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


## Route pavée : les pavés du KayKit Halloween Bits (deux de front, tous les 1,9 m, tournés au hasard), comme les
## allées du Cimetière maudit, sur des bas-côtés de terre battue.
func _build_road() -> void:
	var tiles: Array[String] = [HW + "path_A.gltf", HW + "path_B.gltf", HW + "path_C.gltf", HW + "path_D.gltf"]
	var batches := {}
	for t in tiles:
		batches[t] = []
	var s := -8.0
	while s < TAVERN_S + 2.0:
		var dir := road_dir(s)
		var right := road_right(s)
		var yaw := atan2(dir.x, dir.z)
		for side: float in [-0.92, 0.92]:
			var t: String = tiles[_rng.randi_range(0, tiles.size() - 1)]
			var basis := Basis(Vector3.UP, yaw + PI * 0.5 * _rng.randi_range(0, 3))
			(batches[t] as Array).append(Transform3D(basis, road_point(s) + right * side + Vector3(0, 0.03, 0)) * (KitProps.piece(t)[1] as Transform3D))
		s += 1.85
	for t: String in batches:
		var xforms: Array = batches[t]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = KitProps.piece(t)[0]
		mm.instance_count = xforms.size()
		for i in xforms.size():
			mm.set_instance_transform(i, xforms[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Route_" + t.get_file().get_basename()
		mmi.multimesh = mm
		add_child(mmi)
	# Bas-côtés de terre battue.
	var dirt := Visuals.textured("terre", 3.0, Color(0.32, 0.27, 0.22), 1.0)
	var k := -8.0
	while k < TAVERN_S:
		var d := road_dir(k)
		var bed := Visuals.box(self, Vector3(ROAD_HALF_WIDTH * 2.0 + 1.2, 0.02, 4.4), road_point(k + 2.0) + Vector3(0, 0.005, 0), dirt)
		bed.rotation.y = atan2(d.x, d.z)
		k += 4.0


## Champs de blé sombres, prairies, clôtures et arbres morts de part et d'autre.
func _build_fields() -> void:
	var wheat := Visuals.mat(Color(0.28, 0.24, 0.1), 0.95)
	var furrow := Visuals.mat(Color(0.08, 0.05, 0.03), 1.0)
	var field_centers: Array[Vector3] = []
	var s := 30.0
	while s < ROAD_LENGTH - 20.0:
		for side: float in [-1.0, 1.0]:
			if _rng.randf() < 0.35:
				continue
			var right := road_right(s)
			var dir := road_dir(s)
			var center := road_point(s) + right * side * _rng.randf_range(10.0, 18.0)
			if dist_to_road(center) < 10.5:
				continue # dans un virage, le champ mordrait sur la route
			var crowded := false
			for other in field_centers:
				crowded = crowded or other.distance_to(center) < 15.0
			if crowded:
				continue # pas de champs qui se chevauchent
			field_centers.append(center)
			var field := Node3D.new()
			field.position = center
			field.rotation.y = atan2(dir.x, dir.z) + _rng.randf_range(-0.15, 0.15)
			add_child(field)
			Visuals.box(field, Vector3(9.0, 0.02, 14.0), Vector3(0, 0.01, 0), furrow)
			for r in 9:
				var ridge := Visuals.box(field, Vector3(0.55, 0.4, 13.5), Vector3(-4.0 + r * 1.0, 0.2, 0), wheat)
				ridge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		s += _rng.randf_range(18.0, 26.0)
	# Clôtures de bois le long de la route (Fantasy Town Kit, tronçons de 4 m).
	s = 16.0
	while s < ROAD_LENGTH:
		for side: float in [-1.0, 1.0]:
			if _rng.randf() < 0.25:
				continue
			var mid_s := s + 2.0
			var p := road_point(mid_s) + road_right(mid_s) * side * (ROAD_HALF_WIDTH + 1.4)
			var d := road_dir(mid_s)
			_kit(TOWN + ("fence-broken.glb" if _rng.randf() < 0.2 else "fence.glb"), p, atan2(d.x, d.z) + _rng.randf_range(-0.05, 0.05), 4.0, false, true)
		s += 4.0
	# Arbres morts et pins d'automne (KayKit Halloween Bits).
	for k in 26:
		var ts := _rng.randf_range(0.0, ROAD_LENGTH)
		var p := road_point(ts) + road_right(ts) * (_rng.randf_range(6.0, 30.0) * (1.0 if _rng.randf() < 0.5 else -1.0))
		if dist_to_road(p) > 4.0:
			_dead_tree(p)


## Arbre mort (ou, plus rarement, pin d'automne) du KayKit Halloween Bits, avec une collision au tronc.
func _dead_tree(p: Vector3) -> void:
	var trees := [HW + "tree_dead_large.gltf", HW + "tree_dead_medium.gltf", HW + "tree_dead_small.gltf",
		HW + "tree_dead_large_decorated.gltf", HW + "tree_pine_orange_medium.gltf", HW + "tree_pine_yellow_small.gltf"]
	_kit(trees[_rng.randi_range(0, trees.size() - 1)], p, _rng.randf() * TAU, _rng.randf_range(0.9, 1.2))
	Visuals.solid_cylinder(self, 0.35, 2.0, p + Vector3(0, 1.0, 0))


# =====================================================================================
# Cimetière et chapelle
# =====================================================================================

## Repère du cimetière : origine sur la route (s = 2), u vers la droite, v vers le portail (l'avant de la route).
## Il fait 28 × 28 m : u de -14 à 14, v de -18 (côté caméra) à 10 (le portail, d'où part la route).
var _cem_o := Vector3.ZERO
var _cem_f := Vector3.ZERO
var _cem_r := Vector3.ZERO
var _cem_yaw := 0.0


func _cem(u: float, v: float) -> Vector3:
	return _cem_o + _cem_r * u + _cem_f * v


## Le point est-il dans l'enceinte du cimetière (avec une marge d'un mètre) ?
func in_cemetery(p: Vector3) -> bool:
	var o := road_point(2.0)
	var d := Vector3(p.x - o.x, 0.0, p.z - o.z)
	var u := d.dot(road_right(2.0))
	var v := d.dot(road_dir(2.0))
	return absf(u) < 15.0 and v > -19.0 and v < 11.0


## Pièce d'un kit (KitProps) ; `solid` : une collision suit son emprise.
func _kit(path: String, pos: Vector3, yaw: float, s: float = 1.0, solid: bool = false, centered: bool = false) -> Node3D:
	var n := KitProps.place(self, path, pos, yaw, s, centered)
	if path.contains("floor_dirt"):
		_darken(n)
	if solid:
		var fp := KitProps.footprint(path, pos, yaw, s, centered)
		var size: Vector3 = fp[1]
		if size.y > 0.4:
			var body := Visuals.solid(self, Vector3(size.x, 2.4, size.z), (fp[0] as Vector3) + Vector3(0, 1.2, 0))
			body.rotation.y = yaw
	return n


## Terre du cimetière assombrie : sous la lune de sang, la terre claire du kit paraîtrait rose pâle.
var _dark_mats := {}


func _darken(n: Node) -> void:
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for i in m.mesh.get_surface_count():
			var src := m.mesh.surface_get_material(i) as StandardMaterial3D
			if src == null:
				continue
			if not _dark_mats.has(src):
				var d := src.duplicate() as StandardMaterial3D
				d.albedo_color = Color(0.42, 0.37, 0.34)
				_dark_mats[src] = d
			m.set_surface_override_material(i, _dark_mats[src])


## Mur de collision (invisible) le long d'un côté du cimetière, de (u0, v0) à (u1, v1).
func _cem_wall(u0: float, v0: float, u1: float, v1: float) -> void:
	var a := _cem(u0, v0)
	var b := _cem(u1, v1)
	var body := Visuals.solid(self, Vector3(0.6, 3.0, a.distance_to(b)), (a + b) * 0.5 + Vector3(0, 1.5, 0))
	body.rotation.y = atan2(b.x - a.x, b.z - a.z)


## Le cimetière de Morneval, dans le style du Cimetière maudit (KayKit Halloween Bits, Graveyard Kit) : sol de terre,
## allée pavée jusqu'au portail, clôture de fer, arche d'entrée à la grille arrachée, tombes déterrées et vides à
## droite de l'allée, la chapelle de la messe noire (le mausolée) à gauche, bougies, lanternes, cadavres.
func _build_cemetery() -> void:
	_cem_o = road_point(2.0)
	_cem_f = road_dir(2.0)
	_cem_r = road_right(2.0)
	_cem_yaw = atan2(_cem_f.x, _cem_f.z)
	var face_cam := _cem_yaw + PI # tourné vers la caméra (vers l'arrière du cimetière)
	# Tombes : 12 dalles à droite de l'allée, la plupart déterrées (fosse ouverte).
	var dug := {}
	for u: int in [4, 8, 12]:
		for v: int in [-12, -8, -4, 0]:
			dug[Vector2i(u, v)] = _rng.randf() < 0.7
	# Sol de terre (dalles de 4 m), fosses ouvertes sur les tombes déterrées.
	for iu in range(-3, 4):
		for iv in range(-4, 3):
			var key := Vector2i(iu * 4, iv * 4)
			var open := bool(dug.get(key, false))
			var turn := 0.0 if open else PI * 0.5 * _rng.randi_range(0, 3)
			var tile := _kit(HW + ("floor_dirt_grave.gltf" if open else "floor_dirt.gltf"), _cem(key.x, key.y), face_cam + turn)
			tile.scale = Vector3(1.03, 1.0, 1.03) # pas de joints entre les dalles
	# Tombes : stèle brisée et cercueil éventré pour les fosses, tombe intacte pour les autres.
	for key: Vector2i in dug:
		var c := _cem(key.x, key.y)
		if dug[key]:
			_kit(HW + "grave_A_destroyed.gltf", _cem(key.x, key.y + 1.7), face_cam + _rng.randf_range(-0.2, 0.2), 0.9, true)
			_kit(HW + ("coffin.gltf" if _rng.randf() < 0.5 else "coffin_decorated.gltf"), _cem(key.x + 1.3, key.y - 0.3),
				_cem_yaw + PI * 0.5 + _rng.randf_range(-0.5, 0.5), 0.45)
			if _rng.randf() < 0.5:
				_kit(GY + "shovel-dirt.glb", _cem(key.x - 1.4, key.y - 1.2), _rng.randf() * TAU, 2.0)
			else:
				var bone: String = ["bone_A.gltf", "bone_B.gltf", "bone_C.gltf"][_rng.randi_range(0, 2)]
				_kit(HW + bone, c + Vector3(0, 0.05, 0) - _cem_r * 1.2, _rng.randf() * TAU)
		else:
			_kit(HW + ("grave_A.gltf" if _rng.randf() < 0.5 else "grave_B.gltf"), _cem(key.x, key.y + 0.6), face_cam + _rng.randf_range(-0.1, 0.1), 0.95, true)
	# À gauche, devant la chapelle : petites tombes et croix (Graveyard Kit).
	var small := ["gravestone-round", "gravestone-cross", "gravestone-decorative", "gravestone-broken", "cross-column", "cross-wood"]
	for v: float in [3.0, 6.5]:
		for u: float in [-12.0, -9.5, -7.0, -4.5]:
			if _rng.randf() < 0.25:
				continue
			_kit(GY + str(small[_rng.randi_range(0, small.size() - 1)]) + ".glb", _cem(u + _rng.randf_range(-0.3, 0.3), v), face_cam + _rng.randf_range(-0.3, 0.3), 2.0, true)
	# Allée pavée au fond du cimetière (au-delà, c'est la route elle-même, pavée jusqu'au portail et après).
	var v := -16.0
	while v < -10.5:
		for side: float in [-0.92, 0.92]:
			var t: String = ["path_A.gltf", "path_B.gltf", "path_C.gltf", "path_D.gltf"][_rng.randi_range(0, 3)]
			_kit(HW + t, _cem(side, v) + Vector3(0, 0.03, 0), _cem_yaw + PI * 0.5 * _rng.randi_range(0, 3))
		v += 1.85
	_cemetery_fence()
	_build_chapel()
	# Lanternes : de part et d'autre du portail, et une près de l'allée.
	for side: float in [-1.0, 1.0]:
		_kit(HW + "post_lantern.gltf", _cem(2.9 * side, 8.4), _cem_yaw + PI * 0.5 * side)
		var l := Visuals.flicker_light(self, _cem(1.8 * side, 8.4) + Vector3(0, 2.6, 0), Color(1.0, 0.6, 0.3), 2.0, 9.0)
		l.flicker_amount = 0.5
	_kit(HW + "lantern_standing.gltf", _cem(-2.2, -5.0), 0.0)
	var alley_light := Visuals.flicker_light(self, _cem(-2.2, -5.0) + Vector3(0, 1.0, 0), Color(1.0, 0.62, 0.3), 1.4, 6.0)
	alley_light.flicker_amount = 0.4
	# Bougies de deuil sur quelques tombes.
	for k in 5:
		var cp := _cem(_rng.randf_range(3.0, 12.0), _rng.randf_range(-9.0, 3.0))
		var candle_piece: String = ["candle_melted.gltf", "candle_thin.gltf", "candle_triple.gltf"][_rng.randi_range(0, 2)]
		_kit(HW + candle_piece, cp, _rng.randf() * TAU, 0.8)
		var candle := Visuals.flicker_light(self, cp + Vector3(0, 0.9, 0), Color(1.0, 0.6, 0.3), 1.4, 5.0)
		candle.flicker_amount = 0.5
	# Un arbre mort dans le cimetière ; d'autres au dehors (côté caméra : seulement de petits arbres morts).
	_kit(HW + "tree_dead_large_decorated.gltf", _cem(-11.5, -14.0), _rng.randf() * TAU)
	Visuals.solid_cylinder(self, 0.35, 2.0, _cem(-11.5, -14.0) + Vector3(0, 1.0, 0))
	for k in 14:
		var side := 1.0 if k % 2 == 0 else -1.0
		_dead_tree(_cem(side * _rng.randf_range(16.5, 24.0), _rng.randf_range(-22.0, 8.0)))
	for k in 4:
		var small_tree: String = ["tree_dead_small.gltf", "tree_dead_medium.gltf"][_rng.randi_range(0, 1)]
		_kit(HW + small_tree, _cem(_rng.randf_range(-12.0, 12.0), -20.5 - _rng.randf() * 3.0), _rng.randf() * TAU)
	# Cadavres dans le cimetière et devant son entrée.
	for k in 6:
		_corpse(_cem(_rng.randf_range(-3.0, 11.0), _rng.randf_range(-12.0, 6.0)))
	for k in 5:
		var s := _rng.randf_range(11.0, 22.0)
		_corpse(road_point(s) + road_right(s) * _rng.randf_range(-6.0, 6.0))
	Visuals.label(self, "Cimetière de Morneval", _cem(0, 10.0) + Vector3(0, 5.2, 0), Color(0.75, 0.7, 0.65), 34)


## Clôture de fer (KayKit Halloween Bits) : portail et côtés ; au fond, côté caméra, une grille basse et fine.
## L'arche du portail a perdu sa grille, arrachée et couchée dans l'herbe.
func _cemetery_fence() -> void:
	for u: float in [-12.0, -8.0, -4.0, 4.0, 8.0, 12.0]:
		_kit(HW + ("fence_broken.gltf" if _rng.randf() < 0.25 else "fence.gltf"), _cem(u, 10.0), _cem_yaw)
	for v: float in [-16.0, -12.0, -8.0, -4.0, 0.0, 4.0, 8.0]:
		for side: float in [-1.0, 1.0]:
			_kit(HW + ("fence_broken.gltf" if _rng.randf() < 0.2 else "fence.gltf"), _cem(14.0 * side, v), _cem_yaw + PI * 0.5)
	for u: float in [-12.0, -8.0, -4.0, 0.0, 4.0, 8.0, 12.0]:
		_kit(HW + ("fence_seperate_broken.gltf" if _rng.randf() < 0.3 else "fence_seperate.gltf"), _cem(u, -18.0), _cem_yaw)
	for u: float in [-14.0, -10.0, -6.0, -2.0, 2.0, 6.0, 10.0, 14.0]:
		_kit(HW + "fence_pillar.gltf", _cem(u, 10.0), _cem_yaw)
	for v: float in [-18.0, -14.0, -10.0, -6.0, -2.0, 2.0, 6.0]:
		for side: float in [-1.0, 1.0]:
			_kit(HW + "fence_pillar.gltf", _cem(14.0 * side, v), _cem_yaw)
	_kit(HW + "arch.gltf", _cem(0.0, 10.0), _cem_yaw)
	var grid := _kit(HW + "fence_gate.gltf", _cem(-1.2, 12.2) + Vector3(0, 0.15, 0), _cem_yaw + 0.5, 0.9)
	grid.rotation.x = -PI * 0.5 + 0.08 # grille arrachée, couchée dans l'herbe
	# Collisions : on ne sort que par le portail.
	_cem_wall(-14.0, -18.0, -14.0, 10.0)
	_cem_wall(14.0, -18.0, 14.0, 10.0)
	_cem_wall(-14.0, -18.0, 14.0, -18.0)
	_cem_wall(-14.0, 10.0, -2.0, 10.0)
	_cem_wall(2.0, 10.0, 14.0, 10.0)


## La chapelle de la messe noire : le mausolée du KayKit Halloween Bits, porte entrouverte sur une lueur rouge
## malsaine ; un autel aux bougies et deux crânes-chandeliers devant.
func _build_chapel() -> void:
	# Porte tournée vers la caméra (vers le fond du cimetière) : on voit la lueur de la messe noire.
	var c := _cem(-7.5, -6.5)
	_kit(HW + "crypt.gltf", c, _cem_yaw + PI)
	var body := Visuals.solid(self, Vector3(6.0, 4.0, 7.6), c + _cem_f * 0.2 + Vector3(0, 2.0, 0))
	body.rotation.y = _cem_yaw
	var inner := OmniLight3D.new()
	inner.position = _cem(-7.5, -11.2) + Vector3(0, 1.8, 0)
	inner.light_color = Color(0.9, 0.15, 0.25)
	inner.light_energy = 2.4
	inner.omni_range = 7.0
	add_child(inner)
	_kit(HW + "plaque_candles.gltf", _cem(-7.5, -13.0), _cem_yaw + PI, 0.9, true)
	for side: float in [-1.0, 1.0]:
		var at := _cem(-7.5 + 2.3 * side, -12.2)
		_kit(HW + "skull_candle.gltf", at, _cem_yaw + PI, 0.8)
		var l := Visuals.flicker_light(self, at + Vector3(0, 1.2, 0), Color(1.0, 0.45, 0.25), 1.2, 4.5)
		l.flicker_amount = 0.5


## Cadavre ensanglanté d'une race amicale (humain, orc, troll, ogre, démon, squelette),
## tiré avec l'outil de création de personnage.
func _corpse(p: Vector3) -> void:
	var holder := Node3D.new()
	holder.position = p
	holder.rotation.y = _rng.randf() * TAU
	add_child(holder)
	var look := RaceDB.random_appearance()
	look["guitar"] = false
	look["hunched"] = false
	var body := HeroModel.new()
	body.appearance = look
	holder.add_child(body)
	body.rotation.x = -PI * 0.5 if _rng.randf() < 0.5 else PI * 0.5 # sur le dos ou face contre terre
	body.position.y = 0.18
	body.set_process(false) # figé : pas d'animation
	var blood := Visuals.mat(Color(0.3, 0.0, 0.01), 0.1)
	Visuals.cylinder(holder, _rng.randf_range(0.6, 1.1), _rng.randf_range(0.7, 1.2), 0.01, Vector3(0, 0.012, 0.3), blood, Vector3.ZERO, 14)
	for s in 5:
		Visuals.cylinder(holder, 0.08, 0.1, 0.01, Vector3(_rng.randf_range(-1.2, 1.2), 0.014, _rng.randf_range(-1.2, 1.2)), blood, Vector3.ZERO, 8)


# =====================================================================================
# Bord de route : cadavres, corbeaux... et la taverne
# =====================================================================================

func _build_road_side() -> void:
	var s := 26.0
	while s < ROAD_LENGTH - 10.0:
		var side := 1.0 if _rng.randf() < 0.5 else -1.0
		_corpse(road_point(s) + road_right(s) * side * _rng.randf_range(2.4, 7.0))
		s += _rng.randf_range(12.0, 22.0)
	# Bornes et poteaux indicateurs.
	var wood := Visuals.mat(Color(0.2, 0.13, 0.07), 0.85)
	for sign_s: float in [30.0, 75.0]:
		var p := road_point(sign_s) + road_right(sign_s) * 2.6
		Visuals.box(self, Vector3(0.14, 2.2, 0.14), p + Vector3(0, 1.1, 0), wood)
		var board := Visuals.box(self, Vector3(1.3, 0.35, 0.06), p + Vector3(0.3, 1.9, 0), wood)
		board.rotation.y = atan2(road_dir(sign_s).x, road_dir(sign_s).z) + PI * 0.5
		Visuals.label(self, "La Chèvre Fringante →", p + Vector3(0, 2.5, 0), Color(0.85, 0.7, 0.5), 26)


## L'auberge au bout de la route, bâtie avec le Fantasy Town Kit (cases d'1 unité, ×INN_CELL) : rez-de-chaussée en
## pierre (porte cintrée grande ouverte, fenêtres), étage à colombages et volets, toit à deux pans et sa cheminée ;
## pignons de bois. Lumière chaude derrière la porte et les fenêtres.
const INN_CELL := 3.5
const INN_W := 4
const INN_D := 2


func _build_tavern_exterior() -> void:
	var s := TAVERN_S
	var dir := road_dir(s)
	var center := road_point(s) + dir * 6.0
	var yaw := atan2(dir.x, dir.z)
	var inn := Node3D.new()
	inn.position = center
	inn.rotation.y = yaw + PI # la façade (+Z local) regarde la route
	add_child(inn)
	for f in 2:
		for i in INN_W:
			for j in INN_D:
				var c := Vector3(i - (INN_W - 1) * 0.5, f, j - (INN_D - 1) * 0.5)
				var stone := f == 0
				if j == INN_D - 1: # façade
					var p := "wall.glb" if stone else ("wall-wood-window-shutters.glb" if i % 3 != 0 else "wall-wood-window-small.glb")
					if stone:
						p = ["wall-window-stone.glb", "wall-doorway-round.glb", "wall-window-glass.glb", "wall-window-stone.glb"][i]
					_inn_wall(inn, TOWN + p, c, Vector2(0, 1))
				if j == 0:
					_inn_wall(inn, TOWN + ("wall.glb" if stone else "wall-wood.glb"), c, Vector2(0, -1))
				if i == 0:
					_inn_wall(inn, TOWN + ("wall-window-small.glb" if stone and j == 1 else ("wall.glb" if stone else "wall-wood.glb")), c, Vector2(-1, 0))
				if i == INN_W - 1:
					_inn_wall(inn, TOWN + ("wall.glb" if stone else "wall-wood-window-small.glb"), c, Vector2(1, 0))
	for i in INN_W:
		for j in INN_D:
			var c := Vector3(i - (INN_W - 1) * 0.5, 2, j - (INN_D - 1) * 0.5)
			_inn_wall(inn, TOWN + ("roof-high-window.glb" if j == INN_D - 1 and i == 2 else "roof-high.glb"), c, Vector2(0, -1) if j == INN_D - 1 else Vector2(0, 1))
	_inn_wall(inn, TOWN + "chimney.glb", Vector3(-(INN_W - 1) * 0.5, 2.0, -0.5), Vector2(0, -1))
	_inn_wall(inn, TOWN + "chimney-top.glb", Vector3(-(INN_W - 1) * 0.5, 3.0, -0.5), Vector2(0, -1))
	# Pignons de bois sous le toit, aux deux bouts.
	var gable := Visuals.mat(Color(0.42, 0.26, 0.17), 0.85)
	gable.cull_mode = BaseMaterial3D.CULL_DISABLED
	var half_d := INN_D * INN_CELL * 0.5
	for side: float in [-1.0, 1.0]:
		var x := side * (INN_W * INN_CELL * 0.5 - 0.05)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_normal(Vector3(side, 0, 0))
		st.add_vertex(Vector3(x, 2.0 * INN_CELL, -half_d))
		st.add_vertex(Vector3(x, 3.0 * INN_CELL, 0.0))
		st.add_vertex(Vector3(x, 2.0 * INN_CELL, half_d))
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = gable
		inn.add_child(mi)
	# Lumière chaude de la grande salle : un fond lumineux derrière la porte et les fenêtres.
	Visuals.box(inn, Vector3(INN_W * INN_CELL - 0.6, 2.0 * INN_CELL - 0.4, 0.1), Vector3(0, INN_CELL, half_d - 1.4), Visuals.glow_mat(Color(1.0, 0.6, 0.25), 2.2))
	var warm := OmniLight3D.new()
	warm.position = Vector3(0, 2.0, half_d + 2.0)
	warm.light_color = Color(1.0, 0.65, 0.3)
	warm.light_energy = 3.0
	warm.omni_range = 12.0
	inn.add_child(warm)
	# Bannière et lanternes de part et d'autre de la porte, enseigne au crâne qui hurle.
	for sx: float in [-1.0, 1.0]:
		KitProps.place(inn, TOWN + "lantern.glb", Vector3(sx * 3.1, 0, half_d + 0.9), 0.0, 1.6, true)
	KitProps.place(inn, TOWN + "banner-red.glb", Vector3(0.5 * INN_CELL, INN_CELL * 1.05, half_d - 0.4 * INN_CELL), -PI * 0.5, INN_CELL)
	var timber := Visuals.mat(Color(0.18, 0.1, 0.05), 0.8)
	Visuals.box(inn, Vector3(0.1, 0.1, 1.6), Vector3(-2.3, 3.6, half_d + 0.8), timber)
	Visuals.sphere(inn, 0.4, Vector3(-2.3, 3.0, half_d + 1.5), Visuals.mat(Color(0.85, 0.8, 0.65)), Vector3(1.0, 1.1, 1.0))
	Visuals.box(inn, Vector3(0.25, 0.3, 0.1), Vector3(-2.3, 2.8, half_d + 1.88), Visuals.mat(Color(0.05, 0.02, 0.02)))
	Visuals.label(self, "LE CRÂNE HURLANT", center + Vector3(0, 3.0 * INN_CELL + 1.0, 0), Color(1.0, 0.7, 0.35), 64)
	var body := Visuals.solid(self, Vector3(INN_W * INN_CELL, 5.0, INN_D * INN_CELL), center + Vector3(0, 2.5, 0))
	body.rotation.y = yaw + PI
	var door := road_point(s) + dir * 1.2
	Interactable.create(self, door, "Entrer à la Chèvre Fringante", _enter_tavern, 2.6)
	Visuals.flicker_light(self, door + Vector3(0, 2.6, 0), Color(1.0, 0.6, 0.3), 2.0, 8.0)


## Pièce du Fantasy Town Kit posée sur le bord de normale `n` (plan XZ) de la case `c` de l'auberge.
func _inn_wall(inn: Node3D, path: String, c: Vector3, n: Vector2) -> void:
	KitProps.place(inn, path, c * INN_CELL, atan2(-n.y, n.x), INN_CELL)


# =====================================================================================
# Chauves-souris et orage
# =====================================================================================

func _spawn_bats() -> void:
	var skin := Visuals.mat(Color(0.03, 0.02, 0.03), 0.8)
	for i in 16:
		var bat := Node3D.new()
		add_child(bat)
		Visuals.sphere(bat, 0.12, Vector3.ZERO, skin, Vector3(0.8, 0.8, 1.3))
		for side: float in [-1.0, 1.0]:
			var wing := Node3D.new()
			wing.name = "Wing%d" % (0 if side < 0 else 1)
			bat.add_child(wing)
			var membrane := Visuals.box(wing, Vector3(0.45, 0.02, 0.25), Vector3(0.24 * side, 0, 0), skin)
			membrane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_bats.append(bat)
		_bat_data.append(Vector4(_rng.randf_range(4.0, 14.0), _rng.randf_range(0.6, 1.4) * (1.0 if _rng.randf() < 0.5 else -1.0),
			_rng.randf() * TAU, _rng.randf_range(3.0, 7.0)))


func _update_bats(delta: float) -> void:
	var anchor := hero.global_position if hero != null else Vector3.ZERO
	for i in _bats.size():
		var d := _bat_data[i]
		var a := _t * d.y + d.z
		var target := anchor + IsoCamera.SCREEN_UP * 6.0 + Vector3(cos(a) * d.x, d.w + sin(_t * 1.7 + d.z) * 0.8, sin(a * 1.3) * d.x)
		var bat := _bats[i]
		var prev := bat.global_position
		bat.global_position = prev.lerp(target, 1.0 - exp(-1.5 * delta))
		var v := bat.global_position - prev
		if v.length() > 0.001:
			bat.rotation.y = atan2(v.x, v.z)
		var flap := sin(_t * 22.0 + d.z) * 0.9
		(bat.get_node("Wing0") as Node3D).rotation.z = flap
		(bat.get_node("Wing1") as Node3D).rotation.z = -flap


## Les éclairs tombent sur les coups de tonnerre de la musique d'orage.
func _on_music_strike(force: float) -> void:
	if hero == null:
		return
	if _cinematic:
		Events.screen_flash.emit(Color(0.85, 0.88, 1.0, 0.2 + 0.3 * force), 0.35)
		return
	_lightning()


## Un éclair frappe le décor, jamais sur la route : flash, tonnerre, petit tremblement.
func _lightning() -> void:
	var s := road_s(hero.global_position) + _rng.randf_range(-4.0, 14.0)
	var side := 1.0 if _rng.randf() < 0.5 else -1.0
	var ground := road_point(s) + road_right(s) * side * _rng.randf_range(ROAD_HALF_WIDTH + 5.0, 16.0)
	if dist_to_road(ground) < ROAD_HALF_WIDTH + 4.0:
		ground = road_point(s) - road_right(s) * side * 12.0 # jamais sur la route, même dans un virage
	var sky := ground + Vector3(_rng.randf_range(-4, 4), 40.0, _rng.randf_range(-4, 4))
	ArcBolt.spawn(self, sky, ground, 0.6, 0.45, Color(0.85, 0.9, 1.0))
	ArcBolt.spawn(self, sky + Vector3(1, -8, 0), ground + Vector3(2.0, 0, 1.0), 0.15, 0.25, Color(0.7, 0.8, 1.0))
	# Impact : lumière aveuglante puis braises.
	var flash_light := OmniLight3D.new()
	flash_light.position = ground + Vector3(0, 3.0, 0)
	flash_light.light_color = Color(0.8, 0.85, 1.0)
	flash_light.light_energy = 12.0
	flash_light.omni_range = 30.0
	add_child(flash_light)
	var tw := flash_light.create_tween()
	tw.tween_property(flash_light, "light_energy", 0.0, 0.5)
	tw.tween_callback(flash_light.queue_free)
	Visuals.cylinder(self, 0.9, 1.1, 0.01, ground + Vector3(0, 0.02, 0), Visuals.mat(Color(0.02, 0.02, 0.02), 1.0), Vector3.ZERO, 12)
	var embers := Visuals.flicker_light(self, ground + Vector3(0, 0.6, 0), Color(1.0, 0.45, 0.15), 1.5, 4.0)
	embers.flicker_amount = 0.6
	embers.create_tween().tween_property(embers, "base_energy", 0.0, 6.0)
	var dist := hero.global_position.distance_to(ground)
	Events.screen_flash.emit(Color(0.85, 0.88, 1.0, 0.5 if dist < 20.0 else 0.3), 0.35)
	Events.camera_shake.emit(0.12 if dist < 20.0 else 0.06, 0.3)
	_moon_light.light_energy = 3.0
	_moon_light.create_tween().tween_property(_moon_light, "light_energy", 1.4, 0.4)
	await get_tree().create_timer(minf(1.2, dist / 60.0), false).timeout
	Sfx.play("thunder", -2.0 if dist < 20.0 else -8.0, 0.15)


# =====================================================================================
# Déroulement
# =====================================================================================

func _process(delta: float) -> void:
	_t += delta
	for veil in get_tree().get_nodes_in_group("intro_veils"):
		var v := veil as Node3D
		v.position += IsoCamera.SCREEN_RIGHT * float(v.get_meta("drift")) * delta
	if hero == null:
		return
	_update_bats(delta)
	if _cinematic:
		return
	_keep_on_path()
	# Arrivée devant la porte : on entre automatiquement.
	if road_s(hero.global_position) > TAVERN_S - 1.0:
		_enter_tavern()


## On peut flâner un peu dans les champs, mais la route reste le chemin.
func _keep_on_path() -> void:
	var p := hero.global_position
	var s := clampf(road_s(p), -10.0, TAVERN_S)
	var on_road := road_point(s)
	var right := road_right(s)
	var lateral := (p - on_road).dot(right)
	var clamped := clampf(lateral, -ROAM_HALF_WIDTH, ROAM_HALF_WIDTH)
	if absf(clamped - lateral) > 0.001 or s != road_s(p):
		hero.global_position = on_road + right * clamped
		hero.global_position.y = 0.0


func _play_cinematic() -> void:
	# Caméra de cinéma (perspective) : la lune de sang dans la brume...
	_cine_cam = Camera3D.new()
	_cine_cam.fov = 32.0
	_cine_cam.far = 600.0
	add_child(_cine_cam)
	_cine_cam.current = true
	var moon := _moon_position()
	var cem := road_point(2.0)
	var start_pos := cem + IsoCamera.SCREEN_UP * -10.0 + Vector3(0, 3.0, 0)
	_cine_cam.position = start_pos
	_cine_cam.look_at(moon, Vector3.UP)
	hud.visible = false
	var caption := _caption("Une nuit de Lune de Sang... (encore un truc cliché de métalleux)")
	Sfx.play("thunder", -6.0)
	# ... puis la caméra descend sur le cimetière, les tombes vides et les cadavres, et revient sur
	# notre héros. Une seule séquence, que la touche Espace ou Échap interrompt (voir _input).
	var graves := cem + road_right(2.0) * 5.0 - road_dir(2.0) * 4.0
	var end_pos := cem - road_right(2.0) * 5.0 - road_dir(2.0) * 15.0 + Vector3(0, 7.0, 0)
	var close := hero.global_position + IsoCamera.OFFSET * 0.35
	var over_graves := Basis.looking_at(graves - end_pos, Vector3.UP).get_rotation_quaternion()
	var on_hero := Basis.looking_at(hero.global_position + Vector3(0, 1.4, 0) - close, Vector3.UP).get_rotation_quaternion()
	_cine_tween = create_tween()
	_cine_tween.tween_interval(3.5)
	_cine_tween.tween_callback(func() -> void: caption.text = "Au sortir de la messe noire, on admire les tombes du cimetière...")
	_cine_tween.tween_method(_cine_look.bind(start_pos, end_pos, moon, graves), 0.0, 1.0, 4.5).set_trans(Tween.TRANS_SINE)
	_cine_tween.tween_callback(func() -> void: caption.text = "...et les morts se sont ENCORE échappés de leurs tombes.")
	_cine_tween.tween_interval(2.5)
	_cine_tween.tween_callback(func() -> void: caption.text = "")
	_cine_tween.tween_property(_cine_cam, "position", close, 2.0).set_trans(Tween.TRANS_SINE)
	_cine_tween.parallel().tween_method(_cine_aim, over_graves, on_hero, 2.0)
	_cine_tween.tween_callback(_end_cinematic)


## Espace ou Échap pendant la cinématique : on la passe (sans ouvrir le menu pause).
func _input(event: InputEvent) -> void:
	if _cine_cam == null:
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode in [KEY_SPACE, KEY_ESCAPE]:
		get_viewport().set_input_as_handled()
		skip_cinematic()


func skip_cinematic() -> void:
	if _cine_tween != null:
		_cine_tween.kill()
	_end_cinematic()


## Fin de la cinématique (jouée jusqu'au bout ou passée) : retour à la caméra du jeu et réplique du héros.
func _end_cinematic() -> void:
	if _cine_cam == null:
		return
	_cine_layer.queue_free()
	camera.current = true
	camera.snap_to_target()
	_cine_cam.queue_free()
	_cine_cam = null
	hud.visible = true
	Events.dialogue_requested.emit("intro_hero")
	await Events.dialogue_closed
	_cinematic = false
	hero.captive = false
	hud.show_area_name("La route de la Chèvre Fringante")
	Events.notify("Suivez la route pavée jusqu'à la Chèvre Fringante.", Events.COLOR_DEFAULT)


func _cine_look(k: float, from_pos: Vector3, to_pos: Vector3, from_target: Vector3, to_target: Vector3) -> void:
	_cine_cam.position = from_pos.lerp(to_pos, k)
	_cine_cam.look_at(from_target.lerp(to_target, k), Vector3.UP)


func _cine_aim(q: Quaternion) -> void:
	_cine_cam.quaternion = q


func _caption(text: String) -> Label:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	_cine_layer = layer
	var bars := ColorRect.new() # bandes noires de cinéma
	bars.color = Color(0, 0, 0, 0.0)
	bars.set_anchors_preset(Control.PRESET_FULL_RECT)
	bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(bars)
	for top: bool in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.anchor_right = 1.0
		bar.anchor_top = 0.0 if top else 1.0
		bar.anchor_bottom = 0.0 if top else 1.0
		bar.offset_top = 0.0 if top else -90.0
		bar.offset_bottom = 90.0 if top else 0.0
		bars.add_child(bar)
	var l := UiStyle.label(text, 40, Color(0.95, 0.3, 0.25))
	l.anchor_left = 0.5
	l.anchor_right = 0.5
	l.anchor_top = 1.0
	l.anchor_bottom = 1.0
	l.offset_left = -600
	l.offset_right = 600
	l.offset_top = -80
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bars.add_child(l)
	var hint := UiStyle.label("Espace / Échap : passer", 20, Color(0.7, 0.66, 0.6))
	hint.anchor_left = 1.0
	hint.anchor_right = 1.0
	hint.offset_left = -420
	hint.offset_right = -28
	hint.offset_top = 32
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bars.add_child(hint)
	return l


func _enter_tavern() -> void:
	if _entered:
		return
	_entered = true
	hero.captive = true
	GameState.flags["intro_done"] = true
	GameState.flags["intro_arrival"] = true # les portes se refermeront derrière le héros
	GameState.location = {"scene": Router.TAVERN}
	GameState.save_game()
	Router.go_to(Router.TAVERN)
