extends "res://scripts/world/dungeon.gd"
## Cryptes de la Cathédrale : le portail à XP du sous-sol de la Chèvre Fringante (portail démoniaque).
## Sous-sol d'une cathédrale où coulent des ruisseaux de lave en fusion ; squelettes, diablotins, démons cornus et
## rats. Au fond, le Gardien des Cryptes garde le portail qui ramène au portail de la taverne.
## Rien n'est gardé : chaque passage tire de nouvelles cryptes (graine GameState.crypt_seed, tirée en entrant, la
## même pour tous les joueurs en coop). Les ennemis sont au niveau du héros (de l'hôte en coop) : de quoi gagner de l'XP.

const CONFIG := {"name": "Cryptes de la Cathédrale", "theme": "crypte", "rooms": 9, "boss_key": false}


func _ready() -> void:
	persistent = false
	super._ready()


func _dungeon_config() -> Dictionary:
	return CONFIG


## Niveau des ennemis = celui du héros (en coop : celui de l'hôte, pour que tous voient les mêmes ennemis).
func _enemy_level(_cfg: Dictionary) -> int:
	var lvl := GameState.stats.level
	if Net.is_client():
		lvl = int((Net.players.get(1, {}) as Dictionary).get("level", lvl))
	return clampi(lvl, 1, Balance.MAX_LEVEL)


func _saved_seed() -> int:
	return GameState.crypt_seed


func _store_seed(seed_value: int) -> void:
	GameState.crypt_seed = seed_value


func _arrival_notice() -> void:
	Events.notify("Une chaleur de forge... Les Cryptes de la Cathédrale. Au fond, un portail vous ramènera à la taverne.", Color(1.0, 0.55, 0.3))


## On revient toujours au portail démoniaque de la taverne ; les cryptes seront retirées au prochain passage.
func _exit_scene() -> String:
	GameState.flags["from_crypt"] = true
	GameState.crypt_seed = 0
	return Router.TAVERN
