class_name QuestDB
extends RefCounted
## Définition des quêtes. Ajouter une quête = ajouter une entrée ici + ses dialogues
## dans DialogueDB (voir docs/ARCHITECTURE.md).

enum State { LOCKED, AVAILABLE, ACTIVE, OBJECTIVE_DONE, TURNED_IN }

const QUESTS := {
	"plumeau": {
		"title": "Le Petit Plumeau",
		"giver": "gerald",
		"summary": "Des squelettes ont enlevé Plumeau, le bébé hibours adoré de Gérald le fromager.",
		"objective": "Traverser le portail de Zarathos, prendre la clé au chef des squelettes et délivrer Plumeau de Gloubah, le Roi Grenouille.",
		"objective_talk_mage": "Demander à Zarathos, le vieux mage, d'ouvrir un portail.",
		"objective_done": "Rendre Plumeau à Gérald, à la Chèvre Fringante.",
		"requires": "",
		"dungeon": {
			"name": "Catacombes Suintantes",
			# Donjon fait main dans l'éditeur (voir docs/EDITEUR_NIVEAUX.md) ; sans "map", il est généré.
			"map": "res://scenes/levels/catacombes.tscn",
			"rooms": 10,
			"enemy_level": 1,
			"boss": "gloubah",
		},
		"reward": {"xp": 300, "gold": 50, "item": "portrait_aieule"},
	},
}


static func get_quest(id: String) -> Dictionary:
	var q: Dictionary = QUESTS.get(id, {})
	return q


static func title(id: String) -> String:
	var t: String = get_quest(id).get("title", id)
	return t
