class_name TalentDB
extends RefCounted
## Arbre de talents : 5 branches × 4 paliers. 1 point de talent par niveau
## (dont 1 dès le niveau 1). Dans une branche, les paliers se débloquent dans l'ordre.
## Les talents actifs se placent sur les touches 4 à 7.

const SLOT_COUNT := 4

const BRANCHES := [
	{"id": "ballade", "name": "Ballade", "role": "Soins", "color": Color(0.45, 0.95, 0.5),
		"talents": ["ballade_reparatrice", "rappel", "hymne_phenix", "encore"]},
	{"id": "mur", "name": "Mur du Son", "role": "Protection", "color": Color(0.45, 0.7, 1.0),
		"talents": ["mur_larsen", "cuir_renforce", "pile_amplis", "sustain"]},
	{"id": "mosh", "name": "Mosh Pit", "role": "Repoussement", "color": Color(1.0, 0.6, 0.25),
		"talents": ["wall_of_death", "larsen_persistant", "stage_diving", "pogo"]},
	{"id": "transe", "name": "Transe", "role": "Contrôle", "color": Color(0.8, 0.5, 1.0),
		"talents": ["solo_endiable", "tempo_hypnotique", "growl", "maitre_tempo"]},
	{"id": "thrash", "name": "Thrash", "role": "Destruction", "color": Color(1.0, 0.3, 0.25),
		"talents": ["distorsion", "enceinte", "overdrive", "pyrotechnie"]},
]

## active : sort à lancer (coût en dB, recharge en s) ; sinon talent passif permanent.
const TALENTS := {
	# --- Ballade (soins) ---
	"ballade_reparatrice": {"name": "Ballade réparatrice", "active": true, "cost": 25.0, "cooldown": 12.0,
		"desc": "Mini-jeu sur le vrai solo de guitare de la taverne (10 s, touches 1 2 3 4) : chaque note juste soigne tout le groupe à 10 m. Solo sans faute = 90 % des PV max. Une fausse note arrête la ballade (recharge ×2,5)."},
	"rappel": {"name": "Rappel", "active": false,
		"desc": "Le public en redemande : chaque ennemi vaincu rend 3 PV et 4 dB."},
	"hymne_phenix": {"name": "Hymne du Phénix", "active": true, "cost": 35.0, "cooldown": 30.0,
		"desc": "Cercle de flammes dorées (4 m) pendant 8 s : tous les alliés qui s'y tiennent récupèrent 6 % de leurs PV max par seconde."},
	"encore": {"name": "Encore !", "active": false,
		"desc": "Un coup mortel vous laisse à 1 PV et vous soigne de 50 % (une fois toutes les 2 minutes)."},
	# --- Mur du Son (protection) ---
	"mur_larsen": {"name": "Mur de Larsen", "active": true, "cost": 20.0, "cooldown": 15.0,
		"desc": "Bouclier de larsen qui absorbe 10 + 3 × CHA + 2 × niveau dégâts pendant 8 s."},
	"cuir_renforce": {"name": "Cuir clouté renforcé", "active": false,
		"desc": "+2 à la classe d'armure."},
	"pile_amplis": {"name": "Pile d'amplis", "active": true, "cost": 30.0, "cooldown": 25.0,
		"desc": "Deux amplis se dressent 6 s : dégâts reçus divisés par 2 et chaque attaquant subit 1d6 + CHA."},
	"sustain": {"name": "Sustain", "active": false,
		"desc": "-10 % de dégâts reçus. Quand le Mur de Larsen se brise, il explose en onde qui repousse."},
	# --- Mosh Pit (repoussement) ---
	"wall_of_death": {"name": "Wall of Death", "active": true, "cost": 15.0, "cooldown": 6.0,
		"desc": "Cône de 7 m devant vous : 1d8 + CHA et les ennemis sont violemment projetés en arrière."},
	"larsen_persistant": {"name": "Larsen persistant", "active": false,
		"desc": "Onde de choc : rayon +2 m et recul +50 %."},
	"stage_diving": {"name": "Stage Diving", "active": true, "cost": 25.0, "cooldown": 10.0,
		"desc": "Saut vers le curseur (8 m max). À l'atterrissage : 2d6 + CHA et recul dans un rayon de 4 m."},
	"pogo": {"name": "Pogo", "active": false,
		"desc": "Les ennemis que vous repoussez fortement restent assommés 1,5 s."},
	# --- Transe (contrôle) ---
	"solo_endiable": {"name": "Solo endiablé", "active": true, "cost": 30.0, "cooldown": 25.0,
		"desc": "Mini-jeu du solo : tant que les notes sont réussies (jusqu'à 12), les ennemis à 12 m se figent et headbanguent. Une fausse note brise la transe (recharge ×2,5). Vous pouvez vous déplacer."},
	"tempo_hypnotique": {"name": "Tempo hypnotique", "active": false,
		"desc": "Chaque ennemi touché par l'Accordage de cordes est ralenti de 40 % pendant 2 s."},
	"growl": {"name": "Growl de l'Abîme", "active": true, "cost": 20.0, "cooldown": 16.0,
		"desc": "Hurlement guttural : les ennemis à 6 m fuient, terrifiés, pendant 3,5 s (les boss sont seulement sonnés)."},
	"maitre_tempo": {"name": "Maître du tempo", "active": false,
		"desc": "Solo endiablé jusqu'à 16 notes, et chaque note réussie inflige 1d6 + CHA aux ennemis en transe."},
	# --- Thrash (destruction) ---
	"distorsion": {"name": "Distorsion", "active": false,
		"desc": "Accordage de cordes : 6 cibles au lieu de 5 et +15 % de dégâts."},
	"enceinte": {"name": "Enceinte de façade", "active": true, "cost": 25.0, "cooldown": 14.0,
		"desc": "Pose une enceinte au curseur (8 m) qui pulse 6 fois : 1d8 + CHA dans un rayon de 4 m."},
	"overdrive": {"name": "Overdrive", "active": false,
		"desc": "Riff électrique (et FIREBALL, Riff black metal) : +25 % de dégâts."},
	"pyrotechnie": {"name": "Pyrotechnie", "active": true, "cost": 40.0, "cooldown": 20.0,
		"desc": "Six colonnes de feu jaillissent autour de vous après 0,8 s : 4d6 chacune."},
}


static func get_talent(id: String) -> Dictionary:
	var t: Dictionary = TALENTS.get(id, {})
	return t


static func is_active(id: String) -> bool:
	return bool(get_talent(id).get("active", false))


static func branch_of(id: String) -> Dictionary:
	for b: Dictionary in BRANCHES:
		if (b["talents"] as Array).has(id):
			return b
	return {}


## Palier (0..3) du talent dans sa branche.
static func tier_of(id: String) -> int:
	var talents: Array = branch_of(id).get("talents", [])
	return talents.find(id)


## Talent précédent dans la branche (à apprendre avant), ou "" pour le premier palier.
static func prerequisite(id: String) -> String:
	var talents: Array = branch_of(id).get("talents", [])
	var i := talents.find(id)
	return str(talents[i - 1]) if i > 0 else ""


static func all_ids() -> Array[String]:
	var out: Array[String] = []
	for b: Dictionary in BRANCHES:
		for id: String in b["talents"]:
			out.append(id)
	return out
