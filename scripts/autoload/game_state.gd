extends Node
## État persistant de la partie : fiche du héros, ressources, quêtes, inventaire, sauvegarde.
## Tout ce qui doit survivre à un changement de scène vit ici.

const SAVE_PATH := "user://metal_bard_save.json"
const HERO_NAME := "Riffald"
const HERO_TITLE := "Barde du Tonnerre"

var stats := CharacterStats.new()
var hp := 1
var mana := 0.0
var gold := 0
var potions := 0
var inventory: Array[String] = []
var quests := {} # quest_id -> QuestDB.State
var flags := {}
var active_quest := ""
var dungeon_seed := 0


func _ready() -> void:
	new_game()


func new_game() -> void:
	stats = CharacterStats.new()
	gold = 30
	potions = 2
	inventory.clear()
	flags = {}
	quests = {}
	for id: String in QuestDB.QUESTS:
		var requires: String = QuestDB.get_quest(id).get("requires", "")
		quests[id] = QuestDB.State.AVAILABLE if requires.is_empty() else QuestDB.State.LOCKED
	active_quest = ""
	dungeon_seed = 0
	hp = max_hp()
	mana = max_mana()


# --- Caractéristiques dérivées (règles D&D adaptées) -------------------------

## Valeur totale d'une caractéristique : base + bonus des reliques.
func ability(ab: String) -> int:
	var total := stats.base(ab)
	for item_id in inventory:
		var bonus: Dictionary = ItemDB.get_item(item_id).get("bonus", {})
		total += int(bonus.get(ab, 0))
	return mini(total, 30)


func mod(ab: String) -> int:
	return CharacterStats.modifier_for(ability(ab))


func proficiency() -> int:
	# Bonus de maîtrise D&D : +2 aux niveaux 1-4, +3 aux niveaux 5-8, etc.
	return 2 + floori((stats.level - 1) / 4.0)


func max_hp() -> int:
	var con := mod("CON")
	return maxi(10, Balance.HERO_BASE_HP + Balance.HERO_HP_PER_CON * con
		+ (stats.level - 1) * (Balance.HERO_HP_PER_LEVEL + con))


func max_mana() -> float:
	return Balance.HERO_BASE_MANA + Balance.HERO_MANA_PER_CHA * mod("CHA") \
		+ Balance.HERO_MANA_PER_LEVEL * (stats.level - 1)


func armor_class() -> int:
	return Balance.HERO_BASE_AC + mod("DEX")


## DD des jets de sauvegarde contre les sorts du barde : 8 + maîtrise + CHA.
func spell_dc() -> int:
	return 8 + proficiency() + mod("CHA")


func mana_regen() -> float:
	return Balance.HERO_MANA_REGEN * maxf(0.4, 1.0 + 0.15 * mod("SAG"))


func cooldown_multiplier() -> float:
	return clampf(1.0 - 0.04 * mod("INT"), 0.6, 1.2)


func next_level_xp() -> int:
	if stats.level >= Balance.MAX_LEVEL:
		return stats.xp
	var needed: int = Balance.XP_TABLE[stats.level]
	return needed


func previous_level_xp() -> int:
	var prev: int = Balance.XP_TABLE[stats.level - 1]
	return prev


# --- Ressources ------------------------------------------------------------

func damage_hero(amount: int) -> void:
	hp = maxi(0, hp - amount)
	Events.hero_hp_changed.emit(hp, max_hp())


func heal_hero(amount: int) -> void:
	hp = mini(max_hp(), hp + amount)
	Events.hero_hp_changed.emit(hp, max_hp())


func spend_mana(cost: float) -> bool:
	if mana < cost:
		return false
	mana -= cost
	Events.hero_mana_changed.emit(mana, max_mana())
	return true


func regen_mana(delta: float) -> void:
	var m := max_mana()
	if mana >= m:
		return
	mana = minf(m, mana + mana_regen() * delta)
	Events.hero_mana_changed.emit(mana, m)


func add_gold(amount: int) -> void:
	gold = maxi(0, gold + amount)
	Events.gold_changed.emit(gold)


func add_potion(count: int = 1) -> void:
	potions += count
	Events.potions_changed.emit(potions)


func add_item(id: String) -> void:
	if id.is_empty() or inventory.has(id):
		return
	inventory.append(id)
	var item := ItemDB.get_item(id)
	Events.notify("Relique obtenue : %s (%s)" % [item.get("name", id), ItemDB.bonus_text(id)], ItemDB.color_of(id))
	_on_stats_changed()


func add_xp(amount: int) -> void:
	stats.xp += amount
	while stats.level < Balance.MAX_LEVEL and stats.xp >= next_level_xp():
		stats.level += 1
		stats.unspent_points += Balance.POINTS_PER_LEVEL
		hp = max_hp()
		mana = max_mana()
		Events.level_up.emit(stats.level)
		Events.notify("NIVEAU %d ! +%d points de caractéristique [%s]" % [
			stats.level, Balance.POINTS_PER_LEVEL, Controls.key_label("character_sheet")], Events.COLOR_GOLD)
	Events.xp_changed.emit(stats.xp, next_level_xp(), stats.level)
	_on_stats_changed()


func spend_point(ab: String) -> bool:
	if stats.unspent_points <= 0 or stats.base(ab) >= Balance.ABILITY_CAP:
		return false
	var old_max := max_hp()
	stats.abilities[ab] = stats.base(ab) + 1
	stats.unspent_points -= 1
	hp += maxi(0, max_hp() - old_max)
	_on_stats_changed()
	return true


func _on_stats_changed() -> void:
	hp = mini(hp, max_hp())
	mana = minf(mana, max_mana())
	Events.stats_changed.emit()
	broadcast_all()


## Ré-émet toutes les valeurs (utile quand une nouvelle interface apparaît).
func broadcast_all() -> void:
	Events.hero_hp_changed.emit(hp, max_hp())
	Events.hero_mana_changed.emit(mana, max_mana())
	Events.xp_changed.emit(stats.xp, next_level_xp(), stats.level)
	Events.gold_changed.emit(gold)
	Events.potions_changed.emit(potions)


func apply_death_penalty() -> void:
	var lost := floori(gold * Balance.DEATH_GOLD_PENALTY)
	gold -= lost
	hp = max_hp()
	mana = max_mana()
	flags["last_death_gold_lost"] = lost


# --- Quêtes ----------------------------------------------------------------

func quest_state(id: String) -> int:
	var s: int = quests.get(id, QuestDB.State.LOCKED)
	return s


func set_quest_state(id: String, state: int) -> void:
	quests[id] = state
	Events.quest_updated.emit(id)


func accept_quest(id: String) -> void:
	if quest_state(id) != QuestDB.State.AVAILABLE:
		return
	active_quest = id
	set_quest_state(id, QuestDB.State.ACTIVE)
	Events.notify("Nouvelle quête : %s" % QuestDB.title(id), Events.COLOR_GOLD)


func complete_objective(id: String) -> void:
	if quest_state(id) != QuestDB.State.ACTIVE:
		return
	set_quest_state(id, QuestDB.State.OBJECTIVE_DONE)
	Events.notify("Objectif accompli : %s" % QuestDB.title(id), Events.COLOR_GOOD)


func turn_in_quest(id: String) -> void:
	if quest_state(id) != QuestDB.State.OBJECTIVE_DONE:
		return
	set_quest_state(id, QuestDB.State.TURNED_IN)
	var reward: Dictionary = QuestDB.get_quest(id).get("reward", {})
	Events.notify("Quête terminée : %s" % QuestDB.title(id), Events.COLOR_GOLD)
	add_gold(int(reward.get("gold", 0)))
	add_xp(int(reward.get("xp", 0)))
	add_item(str(reward.get("item", "")))
	if active_quest == id:
		active_quest = ""
	flags.erase("portal_open")
	# Débloque les quêtes qui dépendaient de celle-ci.
	for other: String in QuestDB.QUESTS:
		if QuestDB.get_quest(other).get("requires", "") == id and quest_state(other) == QuestDB.State.LOCKED:
			set_quest_state(other, QuestDB.State.AVAILABLE)
	save_game()


## Exécute une action choisie dans un dialogue (ex. « accept:plumeau »).
func run_dialogue_action(action: String) -> void:
	var parts := action.split(":")
	var verb := parts[0]
	var arg := parts[1] if parts.size() > 1 else ""
	match verb:
		"accept":
			accept_quest(arg)
		"turn_in":
			turn_in_quest(arg)
		"portal":
			flags["portal_open"] = true
			dungeon_seed = randi_range(1, 999999)
			Events.portal_opened.emit()
		"buy_potion":
			if gold >= Balance.POTION_PRICE:
				add_gold(-Balance.POTION_PRICE)
				add_potion()
				Sfx.play("coin")
				Events.notify("Potion de soin achetée (%d en stock)" % potions, Events.COLOR_GOOD)
			else:
				Events.notify("Pas assez d'or (il faut %d po)." % Balance.POTION_PRICE, Events.COLOR_BAD)
		"rest":
			if gold >= Balance.REST_PRICE:
				add_gold(-Balance.REST_PRICE)
				hp = max_hp()
				mana = max_mana()
				broadcast_all()
				Events.notify("Vous dormez comme un roadie après un concert. PV et dB restaurés.", Events.COLOR_GOOD)
			else:
				Events.notify("Pas assez d'or pour une chambre.", Events.COLOR_BAD)
		"flag":
			flags[arg] = true


# --- Sauvegarde ------------------------------------------------------------

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> void:
	var data := {
		"version": 1,
		"stats": stats.to_dict(),
		"hp": hp,
		"mana": mana,
		"gold": gold,
		"potions": potions,
		"inventory": inventory,
		"quests": quests,
		"flags": flags,
		"active_quest": active_quest,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Sauvegarde impossible : %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(data, "\t"))


func load_game() -> bool:
	if not has_save():
		return false
	var text := FileAccess.get_file_as_string(SAVE_PATH)
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return false
	var data: Dictionary = parsed
	new_game()
	stats.from_dict(data.get("stats", {}))
	gold = int(data.get("gold", 0))
	potions = int(data.get("potions", 0))
	inventory.clear()
	for id: Variant in data.get("inventory", []):
		inventory.append(str(id))
	var saved_quests: Dictionary = data.get("quests", {})
	for id: String in saved_quests:
		quests[id] = int(saved_quests[id])
	flags = data.get("flags", {})
	active_quest = str(data.get("active_quest", ""))
	hp = clampi(int(data.get("hp", max_hp())), 1, max_hp())
	mana = clampf(float(data.get("mana", max_mana())), 0.0, max_mana())
	return true
