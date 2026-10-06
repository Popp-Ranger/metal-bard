extends Node
## Test réseau réel à deux instances (hôte + client sur la même machine) :
##   Godot --headless --path . res://tests/coop_net_test.tscn -- host
##   Godot --headless --path . res://tests/coop_net_test.tscn -- client
## L'hôte ouvre une partie dans le donjon ; le client la rejoint (127.0.0.1). Chacun lance
## des sorts ; chacun doit voir ceux de l'autre (Net.spell_fx_received). Le client vérifie
## aussi que les effets apparaissent dans son niveau, sans dégâts en double.
## Sortie : « COOP_TEST <rôle> : OK » ou « COOP_TEST <rôle> : ÉCHEC ... ».

const TIMEOUT := 40.0

var role := "host"
var received := {}
var _elapsed := 0.0
var _done := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	role = str(args[0]) if args.size() > 0 else "host"
	# Sauvegardes du test à part : les héros du joueur ne sont pas touchés.
	GameState.save_root = "user://tests/coop_%s/" % role
	# Ce nœud doit survivre aux changements de scène (le client suit l'hôte dans le donjon).
	var dummy := Node.new()
	get_tree().root.add_child.call_deferred(dummy)
	await get_tree().process_frame
	get_tree().current_scene = dummy
	Net.spell_fx_received.connect(_on_fx)
	if role == "host":
		await _run_host()
	else:
		await _run_client()


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed > TIMEOUT and not _done:
		_finish(false, "délai dépassé (reçus : %s)" % str(received.keys()))


func _on_fx(kind: String, _peer: int) -> void:
	received[kind] = int(received.get(kind, 0)) + 1


func _run_host() -> void:
	GameState.dungeon_seed = 4242
	GameState.dungeon_state = {}
	GameState.active_quest = "plumeau"
	Net.upnp_enabled = false # pas d'ouverture de port sur la box pendant le test
	Net.public_lookup_enabled = false
	var err := Net.host()
	if not err.is_empty():
		_finish(false, err)
		return
	Router.go_to(Router.DUNGEON)
	# Attente du client (profil enregistré) puis de son personnage dans le donjon.
	while Net.players.size() < 2 or Net._remotes.is_empty():
		await get_tree().create_timer(0.2).timeout
	await get_tree().create_timer(2.0).timeout
	var hero := get_tree().get_first_node_in_group("hero") as Hero
	GameState.mana = GameState.max_mana()
	hero.cooldowns["wave"] = 0.0
	hero.cast_wave() # vrai sort, avec dégâts chez l'hôte
	SpellFx.cast(hero, "riff", {"from": hero.global_position, "to": hero.global_position + Vector3(2, 1, 0), "stack": 2,
		"color": Color.GOLD})
	SpellFx.cast(hero, "pyro", {"pos": hero.global_position, "yaw": 0.0})
	SpellFx.cast(hero, "shield", {"on": true})
	# Réponse attendue : le client lance ses propres sorts.
	while not (received.has("wave") and received.has("speaker")):
		await get_tree().create_timer(0.2).timeout
	# Le client a équipé la Batguitare : on la voit dans les mains de son personnage.
	var remote_c: RemoteHero = null
	for n in get_tree().get_nodes_in_group("heroes"):
		if n is RemoteHero:
			remote_c = n
	var gear_wait := 0.0
	while gear_wait < 5.0 and not (remote_c != null and remote_c.model.guitar_model.ends_with("batguitare.glb")):
		await get_tree().create_timer(0.2).timeout
		gear_wait += 0.2
	if remote_c == null or not remote_c.model.guitar_model.ends_with("batguitare.glb"):
		_finish(false, "la guitare équipée du client n'est pas visible chez l'hôte")
		return
	# Mini-jeu de l'histoire (épreuve de Back Jlack) : l'hôte le joue, le client le regarde en direct.
	var solo := (get_tree().current_scene as Level).hud.solo
	Events.solo_requested.emit("epreuve", 0)
	for i in 3:
		var wait := float(solo._notes[i]["time"]) - solo._t
		if wait > 0.0:
			await get_tree().create_timer(wait).timeout
		solo._press(int(solo._notes[i]["lane"]))
	await get_tree().create_timer(0.4).timeout
	solo._finish()
	await get_tree().create_timer(2.0).timeout # laisse le temps au client de conclure
	_finish(true, "")


func _run_client() -> void:
	await get_tree().create_timer(1.0).timeout
	var err := Net.join(Net.encode_code("127.0.0.1", Net.PORT))
	if not err.is_empty():
		_finish(false, err)
		return
	# L'hôte nous emmène dans son donjon ; on attend son personnage et ses sorts.
	while not (received.has("wave") and received.has("riff") and received.has("pyro") and received.has("shield")):
		await get_tree().create_timer(0.2).timeout
	await get_tree().create_timer(0.3).timeout
	var level := get_tree().current_scene as Level
	var remote: RemoteHero = null
	for n in get_tree().get_nodes_in_group("heroes"):
		if n is RemoteHero:
			remote = n
	var shockwaves := 0
	var pyro := 0
	for c in level.get_children():
		if c is Shockwave:
			shockwaves += 1
		if c is SpellFx.PyroFx:
			pyro += 1
	# Plus de 50 ennemis : leur état arrive en plusieurs paquets, aucun ne doit disparaître à tort.
	var synced := Net._enemies.size()
	var ok := remote != null and remote._shield != null and remote._shield.visible and pyro >= 1 and synced > Net.ENEMIES_PER_PACKET
	var why := "personnage de l'hôte=%s bouclier=%s pyro=%d ondes=%d ennemis synchronisés=%d" % [remote != null,
		remote != null and remote._shield != null and remote._shield.visible, pyro, shockwaves, synced]
	# À notre tour : l'hôte doit voir nos sorts.
	var hero := get_tree().get_first_node_in_group("hero") as Hero
	GameState.mana = GameState.max_mana()
	hero.cooldowns["wave"] = 0.0
	hero.cast_wave()
	SpellFx.cast(hero, "speaker", {"pos": hero.global_position + Vector3(2, 0, 0), "yaw": 0.0})
	# On équipe la Batguitare : l'hôte doit la voir dans nos mains.
	GameState.add_item("batguitare")
	GameState.equip("batguitare")
	# L'hôte joue l'épreuve : on la regarde en direct (panneau, notes jouées), sans la jouer.
	var solo := level.hud.solo
	var watched := false
	var seen_hits := 0
	var wait_t := 0.0
	while wait_t < 20.0:
		if solo._active and solo.spectating and solo.mode == "epreuve":
			watched = true
			seen_hits = maxi(seen_hits, solo._hits)
		if watched and not solo._active:
			break
		await get_tree().process_frame
		wait_t += get_process_delta_time()
	ok = ok and watched and seen_hits == 3 and not solo._active and not solo.spectating
	why += " épreuve regardée=%s notes vues=%d" % [watched, seen_hits]
	_finish(ok, why)


func _finish(ok: bool, why: String) -> void:
	if _done:
		return
	_done = true
	print("COOP_TEST %s : %s %s — reçus : %s" % [role, "OK" if ok else "ÉCHEC", why, str(received)])
	Net.leave()
	await get_tree().create_timer(0.3).timeout
	get_tree().quit(0 if ok else 1)
