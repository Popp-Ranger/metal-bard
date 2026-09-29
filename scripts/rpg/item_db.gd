class_name ItemDB
extends RefCounted
## Objets et reliques. Chaque relique possédée ajoute ses bonus aux caractéristiques.

const RARITY_COLORS := {
	"commun": Color(0.85, 0.85, 0.8),
	"peu commun": Color(0.45, 0.9, 0.45),
	"rare": Color(0.4, 0.65, 1.0),
	"épique": Color(0.8, 0.45, 1.0),
}

const ITEMS := {
	"mediator_os": {
		"name": "Médiator en os",
		"desc": "Taillé dans la phalange d'un squelette trop bavard.",
		"bonus": {"DEX": 1},
		"rarity": "commun",
	},
	"ceinture_cloutee": {
		"name": "Ceinture cloutée",
		"desc": "Trente-deux clous, trente-deux raisons de ne pas mourir.",
		"bonus": {"CON": 1},
		"rarity": "commun",
	},
	"bracelet_force": {
		"name": "Bracelet à pointes",
		"desc": "Pour frapper plus fort et accessoirement faire peur.",
		"bonus": {"FOR": 1},
		"rarity": "commun",
	},
	"cordes_dragon": {
		"name": "Cordes en boyau de dragon",
		"desc": "Elles vibrent toutes seules quand un mort-vivant approche.",
		"bonus": {"CHA": 1},
		"rarity": "peu commun",
	},
	"grimoire_tablatures": {
		"name": "Grimoire de tablatures",
		"desc": "Des accords interdits notés à l'encre de seiche.",
		"bonus": {"INT": 1, "SAG": 1},
		"rarity": "peu commun",
	},
	"pendentif_plume": {
		"name": "Pendentif de plume d'ours-hibou",
		"desc": "Offert par Gérald. Porte bonheur, et un peu d'odeur de grange.",
		"bonus": {"CHA": 1, "SAG": 1},
		"rarity": "rare",
	},
	"couronne_gloubah": {
		"name": "Couronne de nénuphar de Gloubah",
		"desc": "Encore humide. Toujours humide. Pour l'éternité, humide.",
		"bonus": {"CON": 2, "CHA": 1},
		"rarity": "épique",
	},
}

const COMMON_DROPS := ["mediator_os", "ceinture_cloutee", "bracelet_force", "cordes_dragon", "grimoire_tablatures"]


static func get_item(id: String) -> Dictionary:
	var item: Dictionary = ITEMS.get(id, {})
	return item


static func color_of(id: String) -> Color:
	var rarity: String = get_item(id).get("rarity", "commun")
	var c: Color = RARITY_COLORS.get(rarity, Color.WHITE)
	return c


static func bonus_text(id: String) -> String:
	var parts: PackedStringArray = []
	var bonus: Dictionary = get_item(id).get("bonus", {})
	for ab: String in bonus:
		parts.append("+%d %s" % [int(bonus[ab]), ab])
	return ", ".join(parts)
