class_name ItemDB
extends RefCounted
## Objets du jeu, lus dans data/items.json (fichier modifiable à la main, voir
## docs/OBJETS.md) : équipement (section « reliques » : bonus aux caractéristiques, appliqués seulement quand
## l'objet est équipé dans son emplacement, comme dans un MMO), consommables (potion, chambre),
## monnaie (médiators) et objets de quête. Si le fichier est absent ou abîmé, les valeurs
## par défaut ci-dessous sont utilisées.

const DATA_PATH := "res://data/items.json"

const RARITY_COLORS := {
	"commun": Color(0.85, 0.85, 0.8),
	"peu commun": Color(0.45, 0.9, 0.45),
	"rare": Color(0.4, 0.65, 1.0),
	"épique": Color(0.8, 0.45, 1.0),
}

## Emplacements d'équipement, dans l'ordre de la fiche de personnage (clé "emplacement" de chaque objet).
const SLOTS := {
	"guitare": "Guitare", "tete": "Tête", "cou": "Cou", "torse": "Torse", "poignets": "Poignets", "ceinture": "Ceinture", "pieds": "Pieds",
	"anneau": "Anneau", "talisman": "Talisman", "mediator": "Médiator", "cordes": "Cordes", "grimoire": "Grimoire",
}
const DEFAULT_SLOT := "talisman"

## Valeurs de secours (identiques au fichier livré).
const DEFAULT_RELICS := {
	"mediator_os": {"nom": "Médiator en os", "desc": "Taillé dans la phalange d'un squelette trop bavard.",
		"bonus": {"DEX": 1}, "rarete": "commun", "butin": true, "emplacement": "mediator"},
	"ceinture_cloutee": {"nom": "Ceinture cloutée", "desc": "Trente-deux clous, trente-deux raisons de ne pas mourir.",
		"bonus": {"CON": 1}, "rarete": "commun", "butin": true, "emplacement": "ceinture"},
	"bracelet_force": {"nom": "Bracelet à pointes", "desc": "Pour frapper plus fort et accessoirement faire peur.",
		"bonus": {"FOR": 1}, "rarete": "commun", "butin": true, "emplacement": "poignets"},
	"cordes_dragon": {"nom": "Cordes en boyau de dragon", "desc": "Elles vibrent toutes seules quand un mort-vivant approche.",
		"bonus": {"CHA": 1}, "rarete": "peu commun", "butin": true, "emplacement": "cordes"},
	"grimoire_tablatures": {"nom": "Grimoire de tablatures", "desc": "Des accords interdits notés à l'encre de seiche.",
		"bonus": {"INT": 1, "SAG": 1}, "rarete": "peu commun", "butin": true, "emplacement": "grimoire"},
	"pendentif_plume": {"nom": "Pendentif de plume de hibours", "desc": "Offert par Gérald. Porte bonheur, et un peu d'odeur de grange.",
		"bonus": {"CHA": 1, "SAG": 1}, "rarete": "rare", "butin": false, "emplacement": "cou"},
	"couronne_gloubah": {"nom": "Couronne de nénuphar de Gloubah", "desc": "Encore humide. Toujours humide. Pour l'éternité, humide.",
		"bonus": {"CON": 2, "CHA": 1}, "rarete": "épique", "butin": false, "emplacement": "tete"},
	"portrait_aieule": {"nom": "Portrait de l'arrière-arrière-arrière-grand-mère de Gérald", "desc": "Une dame moustachue qui fixe l'âme de quiconque la regarde.",
		"bonus": {"SAG": 1, "CHA": 1}, "rarete": "rare", "butin": false, "emplacement": "talisman"},
	"perfecto_cloute": {"nom": "Perfecto clouté", "desc": "Cuir noir, clous d'acier et une odeur tenace de bière renversée.",
		"bonus": {"CON": 1}, "rarete": "commun", "butin": true, "emplacement": "torse"},
	"bottes_roadie": {"nom": "Bottes de roadie", "desc": "Coquées pour survivre aux pieds de micro et aux pogos.",
		"bonus": {"DEX": 1}, "rarete": "commun", "butin": true, "emplacement": "pieds"},
	"chevaliere_bouc": {"nom": "Chevalière tête de bouc", "desc": "Argent terni. Le bouc vous fait un clin d'œil quand vous jouez faux.",
		"bonus": {"CHA": 1, "INT": 1}, "rarete": "peu commun", "butin": true, "emplacement": "anneau"},
}

static var _data := {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = null
		if FileAccess.file_exists(DATA_PATH):
			parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		if parsed is Dictionary:
			_data = parsed
		else:
			push_warning("data/items.json illisible : objets par défaut.")
			_data = {"reliques": DEFAULT_RELICS}
	return _data


## Recharge le fichier (après une modification pendant que le jeu tourne).
static func reload() -> void:
	_data = {}
	data()


# --- Reliques ---------------------------------------------------------------------------

static func relics() -> Dictionary:
	var r: Dictionary = data().get("reliques", DEFAULT_RELICS)
	return r


## Objet au format utilisé par le jeu : name, desc, bonus, rarity, slot (emplacement d'équipement).
static func get_item(id: String) -> Dictionary:
	var raw: Dictionary = relics().get(id, {})
	if raw.is_empty():
		return {}
	return {
		"name": str(raw.get("nom", id)),
		"desc": str(raw.get("desc", "")),
		"bonus": raw.get("bonus", {}),
		"rarity": str(raw.get("rarete", "commun")),
		"enabled": bool(raw.get("actif", true)),
		"slot": slot_of(id),
	}


## Emplacement d'équipement d'un objet (talisman si le fichier n'en donne pas, ou un emplacement inconnu).
static func slot_of(id: String) -> String:
	var slot := str((relics().get(id, {}) as Dictionary).get("emplacement", DEFAULT_SLOT))
	return slot if SLOTS.has(slot) else DEFAULT_SLOT


static func slot_name(slot: String) -> String:
	return str(SLOTS.get(slot, slot))


## Équipements qui peuvent tomber sur les ennemis et dans les coffres.
static func common_drops() -> Array[String]:
	var out: Array[String] = []
	for id: String in relics():
		var raw: Dictionary = relics()[id]
		if bool(raw.get("butin", false)) and bool(raw.get("actif", true)):
			out.append(id)
	return out


static func color_of(id: String) -> Color:
	var rarity: String = get_item(id).get("rarity", "commun")
	var c: Color = RARITY_COLORS.get(rarity, Color.WHITE)
	return c


static func bonus_text(id: String) -> String:
	var parts: PackedStringArray = []
	if not bool(get_item(id).get("enabled", true)):
		return "désactivé"
	var bonus: Dictionary = get_item(id).get("bonus", {})
	for ab: String in bonus:
		parts.append("+%d %s" % [int(bonus[ab]), ab])
	return ", ".join(parts)


## Bonus réellement appliqués (une relique désactivée ne donne plus rien).
static func active_bonus(id: String) -> Dictionary:
	var item := get_item(id)
	if not bool(item.get("enabled", true)):
		return {}
	var b: Dictionary = item.get("bonus", {})
	return b


# --- Consommables et monnaie ---------------------------------------------------------------

static func _consumable(id: String, key: String, fallback: float) -> float:
	var c: Dictionary = data().get("consommables", {}).get(id, {})
	return float(c.get(key, fallback))


static func potion_price() -> int:
	return int(_consumable("potion_soin", "prix", 25))


static func potion_heal_ratio() -> float:
	return _consumable("potion_soin", "soin", 0.4)


static func potion_drop_chance() -> float:
	return _consumable("potion_soin", "chance_butin", 0.12)


static func starting_potions() -> int:
	return int(_consumable("potion_soin", "depart", 2))


static func rest_price() -> int:
	return int(_consumable("chambre", "prix", 10))


static func _money(key: String, fallback: float) -> float:
	var m: Dictionary = data().get("monnaie", {})
	return float(m.get(key, fallback))


static func money_drop_chance() -> float:
	return _money("chance_butin", 0.45)


static func death_money_penalty() -> float:
	return _money("perte_a_la_mort", 0.25)


static func starting_money() -> int:
	return int(_money("depart", 30))


## Chance qu'un ennemi lâche une relique (réglée dans Balance).
static func relic_drop_chance() -> float:
	return Balance.DROP_ITEM_CHANCE


## Prix auquel Grokk rachète une relique (selon sa rareté, data/items.json : monnaie.vente) ; on peut la lui
## racheter au même prix.
static func sell_price(id: String) -> int:
	var prices: Dictionary = (data().get("monnaie", {}) as Dictionary).get("vente", {})
	var fallback := {"commun": 8, "peu commun": 15, "rare": 30, "épique": 60}
	var rarity := str(get_item(id).get("rarity", "commun"))
	return int(prices.get(rarity, fallback.get(rarity, 8)))


# --- Objets de quête -----------------------------------------------------------------------

## Objet de quête (section « quete » de data/items.json) : {nom, desc}.
static func quest_item(id: String) -> Dictionary:
	var q: Dictionary = (data().get("quete", {}) as Dictionary).get(id, {})
	return q


# --- Guitares -------------------------------------------------------------------------------

## Guitare des héros sans guitare équipée (voir docs/GUITARE.md).
const DEFAULT_GUITAR := "res://assets/models/guitare/guitare_heros.glb"


## Modèle 3D d'une guitare (clé « modele » de l'objet) ; la guitare des héros par défaut.
static func guitar_model(id: String) -> String:
	var path := str((relics().get(id, {}) as Dictionary).get("modele", ""))
	return path if not path.is_empty() and ResourceLoader.exists(path) else DEFAULT_GUITAR


## Variante du Riff électrique que donne une guitare (clé « sort_riff ») : « black_metal » (Batguitare : Riff black
## metal, trait brumeux violet et vent brumeux), sinon « » (Riff électrique).
static func riff_variant(id: String) -> String:
	return str((relics().get(id, {}) as Dictionary).get("sort_riff", ""))
