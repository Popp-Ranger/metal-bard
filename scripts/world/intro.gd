extends Level
## Introduction : la Nuit de la Lune de Sang.
##   1. Cinématique : une lune sanglante dans la brume, puis le cimetière près de la
##      chapelle — tombes déterrées et vides, cadavres de toutes les races amicales.
##   2. Le héros : « Aaaaaah, une bonne vieille balade par ce temps est si agréable.
##      Et si j'allais m'en jeter un ! » (« Et si nous allions nous en jeter un » en coop).
##   3. Environ 20 s de marche sur une route pavée sinueuse, entre champs et
##      prairies, cadavres ensanglantés et chauves-souris ; orage sans pluie : des éclairs
##      frappent le décor hors de la route (flash + légers tremblements d'écran).
##   4. Au bout de la route, le Crâne Hurlant : on entre, et les portes se referment.
## La route part vers le « haut de l'écran » de la caméra isométrique puis serpente.

const ROAD_LENGTH := 110.0 # ≈ 20 s de marche à 5,5 m/s (longueur réelle du tracé sinueux)
const ROAD_HALF_WIDTH := 1.7
const ROAM_HALF_WIDTH := 13.0 # on peut s'écarter un peu dans les champs, pas plus
const START_S := 3.0
const TAVERN_S := ROAD_LENGTH + 6.0

var _rng := RandomNumberGenerator.new()
var _moon_light: DirectionalLight3D
var _bats: Array[Node3D] = []
var _bat_data: Array[Vector4] = [] # (rayon, vitesse, phase, hauteur)
var _cine_cam: Camera3D
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
	_moon_light.light_energy = 1.1
	_moon_light.rotation_degrees = Vector3(-50, 150, 0)
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
	var grass := Visuals.mat(Color(0.08, 0.1, 0.06), 0.95)
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
		var sc := _rng.randf_range(0.6, 1.5)
		mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(sc, sc * _rng.randf_range(0.8, 1.6), sc)), p + Vector3(0, 0.15 * sc, 0)))
		var v := _rng.randf_range(0.7, 1.2)
		mm.set_instance_color(i, Color(0.16 * v, 0.23 * v, 0.1 * v))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	Visuals.toon(m)
	mmi.material_override = m
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


## Route pavée de pierres grises irrégulières (MultiMesh), bordée de terre battue.
func _build_road() -> void:
	var stone := BoxMesh.new()
	stone.size = Vector3(0.39, 0.08, 0.39)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = stone
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	var s := -8.0
	var row := 0
	while s < TAVERN_S + 2.0:
		var dir := road_dir(s)
		var right := road_right(s)
		var yaw := atan2(dir.x, dir.z)
		var w := -ROAD_HALF_WIDTH + (0.2 if row % 2 == 0 else 0.0)
		while w < ROAD_HALF_WIDTH - 0.1:
			var p := road_point(s) + right * (w + _rng.randf_range(-0.03, 0.03)) + Vector3(0, 0.02 + _rng.randf_range(-0.015, 0.015), 0)
			var sc := _rng.randf_range(0.85, 1.05)
			transforms.append(Transform3D(Basis(Vector3.UP, yaw + _rng.randf_range(-0.12, 0.12)).scaled(Vector3(sc, 1.0, sc)), p))
			var g := _rng.randf_range(0.13, 0.24)
			colors.append(Color(g, g, g * 1.05))
			w += 0.4
		s += 0.4
		row += 1
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
		mm.set_instance_color(i, colors[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.85
	Visuals.toon(m)
	mmi.material_override = m
	add_child(mmi)
	# Bas-côtés de terre battue.
	var dirt := Visuals.mat(Color(0.1, 0.075, 0.05), 1.0)
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
	# Clôtures de bois le long de la route.
	var wood := Visuals.mat(Color(0.18, 0.12, 0.07), 0.9)
	s = 16.0
	while s < ROAD_LENGTH:
		for side: float in [-1.0, 1.0]:
			if _rng.randf() < 0.25:
				continue
			var p := road_point(s) + road_right(s) * side * (ROAD_HALF_WIDTH + 1.4)
			Visuals.box(self, Vector3(0.12, 1.0, 0.12), p + Vector3(0, 0.5, 0), wood, Vector3(_rng.randf_range(-8, 8), 0, _rng.randf_range(-8, 8)))
			var next := road_point(s + 3.0) + road_right(s + 3.0) * side * (ROAD_HALF_WIDTH + 1.4)
			var mid := (p + next) * 0.5
			var rail := Visuals.box(self, Vector3(0.06, 0.08, p.distance_to(next)), mid + Vector3(0, 0.75, 0), wood)
			rail.rotation.y = atan2(next.x - p.x, next.z - p.z)
		s += 3.0
	# Arbres morts.
	for k in 26:
		var ts := _rng.randf_range(0.0, ROAD_LENGTH)
		var p := road_point(ts) + road_right(ts) * (_rng.randf_range(6.0, 30.0) * (1.0 if _rng.randf() < 0.5 else -1.0))
		if dist_to_road(p) > 4.0:
			_dead_tree(p)


func _dead_tree(p: Vector3) -> void:
	var bark := Visuals.mat(Color(0.09, 0.07, 0.06), 0.95)
	var h := _rng.randf_range(3.0, 5.5)
	Visuals.cylinder(self, 0.12, 0.3, h, p + Vector3(0, h * 0.5, 0), bark, Vector3(_rng.randf_range(-6, 6), 0, _rng.randf_range(-6, 6)), 7)
	for b in 4:
		var y := h * _rng.randf_range(0.5, 0.95)
		var yaw := _rng.randf() * 360.0
		var branch := Visuals.cylinder(self, 0.02, 0.09, 1.8, p + Vector3(0, y, 0), bark, Vector3(0, yaw, _rng.randf_range(40, 70)), 5)
		branch.position += branch.basis.y * 0.9
	Visuals.solid_cylinder(self, 0.3, 2.0, p + Vector3(0, 1.0, 0))


# =====================================================================================
# Cimetière et chapelle
# =====================================================================================

func _build_cemetery() -> void:
	var stone := Visuals.mat(Color(0.3, 0.29, 0.3), 0.9)
	var dark_stone := Visuals.mat(Color(0.18, 0.17, 0.18), 0.9)
	var dirt := Visuals.mat(Color(0.14, 0.09, 0.05), 1.0)
	var hole := Visuals.mat(Color(0.01, 0.008, 0.006), 1.0)
	var wood := Visuals.mat(Color(0.2, 0.12, 0.06), 0.85)
	var origin := road_point(2.0)
	var fwd := road_dir(2.0)
	var right := road_right(2.0)
	var yaw := atan2(fwd.x, fwd.z)
	# Muret du cimetière (carré de 26 m) avec un portail ouvert sur la route.
	var half := 13.0
	var gate := origin + fwd * 10.0
	for side: float in [-1.0, 1.0]:
		_wall_segment(origin + fwd * 10.0 + right * side * 7.6, Vector3(11.0, 1.1, 0.5), yaw, dark_stone) # façade (portail au milieu)
		_wall_segment(origin + right * side * half, Vector3(0.5, 1.1, 26.0), yaw, dark_stone) # côtés
	_wall_segment(origin - fwd * 16.0, Vector3(26.0, 1.1, 0.5), yaw, dark_stone) # fond
	for side: float in [-1.0, 1.0]:
		Visuals.box(self, Vector3(0.6, 2.4, 0.6), gate + right * side * 2.0 + Vector3(0, 1.2, 0), stone, Vector3(0, rad_to_deg(yaw), 0))
		Visuals.sphere(self, 0.28, gate + right * side * 2.0 + Vector3(0, 2.6, 0), stone)
		# Grille arrachée, couchée au sol.
		var grid := Visuals.box(self, Vector3(1.8, 0.05, 1.6), gate + right * side * 1.3 + fwd * 1.5 + Vector3(0, 0.05, 0), Visuals.mat(Color(0.1, 0.1, 0.1), 0.4, 0.8))
		grid.rotation.y = yaw + side * 0.4
	Visuals.label(self, "Cimetière de Morneval", gate + Vector3(0, 3.1, 0), Color(0.75, 0.7, 0.65), 34)
	# Chapelle à gauche du cimetière.
	_build_chapel(origin - right * 7.5 - fwd * 6.0, yaw)
	# Rangées de tombes : la plupart déterrées et vides.
	for row in 4:
		for col in 5:
			var p := origin - fwd * (11.0 - row * 4.2) + right * (1.0 + col * 2.4)
			var dug := _rng.randf() < 0.7
			var headstone := Visuals.box(self, Vector3(0.7, 1.0, 0.18), p - fwd * 1.1 + Vector3(0, 0.5, 0), stone,
				Vector3(_rng.randf_range(-12, 12), rad_to_deg(yaw), _rng.randf_range(-10, 10)))
			headstone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			if _rng.randf() < 0.3:
				Visuals.box(self, Vector3(0.12, 1.3, 0.12), p - fwd * 1.1 + Vector3(0, 0.65, 0), wood) # croix
				Visuals.box(self, Vector3(0.6, 0.12, 0.12), p - fwd * 1.1 + Vector3(0, 0.95, 0), wood, Vector3(0, rad_to_deg(yaw) + 90, 0))
			if dug:
				var pit := Visuals.box(self, Vector3(0.9, 0.02, 1.8), p + Vector3(0, 0.01, 0), hole)
				pit.rotation.y = yaw
				Visuals.sphere(self, 0.7, p + right * 0.9 + Vector3(0, 0.0, 0), dirt, Vector3(0.9, 0.45, 1.4)) # tas de terre
				var lid := Visuals.box(self, Vector3(0.7, 0.08, 1.7), p - right * 0.9 + Vector3(0, 0.15, 0), wood)
				lid.rotation = Vector3(_rng.randf_range(-0.2, 0.2), yaw + _rng.randf_range(-0.6, 0.6), 0.35)
			else:
				Visuals.sphere(self, 0.6, p, dirt, Vector3(0.8, 0.25, 1.5))
			Visuals.solid(self, Vector3(0.8, 2.0, 0.3), p - fwd * 1.1 + Vector3(0, 1.0, 0))
	# Bougies de deuil renversées sur quelques tombes : seules lueurs du cimetière.
	for k in 5:
		var cp := origin - fwd * _rng.randf_range(-2.0, 11.0) + right * _rng.randf_range(1.0, 11.0)
		Visuals.cylinder(self, 0.05, 0.05, 0.2, cp + Vector3(0, 0.1, 0), Visuals.mat(Color(0.9, 0.85, 0.7)))
		Visuals.sphere(self, 0.04, cp + Vector3(0, 0.24, 0), Visuals.glow_mat(Color(1.0, 0.7, 0.3), 8.0))
		var candle := Visuals.flicker_light(self, cp + Vector3(0, 0.6, 0), Color(1.0, 0.6, 0.3), 1.4, 5.0)
		candle.flicker_amount = 0.5
	# Cadavres dans le cimetière et devant son entrée.
	for k in 6:
		var p := origin + right * _rng.randf_range(-3.0, 11.0) - fwd * _rng.randf_range(-6.0, 12.0)
		_corpse(p)
	for k in 5:
		var s := _rng.randf_range(11.0, 22.0)
		_corpse(road_point(s) + road_right(s) * _rng.randf_range(-6.0, 6.0))
	# Lanterne vacillante au portail.
	var l := Visuals.flicker_light(self, gate + right * 2.0 + Vector3(0, 2.2, 0), Color(1.0, 0.6, 0.3), 2.0, 9.0, true)
	l.flicker_amount = 0.5


func _wall_segment(center: Vector3, size: Vector3, yaw: float, mat: Material) -> void:
	var w := Visuals.box(self, size, center + Vector3(0, size.y * 0.5, 0), mat)
	w.rotation.y = yaw
	var body := Visuals.solid(self, Vector3(size.x, 3.0, size.z), center + Vector3(0, 1.5, 0))
	body.rotation.y = yaw


func _build_chapel(center: Vector3, yaw: float) -> void:
	var chapel := Node3D.new()
	chapel.position = center
	chapel.rotation.y = yaw
	add_child(chapel)
	var stone := Visuals.mat(Color(0.26, 0.25, 0.27), 0.9)
	var roof := Visuals.mat(Color(0.1, 0.08, 0.09), 0.8)
	Visuals.box(chapel, Vector3(5.0, 4.0, 8.0), Vector3(0, 2.0, 0), stone)
	for side: float in [-1.0, 1.0]:
		var pan := Visuals.box(chapel, Vector3(3.3, 0.2, 8.4), Vector3(side * 1.3, 5.0, 0), roof)
		pan.rotation.z = side * -0.72
	Visuals.box(chapel, Vector3(1.8, 7.0, 1.8), Vector3(0, 3.5, 4.2), stone) # clocher
	Visuals.cylinder(chapel, 0.0, 1.35, 2.6, Vector3(0, 8.3, 4.2), roof, Vector3.ZERO, 4)
	Visuals.box(chapel, Vector3(0.1, 1.0, 0.1), Vector3(0, 10.0, 4.2), Visuals.mat(Color(0.5, 0.45, 0.3), 0.4, 0.8))
	Visuals.box(chapel, Vector3(0.5, 0.1, 0.1), Vector3(0, 10.2, 4.2), Visuals.mat(Color(0.5, 0.45, 0.3), 0.4, 0.8))
	# Vitrail qui luit d'un rouge malsain, porte entrouverte.
	Visuals.box(chapel, Vector3(0.1, 1.6, 0.9), Vector3(2.52, 2.4, -1.0), Visuals.glow_mat(Color(0.8, 0.1, 0.2), 1.8))
	Visuals.box(chapel, Vector3(0.1, 1.6, 0.9), Vector3(2.52, 2.4, 1.6), Visuals.glow_mat(Color(0.5, 0.15, 0.7), 1.5))
	Visuals.box(chapel, Vector3(1.4, 2.4, 0.1), Vector3(0, 1.2, 5.12), Visuals.mat(Color(0.02, 0.01, 0.01)))
	var inner := OmniLight3D.new()
	inner.position = Vector3(3.2, 2.4, 0.3)
	inner.light_color = Color(0.9, 0.2, 0.3)
	inner.light_energy = 1.4
	inner.omni_range = 6.0
	chapel.add_child(inner)
	var body := Visuals.solid(self, Vector3(5.2, 4.0, 10.0), center + Vector3(0, 2.0, 0))
	body.rotation.y = yaw


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
		Visuals.label(self, "Le Crâne Hurlant →", p + Vector3(0, 2.5, 0), Color(0.85, 0.7, 0.5), 26)


func _build_tavern_exterior() -> void:
	var s := TAVERN_S
	var dir := road_dir(s)
	var center := road_point(s) + dir * 6.0
	var yaw := atan2(dir.x, dir.z)
	var inn := Node3D.new()
	inn.position = center
	inn.rotation.y = yaw + PI # la façade regarde la route
	add_child(inn)
	var stone := Visuals.mat(Color(0.3, 0.27, 0.25), 0.9)
	var timber := Visuals.mat(Color(0.18, 0.1, 0.05), 0.8)
	var roof := Visuals.mat(Color(0.14, 0.07, 0.05), 0.85)
	Visuals.box(inn, Vector3(14.0, 5.0, 9.0), Vector3(0, 2.5, 0), stone)
	for side: float in [-1.0, 1.0]:
		var pan := Visuals.box(inn, Vector3(5.8, 0.25, 9.6), Vector3(side * 3.6, 6.4, 0), roof)
		pan.rotation.z = side * -0.6
		pan.scale.x = 1.35
	for x: float in [-6.8, -2.3, 2.3, 6.8]:
		Visuals.box(inn, Vector3(0.25, 5.0, 0.25), Vector3(x, 2.5, 4.55), timber)
	Visuals.box(inn, Vector3(14.2, 0.25, 0.25), Vector3(0, 2.6, 4.55), timber)
	# Fenêtres chaudes et porte ouverte (lumière de l'intérieur).
	for x: float in [-4.5, 4.5]:
		Visuals.box(inn, Vector3(1.4, 1.2, 0.1), Vector3(x, 1.8, 4.52), Visuals.glow_mat(Color(1.0, 0.6, 0.25), 2.5))
		Visuals.box(inn, Vector3(1.4, 1.0, 0.1), Vector3(x, 3.9, 4.52), Visuals.glow_mat(Color(1.0, 0.55, 0.2), 1.8))
	Visuals.box(inn, Vector3(2.0, 2.8, 0.1), Vector3(0, 1.4, 4.53), Visuals.glow_mat(Color(1.0, 0.65, 0.3), 3.0))
	var warm := OmniLight3D.new()
	warm.position = Vector3(0, 2.0, 6.0)
	warm.light_color = Color(1.0, 0.65, 0.3)
	warm.light_energy = 3.0
	warm.omni_range = 12.0
	warm.shadow_enabled = true
	inn.add_child(warm)
	# Enseigne : un crâne qui hurle.
	Visuals.box(inn, Vector3(0.1, 0.1, 1.6), Vector3(2.0, 3.6, 5.3), timber)
	Visuals.sphere(inn, 0.4, Vector3(2.0, 3.0, 6.0), Visuals.mat(Color(0.85, 0.8, 0.65)), Vector3(1.0, 1.1, 1.0))
	Visuals.box(inn, Vector3(0.25, 0.3, 0.1), Vector3(2.0, 2.8, 6.38), Visuals.mat(Color(0.05, 0.02, 0.02)))
	Visuals.label(self, "LE CRÂNE HURLANT", center + Vector3(0, 7.8, 0), Color(1.0, 0.7, 0.35), 64)
	var body := Visuals.solid(self, Vector3(14.0, 5.0, 9.0), center + Vector3(0, 2.5, 0))
	body.rotation.y = yaw + PI
	var door := road_point(s) + dir * 1.2
	Interactable.create(self, door, "Entrer au Crâne Hurlant", _enter_tavern, 2.6)
	Visuals.flicker_light(self, door + Vector3(0, 2.6, 0), Color(1.0, 0.6, 0.3), 2.0, 8.0)


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
	_moon_light.create_tween().tween_property(_moon_light, "light_energy", 1.1, 0.4)
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
	var caption := _caption("La nuit de la Lune de Sang...")
	Sfx.play("thunder", -6.0)
	await get_tree().create_timer(3.5).timeout
	caption.text = "Les morts ont quitté leurs tombes."
	# ... puis la caméra descend sur le cimetière, les tombes vides et les cadavres.
	var tw := create_tween()
	var graves := cem + road_right(2.0) * 5.0 - road_dir(2.0) * 4.0
	var end_pos := cem - road_right(2.0) * 5.0 - road_dir(2.0) * 15.0 + Vector3(0, 7.0, 0)
	tw.tween_method(_cine_look.bind(start_pos, end_pos, moon, graves), 0.0, 1.0, 4.5).set_trans(Tween.TRANS_SINE)
	await tw.finished
	await get_tree().create_timer(1.5).timeout
	caption.text = ""
	# Retour sur notre héros.
	var tw2 := create_tween()
	var close := hero.global_position + IsoCamera.OFFSET * 0.35
	tw2.tween_property(_cine_cam, "position", close, 2.0).set_trans(Tween.TRANS_SINE)
	tw2.parallel().tween_method(_cine_aim, _cine_cam.global_transform.basis.get_rotation_quaternion(),
		Transform3D().looking_at(hero.global_position + Vector3(0, 1.4, 0) - close).basis.get_rotation_quaternion(), 2.0)
	await tw2.finished
	caption.get_parent().get_parent().queue_free()
	camera.current = true
	camera.snap_to_target()
	_cine_cam.queue_free()
	hud.visible = true
	Events.dialogue_requested.emit("intro_hero")
	await Events.dialogue_closed
	_cinematic = false
	hero.captive = false
	hud.show_area_name("La route du Crâne Hurlant")
	Events.notify("Suivez la route pavée jusqu'à la taverne.", Events.COLOR_DEFAULT)


func _cine_look(k: float, from_pos: Vector3, to_pos: Vector3, from_target: Vector3, to_target: Vector3) -> void:
	_cine_cam.position = from_pos.lerp(to_pos, k)
	_cine_cam.look_at(from_target.lerp(to_target, k), Vector3.UP)


func _cine_aim(q: Quaternion) -> void:
	_cine_cam.quaternion = q


func _caption(text: String) -> Label:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
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
