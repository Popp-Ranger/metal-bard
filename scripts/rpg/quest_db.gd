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
	# Chapitre 2 : l'Inconnue raconte la légende de Back Jlack... et la fait vivre au héros (Temple du Dragon).
	"pick_destin": {
		"title": "La Légende de Back Jlack",
		"giver": "inconnue",
		"turn_in_to": "backjlack",
		"summary": "La légende du sage Back Jlack, qui vainquit avec l'aide de Satan le dragon Mèhn-Strïm, ennemi du métal.",
		# Étapes : tant que le drapeau n'est pas levé, son texte sert d'objectif.
		"stages": [
			["temple_trial_ok", "Réussir l'épreuve de Back Jlack (40 notes, 120 BPM, 80 % au moins), en haut des marches interminables."],
		],
		"objective": "Explorer le Temple du Dragon, chercher le Pick du Destin et vaincre l'ange déchu.",
		"objective_done": "Rapporter la partition maudite à Back Jlack, sur le parvis du temple.",
		"requires": "plumeau",
		"dungeon": {"name": "Temple du Dragon", "theme": "temple", "rooms": 9, "enemy_level": 3, "boss_key": false},
		"reward": {"xp": 1200, "gold": 150},
	},
}


static func get_quest(id: String) -> Dictionary:
	var q: Dictionary = QUESTS.get(id, {})
	return q


## Objectif affiché pour une quête (selon son état et ses étapes).
static func objective_text(id: String) -> String:
	var q := get_quest(id)
	match GameState.quest_state(id):
		State.ACTIVE:
			for stage: Array in q.get("stages", []):
				if not bool(GameState.flags.get(str(stage[0]), false)):
					return str(stage[1])
			if q.has("objective_talk_mage") and not (GameState.flags.get("portal_open", false) or GameState.flags.get("in_dungeon", false)):
				return str(q["objective_talk_mage"])
			return str(q.get("objective", ""))
		State.OBJECTIVE_DONE:
			return str(q.get("objective_done", ""))
	return ""


static func title(id: String) -> String:
	var t: String = get_quest(id).get("title", id)
	return t
