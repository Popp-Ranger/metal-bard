extends Node
## Test de fumée automatisé. Lancer (sans fenêtre) :
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . res://tests/smoke_test.tscn
## Code de sortie 0 = tout va bien, 1 = au moins un échec.

var _failures := 0


func _ready() -> void:
	await get_tree().process_frame
	_test_rules()
	_test_generator()
	await _test_quest_flow()
	if _failures == 0:
		print("SMOKE TEST : OK")
	else:
		printerr("SMOKE TEST : %d échec(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		_failures += 1
		printerr("  ÉCHEC ", what)


func _test_rules() -> void:
	print("[Règles D&D]")
	_check(CharacterStats.modifier_for(10) == 0, "mod(10) = 0")
	_check(CharacterStats.modifier_for(16) == 3, "mod(16) = +3")
	_check(CharacterStats.modifier_for(8) == -1, "mod(8) = -1")
	_check(CharacterStats.modifier_for(7) == -2, "mod(7) = -2")
	GameState.new_game()
	_check(GameState.proficiency() == 2, "maîtrise niveau 1 = +2")
	_check(GameState.armor_class() == 13, "CA de départ = 13 (11 + DEX 14)")
	_check(GameState.spell_dc() == 13, "DD des sorts = 13 (8 + 2 + CHA 16)")
	GameState.add_xp(300)
	_check(GameState.stats.level == 2, "300 XP → niveau 2")
	_check(GameState.stats.unspent_points == Balance.POINTS_PER_LEVEL, "points gagnés au niveau 2")
	_check(GameState.spend_point("CHA") and GameState.ability("CHA") == 17, "dépense d'un point en CHA")
	for i in 200:
		var r := Dice.roll(2, 6, 1)
		if r < 3 or r > 13:
			_check(false, "2d6+1 hors bornes : %d" % r)
			return
	_check(true, "2d6+1 toujours entre 3 et 13")


func _test_generator() -> void:
	print("[Génération de donjons]")
	var all_ok := true
	for s in 50:
		var g := DungeonGenerator.new()
		g.generate(s + 1, 10)
		if g.rooms.size() < 6 or not g.is_start_connected_to_boss() or g.start_room == g.boss_room:
			all_ok = false
			printerr("    graine %d : %d salles, connecté=%s" % [s + 1, g.rooms.size(), g.is_start_connected_to_boss()])
	_check(all_ok, "50 donjons générés, départ toujours relié au boss")


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _test_quest_flow() -> void:
	print("[Déroulé de la quête]")
	GameState.new_game()
	_check(GameState.quest_state("plumeau") == QuestDB.State.AVAILABLE, "quête disponible au départ")
	var tavern: Node = load("res://scenes/tavern.tscn").instantiate()
	add_child(tavern)
	await _frames(20)
	_check(get_tree().get_nodes_in_group("interactable").size() >= 6, "PNJ interactifs présents dans la taverne")
	GameState.run_dialogue_action("accept:plumeau")
	_check(GameState.quest_state("plumeau") == QuestDB.State.ACTIVE, "quête acceptée")
	GameState.run_dialogue_action("portal")
	await _frames(5)
	_check(_count_portals(tavern) == 1, "portail ouvert dans la taverne")
	tavern.queue_free()
	await _frames(5)

	var dungeon: Node = load("res://scenes/dungeon.tscn").instantiate()
	add_child(dungeon)
	await _frames(30)
	var enemies := get_tree().get_nodes_in_group("enemies")
	_check(enemies.size() >= 8, "donjon peuplé (%d ennemis)" % enemies.size())
	var hero := get_tree().get_first_node_in_group("hero") as Hero
	_check(hero != null, "héros présent dans le donjon")
	# Les ennemis n'ont pas été générés dans la salle du héros.
	var nearest := INF
	for n in enemies:
		var e := n as Enemy
		if not e.is_boss:
			nearest = minf(nearest, e.global_position.distance_to(hero.global_position))
	_check(nearest > Balance.ENEMY_DETECT_RADIUS, "aucun squelette à portée de détection au départ")
	# Vitesse des ennemis = 25 % du héros.
	var sk := enemies[0] as Enemy
	_check(is_equal_approx(sk.move_speed, Balance.HERO_SPEED * 0.25), "vitesse ennemie = 0,25 × héros")
	# Sorts : on place 3 squelettes devant le héros.
	var targets: Array[Enemy] = []
	for n in enemies:
		var e := n as Enemy
		if not e.is_boss and targets.size() < 3:
			e.global_position = hero.global_position + Vector3(1.5 + targets.size(), 0, 1.0)
			targets.append(e)
	hero.aim_point = targets[0].global_position
	GameState.mana = GameState.max_mana()
	var hp_before := 0
	for e in targets:
		hp_before += e.hp
	hero.cast_tuning()
	await _frames(2)
	var hp_after := 0
	for e in targets:
		hp_after += maxi(e.hp, 0)
	_check(hp_after < hp_before, "l'Accordage de cordes inflige des dégâts en chaîne")
	hero.cooldowns["wave"] = 0.0
	hero.cast_wave()
	await _frames(2)
	_check(GameState.mana < GameState.max_mana(), "les sorts consomment des décibels")
	# Riff électrique : combo rythmique ×1 → ×3 (4 paliers), remis à ×1 à contretemps.
	_check(is_equal_approx(Hero.riff_multiplier(1), 1.0) and is_equal_approx(Hero.riff_multiplier(4), 3.0)
		and is_equal_approx(Hero.riff_multiplier(9), 3.0), "multiplicateur du Riff : ×1 → ×3 en 4 paliers")
	GameState.mana = GameState.max_mana()
	var dummy: Enemy = null
	for e in hero.enemies():
		if not e.is_boss:
			dummy = e
			break
	dummy.hp = 9999 # mannequin d'entraînement
	dummy.global_position = hero.global_position + Vector3(3, 0, 0)
	hero.aim_point = dummy.global_position
	for beat in 5:
		hero.cooldowns["riff"] = 0.0
		hero.cast_riff()
		await get_tree().create_timer(Balance.RIFF_BEAT).timeout
	_check(hero.riff_stack == Balance.RIFF_MAX_STACKS, "5 riffs en rythme → combo au maximum")
	await get_tree().create_timer(Balance.RIFF_BEAT * 2.5).timeout
	hero.cooldowns["riff"] = 0.0
	hero.cast_riff()
	_check(hero.riff_stack == 1, "riff à contretemps → combo remis à ×1")
	# Solo : le jeu continue, le héros est invincible, touches 1 2 3 4.
	GameState.mana = GameState.max_mana()
	hero.cooldowns["solo"] = 0.0
	hero.cast_solo()
	await _frames(2)
	var solo := (dungeon as Level).hud.solo
	_check(solo._active and not get_tree().paused, "le solo se joue sans mettre le jeu en pause")
	var hp_solo := GameState.hp
	hero._invuln = 0.0
	hero.take_hit(10, Vector3.ZERO)
	_check(GameState.hp == hp_solo, "héros invincible pendant le solo")
	var lane_keys: Array[int] = []
	for lane in 4:
		lane_keys.append(int((InputMap.action_get_events("solo_lane_%d" % lane)[0] as InputEventKey).physical_keycode))
	var expected: Array[int] = [KEY_1, KEY_2, KEY_3, KEY_4]
	_check(lane_keys == expected, "le solo se joue avec les touches 1 2 3 4")
	solo._hits = Balance.SOLO_NOTES
	solo._finish()
	_check(not hero.casting_solo, "fin du solo, le héros redevient vulnérable")
	# On élimine tout le monde, boss compris.
	var xp_before := GameState.stats.xp
	for n in get_tree().get_nodes_in_group("enemies"):
		var e := n as Enemy
		e.take_damage(9999, e.global_position + Vector3(1, 0, 0))
	await _frames(10)
	_check(GameState.stats.xp > xp_before, "les ennemis rapportent de l'XP")
	_check(GameState.quest_state("plumeau") == QuestDB.State.OBJECTIVE_DONE, "boss vaincu → objectif accompli")
	await get_tree().create_timer(3.2).timeout
	_check(_count_portals(dungeon) == 2, "portail de retour apparu")
	dungeon.queue_free()
	await _frames(5)
	GameState.run_dialogue_action("turn_in:plumeau")
	_check(GameState.quest_state("plumeau") == QuestDB.State.TURNED_IN, "quête rendue")
	_check(GameState.inventory.has("pendentif_plume"), "récompense : pendentif reçu")
	_check(GameState.has_save(), "partie sauvegardée")
	var level := GameState.stats.level
	_check(GameState.load_game() and GameState.stats.level == level, "chargement de la sauvegarde")


func _count_portals(root: Node) -> int:
	var count := 1 if root is Portal else 0
	for child in root.get_children():
		count += _count_portals(child)
	return count
