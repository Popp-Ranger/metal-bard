extends Level
## Le Temple du Dragon, dans l'univers de la légende de Back Jlack (chapitre 2, quête « pick_destin »).
##   • En bas : une esplanade de roche sous l'orage, au pied de marches interminables qui se perdent dans les nuages ;
##     un portail ramène à la taverne de notre époque (pour se reposer).
##   • En haut (zone séparée, reliée par les marches avec un fondu) : le parvis, la façade du temple et son immense
##     tête de dragon, Back Jlack, et la porte, scellée jusqu'à l'épreuve (jouer le solo du sage, « Chant de fer », en
##     entier : une note sur chacune de ses notes, 80 % au moins). Réussie, la porte s'ouvre dans un coup de tonnerre, et la foudre tombe du ciel ; elle mène au donjon
##     du temple (dungeon.gd, thème « temple »).

const PLAZA := Vector3.ZERO
const TOP := Vector3(0.0, 0.0, -150.0)
const STEP_DEPTH := 0.9
const STEP_RISE := 0.32
const TRIAL_PASS := 0.8

var backjlack: Npc
var door_interact: Interactable
var _door_leaves: Array[Node3D] = []
var _storm: DirectionalLight3D
var _rain: CPUParticles3D
var _next_bolt := 3.0
var _flash_k := 0.0
var _stone: StandardMaterial3D
var _dark_stone: StandardMaterial3D


func _ready() -> void:
	GameState.flags.erase("in_dungeon")
	setup_level("night", "Le Temple du Dragon")
	_stone = Visuals.textured("dalles", 3.0, Color(0.62, 0.6, 0.64))
	_dark_stone = Visuals.textured("roche", 3.0, Color(0.3, 0.28, 0.32))
	_build_storm()
	_build_plaza()
	_build_terrace()
	_build_facade()
	var spawn := str(GameState.flags.get("temple_spawn", "marches"))
	GameState.flags.erase("temple_spawn")
	spawn_hero(TOP + Vector3(0, 0, -3.0) if spawn == "parvis" else PLAZA + Vector3(0, 0, 0.5))
	Events.story_action.connect(_on_story_action)
	Events.solo_finished.connect(_on_trial_finished)
	if bool(GameState.flags.get("temple_trial_ok", false)):
		_open_doors(false)
	Sfx.play_playlist("res://audio/music/donjons", -12.0)
	if spawn == "marches" and not bool(GameState.flags.get("temple_visited", false)):
		GameState.flags["temple_visited"] = true
		Events.notify("Un autre univers... Devant vous, des marches interminables. Tout en haut, un temple à tête de dragon.", Color(0.75, 0.8, 1.0))
		_lightning(TOP + Vector3(-6, 0, -16), true)


func _process(delta: float) -> void:
	if hero != null:
		_rain.global_position = hero.global_position + Vector3(0, 12, 0)
	_next_bolt -= delta
	if _next_bolt <= 0.0:
		_next_bolt = randf_range(5.0, 11.0)
		var around := hero.global_position if hero != null else PLAZA
		_lightning(around + Vector3(randf_range(-14, 14), 0, randf_range(-26, -12)), false)
	_flash_k = maxf(0.0, _flash_k - delta * 2.5)
	_storm.light_energy = 0.15 + _flash_k * 2.5


# --- Orage -----------------------------------------------------------------------------------

func _build_storm() -> void:
	_storm = DirectionalLight3D.new()
	_storm.light_color = Color(0.6, 0.65, 1.0)
	_storm.light_energy = 0.15
	_storm.rotation_degrees = Vector3(-60, 30, 0)
	add_child(_storm)
	_rain = CPUParticles3D.new()
	_rain.amount = 400
	_rain.lifetime = 0.8
	_rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_rain.emission_box_extents = Vector3(16, 0.2, 16)
	_rain.direction = Vector3(0.1, -1, 0)
	_rain.spread = 3.0
	_rain.gravity = Vector3(0, -30, 0)
	_rain.initial_velocity_min = 8.0
	_rain.initial_velocity_max = 10.0
	var drop := BoxMesh.new()
	drop.size = Vector3(0.015, 0.45, 0.015)
	drop.material = Visuals.transparent_mat(Color(0.6, 0.65, 0.85, 0.35))
	_rain.mesh = drop
	add_child(_rain)


## Éclair qui tombe du ciel sur `ground`, avec flash et coup de tonnerre (`big` : plus fort, qui secoue l'écran).
func _lightning(ground: Vector3, big: bool) -> void:
	_flash_k = 1.0
	ArcBolt.spawn(self, ground + Vector3(randf_range(-2, 2), 26.0, randf_range(-2, 2)), ground, 0.45 if big else 0.3, 0.45, Color(0.8, 0.85, 1.0))
	Sfx.play("solo_thunder", 0.0 if big else -6.0)
	if big:
		Events.camera_shake.emit(0.3, 0.5)
		Events.screen_flash.emit(Color(0.85, 0.9, 1.0, 0.45), 0.3)


# --- En bas : l'esplanade et le pied des marches -----------------------------------------

func _build_plaza() -> void:
	var rock := Visuals.box(self, Vector3(36, 0.2, 30), PLAZA + Vector3(0, -0.1, -2), _dark_stone)
	rock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Rebords de falaise tout autour (on ne tombe pas dans le vide).
	for side: float in [-1.0, 1.0]:
		Visuals.box(self, Vector3(1.5, 1.2, 30), PLAZA + Vector3(17.5 * side, 0.6, -2), _stone)
		Visuals.solid(self, Vector3(1.5, 3.0, 30), PLAZA + Vector3(17.5 * side, 1.5, -2))
	Visuals.box(self, Vector3(36, 1.2, 1.5), PLAZA + Vector3(0, 0.6, 12.5), _stone)
	Visuals.solid(self, Vector3(36, 3.0, 1.5), PLAZA + Vector3(0, 1.5, 12.5))
	# Les marches interminables : elles montent vers le temple et se perdent dans l'orage.
	_build_stairs(PLAZA + Vector3(0, 0, -7.0), -1.0, 28)
	Visuals.solid(self, Vector3(36, 3.0, 1.0), PLAZA + Vector3(0, 1.5, -7.4))
	for side: float in [-1.0, 1.0]:
		_brazier(PLAZA + Vector3(5.6 * side, 0, -6.0))
		for k in 3:
			var p := PLAZA + Vector3(randf_range(6.0, 14.0) * side, 0, randf_range(-4.0, 8.0))
			Visuals.cylinder(self, 0.45, 0.5, randf_range(0.8, 2.6), p + Vector3(0, 0.6, 0), _stone, Vector3(randf_range(-8, 8), 0, randf_range(-8, 8)), 8)
	Interactable.create(self, PLAZA + Vector3(0, 0, -5.8), "Gravir les marches interminables", _climb, 2.5)
	# Le portail vers la taverne de notre époque (pour se reposer).
	var portal := Portal.new()
	portal.position = PLAZA + Vector3(-9.0, 0, 3.0)
	portal.prompt = "Retourner à la Chèvre Fringante (votre époque)"
	portal.on_enter = func() -> void:
		GameState.location = {"scene": Router.TAVERN}
		GameState.save_game()
	portal.target_scene = Router.TAVERN
	add_child(portal)


## Marches qui montent (`dir` = -1, vers -Z) ou descendent vers la caméra (+1), à partir de `start`.
func _build_stairs(start: Vector3, dir: float, count: int) -> void:
	for k in count:
		var h := STEP_RISE * (k + 1) * (1.0 if dir < 0.0 else -1.0)
		var z := start.z + dir * (k * STEP_DEPTH + STEP_DEPTH * 0.5)
		var height := absf(h) + 0.3
		var step := Visuals.box(self, Vector3(9.0, height, STEP_DEPTH), Vector3(start.x, h - height * 0.5 + (0.0 if dir < 0.0 else 0.0), z),
			_stone if k % 2 == 0 else Visuals.textured("dalles", 3.0, Color(0.74, 0.72, 0.76)))
		step.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if k % 3 == 1:
			for side: float in [-1.0, 1.0]:
				var b := Vector3(start.x + 4.9 * side, h, z)
				Visuals.cylinder(self, 0.25, 0.3, 0.8, b + Vector3(0, 0.4, 0), _dark_stone, Vector3.ZERO, 8)
				Visuals.sphere(self, 0.2, b + Vector3(0, 0.9, 0), Visuals.glow_mat(Color(1.0, 0.45, 0.15), 4.0), Vector3(1, 0.6, 1))
				var l := Visuals.flicker_light(self, b + Vector3(0, 1.4, 0), Color(1.0, 0.5, 0.2), 1.5, 6.0)
				l.flicker_amount = 0.3


func _brazier(p: Vector3) -> void:
	Visuals.cylinder(self, 0.45, 0.3, 1.1, p + Vector3(0, 0.55, 0), _dark_stone, Vector3.ZERO, 8)
	Visuals.sphere(self, 0.35, p + Vector3(0, 1.2, 0), Visuals.glow_mat(Color(1.0, 0.45, 0.12), 5.0), Vector3(1, 0.6, 1))
	var l := Visuals.flicker_light(self, p + Vector3(0, 1.8, 0), Color(1.0, 0.5, 0.2), 2.5, 9.0)
	l.flicker_amount = 0.3
	Visuals.solid_cylinder(self, 0.45, 2.0, p + Vector3(0, 1.0, 0))


func _climb() -> void:
	Events.notify("Des marches. Encore des marches. Toujours des marches... Vos mollets de coq vous maudissent.", Events.COLOR_DEFAULT)
	travel(TOP + Vector3(0, 0, -2.0), "Le parvis du temple")


func _descend() -> void:
	travel(PLAZA + Vector3(0, 0, -4.0), "Au pied des marches")


# --- En haut : le parvis, la façade et Back Jlack ------------------------------------------

func _build_terrace() -> void:
	var floor_mesh := Visuals.box(self, Vector3(30, 0.2, 22), TOP + Vector3(0, -0.1, -2), _stone)
	floor_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for x in range(-14, 15, 2):
		Visuals.box(self, Vector3(0.05, 0.01, 22), TOP + Vector3(x, 0.005, -2), _dark_stone)
	for side: float in [-1.0, 1.0]:
		Visuals.box(self, Vector3(1.0, 1.0, 22), TOP + Vector3(15.0 * side, 0.5, -2), _dark_stone)
		Visuals.solid(self, Vector3(1.0, 3.0, 22), TOP + Vector3(15.0 * side, 1.5, -2))
		_brazier(TOP + Vector3(6.5 * side, 0, 4.0))
	# Les marches redescendent vers l'esplanade, côté caméra.
	_build_stairs(TOP + Vector3(0, 0, 9.0), 1.0, 14)
	Visuals.solid(self, Vector3(30, 3.0, 1.0), TOP + Vector3(0, 1.5, 9.6))
	Interactable.create(self, TOP + Vector3(0, 0, 8.2), "Redescendre les marches", _descend, 2.5)
	backjlack = Npc.create("backjlack", TOP + Vector3(3.2, 0, -7.0), 200.0)
	backjlack.wander_radius = 0.0
	add_child(backjlack)


## Façade du temple : mur colossal, colonnes, et au-dessus de la porte une immense tête de dragon aux yeux de braise,
## gueule ouverte au-dessus des battants.
func _build_facade() -> void:
	var z := TOP.z - 11.5
	Visuals.box(self, Vector3(28, 14, 2.0), Vector3(TOP.x, 7.0, z - 1.0), _dark_stone)
	Visuals.solid(self, Vector3(28, 6.0, 2.0), Vector3(TOP.x, 3.0, z - 1.0))
	for k in 6:
		var x := TOP.x - 11.0 + k * 4.4
		if absf(x) < 3.0:
			continue
		Visuals.cylinder(self, 0.6, 0.7, 11.0, Vector3(x, 5.5, z + 0.4), _stone, Vector3.ZERO, 12)
		Visuals.box(self, Vector3(1.6, 0.6, 1.6), Vector3(x, 11.2, z + 0.4), _stone)
		Visuals.solid_cylinder(self, 0.7, 3.0, Vector3(x, 1.5, z + 0.4))
	# Le noir derrière les battants (on le voit quand ils s'ouvrent).
	Visuals.box(self, Vector3(3.8, 4.7, 0.1), Vector3(TOP.x, 2.35, z + 0.02), Visuals.mat(Color(0.01, 0.0, 0.01), 1.0))
	# Portes (deux battants sur leurs gonds).
	var wood := Visuals.mat(Color(0.18, 0.08, 0.05), 0.75)
	var iron := Visuals.mat(Color(0.2, 0.18, 0.18), 0.4, 0.8)
	for side: float in [-1.0, 1.0]:
		var hinge := Node3D.new()
		hinge.position = Vector3(TOP.x + 1.9 * side, 0, z + 0.2)
		add_child(hinge)
		Visuals.box(hinge, Vector3(1.9, 4.6, 0.25), Vector3(-0.95 * side, 2.3, 0), wood)
		for k in 3:
			Visuals.box(hinge, Vector3(1.9, 0.12, 0.3), Vector3(-0.95 * side, 0.8 + k * 1.5, 0.02), iron)
		Visuals.torus(hinge, 0.12, 0.17, Vector3(-1.6 * side, 2.2, 0.2), iron, Vector3(90, 0, 0))
		_door_leaves.append(hinge)
	door_interact = Interactable.create(self, Vector3(TOP.x, 0, z + 1.6), "Porte du temple (scellée)", _on_door, 2.2)
	_build_dragon_head(Vector3(TOP.x, 7.6, z + 0.6))


func _build_dragon_head(c: Vector3) -> void:
	var scale_mat := Visuals.mat(Color(0.16, 0.14, 0.14), 0.6, 0.3)
	var bone := Visuals.mat(Color(0.7, 0.66, 0.55), 0.6)
	var head := Node3D.new()
	head.position = c
	add_child(head)
	var under := Visuals.flicker_light(head, Vector3(0, -3.0, 3.5), Color(1.0, 0.35, 0.1), 2.2, 10.0) # lueur de braise sous la gueule
	under.flicker_amount = 0.25
	Visuals.sphere(head, 2.4, Vector3(0, 0.6, -0.6), scale_mat, Vector3(1.25, 0.85, 0.9)) # crâne
	Visuals.box(head, Vector3(2.6, 1.3, 3.2), Vector3(0, 0.3, 1.6), scale_mat, Vector3(-10, 0, 0)) # museau
	Visuals.box(head, Vector3(2.4, 0.5, 2.8), Vector3(0, -1.5, 1.4), scale_mat, Vector3(20, 0, 0)) # mâchoire ouverte
	for side: float in [-1.0, 1.0]:
		var eye := Visuals.glow_mat(Color(1.0, 0.25, 0.05), 6.0)
		Visuals.sphere(head, 0.32, Vector3(1.1 * side, 1.1, 0.9), eye, Vector3(1.0, 0.6, 0.6))
		var l := Visuals.flicker_light(head, Vector3(1.1 * side, 1.0, 1.8), Color(1.0, 0.3, 0.05), 2.0, 9.0)
		l.flicker_amount = 0.2
		DemonParts.horn(head, Vector3(1.5 * side, 1.6, -0.8), side, bone, 3.2, 40.0)
		Visuals.cylinder(head, 0.0, 0.18, 0.9, Vector3(0.6 * side, 1.7, 1.4), bone, Vector3(-30, 0, 0), 6) # naseaux
		for k in 4:
			Visuals.cylinder(head, 0.0, 0.14, 0.6, Vector3((0.35 + k * 0.28) * side, -0.6, 2.6 - k * 0.15), bone, Vector3(180, 0, 0), 6) # crocs du haut
			Visuals.cylinder(head, 0.0, 0.12, 0.5, Vector3((0.35 + k * 0.28) * side, -1.2, 2.3 - k * 0.15), bone, Vector3.ZERO, 6) # crocs du bas


func _on_door() -> void:
	if bool(GameState.flags.get("temple_trial_ok", false)):
		_enter_temple()
		return
	Sfx.play("dud", -8.0)
	Events.notify("Back Jlack : « Pas si vite ! D'abord, l'épreuve. Viens me voir. »", DialogueDB.npc_color("backjlack"))


func _enter_temple() -> void:
	GameState.active_quest = "pick_destin"
	if GameState.dungeon_seed == 0 or GameState.dungeon_state.is_empty():
		GameState.dungeon_seed = randi_range(1, 999999)
		GameState.dungeon_state = {}
		GameState.town_portal = {}
	GameState.flags["in_dungeon"] = true
	GameState.save_game()
	Router.go_to(Router.DUNGEON)


# --- L'épreuve de Back Jlack ---------------------------------------------------------------

func _on_story_action(action: String) -> void:
	if action != "epreuve":
		return
	await Events.dialogue_closed
	GameState.flags["temple_attempts"] = int(GameState.flags.get("temple_attempts", 0)) + 1
	hero.planted = true
	hero.model.solo_pose(true)
	Events.notify("L'épreuve : joue le Chant de fer, note pour note. Il faut 80 % de justesse. Touches 1 2 3 4 !", Events.COLOR_GOLD)
	Events.solo_requested.emit("epreuve", 0) # la partition vient du morceau (data/epreuve_solo.json)


## Résultat de l'épreuve : au moins 80 % de notes justes pour ouvrir le temple (du premier coup : bénédiction).
func _on_trial_finished(mode: String, hits: int, total: int) -> void:
	if mode != "epreuve":
		return
	hero.planted = false
	hero.model.solo_pose(false)
	var ratio := float(hits) / maxf(1.0, float(total))
	Events.notify("Score : %d / %d (%d %%) — il en faut %d %%." % [hits, total, roundi(ratio * 100.0), roundi(TRIAL_PASS * 100.0)],
		Events.COLOR_GOLD if ratio >= TRIAL_PASS else Events.COLOR_BAD)
	if ratio < TRIAL_PASS:
		Sfx.play("dud", -4.0)
		Events.dialogue_requested.emit("backjlack_echec")
		return
	GameState.flags["temple_trial_ok"] = true
	if int(GameState.flags.get("temple_attempts", 1)) == 1:
		GameState.flags["temple_first_try"] = true
		GameState.damage_buff_time = GameState.DAMAGE_BUFF_DURATION
		Events.notify("Bénédiction de Back Jlack : +10 % de dégâts pendant 20 minutes !", Events.COLOR_GOLD)
	Events.quest_updated.emit("pick_destin")
	await _open_doors(true)
	Events.dialogue_requested.emit("backjlack_reussite")
	GameState.save_game()


## La porte du temple s'ouvre dans un coup de tonnerre ; des éclairs tombent du ciel tout autour du parvis.
func _open_doors(animate: bool) -> void:
	door_interact.prompt = "Entrer dans le Temple du Dragon"
	for i in _door_leaves.size():
		var target := deg_to_rad(-100.0 if i == 0 else 100.0)
		if animate:
			_door_leaves[i].create_tween().tween_property(_door_leaves[i], "rotation:y", target, 1.6).set_trans(Tween.TRANS_SINE)
		else:
			_door_leaves[i].rotation.y = target
	if not animate:
		return
	Sfx.play("boom", 0.0)
	_lightning(TOP + Vector3(0, 0, -9.0), true)
	for k in 5:
		await get_tree().create_timer(0.35, false).timeout
		_lightning(TOP + Vector3(randf_range(-12, 12), 0, randf_range(-8, 6)), k % 2 == 0)
	await get_tree().create_timer(0.6, false).timeout
