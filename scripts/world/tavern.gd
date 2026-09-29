extends Level
## Le Crâne Hurlant — taverne-hub : PNJ, quêtes, boutique, portail vers les donjons.
## Salle de 20 × 14 m. Murs du fond (nord / ouest) pleins avec fenêtres ; murs de devant
## (sud / est) bas pour ne pas masquer la vue isométrique.

const HALF_X := 10.0
const HALF_Z := 7.0
const WALL_H := 3.6
const RUNE_CIRCLE := Vector3(6.3, 0.0, 1.0)

var _wood_dark := Visuals.mat(Color(0.2, 0.11, 0.06), 0.8)
var _wood := Visuals.mat(Color(0.33, 0.19, 0.1), 0.75)
var _wood_light := Visuals.mat(Color(0.45, 0.28, 0.15), 0.7)
var _iron := Visuals.mat(Color(0.15, 0.15, 0.16), 0.4, 0.8)
var _stone := Visuals.stone_material(false, Color(0.3, 0.27, 0.25))
var _portal: Portal


func _ready() -> void:
	setup_level("tavern", "Le Crâne Hurlant")
	_build_room()
	_build_fireplace()
	_build_counter()
	_build_tables()
	_build_lanterns()
	_build_props()
	_build_rune_circle()
	_spawn_npcs()
	var spawn := Vector3(0.0, 0.0, 5.3)
	if GameState.flags.get("in_dungeon", false):
		spawn = RUNE_CIRCLE + Vector3(0.0, 0.0, 1.8)
		GameState.flags.erase("in_dungeon")
		if GameState.hp <= 0 or GameState.flags.has("last_death_gold_lost"):
			var lost: int = GameState.flags.get("last_death_gold_lost", 0)
			GameState.flags.erase("last_death_gold_lost")
			Events.notify("Zarathos vous a ramené inconscient à la taverne... (-%d po)" % lost, Events.COLOR_BAD)
	spawn_hero(spawn)
	if GameState.flags.get("portal_open", false) and GameState.quest_state("plumeau") == QuestDB.State.ACTIVE:
		_open_portal()
	Events.portal_opened.connect(_open_portal)
	Sfx.play_music("res://audio/music/tavern_theme.mp3", -8.0) # musique « metal-band-tavern »
	GameState.save_game()


# --- Structure ---------------------------------------------------------------

func _build_room() -> void:
	# Plancher en lattes.
	var planks := int(HALF_Z * 2.0 / 0.5)
	for i in planks:
		var shade := randf_range(0.8, 1.15)
		var m := Visuals.mat(Color(0.2 * shade, 0.15 * shade, 0.11 * shade), 0.8)
		Visuals.box(self, Vector3(HALF_X * 2.0, 0.1, 0.47), Vector3(0, -0.05, -HALF_Z + 0.25 + i * 0.5), m)
	Visuals.box(self, Vector3(HALF_X * 2.0 + 2.0, 0.1, HALF_Z * 2.0 + 2.0), Vector3(0, -0.12, 0), Visuals.mat(Color(0.03, 0.02, 0.02)))
	# Faible lumière d'appoint (clair de lune diffus) pour lire la salle sans casser l'ambiance.
	var fill := DirectionalLight3D.new()
	fill.light_color = Color(0.6, 0.65, 0.9)
	fill.light_energy = 0.35
	fill.rotation_degrees = Vector3(-55, -30, 0)
	add_child(fill)
	# Mur nord (fond) avec 2 fenêtres, mur ouest avec 2 fenêtres (+ cheminée au centre).
	_wall_x_axis(-HALF_Z, -HALF_X, HALF_X, [-6.5, 7.8])
	_wall_z_axis(-HALF_X, -HALF_Z, HALF_Z, [-4.2, 4.2])
	# Murs de devant, bas, avec la porte au sud.
	_low_wall(Vector3(-5.5, 0, HALF_Z), Vector3(9.0, 0.9, 0.4))
	_low_wall(Vector3(5.5, 0, HALF_Z), Vector3(9.0, 0.9, 0.4))
	_low_wall(Vector3(HALF_X, 0, 0), Vector3(0.4, 0.9, HALF_Z * 2.0))
	for sx: float in [-1.0, 1.0]: # montants de la porte
		Visuals.box(self, Vector3(0.3, 1.6, 0.5), Vector3(1.1 * sx, 0.8, HALF_Z), _wood_dark)
	Visuals.label(self, "Sortie (fermée la nuit)", Vector3(0, 1.9, HALF_Z), Color(0.6, 0.55, 0.5), 22)


func _low_wall(center: Vector3, size: Vector3) -> void:
	Visuals.box(self, size, center + Vector3(0, size.y * 0.5, 0), _stone)
	Visuals.box(self, Vector3(size.x + 0.1, 0.08, size.z + 0.1), center + Vector3(0, size.y, 0), _wood_dark)
	Visuals.solid(self, Vector3(size.x, 3.0, size.z), center + Vector3(0, 1.5, 0))


## Mur le long de l'axe X (z fixe), avec fenêtres centrées sur les x donnés.
func _wall_x_axis(z: float, x_from: float, x_to: float, windows: Array) -> void:
	var t := 0.4
	var w := 1.6
	var cursor := x_from
	for wx: float in windows:
		_wall_block(Vector3((cursor + wx - w * 0.5) * 0.5, WALL_H * 0.5, z), Vector3(wx - w * 0.5 - cursor, WALL_H, t))
		_window(Vector3(wx, 0, z), Vector3(w, 0, t), Vector3(0, 0, 1))
		cursor = wx + w * 0.5
	_wall_block(Vector3((cursor + x_to) * 0.5, WALL_H * 0.5, z), Vector3(x_to - cursor, WALL_H, t))
	Visuals.solid(self, Vector3(x_to - x_from, 4.0, t), Vector3((x_from + x_to) * 0.5, 2.0, z))


## Mur le long de l'axe Z (x fixe).
func _wall_z_axis(x: float, z_from: float, z_to: float, windows: Array) -> void:
	var t := 0.4
	var w := 1.6
	var cursor := z_from
	for wz: float in windows:
		_wall_block(Vector3(x, WALL_H * 0.5, (cursor + wz - w * 0.5) * 0.5), Vector3(t, WALL_H, wz - w * 0.5 - cursor))
		_window(Vector3(x, 0, wz), Vector3(t, 0, w), Vector3(1, 0, 0))
		cursor = wz + w * 0.5
	_wall_block(Vector3(x, WALL_H * 0.5, (cursor + z_to) * 0.5), Vector3(t, WALL_H, z_to - cursor))
	Visuals.solid(self, Vector3(t, 4.0, z_to - z_from), Vector3(x, 2.0, (z_from + z_to) * 0.5))


func _wall_block(center: Vector3, size: Vector3) -> void:
	if size.x <= 0.01 or size.z <= 0.01:
		return
	Visuals.box(self, size, center, _stone)
	# Poutre de bois au sommet et plinthe.
	Visuals.box(self, size + Vector3(0.05, -size.y + 0.2, 0.05), Vector3(center.x, WALL_H - 0.1, center.z), _wood_dark)


## Fenêtre à croisillons, clair de lune bleuté qui entre dans la salle.
func _window(center: Vector3, size: Vector3, inward: Vector3) -> void:
	var sill := 1.1
	var top := 2.6
	Visuals.box(self, Vector3(maxf(size.x, 0.4), sill, maxf(size.z, 0.4)), center + Vector3(0, sill * 0.5, 0), _stone)
	Visuals.box(self, Vector3(maxf(size.x, 0.4), WALL_H - top, maxf(size.z, 0.4)), center + Vector3(0, (top + WALL_H) * 0.5, 0), _stone)
	var along := Vector3(1, 0, 0) if inward.z != 0.0 else Vector3(0, 0, 1)
	var pane_size := along * 1.5 + Vector3(0, top - sill, 0) + inward * 0.04
	var pane := Visuals.box(self, pane_size, center + Vector3(0, (sill + top) * 0.5, 0), Visuals.glow_mat(Color(0.25, 0.35, 0.65), 0.9))
	pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Croisillons.
	var frame := along * 1.6 + Vector3(0, 0.08, 0) + inward * 0.12
	for y: float in [sill, (sill + top) * 0.5, top]:
		Visuals.box(self, frame, center + Vector3(0, y, 0) + inward * 0.05, _wood_dark)
	Visuals.box(self, Vector3(0.08, top - sill, 0.08) + inward * 0.04, center + Vector3(0, (sill + top) * 0.5, 0) + inward * 0.05, _wood_dark)
	# Rayon de lune.
	var moon := SpotLight3D.new()
	moon.light_color = Color(0.45, 0.55, 1.0)
	moon.light_energy = 3.0
	moon.spot_range = 9.0
	moon.spot_angle = 28.0
	moon.shadow_enabled = true
	moon.position = center + Vector3(0, 3.4, 0) - inward * 0.8
	add_child(moon)
	moon.look_at(center + inward * 3.5 + Vector3(0, 0, 0), Vector3.UP)


func _build_fireplace() -> void:
	var x := -HALF_X + 0.7
	Visuals.box(self, Vector3(1.0, 2.4, 2.8), Vector3(x, 1.2, 0), _stone)
	Visuals.box(self, Vector3(0.4, 1.2, 3.2), Vector3(x - 0.2, 3.0, 0), _stone) # conduit
	Visuals.box(self, Vector3(0.3, 0.15, 3.1), Vector3(x + 0.45, 1.75, 0), _wood_dark) # manteau
	Visuals.box(self, Vector3(0.2, 1.1, 1.6), Vector3(x + 0.42, 0.55, 0), Visuals.mat(Color(0.02, 0.015, 0.01))) # foyer
	for k in 3:
		Visuals.cylinder(self, 0.08, 0.08, 1.0, Vector3(x + 0.55, 0.12 + k * 0.05, -0.2 + k * 0.2), _wood_dark, Vector3(90, 20 * k, 0))
	var fire := Visuals.glow_mat(Color(1.0, 0.45, 0.1), 5.0)
	Visuals.sphere(self, 0.25, Vector3(x + 0.6, 0.35, 0), fire, Vector3(1.4, 1.2, 1.8))
	Visuals.sphere(self, 0.15, Vector3(x + 0.62, 0.6, 0.1), Visuals.glow_mat(Color(1.0, 0.75, 0.3), 6.0))
	var light := Visuals.flicker_light(self, Vector3(x + 1.6, 1.0, 0), Color(1.0, 0.5, 0.2), 3.5, 11.0, true)
	light.flicker_amount = 0.35
	Visuals.solid(self, Vector3(1.2, 3.0, 3.0), Vector3(x, 1.5, 0))
	Visuals.box(self, Vector3(3.0, 0.02, 4.0), Vector3(x + 2.6, 0.01, 0), Visuals.mat(Color(0.22, 0.08, 0.06), 0.95)) # tapis
	# Trophée : un crâne hurlant au-dessus de la cheminée.
	Visuals.sphere(self, 0.25, Vector3(x + 0.5, 2.3, 0), Visuals.mat(Color(0.8, 0.75, 0.6)), Vector3(1, 1.1, 1))
	Visuals.box(self, Vector3(0.1, 0.18, 0.12), Vector3(x + 0.72, 2.18, 0), Visuals.mat(Color(0.05, 0.02, 0.02)))


func _build_counter() -> void:
	var z := -4.3
	var x0 := -1.5
	var x1 := 5.5
	var cx := (x0 + x1) * 0.5
	var length := x1 - x0
	Visuals.box(self, Vector3(length, 1.05, 0.7), Vector3(cx, 0.525, z), _wood_dark)
	Visuals.box(self, Vector3(length + 0.2, 0.08, 0.85), Vector3(cx, 1.08, z), _wood_light)
	for k in 7:
		Visuals.box(self, Vector3(0.06, 0.9, 0.02), Vector3(x0 + 0.5 + k, 0.5, z + 0.36), _wood)
	Visuals.solid(self, Vector3(length, 2.0, 0.8), Vector3(cx, 1.0, z))
	# Chopes et pichet sur le comptoir.
	for k in 4:
		Visuals.cylinder(self, 0.07, 0.07, 0.16, Vector3(x0 + 1.0 + k * 1.4, 1.2, z + randf_range(-0.2, 0.2)), Visuals.mat(Color(0.55, 0.4, 0.2)))
	# Tabourets.
	for k in 4:
		var p := Vector3(x0 + 1.0 + k * 1.6, 0, z + 0.95)
		Visuals.cylinder(self, 0.22, 0.22, 0.06, p + Vector3(0, 0.72, 0), _wood)
		Visuals.cylinder(self, 0.05, 0.08, 0.7, p + Vector3(0, 0.35, 0), _wood_dark)
	# Étagères à bouteilles sur le mur du fond.
	var shelf_z := -HALF_Z + 0.4
	for y: float in [1.3, 2.0, 2.7]:
		Visuals.box(self, Vector3(6.0, 0.06, 0.35), Vector3(2.0, y, shelf_z), _wood)
		for k in 11:
			var colors := [Color(0.2, 0.5, 0.2), Color(0.5, 0.15, 0.1), Color(0.6, 0.5, 0.2), Color(0.25, 0.2, 0.5)]
			var c: Color = colors.pick_random()
			var bx := -0.7 + k * 0.52 + randf_range(-0.08, 0.08)
			var h := randf_range(0.22, 0.34)
			var bottle := Visuals.glow_mat(c, 0.25) if randf() < 0.3 else Visuals.mat(c, 0.15)
			Visuals.cylinder(self, 0.06, 0.07, h, Vector3(bx, y + h * 0.5 + 0.03, shelf_z), bottle, Vector3.ZERO, 8)
	# Tonneaux derrière le comptoir.
	for k in 3:
		var p := Vector3(6.8, 0.0, -6.2 + k * 0.95)
		Visuals.cylinder(self, 0.42, 0.42, 1.0, p + Vector3(0, 0.5, 0), _wood, Vector3.ZERO, 14)
		Visuals.torus(self, 0.4, 0.44, p + Vector3(0, 0.2, 0), _iron)
		Visuals.torus(self, 0.4, 0.44, p + Vector3(0, 0.8, 0), _iron)
		Visuals.solid_cylinder(self, 0.45, 1.5, p + Vector3(0, 0.75, 0))


func _build_tables() -> void:
	var tables := [Vector3(-5.6, 0, -2.2), Vector3(-5.2, 0, 3.4), Vector3(0.6, 0, 1.8), Vector3(4.8, 0, 4.4)]
	for t: Vector3 in tables:
		Visuals.cylinder(self, 0.85, 0.85, 0.08, t + Vector3(0, 0.8, 0), _wood_light, Vector3.ZERO, 20)
		Visuals.cylinder(self, 0.1, 0.12, 0.8, t + Vector3(0, 0.4, 0), _wood_dark)
		Visuals.cylinder(self, 0.4, 0.45, 0.06, t + Vector3(0, 0.03, 0), _wood_dark)
		Visuals.solid_cylinder(self, 0.85, 2.0, t + Vector3(0, 1.0, 0))
		# Bougie + chope.
		Visuals.cylinder(self, 0.04, 0.04, 0.18, t + Vector3(0.1, 0.93, 0.1), Visuals.mat(Color(0.9, 0.85, 0.7)))
		Visuals.sphere(self, 0.035, t + Vector3(0.1, 1.05, 0.1), Visuals.glow_mat(Color(1.0, 0.7, 0.3), 8.0))
		var candle := Visuals.flicker_light(self, t + Vector3(0.1, 1.3, 0.1), Color(1.0, 0.65, 0.3), 0.9, 3.5)
		candle.flicker_amount = 0.4
		Visuals.cylinder(self, 0.07, 0.07, 0.16, t + Vector3(-0.3, 0.92, -0.1), Visuals.mat(Color(0.55, 0.4, 0.2)))
		# Chaises autour.
		var n := 4
		for k in n:
			var a := TAU * k / n + 0.4
			var dir := Vector3(cos(a), 0, sin(a))
			_chair(t + dir * 1.25, atan2(-dir.x, -dir.z))


## Chaise dont l'avant (+Z local) est orienté selon `yaw`.
func _chair(pos: Vector3, yaw: float) -> void:
	var chair := Node3D.new()
	chair.position = pos
	chair.rotation.y = yaw
	add_child(chair)
	Visuals.box(chair, Vector3(0.46, 0.06, 0.46), Vector3(0, 0.46, 0), _wood)
	for lx: float in [-0.19, 0.19]:
		for lz: float in [-0.19, 0.19]:
			Visuals.box(chair, Vector3(0.05, 0.46, 0.05), Vector3(lx, 0.23, lz), _wood_dark)
	Visuals.box(chair, Vector3(0.46, 0.55, 0.05), Vector3(0, 0.76, -0.21), _wood)
	Visuals.box(chair, Vector3(0.05, 0.6, 0.05), Vector3(-0.2, 0.75, -0.21), _wood_dark)
	Visuals.box(chair, Vector3(0.05, 0.6, 0.05), Vector3(0.2, 0.75, -0.21), _wood_dark)


func _build_lanterns() -> void:
	# Piliers de bois avec lanternes suspendues.
	var pillars := [Vector3(-2.4, 0, 0.4), Vector3(3.2, 0, -1.6), Vector3(2.6, 0, 5.4)]
	var first := true
	for p: Vector3 in pillars:
		Visuals.box(self, Vector3(0.35, WALL_H + 0.4, 0.35), p + Vector3(0, (WALL_H + 0.4) * 0.5, 0), _wood_dark)
		Visuals.solid(self, Vector3(0.4, 3.0, 0.4), p + Vector3(0, 1.5, 0))
		_lantern(p + Vector3(0.4, 2.35, 0.4), first)
		first = false
	# Lanternes murales.
	_lantern(Vector3(-3.5, 2.6, -HALF_Z + 0.45), false)
	_lantern(Vector3(-HALF_X + 0.45, 2.6, -1.9), false)
	_lantern(Vector3(-HALF_X + 0.45, 2.6, 2.1), false)


func _lantern(pos: Vector3, shadows: bool) -> void:
	Visuals.box(self, Vector3(0.05, 0.3, 0.05), pos + Vector3(0, 0.3, 0), _iron) # crochet
	Visuals.box(self, Vector3(0.26, 0.04, 0.26), pos + Vector3(0, 0.16, 0), _iron)
	Visuals.box(self, Vector3(0.26, 0.04, 0.26), pos + Vector3(0, -0.16, 0), _iron)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			Visuals.box(self, Vector3(0.03, 0.32, 0.03), pos + Vector3(0.12 * sx, 0, 0.12 * sz), _iron)
	Visuals.box(self, Vector3(0.18, 0.26, 0.18), pos, Visuals.glow_mat(Color(1.0, 0.65, 0.25), 3.5))
	Visuals.flicker_light(self, pos, Color(1.0, 0.68, 0.38), 2.6, 8.5, shadows)


func _build_props() -> void:
	# Escalier vers l'étage (décor), coin nord-est.
	for k in 8:
		Visuals.box(self, Vector3(1.4, 0.22, 0.45), Vector3(9.1, 0.11 + k * 0.22, -1.4 - k * 0.45), _wood)
		Visuals.box(self, Vector3(1.4, 0.11 + k * 0.22, 0.45), Vector3(9.1, (0.11 + k * 0.22) * 0.5, -1.4 - k * 0.45), _wood_dark)
	Visuals.solid(self, Vector3(1.4, 3.0, 3.8), Vector3(9.1, 1.5, -3.0))
	# Tonneaux et caisses, coin sud-ouest.
	for p: Vector3 in [Vector3(-9.0, 0, 5.8), Vector3(-8.1, 0, 6.2), Vector3(-9.1, 0, 4.9)]:
		Visuals.cylinder(self, 0.4, 0.4, 0.95, p + Vector3(0, 0.475, 0), _wood, Vector3.ZERO, 14)
		Visuals.torus(self, 0.38, 0.42, p + Vector3(0, 0.2, 0), _iron)
		Visuals.torus(self, 0.38, 0.42, p + Vector3(0, 0.75, 0), _iron)
		Visuals.solid_cylinder(self, 0.42, 1.5, p + Vector3(0, 0.75, 0))
	Visuals.box(self, Vector3(0.8, 0.7, 0.8), Vector3(-7.9, 0.35, 5.2), _wood, Vector3(0, 20, 0))
	# Tableau des quêtes sur le mur nord.
	var board_pos := Vector3(-3.5, 0, -HALF_Z + 0.3)
	Visuals.box(self, Vector3(1.6, 1.1, 0.08), board_pos + Vector3(0, 1.7, 0), _wood_dark)
	for k in 5:
		Visuals.box(self, Vector3(0.35, 0.45, 0.02), board_pos + Vector3(-0.55 + k * 0.28, 1.7 + randf_range(-0.2, 0.2), 0.06),
			Visuals.mat(Color(0.85, 0.8, 0.65)), Vector3(0, 0, randf_range(-8, 8)))
	var board := DialogueProp.new()
	board.dialogue_id = "tableau"
	board.prompt = "Lire le tableau des quêtes"
	board.position = board_pos + Vector3(0, 0, 0.6)
	add_child(board)
	# Bannière du Crâne Hurlant.
	Visuals.box(self, Vector3(0.05, 1.6, 1.0), Vector3(-HALF_X + 0.25, 2.6, -5.8), Visuals.mat(Color(0.35, 0.05, 0.05)))
	Visuals.sphere(self, 0.18, Vector3(-HALF_X + 0.3, 2.7, -5.8), Visuals.mat(Color(0.85, 0.8, 0.65)))


func _build_rune_circle() -> void:
	Visuals.torus(self, 1.5, 1.65, RUNE_CIRCLE + Vector3(0, 0.02, 0), Visuals.glow_mat(Color(0.45, 0.25, 0.85), 1.2))
	Visuals.torus(self, 1.1, 1.16, RUNE_CIRCLE + Vector3(0, 0.02, 0), Visuals.glow_mat(Color(0.45, 0.25, 0.85), 0.8))
	for k in 8:
		var a := TAU * k / 8.0
		Visuals.box(self, Vector3(0.18, 0.02, 0.06), RUNE_CIRCLE + Vector3(cos(a) * 1.33, 0.03, sin(a) * 1.33),
			Visuals.glow_mat(Color(0.6, 0.4, 1.0), 2.0), Vector3(0, -rad_to_deg(a), 0))


func _open_portal() -> void:
	if _portal != null:
		return
	_portal = Portal.new()
	_portal.position = RUNE_CIRCLE
	_portal.prompt = "Entrer dans les Catacombes Suintantes"
	_portal.target_scene = Router.DUNGEON
	_portal.on_enter = _on_enter_dungeon
	add_child(_portal)
	Events.camera_shake.emit(0.15, 0.5)


func _on_enter_dungeon() -> void:
	GameState.flags["in_dungeon"] = true
	GameState.save_game()


func _spawn_npcs() -> void:
	add_child(Npc.create("brunhilde", Vector3(2.0, 0, -5.4), 0.0))
	add_child(Npc.create("zarathos", Vector3(8.0, 0, -0.6), -110.0))
	add_child(Npc.create("gerald", Vector3(-3.7, 0, 4.4), 150.0))
	add_child(Npc.create("inconnue", Vector3(-8.7, 0, -5.9), 40.0))
	# Clients attablés (assis sur une chaise, face à la table).
	var t3 := Vector3(0.6, 0, 1.8)
	var a3 := TAU * 1 / 4.0 + 0.4
	var d3 := Vector3(cos(a3), 0, sin(a3))
	add_child(Npc.create("borin", t3 + d3 * 1.25, rad_to_deg(atan2(-d3.x, -d3.z)), true))
	var t4 := Vector3(4.8, 0, 4.4)
	var a4 := TAU * 2 / 4.0 + 0.4
	var d4 := Vector3(cos(a4), 0, sin(a4))
	add_child(Npc.create("sylvaine", t4 + d4 * 1.25, rad_to_deg(atan2(-d4.x, -d4.z)), true))
	if GameState.flags.get("plumeau_rescued", false):
		var cub := OwlbearCub.new()
		cub.position = Vector3(-2.9, 0, 5.0)
		cub.rotation.y = PI
		add_child(cub)
