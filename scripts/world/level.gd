class_name Level
extends Node3D
## Base commune aux niveaux (taverne, donjons) : environnement, caméra, héros, HUD.

var hero: Hero
var camera: IsoCamera
var hud: Hud


func setup_level(env_kind: String, area_name: String) -> void:
	Net.reset_level()
	add_child(Visuals.make_environment(env_kind))
	if env_kind != "night": # l'intro a déjà sa lune
		add_child(Visuals.make_key_light(env_kind))
	camera = IsoCamera.new()
	add_child(camera)
	hud = Hud.new()
	add_child(hud)
	hud.show_area_name(area_name)


func spawn_hero(pos: Vector3) -> void:
	hero = Hero.new()
	# Après un chargement : on reprend là où la partie a été sauvegardée.
	if GameState.pending_spawn != Vector3.INF:
		pos = GameState.pending_spawn
		GameState.pending_spawn = Vector3.INF
	GameState.location = {"scene": scene_file_path}
	hero.position = pos
	hero.camera = camera
	add_child(hero)
	camera.target = hero
	camera.snap_to_target()
	GameState.broadcast_all()


## Déplace le héros ailleurs dans le niveau (escaliers), avec un fondu au noir.
func travel(pos: Vector3, area_name: String = "") -> void:
	Router.fade(_place_hero.bind(pos, area_name))


func _place_hero(pos: Vector3, area_name: String) -> void:
	hero.global_position = pos
	hero.velocity = Vector3.ZERO
	camera.snap_to_target()
	if not area_name.is_empty():
		hud.show_area_name(area_name)


func _exit_tree() -> void:
	GameState.infinite_mana = false


## Lieu et position à enregistrer dans une sauvegarde manuelle.
func save_location() -> Dictionary:
	var loc := {"scene": scene_file_path}
	if hero != null:
		loc["pos"] = [snappedf(hero.global_position.x, 0.01), snappedf(hero.global_position.z, 0.01)]
	return loc


## Combat en cours : un ennemi poursuit ou attaque le héros, ou un solo est en cours.
## (On ne peut pas sauvegarder en plein combat.)
func in_combat() -> bool:
	if hero != null and (hero.casting_solo or hero.talents_caster.in_frenzy or hero.talents_caster.in_ballade):
		return true
	for n in get_tree().get_nodes_in_group("enemies"):
		var e := n as Enemy
		if e != null and not (e is TrainingDummy) and e.is_alive() and e.state != Enemy.State.WANDER:
			return true
	return false
