@tool
class_name DungeonMarker
extends Node3D
## Objet placé à la main dans un donjon (scène DungeonMap) : ennemi, coffre, torche ou décor.
## Dans l'éditeur, il s'affiche avec son apparence ; en jeu, le donjon crée le vrai objet à sa place
## (voir dungeon.gd, _spawn_from_map). Tourner le marqueur oriente l'objet ; pour une torche,
## la flèche (+Z) pointe vers l'intérieur de la pièce, l'applique contre le mur.

enum Kind { SQUELETTE, CAPITAINE, CHEF, RAT, COFFRE, TORCHE, OS, BAVE, PILIER, TONNEAU }
const NAMES := ["Squelette", "Capitaine squelette", "Chef des squelettes (clé du boss)", "Rat", "Coffre",
	"Torche murale", "Tas d'os", "Flaque de bave", "Pilier brisé", "Tonneau"]

@export_enum("Squelette", "Capitaine squelette", "Chef des squelettes (clé du boss)", "Rat", "Coffre",
	"Torche murale", "Tas d'os", "Flaque de bave", "Pilier brisé", "Tonneau")
var kind := 0:
	set(value):
		kind = value
		_refresh()

var _preview: Node3D


func _ready() -> void:
	set_notify_transform(true)
	_refresh()


func is_enemy() -> bool:
	return kind in [Kind.SQUELETTE, Kind.CAPITAINE, Kind.CHEF, Kind.RAT]


## Aperçu dans l'éditeur seulement (rien n'est enregistré dans la scène).
func _refresh() -> void:
	if Engine.is_editor_hint() and is_inside_tree():
		build_preview()


## Construit l'aperçu (appelé par l'éditeur ; public pour les captures de contrôle).
func build_preview() -> void:
	if _preview != null:
		_preview.queue_free()
	_preview = Node3D.new()
	add_child(_preview, false, Node.INTERNAL_MODE_FRONT)
	var p := _preview
	match kind:
		Kind.SQUELETTE, Kind.CAPITAINE, Kind.CHEF:
			var s := 1.0 if kind == Kind.SQUELETTE else 1.25
			var bone := Visuals.mat(Color(0.82, 0.78, 0.66))
			var rust := Visuals.mat(Color(0.38, 0.26, 0.2))
			for x: float in [-0.11, 0.11]:
				Visuals.capsule(p, 0.045 * s, 0.8 * s, Vector3(x * s, 0.4 * s, 0), bone)
			Visuals.cylinder(p, 0.12 * s, 0.1 * s, 0.6 * s, Vector3(0, 1.1 * s, 0), bone)
			Visuals.sphere(p, 0.14 * s, Vector3(0, 1.55 * s, 0.01), bone)
			for side: float in [-1.0, 1.0]:
				Visuals.sphere(p, 0.03 * s, Vector3(0.05 * side * s, 1.56 * s, 0.13 * s), Visuals.glow_mat(Color(1.0, 0.15, 0.05), 4.0))
				Visuals.capsule(p, 0.035 * s, 0.6 * s, Vector3(0.24 * side * s, 1.1 * s, 0), bone)
			Visuals.box(p, Vector3(0.05, 0.02, 0.5) * s, Vector3(0.24 * s, 0.85 * s, 0.3 * s), rust) # épée
			Visuals.cylinder(p, 0.2 * s, 0.2 * s, 0.04, Vector3(-0.3 * s, 0.95 * s, 0.05), rust, Vector3(0, 0, 90)) # bouclier
			if kind == Kind.CAPITAINE:
				Visuals.sphere(p, 0.16 * s, Vector3(0, 1.62 * s, 0), rust, Vector3(1.0, 0.7, 1.0)) # casque
			elif kind == Kind.CHEF:
				Visuals.sphere(p, 0.18 * s, Vector3(0, 1.65 * s, -0.02), Visuals.mat(Color(0.46, 0.43, 0.4)), Vector3(1.1, 0.8, 1.2))
				Visuals.box(p, Vector3(0.02, 0.14, 0.02), Vector3(0.17, 0.7, 0.06), Visuals.glow_mat(Color(1.0, 0.8, 0.3), 1.5)) # clé
		Kind.RAT:
			var fur := Visuals.mat(Color(0.3, 0.25, 0.22))
			Visuals.sphere(p, 0.16, Vector3(0, 0.14, 0), fur, Vector3(1.0, 0.8, 1.6))
			Visuals.sphere(p, 0.08, Vector3(0, 0.18, 0.26), fur)
			Visuals.capsule(p, 0.015, 0.4, Vector3(0, 0.08, -0.38), fur, Vector3(80, 0, 0))
		Kind.COFFRE:
			DungeonDecor.chest(p, Vector3.ZERO)
		Kind.TORCHE:
			DungeonDecor.torch(p, Vector3.ZERO, Vector3.BACK)
		Kind.OS:
			var rng := RandomNumberGenerator.new()
			rng.seed = 7
			DungeonDecor.bones(p, Vector3.ZERO, rng)
		Kind.BAVE:
			DungeonDecor.slime(p, Vector3.ZERO)
		Kind.PILIER:
			DungeonDecor.pillar(p, Vector3.ZERO, Visuals.stone_material(true), false)
		Kind.TONNEAU:
			DungeonDecor.barrel(p, Vector3.ZERO, false)
	if kind != Kind.TORCHE and kind != Kind.COFFRE:
		# Flèche au sol : orientation de l'objet (+Z).
		Visuals.box(p, Vector3(0.06, 0.02, 0.5), Vector3(0, 0.02, 0.35), Visuals.glow_mat(Color(0.3, 0.8, 1.0), 1.0))
	var label := Visuals.label(p, str(NAMES[kind]), Vector3(0, 2.4 if is_enemy() and kind != Kind.RAT else 1.2, 0), Color(1.0, 0.9, 0.6), 28)
	label.no_depth_test = true
