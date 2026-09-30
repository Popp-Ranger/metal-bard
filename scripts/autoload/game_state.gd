extends Node
## État persistant de la partie : fiche du héros, ressources, quêtes, inventaire, sauvegarde.
## Tout ce qui doit survivre à un changement de scène vit ici.

const SAVE_PATH := "user://metal_bard_save.json"
const DEFAULT_NAME := "Riffald"
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
## Personnage créé au début de la partie (voir RaceDB).
var hero_name := DEFAULT_NAME
var appearance := RaceDB.DEFAULT_APPEARANCE.duplicate()
## Arbre de talents (voir TalentDB).
var talents: Array[String] = []
var talent_points := 1
var spell_slots: Array[String] = ["", "", "", ""] # talents actifs sur les touches 4 à 7
## Bouclier temporaire (Mur de Larsen), non sauvegardé.
var shield := 0
## Décibels illimités (sous-sol d'entraînement de la taverne), non sauvegardé.
var infinite_mana := false
## Statistiques du passage en cours au donjon (compteur de victimes, récapitulatif).
var run := {"kills": 0, "dealt": 0, "taken": 0, "avoided": 0, "start": 0}


func _ready() -> void:
	new_game()
	Events.enemy_killed.connect(func(_e: Node3D) -> void: run_add("kills", 1))


func new_game() -> void:
	stats = CharacterStats.new()
	gold = ItemDB.starting_money()
	potions = ItemDB.starting_potions()
	inventory.clear()
	flags = {}
	quests = {}
	for id: String in QuestDB.QUESTS:
		var requires: String = QuestDB.get_quest(id).get("requires", "")
		quests[id] = QuestDB.State.AVAILABLE if requires.is_empty() else QuestDB.State.LOCKED
	active_quest = ""
	dungeon_seed = 0
	hero_name = DEFAULT_NAME
	appearance = RaceDB.DEFAULT_APPEARANCE.duplicate()
	talents.clear()
	talent_points = 1
	spell_slots = ["", "", "", ""]
	shield = 0
	location = {}
	pending_spawn = Vector3.INF
	hp = max_hp()
	mana = max_mana()


# --- Caractéristiques dérivées (règles D&D adaptées) -------------------------

## Valeur totale d'une caractéristique : base + bonus des reliques.
func ability(ab: String) -> int:
	var total := stats.base(ab) + RaceDB.bonus(race(), ab)
	for item_id in inventory:
		var bonus: Dictionary = ItemDB.active_bonus(item_id)
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
		+ (stats.level - 1) * (Balance.HERO_HP_PER_LEVEL + con)) + (15 if race() == "ogre" else 0)


func max_mana() -> float:
	return Balance.HERO_BASE_MANA + Balance.HERO_MANA_PER_CHA * mod("CHA") \
		+ Balance.HERO_MANA_PER_LEVEL * (stats.level - 1)


func armor_class() -> int:
	return Balance.HERO_BASE_AC + mod("DEX") + (2 if has_talent("cuir_renforce") else 0)


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
	if infinite_mana:
		# Salle d'entraînement : les décibels restent au maximum.
		mana = max_mana()
		Events.hero_mana_changed.emit(mana, max_mana())
		return true
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
	if race() == "humain":
		amount = roundi(amount * 1.1) # Polyvalent : +10 % d'XP
	stats.xp += amount
	while stats.level < Balance.MAX_LEVEL and stats.xp >= next_level_xp():
		stats.level += 1
		stats.unspent_points += Balance.POINTS_PER_LEVEL
		talent_points += 1
		hp = max_hp()
		mana = max_mana()
		Events.level_up.emit(stats.level)
		Events.notify("NIVEAU %d ! +%d points de caractéristique [%s] et +1 point de talent [%s]" % [
			stats.level, Balance.POINTS_PER_LEVEL, Controls.key_label("character_sheet"),
			Controls.key_label("talents")], Events.COLOR_GOLD)
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
	var lost := floori(gold * ItemDB.death_money_penalty())
	gold -= lost
	hp = max_hp()
	mana = max_mana()
	flags["last_death_gold_lost"] = lost


# --- Personnage : race, sexe, talents ------------------------------------------

func race() -> String:
	return str(appearance.get("race", "humain"))


func is_female() -> bool:
	return appearance.get("sex", "m") == "f"


## Accorde un mot au sexe du personnage : g("le barde", "la barde").
func g(masculine: String, feminine: String) -> String:
	return feminine if is_female() else masculine


## Multiplicateur des dégâts de sorts (Démon : Sang infernal).
func spell_power() -> float:
	return 1.1 if race() == "demon" else 1.0


func has_talent(id: String) -> bool:
	return talents.has(id)


## Vide si le talent peut être appris, sinon la raison du refus.
func talent_block_reason(id: String) -> String:
	if has_talent(id):
		return "Déjà appris"
	if talent_points <= 0:
		return "Aucun point de talent"
	var pre := TalentDB.prerequisite(id)
	if not pre.is_empty() and not has_talent(pre):
		return "Nécessite : %s" % TalentDB.get_talent(pre).get("name", pre)
	return ""


func learn_talent(id: String) -> bool:
	if not talent_block_reason(id).is_empty():
		return false
	talents.append(id)
	talent_points -= 1
	if TalentDB.is_active(id):
		var free := spell_slots.find("")
		if free != -1:
			spell_slots[free] = id
	Events.notify("Talent appris : %s" % TalentDB.get_talent(id).get("name", id), Events.COLOR_GOLD)
	Events.talents_changed.emit()
	_on_stats_changed()
	return true


## L'Inconnue encapuchonnée efface l'arbre de talents : tous les points sont rendus.
func reset_talents() -> void:
	if talents.is_empty():
		Events.notify("Vous n'avez aucun talent à oublier.", Events.COLOR_BAD)
		return
	talent_points += talents.size()
	talents.clear()
	spell_slots = ["", "", "", ""]
	Events.notify("Vos talents s'effacent comme un vieux vinyle rayé... %d point(s) de talent à redistribuer [%s]." % [
		talent_points, Controls.key_label("talents")], Events.COLOR_MAGIC)
	Events.talents_changed.emit()
	_on_stats_changed()


## Place un talent actif sur l'emplacement `slot` (0..3) ; échange si déjà placé ailleurs.
func assign_slot(id: String, slot: int) -> void:
	var old := spell_slots.find(id)
	if old != -1:
		spell_slots[old] = spell_slots[slot]
	spell_slots[slot] = id
	Events.talents_changed.emit()


## Fait tourner le talent sur les emplacements 4 → 5 → 6 → 7 → (aucun).
func cycle_slot(id: String) -> void:
	var cur := spell_slots.find(id)
	if cur == TalentDB.SLOT_COUNT - 1:
		spell_slots[cur] = ""
		Events.talents_changed.emit()
	else:
		assign_slot(id, cur + 1)


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
			if gold >= ItemDB.potion_price():
				add_gold(-ItemDB.potion_price())
				add_potion()
				Sfx.play("coin")
				Events.notify("Potion de soin achetée (%d en stock)" % potions, Events.COLOR_GOOD)
			else:
				Events.notify("Pas assez de médiators (il en faut %d)." % ItemDB.potion_price(), Events.COLOR_BAD)
		"rest":
			if gold >= ItemDB.rest_price():
				add_gold(-ItemDB.rest_price())
				hp = max_hp()
				mana = max_mana()
				broadcast_all()
				Events.notify("Vous dormez comme un roadie après un concert. PV et dB restaurés.", Events.COLOR_GOOD)
			else:
				Events.notify("Pas assez de médiators pour une chambre.", Events.COLOR_BAD)
		"reset_talents":
			reset_talents()
		"flag":
			flags[arg] = true
		"story":
			Events.story_action.emit(arg)


# --- Sauvegarde ------------------------------------------------------------

## Emplacements de sauvegarde manuelle (1 à SLOT_COUNT) ; l'emplacement 0 est la
## sauvegarde automatique (SAVE_PATH), faite à chaque étape importante.
const SAVE_SLOTS := 5
const SAVE_DIR := "user://saves/"

## Où reprendre la partie au chargement : {"scene": chemin, "pos": [x, z]} (voir Level).
var location := {}
## Position où placer le héros à l'arrivée dans la scène (après un chargement).
var pending_spawn := Vector3.INF


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func slot_path(slot: int) -> String:
	return SAVE_PATH if slot <= 0 else SAVE_DIR + "slot_%d.json" % slot


func has_slot(slot: int) -> bool:
	return FileAccess.file_exists(slot_path(slot))


## Sauvegarde automatique (emplacement 0).
func save_game() -> void:
	save_to_slot(0)


func _snapshot() -> Dictionary:
	return {
		"version": 2,
		"saved_at": Time.get_datetime_string_from_system(false, true),
		"stats": stats.to_dict(),
		"hero_name": hero_name,
		"appearance": appearance,
		"talents": talents,
		"talent_points": talent_points,
		"spell_slots": spell_slots,
		"hp": hp,
		"mana": mana,
		"gold": gold,
		"potions": potions,
		"inventory": inventory,
		"quests": quests,
		"flags": flags,
		"active_quest": active_quest,
		"dungeon_seed": dungeon_seed,
		"location": location,
	}


func save_to_slot(slot: int) -> bool:
	if slot > 0:
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var file := FileAccess.open(slot_path(slot), FileAccess.WRITE)
	if file == null:
		push_warning("Sauvegarde impossible : %s" % error_string(FileAccess.get_open_error()))
		return false
	file.store_string(JSON.stringify(_snapshot(), "\t"))
	return true


func _read_slot(slot: int) -> Dictionary:
	if not has_slot(slot):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(slot_path(slot)))
	if parsed is Dictionary:
		return parsed
	return {}


## Résumé affiché dans le menu Charger : nom, race, niveau, lieu, date.
func slot_summary(slot: int) -> String:
	var data := _read_slot(slot)
	if data.is_empty():
		return ""
	var look: Dictionary = data.get("appearance", {})
	var st: Dictionary = data.get("stats", {})
	var loc: Dictionary = data.get("location", {})
	return "%s — %s niv. %d — %s — %s" % [
		str(data.get("hero_name", DEFAULT_NAME)), RaceDB.title(look), int(st.get("level", 1)),
		location_label(str(loc.get("scene", ""))), str(data.get("saved_at", "?")).replace("T", " ").left(16)]


static func location_label(scene: String) -> String:
	match scene:
		Router.INTRO:
			return "Route du Crâne Hurlant"
		Router.DUNGEON:
			return "Catacombes Suintantes"
	return "Le Crâne Hurlant"


func load_game() -> bool:
	return load_slot(0)


func load_slot(slot: int) -> bool:
	var data := _read_slot(slot)
	if data.is_empty():
		return false
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
	hero_name = str(data.get("hero_name", DEFAULT_NAME))
	var saved_look: Dictionary = data.get("appearance", {})
	for key: String in RaceDB.DEFAULT_APPEARANCE:
		var default_value: Variant = RaceDB.DEFAULT_APPEARANCE[key]
		var v: Variant = saved_look.get(key, default_value)
		appearance[key] = str(v) if default_value is String else int(v)
	talents.clear()
	for id: Variant in data.get("talents", []):
		talents.append(str(id))
	talent_points = int(data.get("talent_points", 1))
	var saved_slots: Array = data.get("spell_slots", [])
	for i in TalentDB.SLOT_COUNT:
		spell_slots[i] = str(saved_slots[i]) if i < saved_slots.size() else ""
	hp = clampi(int(data.get("hp", max_hp())), 1, max_hp())
	mana = clampf(float(data.get("mana", max_mana())), 0.0, max_mana())
	dungeon_seed = int(data.get("dungeon_seed", 0))
	location = data.get("location", {})
	return true


## Scène où reprendre après un chargement (et position du héros si elle est connue).
func resume_scene() -> String:
	var scene := str(location.get("scene", ""))
	if scene.is_empty():
		scene = Router.TAVERN if flags.get("intro_done", false) or quest_state("plumeau") != QuestDB.State.AVAILABLE else Router.INTRO
	var pos: Array = location.get("pos", [])
	pending_spawn = Vector3(float(pos[0]), 0.0, float(pos[1])) if pos.size() == 2 and scene != Router.INTRO else Vector3.INF
	if scene == Router.DUNGEON:
		flags["in_dungeon"] = true
	else:
		flags.erase("in_dungeon")
	return scene


# --- Statistiques du donjon ---------------------------------------------------------

func reset_run() -> void:
	run = {"kills": 0, "dealt": 0, "taken": 0, "avoided": 0, "start": Time.get_ticks_msec()}


func run_add(key: String, amount: int) -> void:
	if amount <= 0:
		return
	run[key] = int(run.get(key, 0)) + amount
	Events.run_stats_changed.emit()


func run_seconds() -> int:
	return floori((Time.get_ticks_msec() - int(run.get("start", 0))) / 1000.0)
