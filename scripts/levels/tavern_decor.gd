class_name TavernDecor
extends RefCounted
## Mobilier et décor de la taverne, partagés par le jeu et les aperçus de l'éditeur (TavernMarker).
## Repère local de chaque objet : +Z = côté d'où l'on arrive (devant), Y vers le haut.
## `solid` : ajoute les collisions (bloquent le héros, contournées par les clients : groupe « tavern_nav »).

const NAV_GROUP := "tavern_nav"
const WALL_H := 4.0
const BLANKETS := [Color(0.35, 0.1, 0.4), Color(0.5, 0.08, 0.06), Color(0.1, 0.25, 0.4), Color(0.2, 0.3, 0.15)]

static var _mats := {}


## Matériaux partagés : "wood_dark", "wood", "wood_light", "iron", "stone", "cut_stone", "candle", "beer".
static func mat(key: String) -> Material:
	if not _mats.has(key):
		match key:
			"wood_dark":
				_mats[key] = Visuals.mat(Color(0.2, 0.11, 0.06), 0.8)
			"wood":
				_mats[key] = Visuals.mat(Color(0.33, 0.19, 0.1), 0.75)
			"wood_light":
				_mats[key] = Visuals.mat(Color(0.45, 0.28, 0.15), 0.7)
			"iron":
				_mats[key] = Visuals.mat(Color(0.15, 0.15, 0.16), 0.4, 0.8)
			"stone":
				_mats[key] = Visuals.stone_material(false, Color(0.3, 0.27, 0.25))
			"candle":
				_mats[key] = Visuals.mat(Color(0.9, 0.85, 0.7))
			"beer":
				_mats[key] = Visuals.mat(Color(0.55, 0.4, 0.2))
	return _mats[key]


static func _solid(parent: Node3D, size: Vector3, pos: Vector3, solid: bool) -> void:
	if solid:
		Visuals.solid(parent, size, pos).add_to_group(NAV_GROUP)


static func _solid_cyl(parent: Node3D, r: float, h: float, pos: Vector3, solid: bool) -> void:
	if solid:
		Visuals.solid_cylinder(parent, r, h, pos).add_to_group(NAV_GROUP)


static func _candle(parent: Node3D, pos: Vector3, light_pos: Vector3, energy: float, light_range: float) -> void:
	Visuals.cylinder(parent, 0.04, 0.04, 0.16, pos, mat("candle"))
	Visuals.sphere(parent, 0.03, pos + Vector3(0, 0.11, 0), Visuals.glow_mat(Color(1.0, 0.7, 0.3), 8.0))
	var light := Visuals.flicker_light(parent, light_pos, Color(1.0, 0.65, 0.3), energy, light_range)
	light.flicker_amount = 0.4


## Chaise dont l'avant (+Z local) est orienté selon `yaw`.
static func chair(parent: Node3D, pos: Vector3, yaw: float) -> Node3D:
	var c := Node3D.new()
	c.position = pos
	c.rotation.y = yaw
	parent.add_child(c)
	Visuals.box(c, Vector3(0.46, 0.06, 0.46), Vector3(0, 0.46, 0), mat("wood"))
	for lx: float in [-0.19, 0.19]:
		for lz: float in [-0.19, 0.19]:
			Visuals.box(c, Vector3(0.05, 0.46, 0.05), Vector3(lx, 0.23, lz), mat("wood_dark"))
	Visuals.box(c, Vector3(0.46, 0.55, 0.05), Vector3(0, 0.76, -0.21), mat("wood"))
	return c


## Places autour d'une table ronde (repère de la table) : [{pos, yaw}] ; la 2e est celle du fauteuil roulant.
static func table_seats() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for k in 4:
		var a := TAU * k / 4.0 + 0.4
		var dir := Vector3(cos(a), 0, sin(a))
		out.append({"pos": dir * 1.25, "yaw": atan2(-dir.x, -dir.z), "dir": dir})
	return out


## Table ronde avec bougie et chope ; ses chaises sont posées par TavernMarker (les clients les déplacent).
static func table(p: Node3D, solid: bool) -> void:
	Visuals.cylinder(p, 0.85, 0.85, 0.08, Vector3(0, 0.8, 0), mat("wood_light"), Vector3.ZERO, 20)
	Visuals.cylinder(p, 0.1, 0.12, 0.8, Vector3(0, 0.4, 0), mat("wood_dark"))
	Visuals.cylinder(p, 0.4, 0.45, 0.06, Vector3(0, 0.03, 0), mat("wood_dark"))
	_solid_cyl(p, 0.85, 2.0, Vector3(0, 1.0, 0), solid)
	_candle(p, Vector3(0.1, 0.93, 0.1), Vector3(0.1, 1.3, 0.1), 0.9, 3.5)
	Visuals.cylinder(p, 0.07, 0.07, 0.16, Vector3(-0.3, 0.92, -0.1), mat("beer"))


## Places au comptoir (repère du comptoir), une tous les 1,6 m le long de la façade.
static func bar_spots(length: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var n := maxi(1, floori((length - 1.4) / 1.6 + 0.001))
	for k in n:
		out.append(Vector3(-(n - 1) * 0.8 + k * 1.6, 0, 1.1))
	return out


## Comptoir le long de X (`length` m), façade vers +Z, chopes posées dessus.
static func counter(p: Node3D, length: float, solid: bool) -> void:
	Visuals.box(p, Vector3(length, 1.05, 0.7), Vector3(0, 0.525, 0), mat("wood_dark"))
	Visuals.box(p, Vector3(length + 0.2, 0.08, 0.85), Vector3(0, 1.08, 0), mat("wood_light"))
	for k in int(length):
		Visuals.box(p, Vector3(0.06, 0.9, 0.02), Vector3(-length * 0.5 + 0.5 + k, 0.5, 0.36), mat("wood"))
	_solid(p, Vector3(length, 2.0, 0.8), Vector3(0, 1.0, 0), solid)
	for k in int(length / 1.8):
		Visuals.cylinder(p, 0.07, 0.07, 0.16, Vector3(-length * 0.5 + 1.0 + k * 1.8, 1.2, 0.15 * sin(k * 2.3)), mat("beer"))


## Étagères à bouteilles contre un mur (`length` m), trois rayons.
static func shelves(p: Node3D, length: float) -> void:
	var colors := [Color(0.2, 0.5, 0.2), Color(0.5, 0.15, 0.1), Color(0.6, 0.5, 0.2), Color(0.25, 0.2, 0.5)]
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	for y: float in [1.3, 2.0, 2.7]:
		Visuals.box(p, Vector3(length, 0.06, 0.35), Vector3(0, y, 0), mat("wood"))
		for k in int(length / 0.56):
			var c: Color = colors[rng.randi_range(0, 3)]
			var h := rng.randf_range(0.22, 0.34)
			var bottle := Visuals.glow_mat(c, 0.25) if rng.randf() < 0.3 else Visuals.mat(c, 0.15)
			Visuals.cylinder(p, 0.06, 0.07, h, Vector3(-length * 0.5 + 0.3 + k * 0.55 + rng.randf_range(-0.08, 0.08), y + h * 0.5 + 0.03, 0),
				bottle, Vector3.ZERO, 8)


## Cheminée adossée au mur (foyer vers +Z), feu, crâne sur le manteau et tapis devant.
static func fireplace(p: Node3D, solid: bool) -> void:
	var stone := mat("stone")
	Visuals.box(p, Vector3(2.8, 2.4, 1.0), Vector3(0, 1.2, 0), stone)
	Visuals.box(p, Vector3(3.2, 1.6, 0.4), Vector3(0, 3.2, -0.2), stone)
	Visuals.box(p, Vector3(3.1, 0.15, 0.3), Vector3(0, 1.75, 0.45), mat("wood_dark"))
	Visuals.box(p, Vector3(1.6, 1.1, 0.2), Vector3(0, 0.55, 0.42), Visuals.mat(Color(0.02, 0.015, 0.01)))
	for k in 3:
		Visuals.cylinder(p, 0.08, 0.08, 1.0, Vector3(0.2 - k * 0.2, 0.12 + k * 0.05, 0.55), mat("wood_dark"), Vector3(90, 90 + 20 * k, 0))
	Visuals.sphere(p, 0.25, Vector3(0, 0.35, 0.6), Visuals.glow_mat(Color(1.0, 0.45, 0.1), 5.0), Vector3(1.8, 1.2, 1.4))
	Visuals.sphere(p, 0.15, Vector3(-0.1, 0.6, 0.62), Visuals.glow_mat(Color(1.0, 0.75, 0.3), 6.0))
	var light := Visuals.flicker_light(p, Vector3(0, 1.0, 1.6), Color(1.0, 0.5, 0.2), 3.5, 11.0)
	light.flicker_amount = 0.35
	_solid(p, Vector3(3.0, 3.0, 1.2), Vector3(0, 1.5, 0), solid)
	Visuals.box(p, Vector3(4.0, 0.02, 3.0), Vector3(0, 0.01, 2.6), Visuals.mat(Color(0.22, 0.08, 0.06), 0.95))
	Visuals.sphere(p, 0.25, Vector3(0, 2.3, 0.5), Visuals.mat(Color(0.8, 0.75, 0.6)), Vector3(1, 1.1, 1))
	Visuals.box(p, Vector3(0.12, 0.18, 0.1), Vector3(0, 2.18, 0.72), Visuals.mat(Color(0.05, 0.02, 0.02)))


static func barrel(p: Node3D, solid: bool, r: float = 0.4) -> void:
	Visuals.cylinder(p, r, r, r * 2.3, Vector3(0, r * 1.15, 0), mat("wood"), Vector3.ZERO, 14)
	Visuals.torus(p, r - 0.02, r + 0.02, Vector3(0, r * 0.45, 0), mat("iron"))
	Visuals.torus(p, r - 0.02, r + 0.02, Vector3(0, r * 1.85, 0), mat("iron"))
	_solid_cyl(p, r + 0.02, 1.5, Vector3(0, 0.75, 0), solid)


static func crate(p: Node3D, solid: bool) -> void:
	Visuals.box(p, Vector3(0.8, 0.7, 0.8), Vector3(0, 0.35, 0), mat("wood"))
	for y: float in [0.1, 0.6]:
		Visuals.box(p, Vector3(0.84, 0.06, 0.84), Vector3(0, y, 0), mat("wood_dark"))
	_solid(p, Vector3(0.8, 1.5, 0.8), Vector3(0, 0.75, 0), solid)


## Lanterne de fer (centre de la lanterne à l'origine).
static func lantern(p: Node3D) -> void:
	var iron := mat("iron")
	Visuals.box(p, Vector3(0.05, 0.3, 0.05), Vector3(0, 0.3, 0), iron)
	Visuals.box(p, Vector3(0.26, 0.04, 0.26), Vector3(0, 0.16, 0), iron)
	Visuals.box(p, Vector3(0.26, 0.04, 0.26), Vector3(0, -0.16, 0), iron)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			Visuals.box(p, Vector3(0.03, 0.32, 0.03), Vector3(0.12 * sx, 0, 0.12 * sz), iron)
	Visuals.box(p, Vector3(0.18, 0.26, 0.18), Vector3.ZERO, Visuals.glow_mat(Color(1.0, 0.65, 0.25), 3.5))
	Visuals.flicker_light(p, Vector3.ZERO, Color(1.0, 0.68, 0.38), 2.6, 8.5)


## Pilier de bois jusqu'au plafond, une lanterne accrochée.
static func pillar_lantern(p: Node3D, solid: bool) -> void:
	Visuals.box(p, Vector3(0.35, WALL_H + 0.4, 0.35), Vector3(0, (WALL_H + 0.4) * 0.5, 0), mat("wood_dark"))
	_solid(p, Vector3(0.4, 3.0, 0.4), Vector3(0, 1.5, 0), solid)
	var l := Node3D.new()
	l.position = Vector3(0.4, 2.35, 0.4)
	p.add_child(l)
	lantern(l)


## Escalier qui monte vers l'arrière (-Z), `steps` marches ; on l'emprunte depuis l'origine.
static func stairs_up(p: Node3D, steps: int, solid: bool) -> void:
	for k in steps:
		Visuals.box(p, Vector3(2.2, 0.22, 0.45), Vector3(0, 0.11 + k * 0.22, -1.0 - k * 0.45), mat("wood"))
		Visuals.box(p, Vector3(2.2, 0.11 + k * 0.22, 0.45), Vector3(0, (0.11 + k * 0.22) * 0.5, -1.0 - k * 0.45), mat("wood_dark"))
	if steps >= 8:
		Visuals.box(p, Vector3(0.1, 1.0, steps * 0.46), Vector3(-1.15, 2.2, -1.0 - steps * 0.22), mat("wood_dark"), Vector3(26, 0, 0)) # rampe
	_solid(p, Vector3(2.2, 3.0, steps * 0.45 + 0.1), Vector3(0, 1.5, -0.95 - steps * 0.225), solid)


## Trémie sombre et marches qui descendent, vers l'arrière (-Z) ; on l'emprunte depuis l'origine.
static func trapdoor(p: Node3D) -> void:
	var hole := Vector3(0, 0, -2.2)
	Visuals.box(p, Vector3(2.4, 0.03, 3.2), hole + Vector3(0, 0.015, 0), Visuals.mat(Color(0.01, 0.01, 0.01)))
	for k in 5:
		var shade := (0.3 - k * 0.05) * 3.0
		Visuals.box(p, Vector3(2.0, 0.02, 0.5), hole + Vector3(0, 0.035, 1.2 - k * 0.55), Visuals.mat(Color(0.33 * shade, 0.19 * shade, 0.1 * shade)))
	for sx: float in [-1.0, 1.0]:
		Visuals.box(p, Vector3(0.12, 0.9, 3.2), hole + Vector3(1.25 * sx, 0.45, 0), mat("wood_dark"))


## Tableau des quêtes accroché au mur (face vers +Z).
static func quest_board(p: Node3D) -> void:
	Visuals.box(p, Vector3(1.6, 1.1, 0.08), Vector3(0, 1.7, 0), mat("wood_dark"))
	for k in 5:
		Visuals.box(p, Vector3(0.35, 0.45, 0.02), Vector3(-0.55 + k * 0.28, 1.7 + 0.15 * sin(k * 1.7), 0.06),
			Visuals.mat(Color(0.85, 0.8, 0.65)), Vector3(0, 0, 7.0 * sin(k * 2.9)))


## Bannière de la Chèvre Fringante accrochée au mur (face vers +Z).
static func banner(p: Node3D) -> void:
	Visuals.box(p, Vector3(1.0, 1.6, 0.05), Vector3.ZERO, Visuals.mat(Color(0.35, 0.05, 0.05)))
	Visuals.sphere(p, 0.18, Vector3(0, 0.1, 0.05), Visuals.mat(Color(0.85, 0.8, 0.65)))


## Tapis de `size` m (largeur × profondeur).
static func rug(p: Node3D, size: Vector2, color: Color) -> void:
	Visuals.box(p, Vector3(size.x, 0.02, size.y), Vector3(0, 0.01, 0), Visuals.mat(color, 0.95))


## Lit (tête contre le mur, vers -Z), couverture de la couleur BLANKETS[`variant`].
static func bed(p: Node3D, variant: int, solid: bool) -> void:
	var wd := mat("wood_dark")
	Visuals.box(p, Vector3(1.3, 0.4, 2.2), Vector3(0, 0.2, 0), wd)
	Visuals.box(p, Vector3(1.2, 0.18, 2.1), Vector3(0, 0.49, 0), Visuals.mat(Color(0.85, 0.82, 0.72)))
	Visuals.box(p, Vector3(1.25, 0.08, 1.4), Vector3(0, 0.6, 0.35), Visuals.mat(BLANKETS[posmod(variant, 4)]))
	Visuals.box(p, Vector3(0.8, 0.12, 0.35), Vector3(0, 0.62, -0.8), Visuals.mat(Color(0.95, 0.93, 0.88)))
	Visuals.box(p, Vector3(1.3, 0.9, 0.1), Vector3(0, 0.45, -1.1), wd)
	_solid(p, Vector3(1.3, 1.0, 2.2), Vector3(0, 0.5, 0), solid)


## Table de chevet et sa bougie.
static func nightstand(p: Node3D, solid: bool) -> void:
	Visuals.box(p, Vector3(0.5, 0.55, 0.5), Vector3(0, 0.275, 0), mat("wood_dark"))
	_candle(p, Vector3(0, 0.63, 0), Vector3(0, 1.2, 0.4), 1.3, 5.0)
	_solid(p, Vector3(0.5, 1.0, 0.5), Vector3(0, 0.5, 0), solid)


## Coffre de chambre (bois cerclé de fer).
static func trunk(p: Node3D, solid: bool) -> void:
	Visuals.box(p, Vector3(0.9, 0.55, 0.55), Vector3(0, 0.275, 0), mat("wood"))
	Visuals.box(p, Vector3(0.95, 0.06, 0.6), Vector3(0, 0.58, 0), mat("iron"))
	_solid(p, Vector3(0.9, 1.0, 0.55), Vector3(0, 0.5, 0), solid)


## Pile de grimoires (posée à la hauteur de l'origine).
static func books(p: Node3D) -> void:
	for k in 4:
		Visuals.box(p, Vector3(0.4, 0.08, 0.3), Vector3(0, 0.04 + k * 0.08, 0), Visuals.mat(Color(0.3 + k * 0.1, 0.1, 0.35)), Vector3(0, 9.0 * k, 0))


## Orbe magique lumineuse.
static func orb(p: Node3D) -> void:
	Visuals.sphere(p, 0.12, Vector3.ZERO, Visuals.glow_mat(Color(0.6, 0.4, 1.0), 3.0))


## Dormeur : une bosse sous la couverture (à poser sur un lit).
static func sleeper(p: Node3D, variant: int) -> void:
	Visuals.capsule(p, 0.3, 1.4, Vector3(0, 0.75, 0.2), Visuals.mat(BLANKETS[posmod(variant, 4)]), Vector3(90, 0, 0))


## Fantôme : lueur spectrale.
static func ghost(p: Node3D) -> void:
	var light := Visuals.flicker_light(p, Vector3(0, 1.5, 0), Color(0.4, 0.8, 1.0), 1.5, 5.0)
	light.flicker_amount = 0.9
	Visuals.sphere(p, 0.25, Vector3(0, 1.4, 0), Visuals.transparent_mat(Color(0.6, 0.9, 1.0, 0.25), 1.0), Vector3(1, 1.6, 1))


## Râtelier à bouteilles (contre le mur, face vers +Z).
static func rack(p: Node3D, solid: bool) -> void:
	Visuals.box(p, Vector3(1.4, 1.8, 0.4), Vector3(0, 0.9, 0), mat("wood_dark"))
	var glass := Visuals.mat(Color(0.25, 0.1, 0.12), 0.2)
	for r in 4:
		for b in 5:
			Visuals.cylinder(p, 0.06, 0.06, 0.3, Vector3(-0.5 + b * 0.25, 0.3 + r * 0.42, 0.1), glass, Vector3(90, 0, 0), 6)
	_solid(p, Vector3(1.4, 2.0, 0.4), Vector3(0, 1.0, 0), solid)


## Torche murale simple (flamme à l'origine, lumière devant).
static func torch(p: Node3D) -> void:
	Visuals.box(p, Vector3(0.12, 0.45, 0.12), Vector3(0, -0.3, 0), mat("wood_dark"))
	Visuals.sphere(p, 0.12, Vector3.ZERO, Visuals.glow_mat(Color(1.0, 0.55, 0.15), 6.0), Vector3(1, 1.5, 1))
	Visuals.flicker_light(p, Vector3(0, 0.3, 0.8), Color(1.0, 0.6, 0.3), 2.8, 11.0)


## Cercle de runes de Zarathos (là où s'ouvre le portail vers le donjon).
static func rune_circle(p: Node3D) -> void:
	Visuals.torus(p, 1.5, 1.65, Vector3(0, 0.02, 0), Visuals.glow_mat(Color(0.45, 0.25, 0.85), 1.2))
	Visuals.torus(p, 1.1, 1.16, Vector3(0, 0.02, 0), Visuals.glow_mat(Color(0.45, 0.25, 0.85), 0.8))
	for k in 8:
		var a := TAU * k / 8.0
		Visuals.box(p, Vector3(0.18, 0.02, 0.06), Vector3(cos(a) * 1.33, 0.03, sin(a) * 1.33),
			Visuals.glow_mat(Color(0.6, 0.4, 1.0), 2.0), Vector3(0, -rad_to_deg(a), 0))


## Portes d'entrée : double porte voûtée tout en bois, tête de chèvre au-dessus (art/portes/build_portes.py,
## « taverne ») ; elle remplit le trou de 4 m du muret (poteaux et panneaux de planches à hauteur du muret).
## Face décorée vers +Z (la rue). Renvoie les battants [gauche, droit], qui pivotent sur leurs gonds.
const FRONT_DOORS := "res://assets/models/portes/taverne.glb"

static func front_doors(p: Node3D) -> Array[Node3D]:
	var hinges: Array[Node3D] = []
	var model := (load(FRONT_DOORS) as PackedScene).instantiate() as Node3D
	p.add_child(model)
	for c in model.get_children():
		if c.name.ends_with("_g"):
			hinges.insert(0, c as Node3D)
		elif c.name.ends_with("_d"):
			hinges.append(c as Node3D)
	# Poteaux et panneaux de part et d'autre du passage (2,5 m) : on ne passe pas à travers.
	for side: float in [-1.0, 1.0]:
		var wall := Visuals.solid(p, Vector3(0.75, 3.0, 0.4), Vector3(1.625 * side, 1.5, 0))
		wall.add_to_group(NAV_GROUP)
	return hinges


## Libère les matériaux partagés (fin de la taverne).
static func clear_cache() -> void:
	_mats.clear()
