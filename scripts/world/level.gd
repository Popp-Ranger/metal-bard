class_name Level
extends Node3D
## Base commune aux niveaux (taverne, donjons) : environnement, caméra, héros, HUD.

var hero: Hero
var camera: IsoCamera
var hud: Hud


func setup_level(env_kind: String, area_name: String) -> void:
	add_child(Visuals.make_environment(env_kind))
	camera = IsoCamera.new()
	add_child(camera)
	add_child(PostFx.new())
	hud = Hud.new()
	add_child(hud)
	hud.show_area_name(area_name)


func spawn_hero(pos: Vector3) -> void:
	hero = Hero.new()
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
