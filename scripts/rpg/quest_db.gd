class_name QuestDB
extends RefCounted
## Définition des quêtes. Ajouter une quête = ajouter une entrée ici + ses dialogues
## dans DialogueDB (voir docs/ARCHITECTURE.md).

enum State { LOCKED, AVAILABLE, ACTIVE, OBJECTIVE_DONE, TURNED_IN }

const QUESTS := {
	"plumeau": {
		"title": "Le Petit Plumeau",
		"giver": "gerald",
		"summary": "Des squelettes ont enlevé Plumeau, le bébé ours-hibou de Gérald.",
		"objective": "Traverser le portail de Zarathos et retrouver Plumeau dans les Catacombes Suintantes.",
		"objective_talk_mage": "Demander à Zarathos, le vieux mage, d'ouvrir un portail.",
		"objective_done": "Retourner voir Gérald à la taverne.",
		"requires": "",
		"dungeon": {
			"name": "Catacombes Suintantes",
			"rooms": 10,
			"enemy_level": 1,
			"boss": "gloubah",
		},
		"reward": {"xp": 300, "gold": 100, "item": "pendentif_plume"},
	},
}


static func get_quest(id: String) -> Dictionary:
	var q: Dictionary = QUESTS.get(id, {})
	return q


static func title(id: String) -> String:
	var t: String = get_quest(id).get("title", id)
	return t
