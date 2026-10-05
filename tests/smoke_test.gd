extends Node
## Test de fumée automatisé. Lancer (sans fenêtre) :
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . res://tests/smoke_test.tscn
## Code de sortie 0 = tout va bien, 1 = au moins un échec.

var _failures := 0


func _ready() -> void:
	# Cadence de référence (60 images/s) quels que soient les réglages d'affichage du joueur (fichier non modifié) :
	# certains tests comptent des images de physique.
	Display.fps = 60
	Display.apply()
	await get_tree().process_frame
	_test_rules()
	_test_generator()
	_test_audio()
	_test_inventory()
	_test_story()
	await _test_characters()
	await _test_skeleton_body()
	await _test_loot_and_gear()
	await _test_crypt()
	await _test_chapter_two()
	await _test_level_editor()
	await _test_quest_flow()
	await _test_new_features()
	await _test_town_portal()
	await _test_click_move()
	await _test_remote_spell_fx()
	await _test_display()
	if _failures == 0:
		print("SMOKE TEST : OK")
	else:
		printerr("SMOKE TEST : %d échec(s)" % _failures)
	Sfx.stop_ambience()
	Sfx._ambience.stream = null
	await get_tree().create_timer(0.2).timeout # laisse le serveur audio libérer la musique
	get_tree().quit(1 if _failures > 0 else 0)


## Options > Affichage : mode, résolution, images par seconde (sans toucher au fichier de réglages).
func _test_display() -> void:
	print("[Affichage]")
	var menu := OptionsMenu.new()
	add_child(menu)
	await _frames(1)
	var res := Display.resolutions()
	_check(menu.mode_button.item_count == 2 and menu.fps_button.item_count == 4 and res.has(Vector2i(1920, 1080))
		and menu.resolution_button.item_count == res.size(),
		"options d'affichage : fenêtré / plein écran, %d résolutions, 60 / 90 / 120 / 140 images/s" % res.size())
	menu.fps_button.select(2)
	menu.fps_button.item_selected.emit(2)
	var at_120 := Engine.max_fps == 120 and Engine.physics_ticks_per_second == 120
	menu.fps_button.select(0)
	menu.fps_button.item_selected.emit(0)
	_check(at_120 and Engine.max_fps == 60 and Engine.physics_ticks_per_second == 60,
		"fluidité : le jeu tourne à 120 images/s quand on le choisit (puis revient à 60)")
	menu.queue_free()
	# HUD : la main cornue (vie) et l'enceinte (décibels) se remplissent selon les valeurs.
	var life := Reservoir.create("main_vie", Vector2(150, 200), Color.DARK_RED, Color.RED, Color.WHITE)
	add_child(life)
	life.set_value(30, 50, "VIE 60 %")
	var span := Reservoir._mask_span(load("res://assets/ui/enceinte_db_masque.png"))
	_check(is_equal_approx(life.ratio, 0.6) and life._label.text == "VIE 60 %" and span.y > span.x + 0.6,
		"HUD : réservoir de vie (main cornue) à 60 %, l'enceinte entière est le récipient (masque de toute sa hauteur)")
	life.queue_free()


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
		elif normal_door < 0 and not bool(door_list[i]["doorway"]) and int(door_list[i]["room"]) != dg.get("gen").start_room:
			normal_door = i
	var normal_room := int(door_list[normal_door]["room"])
	# Torches : rouge orangé tant que le héros n'est pas passé à moins de 15 m, flamme normale ensuite (pour de bon).
	var torch_list: Array = dg.get("_torches")
	var hero_t := get_tree().get_first_node_in_group("hero") as Node3D
	var far_i := -1
	for i in torch_list.size():
		if _flat((torch_list[i] as Node3D).global_position, hero_t.global_position) > 22.0:
			far_i = i
			break
	var far_t: Node3D = torch_list[far_i] if far_i >= 0 else null
	var torch_mat: StandardMaterial3D = far_t.get_meta("torch")[0] if far_t != null else null
	var was_red := torch_mat != null and torch_mat.emission.is_equal_approx(DungeonDecor.TORCH_ALARM[0])
	var start_pos := hero_t.global_position
	far_t.visible = true # sa salle est peut-être encore fermée
	hero_t.global_position = far_t.global_position + far_t.global_basis.z * 3.0
	await get_tree().create_timer(1.8).timeout
	var seen: Array = (dg.get("_state") as Dictionary).get("torches", [])
	_check(was_red and seen.has(far_i) and torch_mat.emission.is_equal_approx(DungeonDecor.TORCH_CALM[0]),
		"torches rouge orangé tant qu'on n'est pas passé à moins de 15 m, flamme normale ensuite")
	hero_t.global_position = start_pos
	# Une torche de chaque côté des portes, sauf celle du boss.
	var flanked := 0
	var boss_flank := 0
	for d: Dictionary in door_list:
		var near := 0
		for t: Node3D in torch_list:
			if t.position.distance_to((d["node"] as Node3D).position) < 1.8:
				near += 1
		if bool(d["locked"]):
			boss_flank += near
		elif near >= 2:
			flanked += 1
	_check(flanked >= 2 and boss_flank == 0, "une torche de chaque côté des portes (%d portes), aucune à la porte du boss" % flanked)
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
	_check(dungeon_music != null and not dungeon_music.loop and dungeon_music.resource_path.begins_with("res://audio/music/donjons/")
		and Sfx.playlist().size() == 5, "musique du donjon : un des 5 morceaux du dossier, tiré au hasard")
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
	for e in targets:
		e.hp = 9999 # cibles d'entraînement : elles doivent survivre à tous les sorts du test
	var hp_before := 0
	for e in targets:
		hp_before += e.hp
	# Les sorts touchent 8 fois sur 10 : on relance l'Accordage si les 3 cibles l'ont esquivé.
	var hp_after := hp_before
	for attempt in 5:
		hero.cooldowns["tuning"] = 0.0
		GameState.mana = GameState.max_mana()
		hero.cast_tuning()
		await _frames(2)
		hp_after = 0
		for e in targets:
			hp_after += maxi(e.hp, 0)
		if hp_after < hp_before:
			break
	_check(hp_after < hp_before, "l'Accordage de cordes inflige des dégâts en chaîne")
	# (la recharge a déjà un peu décompté pendant les deux images : un à-coup de chargement ne doit pas faire échouer)
	var tuning_cd := float(hero.cooldowns["tuning"])
	var tuning_full := 10.0 * GameState.cooldown_multiplier()
	_check(is_equal_approx(Balance.TUNING_COOLDOWN, 10.0) and tuning_cd <= tuning_full + 0.01 and tuning_cd > tuning_full - 1.0,
		"Accordage de cordes : recharge de 10 s")
	var banging := 0
	for attempt in 5:
		hero.cooldowns["wave"] = 0.0
		GameState.mana = GameState.max_mana()
		for e in targets:
			e.hp = 9999
			e.global_position = hero.global_position + Vector3(1.5, 0, 0)
		hero.cast_wave()
		await _frames(2)
		banging = 0
		for e in targets:
			if is_instance_valid(e) and e.is_in_trance():
				banging += 1
		if banging > 0:
			break
	await get_tree().create_timer(Balance.WAVE_HEADBANG + 0.3).timeout
	var still := 0
	for e in targets:
		if is_instance_valid(e) and e.is_in_trance():
			still += 1
	_check(banging > 0 and still == 0, "Onde de choc : les ennemis touchés headbanguent %.2f s (%d)" % [Balance.WAVE_HEADBANG, banging])
	_check(GameState.mana < GameState.max_mana(), "les sorts consomment des décibels")
	# Chance de toucher des sorts : 80 % (sauf mini-jeux : 100 %).
	var spell_hits := 0
	var sure_hits := 0
	var hp_probe := targets[0]
	for k in 300:
		hp_probe.hp = 9999
		if hero.hit_enemy(hp_probe, 1, 0.0, "sound"):
			spell_hits += 1
		if hero.hit_enemy(hp_probe, 1, 0.0, "sound", Vector3.INF, true):
			sure_hits += 1
	_check(is_equal_approx(GameState.spell_hit_chance(), 0.8) and spell_hits > 210 and spell_hits < 270 and sure_hits == 300,
		"sorts : 80 %% de chances de toucher (%d / 300), mini-jeux toujours (%d / 300)" % [spell_hits, sure_hits])
	# Riff électrique : mini-jeu, la même note à 90 BPM ; l'éclair saute d'un ennemi au suivant.
	var solo_game := (dungeon as Level).hud.solo
	for i in targets.size():
		targets[i].hp = 9999
		targets[i].global_position = hero.global_position + Vector3(2.0 + i * 1.5, 0, 0)
		targets[i].exit_trance()
	hero.aim_point = targets[0].global_position
	GameState.mana = GameState.max_mana()
	GameState.hp = GameState.max_hp() # les squelettes réveillés ne doivent pas tuer le héros pendant le test
	hero.cooldowns["riff"] = 0.0
	hero.cast_riff()
	await _frames(1)
	var riff_beat := 60.0 / Balance.RIFF_BPM
	var regular := solo_game._notes.size() == Balance.RIFF_NOTES - 1
	for i in solo_game._notes.size():
		regular = regular and absf(float(solo_game._notes[i]["time"]) - riff_beat * (i + 1)) < 0.001 and int(solo_game._notes[i]["lane"]) == 0
	_check(hero.casting_riff and solo_game._active and solo_game.mode == "riff" and solo_game._lanes == 1 and regular,
		"Riff électrique : mini-jeu d'une seule note, 8 notes à 90 BPM (la 1re part avec le sort)")
	for i in solo_game._notes.size():
		var wait := float(solo_game._notes[i]["time"]) - solo_game._t
		if wait > 0.0:
			await get_tree().create_timer(wait).timeout
		GameState.hp = GameState.max_hp()
		solo_game._press(0)
	await _frames(2)
	var chained := {}
	for e: Enemy in hero._riff_chain:
		chained[e] = true
	_check(not hero.casting_riff and not solo_game._active and hero._riff_chain.size() == Balance.RIFF_NOTES and chained.size() >= 3,
		"riff parfait : 8 notes, l'éclair se propage aux ennemis suivants (%d touchés ; chaîne %d, notes %d / %d, t %.3f, en cours %s)" % [chained.size(), hero._riff_chain.size(), solo_game._hits, solo_game._notes.size(), solo_game._t, hero.casting_riff])
	_check(absf(float(hero.cooldowns["riff"]) - Balance.RIFF_COOLDOWN * GameState.cooldown_multiplier()) < 0.05, "Riff électrique : recharge de 3 s")
	hero.cooldowns["riff"] = 0.0
	GameState.mana = GameState.max_mana()
	hero.cast_riff()
	await _frames(1)
	solo_game._press(0) # à contretemps : la 2e note n'arrive qu'au bout de 0,375 s
	await _frames(1)
	_check(not hero.casting_riff and absf(float(hero.cooldowns["riff"]) - 3.0 * Balance.RIFF_COOLDOWN * GameState.cooldown_multiplier()) < 0.05,
		"riff : une fausse note l'arrête et triple la recharge")
	# Coup de guitare : il touche à chaque fois (même contre une CA de 99), 1d6 + FOR.
	var victim := targets[0]
	victim.armor_class = 99
	var landed := 0
	for k in 4:
		victim.hp = 9999
		victim.global_position = hero.global_position + hero.facing * 1.2
		GameState.hp = GameState.max_hp()
		hero.cooldowns["attack"] = 0.0
		hero.melee()
		await get_tree().create_timer(Balance.MELEE_HIT_DELAY + 0.1).timeout
		var dealt := 9999 - victim.hp
		if dealt >= 1 and dealt <= 2 * Balance.MELEE_DICE + GameState.mod("FOR") + 2:
			landed += 1
	_check(landed == 4, "coup de guitare : touche à tous les coups (CA 99), 1d6 + FOR (%d / 4)" % landed)
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
	# Bruitages synthétisés (montée de niveau, sorts...) : tous au même niveau perçu, sous les
	# enregistrements fournis (riff électrique ≈ -5,5 LUFS) au lieu de les couvrir.
	var levels := {}
	for id: String in ["levelup", "boom", "portal", "zap", "croak", "thud", "swoosh", "solo_start", "note_0", "coin"]:
		var w := Sfx._streams[id] as AudioStreamWAV
		var pcm := PackedFloat32Array()
		pcm.resize(w.data.size() / 2)
		for k in pcm.size():
			pcm[k] = w.data.decode_s16(k * 2) / 32767.0
		levels[id] = Sfx.loudness(pcm, Sfx.RATE)
	var level_ok := Sfx.SYNTH_LUFS <= -18.0
	for id: String in levels:
		level_ok = level_ok and absf(float(levels[id]) - Sfx.SYNTH_LUFS) < 0.6
	_check(level_ok, "bruitages synthétisés ramenés à %.0f LUFS (montée de niveau %.1f, explosion %.1f)"
		% [Sfx.SYNTH_LUFS, float(levels["levelup"]), float(levels["boom"])])
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
	var hero_at := hero.global_position
	var boss_t := boss._anim_t
	await _frames(5)
	_check(not get_tree().paused and DialogueBox.active and boss._anim_t > boss_t and hero.global_position.distance_to(hero_at) < 0.01,
		"dialogue sans pause : le monde continue, le héros attend sans bouger")
	_check(dlg._npc_face["target"] == boss and dlg._hero_face["target"] == hero and (dlg._npc_face["frame"] as Control).visible
		and (dlg._hero_face["frame"] as Control).visible, "dialogue : portraits de Gloubah à gauche et du héros à droite")
	dlg._show_line()
	dlg.skip_typing()
	_check(not dlg._typing and is_equal_approx(dlg._text.visible_ratio, 1.0), "dialogue : clic ou Espace affiche la réplique en entier")
	dlg.close()
	_check(not DialogueBox.active, "fin du dialogue : le héros reprend la main")
	# Vie sous 20 % : aura rouge clignotante sur le pourtour de l'écran.
	var low_hud := (dungeon as Level).hud
	var hp_saved := GameState.hp
	GameState.hp = maxi(1, floori(GameState.max_hp() * 0.15))
	await _frames(2)
	var low_on := low_hud._low_hp.visible
	GameState.hp = hp_saved
	await _frames(2)
	_check(low_on and not low_hud._low_hp.visible, "vie sous 20 %% : aura rouge clignotante (toutes les %.2f s)" % Hud.LOW_HP_PERIOD)
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
	_check(GameState.inventory.has("portrait_aieule"), "récompense : le portrait de l'arrière-arrière-arrière-grand-mère de Gérald")
	_check(GameState.has_save() and GameState.latest_slot() == 0, "partie sauvegardée (Continuer reprend la sauvegarde la plus récente)")
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
	_check(ItemDB.common_drops().size() == 8 and ItemDB.potion_price() == 25 and ItemDB.get_item("couronne_gloubah").get("name", "") != "",
		"objets lus dans data/items.json (8 équipements de butin)")
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
	# Pas de musique dans la salle commune : sorts et coups de guitare refusés, guitare dans le dos.
	GameState.mana = GameState.max_mana()
	hero.cooldowns["wave"] = 0.0
	hero.cast_wave()
	hero.melee()
	_check(not hero.spells_allowed and hero.model.guitar_slung and GameState.mana >= GameState.max_mana() - 0.01
		and float(hero.cooldowns["wave"]) == 0.0 and float(hero.cooldowns["attack"]) == 0.0,
		"salle commune : ni sorts ni coups de guitare, guitare dans le dos")
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
	var walked_animated := false
	if walker_p != null:
		walker_p.walk_speed = 12.0
		walker_p.walker.speed = 12.0
		for f in 600:
			await get_tree().physics_frame
			walked_animated = walked_animated or (walker_p.walker.walking and walker_p.model._loco_on)
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
	_check(walked_animated and walker_p.seated and not walker_p.model._loco_on,
		"le client marche comme Riffald (clips Mixamo), puis se rassoit (pose procédurale)")
	# PNJ : modèles 3D importés (Zarathos le mage, Grokk le tavernier orc), les autres articulés (HeroModel)
	# avec la posture et la démarche de Riffald.
	var npc_models := true
	var animated_npcs := 0
	var skins := {}
	for c in tavern.get_children():
		var n := c as Npc
		if n != null:
			npc_models = npc_models and (n.model != null or n.skin != null)
			if n.model != null and n.model._loco_on and n.model._body.style == "pnj_corps":
				animated_npcs += 1
			if n.skin != null:
				skins[n.npc_id] = n.skin
	var mage: CharacterSkin = skins.get("zarathos")
	var keeper: CharacterSkin = skins.get("brunhilde")
	_check(npc_models and animated_npcs >= 2 and mage != null and keeper != null and mage.lengths.has("walk")
		and keeper.skeleton.get_bone_count() == 17 and DialogueDB.npc_name("brunhilde").begins_with("Grokk")
		and is_equal_approx(keeper.scale.y, 1.25) and keeper.height > 2.5,
		"PNJ : Zarathos et Grokk le tavernier orc (agrandi de 25 %%) avec leurs modèles 3D (17 os, clips Mixamo), %d autres debout (repos pnjPose)" % animated_npcs)
	var pnj_idle := ""
	for c in tavern.get_children():
		var n := c as Npc
		if n != null and n.model != null and n.model._body.loco != null:
			pnj_idle = str((n.model._body.loco.tree.tree_root.get_node("idle") as AnimationNodeAnimation).animation)
	var idle_of := func(s: CharacterSkin) -> String:
		return str(((s.tree.tree_root as AnimationNodeBlendTree).get_node("loco").get_node("idle") as AnimationNodeAnimation).animation)
	_check(pnj_idle == "squelettes/idle_pnj" and idle_of.call(keeper) == "idle" and keeper.lengths.has("idle")
		and not is_equal_approx(float(keeper.lengths["idle"]), float(mage.lengths["idle"])),
		"repos : pnjPose pour les PNJ, Orc Idle pour le tavernier (%.1f s)" % float(keeper.lengths.get("idle", 0.0)))
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
	for i in 3: # la guitare revient en main au pas de physique, puis les bras suivent à l'image
		await get_tree().physics_frame
	await _frames(2)
	GameState.mana = 5.0
	var spent := GameState.spend_mana(40.0)
	_check(spent and GameState.infinite_mana and GameState.mana >= GameState.max_mana() - 0.01, "sous-sol : décibels toujours au maximum")
	# Au sous-sol, la guitare revient en main : main gauche au bout du manche (près du sillet),
	# main droite au centre de la caisse (pivots « _r » = main gauche, côté +X).
	var hm := hero.model
	var neck_end := hm._guitar.global_transform * Vector3(0, HeroModel.PROC_NUT * hm._neck_scale, 0)
	var body_mid := hm._guitar.global_transform * Vector3(0, -0.1, 0)
	_check(hero.spells_allowed and not hm.guitar_slung and hm._hand_r.global_position.distance_to(neck_end) < 0.1
		and hm._hand_l.global_position.distance_to(body_mid) < 0.12,
		"sous-sol : guitare en main, main gauche au bout du manche, main droite au centre de la caisse (écarts %.2f / %.2f m)" % [
			hm._hand_r.global_position.distance_to(neck_end), hm._hand_l.global_position.distance_to(body_mid)])
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
	# Rejoindre avec une adresse IP tapée à la main (VPN) ou un code.
	var by_ip := Net.parse_invite(" 26.12.34.56 ")
	var by_port := Net.parse_invite("26.12.34.56:4000")
	_check(by_ip.get("ip", "") == "26.12.34.56" and int(by_ip.get("port", 0)) == Net.PORT
		and int(by_port.get("port", 0)) == 4000 and Net.parse_invite(code).get("ip", "") == "86.201.14.7",
		"rejoindre avec une adresse IP (avec ou sans port) ou un code")
	# Codes proposés à l'hôte sans UPnP : VPN d'abord, puis Internet (port à ouvrir), puis local.
	var vpns: Array[Dictionary] = [{"name": "Radmin VPN", "ip": "26.1.2.3"}]
	var no_upnp := Net.build_codes("86.201.14.7", false, vpns, "192.168.1.16")
	var labels := no_upnp.map(func(c: Dictionary) -> String: return str(c["label"]))
	_check(labels == ["Radmin VPN", "Internet", "Réseau local"]
		and Net.decode_code(str(no_upnp[0]["code"]))["ip"] == "26.1.2.3"
		and Net.decode_code(str(no_upnp[1]["code"]))["ip"] == "86.201.14.7"
		and Net.decode_code(str(no_upnp[2]["code"]))["ip"] == "192.168.1.16"
		and str(no_upnp[1]["hint"]).contains("24565"), "sans UPnP : codes VPN, Internet (port à ouvrir) et local")
	var with_upnp := Net.build_codes("86.201.14.7", true, vpns, "192.168.1.16")
	_check(str(with_upnp[0]["label"]) == "Internet" and Net.build_codes("", false, [] as Array[Dictionary], "192.168.1.16").size() == 1,
		"port ouvert par UPnP : code Internet en premier ; adresse publique inconnue : code local seul")
	_check(Net._is_vpn_interface({"friendly": "Radmin VPN", "addresses": ["26.5.6.7"]})
		and Net._is_vpn_interface({"friendly": "Ethernet 3", "addresses": ["100.101.2.3"]})
		and not Net._is_vpn_interface({"friendly": "Wi-Fi", "addresses": ["192.168.1.16"]})
		and not Net.local_ip().begins_with("26."), "cartes VPN reconnues (Radmin, Tailscale), exclues de l'adresse locale")
	Net.upnp_enabled = false # les tests ne touchent pas à la box
	Net.public_lookup_enabled = false # ni au service d'adresse publique
	var err := Net.host()
	_check(err.is_empty() and Net.is_host() and Net.player_count() == 1 and not Net.codes.is_empty()
		and str(Net.codes[-1]["label"]) == "Réseau local", "partie ouverte en coop (hôte) avec ses codes")
	Net.leave()
	# Hôte injoignable : abandon avec un message d'aide au lieu d'attendre indéfiniment.
	var statuses: Array[String] = []
	var on_status := func(t: String) -> void: statuses.append(t)
	Net.status_changed.connect(on_status)
	_check(Net.join("127.0.0.1:1").is_empty(), "tentative de connexion lancée")
	Net._on_join_timeout(Net._join_attempt)
	Net.status_changed.disconnect(on_status)
	_check(not Net.is_online() and multiplayer.multiplayer_peer is OfflineMultiplayerPeer and not statuses.is_empty()
		and statuses[-1] == Net.NO_ANSWER, "hôte injoignable : abandon au bout de %d s avec des pistes" % int(Net.JOIN_TIMEOUT))
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
	# Échap (ou Espace) passe la cinématique, sans ouvrir le menu pause.
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	get_viewport().push_input(esc)
	await _frames(3)
	var i_hud := i_level.hud
	_check(intro.get("_cine_cam") == null and i_level.camera.current and i_hud.dialogue.visible and not i_hud._pause_menu.visible
		and i_level.hero.captive, "intro : Échap passe la cinématique, réplique du héros (pas de menu pause)")
	i_hud.dialogue.close()
	await _frames(2)
	_check(not bool(intro.get("_cinematic")) and not i_level.hero.captive, "intro : après sa réplique, le héros est libre")
	intro.call("_lightning")
	await get_tree().create_timer(1.5).timeout
	_check(true, "un éclair frappe le décor sans erreur")
	var intro_lines: Array = DialogueDB.get_dialogue("intro_hero")["lines"]
	_check(str(intro_lines[1][1]) == "...J'ai rien vu." and str(intro_lines[3][1]).contains("thé glacé à la goyave"), "intro : le héros fait mine de rien et file boire un thé glacé à la goyave")
	intro.queue_free()
	await _frames(5)
	get_tree().paused = false


func _count_portals(root: Node) -> int:
	var count := 1 if root is Portal else 0
	for child in root.get_children():
		count += _count_portals(child)
	return count


## Histoire : Gérald le fromager, refus en boucle jusqu'au fromage d'hibours (+20 % de PV 20 min).
func _test_story() -> void:
	print("[Histoire]")
	GameState.new_game()
	_check(GameState.location_label("") == "La Chèvre Fringante" and QuestDB.get_quest("plumeau")["reward"]["gold"] == 50,
		"taverne : la Chèvre Fringante ; récompense de Gérald : 50 médiators")
	var first: Array = DialogueDB.get_dialogue("gerald")["choices"]
	_check(str(first[1][1]) == "refuse:plumeau", "on peut refuser la quête de Gérald")
	var pleas: Array[String] = []
	var hp0 := GameState.max_hp()
	for i in DialogueDB.GERALD_PLEAS.size():
		GameState.run_dialogue_action("refuse:plumeau")
		var d := DialogueDB.get_dialogue("gerald")
		pleas.append(str((d["lines"] as Array)[0][1]))
	_check(pleas[0] == "Et maintenant, tu veux bien ?" and pleas[3].begins_with("Allé") and pleas[4] == "Je te donnerai du fromage d'hibours !",
		"Gérald revient à la charge : %s" % " / ".join(pleas))
	var cheese: Array = DialogueDB.get_dialogue("gerald")["choices"]
	GameState.run_dialogue_action(str(cheese[1][1]))
	_check(GameState.cheese_time > 0.0 and GameState.max_hp() == roundi(hp0 * 1.2) and int(GameState.flags["gerald_refus"]) == 5
		and str(DialogueDB.get_dialogue("gerald")["lines"][0][1]) == "Je te donnerai du fromage d'hibours !",
		"fromage d'hibours : +20 %% de PV max (%d → %d) pendant 20 min, puis la proposition tourne en boucle" % [hp0, GameState.max_hp()])
	GameState.run_dialogue_action("cheese")
	_check(is_equal_approx(GameState.cheese_time, GameState.CHEESE_DURATION), "le fromage n'est offert qu'une fois")
	GameState.run_dialogue_action(str(DialogueDB.get_dialogue("gerald")["choices"][0][1]))
	_check(GameState.quest_state("plumeau") == QuestDB.State.ACTIVE, "on peut toujours accepter après avoir refusé")
	GameState.new_game()


## Inventaire (touche B) : vente des reliques à Grokk et rachat des 10 dernières.
func _test_inventory() -> void:
	print("[Inventaire et équipement]")
	GameState.new_game()
	var relics: Array = ItemDB.relics().keys()
	var cha_base := GameState.ability("CHA")
	for id: String in relics:
		GameState.add_item(id)
	_check(GameState.inventory.size() == relics.size() and GameState.equipment.is_empty() and GameState.ability("CHA") == cha_base,
		"le butin va dans le sac : ses bonus ne comptent pas tant qu'il n'est pas équipé")
	var slots_ok := true
	for id: String in relics:
		slots_ok = slots_ok and ItemDB.SLOTS.has(ItemDB.slot_of(id))
	_check(slots_ok and ItemDB.SLOTS.size() == 11 and ItemDB.slot_of("couronne_gloubah") == "tete" and ItemDB.slot_of("bottes_roadie") == "pieds",
		"équipement : 11 emplacements (tête, cou, torse... cordes, grimoire), chaque objet a le sien")
	_check(GameState.equip("cordes_dragon") and GameState.equipment.get("cordes", "") == "cordes_dragon"
		and not GameState.inventory.has("cordes_dragon") and GameState.ability("CHA") == cha_base + 1,
		"équiper les cordes en boyau de dragon : +1 CHA")
	_check(GameState.unequip("cordes") and GameState.inventory.has("cordes_dragon") and GameState.ability("CHA") == cha_base,
		"retirer un équipement : il retourne dans le sac et ses bonus disparaissent")
	GameState.equip("cordes_dragon")
	GameState.inventory.append("cordes_dragon_bis") # même emplacement : l'ancien objet retourne dans le sac
	ItemDB.relics()["cordes_dragon_bis"] = {"nom": "Cordes de test", "bonus": {"CHA": 2}, "rarete": "commun", "emplacement": "cordes"}
	_check(GameState.equip("cordes_dragon_bis") and GameState.inventory.has("cordes_dragon") and GameState.ability("CHA") == cha_base + 2,
		"équiper sur un emplacement occupé : l'objet précédent retourne dans le sac")
	GameState.unequip("cordes")
	GameState.inventory.erase("cordes_dragon_bis")
	ItemDB.relics().erase("cordes_dragon_bis")
	var gold0 := GameState.gold
	var first := "mediator_os"
	var price := ItemDB.sell_price(first)
	_check(GameState.sell_item(first) and not GameState.inventory.has(first) and GameState.gold == gold0 + price
		and GameState.buyback[0] == first and price > 0, "vendre un objet du sac à Grokk : +%d médiators, dans l'historique de rachat" % price)
	_check(GameState.buy_back(first) and GameState.inventory.has(first) and GameState.gold == gold0 and GameState.buyback.is_empty(),
		"racheter un objet au prix de vente")
	GameState.equip(first)
	_check(not GameState.sell_item(first) and GameState.is_equipped(first), "on ne vend pas un objet porté")
	GameState.unequip("mediator")
	for i in 12:
		GameState.buyback.push_front("x%d" % i)
	GameState.sell_item(first)
	_check(GameState.buyback.size() == GameState.BUYBACK_MAX and GameState.buyback[0] == first, "historique de rachat limité aux 10 derniers")
	_check(InputMap.has_action("inventory") and InputMap.action_get_events("inventory").size() > 0, "inventaire sur la touche B")
	GameState.equip("couronne_gloubah")
	var snap: Dictionary = GameState._snapshot()
	_check((snap["buyback"] as Array).has(first) and (snap["equipment"] as Dictionary).get("tete", "") == "couronne_gloubah",
		"l'historique de rachat et l'équipement porté sont sauvegardés")
	GameState.apply_save(JSON.parse_string(JSON.stringify(snap)))
	_check(GameState.equipment.get("tete", "") == "couronne_gloubah" and not GameState.inventory.has("couronne_gloubah"),
		"équipement rechargé avec la partie")
	# Ancienne sauvegarde (sans équipement) : les reliques qu'on avait sont équipées d'office.
	snap.erase("equipment")
	snap["inventory"] = ["bracelet_force", "pendentif_plume"]
	GameState.apply_save(JSON.parse_string(JSON.stringify(snap)))
	_check(GameState.equipment.get("poignets", "") == "bracelet_force" and GameState.equipment.get("cou", "") == "pendentif_plume"
		and GameState.inventory.is_empty(), "sauvegarde d'avant l'équipement : reliques équipées automatiquement")
	GameState.new_game()


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
	# Donjons : les musiques du dossier jouées au hasard, sans répéter deux fois de suite la même.
	Sfx.play_playlist("res://audio/music/donjons", -60.0)
	var first := Sfx._playlist_last
	Sfx._next_track()
	var mp3 := Sfx._ambience.stream as AudioStreamMP3
	_check(Sfx.playlist().size() == 5 and Sfx._playlist_last != first and mp3 != null and not mp3.loop,
		"donjons : %d musiques en lecture aléatoire, enchaînées sans répétition" % Sfx.playlist().size())
	Sfx.stop_ambience()
	_check(Sfx.playlist().is_empty(), "la liste de lecture s'arrête avec la musique")


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
	# IK après l'animation : poignets à leur place (main gauche au bout du manche, main droite sur la
	# caisse), paumes tournées vers la guitare, agrandie comme ses mains.
	# La pose modifiée n'existe qu'au moment du rendu : on la lit au signal skeleton_updated.
	await sk.skeleton_updated
	var gt := anim._skel_to_model().affine_inverse() * rig._guitar.transform.orthonormalized()
	var wrists := anim.hand_targets(gt)
	var hand_err := (sk.get_bone_global_pose(sk.find_bone("hand.L")).origin - (wrists["L"] as Vector3)).length()
	_check(hand_err < 0.03, "Riffald : la main gauche tient le bout du manche, près du sillet (écart %.3f m)" % hand_err)
	var pick_err := (sk.get_bone_global_pose(sk.find_bone("hand.R")).origin - (wrists["R"] as Vector3)).length()
	_check(pick_err < 0.03, "Riffald : la main droite gratte sur la caisse (écart %.3f m)" % pick_err)
	var palms := minf(anim.palm_normal("L").dot(-gt.basis.z), anim.palm_normal("R").dot(-gt.basis.z))
	_check(palms > 0.8 and rig._guitar.transform.basis.get_scale().x > 1.25,
		"Riffald : paumes tournées vers la guitare (%.2f), guitare agrandie comme ses mains" % palms)
	# Guitariste droitier : le manche part vers la gauche du héros (+X, le modèle regarde vers +Z).
	_check(gt.basis.y.x > 0.5 and sk.get_bone_global_pose(sk.find_bone("hand.L")).origin.x > 0.0,
		"Riffald : droitier, manche à gauche tenu par la main gauche")
	_check(anim._playback.get_current_node() == "loco"
		and float(anim.tree.get("parameters/sm/loco/pace/scale")) > 1.0, "Riffald : course accélérée à la vitesse du héros")
	# Les cycles bouclent : après plusieurs foulées, les pieds bougent encore (pas de pose figée).
	await get_tree().create_timer(1.2).timeout
	var foot_ys: Array[float] = []
	for k in 8:
		await get_tree().create_timer(0.1).timeout
		await sk.skeleton_updated
		foot_ys.append(sk.get_bone_global_pose(sk.find_bone("foot.L")).origin.y)
	_check(foot_ys.max() - foot_ys.min() > 0.2 and foot_ys.min() < 0.16,
		"Riffald : la course boucle et le pied revient au sol (%.2f → %.2f m)" % [foot_ys.min(), foot_ys.max()])
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
	var riff_head := sk.get_bone_global_rest(sk.find_bone("head")).origin.y
	# Héroïne prédéfinie (modèle fourni, squelette et animations de Riffald).
	creation._set_hero_mode(1)
	creation._refresh()
	await _frames(3)
	var heroine: HeroModel = creation._model
	var preset_f: Dictionary = RaceDB.PRESETS["persof1"]
	_check(str(creation.appearance["preset"]) == "persof1" and creation._name_edit.text == str(preset_f["name"])
		and not creation._name_edit.editable and str(creation.appearance["sex"]) == "f",
		"création : héroïne prédéfinie %s (nom verrouillé)" % preset_f["name"])
	var anim_f := heroine._anim
	_check(heroine._skin != null and heroine._skin.skeleton.get_bone_count() == 17 and anim_f != null
		and anim_f.lengths.size() >= 16 and anim_f.lengths.has("smash") and anim_f.lengths.has("sleep") and is_equal_approx(heroine.scale.y, 1.84 / 1.74)
		and is_equal_approx(heroine.height(), 1.84) and is_equal_approx(anim_f.guitar_scale, float(preset_f["rig"]["guitar_scale"])),
		"%s : son modèle, les 17 os et les %d animations de Riffald, 1,84 m (agrandie en jeu)" % [preset_f["name"], anim_f.lengths.size() if anim_f else 0])
	var sk_f := heroine._skin.skeleton
	await sk_f.skeleton_updated
	var gt_f := anim_f._skel_to_model().affine_inverse() * heroine._guitar.transform.orthonormalized()
	var hands_f := anim_f.hand_targets(gt_f)
	var err_f := maxf((sk_f.get_bone_global_pose(sk_f.find_bone("hand.L")).origin - hands_f["L"]).length(),
		(sk_f.get_bone_global_pose(sk_f.find_bone("hand.R")).origin - hands_f["R"]).length())
	var top_f := sk_f.get_bone_global_rest(sk_f.find_bone("head")).origin.y
	_check(err_f < 0.03 and gt_f.basis.y.x > 0.5 and absf(top_f * heroine.scale.y - riff_head) < 0.08,
		"%s : mains sur la guitare (écart %.3f m), droitière, tête à la hauteur de celle de Riffald (%.2f m / %.2f m)" % [preset_f["name"], err_f, top_f * heroine.scale.y, riff_head])
	heroine.swing()
	_check(anim_f.state == "smash", "%s : coups de guitare animés" % preset_f["name"])
	# Démon prédéfini (modèle fourni, poids peints par Ulysse).
	var demon_i := RaceDB.PRESET_ORDER.find("demon")
	creation._set_hero_mode(demon_i)
	creation._refresh()
	await _frames(3)
	var demon: HeroModel = creation._model
	_check(demon_i >= 0 and creation._name_edit.text == "Belzeluth" and str(creation.appearance["race"]) == "demon"
		and demon._skin != null and demon._skin.skeleton.get_bone_count() == 17 and demon._anim != null
		and demon._anim.lengths.size() >= 16 and is_equal_approx(demon.height(), 1.95),
		"Belzeluth : démon prédéfini, son modèle, les 17 os et les animations de Riffald, 1,95 m")
	# Hella, héroïne prédéfinie (modèle retravaillé par Ulysse).
	var hella_i := RaceDB.PRESET_ORDER.find("hella")
	creation._set_hero_mode(hella_i)
	creation._refresh()
	await _frames(3)
	var hella: HeroModel = creation._model
	_check(hella_i >= 0 and creation._name_edit.text == "Hella" and str(creation.appearance["sex"]) == "f"
		and hella._skin != null and hella._skin.skeleton.get_bone_count() == 17 and hella._anim != null
		and hella._anim.lengths.size() >= 16 and is_equal_approx(hella.height(), 1.75),
		"Hella : héroïne prédéfinie, son modèle, les 17 os et les %d animations de Riffald, 1,75 m" % (hella._anim.lengths.size() if hella._anim else 0))
	var sk_h := hella._skin.skeleton
	await sk_h.skeleton_updated
	var gt_h := hella._anim._skel_to_model().affine_inverse() * hella._guitar.transform.orthonormalized()
	var hands_h := hella._anim.hand_targets(gt_h)
	var err_h := maxf((sk_h.get_bone_global_pose(sk_h.find_bone("hand.L")).origin - hands_h["L"]).length(),
		(sk_h.get_bone_global_pose(sk_h.find_bone("hand.R")).origin - hands_h["R"]).length())
	_check(err_h < 0.03, "Hella : mains sur la guitare (écart %.3f m)" % err_h)
	creation._set_hero_mode(RaceDB.PRESET_ORDER.size())
	creation._refresh()
	_check(str(creation.appearance["preset"]) == "" and creation._name_edit.editable, "création : passage en personnage personnalisé")
	# Héros personnalisé (corps procédural) : posture et démarche de Riffald, mêmes clips Mixamo.
	await _frames(3)
	var custom: HeroModel = creation._model
	var loco := custom._body.loco
	_check(custom._anim == null and loco != null and custom._loco_on and loco.lengths.has("idle") and loco.lengths.has("run")
		and custom._torso.basis.y.dot(Vector3.UP) > 0.97, "héros personnalisé : posture de repos de Riffald (clips Mixamo), dos droit")
	custom.move_speed = Balance.HERO_SPEED
	custom.set_moving(true)
	var stride := Vector2(INF, -INF)
	var sole := INF
	for k in 16:
		await get_tree().create_timer(0.05).timeout
		var ankle := custom.to_local(custom._ankle_l.global_position)
		stride = Vector2(minf(stride.x, ankle.z), maxf(stride.y, ankle.z))
		sole = minf(sole, ankle.y)
	_check(custom._loco_on and stride.y - stride.x > 0.5 and sole < 0.15 and custom._torso.basis.y.z > 0.05,
		"héros personnalisé : course de Riffald (foulée %.2f m, pied au sol, buste penché en avant)" % (stride.y - stride.x))
	custom.set_moving(false)
	custom.set_seated(true)
	await _frames(2)
	_check(not custom._loco_on and absf(custom._hip_l.rotation.x + 1.45) < 0.01
		and is_equal_approx(custom._hip_l.position.x, -HeroModel.HIP_HALF_WIDTH), "assis : le squelette procédural reprend la main")
	custom.set_seated(false)
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


## Éditeur de niveau : le premier donjon est une scène faite main (DungeonMap), les suivants restent générés.
func _test_level_editor() -> void:
	print("[Éditeur de niveau]")
	var map := (load("res://scenes/levels/catacombes.tscn") as PackedScene).instantiate() as DungeonMap
	var problems := map.check()
	var kinds := {}
	for m in map.markers():
		kinds[m.kind] = int(kinds.get(m.kind, 0)) + 1
	_check(problems.is_empty() and map.rooms().size() >= 8 and int(kinds.get(DungeonMarker.Kind.CHEF, 0)) == 1
		and int(kinds.get(DungeonMarker.Kind.TORCHE, 0)) > 5, "Catacombes : scène faite main valide (%d salles, %d objets) %s"
		% [map.rooms().size(), map.markers().size(), problems])
	map.free()
	GameState.new_game()
	GameState.accept_quest("plumeau")
	var d: Node = load("res://scenes/dungeon.tscn").instantiate()
	add_child(d)
	await _frames(3)
	var chests := 0
	for c in d.get_children():
		if c is Interactable and (c as Interactable).prompt == "Ouvrir le coffre":
			chests += 1
	_check(bool(d.get("from_map")) and d.get("chief") != null and (d.get("doors") as Array).size() >= 8 and chests >= 1
		and d.call("is_walkable", (d as Level).hero.global_position),
		"donjon de la quête lu dans la scène : salles, portes, chef, coffres (%d), héros dans la salle de départ" % chests)
	d.queue_free()
	await _frames(3)
	GameState.new_game()
	GameState.accept_quest("plumeau")
	GameState.flags["test_map"] = "" # sans scène : donjon généré (donjons suivants)
	var g: Node = load("res://scenes/dungeon.tscn").instantiate()
	add_child(g)
	await _frames(3)
	_check(not bool(g.get("from_map")) and g.get("chief") != null and (g.get("gen") as DungeonGenerator).rooms.size() >= 10,
		"sans scène, le donjon reste généré aléatoirement")
	g.queue_free()
	await _frames(3)
	# Taverne faite main (TavernMap) : la vie de la taverne branchée sur la scène.
	var tmap := (load("res://scenes/levels/taverne.tscn") as PackedScene).instantiate() as TavernMap
	var t_problems := tmap.check()
	_check(t_problems.is_empty() and tmap.markers().size() > 60, "Taverne : scène faite main valide (%d objets) %s" % [tmap.markers().size(), t_problems])
	tmap.free()
	GameState.new_game()
	GameState.flags["intro_done"] = true
	var tv: Node = load("res://scenes/tavern.tscn").instantiate()
	add_child(tv)
	await _frames(3)
	var stairs := 0
	var moons := 0
	for c in tv.get_children():
		if c is Interactable and ((c as Interactable).prompt.begins_with("Monter") or (c as Interactable).prompt.begins_with("Descendre")
				or (c as Interactable).prompt.begins_with("Remonter")):
			stairs += 1
		if c is SpotLight3D:
			moons += 1
	_check((tv.get("_seats") as Array).size() == 23 and not (tv.get("_katrkar_seat") as Dictionary).is_empty()
		and (tv.get("_bar_spots") as Array).size() == 6 and stairs == 4 and moons == 8 and tv.get("bed_interact") != null
		and bool(tv.call("is_in_cellar", Vector3(61, 0, -3))) and not bool(tv.call("is_in_cellar", Vector3(0, 0, 0))),
		"taverne lue dans la scène : 23 places, comptoir, 4 escaliers, %d fenêtres éclairées, lit, salle d'entraînement (%d %d %d)" % [moons,
			(tv.get("_seats") as Array).size(), (tv.get("_bar_spots") as Array).size(), stairs])
	tv.queue_free()
	await _frames(3)
	GameState.new_game()


## Ennemis humanoïdes : corps articulé (HumanoidBody), posture et démarche de Riffald.
func _test_skeleton_body() -> void:
	print("[Squelettes : modèle 3D importé]")
	var skel := Skeleton.new()
	skel.captain = true
	add_child(skel)
	skel.set_physics_process(false)
	await _frames(1)
	var skin := skel.skin
	var sk := skin.skeleton
	var foot := sk.find_bone("foot.L")
	var stride := Vector2(INF, -INF)
	for k in 40:
		skel._speed_now = skel.move_speed
		skel._animate(0.033, true)
		var p := sk.get_bone_global_pose(foot).origin
		stride = Vector2(minf(stride.x, p.z), maxf(stride.y, p.z))
	var gait := skin.tree.tree_root.get_node("loco").get_node("gait") as AnimationNodeBlendSpace1D
	_check(sk.get_bone_count() == 17 and str((gait.get_blend_point_node(0) as AnimationNodeAnimation).animation) == "zombie_run"
		and stride.y - stride.x > 0.3 and skin.lengths.has("slash") and skin.lengths.has("die"),
		"squelette : modèle 3D (17 os), repos et course de zombie (foulée %.2f m)" % (stride.y - stride.x))
	var hand := sk.find_bone("hand.R")
	var before := sk.get_bone_global_pose(hand).origin
	skel._attack_anim(0.5)
	var moved := 0.0
	for k in 12:
		skel._animate(0.033, false)
		moved = maxf(moved, sk.get_bone_global_pose(hand).origin.distance_to(before))
	var sword := sk.find_children("*", "BoneAttachment3D", true, false)
	_check(moved > 0.2 and sword.size() >= 3, "squelette : coup d'épée animé (main %.2f m), épée, bouclier et casque accrochés aux os" % moved)
	skel.queue_free()
	await _frames(1)
	# Ennemi posé tourné (marqueur, apparition au hasard) : le corps reste droit, c'est le modèle
	# qui prend l'orientation, sinon le regard (angle du monde) le ferait marcher de travers.
	var rat := Rat.new()
	rat.rotation.y = 1.3
	add_child(rat)
	rat.set_physics_process(false)
	await _frames(1)
	var fwd := rat.model.global_basis.z.normalized()
	_check(is_zero_approx(rat.rotation.y) and fwd.distance_to(Basis(Vector3.UP, 1.3).z) < 0.01,
		"ennemi posé tourné : le modèle regarde où il va (corps droit, orientation sur le modèle)")
	rat.queue_free()
	await _frames(1)


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
		if not bool(d1_doors[i]["locked"]) and not bool(d1_doors[i]["doorway"]):
			opened = i
			break
	d1.call("_on_door", opened)
	var chief_sk: Skeleton = d1.get("chief")
	chief_sk.set_dormant(false)
	chief_sk.take_damage(99999, chief_sk.global_position + Vector3(0.1, 0, 0), 0.0, false, "phys")
	await _frames(3)
	GameState.stats.xp = 0
	hero.global_position += Vector3(1.0, 0, 0)
	# Touche T : 3 s d'incantation (barre d'incantation) ; bouger l'interrompt.
	var hud := (d1 as Level).hud
	# Pendant un dialogue, la barre de sorts s'efface ; elle revient à la fermeture.
	Events.dialogue_requested.emit("gerald")
	await _frames(2)
	var hidden_in_dialogue := hud.dialogue.visible and not hud.skill_bar.visible
	hud.dialogue.close()
	await _frames(2)
	_check(hidden_in_dialogue and hud.skill_bar.visible, "la barre de sorts disparaît pendant les dialogues")
	Events.town_portal_requested.emit()
	await _frames(2)
	var casting := float(d1.get("_portal_cast")) >= 0.0 and hud.cast_box.visible and GameState.town_portal.is_empty()
	hero.global_position += Vector3(0.6, 0, 0)
	await _frames(2)
	_check(casting and float(d1.get("_portal_cast")) < 0.0 and not hud.cast_box.visible and GameState.town_portal.is_empty(),
		"touche T : incantation du portail (barre), interrompue si le héros bouge")
	Events.town_portal_requested.emit()
	await get_tree().create_timer(Balance.TOWN_PORTAL_CAST * 0.5).timeout
	var half_way := GameState.town_portal.is_empty()
	await get_tree().create_timer(Balance.TOWN_PORTAL_CAST * 0.5 + 0.3).timeout
	var tp: Array = GameState.town_portal.get("pos", [])
	_check(half_way and tp.size() == 2 and _blue_portals(d1) == 1 and not hud.cast_box.visible,
		"touche T : portail bleu ouvert après %.0f s d'incantation" % Balance.TOWN_PORTAL_CAST)
	# Un seul portail par joueur : en ouvrir un autre referme le premier.
	hero.global_position += Vector3(0.0, 0, 1.0)
	Events.town_portal_requested.emit()
	await get_tree().create_timer(Balance.TOWN_PORTAL_CAST + 0.3).timeout
	await _frames(2)
	tp = GameState.town_portal.get("pos", [])
	_check(_blue_portals(d1) == 1 and tp.size() == 2, "un seul portail bleu par joueur (le précédent se referme)")
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
	# Plumeau posé dans un tonneau (comme à son retour) : il en sort et suit le héros sans rester coincé.
	var barrel := Vector3.INF
	for m in tavern.find_children("Tonneau*", "", true, false):
		barrel = (m as Node3D).global_position
		break
	var cub := OwlbearCub.new()
	tavern.add_child(cub)
	cub.global_position = barrel if barrel != Vector3.INF else t_hero.global_position
	cub.follow(t_hero)
	await get_tree().create_timer(2.5).timeout
	var walker: NavWalker = cub.get("_walker")
	var free := walker.snap(cub.global_position)
	_check(barrel != Vector3.INF and Vector2(free.x - cub.global_position.x, free.z - cub.global_position.z).length() < 0.2
		and cub.global_position.distance_to(barrel) > 0.3, "Plumeau apparu dans un tonneau : il en sort (zone praticable)")
	cub.queue_free()
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


func _blue_portals(level: Node) -> int:
	var n := 0
	for c in level.get_children():
		if c is Portal and (c as Portal).blue and not c.is_queued_for_deletion():
			n += 1
	return n


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


func _test_loot_and_gear() -> void:
	print("[Butin sur les corps, barres de vie, Gérald, Zarathos]")
	GameState.new_game()
	var skel := Skeleton.new()
	add_child(skel)
	skel.set_physics_process(false)
	await _frames(1)
	# Barre de vie : elle se vide de la droite vers la gauche (le bord gauche ne bouge pas).
	skel.take_damage(skel.max_hp / 2, skel.global_position + Vector3(0.1, 0, 0), 0.0)
	var q := skel._hp_fill.mesh as QuadMesh
	_check(absf(q.center_offset.x - q.size.x * 0.5 + 0.43) < 0.001 and q.size.x < 0.75,
		"barre de vie des ennemis : elle se vide de la droite vers la gauche")
	# Butin : il reste sur le corps, qui ne disparaît pas tant qu'on ne l'a pas fouillé.
	skel.loot.append({"kind": "gold", "value": 7})
	skel.loot.append({"kind": "item", "item": "bottes_roadie"})
	var gold0 := GameState.gold
	skel.take_damage(9999, skel.global_position + Vector3(0.1, 0, 0), 0.0)
	await _frames(3)
	var spot := skel._loot_spot
	_check(spot != null and spot.is_in_group("interactable") and spot.get_prompt().contains("Bottes de roadie")
		and spot.click_height < 1.0, "corps à fouiller (clic ou E) : « %s »" % (spot.get_prompt() if spot else ""))
	var glow := [] as Array[float]
	for k in 4:
		await get_tree().create_timer(0.5).timeout
		glow.append(skel._glow_light.light_energy)
	var mat: StandardMaterial3D = skel._flash_mats[0]
	_check(skel._glow_tween != null and skel._glow_tween.is_running() and glow.max() - glow.min() > 0.8
		and mat.emission.is_equal_approx(Enemy.LOOT_GLOW) and is_equal_approx(Enemy.LOOT_GLOW_FADE, 1.0),
		"équipement à ramasser : le corps « respire » en doré (fondu d'une seconde)")
	await get_tree().create_timer(2.0).timeout
	_check(is_instance_valid(skel) and skel.model.scale.y > 0.5, "le corps reste au sol tant que le butin est là")
	spot.interact(null)
	_check(GameState.gold >= gold0 + 7 and GameState.inventory.has("bottes_roadie") and skel.loot.is_empty(),
		"fouiller le corps : médiators et équipement ramassés")
	await get_tree().create_timer(0.9).timeout
	_check(not is_instance_valid(skel), "une fois fouillé, le corps disparaît")
	# Une potion seule suffit pour que le corps scintille.
	var skel2 := Skeleton.new()
	add_child(skel2)
	skel2.set_physics_process(false)
	await _frames(1)
	skel2.loot.append({"kind": "potion"})
	skel2.take_damage(9999, skel2.global_position + Vector3(0.1, 0, 0), 0.0)
	await _frames(3)
	_check(skel2._glow_tween != null and skel2._glow_tween.is_running(), "corps avec une simple potion : il scintille aussi")
	skel2.queue_free()
	# Rat mort : retourné sur le dos, mais au-dessus du sol (on peut le fouiller).
	var rat := Rat.new()
	add_child(rat)
	rat.set_physics_process(false)
	await _frames(1)
	rat.loot.append({"kind": "potion"})
	rat.take_damage(9999, rat.global_position + Vector3(0.1, 0, 0), 0.0)
	await get_tree().create_timer(0.5).timeout
	var low := INF
	for mi in rat.model.find_children("*", "MeshInstance3D", true, false):
		var aabb := (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
		low = minf(low, aabb.position.y)
	_check(low > -0.05 and rat._loot_spot != null, "rat mort sur le dos, au-dessus du sol (%.2f m) : on peut le fouiller" % low)
	rat.queue_free()
	# Gérald revient à la charge 3 s après un refus, puis 2 s, puis 1 s.
	var tavern_script: GDScript = load("res://scripts/world/tavern.gd")
	var delays: Array[float] = []
	for refus in [1, 2, 3, 5]:
		GameState.flags["gerald_refus"] = refus
		delays.append(float(tavern_script.call("plea_delay")))
	GameState.flags.erase("gerald_refus")
	_check(delays == ([3.0, 2.0, 1.0, 1.0] as Array[float]), "Gérald revient au bout de 3 s, puis 2 s, puis 1 s")
	# Zarathos : nouveau modèle (Mage V2), animé.
	var mage := CharacterSkin.create("mage")
	add_child(mage)
	await _frames(2)
	_check(mage != null and mage.skeleton.get_bone_count() == 17 and mage.lengths.has("idle") and mage.lengths.has("walk")
		and is_equal_approx(mage.height, 1.85), "Zarathos : modèle Mage V2 (17 os, repos et marche), 1,85 m")
	mage.queue_free()
	# Coup de guitare : 20 % plus rapide.
	_check(is_equal_approx(Balance.MELEE_COOLDOWN, 0.54) and is_equal_approx(float(HeroAnimator.ONE_SHOTS["smash"]), 0.5)
		and Balance.MELEE_DICE == 6, "coup de guitare : 1d6, 20 % plus rapide (0,54 s)")
	GameState.new_game()


func _test_crypt() -> void:
	print("[Médiators automatiques et Cryptes de la Cathédrale]")
	GameState.new_game()
	# Les médiators filent tout seuls vers le héros, même loin.
	for c in get_children():
		if c is Pickup:
			c.free() # médiators lâchés par les ennemis des tests précédents
	var fake_hero := Node3D.new()
	fake_hero.add_to_group("hero")
	add_child(fake_hero)
	fake_hero.global_position = Vector3(12, 0, 0)
	var gold0 := GameState.gold
	var heroes := get_tree().get_nodes_in_group("hero").size()
	var coin := Pickup.spawn(self, Vector3.ZERO, "gold", 9)
	coin._hero = fake_hero # (d'autres tests ont pu laisser un héros dans le groupe)
	await get_tree().create_timer(2.0).timeout
	var coin_state := "ramassé" if not is_instance_valid(coin) else "en %s, âge %.2f, pause %s, héros %s" % [coin.global_position, coin._age, get_tree().paused, coin._hero]
	_check(GameState.gold == gold0 + 9 and not is_instance_valid(coin), "médiators ramassés automatiquement (ils filent vers le héros, à 12 m ; %d héros ; %s ; or %d → %d)" % [heroes, coin_state, gold0, GameState.gold])
	fake_hero.queue_free()
	await _frames(1)
	# Les Cryptes : générées au hasard, lave, démons au niveau du héros, gardien et portail de sortie.
	GameState.stats.level = 4
	GameState.crypt_seed = 4242
	var crypt: Node = load("res://scenes/crypt.tscn").instantiate()
	add_child(crypt)
	await _frames(20)
	var lava: Array = crypt.get("_lava_zones")
	var imps := 0
	var brutes := 0
	var levels_ok := true
	for c in crypt.get_children():
		if c is DemonImp:
			imps += 1
		if c is DemonBrute:
			brutes += 1
		if c is Enemy:
			levels_ok = levels_ok and (c as Enemy).level == 4
	var exit_portal: DemonPortal = null
	for c in crypt.get_children():
		if c is DemonPortal:
			exit_portal = c
	var guardian: DemonBrute = crypt.get("guardian")
	_check(str(crypt.get("theme")) == "crypte" and not bool(crypt.get("persistent")) and lava.size() >= 2 and imps >= 5 and brutes >= 2
		and levels_ok, "Cryptes : ruisseaux de lave (%d), diablotins (%d), démons cornus (%d), ennemis au niveau du héros" % [lava.size(), imps, brutes])
	_check(guardian != null and guardian.guardian and guardian.is_boss and exit_portal != null and exit_portal.on_enter.is_valid()
		and exit_portal.get_prompt().contains("Chèvre Fringante"), "au fond : le Gardien des Cryptes et le portail qui ramène à la taverne")
	# La lave brûle.
	var hero := crypt.get("hero") as Hero
	var zone: Rect2 = lava[0]
	GameState.hp = GameState.max_hp()
	var hp0 := GameState.hp
	hero.global_position = Vector3(zone.get_center().x, 0, zone.get_center().y)
	await get_tree().create_timer(0.7).timeout
	_check(GameState.hp < hp0, "marcher dans la lave brûle (%d → %d PV)" % [hp0, GameState.hp])
	GameState.hp = GameState.max_hp()
	# On revient toujours au portail démoniaque de la taverne ; les Cryptes seront tirées à nouveau.
	var dest := str(crypt.call("_exit_scene"))
	_check(dest == Router.TAVERN and bool(GameState.flags.get("from_crypt", false)) and GameState.crypt_seed == 0,
		"sortie des Cryptes : retour au portail de la taverne, nouvelles Cryptes au prochain passage")
	GameState.flags.erase("from_crypt")
	crypt.queue_free()
	await _frames(3)
	GameState.new_game()


func _test_chapter_two() -> void:
	print("[Chapitre 2 : la légende de Back Jlack]")
	GameState.new_game()
	GameState.set_quest_state("plumeau", QuestDB.State.OBJECTIVE_DONE)
	GameState.turn_in_quest("plumeau")
	_check(GameState.quest_state("pick_destin") == QuestDB.State.AVAILABLE, "après Plumeau : la quête de l'Inconnue se débloque")
	var d := DialogueDB.get_dialogue("inconnue")
	var actions: Array[String] = []
	for ch: Array in d["choices"]:
		actions.append(str(ch[1]))
	_check(actions.has("accept:pick_destin+story:legende"), "l'Inconnue propose d'écouter la légende")
	# Cinématique : visage de Back Jlack en contre-plongée, orage, puis départ vers l'autre univers.
	var cine := LegendCinematic.play(self)
	await _frames(3)
	var face_ok := cine._model != null and cine._cam.global_position.y < LegendCinematic.FACE.y
	_check(get_tree().paused and face_ok and cine._text.text == str(DialogueDB.LEGEND_LINES[0]) and DialogueDB.LEGEND_LINES[2].contains("Mèhn-Strïm"),
		"cinématique : Back Jlack en gros plan en contre-plongée, sur fond d'orage")
	var ended := [false]
	cine.finished.connect(func() -> void: ended[0] = true)
	for k in DialogueDB.LEGEND_LINES.size():
		cine._next_line()
	await get_tree().create_timer(1.0).timeout
	_check(ended[0] and str(DialogueDB.LEGEND_LINES[-1]).contains("vivre"), "fin de la légende : « ...tu vas la vivre ! »")
	get_tree().paused = false
	cine.queue_free()
	GameState.accept_quest("pick_destin")
	_check(QuestDB.objective_text("pick_destin").contains("épreuve"), "objectif : l'épreuve de Back Jlack")
	# L'autre univers : marches interminables, parvis, Back Jlack, porte scellée.
	GameState.flags["temple_spawn"] = "marches"
	var temple: Node = load("res://scenes/temple.tscn").instantiate()
	add_child(temple)
	await _frames(10)
	var bj: Npc = temple.get("backjlack")
	var door: Interactable = temple.get("door_interact")
	var climb := false
	for c in temple.get_children():
		if c is Interactable and (c as Interactable).prompt.begins_with("Gravir les marches"):
			climb = true
	_check(bj != null and bj.npc_id == "backjlack" and door.prompt.contains("scellée") and climb,
		"Temple du Dragon : marches interminables, Back Jlack, porte scellée")
	var hero := temple.get("hero") as Hero
	# L'épreuve : le solo du sage en entier, une note sur chacune de ses notes (partition détectée dans le morceau).
	temple.call("_on_story_action", "epreuve")
	Events.dialogue_closed.emit()
	await _frames(2)
	var solo := (temple as Level).hud.solo
	var chart := SoloMinigame.chart_of(SoloMinigame.EPREUVE_CHART_PATH)
	var song := load(str(chart.get("source", ""))) as AudioStream
	var synced := song != null and solo._notes.size() == (chart["notes"] as Array).size() and solo._notes.size() >= 40
	var lanes_used := {}
	for i in solo._notes.size():
		lanes_used[int(solo._notes[i]["lane"])] = true
		if i > 0:
			synced = synced and float(solo._notes[i]["time"]) - float(solo._notes[i - 1]["time"]) >= 0.14
	# le morceau est joué en entier : le mini-jeu dure jusqu'à sa fin, la dernière note tombe avant
	synced = synced and absf(solo._end_t - (SoloMinigame.LEAD_TIME + song.get_length() + 0.5)) < 0.1
	synced = synced and float(solo._notes[-1]["time"]) < solo._end_t
	_check(solo._active and solo.mode == "epreuve" and solo._lanes == 4 and lanes_used.size() == 4 and synced
		and solo._clip_source == "res://audio/riffs/chant_de_fer.mp3" and hero.planted,
		"épreuve de Back Jlack : le Chant de fer en entier, %d notes calées sur le morceau, touches 1 2 3 4" % solo._notes.size())
	solo._active = false
	solo.visible = false
	temple.call("_on_trial_finished", "epreuve", 31, 40)
	await _frames(2)
	_check(not bool(GameState.flags.get("temple_trial_ok", false)) and GameState.damage_buff_time <= 0.0 and door.prompt.contains("scellée"),
		"épreuve ratée (31/40, 77 %) : Back Jlack renvoie le héros s'entraîner")
	(temple as Level).hud.dialogue.close()
	GameState.flags["temple_attempts"] = 1 # comme si la réussite venait du premier coup
	temple.call("_on_trial_finished", "epreuve", 33, 40)
	await get_tree().create_timer(3.5).timeout
	var buff := GameState.spell_power()
	_check(bool(GameState.flags.get("temple_trial_ok", false)) and GameState.damage_buff_time > 1000.0 and is_equal_approx(buff, 1.1)
		and door.prompt.begins_with("Entrer"), "épreuve réussie du premier coup : porte ouverte dans le tonnerre, +10 % de dégâts pendant 20 min")
	(temple as Level).hud.dialogue.close()
	_check(QuestDB.objective_text("pick_destin").contains("Temple du Dragon"), "objectif : explorer le temple")
	temple.queue_free()
	await _frames(3)
	# Le temple : nef et fontaine de sang, embuscade de diablotins, ange déchu, partition maudite.
	GameState.active_quest = "pick_destin"
	GameState.dungeon_seed = 777
	GameState.dungeon_state = {}
	var dg: Node = load("res://scenes/dungeon.tscn").instantiate()
	add_child(dg)
	await _frames(20)
	hero = dg.get("hero") as Hero
	var glass := 0
	for c in dg.get_children():
		if c is Node3D and (c as Node3D).get_child_count() > 15 and c.get_children().any(func(n: Node) -> bool: return n is OmniLight3D):
			glass += 1
	_check(str(dg.get("theme")) == "temple" and dg.get("angel") != null and glass >= 1,
		"Temple du Dragon : nef à la fontaine de sang, vitraux, l'ange déchu au fond")
	var gen: DungeonGenerator = dg.get("gen")
	var center: Vector3 = dg.call("cell_to_world", gen.center(gen.start_room))
	var axis: Vector3 = dg.call("_nave_axis")
	hero.global_position = center + axis * 1.0 + dg.call("_nave_side") * 3.2
	await _frames(3)
	var ambush: Array = dg.get("_ambush")
	_check(ambush.size() == 10, "passé la fontaine : une dizaine de démons ailés fondent sur le héros (%d)" % ambush.size())
	for e: Enemy in ambush:
		GameState.hp = GameState.max_hp()
		e.take_damage(99999, e.global_position + Vector3(0.1, 0, 0), 0.0)
	await _frames(5)
	_check(int(dg.get("_ambush_state")) == 2 and bool((dg.get("_state") as Dictionary).get("ambush_done", false)),
		"démons vaincus : un éclair frappe la fontaine dans un coup de tonnerre")
	var angel: FallenAngel = dg.get("angel")
	dg.call("_reveal_room", gen.boss_room)
	angel.take_damage(99999, angel.global_position + Vector3(0.1, 0, 0), 0.0)
	await _frames(5)
	var has_partition := false
	for l: Dictionary in angel.loot:
		has_partition = has_partition or str(l.get("item", "")) == "partition_maudite"
	_check(has_partition and angel._loot_spot != null, "l'ange déchu vaincu : la partition maudite sur son corps")
	angel._loot_spot.interact(null)
	await _frames(3)
	var exit_ok := false
	for c in dg.get_children():
		if c is Portal and (c as Portal).prompt.contains("Back Jlack"):
			exit_ok = true
	_check(GameState.quest_items.has("partition_maudite") and GameState.quest_state("pick_destin") == QuestDB.State.OBJECTIVE_DONE and exit_ok,
		"partition ramassée : objectif accompli, portail vers le parvis de Back Jlack")
	_check(str(dg.call("_exit_scene")) == Router.TEMPLE, "on ressort du temple sur le parvis, dans l'autre univers")
	# Jouer la partition sans le Pick du Destin : la foudre frappe (sans tuer).
	GameState.hp = 5
	var inv := InventoryWindow.new()
	add_child(inv)
	inv._play_partition()
	await _frames(2)
	_check(GameState.hp >= 1 and GameState.hp < 5, "jouer la partition sans le Pick du Destin : la foudre frappe")
	inv.queue_free()
	GameState.hp = GameState.max_hp()
	DialogueDB.get_dialogue("backjlack")
	GameState.run_dialogue_action("turn_in:pick_destin")
	_check(GameState.quest_state("pick_destin") == QuestDB.State.TURNED_IN, "Back Jlack reprend la partition en main : quête terminée")
	dg.queue_free()
	await _frames(3)
	GameState.new_game()
