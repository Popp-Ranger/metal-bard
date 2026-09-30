extends Node
## Test de fumée automatisé. Lancer (sans fenêtre) :
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . res://tests/smoke_test.tscn
## Code de sortie 0 = tout va bien, 1 = au moins un échec.

var _failures := 0


func _ready() -> void:
	await get_tree().process_frame
	_test_rules()
	_test_generator()
	_test_audio()
	await _test_characters()
	await _test_quest_flow()
	await _test_new_features()
	if _failures == 0:
		print("SMOKE TEST : OK")
	else:
		printerr("SMOKE TEST : %d échec(s)" % _failures)
	Sfx.stop_ambience()
	Sfx._ambience.stream = null
	await get_tree().create_timer(0.2).timeout # laisse le serveur audio libérer la musique
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
	var cha_before := GameState.ability("CHA")
	_check(GameState.spend_point("CHA") and GameState.ability("CHA") == cha_before + 1, "dépense d'un point en CHA")
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
	var music := Sfx._ambience.stream as AudioStreamMP3
	_check(music != null and music.loop and music.get_length() > 30.0,
		"musique de la taverne chargée et en boucle (%.0f s)" % (music.get_length() if music else 0.0))
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
	var dungeon_music := Sfx._ambience.stream as AudioStreamMP3
	_check(dungeon_music != null and dungeon_music.loop and dungeon_music.resource_path.ends_with("dungeon_theme.mp3"),
		"musique du donjon chargée et en boucle")
	dungeon_music = null
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
	# --- Talents actifs : chacun se lance sans erreur et produit son effet. ---
	GameState.talent_points = 20
	for id in TalentDB.all_ids():
		GameState.learn_talent(id)
	_check(GameState.talents.size() == 20, "les 20 talents peuvent être appris dans l'ordre")
	var victims: Array[Enemy] = []
	for n in get_tree().get_nodes_in_group("enemies"):
		var e := n as Enemy
		if not e.is_boss and victims.size() < 3:
			e.hp = 5000
			e.max_hp = 5000
			victims.append(e)
	var place_victims := func() -> void:
		for i in victims.size():
			victims[i].global_position = hero.global_position + Vector3(2.0 + i, 0, 0.5 * i)
			victims[i].exit_trance()
			victims[i].state = Enemy.State.CHASE
	var actives: Array[String] = []
	for id in TalentDB.all_ids():
		if TalentDB.is_active(id) and id != "solo_endiable" and id != "ballade_reparatrice":
			actives.append(id)
	var cast_ok := true
	for id in actives:
		place_victims.call()
		GameState.mana = GameState.max_mana()
		hero.cooldowns[id] = 0.0
		hero.aim_point = hero.global_position + Vector3(3, 0, 0)
		hero.facing = Vector3(1, 0, 0)
		if not hero.talents_caster.cast(id):
			cast_ok = false
			printerr("    le talent %s n'a pas pu être lancé" % id)
		await _frames(3)
		if id == "stage_diving":
			await get_tree().create_timer(0.8).timeout
	_check(cast_ok, "les 8 autres talents actifs se lancent")
	await get_tree().create_timer(1.5).timeout
	# Ballade réparatrice : mini-jeu sur le solo extrait de la musique de la taverne.
	var chart := SoloMinigame.ballade_chart()
	var chart_notes: Array = chart.get("notes", [])
	_check(chart_notes.size() >= 15 and is_equal_approx(float(chart.get("duration", 0.0)), 10.0),
		"partition du solo de la taverne : %d notes sur 10 s" % chart_notes.size())
	GameState.mana = GameState.max_mana()
	hero.cooldowns["ballade_reparatrice"] = 0.0
	hero.talents_caster.cast("ballade_reparatrice")
	await _frames(2)
	var ballade_solo := (dungeon as Level).hud.solo
	_check(ballade_solo._active and ballade_solo.mode == "ballade" and ballade_solo._notes.size() == chart_notes.size()
		and hero.planted and Sfx.clip_playing(), "Ballade : mini-jeu lancé sur l'extrait musical, héros planté")
	GameState.hp = 1
	for k in chart_notes.size():
		Events.solo_note_hit.emit("ballade", k + 1)
	var expected_heal := roundi(GameState.max_hp() * Balance.BALLADE_HEAL_TOTAL / chart_notes.size()) * chart_notes.size()
	_check(absi(GameState.hp - 1 - expected_heal) <= chart_notes.size(), "solo sans faute ≈ 90 %% des PV max soignés (%d PV)" % (GameState.hp - 1))
	ballade_solo._hits = 3
	ballade_solo._finish()
	var ballade_cd := 12.0 * Balance.MINIGAME_FAIL_COOLDOWN_MULT * GameState.cooldown_multiplier()
	_check(not hero.planted and absf(float(hero.cooldowns["ballade_reparatrice"]) - ballade_cd) < 0.2,
		"notes ratées : recharge ×2,5 (%.1f s)" % float(hero.cooldowns["ballade_reparatrice"]))
	await _frames(2)
	# Bouclier du Mur de Larsen.
	hero.talents_caster.set_shield(20)
	var hp_shield := GameState.hp
	hero._invuln = 0.0
	hero.take_hit(8, Vector3.ZERO)
	_check(GameState.hp == hp_shield and GameState.shield < 20, "le Mur de Larsen absorbe les dégâts")
	hero.talents_caster.set_shield(0)
	# Growl : fuite.
	place_victims.call()
	hero.cooldowns["growl"] = 0.0
	GameState.mana = GameState.max_mana()
	hero.talents_caster.cast("growl")
	_check(victims[0].state == Enemy.State.FEAR, "Growl de l'Abîme : les ennemis fuient")
	# Solo endiablé : transe tant que les notes sont réussies, brisée à la 1re fausse note.
	place_victims.call()
	hero.cooldowns["solo_endiable"] = 0.0
	GameState.mana = GameState.max_mana()
	hero.talents_caster.cast("solo_endiable")
	await _frames(3)
	var frenzy_solo := (dungeon as Level).hud.solo
	_check(frenzy_solo._active and frenzy_solo.mode == "endiable" and frenzy_solo._notes.size() == 16,
		"Solo endiablé : mini-jeu de 16 notes (Maître du tempo)")
	_check(victims[0].is_in_trance() and not get_tree().paused, "les ennemis proches headbanguent, figés")
	var trance_pos := victims[1].global_position
	await get_tree().create_timer(0.5).timeout
	_check(victims[1].global_position.distance_to(trance_pos) < 0.05, "en transe, ils ne bougent plus")
	await get_tree().create_timer(2.5).timeout # aucune touche pressée : la 1re note est ratée
	_check(not frenzy_solo._active and not victims[0].is_in_trance() and not hero.talents_caster.in_frenzy,
		"une fausse note brise la transe")
	for e in victims:
		e.hp = 1
	# On élimine tous les ennemis (sauf Gloubah, qui attend de parler).
	var xp_before := GameState.stats.xp
	var dlg := (dungeon as Level).hud.dialogue
	var rats := 0
	var rat_hp_ok := true
	for n in get_tree().get_nodes_in_group("enemies"):
		var e := n as Enemy
		if e is Rat:
			rats += 1
			rat_hp_ok = rat_hp_ok and (e.max_hp == 3 or e.max_hp == 5000) # 5000 : rats pris comme cibles plus haut
		if not e.is_boss:
			e.take_damage(9999, e.global_position + Vector3(1, 0, 0))
	await _frames(10)
	_check(rats > 0 and rat_hp_ok, "des rats (3 PV) grouillent dans le premier donjon (%d)" % rats)
	_check(GameState.stats.xp > xp_before, "les ennemis rapportent de l'XP")
	_check(int(GameState.run.get("kills", 0)) > 10 and int(GameState.run.get("dealt", 0)) > 0, "compteur de victimes et dégâts infligés")
	# Gloubah interpelle le héros quand il arrive à portée.
	var d_level := dungeon as Node
	var boss: FrogBoss = d_level.get("boss")
	hero.global_position = boss.global_position + Vector3(4.0, 0, 4.0)
	await _frames(5)
	_check(dlg.visible and boss.passive, "Gloubah engage la conversation au lieu d'attaquer")
	dlg.close()
	# Réponse « il est kiki » : amicale, clé donnée, double XP, pas de combat.
	var xp_friend := GameState.stats.xp
	GameState.run_dialogue_action("story:gloubah_friend")
	await _frames(3)
	_check(boss.friendly and bool(d_level.get("_has_key")) and GameState.stats.xp >= xp_friend + boss.xp_reward * 2,
		"« il est kiki » : Gloubah amicale, clé offerte, XP doublée")
	d_level.call("_try_open_cage")
	_check(GameState.quest_state("plumeau") == QuestDB.State.OBJECTIVE_DONE, "cage ouverte avec la clé → objectif accompli")
	await get_tree().create_timer(2.4).timeout
	_check(_count_portals(dungeon) == 2, "portail de retour apparu")
	var recap_portal: Portal = null
	for c in dungeon.get_children():
		if c is Portal and (c as Portal).prompt.begins_with("Retourner"):
			recap_portal = c
	if recap_portal != null:
		recap_portal.on_enter.call()
	await _frames(2)
	var d_hud := (dungeon as Level).hud
	_check(d_hud.is_recap_open() and Hud.recap_text().contains("Dégâts subis"), "récapitulatif du donjon affiché")
	get_tree().paused = false
	dungeon.queue_free()
	await _frames(5)
	GameState.run_dialogue_action("turn_in:plumeau")
	_check(GameState.quest_state("plumeau") == QuestDB.State.TURNED_IN, "quête rendue")
	_check(GameState.inventory.has("pendentif_plume"), "récompense : pendentif reçu")
	_check(GameState.has_save(), "partie sauvegardée")
	var level := GameState.stats.level
	_check(GameState.load_game() and GameState.stats.level == level, "chargement de la sauvegarde")
	await _test_boss_fight_and_surrender()


## Autres issues du dialogue de Gloubah : combat (clé à ramasser) et reddition (cage).
func _test_boss_fight_and_surrender() -> void:
	GameState.new_game()
	GameState.run_dialogue_action("accept:plumeau")
	var dungeon: Node = load("res://scenes/dungeon.tscn").instantiate()
	add_child(dungeon)
	await _frames(20)
	var boss: FrogBoss = dungeon.get("boss")
	GameState.run_dialogue_action("story:gloubah_fight")
	_check(not boss.passive and boss.state != Enemy.State.WANDER, "« combat à mort » : Gloubah attaque")
	boss.take_damage(99999, boss.global_position + Vector3(1, 0, 0))
	await _frames(5)
	var key: Interactable = null
	for n in get_tree().get_nodes_in_group("interactable"):
		var i := n as Interactable
		if i != null and i.prompt.begins_with("Ramasser la clé"):
			key = i
	_check(key != null and not bool(dungeon.get("_has_key")), "Gloubah vaincue : la clé tombe au sol")
	if key != null:
		key.interact(null)
	_check(bool(dungeon.get("_has_key")), "clé ramassée ([E] ou clic)")
	GameState.run_dialogue_action("story:gloubah_surrender")
	var hero := get_tree().get_first_node_in_group("hero") as Hero
	var prison: Vector3 = dungeon.get("_prison_pos")
	_check(hero.captive and hero.global_position.distance_to(prison) < 0.5, "« je me rends » : enfermé dans la cage vide")
	await _frames(10)
	_check(hero.global_position.distance_to(prison) < 0.5, "prisonnier : impossible de bouger")
	get_tree().paused = false
	dungeon.queue_free()
	await _frames(5)


func _test_new_features() -> void:
	print("[Taverne, intro, sauvegardes, coop, objets]")
	GameState.new_game()
	_check(ItemDB.common_drops().size() == 5 and ItemDB.potion_price() == 25 and ItemDB.get_item("couronne_gloubah").get("name", "") != "",
		"objets lus dans data/items.json (5 reliques de butin)")
	var tavern: Node = load("res://scenes/tavern.tscn").instantiate()
	add_child(tavern)
	await _frames(20)
	var t_level := tavern as Level
	var hero := t_level.hero
	_check(t_level.hud._gold_label.text.ends_with("médiators"), "la monnaie : les médiators")
	# Portes verrouillées.
	var locked := false
	for n in get_tree().get_nodes_in_group("interactable"):
		var i := n as Interactable
		if i != null and i.prompt == "Porte verrouillée":
			locked = true
	_check(locked, "les portes de la taverne sont verrouillées")
	# Glissade sur les genoux : 5 m, intouchable, recharge 20 s.
	hero.global_position = Vector3(-3.0, 0, 4.0)
	hero.facing = Vector3(1, 0, 0)
	var from := hero.global_position
	hero.dash()
	await _frames(3)
	var hp0 := GameState.hp
	hero._invuln = 0.0
	hero.take_hit(10, Vector3.ZERO)
	_check(hero.dashing and GameState.hp == hp0, "glissade : aucune attaque ne touche")
	await get_tree().create_timer(0.8).timeout
	var moved := hero.global_position.distance_to(from)
	_check(moved > 1.0 and moved <= Balance.DASH_DISTANCE + 0.05 and not hero.dashing, "glissade de %.1f m (5 m max)" % moved)
	_check(float(hero.cooldowns["dash"]) > Balance.DASH_COOLDOWN * GameState.cooldown_multiplier() - 1.5,
		"recharge de la glissade : 20 s")
	hero.dodged()
	_check(hero.model._pose == "hop", "esquive passive : saut sur une jambe façon Angus Young")
	# Clients : jamais plus de 2 debout ; chaises déplacées.
	var patrons: Array[Patron] = []
	for c in tavern.get_children():
		if c is Patron:
			patrons.append(c)
			(c as Patron)._timer = 0.0
	var max_up := 0
	var chair_moved := false
	for f in 60:
		await get_tree().physics_frame
		max_up = maxi(max_up, int(tavern.call("standing_count")))
		for p in patrons:
			if p.chair != null and p.chair.position.distance_to(p._chair_home) > 0.2:
				chair_moved = true
	_check(max_up >= 1 and max_up <= 2, "au plus 2 clients debout à la fois (%d)" % max_up)
	_check(chair_moved, "les clients reculent leur chaise pour se lever")
	var zarathos: Npc = null
	for c in tavern.get_children():
		if c is Npc and (c as Npc).npc_id == "zarathos":
			zarathos = c
	_check(zarathos != null and zarathos.wander_radius > 0.0, "Zarathos fait les cent pas près de son portail")
	var demon_found := false
	for c in tavern.get_children():
		demon_found = demon_found or c is DemonPortal
	_check(demon_found, "portail démoniaque dans le sous-sol")
	# Sous-sol (zone décalée en x = 70) : décibels illimités.
	hero.global_position = Vector3(70.0 - 9.0, 0, -3.0)
	await _frames(3)
	GameState.mana = 5.0
	var spent := GameState.spend_mana(40.0)
	_check(spent and GameState.infinite_mana and GameState.mana >= GameState.max_mana() - 0.01, "sous-sol : décibels toujours au maximum")
	# Réinitialisation des talents (l'Inconnue encapuchonnée).
	GameState.talent_points = 3
	GameState.learn_talent("ballade_reparatrice")
	GameState.learn_talent("rappel")
	GameState.run_dialogue_action("reset_talents")
	_check(GameState.talents.is_empty() and GameState.talent_points == 3 and GameState.spell_slots[0] == "", "l'Inconnue réinitialise l'arbre de talents")
	# Sauvegardes : emplacement manuel, lieu, chargement ; pas en combat.
	GameState.location = t_level.save_location()
	_check(GameState.save_to_slot(1) and not GameState.slot_summary(1).is_empty(), "sauvegarde dans l'emplacement 1")
	var lvl := GameState.stats.level
	_check(GameState.load_slot(1) and GameState.stats.level == lvl and GameState.resume_scene() == Router.TAVERN
		and GameState.pending_spawn != Vector3.INF, "chargement : retour à la taverne, à la même position")
	GameState.pending_spawn = Vector3.INF
	_check(not t_level.in_combat(), "hors combat : sauvegarde autorisée")
	tavern.queue_free()
	await _frames(5)
	DirAccess.remove_absolute(GameState.slot_path(1))
	# Coop : code d'invitation, hébergement.
	var code := Net.encode_code("86.201.14.7", Net.PORT)
	var back := Net.decode_code(code.to_lower())
	_check(code.length() == 11 and back.get("ip", "") == "86.201.14.7" and int(back.get("port", 0)) == Net.PORT,
		"code d'invitation %s ↔ 86.201.14.7:%d" % [code, Net.PORT])
	_check(Net.decode_code("pas-un-code").is_empty(), "code invalide refusé")
	var err := Net.host()
	_check(err.is_empty() and Net.is_host() and Net.player_count() == 1, "partie ouverte en coop (hôte)")
	Net.leave()
	_check(not Net.is_online(), "partie coop fermée")
	# Intro : cimetière, lune de sang, route d'environ 40 s.
	var intro: Node = load("res://scenes/intro.tscn").instantiate()
	add_child(intro)
	await _frames(10)
	var i_level := intro as Level
	var road_time := 222.0 / Balance.HERO_SPEED
	_check(i_level.hero.captive and bool(intro.get("_cinematic")), "intro : cinématique de la lune de sang, héros figé")
	_check(road_time > 35.0 and road_time < 45.0, "route pavée d'environ 40 s de marche (%.0f s)" % road_time)
	intro.set("_cinematic", false)
	i_level.hero.captive = false
	intro.call("_lightning")
	await get_tree().create_timer(1.5).timeout
	_check(true, "un éclair frappe le décor sans erreur")
	var intro_lines: Array = DialogueDB.get_dialogue("intro_hero")["lines"]
	_check(str(intro_lines[1][1]) == "Et si j'allais m'en jeter un !", "réplique du héros seul")
	intro.queue_free()
	await _frames(5)
	get_tree().paused = false


func _count_portals(root: Node) -> int:
	var count := 1 if root is Portal else 0
	for child in root.get_children():
		count += _count_portals(child)
	return count


func _test_audio() -> void:
	print("[Audio]")
	var ok := true
	for channel: Array in Sfx.CHANNELS:
		if AudioServer.get_bus_index(str(channel[0])) == -1:
			ok = false
	_check(ok, "3 canaux audio : Musique, Sorts et effets, Dialogues")
	_check(Sfx._ambience.bus == Sfx.BUS_MUSIC and Sfx._players[0].bus == Sfx.BUS_SFX
		and Sfx._voice.bus == Sfx.BUS_DIALOGUE, "chaque lecteur est branché sur son canal")
	# Réglages indépendants + sauvegarde / rechargement (on restaure ensuite ceux du joueur).
	var saved := {}
	for channel: Array in Sfx.CHANNELS:
		saved[channel[0]] = Sfx.get_volume(str(channel[0]))
	Sfx.set_volume(Sfx.BUS_MUSIC, 0.25)
	Sfx.set_volume(Sfx.BUS_SFX, 1.0)
	Sfx.set_volume(Sfx.BUS_DIALOGUE, 0.0)
	Sfx.save_settings()
	Sfx.set_volume(Sfx.BUS_MUSIC, 0.9)
	Sfx.load_settings()
	var music_idx := AudioServer.get_bus_index(Sfx.BUS_MUSIC)
	_check(is_equal_approx(Sfx.get_volume(Sfx.BUS_MUSIC), 0.25)
		and is_equal_approx(AudioServer.get_bus_volume_db(music_idx), linear_to_db(0.25)), "volume musique réglé et rechargé")
	_check(AudioServer.is_bus_mute(AudioServer.get_bus_index(Sfx.BUS_DIALOGUE))
		and not AudioServer.is_bus_mute(AudioServer.get_bus_index(Sfx.BUS_SFX)), "canaux indépendants (dialogues muets, effets actifs)")
	for bus_name: String in saved:
		Sfx.set_volume(bus_name, float(saved[bus_name]))
	Sfx.save_settings()
	_check(Sfx._streams.has("voice_0") and Sfx._streams.has("voice_3"), "voix des dialogues générées")


func _test_characters() -> void:
	print("[Races, talents, création de personnage]")
	GameState.new_game()
	_check(GameState.talent_points == 1, "1 point de talent au niveau 1")
	_check(GameState.talent_block_reason("rappel") != "", "palier 2 verrouillé tant que le palier 1 n'est pas appris")
	_check(GameState.learn_talent("ballade_reparatrice") and GameState.spell_slots[0] == "ballade_reparatrice"
		and GameState.talent_points == 0, "talent actif appris → placé sur la touche 4")
	_check(not GameState.learn_talent("rappel"), "plus de point : impossible d'apprendre")
	GameState.add_xp(400)
	_check(GameState.talent_points == 1, "+1 point de talent en montant de niveau")
	GameState.cycle_slot("ballade_reparatrice")
	_check(GameState.spell_slots[1] == "ballade_reparatrice" and GameState.spell_slots[0] == "", "changement de touche (4 → 5)")
	# Races : taille et bonus.
	GameState.new_game()
	var base_hp := GameState.max_hp()
	GameState.appearance["race"] = "ogre"
	_check(GameState.max_hp() > base_hp + 10, "Ogre : plus de points de vie (Colosse)")
	GameState.appearance["race"] = "demon"
	_check(GameState.ability("CHA") == 18 and is_equal_approx(GameState.spell_power(), 1.1), "Démon : +2 CHA et +10 % aux sorts")
	GameState.appearance["race"] = "humain"
	# Écran de création : toutes les combinaisons de race / sexe / options se construisent.
	var creation: Node = load("res://scenes/character_creation.tscn").instantiate()
	add_child(creation)
	await _frames(3)
	var heights := {}
	var built := true
	for race_id: String in RaceDB.RACE_ORDER:
		for sex: String in ["m", "f"]:
			for option in 4:
				creation.appearance = {"sex": sex, "race": race_id, "horns": option % 3, "tusks": option % 3,
					"beard": option % 3, "hair": option, "hair_color": option}
				creation._refresh()
				await get_tree().process_frame
				var model: HeroModel = creation._model
				if model == null or model._torso == null or model._head.get_child_count() < 6:
					built = false
			heights[race_id] = creation._model.height()
	_check(built, "48 apparences construites (6 races × 2 sexes × 4 variantes)")
	_check(is_equal_approx(float(heights["ogre"]), 2.5) and is_equal_approx(float(heights["troll"]), 2.2)
		and is_equal_approx(float(heights["orc"]), 2.0) and is_equal_approx(float(heights["squelette"]), 1.8),
		"tailles : squelette 1,8 m, orc 2 m, troll 2,2 m, ogre 2,5 m")
	creation._name_edit.text = "Lemmy"
	creation.appearance = {"sex": "f", "race": "troll", "horns": 0, "tusks": 1, "beard": 0, "hair": 3, "hair_color": 4}
	GameState.hero_name = creation._name_edit.text
	GameState.appearance = creation.appearance.duplicate()
	_check(DialogueDB.hero() == "Lemmy" and RaceDB.title(GameState.appearance) == "Barde trollesse"
		and GameState.g("le barde", "la barde") == "la barde", "nom et genre repris dans les dialogues")
	creation.queue_free()
	await _frames(3)
