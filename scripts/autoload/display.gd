extends Node
## Réglages d'affichage (menu Options > Affichage), sauvegardés dans user://settings.cfg (section « affichage ») et
## appliqués au lancement :
##  - mode : fenêtré ou plein écran (exclusif : la fréquence de l'écran est pleinement exploitée) ;
##  - résolution : taille de la fenêtre en mode fenêtré ; en plein écran, l'écran garde sa définition et la 3D est
##    calculée à la résolution choisie (l'interface reste nette) ;
##  - images par seconde : 60, 90, 120 ou 140 (synchronisation verticale coupée pour pouvoir dépasser la fréquence
##    de l'écran ; la physique suit la même cadence, pour des mouvements fluides).

const SETTINGS_PATH := "user://settings.cfg"
const SECTION := "affichage"
const MODES := ["Fenêtré", "Plein écran"]
const FPS_CHOICES := [60, 90, 120, 140]
const RESOLUTIONS: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1600, 900),
	Vector2i(1920, 1080), Vector2i(2560, 1080), Vector2i(2560, 1440), Vector2i(3440, 1440), Vector2i(3840, 2160)]

var fullscreen := false
var resolution := Vector2i(1600, 900)
var fps := 60


func _ready() -> void:
	load_settings()
	apply()


## Résolutions proposées : les courantes qui tiennent dans l'écran, plus celle de l'écran.
func resolutions() -> Array[Vector2i]:
	var screen := screen_size()
	var out: Array[Vector2i] = []
	for r in RESOLUTIONS:
		if r.x <= screen.x and r.y <= screen.y:
			out.append(r)
	if not out.has(screen):
		out.append(screen)
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x * a.y < b.x * b.y)
	return out


func screen_size() -> Vector2i:
	if _headless():
		return Vector2i(1920, 1080)
	return DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())


func apply() -> void:
	Engine.max_fps = fps
	Engine.physics_ticks_per_second = fps
	Engine.max_physics_steps_per_frame = maxi(8, ceili(fps / 15.0))
	if _headless():
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var vp := get_viewport()
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		var screen := screen_size()
		vp.scaling_3d_scale = clampf(float(resolution.y) / float(maxi(1, screen.y)), 0.25, 1.0)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		vp.scaling_3d_scale = 1.0
		var size := resolution.min(screen_size())
		DisplayServer.window_set_size(size)
		var screen_pos := DisplayServer.screen_get_position(DisplayServer.window_get_current_screen())
		DisplayServer.window_set_position(screen_pos + (screen_size() - size) / 2)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH) # conserve les autres sections (audio)
	cfg.set_value(SECTION, "plein_ecran", fullscreen)
	cfg.set_value(SECTION, "resolution", resolution)
	cfg.set_value(SECTION, "images_par_seconde", fps)
	cfg.save(SETTINGS_PATH)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH) # fichier absent au premier lancement : valeurs par défaut
	fullscreen = bool(cfg.get_value(SECTION, "plein_ecran", false))
	resolution = cfg.get_value(SECTION, "resolution", Vector2i(1600, 900))
	var f := int(cfg.get_value(SECTION, "images_par_seconde", 60))
	fps = f if FPS_CHOICES.has(f) else 60


func _headless() -> bool:
	return DisplayServer.get_name() == "headless"
