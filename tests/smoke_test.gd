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
	await _test_town_portal()
	await _test_click_move()
	await _test_remote_spell_fx()
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
	var sealed_ok := true
	for s in 200:
		var g2 := DungeonGenerator.new()
		g2.generate_sealed(s * 4513 + 1, 10, 5)
		sealed_ok = sealed_ok and g2.boss_room_sealable(5) and g2.all_rooms_reachable_without_boss_room()
	_check(sealed_ok, "200 donjons : salle du boss toujours scellable, le reste accessible sans elle")


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
	# Portes : salles fermées plongées dans le noir, occupants endormis.
	var dg := dungeon as Node
	var door_list: Array = dg.get("doors")
	_check(door_list.size() >= dg.get("gen").rooms.size(), "portes à l'entrée des salles (%d)" % door_list.size())
	var covers: Dictionary = dg.get("_covers")
	var dormant := 0
	for c in dg.get_children():
		if c is Enemy and (c as Enemy).dormant:
			dormant += 1
	_check(covers.size() >= dg.get("gen").rooms.size() - 2 and dormant >= 8,
		"salles fermées sombres, %d ennemis endormis derrière les portes" % dormant)
	var boss_door := -1
	var normal_door := -1
	for i in door_list.size():
		if bool(door_list[i]["locked"]):
			boss_door = i
		elif normal_door < 0 and int(door_list[i]["room"]) != dg.get("gen").start_room:
			normal_door = i
	var normal_room := int(door_list[normal_door]["room"])
	dg.call("_on_door", normal_door)
	await _frames(2)
	_check(bool(door_list[normal_door]["open"]) and not covers.has(normal_room), "ouvrir une porte éclaire la salle")
	dg.call("_on_door", boss_door)
	_check(boss_door >= 0 and not bool(door_list[boss_door]["open"]), "salle du boss fermée à clé")
	var chief_sk: Skeleton = dg.get("chief")
	_check(chief_sk != null and chief_sk.chief and is_equal_approx(chief_sk.model.scale.x, 1.25) and chief_sk.display_name == "Chef des squelettes",
		"chef des squelettes 25 % plus grand, en peau de loup")
	var room_enemies: Dictionary = dg.get("_room_enemies")
	for room: int in room_enemies:
		if (room_enemies[room] as Array).has(chief_sk):
			dg.call("_reveal_room", room)
	chief_sk.take_damage(99999, chief_sk.global_position + Vector3(0.1, 0, 0), 0.0, false, "phys")
	await _frames(3)
	var boss_key: Interactable = null
	for c in dg.get_children():
		if c is Interactable and (c as Interactable).prompt.contains("clé de la salle du boss"):
			boss_key = c
	_check(boss_key != null, "le chef laisse tomber la clé de la salle du boss")
	boss_key.interact(null)
	dg.call("_on_door", boss_door)
	_check(bool(door_list[boss_door]["open"]), "la clé du chef ouvre la salle du boss")
	GameState.stats.xp = 0 # l'XP du chef ne doit pas faire monter de niveau (dB remplis) pendant la suite
	# On découvre tout le donjon pour la suite du test.
	for i in dg.get("gen").rooms.size():
		dg.call("_reveal_room", i)
	await _frames(2)
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
		GameState.hp = GameState.max_hp() # les squelettes réveillés ne doivent pas tuer le héros pendant le test
		hero.cooldowns["riff"] = 0.0
		hero.cast_riff()
		await get_tree().create_timer(Balance.RIFF_BEAT).timeout
	_check(hero.riff_stack == Balance.RIFF_MAX_STACKS, "5 riffs en rythme → combo au maximum")
	await get_tree().create_timer(Balance.RIFF_BEAT * 2.5).timeout
	GameState.hp = GameState.max_hp()
	hero.cooldowns["riff"] = 0.0
	hero.cast_riff()
	_check(hero.riff_stack == 1, "riff à contretemps → combo remis à ×1")
	_check(absf(float(hero.cooldowns["riff"]) - 3.0) < 0.05, "Riff électrique : recharge de 3 s")
	_check(Sfx._streams.has("riff") and (Sfx._streams["riff"] as AudioStream).resource_path.ends_with("riff_electrique.wav"),
		"Riff électrique : son riff electrique.wav")
	_check(Sfx._thunders.size() == 2 and Sfx._streams.has("thunder_0") and Sfx._streams.has("thunder_1"),
		"éclairs : short_lightning.mp3 et short_thunder.mp3 tirés au hasard")
	# Proportions et mains : cinq doigts par main, tête ≈ 1/7,5 de la taille.
	_check(hero.model._fingers_l.size() == 5 and hero.model._fingers_r.size() == 5
		and (hero.model._fingers_r[1] as Array).size() == 3 and (hero.model._fingers_r[0] as Array).size() == 2,
		"mains modélisées : 5 doigts (3 phalanges, pouce à 2)")
	# Coop : +33 % d'ennemis et +25 % de PV par joueur supplémentaire.
	_check(is_equal_approx(Balance.coop_enemy_count_mult(1), 1.0) and is_equal_approx(Balance.coop_enemy_count_mult(6), 2.65)
		and is_equal_approx(Balance.coop_enemy_hp_mult(6), 2.25), "coop 6 joueurs : ennemis ×2,65, PV ×2,25")
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
	_check(int((InputMap.action_get_events("talents")[0] as InputEventKey).physical_keycode) == KEY_K
		and int((InputMap.action_get_events("town_portal")[0] as InputEventKey).physical_keycode) == KEY_T,
		"touches : K = arbre de talents, T = portail de retour")
	var foudre_times: Array[float] = []
	for n in solo._notes:
		foudre_times.append(float(n["time"]))
	var even := foudre_times.size() == 6
	for i in range(2, foudre_times.size()):
		even = even and absf((foudre_times[i] - foudre_times[i - 1]) - (foudre_times[1] - foudre_times[0])) < 0.01
	_check(even and solo._clip_source.ends_with("solo_de_la_foudre.mp3"),
		"Solo de la Foudre : 6 notes régulières sur solo_del_la_foudre.mp3")
	_check((Sfx._streams["solo_thunder"] as AudioStream).resource_path.ends_with("short_thunder.mp3")
		and (Sfx._streams["wave"] as AudioStream).resource_path.ends_with("ondes_de_chocs.wav"),
		"sons : éclairs du solo = short_thunder, onde de choc = ondes de chocs.wav")
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
	_check(chart_notes.size() >= 15 and str(chart.get("source", "")).ends_with("healing.wav") and float(chart.get("duration", 0.0)) > 8.0,
		"partition calée sur Healing.wav : %d notes sur %.1f s" % [chart_notes.size(), float(chart.get("duration", 0.0))])
	GameState.mana = GameState.max_mana()
	hero.cooldowns["ballade_reparatrice"] = 0.0
	hero.talents_caster.cast("ballade_reparatrice")
	await _frames(2)
	var ballade_solo := (dungeon as Level).hud.solo
	_check(ballade_solo._active and ballade_solo.mode == "ballade" and ballade_solo._notes.size() == chart_notes.size()
		and hero.planted, "Ballade : mini-jeu lancé, héros planté")
	await get_tree().create_timer(SoloMinigame.LEAD_TIME + 0.2).timeout
	_check(Sfx.clip_playing() and Sfx._clip.stream.resource_path.ends_with("healing.wav"),
		"Healing.wav démarre quand la première note atteint la cible")
	GameState.hp = 1
	for k in chart_notes.size():
		Events.solo_note_hit.emit("ballade", k + 1)
	_check(GameState.hp >= roundi(GameState.max_hp() * 0.8), "solo sans faute : la barre de vie remonte presque entièrement (%d / %d PV)" % [GameState.hp, GameState.max_hp()])
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
	# Un client va vraiment jusqu'au comptoir, prend une chope et revient s'asseoir.
	var walker_p: Patron = null
	for p in patrons:
		if p.mode == Patron.Mode.TO_BAR and not p.wheelchair:
			walker_p = p
	var reached_bar := false
	var back_seated := false
	if walker_p != null:
		walker_p.walk_speed = 12.0
		walker_p.walker.speed = 12.0
		for f in 600:
			await get_tree().physics_frame
			if walker_p.mode == Patron.Mode.AT_BAR:
				reached_bar = true
				walker_p._timer = 0.0
			if reached_bar and walker_p.walker.walking:
				walker_p.walker.speed = 12.0
			if reached_bar and walker_p.mode == Patron.Mode.SEATED:
				back_seated = walker_p.has_mug()
				break
	_check(reached_bar, "un client marche jusqu'au comptoir")
	_check(back_seated, "il revient s'asseoir à sa place avec une chope")
	var zarathos: Npc = null
	for c in tavern.get_children():
		if c is Npc and (c as Npc).npc_id == "zarathos":
			zarathos = c
	_check(zarathos != null and zarathos.wander_radius > 0.0, "Zarathos fait les cent pas près de son portail")
	# Chambre : payer ne soigne plus, il faut se coucher sur le lit (1 PV → 100 % en 10 s).
	var t_tavern := tavern as Node
	GameState.flags.erase("room_paid")
	GameState.gold = 500
	GameState.hp = 1
	GameState.run_dialogue_action("rest")
	_check(GameState.hp == 1 and bool(GameState.flags.get("room_paid", false)), "louer la chambre ne soigne pas immédiatement")
	var bed: Interactable = t_tavern.get("bed_interact")
	var hp_max := GameState.max_hp()
	bed.interact(hero)
	_check(hero.resting and absf(hero.model.rotation.x + PI * 0.5) < 0.01, "clic sur le lit : le héros s'allonge")
	await get_tree().create_timer(5.0).timeout
	var half_hp := GameState.hp
	_check(half_hp > hp_max * 0.35 and half_hp < hp_max * 0.65, "vie régénérée progressivement (%d / %d après 5 s)" % [half_hp, hp_max])
	await get_tree().create_timer(5.5).timeout
	_check(GameState.hp == hp_max and not hero.resting and not GameState.flags.has("room_paid"),
		"10 s au lit : vie pleine, le héros se relève")
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
	Net.upnp_enabled = false # les tests ne touchent pas à la box
	var err := Net.host()
	_check(err.is_empty() and Net.is_host() and Net.player_count() == 1, "partie ouverte en coop (hôte)")
	Net.leave()
	_check(not Net.is_online(), "partie coop fermée")
	# Intro : cimetière, lune de sang, route sinueuse d'environ 20 s.
	var intro: Node = load("res://scenes/intro.tscn").instantiate()
	add_child(intro)
	await _frames(10)
	var i_level := intro as Level
	var road_len: float = (intro.get_script() as Script).get_script_constant_map()["ROAD_LENGTH"]
	var road_time := road_len / Balance.HERO_SPEED
	var max_turn := 0.0
	for s in range(0, int(road_len), 2):
		var dir: Vector3 = intro.call("road_dir", float(s))
		max_turn = maxf(max_turn, dir.angle_to(IsoCamera.SCREEN_UP))
	_check(i_level.hero.captive and bool(intro.get("_cinematic")), "intro : cinématique de la lune de sang, héros figé")
	_check(Sfx.storm_playing() and Sfx._strikes.size() >= 5, "intro : musique d'orage lightning_menu.mp3 (%d coups de tonnerre repérés)" % Sfx._strikes.size())
	_check(road_time > 17.0 and road_time < 23.0, "route pavée d'environ 20 s de marche (%.0f s)" % road_time)
	_check(max_turn > 0.9, "route sinueuse : virages jusqu'à %.0f°" % rad_to_deg(max_turn))
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
	_check(str(creation.appearance.get("preset", "")) == "riffald" and creation._name_edit.text == "Riffald"
		and not creation._name_edit.editable and int(creation.appearance["hair_color"]) == 5 and int(creation.appearance["beard"]) == 3,
		"création : Riffald prédéfini proposé par défaut (roux flamboyant, rasé, nom verrouillé)")
	var rig: HeroModel = creation._model
	_check(rig._skin != null and rig._skin.skeleton != null and rig._skin.skeleton.get_bone_count() == 17,
		"Riffald : modèle Blender à squelette (17 os)")
	_check(rig._neck_scale < 1.0 and rig._strings_mat != null and rig._guitar.find_children("*", "MeshInstance3D", true, false).size() >= 1,
		"guitare des héros importée de Blender (cordes lumineuses)")
	var sk := rig._skin.skeleton
	var knee_before := sk.get_bone_global_pose(sk.find_bone("shin.L")).origin
	rig.move_speed = 5.5
	rig.set_moving(true)
	for f in 20:
		await get_tree().process_frame
	_check(sk.get_bone_global_pose(sk.find_bone("shin.L")).origin.distance_to(knee_before) > 0.03, "Riffald : les jambes du modèle suivent la foulée")
	var anim := rig._anim
	_check(anim != null and anim.tree.active and anim.lengths.size() >= 15 and anim.lengths.has("run") and anim.lengths.has("sleep"),
		"Riffald : animations Mixamo (transférées dans Blender) jouées par un AnimationTree")
	# IK après l'animation : la main du manche (os « hand.R ») est posée sur la case de la guitare.
	# La pose modifiée n'existe qu'au moment du rendu : on la lit au signal skeleton_updated.
	await sk.skeleton_updated
	var gt := anim._skel_to_model().affine_inverse() * rig._guitar.transform.orthonormalized()
	var fret_target := gt * Vector3(-0.02, 0.42 * rig._neck_scale, -0.025)
	var hand_err := (sk.get_bone_global_pose(sk.find_bone("hand.R")).origin - fret_target).length()
	_check(hand_err < 0.03, "Riffald : la main du manche reste sur la guitare (écart %.3f m)" % hand_err)
	_check(anim._playback.get_current_node() == "loco"
		and float(anim.tree.get("parameters/sm/loco/pace/scale")) > 1.0, "Riffald : course accélérée à la vitesse du héros")
	# Actions : coups alternés (guitare empoignée), sorts, lit, mort.
	rig.set_moving(false)
	rig.swing()
	var first := anim.state
	await get_tree().create_timer(0.2).timeout
	await sk.skeleton_updated
	var hands_mid := (sk.get_bone_global_pose(sk.find_bone("hand.L")).origin + sk.get_bone_global_pose(sk.find_bone("hand.R")).origin) * 0.5
	var grip_err := (anim._skel_to_model() * hands_mid).distance_to(rig._guitar.transform * Vector3(0, HeroAnimator.GRIP, 0))
	_check(first == "smash" and float(anim._weights[2]) > 0.99 and grip_err < 0.05,
		"Riffald : frappe, guitare empoignée par le manche (écart %.3f m)" % grip_err)
	rig.swing()
	_check(anim.state == "slash", "Riffald : coups de guitare alternés (vertical puis diagonal)")
	await get_tree().create_timer(0.8).timeout
	_check(anim.state == "loco", "Riffald : retour au repos après la frappe")
	rig.act("area")
	_check(anim.state == "area", "Riffald : onde de choc = frappe du sol")
	rig.set_moving(true)
	await get_tree().create_timer(0.4).timeout
	_check(anim.state == "loco", "Riffald : se déplacer interrompt le sort")
	rig.set_moving(false)
	_check(rig.lie(true) and anim.state == "sleep", "Riffald : allongé sur le lit (animation)")
	rig.lie(false)
	rig.die()
	await _frames(5)
	rig.swing()
	_check(anim.state == "die" and anim._playback.get_current_node() == "die", "Riffald : mort, plus aucune action ensuite")
	rig.set_moving(false)
	creation._set_hero_mode(1)
	creation._refresh()
	_check(str(creation.appearance["preset"]) == "" and creation._name_edit.editable, "création : passage en personnage personnalisé")
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


## Portail bleu (T) et donjon persistant : on repart exactement où on était, rien n'a bougé.
func _test_town_portal() -> void:
	print("[Portail de retour et donjon persistant]")
	GameState.dungeon_seed = 4242
	GameState.dungeon_state = {}
	GameState.town_portal = {}
	GameState.active_quest = "plumeau"
	var d1: Node = load("res://scenes/dungeon.tscn").instantiate()
	add_child(d1)
	await _frames(10)
	var hero := get_tree().get_first_node_in_group("hero") as Hero
	var d1_doors: Array = d1.get("doors")
	var opened := -1
	for i in d1_doors.size():
		if not bool(d1_doors[i]["locked"]):
			opened = i
			break
	d1.call("_on_door", opened)
	var chief_sk: Skeleton = d1.get("chief")
	chief_sk.set_dormant(false)
	chief_sk.take_damage(99999, chief_sk.global_position + Vector3(0.1, 0, 0), 0.0, false, "phys")
	await _frames(3)
	GameState.stats.xp = 0
	hero.global_position += Vector3(1.0, 0, 0)
	Events.town_portal_requested.emit()
	await _frames(2)
	var tp: Array = GameState.town_portal.get("pos", [])
	var blue_ok := false
	for c in d1.get_children():
		if c is Portal and (c as Portal).blue:
			blue_ok = true
	_check(tp.size() == 2 and blue_ok, "touche T : portail bleu ouvert dans le donjon")
	var portal_pos := Vector3(float(tp[0]), 0, float(tp[1]))
	d1.call("_take_town_portal")
	d1.queue_free()
	await _frames(3)
	var tavern: Node = load("res://scenes/tavern.tscn").instantiate()
	add_child(tavern)
	await _frames(5)
	var bp: Portal = tavern.get("blue_portal")
	var t_hero := get_tree().get_first_node_in_group("hero") as Hero
	_check(bp != null and bp.blue and t_hero.global_position.distance_to(bp.global_position) < 2.5,
		"taverne : arrivée devant un portail bleu, à côté de celui de Zarathos")
	tavern.call("_on_enter_blue_portal")
	tavern.queue_free()
	await _frames(3)
	var d2: Node = load("res://scenes/dungeon.tscn").instantiate()
	add_child(d2)
	await _frames(10)
	var hero2 := get_tree().get_first_node_in_group("hero") as Hero
	_check(hero2.global_position.distance_to(portal_pos) < 2.0 and GameState.town_portal.is_empty(),
		"portail bleu repris : retour exactement là où on était")
	var d2_doors: Array = d2.get("doors")
	_check(d2.get("chief") == null and bool(d2_doors[opened]["open"]),
		"donjon persistant : chef toujours mort, porte toujours ouverte")
	d2.queue_free()
	GameState.dungeon_state = {}
	GameState.dungeon_seed = 0
	await _frames(3)


## Déplacement à la souris façon Diablo : aller au point cliqué, aller frapper un ennemi.
func _test_click_move() -> void:
	print("[Déplacement à la souris]")
	GameState.dungeon_seed = 777
	GameState.dungeon_state = {}
	GameState.town_portal = {}
	var d: Node = load("res://scenes/dungeon.tscn").instantiate()
	add_child(d)
	await _frames(10)
	for i in d.get("gen").rooms.size():
		d.call("_reveal_room", i)
	var hero := get_tree().get_first_node_in_group("hero") as Hero
	var from := hero.global_position
	var dest := from + IsoCamera.SCREEN_RIGHT * 3.0
	hero._click_mode = Hero.ClickMode.GROUND
	hero._click_hold = false
	hero.move_target = dest
	var marker := MoveMarker.spawn(d, dest)
	_check(marker != null and marker.is_inside_tree(), "zone lumineuse au sol à l'endroit cliqué")
	await get_tree().create_timer(1.2).timeout
	_check(hero.global_position.distance_to(dest) < 0.35 and hero._click_mode == Hero.ClickMode.NONE,
		"clic sur le sol : le héros marche jusqu'au point cliqué")
	var target: Enemy = null
	for e in hero.enemies():
		if not e.is_boss:
			target = e
			break
	target.hp = 500
	target.max_hp = 500
	target.process_mode = Node.PROCESS_MODE_DISABLED # cible immobile pour le test
	target.global_position = hero.global_position + IsoCamera.SCREEN_UP * 4.0
	hero._click_mode = Hero.ClickMode.ENEMY
	hero._click_node = target
	hero.cooldowns["attack"] = 0.0
	var swung := false
	for f in 100:
		await get_tree().physics_frame
		swung = swung or float(hero.cooldowns["attack"]) > 0.0
	_check(_flat(hero.global_position, target.global_position) < Balance.MELEE_RANGE + target.radius and swung,
		"clic sur un ennemi : le héros va au contact et frappe")
	d.queue_free()
	GameState.dungeon_state = {}
	GameState.dungeon_seed = 0
	await _frames(3)


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()



## Coop : chaque sort d'un autre joueur est rejoué chez soi (SpellFx), sans dégâts.
func _test_remote_spell_fx() -> void:
	print("[Sorts visibles par tous les joueurs]")
	GameState.dungeon_seed = 777
	GameState.dungeon_state = {}
	var d: Node = load("res://scenes/dungeon.tscn").instantiate()
	add_child(d)
	await _frames(10)
	for i in d.get("gen").rooms.size():
		d.call("_reveal_room", i)
	var hero := get_tree().get_first_node_in_group("hero") as Hero
	var other := RemoteHero.new()
	other.peer_id = 42
	other.profile = {"name": "Lemmy", "appearance": RaceDB.preset_appearance("riffald"), "level": 3}
	other.position = hero.global_position + Vector3(3, 0, 0)
	d.add_child(other)
	await _frames(2)
	var target: Enemy = null
	for e in hero.enemies():
		if not e.is_boss:
			target = e
			break
	target.global_position = other.global_position + Vector3(2, 0, 2)
	var hp_before := target.hp
	var p := other.global_position
	var q := target.global_position
	var fx := [
		["swing", {}], ["tuning", {"points": PackedVector3Array([p, q])}],
		["riff", {"from": p, "to": q, "stack": 3, "color": Color.GOLD}],
		["bolt", {"from": p, "to": q}], ["wave", {"pos": p, "radius": 5.0}],
		["shockwave", {"pos": p, "radius": 4.0, "sound": "boom"}],
		["storm", {"center": p, "ids": PackedInt32Array([target.net_id])}],
		["burst", {"points": PackedVector3Array([p]), "color": Color.GREEN, "amount": 4}],
		["phoenix", {"pos": p}], ["shield", {"on": true}], ["amps", {}],
		["wall_of_death", {"pos": p, "dir": Vector3.FORWARD}], ["stage_dive", {"from": p, "to": p + Vector3(3, 0, 0)}],
		["growl", {"pos": p}], ["speaker", {"pos": q, "yaw": 0.5}], ["pyro", {"pos": p, "yaw": 0.0}],
	]
	for entry: Array in fx:
		SpellFx.play(d, other, str(entry[0]), entry[1], true)
	await _frames(3)
	var kinds := {}
	for c in d.get_children():
		kinds[c.get_class() if c.get_script() == null else str(c.get_script().get_global_name())] = true
	var speaker_ok := false
	var pyro_ok := false
	for c in d.get_children():
		speaker_ok = speaker_ok or c is SpellFx.SpeakerFx
		pyro_ok = pyro_ok or c is SpellFx.PyroFx
	_check(kinds.has("ArcBolt") and kinds.has("Shockwave") and kinds.has("LightningStorm") and speaker_ok and pyro_ok,
		"sorts d'un autre joueur rejoués : éclairs, ondes, pluie d'éclairs, enceinte, pyrotechnie")
	_check(other._shield != null and other._shield.visible and other.find_children("*", "MeshInstance3D", true, false).size() > 20,
		"bouclier et amplis affichés sur le personnage de l'autre joueur")
	await get_tree().create_timer(1.5).timeout
	_check(target.hp == hp_before, "effets des autres joueurs purement visuels (aucun dégât en double)")
	SpellFx.play(d, other, "shield", {"on": false}, true)
	_check(not other._shield.visible, "la bulle de l'autre joueur disparaît quand elle éclate")
	d.queue_free()
	GameState.dungeon_state = {}
	GameState.dungeon_seed = 0
	await _frames(3)
