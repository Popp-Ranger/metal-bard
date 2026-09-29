class_name RaceDB
extends RefCounted
## Races jouables, options d'apparence et bonus raciaux (façon D&D).

const RACES := {
	"humain": {
		"name": "Humain", "height": 1.8, "width": 1.0,
		"skin": Color(0.8, 0.63, 0.52), "eyes": Color(0.6, 0.85, 1.0),
		"bonus": {"FOR": 1, "DEX": 1, "CON": 1, "INT": 1, "SAG": 1, "CHA": 1},
		"trait": "Polyvalent : +10 % d'expérience.",
		"horns": false, "tusks": false,
	},
	"squelette": {
		"name": "Squelette", "height": 1.8, "width": 0.85,
		"skin": Color(0.86, 0.82, 0.7), "eyes": Color(1.0, 0.25, 0.1),
		"bonus": {"DEX": 2, "CON": 1},
		"trait": "Un des leurs : les squelettes ennemis ne vous repèrent qu'à 3 m (au lieu de 4).",
		"horns": false, "tusks": false,
	},
	"orc": {
		"name": "Orc", "height": 2.0, "width": 1.15,
		"skin": Color(0.36, 0.5, 0.25), "eyes": Color(1.0, 0.8, 0.2),
		"bonus": {"FOR": 2, "CON": 1},
		"trait": "Rage sanguinaire : +2 aux dégâts du coup de guitare.",
		"horns": false, "tusks": true,
	},
	"troll": {
		"name": "Troll", "height": 2.2, "width": 1.1,
		"skin": Color(0.3, 0.52, 0.56), "eyes": Color(1.0, 0.35, 0.3),
		"bonus": {"CON": 2, "FOR": 1},
		"trait": "Régénération : récupère 1 PV toutes les 2 secondes.",
		"horns": false, "tusks": true,
	},
	"ogre": {
		"name": "Ogre", "height": 2.5, "width": 1.45,
		"skin": Color(0.62, 0.55, 0.42), "eyes": Color(0.95, 0.75, 0.2),
		"bonus": {"FOR": 2, "CON": 2, "DEX": -1},
		"trait": "Colosse : +15 points de vie maximum.",
		"horns": false, "tusks": true,
	},
	"demon": {
		"name": "Démon", "height": 1.8, "width": 1.0,
		"skin": Color(0.62, 0.14, 0.12), "eyes": Color(1.0, 0.6, 0.1),
		"bonus": {"CHA": 2, "INT": 1},
		"trait": "Sang infernal : +10 % de dégâts des sorts.",
		"horns": true, "tusks": false,
	},
}
const RACE_ORDER := ["humain", "squelette", "orc", "troll", "ogre", "demon"]

const HORNS := ["Cornes de bélier", "Cornes de taureau", "Cornes infernales"]
const TUSKS := ["Petites défenses", "Grandes défenses", "Défenses brisées"]
const BEARDS := ["Barbe courte", "Longue barbe tressée", "Bouc"]
const HAIRSTYLES := ["Tresses", "Queue de cheval", "Longs lâchés", "Glam-metal"]
const HAIR_COLORS := [Color(0.42, 0.11, 0.05), Color(0.05, 0.04, 0.04), Color(0.9, 0.82, 0.55),
	Color(0.85, 0.85, 0.88), Color(0.4, 0.15, 0.55)]
const HAIR_COLOR_NAMES := ["Roux sombre", "Noir corbeau", "Blond platine", "Blanc d'argent", "Violet"]

const DEFAULT_APPEARANCE := {
	"sex": "m", "race": "humain", "horns": 0, "tusks": 0, "beard": 0, "hair": 2, "hair_color": 0,
}


static func get_race(id: String) -> Dictionary:
	var r: Dictionary = RACES.get(id, RACES["humain"])
	return r


static func bonus(race_id: String, ability: String) -> int:
	var b: Dictionary = get_race(race_id).get("bonus", {})
	return int(b.get(ability, 0))


static func can_have_beard(appearance: Dictionary) -> bool:
	return appearance.get("sex", "m") == "m" and appearance.get("race", "humain") != "squelette"


## Libellé « Barde humain », « Barde orque »... accordé au sexe.
static func title(appearance: Dictionary) -> String:
	var female: bool = appearance.get("sex", "m") == "f"
	match str(appearance.get("race", "humain")):
		"squelette":
			return "Barde squelette"
		"orc":
			return "Barde orque" if female else "Barde orc"
		"troll":
			return "Barde trollesse" if female else "Barde troll"
		"ogre":
			return "Barde ogresse" if female else "Barde ogre"
		"demon":
			return "Barde démone" if female else "Barde démon"
	return "Barde humaine" if female else "Barde humain"
