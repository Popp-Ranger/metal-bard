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
const BEARDS := ["Barbe courte", "Longue barbe tressée", "Bouc", "Rasé de près"]
const HAIRSTYLES := ["Tresses", "Queue de cheval", "Longs lâchés", "Glam-metal"]
const HAIR_COLORS := [Color(0.42, 0.11, 0.05), Color(0.05, 0.04, 0.04), Color(0.9, 0.82, 0.55),
	Color(0.85, 0.85, 0.88), Color(0.4, 0.15, 0.55), Color(0.95, 0.42, 0.08), Color(0.24, 0.14, 0.07)]
const HAIR_COLOR_NAMES := ["Roux sombre", "Noir corbeau", "Blond platine", "Blanc d'argent", "Violet", "Roux flamboyant", "Châtain"]

const DEFAULT_APPEARANCE := {
	"sex": "m", "race": "humain", "horns": 0, "tusks": 0, "beard": 0, "hair": 2, "hair_color": 0,
	"preset": "", # héros prédéfini ("riffald") ou personnage personnalisé ("")
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


const MALE_NAMES := ["Hrothgar", "Ulrich", "Dagmar", "Grimm", "Lemmy", "Bjorn", "Vargus", "Otto", "Snorri", "Kael", "Mordak", "Tobias"]
const FEMALE_NAMES := ["Ysolde", "Morgane", "Brenna", "Nyx", "Helga", "Lilith", "Sigrun", "Rhiannon", "Yrsa", "Doro", "Tarja", "Maude"]


## Apparence aléatoire, tirée avec les mêmes options que la création de personnage.
static func random_appearance(sex: String = "") -> Dictionary:
	return {
		"sex": sex if not sex.is_empty() else ["m", "f"].pick_random(),
		"race": RACE_ORDER.pick_random(),
		"horns": randi_range(0, HORNS.size() - 1),
		"tusks": randi_range(0, TUSKS.size() - 1),
		"beard": randi_range(0, BEARDS.size() - 1),
		"hair": randi_range(0, HAIRSTYLES.size() - 1),
		"hair_color": randi_range(0, HAIR_COLORS.size() - 1),
	}


## Héros prédéfinis proposés à la création de personnage, dans l'ordre de PRESET_ORDER.
##  - "height" : taille réelle du modèle (m), affichée à la création et utilisée pour les étiquettes ;
##  - "scale" : agrandissement du modèle en jeu (1 par défaut), pour atteindre "height" ;
##  - "model" : modèle Blender à squelette (17 os) contenant les animations Mixamo (voir docs/ANIMATIONS.md) ;
##  - "rig" : réglages de la guitare pour ce modèle (voir HeroAnimator) : "guitar_scale" (taille de la
##    guitare, à l'échelle des mains), "play_pick" (point de grattage, repère du squelette au repos) et
##    "back_pos" (guitare dans le dos).
## Riffald suit la planche docs/concept/riffald_turnaround.jpg (voir docs/RIFFALD.md) ; l'héroïne est le
## modèle fourni par Ulysse (art/persof1, voir docs/PERSOF1.md), le démon aussi (art/demon, voir docs/DEMON.md).
const PRESETS := {
	"riffald": {
		"name": "Riffald",
		"title": "Riffald, le barde de la Lune de Sang",
		"desc": "Humain, longue crinière rousse et bouclée, cuir noir clouté, épaulières à pointes, cape bordeaux en lambeaux, gemme rouge au col, bottes cloutées et mitaines. Armé de sa Flying V.",
		"appearance": {"sex": "m", "race": "humain", "horns": 0, "tusks": 0, "beard": 3, "hair": 3, "hair_color": 5, "preset": "riffald"},
		"model": "res://assets/models/riffald/riffald.glb",
		"height": 1.84,
		"rig": {"guitar_scale": 1.3, "play_pick": Vector3(-0.15, 0.9, 0.16), "back_pos": Vector3(0.0, 1.15, -0.25)},
	},
	"persof1": {
		"name": "Valkyriff",
		"title": "Valkyriff, la walkyrie du riff",
		"desc": "Humaine, longues tresses rousses, cuir sombre et ventre nu, épaulière à pointes, brassards cloutés, genouillères d'acier, cape bordeaux en lambeaux. Armée de la même Flying V.",
		"appearance": {"sex": "f", "race": "humain", "horns": 0, "tusks": 0, "beard": 0, "hair": 3, "hair_color": 5, "preset": "persof1"},
		"model": "res://assets/models/persof1/persof1.glb",
		"height": 1.84,
		"scale": 1.84 / 1.74, # modèle de 1,74 m agrandi en jeu (son .blend, retouché à la main, reste tel quel)
		"rig": {"guitar_scale": 1.1, "play_pick": Vector3(-0.11, 0.86, 0.16), "back_pos": Vector3(0.0, 1.1, -0.2)},
	},
	"demon": {
		"name": "Belzeluth",
		"title": "Belzeluth, le démon du power chord",
		"desc": "Démon à la peau écarlate, cornes de bélier et longue crinière noire, yeux de braise, épaulières et brassards à pointes, cuir noir et genouillères d'acier, cape bordeaux. Armé de la même Flying V.",
		"appearance": {"sex": "m", "race": "demon", "horns": 0, "tusks": 0, "beard": 0, "hair": 3, "hair_color": 0, "preset": "demon"},
		"model": "res://assets/models/demon/demon.glb",
		"height": 1.95,
		"rig": {"guitar_scale": 1.2, "play_pick": Vector3(-0.12, 0.93, 0.21), "back_pos": Vector3(0.0, 1.2, -0.27)},
	},
	"hella": {
		"name": "Hella",
		"title": "Hella, la furie du larsen",
		"desc": "Humaine, crinière rousse flamboyante et tresses, haut déchiré et ventre nu, épaulières et brassards à pointes, genouillères d'acier, cape bordeaux en lambeaux. Armée de la même Flying V.",
		"appearance": {"sex": "f", "race": "humain", "horns": 0, "tusks": 0, "beard": 0, "hair": 3, "hair_color": 5, "preset": "hella"},
		"model": "res://assets/models/hella/hella.glb",
		"height": 1.75,
		"rig": {"guitar_scale": 1.1, "play_pick": Vector3(-0.11, 0.86, 0.16), "back_pos": Vector3(0.0, 1.1, -0.22)},
	},
	"twin": {
		"name": "Riffald's Twin",
		"title": "Riffald's Twin, le double de la Lune de Sang",
		"desc": "Humain, le jumeau de Riffald : crinière rousse flamboyante, cuir noir et sangles croisées, épaulières à pointes, gemme rouge au col, genouillères d'acier, bottes à boucles, cape bordeaux en lambeaux. Armé de la même Flying V.",
		"appearance": {"sex": "m", "race": "humain", "horns": 0, "tusks": 0, "beard": 0, "hair": 3, "hair_color": 5, "preset": "twin"},
		"model": "res://assets/models/twin/twin.glb",
		"height": 1.84,
		"rig": {"guitar_scale": 1.3, "play_pick": Vector3(-0.15, 0.9, 0.16), "back_pos": Vector3(0.0, 1.15, -0.27)},
	},
}
const PRESET_ORDER := ["riffald", "persof1", "demon", "hella", "twin"]


## Modèle 3D d'un héros prédéfini ("" si personnage personnalisé ou sans modèle).
static func preset_model(id: String) -> String:
	return str((PRESETS.get(id, {}) as Dictionary).get("model", ""))


## Taille d'un héros : celle de son modèle s'il est prédéfini, sinon celle de sa race.
static func hero_height(appearance: Dictionary) -> float:
	var p: Dictionary = PRESETS.get(str(appearance.get("preset", "")), {})
	return float(p.get("height", get_race(str(appearance.get("race", "humain"))).get("height", 1.8)))


## Réglages de la guitare d'un héros prédéfini (voir PRESETS).
static func preset_rig(id: String) -> Dictionary:
	return (PRESETS.get(id, {}) as Dictionary).get("rig", {})


static func preset_appearance(id: String) -> Dictionary:
	var base: Dictionary = DEFAULT_APPEARANCE.duplicate()
	var p: Dictionary = PRESETS.get(id, {})
	base.merge(p.get("appearance", {}), true)
	return base
