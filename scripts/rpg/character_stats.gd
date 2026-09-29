class_name CharacterStats
extends RefCounted
## Fiche de personnage selon les règles de D&D 5e (version française).

const ABILITIES := ["FOR", "DEX", "CON", "INT", "SAG", "CHA"]
const NAMES := {
	"FOR": "Force",
	"DEX": "Dextérité",
	"CON": "Constitution",
	"INT": "Intelligence",
	"SAG": "Sagesse",
	"CHA": "Charisme",
}
const DESCRIPTIONS := {
	"FOR": "Dégâts et précision des coups de luth.",
	"DEX": "Classe d'armure (esquive).",
	"CON": "Points de vie.",
	"INT": "Réduit le temps de recharge des sorts (4 % par point de mod.).",
	"SAG": "Régénération des décibels (+15 % par point de mod.).",
	"CHA": "Puissance des sorts, DD des jets de sauvegarde, réserve de décibels.",
}

## Répartition de départ d'un barde (achat de points D&D) : le Charisme est roi.
var abilities := {"FOR": 12, "DEX": 14, "CON": 13, "INT": 10, "SAG": 8, "CHA": 16}
var level := 1
var xp := 0
var unspent_points := 0


## Modificateur D&D : (valeur - 10) / 2, arrondi à l'inférieur. 16 → +3, 8 → -1.
static func modifier_for(score: int) -> int:
	return floori((score - 10) / 2.0)


func base(ability: String) -> int:
	var value: int = abilities.get(ability, 10)
	return value


func to_dict() -> Dictionary:
	return {"abilities": abilities.duplicate(), "level": level, "xp": xp, "points": unspent_points}


func from_dict(data: Dictionary) -> void:
	var saved: Dictionary = data.get("abilities", {})
	for ab: String in ABILITIES:
		abilities[ab] = int(saved.get(ab, abilities[ab]))
	level = int(data.get("level", 1))
	xp = int(data.get("xp", 0))
	unspent_points = int(data.get("points", 0))
