extends Level
## La Chèvre Fringante — auberge-hub sur trois niveaux :
##   • rez-de-chaussée : salle commune, comptoir, clients, PNJ, portail ;
##   • étage (zone éloignée, reliée par l'escalier) : couloir et chambres ;
##   • sous-sol (zone éloignée) : salle d'entraînement avec mannequins et cible amicale.
## Les étages sont des zones séparées du même niveau : l'escalier y mène avec un fondu,
## comme dans la plupart des jeux isométriques (sinon l'étage cacherait la salle).
## La taverne est faite main dans l'éditeur de Godot (scène TavernMap, voir docs/EDITEUR_NIVEAUX.md) :
## ce script la charge et y branche toute la vie de la taverne.

const MAP := "res://scenes/levels/taverne.tscn"
const MAX_STANDING := 2 # jamais plus de 2 clients debout en même temps

var map: TavernMap
var _portal: Portal
var _nav: NavigationRegion3D
var _bar_spots: Array[Vector3] = []
var _bar_taken: Array[bool] = []
## Clients actuellement debout (jamais plus de MAX_STANDING à la fois).
var _standing := 0
var _seats: Array[Dictionary] = [] # {pos, yaw, chair}
var _katrkar_seat := {}
var _gerald: Npc
var _gerald_home := Vector3.ZERO
## Chaise et table du héros (thé glacé à la goyave et plateau de fromages) : {pos, yaw}, gardée libre.
var _hero_seat := {}
## Gérald revient demander de l'aide après chaque refus (toutes les PLEA_DELAY secondes).
var _plea_timer := 0.0
var _gerald_busy := false
const PLEA_DELAY := 12.0
var _rune_circle := Vector3.ZERO
var _blue_portal_pos := Vector3.ZERO
var _training_zones: Array[TavernMarker] = []
var _cut_stone: ShaderMaterial
var _door_hinges: Array[Node3D] = []
var _door_block: StaticBody3D
var _door_interact: Interactable
## Lit loué par le héros (on s'y repose).
var bed_interact: Interactable


func _ready() -> void:
	setup_level("tavern", "La Chèvre Fringante")
	var fill := DirectionalLight3D.new()
	fill.light_color = Color(0.6, 0.65, 0.9)
	fill.light_energy = 0.35
	fill.rotation_degrees = Vector3(-55, -30, 0)
	add_child(fill)
	_nav = NavigationRegion3D.new()
	add_child(_nav)
	_load_map()
	_bake_navigation()
	_spawn_npcs()
	var spawn := _marker_pos(TavernMarker.Kind.APPARITION, Vector3(0.0, 0.0, 9.5))
	var from_dungeon: bool = GameState.flags.get("in_dungeon", false)
	if from_dungeon:
		spawn = _rune_circle + Vector3(0.0, 0.0, 2.5)
		GameState.flags.erase("in_dungeon")
		if GameState.flags.get("from_town_portal", false):
			spawn = _blue_portal_pos + Vector3(0.0, 0.0, 1.6) # sortie du portail bleu
		GameState.flags.erase("from_town_portal")
		if GameState.flags.has("last_death_gold_lost"):
			var lost: int = GameState.flags.get("last_death_gold_lost", 0)
			GameState.flags.erase("last_death_gold_lost")
			Events.notify("Zarathos vous a ramené inconscient à la taverne... (-%d médiators)" % lost, Events.COLOR_BAD)
	spawn_hero(spawn)
	if GameState.flags.get("intro_arrival", false):
		GameState.flags.erase("intro_arrival")
		_arrival_scene()
	if GameState.flags.get("portal_open", false) and GameState.quest_state("plumeau") == QuestDB.State.ACTIVE:
		_open_portal()
	Events.portal_opened.connect(_open_portal)
	if not GameState.town_portal.is_empty():
		_open_blue_portal()
	Sfx.play_music("res://audio/music/tavern_theme.mp3", -8.0) # musique « metal-band-tavern »
	_spawn_plumeau()
	GameState.save_game()


func _process(delta: float) -> void:
	_update_pleas(delta)
	if hero != null:
		if _cut_stone != null:
			_cut_stone.set_shader_parameter("hero_pos", hero.global_position)
		# Sous-sol d'entraînement : décibels toujours au maximum.
		var in_cellar := is_in_cellar(hero.global_position)
		if in_cellar != GameState.infinite_mana:
			GameState.infinite_mana = in_cellar
			if in_cellar:
				Events.notify("Salle d'entraînement : décibels illimités !", Events.COLOR_MAGIC)
		if in_cellar and GameState.mana < GameState.max_mana():
			GameState.mana = GameState.max_mana()
			Events.hero_mana_changed.emit(GameState.mana, GameState.max_mana())


## On ne joue pas dans la salle commune ni à l'étage : sorts seulement dans la zone d'entraînement.
func spells_allowed_at(pos: Vector3) -> bool:
	return is_in_cellar(pos)


func is_in_cellar(pos: Vector3) -> bool:
	for z in _training_zones:
		if z.contains(pos):
			return true
	return false


# =====================================================================================
# Scène de la taverne (faite main) : mobilier, escaliers, portes, lit, points du jeu
# =====================================================================================

func _load_map() -> void:
	var path := str(GameState.flags.get("test_tavern", MAP))
	map = (load(path) as PackedScene).instantiate() as TavernMap
	add_child(map) # le mobilier se construit lui-même (TavernMarker)
	for grid: GridMap in [map.floor_map(), map.wall_map()]:
		grid.add_to_group(TavernDecor.NAV_GROUP)
	var partition := map.wall_map().mesh_library.get_item_mesh(TavernMap.PARTITION)
	if partition != null:
		_cut_stone = partition.surface_get_material(0) as ShaderMaterial
	_moonlight()
	for m in map.markers():
		match m.kind:
			TavernMarker.Kind.TABLE:
				_seats.append_array(m.seats)
				if not m.wheelchair_seat.is_empty():
					_katrkar_seat = m.wheelchair_seat
			TavernMarker.Kind.COMPTOIR:
				_bar_spots.append_array(m.bar_spots())
			TavernMarker.Kind.CERCLE_RUNES:
				_rune_circle = m.global_position
			TavernMarker.Kind.PORTAIL_BLEU:
				_blue_portal_pos = m.global_position
			TavernMarker.Kind.ZONE_ENTRAINEMENT:
				_training_zones.append(m)
			TavernMarker.Kind.PORTES:
				_build_front_doors(m)
			TavernMarker.Kind.ESCALIER_MONTANT, TavernMarker.Kind.ESCALIER_DESCENDANT:
				var dest := m.destination_marker()
				if dest != null:
					Interactable.create(self, m.global_position, m.text, travel.bind(dest.global_position, dest.text), 1.8)
			TavernMarker.Kind.TABLEAU:
				var board := DialogueProp.new()
				board.dialogue_id = "tableau"
				board.prompt = "Lire le tableau des quêtes"
				board.position = m.global_transform * Vector3(0, 0, 0.6)
				add_child(board)
			TavernMarker.Kind.LIT:
				if m.option:
					bed_interact = Interactable.create(self, m.global_transform * Vector3(1.0, 0, 0.3), "Se coucher sur le lit",
						_use_bed.bind(m.global_position, m.global_rotation.y), 1.8)
			TavernMarker.Kind.MANNEQUIN:
				var d := TrainingDummy.new()
				d.transform = m.global_transform
				add_child(d)
			TavernMarker.Kind.MANNEQUIN_AMI:
				var f := FriendlyDummy.new()
				f.transform = m.global_transform
				add_child(f)
			TavernMarker.Kind.PORTAIL_DEMONIAQUE:
				var demon := DemonPortal.new()
				demon.transform = m.global_transform
				add_child(demon)
	_bar_taken.resize(_bar_spots.size())
	_bar_taken.fill(false)


func _marker_pos(kind: int, fallback: Vector3) -> Vector3:
	var m := map.first(kind)
	return m.global_position if m != null else fallback


## Clair de lune bleuté qui entre par chaque fenêtre (une lumière par baie de fenêtres côte à côte),
## du côté où il y a du plancher.
func _moonlight() -> void:
	var walls := map.wall_map()
	var floor_grid := map.floor_map()
	for cell: Vector3i in walls.get_used_cells_by_item(TavernMap.WINDOW):
		var basis := walls.get_cell_item_basis(cell)
		var along := Vector3i(roundi((basis * Vector3.RIGHT).x), 0, roundi((basis * Vector3.RIGHT).z))
		var prev := cell - along
		if walls.get_cell_item(prev) == TavernMap.WINDOW and walls.get_cell_item_orientation(prev) == walls.get_cell_item_orientation(cell):
			continue # pas le début de la baie
		var count := 1
		while walls.get_cell_item(cell + along * count) == TavernMap.WINDOW \
				and walls.get_cell_item_orientation(cell + along * count) == walls.get_cell_item_orientation(cell):
			count += 1
		var center := walls.to_global(walls.map_to_local(cell)) + basis * Vector3(0, 0, -0.5) \
			+ Vector3(along) * (count - 1) * 0.5
		center.y = 0.0
		var inward := basis * Vector3.BACK
		if floor_grid.get_cell_item(floor_grid.local_to_map(floor_grid.to_local(center + inward * 0.6))) < 0:
			inward = -inward
		var moon := SpotLight3D.new()
		moon.light_color = Color(0.45, 0.55, 1.0)
		moon.light_energy = 3.0
		moon.spot_range = 9.0
		moon.spot_angle = 28.0
		moon.shadow_enabled = false
		add_child(moon)
		moon.position = center + Vector3(0, 3.4, 0) - inward * 0.8
		moon.look_at(center + inward * 3.5, Vector3.UP)


## Portes d'entrée (double porte de bois, tête de chèvre). Elles se referment derrière le héros à la fin de
## l'intro et restent verrouillées jusqu'à une quête ultérieure (drapeau « tavern_doors_open »).
func _build_front_doors(m: TavernMarker) -> void:
	var opened: bool = GameState.flags.get("tavern_doors_open", false)
	var arriving: bool = GameState.flags.get("intro_arrival", false)
	_door_hinges = m.hinges
	for i in _door_hinges.size():
		var side := -1.0 if i == 0 else 1.0
		_door_hinges[i].rotation.y = side * deg_to_rad(100.0) if (opened or arriving) else 0.0
	_door_block = Visuals.solid(self, Vector3(2.5, 3.0, 0.3), Vector3.ZERO)
	_door_block.transform = m.global_transform * Transform3D(Basis.IDENTITY, Vector3(0, 1.5, 0))
	_door_block.add_to_group(TavernDecor.NAV_GROUP)
	if opened:
		_door_block.queue_free()
	else:
		_door_interact = Interactable.create(self, m.global_transform * Vector3(0, 0, -0.8), "Porte verrouillée", _on_locked_door, 1.6)


func _on_locked_door() -> void:
	Sfx.play("thud", -6.0)
	Events.notify("Les portes de la Chèvre Fringante sont verrouillées. Grokk : « Personne ne sort tant que la Lune de Sang est levée ! »", Events.COLOR_BAD)


## Fin de l'intro : les portes claquent derrière le héros.
func _close_doors_behind_hero() -> void:
	await get_tree().create_timer(1.3, false).timeout
	for i in _door_hinges.size():
		var tw := _door_hinges[i].create_tween()
		tw.tween_property(_door_hinges[i], "rotation:y", 0.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await get_tree().create_timer(0.5, false).timeout
	Sfx.play("boom", -4.0)
	Sfx.play("thud", 0.0)
	Events.camera_shake.emit(0.2, 0.3)
	Events.notify("BLAM ! Les portes se referment lourdement derrière vous... Elles ne se rouvriront pas de sitôt.", Color(1.0, 0.7, 0.5))


# =====================================================================================
# Navigation, PNJ et clients
# =====================================================================================

## Maillage de navigation, calculé au lancement à partir des collisions (sols, murs, mobilier).
func _bake_navigation() -> void:
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_EXPLICIT
	nm.geometry_source_group_name = TavernDecor.NAV_GROUP
	nm.agent_radius = 0.25
	nm.agent_height = 1.5
	nm.agent_max_climb = 0.25
	nm.cell_size = 0.25
	nm.cell_height = 0.25
	_nav.navigation_mesh = nm
	_nav.bake_navigation_mesh(false)


func claim_standing() -> bool:
	if _standing >= MAX_STANDING:
		return false
	_standing += 1
	return true


func release_standing() -> void:
	_standing = maxi(0, _standing - 1)


func standing_count() -> int:
	return _standing


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
	return _bar_spots[index]


func release_bar_spot(index: int) -> void:
	if index >= 0 and index < _bar_taken.size():
		_bar_taken[index] = false


func _spawn_npcs() -> void:
	for m in map.markers():
		if m.kind != TavernMarker.Kind.PNJ:
			continue
		var id: String = TavernMarker.NPCS[m.npc]
		var n := Npc.create(id, m.global_position, rad_to_deg(m.global_rotation.y))
		match id:
			"brunhilde":
				# Grokk, le tavernier orc (modèle 3D importé, voir Npc.SKINS), derrière son comptoir.
				n.interact_radius = 3.2
			"zarathos":
				n.wander_radius = 2.5 # quelques pas près de son cercle de runes
				n.walk_speed = 0.9
			"gerald":
				_gerald = n
				_gerald_home = m.global_position
		add_child(n)
	# Clients générés avec l'outil de création de personnage.
	var seats := _seats.duplicate()
	_reserve_hero_seat(seats)
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
		p.chair = seat["chair"]
		p.position = seat["pos"]
		if i < specials.size():
			var sp: Dictionary = specials[i]
			p.npc_id = str(sp["id"])
			p.look = sp["look"]
		else:
			var look := RaceDB.random_appearance()
			var female: bool = look["sex"] == "f"
			var pool: Array = RaceDB.FEMALE_NAMES if female else RaceDB.MALE_NAMES
			var npc_name := str(pool.pick_random())
			while used_names.has(npc_name):
				npc_name = str(pool.pick_random())
			used_names.append(npc_name)
			p.npc_id = "client"
			p.look = look
			p.display_name = npc_name
			p.title_override = "Cliente" if female else "Client"
			p.dialogue_id = "client|" + npc_name
		add_child(p)
	# Katrkar, en fauteuil roulant (jambes écrasées par un troll des montagnes).
	if not _katrkar_seat.is_empty():
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
	_portal.position = _rune_circle
	_portal.prompt = "Entrer dans les Catacombes Suintantes"
	_portal.target_scene = Router.DUNGEON
	_portal.on_enter = _on_enter_dungeon
	add_child(_portal)
	Events.camera_shake.emit(0.15, 0.5)


func _on_enter_dungeon() -> void:
	GameState.flags["in_dungeon"] = true
	GameState.save_game()


func _spawn_plumeau() -> void:
	if _gerald == null:
		return
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



# =====================================================================================
# Arrivée de l'intro : thé glacé, brie, et Gérald le fromager
# =====================================================================================

## Garde pour le héros la chaise la plus proche de l'entrée (les clients ne s'y assoient pas) et pose sur
## sa table un thé glacé à la goyave et un plateau de fromages.
func _reserve_hero_seat(seats: Array) -> void:
	if seats.is_empty():
		return
	var door := _marker_pos(TavernMarker.Kind.APPARITION, Vector3(0.0, 0.0, 9.5))
	var best: Dictionary = seats[0]
	for s: Dictionary in seats:
		if (s["pos"] as Vector3).distance_to(door) < (best["pos"] as Vector3).distance_to(door):
			best = s
	seats.erase(best)
	_hero_seat = best
	var yaw := float(best["yaw"])
	var to_table := Vector3(sin(yaw), 0.0, cos(yaw))
	var top := (best["pos"] as Vector3) + to_table * 0.62 + Vector3(0, 0.84, 0)
	var side := to_table.cross(Vector3.UP)
	# Thé glacé à la goyave : grand verre rose orangé, glaçons, paille.
	var glass := Visuals.transparent_mat(Color(1.0, 0.55, 0.45, 0.75))
	Visuals.cylinder(self, 0.055, 0.045, 0.2, top + side * 0.22 + Vector3(0, 0.1, 0), glass, Vector3.ZERO, 14)
	var ice := Visuals.transparent_mat(Color(0.9, 0.95, 1.0, 0.6))
	Visuals.box(self, Vector3(0.035, 0.035, 0.035), top + side * 0.21 + Vector3(0, 0.18, 0), ice, Vector3(20, 30, 0))
	Visuals.cylinder(self, 0.006, 0.006, 0.26, top + side * 0.24 + Vector3(0.01, 0.24, 0), Visuals.mat(Color(0.95, 0.3, 0.35)), Vector3(0, 0, 14), 6)
	# Plateau de fromages : planche, meule de brie entamée, quartiers, raisin.
	var board := Visuals.box(self, Vector3(0.4, 0.03, 0.28), top + Vector3(0, 0.015, 0), Visuals.mat(Color(0.5, 0.33, 0.18)))
	board.rotation.y = yaw
	var brie := Visuals.mat(Color(0.96, 0.92, 0.8), 0.9)
	var crust := Visuals.mat(Color(0.98, 0.97, 0.93), 0.95)
	Visuals.cylinder(self, 0.09, 0.09, 0.045, top - side * 0.06 + Vector3(0, 0.055, 0), crust, Vector3.ZERO, 18)
	Visuals.cylinder(self, 0.06, 0.06, 0.046, top - side * 0.06 + to_table * 0.02 + Vector3(0, 0.056, 0), brie, Vector3.ZERO, 12)
	var yellow := Visuals.mat(Color(0.95, 0.75, 0.3), 0.7)
	for k in 3:
		var p := top + side * (0.07 + k * 0.045) - to_table * 0.06 + Vector3(0, 0.05, 0)
		Visuals.box(self, Vector3(0.04, 0.04, 0.07), p, yellow, Vector3(0, rad_to_deg(yaw) + 20 * k, 0))
	var grape := Visuals.mat(Color(0.35, 0.12, 0.35), 0.4)
	for k in 5:
		Visuals.sphere(self, 0.018, top + side * 0.1 + to_table * (0.07 + 0.012 * (k % 2)) + Vector3(0.01 * k, 0.05, 0), grape)


## Fin de l'intro : les portes claquent, puis le héros s'attable devant son thé glacé et son brie,
## et Gérald Pissenlit trottine jusqu'à lui.
func _arrival_scene() -> void:
	await _close_doors_behind_hero()
	await get_tree().create_timer(1.2, false).timeout
	if _hero_seat.is_empty() or hero == null:
		return
	Events.screen_flash.emit(Color.BLACK, 1.4)
	hero.sit_at(_hero_seat["pos"], float(_hero_seat["yaw"]))
	camera.snap_to_target()
	Events.notify("Un thé glacé à la goyave... et un plateau de fromages. Impossible de résister.", Color(1.0, 0.85, 0.6))
	await get_tree().create_timer(3.0, false).timeout
	if GameState.quest_state("plumeau") == QuestDB.State.AVAILABLE:
		await _gerald_comes()


## Gérald vient jusqu'au héros, lui parle (dialogue « gerald »), puis retourne à sa place.
func _gerald_comes() -> void:
	if _gerald == null or hero == null or _gerald_busy:
		return
	_gerald_busy = true
	# À côté du héros (s'il est attablé, à côté de sa chaise, du côté le plus proche ; la table barre le reste).
	var spot := hero.global_position + (_gerald.global_position - hero.global_position).normalized() * 1.2
	if hero.sitting:
		var side := hero.facing.cross(Vector3.UP)
		if side.dot(_gerald.global_position - hero.global_position) < 0.0:
			side = -side
		spot = hero.global_position + side * 0.9 - hero.facing * 0.3
	# Point du sol praticable le plus proche (chaises et tables bloquent).
	var nav_map := get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(nav_map) > 0:
		spot = NavigationServer3D.map_get_closest_point(nav_map, spot)
		spot.y = 0.0
	_gerald.walk_to(spot, 2.2)
	var guard := 0.0
	while is_instance_valid(hero) and _gerald.walker.walking and guard < 25.0:
		await get_tree().create_timer(0.25, false).timeout
		guard += 0.25
	_gerald.walker.stop()
	var to_hero := hero.global_position - _gerald.global_position
	_gerald.rotation.y = atan2(to_hero.x, to_hero.z)
	Events.dialogue_requested.emit("gerald")
	await Events.dialogue_closed
	_plea_timer = 0.0
	_gerald.walk_to(_gerald_home)
	_gerald_busy = false


## Quête refusée : Gérald revient à la charge toutes les PLEA_DELAY secondes, tant que le héros est dans la
## salle commune (pas à l'étage, au sous-sol, au lit ni en pleine conversation).
func _update_pleas(delta: float) -> void:
	if _gerald == null or hero == null or _gerald_busy or DialogueBox.active or InventoryWindow.active:
		return
	if GameState.quest_state("plumeau") != QuestDB.State.AVAILABLE or int(GameState.flags.get("gerald_refus", 0)) <= 0:
		return
	if hero.resting or hero.global_position.distance_to(_gerald_home) > 25.0:
		return
	_plea_timer += delta
	if _plea_timer >= PLEA_DELAY:
		_plea_timer = 0.0
		_gerald_comes()


# =====================================================================================
# Chambre louée : se coucher pour récupérer
# =====================================================================================

## Lit loué : il faut l'avoir loué à Grokk, puis le héros s'y allonge et récupère
## progressivement (voir Hero.lie_down).
func _use_bed(bed: Vector3, yaw: float) -> void:
	if hero == null or hero.resting:
		return
	if not bool(GameState.flags.get("room_paid", false)):
		Events.notify("Ce lit n'est pas à toi : loue d'abord la chambre à Grokk (%d médiators)." % ItemDB.rest_price(), Events.COLOR_BAD)
		Sfx.play("dud", -8.0)
		return
	hero.lie_down(bed, yaw)


# =====================================================================================
# Portail bleu : retour au donjon, là où on l'a ouvert
# =====================================================================================

var blue_portal: Portal


func _open_blue_portal() -> void:
	blue_portal = Portal.new()
	blue_portal.blue = true
	blue_portal.position = _blue_portal_pos
	blue_portal.prompt = "Portail bleu : retourner dans les catacombes"
	blue_portal.target_scene = Router.DUNGEON
	blue_portal.on_enter = _on_enter_blue_portal
	add_child(blue_portal)


func _on_enter_blue_portal() -> void:
	GameState.flags["via_town_portal"] = true
	_on_enter_dungeon()


func _exit_tree() -> void:
	super()
	TavernDecor.clear_cache()
