@tool
class_name TavernMarker
extends Node3D
## Objet placé à la main dans la taverne (scène TavernMap) : mobilier, décor, ou point du jeu (arrivée du
## héros, portails, escaliers, PNJ, mannequins...). Le mobilier se construit lui-même (dans l'éditeur et en
## jeu) ; les points du jeu ne sont que des repères dans l'éditeur, que tavern.gd utilise.
## Repère : +Z = devant (côté d'où l'on arrive) ; tourner l'objet le réoriente. Taille d'un tonneau,
## d'une caisse... : échelle uniforme du nœud.

enum Kind { TABLE, CHAISE, COMPTOIR, ETAGERE, CHEMINEE, TONNEAU, CAISSE, PILIER_LANTERNE, LANTERNE, TABLEAU,
	BANNIERE, TAPIS, LIT, CHEVET, MALLE, GRIMOIRES, ORBE, DORMEUR, FANTOME, RATELIER, TORCHE, ECRITEAU,
	APPARITION, CERCLE_RUNES, PORTAIL_BLEU, PORTES, ESCALIER_MONTANT, ESCALIER_DESCENDANT, ARRIVEE,
	ZONE_ENTRAINEMENT, MANNEQUIN, MANNEQUIN_AMI, PORTAIL_DEMONIAQUE, PNJ }
const NAMES := ["Table ronde", "Chaise", "Comptoir", "Étagère à bouteilles", "Cheminée", "Tonneau", "Caisse",
	"Pilier et lanterne", "Lanterne", "Tableau des quêtes", "Bannière", "Tapis", "Lit", "Table de chevet", "Malle",
	"Grimoires", "Orbe magique", "Dormeur", "Fantôme", "Râtelier à bouteilles", "Torche", "Écriteau",
	"Arrivée du héros", "Cercle de runes", "Portail bleu", "Portes d'entrée", "Escalier qui monte",
	"Escalier qui descend", "Arrivée d'escalier", "Zone d'entraînement", "Mannequin", "Mannequin allié",
	"Portail démoniaque", "PNJ"]
const NPCS := ["brunhilde", "zarathos", "inconnue", "gerald"]
const NPC_NAMES := ["Tavernier (Grokk)", "Zarathos", "L'Inconnue", "Gérald"]
## Propriétés affichées dans l'Inspecteur selon le type (les autres sont masquées).
const FIELDS := {
	Kind.TABLE: ["option"], Kind.COMPTOIR: ["size"], Kind.ETAGERE: ["size"], Kind.TAPIS: ["size", "color"],
	Kind.LIT: ["variant", "option"], Kind.DORMEUR: ["variant"], Kind.ECRITEAU: ["text", "color"],
	Kind.ESCALIER_MONTANT: ["variant", "text", "destination"], Kind.ESCALIER_DESCENDANT: ["text", "destination"],
	Kind.ARRIVEE: ["text"], Kind.ZONE_ENTRAINEMENT: ["size"], Kind.PNJ: ["npc"],
}
const OPTION_HINTS := {Kind.TABLE: "Place libre pour le fauteuil roulant de Katrkar", Kind.LIT: "Lit loué par le héros (on s'y repose)"}

@export_enum("Table ronde", "Chaise", "Comptoir", "Étagère à bouteilles", "Cheminée", "Tonneau", "Caisse",
	"Pilier et lanterne", "Lanterne", "Tableau des quêtes", "Bannière", "Tapis", "Lit", "Table de chevet", "Malle",
	"Grimoires", "Orbe magique", "Dormeur", "Fantôme", "Râtelier à bouteilles", "Torche", "Écriteau",
	"Arrivée du héros", "Cercle de runes", "Portail bleu", "Portes d'entrée", "Escalier qui monte",
	"Escalier qui descend", "Arrivée d'escalier", "Zone d'entraînement", "Mannequin", "Mannequin allié",
	"Portail démoniaque", "PNJ") var kind := 0:
	set(value):
		kind = value
		notify_property_list_changed()
		_refresh()
## Longueur (comptoir, étagère) ou largeur × profondeur (tapis, zone d'entraînement), en mètres.
@export var size := Vector2(4.0, 3.0):
	set(value):
		size = value
		_refresh()
## Couleur de la couverture (lit, dormeur : 0 à 3) ou nombre de marches (escalier qui monte).
@export var variant := 0:
	set(value):
		variant = value
		_refresh()
## Table : place pour le fauteuil de Katrkar ; lit : lit loué par le héros.
@export var option := false:
	set(value):
		option = value
		_refresh()
## Texte : écriteau, invite de l'escalier (« Monter à l'étage »), nom du lieu d'arrivée.
@export var text := "":
	set(value):
		text = value
		_refresh()
## Couleur du tapis ou de l'écriteau.
@export var color := Color(0.3, 0.07, 0.06):
	set(value):
		color = value
		_refresh()
## Escalier : arrivée (un marqueur « Arrivée d'escalier »).
@export var destination: NodePath
@export_enum("Tavernier (Grokk)", "Zarathos", "L'Inconnue", "Gérald") var npc := 0:
	set(value):
		npc = value
		_refresh()

## En jeu : places autour d'une table [{pos, yaw, chair}] (repère du monde, chaises déplaçables) et
## place du fauteuil roulant ; gonds des portes d'entrée.
var seats: Array[Dictionary] = []
var wheelchair_seat := {}
var hinges: Array[Node3D] = []
var _built: Node3D


func _ready() -> void:
	_refresh()


func _validate_property(property: Dictionary) -> void:
	var name := str(property["name"])
	if name in ["size", "variant", "option", "text", "color", "destination", "npc"]:
		if not name in (FIELDS.get(kind, []) as Array):
			property["usage"] = PROPERTY_USAGE_NO_EDITOR | PROPERTY_USAGE_STORAGE


func _refresh() -> void:
	if is_inside_tree():
		build(not Engine.is_editor_hint())


## Construit l'objet : en jeu (`runtime`) avec ses collisions, sinon l'aperçu de l'éditeur (repères
## visibles pour les points du jeu, rien n'est enregistré dans la scène).
func build(runtime: bool) -> void:
	if _built != null:
		_built.queue_free()
	_built = Node3D.new()
	add_child(_built, false, Node.INTERNAL_MODE_FRONT)
	var p := _built
	seats.clear()
	wheelchair_seat = {}
	hinges.clear()
	match kind:
		Kind.TABLE:
			TavernDecor.table(p, runtime)
			var all := TavernDecor.table_seats()
			for k in all.size():
				var s: Dictionary = all[k]
				var pos: Vector3 = s["pos"]
				if option and k == 1:
					wheelchair_seat = {"pos": global_transform * (pos + (s["dir"] as Vector3) * 0.1),
						"yaw": global_rotation.y + float(s["yaw"])}
					if not runtime:
						Visuals.label(p, "Fauteuil de Katrkar", pos + Vector3(0, 1.0, 0), Color(0.9, 0.7, 0.4), 22).no_depth_test = true
					continue
				var chair := TavernDecor.chair(p, pos, float(s["yaw"]))
				if runtime:
					# Les clients reculent leur chaise : elle se déplace dans le repère du monde.
					var t := chair.global_transform
					chair.top_level = true
					chair.global_transform = t
					seats.append({"pos": t.origin, "yaw": global_rotation.y + float(s["yaw"]), "chair": chair})
		Kind.CHAISE:
			TavernDecor.chair(p, Vector3.ZERO, 0.0)
		Kind.COMPTOIR:
			TavernDecor.counter(p, size.x, runtime)
			if not runtime:
				for s in TavernDecor.bar_spots(size.x):
					Visuals.cylinder(p, 0.25, 0.25, 0.02, s + Vector3(0, 0.02, 0), Visuals.glow_mat(Color(0.3, 0.8, 1.0), 0.6))
		Kind.ETAGERE:
			TavernDecor.shelves(p, size.x)
		Kind.CHEMINEE:
			TavernDecor.fireplace(p, runtime)
		Kind.TONNEAU:
			TavernDecor.barrel(p, runtime)
		Kind.CAISSE:
			TavernDecor.crate(p, runtime)
		Kind.PILIER_LANTERNE:
			TavernDecor.pillar_lantern(p, runtime)
		Kind.LANTERNE:
			TavernDecor.lantern(p)
		Kind.TABLEAU:
			TavernDecor.quest_board(p)
		Kind.BANNIERE:
			TavernDecor.banner(p)
		Kind.TAPIS:
			TavernDecor.rug(p, size, color)
		Kind.LIT:
			TavernDecor.bed(p, variant, runtime)
			if option and not runtime:
				Visuals.label(p, "Lit du héros (loué)", Vector3(0, 1.4, 0), Color(1.0, 0.85, 0.4), 24).no_depth_test = true
		Kind.CHEVET:
			TavernDecor.nightstand(p, runtime)
		Kind.MALLE:
			TavernDecor.trunk(p, runtime)
		Kind.GRIMOIRES:
			TavernDecor.books(p)
		Kind.ORBE:
			TavernDecor.orb(p)
		Kind.DORMEUR:
			TavernDecor.sleeper(p, variant)
		Kind.FANTOME:
			TavernDecor.ghost(p)
		Kind.RATELIER:
			TavernDecor.rack(p, runtime)
		Kind.TORCHE:
			TavernDecor.torch(p)
		Kind.ECRITEAU:
			Visuals.label(p, text, Vector3.ZERO, color, 26)
		Kind.CERCLE_RUNES:
			TavernDecor.rune_circle(p)
		Kind.PORTES:
			hinges = TavernDecor.front_doors(p)
		Kind.ESCALIER_MONTANT:
			TavernDecor.stairs_up(p, variant if variant > 0 else 10, runtime)
		Kind.ESCALIER_DESCENDANT:
			TavernDecor.trapdoor(p)
	if not runtime:
		_editor_preview(p)


## Repères des points du jeu, visibles seulement dans l'éditeur.
func _editor_preview(p: Node3D) -> void:
	var cyan := Visuals.glow_mat(Color(0.3, 0.8, 1.0), 0.8)
	var title := str(NAMES[kind])
	match kind:
		Kind.APPARITION, Kind.PORTAIL_BLEU, Kind.ARRIVEE:
			var c := {Kind.APPARITION: Color(0.3, 1.0, 0.4), Kind.PORTAIL_BLEU: Color(0.3, 0.6, 1.0), Kind.ARRIVEE: Color(1.0, 0.85, 0.3)}
			Visuals.cylinder(p, 0.5, 0.5, 0.04, Vector3(0, 0.03, 0), Visuals.glow_mat(c[kind], 1.0), Vector3.ZERO, 16)
			Visuals.box(p, Vector3(0.08, 0.03, 0.6), Vector3(0, 0.05, 0.45), Visuals.glow_mat(c[kind], 1.0))
			if kind == Kind.ARRIVEE and not text.is_empty():
				title += " : " + text
		Kind.ESCALIER_MONTANT, Kind.ESCALIER_DESCENDANT:
			Visuals.cylinder(p, 0.35, 0.35, 0.04, Vector3(0, 0.03, 0), cyan, Vector3.ZERO, 16)
			var dest := get_node_or_null(destination) as TavernMarker
			title += "\n%s\n→ %s" % [text, dest.text if dest != null else "(aucune arrivée !)"]
		Kind.ZONE_ENTRAINEMENT:
			var zone := Visuals.box(p, Vector3(size.x, 0.05, size.y), Vector3(0, 0.03, 0), Visuals.transparent_mat(Color(1.0, 0.6, 0.2, 0.12)))
			zone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		Kind.MANNEQUIN, Kind.MANNEQUIN_AMI:
			var sack := Visuals.mat(Color(0.75, 0.65, 0.4) if kind == Kind.MANNEQUIN else Color(0.5, 0.75, 0.5))
			Visuals.cylinder(p, 0.06, 0.06, 1.0, Vector3(0, 0.5, 0), TavernDecor.mat("wood_dark"))
			Visuals.capsule(p, 0.28, 0.9, Vector3(0, 1.3, 0), sack)
			Visuals.sphere(p, 0.2, Vector3(0, 1.95, 0), sack)
		Kind.PORTAIL_DEMONIAQUE:
			Visuals.torus(p, 1.0, 1.2, Vector3(0, 1.4, 0), Visuals.glow_mat(Color(1.0, 0.2, 0.1), 2.0), Vector3(90, 0, 0))
		Kind.PNJ:
			var colors := [Color(0.5, 0.15, 0.12), Color(0.2, 0.15, 0.4), Color(0.08, 0.06, 0.08), Color(0.45, 0.35, 0.2)]
			var body := Visuals.mat(colors[npc])
			Visuals.capsule(p, 0.25, 1.4, Vector3(0, 0.7, 0), body)
			Visuals.sphere(p, 0.18, Vector3(0, 1.62, 0), Visuals.mat(Color(0.85, 0.66, 0.54)))
			Visuals.box(p, Vector3(0.06, 0.03, 0.5), Vector3(0, 0.03, 0.4), cyan)
			title = str(NPC_NAMES[npc])
	var label_y := {Kind.LANTERNE: 0.5, Kind.ORBE: 0.4, Kind.TORCHE: 0.5, Kind.BANNIERE: 1.0, Kind.GRIMOIRES: 0.6}
	if kind != Kind.ECRITEAU:
		Visuals.label(p, title, Vector3(0, float(label_y.get(kind, 2.3)), 0), Color(1.0, 0.9, 0.6), 24).no_depth_test = true


## Places au comptoir, repère du monde.
func bar_spots() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for s in TavernDecor.bar_spots(size.x):
		out.append(global_transform * s)
	return out


## Point d'arrivée de l'escalier (null s'il n'est pas relié).
func destination_marker() -> TavernMarker:
	return get_node_or_null(destination) as TavernMarker


## Zone d'entraînement : `pos` est-il dedans (repère du monde) ?
func contains(pos: Vector3) -> bool:
	var local := global_transform.affine_inverse() * pos
	return absf(local.x) <= size.x * 0.5 and absf(local.z) <= size.y * 0.5
