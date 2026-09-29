extends Level
## Le Crâne Hurlant — auberge-hub sur trois niveaux :
##   • rez-de-chaussée (30 × 22 m) : salle commune, comptoir, clients, PNJ, portail ;
##   • étage (zone décalée, reliée par l'escalier) : couloir et 4 chambres ;
##   • sous-sol (zone décalée) : salle d'entraînement avec mannequins et cible amicale.
## Les étages sont des zones séparées du même niveau : l'escalier y mène avec un fondu,
## comme dans la plupart des jeux isométriques (sinon l'étage cacherait la salle).
## Murs du fond (nord / ouest) pleins avec fenêtres ; murs de devant bas.

const HALF_X := 15.0
const HALF_Z := 11.0
const WALL_H := 4.0
const RUNE_CIRCLE := Vector3(10.5, 0.0, -1.0)
const UP := Vector3(0.0, 0.0, -70.0) # origine de l'étage
const CELLAR := Vector3(70.0, 0.0, 0.0) # origine du sous-sol
const GROUND_STAIRS_UP := Vector3(13.4, 0.0, -4.4)
const GROUND_STAIRS_DOWN := Vector3(-12.0, 0.0, 6.4)
const BAR_SPOTS := [Vector3(-3.0, 0, -6.4), Vector3(-1.4, 0, -6.4), Vector3(0.2, 0, -6.4),
	Vector3(1.8, 0, -6.4), Vector3(3.4, 0, -6.4), Vector3(5.0, 0, -6.4)]
const TABLES := [Vector3(-9.0, 0, -4.0), Vector3(-9.5, 0, 5.0), Vector3(-3.0, 0, 1.0),
	Vector3(3.0, 0, 1.5), Vector3(-2.5, 0, 7.0), Vector3(7.5, 0, 6.0)]
const KATRKAR_TABLE := 3 # la table où une chaise est remplacée par le fauteuil roulant

var _wood_dark := Visuals.mat(Color(0.2, 0.11, 0.06), 0.8)
var _wood := Visuals.mat(Color(0.33, 0.19, 0.1), 0.75)
var _wood_light := Visuals.mat(Color(0.45, 0.28, 0.15), 0.7)
var _iron := Visuals.mat(Color(0.15, 0.15, 0.16), 0.4, 0.8)
var _stone := Visuals.stone_material(false, Color(0.3, 0.27, 0.25))
var _cut_stone := Visuals.stone_material(true, Color(0.32, 0.28, 0.25))
var _portal: Portal
var _nav: NavigationRegion3D
var _bar_taken: Array[bool] = [false, false, false, false, false, false]
var _seats: Array[Dictionary] = [] # {pos, yaw}
var _katrkar_seat := {}
var _gerald: Npc
var _gerald_home := Vector3(-6.5, 0, 7.5)


func _ready() -> void:
	setup_level("tavern", "Le Crâne Hurlant")
	_nav = NavigationRegion3D.new()
	add_child(_nav)
	_build_ground_floor()
	_build_upstairs()
	_build_cellar()
	_bake_navigation()
	_spawn_npcs()
	var spawn := Vector3(0.0, 0.0, 9.5)
	var from_dungeon: bool = GameState.flags.get("in_dungeon", false)
	if from_dungeon:
		spawn = RUNE_CIRCLE + Vector3(0.0, 0.0, 2.5)
		GameState.flags.erase("in_dungeon")
		if GameState.flags.has("last_death_gold_lost"):
			var lost: int = GameState.flags.get("last_death_gold_lost", 0)
			GameState.flags.erase("last_death_gold_lost")
			Events.notify("Zarathos vous a ramené inconscient à la taverne... (-%d po)" % lost, Events.COLOR_BAD)
	spawn_hero(spawn)
	if GameState.flags.get("portal_open", false) and GameState.quest_state("plumeau") == QuestDB.State.ACTIVE:
		_open_portal()
	Events.portal_opened.connect(_open_portal)
	Sfx.play_music("res://audio/music/tavern_theme.mp3", -8.0) # musique « metal-band-tavern »
	_spawn_plumeau()
	GameState.save_game()


func _process(_delta: float) -> void:
	if hero != null:
		_cut_stone.set_shader_parameter("hero_pos", hero.global_position)


# =====================================================================================
# Rez-de-chaussée
# =====================================================================================

func _build_ground_floor() -> void:
	_floor(self, Vector3.ZERO, HALF_X, HALF_Z, true)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color(0.6, 0.65, 0.9)
	fill.light_energy = 0.35
	fill.rotation_degrees = Vector3(-55, -30, 0)
	add_child(fill)
	_wall_x_axis(self, Vector3.ZERO, -HALF_Z, -HALF_X, HALF_X, [-10.0, 10.0], _stone)
	_wall_z_axis(self, Vector3.ZERO, -HALF_X, -HALF_Z, HALF_Z, [-6.5, 6.5], _stone)
	_low_wall(self, Vector3(-8.25, 0, HALF_Z), Vector3(13.5, 0.9, 0.4))
	_low_wall(self, Vector3(8.25, 0, HALF_Z), Vector3(13.5, 0.9, 0.4))
	_low_wall(self, Vector3(HALF_X, 0, 0), Vector3(0.4, 0.9, HALF_Z * 2.0))
	for sx: float in [-1.0, 1.0]: # montants de la porte
		Visuals.box(self, Vector3(0.3, 1.6, 0.5), Vector3(1.4 * sx, 0.8, HALF_Z), _wood_dark)
	Visuals.label(self, "Sortie (fermée la nuit)", Vector3(0, 1.9, HALF_Z), Color(0.6, 0.55, 0.5), 22)
	_build_fireplace()
	_build_counter()
	for i in TABLES.size():
		_build_table(TABLES[i], i)
	# Piliers avec lanternes + lanternes murales.
	var first := true
	for p: Vector3 in [Vector3(-6.0, 0, -1.5), Vector3(6.5, 0, -2.5), Vector3(0.5, 0, 5.0)]:
		Visuals.box(self, Vector3(0.35, WALL_H + 0.4, 0.35), p + Vector3(0, (WALL_H + 0.4) * 0.5, 0), _wood_dark)
		_solid(self, Vector3(0.4, 3.0, 0.4), p + Vector3(0, 1.5, 0))
		_lantern(self, p + Vector3(0.4, 2.35, 0.4), first)
		first = false
	_lantern(self, Vector3(-4.5, 2.8, -HALF_Z + 0.45), false)
	_lantern(self, Vector3(-HALF_X + 0.45, 2.8, -3.0), false)
	_lantern(self, Vector3(-HALF_X + 0.45, 2.8, 3.0), false)
	_build_ground_props()
	_build_rune_circle()


func _build_fireplace() -> void:
	var x := -HALF_X + 0.7
	Visuals.box(self, Vector3(1.0, 2.4, 2.8), Vector3(x, 1.2, 0), _stone)
	Visuals.box(self, Vector3(0.4, 1.6, 3.2), Vector3(x - 0.2, 3.2, 0), _stone)
	Visuals.box(self, Vector3(0.3, 0.15, 3.1), Vector3(x + 0.45, 1.75, 0), _wood_dark)
	Visuals.box(self, Vector3(0.2, 1.1, 1.6), Vector3(x + 0.42, 0.55, 0), Visuals.mat(Color(0.02, 0.015, 0.01)))
	for k in 3:
		Visuals.cylinder(self, 0.08, 0.08, 1.0, Vector3(x + 0.55, 0.12 + k * 0.05, -0.2 + k * 0.2), _wood_dark, Vector3(90, 20 * k, 0))
	Visuals.sphere(self, 0.25, Vector3(x + 0.6, 0.35, 0), Visuals.glow_mat(Color(1.0, 0.45, 0.1), 5.0), Vector3(1.4, 1.2, 1.8))
	Visuals.sphere(self, 0.15, Vector3(x + 0.62, 0.6, 0.1), Visuals.glow_mat(Color(1.0, 0.75, 0.3), 6.0))
	var light := Visuals.flicker_light(self, Vector3(x + 1.6, 1.0, 0), Color(1.0, 0.5, 0.2), 3.5, 11.0, true)
	light.flicker_amount = 0.35
	_solid(self, Vector3(1.2, 3.0, 3.0), Vector3(x, 1.5, 0))
	Visuals.box(self, Vector3(3.0, 0.02, 4.0), Vector3(x + 2.6, 0.01, 0), Visuals.mat(Color(0.22, 0.08, 0.06), 0.95))
	Visuals.sphere(self, 0.25, Vector3(x + 0.5, 2.3, 0), Visuals.mat(Color(0.8, 0.75, 0.6)), Vector3(1, 1.1, 1))
	Visuals.box(self, Vector3(0.1, 0.18, 0.12), Vector3(x + 0.72, 2.18, 0), Visuals.mat(Color(0.05, 0.02, 0.02)))


func _build_counter() -> void:
	var z := -7.5
	var x0 := -4.5
	var x1 := 6.5
	var cx := (x0 + x1) * 0.5
	var length := x1 - x0
	Visuals.box(self, Vector3(length, 1.05, 0.7), Vector3(cx, 0.525, z), _wood_dark)
	Visuals.box(self, Vector3(length + 0.2, 0.08, 0.85), Vector3(cx, 1.08, z), _wood_light)
	for k in 11:
		Visuals.box(self, Vector3(0.06, 0.9, 0.02), Vector3(x0 + 0.5 + k, 0.5, z + 0.36), _wood)
	_solid(self, Vector3(length, 2.0, 0.8), Vector3(cx, 1.0, z))
	for k in 6:
		Visuals.cylinder(self, 0.07, 0.07, 0.16, Vector3(x0 + 1.0 + k * 1.8, 1.2, z + randf_range(-0.2, 0.2)), Visuals.mat(Color(0.55, 0.4, 0.2)))
	# Étagères à bouteilles sur le mur du fond.
	var shelf_z := -HALF_Z + 0.4
	var colors := [Color(0.2, 0.5, 0.2), Color(0.5, 0.15, 0.1), Color(0.6, 0.5, 0.2), Color(0.25, 0.2, 0.5)]
	for y: float in [1.3, 2.0, 2.7]:
		Visuals.box(self, Vector3(9.0, 0.06, 0.35), Vector3(1.0, y, shelf_z), _wood)
		for k in 16:
			var c: Color = colors.pick_random()
			var h := randf_range(0.22, 0.34)
			var bottle := Visuals.glow_mat(c, 0.25) if randf() < 0.3 else Visuals.mat(c, 0.15)
			Visuals.cylinder(self, 0.06, 0.07, h, Vector3(-3.2 + k * 0.55 + randf_range(-0.08, 0.08), y + h * 0.5 + 0.03, shelf_z), bottle, Vector3.ZERO, 8)
	# Gros tonneaux en perce derrière le comptoir.
	for p: Vector3 in [Vector3(7.8, 0, -9.8), Vector3(8.8, 0, -9.8), Vector3(7.8, 0, -8.8)]:
		_barrel(self, p, 0.45)


func _build_table(t: Vector3, index: int) -> void:
	Visuals.cylinder(self, 0.85, 0.85, 0.08, t + Vector3(0, 0.8, 0), _wood_light, Vector3.ZERO, 20)
	Visuals.cylinder(self, 0.1, 0.12, 0.8, t + Vector3(0, 0.4, 0), _wood_dark)
	Visuals.cylinder(self, 0.4, 0.45, 0.06, t + Vector3(0, 0.03, 0), _wood_dark)
	_solid_cylinder(self, 0.85, 2.0, t + Vector3(0, 1.0, 0))
	Visuals.cylinder(self, 0.04, 0.04, 0.18, t + Vector3(0.1, 0.93, 0.1), Visuals.mat(Color(0.9, 0.85, 0.7)))
	Visuals.sphere(self, 0.035, t + Vector3(0.1, 1.05, 0.1), Visuals.glow_mat(Color(1.0, 0.7, 0.3), 8.0))
	var candle := Visuals.flicker_light(self, t + Vector3(0.1, 1.3, 0.1), Color(1.0, 0.65, 0.3), 0.9, 3.5)
	candle.flicker_amount = 0.4
	Visuals.cylinder(self, 0.07, 0.07, 0.16, t + Vector3(-0.3, 0.92, -0.1), Visuals.mat(Color(0.55, 0.4, 0.2)))
	for k in 4:
		var a := TAU * k / 4.0 + 0.4
		var dir := Vector3(cos(a), 0, sin(a))
		var pos: Vector3 = t + dir * 1.25
		var yaw := atan2(-dir.x, -dir.z)
		if index == KATRKAR_TABLE and k == 1:
			_katrkar_seat = {"pos": pos + dir * 0.1, "yaw": yaw} # place laissée libre au fauteuil
			continue
		_chair(self, pos, yaw)
		_seats.append({"pos": pos, "yaw": yaw})


func _build_ground_props() -> void:
	# Escalier vers l'étage (coin nord-est).
	for k in 10:
		Visuals.box(self, Vector3(2.2, 0.22, 0.45), Vector3(13.4, 0.11 + k * 0.22, -5.4 - k * 0.45), _wood)
		Visuals.box(self, Vector3(2.2, 0.11 + k * 0.22, 0.45), Vector3(13.4, (0.11 + k * 0.22) * 0.5, -5.4 - k * 0.45), _wood_dark)
	Visuals.box(self, Vector3(0.1, 1.0, 4.6), Vector3(12.25, 2.2, -7.4), _wood_dark, Vector3(26, 0, 0)) # rampe
	_solid(self, Vector3(2.2, 3.0, 4.6), Vector3(13.4, 1.5, -7.6))
	_stairs_interact(self, GROUND_STAIRS_UP, "Monter à l'étage (chambres)", UP + Vector3(10.0, 0, 0.5), "L'étage — Chambres")
	# Escalier vers le sous-sol (coin sud-ouest) : trémie sombre et marches qui descendent.
	var hole := Vector3(-12.0, 0, 8.6)
	Visuals.box(self, Vector3(2.4, 0.03, 3.2), hole + Vector3(0, 0.015, 0), Visuals.mat(Color(0.01, 0.01, 0.01)))
	for k in 5:
		var shade := 0.3 - k * 0.05
		Visuals.box(self, Vector3(2.0, 0.02, 0.5), hole + Vector3(0, 0.035, -1.2 + k * 0.55),
			Visuals.mat(Color(0.33 * shade * 3.0, 0.19 * shade * 3.0, 0.1 * shade * 3.0)))
	for sx: float in [-1.0, 1.0]:
		Visuals.box(self, Vector3(0.12, 0.9, 3.2), hole + Vector3(1.25 * sx, 0.45, 0), _wood_dark)
	Visuals.label(self, "Sous-sol — entraînement", hole + Vector3(0, 1.5, -1.6), Color(0.9, 0.7, 0.4), 26)
	_stairs_interact(self, GROUND_STAIRS_DOWN, "Descendre au sous-sol (salle d'entraînement)", CELLAR + Vector3(-9.0, 0, -3.0), "Le sous-sol — Salle d'entraînement")
	# Tonneaux et caisses.
	for p: Vector3 in [Vector3(-13.8, 0, 9.8), Vector3(-13.9, 0, 3.8), Vector3(10.0, 0, 9.8), Vector3(11.0, 0, 9.9)]:
		_barrel(self, p, 0.4)
	Visuals.box(self, Vector3(0.8, 0.7, 0.8), Vector3(12.2, 0.35, 9.6), _wood, Vector3(0, 20, 0))
	# Tableau des quêtes sur le mur nord.
	var board_pos := Vector3(-8.0, 0, -HALF_Z + 0.3)
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
	Visuals.box(self, Vector3(0.05, 1.6, 1.0), Vector3(-HALF_X + 0.25, 2.8, -9.0), Visuals.mat(Color(0.35, 0.05, 0.05)))
	Visuals.sphere(self, 0.18, Vector3(-HALF_X + 0.3, 2.9, -9.0), Visuals.mat(Color(0.85, 0.8, 0.65)))


func _build_rune_circle() -> void:
	Visuals.torus(self, 1.5, 1.65, RUNE_CIRCLE + Vector3(0, 0.02, 0), Visuals.glow_mat(Color(0.45, 0.25, 0.85), 1.2))
	Visuals.torus(self, 1.1, 1.16, RUNE_CIRCLE + Vector3(0, 0.02, 0), Visuals.glow_mat(Color(0.45, 0.25, 0.85), 0.8))
	for k in 8:
		var a := TAU * k / 8.0
		Visuals.box(self, Vector3(0.18, 0.02, 0.06), RUNE_CIRCLE + Vector3(cos(a) * 1.33, 0.03, sin(a) * 1.33),
			Visuals.glow_mat(Color(0.6, 0.4, 1.0), 2.0), Vector3(0, -rad_to_deg(a), 0))


# =====================================================================================
# Étage : couloir et chambres
# =====================================================================================

func _build_upstairs() -> void:
	var o := UP
	_floor(self, o + Vector3(0, 0, -3.0), 13.0, 6.0, false)
	_wall_x_axis(self, o, -9.0, -13.0, 13.0, [-9.0, -3.0, 3.0, 9.0], _stone)
	_wall_z_axis(self, o, -13.0, -9.0, 3.0, [], _stone)
	_low_wall(self, o + Vector3(0, 0, 3.0), Vector3(26.0, 1.0, 0.3)) # garde-corps
	_low_wall(self, o + Vector3(13.0, 0, -3.0), Vector3(0.3, 1.0, 12.0))
	var names := ["Chambre 1 — Zarathos", "Chambre 2 — la vôtre", "Chambre 3 — occupée", "Chambre 4 — hantée ?"]
	for i in 4:
		var cx := -9.0 + i * 6.0
		# Cloisons entre chambres (s'effacent devant le héros) et mur côté couloir avec porte.
		if i > 0:
			var sep := o + Vector3(cx - 3.0, 0, -6.0)
			Visuals.box(self, Vector3(0.25, 3.0, 6.0), sep + Vector3(0, 1.5, 0), _cut_stone)
			_solid(self, Vector3(0.25, 3.0, 6.0), sep + Vector3(0, 1.5, 0))
		for side: float in [-1.0, 1.0]:
			var seg := o + Vector3(cx + side * 1.85, 0, -3.0)
			Visuals.box(self, Vector3(2.3, 1.0, 0.25), seg + Vector3(0, 0.5, 0), _stone)
			_solid(self, Vector3(2.3, 3.0, 0.25), seg + Vector3(0, 1.5, 0))
		Visuals.label(self, names[i], o + Vector3(cx, 1.6, -2.7), Color(0.9, 0.8, 0.6), 22)
		_build_room(o + Vector3(cx, 0, -6.0), i)
	# Couloir : tapis, lanternes, escalier qui redescend.
	Visuals.box(self, Vector3(22.0, 0.02, 1.4), o + Vector3(0, 0.01, 0), Visuals.mat(Color(0.3, 0.07, 0.06), 0.95))
	for x: float in [-9.0, -1.0, 7.0]:
		_lantern(self, o + Vector3(x, 2.6, -3.3), false)
	for k in 6:
		Visuals.box(self, Vector3(2.0, 0.2, 0.45), o + Vector3(11.8, -0.1 - k * 0.2, -0.5 + k * 0.45), _wood)
	_stairs_interact(self, o + Vector3(10.2, 0, 0.5), "Descendre à la salle commune", GROUND_STAIRS_UP + Vector3(-1.0, 0, 1.2), "Le Crâne Hurlant")


func _build_room(c: Vector3, index: int) -> void:
	var blankets := [Color(0.35, 0.1, 0.4), Color(0.5, 0.08, 0.06), Color(0.1, 0.25, 0.4), Color(0.2, 0.3, 0.15)]
	# Lit contre le mur du fond.
	var bed := c + Vector3(-1.3, 0, -1.6)
	Visuals.box(self, Vector3(1.3, 0.4, 2.2), bed + Vector3(0, 0.2, 0), _wood_dark)
	Visuals.box(self, Vector3(1.2, 0.18, 2.1), bed + Vector3(0, 0.49, 0), Visuals.mat(Color(0.85, 0.82, 0.72)))
	Visuals.box(self, Vector3(1.25, 0.08, 1.4), bed + Vector3(0, 0.6, 0.35), Visuals.mat(blankets[index]))
	Visuals.box(self, Vector3(0.8, 0.12, 0.35), bed + Vector3(0, 0.62, -0.8), Visuals.mat(Color(0.95, 0.93, 0.88)))
	Visuals.box(self, Vector3(1.3, 0.9, 0.1), bed + Vector3(0, 0.45, -1.1), _wood_dark)
	_solid(self, Vector3(1.3, 1.0, 2.2), bed + Vector3(0, 0.5, 0))
	# Coffre, table de chevet et bougie, tapis.
	Visuals.box(self, Vector3(0.9, 0.55, 0.55), c + Vector3(1.6, 0.275, -2.2), _wood)
	Visuals.box(self, Vector3(0.95, 0.06, 0.6), c + Vector3(1.6, 0.58, -2.2), _iron)
	Visuals.box(self, Vector3(0.5, 0.55, 0.5), c + Vector3(0.0, 0.275, -2.4), _wood_dark)
	Visuals.cylinder(self, 0.04, 0.04, 0.16, c + Vector3(0.0, 0.63, -2.4), Visuals.mat(Color(0.9, 0.85, 0.7)))
	Visuals.sphere(self, 0.03, c + Vector3(0.0, 0.74, -2.4), Visuals.glow_mat(Color(1.0, 0.7, 0.3), 8.0))
	var light := Visuals.flicker_light(self, c + Vector3(0.0, 1.2, -2.0), Color(1.0, 0.65, 0.35), 1.3, 5.0)
	light.flicker_amount = 0.35
	Visuals.box(self, Vector3(2.0, 0.02, 1.4), c + Vector3(0.6, 0.01, 0.6), Visuals.mat(blankets[(index + 1) % 4].darkened(0.3), 0.95))
	match index:
		0: # Zarathos : piles de grimoires et orbe
			for k in 4:
				Visuals.box(self, Vector3(0.4, 0.08, 0.3), c + Vector3(1.5, 0.62 + k * 0.08, -2.2), Visuals.mat(Color(0.3 + k * 0.1, 0.1, 0.35)))
			Visuals.sphere(self, 0.12, c + Vector3(1.9, 0.75, 1.0), Visuals.glow_mat(Color(0.6, 0.4, 1.0), 3.0))
		1: # votre chambre : on peut y dormir
			Interactable.create(self, bed + Vector3(1.0, 0, 0.3), "Dormir (%d po — PV et dB restaurés)" % Balance.REST_PRICE,
				func() -> void: GameState.run_dialogue_action("rest"), 1.8)
		2: # occupée : ronflements (une bosse sous la couverture)
			Visuals.capsule(self, 0.3, 1.4, bed + Vector3(0, 0.75, 0.2), Visuals.mat(blankets[2]), Vector3(90, 0, 0))
		3: # hantée : lueur spectrale
			var ghost := Visuals.flicker_light(self, c + Vector3(0.5, 1.5, 0.0), Color(0.4, 0.8, 1.0), 1.5, 5.0)
			ghost.flicker_amount = 0.9
			Visuals.sphere(self, 0.25, c + Vector3(0.5, 1.4, 0.0), Visuals.transparent_mat(Color(0.6, 0.9, 1.0, 0.25), 1.0), Vector3(1, 1.6, 1))


# =====================================================================================
# Sous-sol : salle d'entraînement
# =====================================================================================

func _build_cellar() -> void:
	var o := CELLAR
	var tiles := Visuals.mat(Color(0.2, 0.19, 0.19), 0.9)
	Visuals.box(self, Vector3(26.0, 0.1, 16.0), o + Vector3(0, -0.05, 0), tiles)
	for x in range(-12, 13, 2):
		Visuals.box(self, Vector3(0.04, 0.02, 16.0), o + Vector3(x, 0.005, 0), Visuals.mat(Color(0.08, 0.08, 0.08)))
	for z in range(-7, 8, 2):
		Visuals.box(self, Vector3(26.0, 0.02, 0.04), o + Vector3(0, 0.005, z), Visuals.mat(Color(0.08, 0.08, 0.08)))
	_wall_x_axis(self, o, -8.0, -13.0, 13.0, [], _stone)
	_wall_z_axis(self, o, -13.0, -8.0, 8.0, [], _stone)
	_low_wall(self, o + Vector3(0, 0, 8.0), Vector3(26.0, 0.9, 0.4))
	_low_wall(self, o + Vector3(13.0, 0, 0), Vector3(0.4, 0.9, 16.0))
	# Torches murales.
	for p: Vector3 in [Vector3(-7, 2.2, -7.7), Vector3(1, 2.2, -7.7), Vector3(9, 2.2, -7.7), Vector3(-12.7, 2.2, 2.0)]:
		Visuals.box(self, Vector3(0.12, 0.45, 0.12), o + p + Vector3(0, -0.3, 0), _wood_dark)
		Visuals.sphere(self, 0.12, o + p, Visuals.glow_mat(Color(1.0, 0.55, 0.15), 6.0), Vector3(1, 1.5, 1))
		Visuals.flicker_light(self, o + p + Vector3(0, 0.3, 0.8), Color(1.0, 0.6, 0.3), 2.8, 11.0)
	# Réserves : tonneaux et râteliers à bouteilles contre le mur ouest.
	for k in 4:
		_barrel(self, o + Vector3(-12.0, 0, 3.5 + k * 1.0), 0.42)
	for k in 3:
		var rack := o + Vector3(-9.0 + k * 1.6, 0, -7.4)
		Visuals.box(self, Vector3(1.4, 1.8, 0.4), rack + Vector3(0, 0.9, 0), _wood_dark)
		for r in 4:
			for b in 5:
				Visuals.cylinder(self, 0.06, 0.06, 0.3, rack + Vector3(-0.5 + b * 0.25, 0.3 + r * 0.42, 0.1),
					Visuals.mat(Color(0.25, 0.1, 0.12), 0.2), Vector3(90, 0, 0), 6)
		_solid(self, Vector3(1.4, 2.0, 0.4), rack + Vector3(0, 1.0, 0))
	# Escalier qui remonte.
	for k in 5:
		Visuals.box(self, Vector3(2.0, 0.22 + k * 0.22, 0.45), o + Vector3(-11.5, (0.22 + k * 0.22) * 0.5, -3.6 - k * 0.45), _wood)
	_stairs_interact(self, o + Vector3(-10.8, 0, -2.4), "Remonter à la salle commune", GROUND_STAIRS_DOWN + Vector3(1.8, 0, -0.6), "Le Crâne Hurlant")
	# Mannequins : 3 groupés (sorts de zone et rebonds), 1 isolé (≥ 13 m des autres).
	for p: Vector3 in [Vector3(-3.0, 0, -3.0), Vector3(-1.3, 0, -3.9), Vector3(-1.3, 0, -2.1)]:
		_dummy(o + p)
	_dummy(o + Vector3(10.0, 0, -3.0))
	Visuals.label(self, "Cibles groupées — sorts de zone", o + Vector3(-2.0, 3.0, -3.0), Color(1.0, 0.8, 0.45), 28)
	Visuals.label(self, "Cible isolée", o + Vector3(10.0, 3.0, -3.0), Color(1.0, 0.8, 0.45), 28)
	var friend := FriendlyDummy.new()
	friend.position = o + Vector3(3.5, 0, 4.0)
	add_child(friend)
	Visuals.label(self, "Les soins de groupe soignent tous les alliés proches", o + Vector3(3.5, 3.1, 4.0), Color(0.6, 1.0, 0.6), 22)


func _dummy(pos: Vector3) -> void:
	var d := TrainingDummy.new()
	d.position = pos
	d.rotation.y = PI * 0.25
	add_child(d)


# =====================================================================================
# Briques de construction
# =====================================================================================

func _floor(parent: Node3D, center: Vector3, half_x: float, half_z: float, with_collision: bool) -> void:
	var planks := int(half_z * 2.0 / 0.5)
	for i in planks:
		var shade := randf_range(0.8, 1.15)
		var m := Visuals.mat(Color(0.2 * shade, 0.15 * shade, 0.11 * shade), 0.8)
		Visuals.box(parent, Vector3(half_x * 2.0, 0.1, 0.47), center + Vector3(0, -0.05, -half_z + 0.25 + i * 0.5), m)
	Visuals.box(parent, Vector3(half_x * 2.0 + 2.0, 0.1, half_z * 2.0 + 2.0), center + Vector3(0, -0.12, 0), Visuals.mat(Color(0.03, 0.02, 0.02)))
	if with_collision:
		# Sol « physique » : sert de base au maillage de navigation des clients.
		_solid(parent, Vector3(half_x * 2.0, 0.2, half_z * 2.0), center + Vector3(0, -0.1, 0))


## Collision statique ajoutée à la navigation (les clients contournent l'obstacle).
func _solid(parent: Node3D, size: Vector3, pos: Vector3) -> void:
	Visuals.solid(parent, size, pos).add_to_group("tavern_nav")


func _solid_cylinder(parent: Node3D, r: float, h: float, pos: Vector3) -> void:
	Visuals.solid_cylinder(parent, r, h, pos).add_to_group("tavern_nav")


func _low_wall(parent: Node3D, center: Vector3, size: Vector3) -> void:
	Visuals.box(parent, size, center + Vector3(0, size.y * 0.5, 0), _stone)
	Visuals.box(parent, Vector3(size.x + 0.1, 0.08, size.z + 0.1), center + Vector3(0, size.y, 0), _wood_dark)
	_solid(parent, Vector3(size.x, 3.0, size.z), center + Vector3(0, 1.5, 0))


## Mur le long de l'axe X (z fixe), avec fenêtres centrées sur les x donnés.
func _wall_x_axis(parent: Node3D, o: Vector3, z: float, x_from: float, x_to: float, windows: Array, mat: Material) -> void:
	var t := 0.4
	var w := 1.6
	var cursor := x_from
	for wx: float in windows:
		_wall_block(parent, o + Vector3((cursor + wx - w * 0.5) * 0.5, WALL_H * 0.5, z), Vector3(wx - w * 0.5 - cursor, WALL_H, t), mat)
		_window(parent, o + Vector3(wx, 0, z), Vector3(w, 0, t), Vector3(0, 0, 1))
		cursor = wx + w * 0.5
	_wall_block(parent, o + Vector3((cursor + x_to) * 0.5, WALL_H * 0.5, z), Vector3(x_to - cursor, WALL_H, t), mat)
	_solid(parent, Vector3(x_to - x_from, 4.0, t), o + Vector3((x_from + x_to) * 0.5, 2.0, z))


## Mur le long de l'axe Z (x fixe).
func _wall_z_axis(parent: Node3D, o: Vector3, x: float, z_from: float, z_to: float, windows: Array, mat: Material) -> void:
	var t := 0.4
	var w := 1.6
	var cursor := z_from
	for wz: float in windows:
		_wall_block(parent, o + Vector3(x, WALL_H * 0.5, (cursor + wz - w * 0.5) * 0.5), Vector3(t, WALL_H, wz - w * 0.5 - cursor), mat)
		_window(parent, o + Vector3(x, 0, wz), Vector3(t, 0, w), Vector3(1, 0, 0))
		cursor = wz + w * 0.5
	_wall_block(parent, o + Vector3(x, WALL_H * 0.5, (cursor + z_to) * 0.5), Vector3(t, WALL_H, z_to - cursor), mat)
	_solid(parent, Vector3(t, 4.0, z_to - z_from), o + Vector3(x, 2.0, (z_from + z_to) * 0.5))


func _wall_block(parent: Node3D, center: Vector3, size: Vector3, mat: Material) -> void:
	if size.x <= 0.01 or size.z <= 0.01:
		return
	Visuals.box(parent, size, center, mat)
	Visuals.box(parent, size + Vector3(0.05, -size.y + 0.2, 0.05), Vector3(center.x, WALL_H - 0.1, center.z), _wood_dark)


## Fenêtre à croisillons, clair de lune bleuté qui entre dans la salle.
func _window(parent: Node3D, center: Vector3, size: Vector3, inward: Vector3) -> void:
	var sill := 1.1
	var top := 2.6
	Visuals.box(parent, Vector3(maxf(size.x, 0.4), sill, maxf(size.z, 0.4)), center + Vector3(0, sill * 0.5, 0), _stone)
	Visuals.box(parent, Vector3(maxf(size.x, 0.4), WALL_H - top, maxf(size.z, 0.4)), center + Vector3(0, (top + WALL_H) * 0.5, 0), _stone)
	var along := Vector3(1, 0, 0) if inward.z != 0.0 else Vector3(0, 0, 1)
	var pane := Visuals.box(parent, along * 1.5 + Vector3(0, top - sill, 0) + inward * 0.04, center + Vector3(0, (sill + top) * 0.5, 0),
		Visuals.glow_mat(Color(0.25, 0.35, 0.65), 0.9))
	pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var frame := along * 1.6 + Vector3(0, 0.08, 0) + inward * 0.12
	for y: float in [sill, (sill + top) * 0.5, top]:
		Visuals.box(parent, frame, center + Vector3(0, y, 0) + inward * 0.05, _wood_dark)
	Visuals.box(parent, Vector3(0.08, top - sill, 0.08) + inward * 0.04, center + Vector3(0, (sill + top) * 0.5, 0) + inward * 0.05, _wood_dark)
	var moon := SpotLight3D.new()
	moon.light_color = Color(0.45, 0.55, 1.0)
	moon.light_energy = 3.0
	moon.spot_range = 9.0
	moon.spot_angle = 28.0
	moon.shadow_enabled = true
	moon.position = center + Vector3(0, 3.4, 0) - inward * 0.8
	parent.add_child(moon)
	moon.look_at(center + inward * 3.5, Vector3.UP)


## Chaise dont l'avant (+Z local) est orienté selon `yaw`.
func _chair(parent: Node3D, pos: Vector3, yaw: float) -> void:
	var chair := Node3D.new()
	chair.position = pos
	chair.rotation.y = yaw
	parent.add_child(chair)
	Visuals.box(chair, Vector3(0.46, 0.06, 0.46), Vector3(0, 0.46, 0), _wood)
	for lx: float in [-0.19, 0.19]:
		for lz: float in [-0.19, 0.19]:
			Visuals.box(chair, Vector3(0.05, 0.46, 0.05), Vector3(lx, 0.23, lz), _wood_dark)
	Visuals.box(chair, Vector3(0.46, 0.55, 0.05), Vector3(0, 0.76, -0.21), _wood)


func _lantern(parent: Node3D, pos: Vector3, shadows: bool) -> void:
	Visuals.box(parent, Vector3(0.05, 0.3, 0.05), pos + Vector3(0, 0.3, 0), _iron)
	Visuals.box(parent, Vector3(0.26, 0.04, 0.26), pos + Vector3(0, 0.16, 0), _iron)
	Visuals.box(parent, Vector3(0.26, 0.04, 0.26), pos + Vector3(0, -0.16, 0), _iron)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			Visuals.box(parent, Vector3(0.03, 0.32, 0.03), pos + Vector3(0.12 * sx, 0, 0.12 * sz), _iron)
	Visuals.box(parent, Vector3(0.18, 0.26, 0.18), pos, Visuals.glow_mat(Color(1.0, 0.65, 0.25), 3.5))
	Visuals.flicker_light(parent, pos, Color(1.0, 0.68, 0.38), 2.6, 8.5, shadows)


func _barrel(parent: Node3D, p: Vector3, r: float) -> void:
	Visuals.cylinder(parent, r, r, r * 2.3, p + Vector3(0, r * 1.15, 0), _wood, Vector3.ZERO, 14)
	Visuals.torus(parent, r - 0.02, r + 0.02, p + Vector3(0, r * 0.45, 0), _iron)
	Visuals.torus(parent, r - 0.02, r + 0.02, p + Vector3(0, r * 1.85, 0), _iron)
	_solid_cylinder(parent, r + 0.02, 1.5, p + Vector3(0, 0.75, 0))


func _stairs_interact(parent: Node3D, pos: Vector3, text: String, destination: Vector3, area: String) -> void:
	Interactable.create(parent, pos, text, travel.bind(destination, area), 1.8)


# =====================================================================================
# Navigation, PNJ et clients
# =====================================================================================

## Maillage de navigation du rez-de-chaussée, calculé au lancement à partir des collisions.
func _bake_navigation() -> void:
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_EXPLICIT
	nm.geometry_source_group_name = "tavern_nav"
	nm.agent_radius = 0.35
	nm.agent_height = 1.6
	nm.agent_max_climb = 0.2
	nm.cell_size = 0.25
	nm.cell_height = 0.25
	nm.filter_baking_aabb = AABB(Vector3(-HALF_X, -1.0, -HALF_Z), Vector3(HALF_X * 2.0, 3.0, HALF_Z * 2.0))
	_nav.navigation_mesh = nm
	_nav.bake_navigation_mesh(false)


func claim_bar_spot() -> int:
	var free: Array[int] = []
	for i in _bar_taken.size():
		if not _bar_taken[i]:
			free.append(i)
	if free.is_empty():
		return -1
	var idx: int = free.pick_random()
	_bar_taken[idx] = true
	return idx


func bar_spot(index: int) -> Vector3:
	var p: Vector3 = BAR_SPOTS[index]
	return p


func release_bar_spot(index: int) -> void:
	if index >= 0 and index < _bar_taken.size():
		_bar_taken[index] = false


func _spawn_npcs() -> void:
	# Brunhilde, tavernière ogresse, 1,5 fois plus large que les autres ogres.
	var brunhilde := Npc.create("brunhilde", Vector3(1.0, 0, -9.1), 0.0)
	brunhilde.look = {"sex": "f", "race": "ogre", "horns": 0, "tusks": 1, "beard": 0, "hair": 0, "hair_color": 2, "width_mult": 1.5}
	brunhilde.interact_radius = 3.2
	add_child(brunhilde)
	add_child(Npc.create("zarathos", Vector3(12.8, 0, 1.8), -120.0))
	add_child(Npc.create("inconnue", Vector3(-13.5, 0, -9.3), 45.0))
	_gerald = Npc.create("gerald", _gerald_home, 80.0)
	add_child(_gerald)
	# Clients générés avec l'outil de création de personnage.
	var seats := _seats.duplicate()
	seats.shuffle()
	var used_names: Array[String] = []
	var specials := [
		{"id": "borin", "look": {"sex": "m", "race": "ogre", "horns": 0, "tusks": 0, "beard": 1, "hair": 0, "hair_color": 0}},
		{"id": "sylvaine", "look": {"sex": "f", "race": "humain", "horns": 0, "tusks": 0, "beard": 0, "hair": 3, "hair_color": 3}},
	]
	for i in 9:
		if seats.is_empty():
			break
		var seat: Dictionary = seats.pop_back()
		var p := Patron.new()
		p.tavern = self
		p.seat_pos = seat["pos"]
		p.seat_yaw = seat["yaw"]
		p.position = seat["pos"]
		if i < specials.size():
			var sp: Dictionary = specials[i]
			p.npc_id = str(sp["id"])
			p.look = sp["look"]
		else:
			var look := RaceDB.random_appearance()
			var female: bool = look["sex"] == "f"
			var pool: Array = RaceDB.FEMALE_NAMES if female else RaceDB.MALE_NAMES
			var name := str(pool.pick_random())
			while used_names.has(name):
				name = str(pool.pick_random())
			used_names.append(name)
			p.npc_id = "client"
			p.look = look
			p.display_name = name
			p.title_override = "Cliente" if female else "Client"
			p.dialogue_id = "client|" + name
		add_child(p)
	# Katrkar, en fauteuil roulant (jambes écrasées par un troll des montagnes).
	var katrkar := Patron.new()
	katrkar.npc_id = "katrkar"
	katrkar.wheelchair = true
	katrkar.tavern = self
	katrkar.look = {"sex": "m", "race": "orc", "horns": 0, "tusks": 2, "beard": 1, "hair": 0, "hair_color": 1}
	katrkar.seat_pos = _katrkar_seat["pos"]
	katrkar.seat_yaw = _katrkar_seat["yaw"]
	katrkar.position = _katrkar_seat["pos"]
	add_child(katrkar)


# =====================================================================================
# Portail, Plumeau et retrouvailles
# =====================================================================================

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


func _spawn_plumeau() -> void:
	var state := GameState.quest_state("plumeau")
	if state == QuestDB.State.TURNED_IN:
		var cub := OwlbearCub.new()
		cub.position = _gerald_home + Vector3(0.9, 0, 0.6)
		add_child(cub)
		cub.follow(_gerald)
	elif state == QuestDB.State.OBJECTIVE_DONE:
		_reunion()


## Retour du donjon : Plumeau court vers Gérald, puis Gérald vient remercier le héros.
func _reunion() -> void:
	var cub := OwlbearCub.new()
	cub.position = hero.global_position + Vector3(-1.0, 0, 0.5)
	add_child(cub)
	await get_tree().create_timer(1.0, false).timeout
	cub.follow(_gerald, 3.5)
	_gerald.say("PLUMEAU ?!", 3.0)
	var guard := 0.0
	while is_instance_valid(cub) and cub.global_position.distance_to(_gerald.global_position) > 1.8 and guard < 20.0:
		await get_tree().create_timer(0.25, false).timeout
		guard += 0.25
	cub.celebrate()
	Sfx.play("levelup", -6.0, 0.0)
	_gerald.say("Mon tout petit !", 3.0)
	await get_tree().create_timer(1.5, false).timeout
	# Gérald vient à la rencontre du héros.
	guard = 0.0
	while is_instance_valid(hero) and _gerald.global_position.distance_to(hero.global_position) > 1.9 and guard < 30.0:
		_gerald.walk_to(hero.global_position + (_gerald.global_position - hero.global_position).normalized() * 1.2, 2.2)
		await get_tree().create_timer(0.4, false).timeout
		guard += 0.4
	_gerald.walker.stop()
	var to_hero := hero.global_position - _gerald.global_position
	_gerald.rotation.y = atan2(to_hero.x, to_hero.z)
	Events.dialogue_requested.emit("gerald")
	await Events.dialogue_closed
	if GameState.quest_state("plumeau") == QuestDB.State.TURNED_IN:
		GameState.flags["plumeau_reunited"] = true
	_gerald.walk_to(_gerald_home)
