extends Node
## Coopération en ligne (jusqu'à 6 joueurs) avec un CODE D'INVITATION.
##
## • L'hôte ouvre sa partie (menu pause > Coopération) : le jeu ouvre le port UDP 24565 sur
##   la box par UPnP si possible, puis affiche un code (ex. « 3F7QK-2M9XA ») qui contient
##   son adresse et son port. Il suffit d'envoyer ce code à ses amis.
## • Les amis choisissent « Rejoindre une partie » sur l'écran titre, collent le code, et
##   arrivent avec LEUR personnage (nom, race, niveau, talents) dans la partie de l'hôte,
##   quels que soient les niveaux de chacun.
## • L'hôte fait autorité : il simule les ennemis et envoie leur état ~10 fois par seconde ;
##   les clients lui transmettent leurs coups. Chacun voit les autres joueurs se déplacer,
##   gagne l'XP et ramasse son propre butin. Les sorts de chacun (éclairs, ondes, enceintes,
##   amplis, bouclier, pyrotechnie...) sont visibles et audibles par tous (SpellFx).
##   Quand l'hôte change de lieu (portail, escalier de scène...), tout le groupe le suit.
## Si l'UPnP est indisponible, le code contient l'adresse locale : il marche alors en
## réseau local (ou via un VPN type Tailscale / ZeroTier), sinon il faut ouvrir le port
## 24565 (UDP) sur la box.

signal status_changed(text: String)
signal code_ready(code: String, note: String)
signal roster_changed
## Effet de sort reçu d'un autre joueur (type, identifiant du joueur).
signal spell_fx_received(kind: String, peer_id: int)

const PORT := 24565
const MAX_PLAYERS := Balance.COOP_MAX_PLAYERS
const STATE_RATE := 1.0 / 15.0
const ENEMY_RATE := 0.1
## Ennemis par paquet de synchronisation (6 nombres de 4 octets chacun, sous le MTU d'ENet).
const ENEMIES_PER_PACKET := 50
const CODE_ALPHABET := "0123456789ABCDEFGHJKMNPQRSTVWXYZ" # base 32 de Crockford (pas de I, L, O, U)

## peer_id -> {"name", "appearance", "level"} (tous les joueurs, hôte compris).
var players := {}
var code := ""
## false : pas d'ouverture automatique du port sur la box (tests automatiques).
var upnp_enabled := true

var _upnp: UPNP
var _thread: Thread
var _state_timer := 0.0
var _enemy_timer := 0.0
var _enemy_counter := 0
var _enemies := {} # net_id -> WeakRef(Enemy)
var _remotes := {} # peer_id -> RemoteHero (dans le niveau courant)
var _following := false # changement de scène demandé par l'hôte
var _enemy_seq := 0 # numéro de l'envoi en cours (hôte)
var _recv_seq := -1 # envoi en cours de réception (client)
var _recv_seen := {}
var _recv_parts := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


# --- État ------------------------------------------------------------------------------

func is_online() -> bool:
	var peer := multiplayer.multiplayer_peer
	return peer != null and not (peer is OfflineMultiplayerPeer) \
		and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


func is_host() -> bool:
	return is_online() and multiplayer.is_server()


func is_client() -> bool:
	return is_online() and not multiplayer.is_server()


## Nombre de joueurs dans la partie (1 hors ligne).
func player_count() -> int:
	return maxi(1, players.size()) if is_online() else 1


func my_profile() -> Dictionary:
	return {"name": GameState.hero_name, "appearance": GameState.appearance.duplicate(), "level": GameState.stats.level}


# --- Code d'invitation -------------------------------------------------------------------

## Adresse IPv4 + port → code de 10 caractères (« XXXXX-XXXXX »).
static func encode_code(ip: String, port: int) -> String:
	var parts := ip.split(".")
	if parts.size() != 4:
		return ""
	var value := 0
	for p in parts:
		value = (value << 8) | (int(p) & 255)
	value = (value << 16) | (port & 0xFFFF)
	var out := ""
	for i in 10:
		out = CODE_ALPHABET[value & 31] + out
		value >>= 5
	return out.left(5) + "-" + out.right(5)


## Code → {"ip", "port"} ; vide si le code est invalide.
static func decode_code(text: String) -> Dictionary:
	var clean := text.strip_edges().to_upper().replace("-", "").replace(" ", "")
	clean = clean.replace("O", "0").replace("I", "1").replace("L", "1")
	if clean.length() != 10:
		return {}
	var value := 0
	for ch in clean:
		var d := CODE_ALPHABET.find(ch)
		if d < 0:
			return {}
		value = (value << 5) | d
	var port := value & 0xFFFF
	value >>= 16
	var ip := "%d.%d.%d.%d" % [(value >> 24) & 255, (value >> 16) & 255, (value >> 8) & 255, value & 255]
	return {"ip": ip, "port": port}


static func local_ip() -> String:
	for a in IP.get_local_addresses():
		if a.begins_with("192.168.") or a.begins_with("10.") or (a.begins_with("172.") and a.split(".").size() == 4):
			return a
	return "127.0.0.1"


# --- Héberger / rejoindre ----------------------------------------------------------------

func host() -> String:
	if is_online():
		return ""
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_PLAYERS - 1)
	if err != OK:
		return "Impossible d'ouvrir le port %d (%s)." % [PORT, error_string(err)]
	multiplayer.multiplayer_peer = peer
	players = {1: my_profile()}
	roster_changed.emit()
	code = encode_code(local_ip(), PORT)
	if not upnp_enabled:
		_on_upnp_done.call_deferred(null, "")
		return ""
	status_changed.emit("Recherche de la box (UPnP)...")
	_thread = Thread.new()
	_thread.start(_upnp_setup)
	return ""


func _upnp_setup() -> void:
	var upnp := UPNP.new()
	var external := ""
	if upnp.discover(2000, 2, "InternetGatewayDevice") == OK and upnp.get_gateway() != null \
			and upnp.get_gateway().is_valid_gateway():
		if upnp.add_port_mapping(PORT, PORT, "Metal Bard", "UDP") == UPNP.UPNP_RESULT_SUCCESS:
			external = upnp.query_external_address()
	_on_upnp_done.call_deferred(upnp, external)


func _on_upnp_done(upnp: UPNP, external: String) -> void:
	if _thread != null:
		_thread.wait_to_finish()
		_thread = null
	if not is_host():
		return
	var note := ""
	if not external.is_empty():
		_upnp = upnp
		code = encode_code(external, PORT)
		note = "Port %d ouvert automatiquement : vos amis peuvent vous rejoindre par Internet." % PORT
	else:
		code = encode_code(local_ip(), PORT)
		note = "La box n'a pas répondu (UPnP) : ce code marche en réseau local ou via un VPN (Tailscale, ZeroTier). Pour Internet, ouvrez le port %d en UDP sur votre box." % PORT
	code_ready.emit(code, note)
	status_changed.emit("Partie ouverte — code : %s" % code)


func join(invite: String) -> String:
	var target := decode_code(invite)
	if target.is_empty():
		return "Code invalide."
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(str(target["ip"]), int(target["port"]))
	if err != OK:
		return "Connexion impossible (%s)." % error_string(err)
	multiplayer.multiplayer_peer = peer
	status_changed.emit("Connexion à %s..." % invite.to_upper())
	return ""


func leave() -> void:
	if _thread != null:
		_thread.wait_to_finish()
		_thread = null
	if _upnp != null:
		_upnp.delete_port_mapping(PORT, "UDP")
		_upnp = null
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players.clear()
	code = ""
	_clear_remotes()
	roster_changed.emit()
	status_changed.emit("Hors ligne")


func _on_peer_connected(id: int) -> void:
	if multiplayer.is_server():
		Events.notify("Un joueur rejoint la partie...", Events.COLOR_GOOD)
	# Le client s'annonce dans _on_connected ; l'hôte n'a rien à faire ici.
	if not multiplayer.is_server() and id == 1:
		pass


func _on_peer_disconnected(id: int) -> void:
	var p: Dictionary = players.get(id, {})
	players.erase(id)
	if _remotes.has(id):
		var r: Node = _remotes[id]
		if is_instance_valid(r):
			r.queue_free()
		_remotes.erase(id)
	if not p.is_empty():
		Events.notify("%s a quitté la partie." % str(p.get("name", "Un joueur")), Events.COLOR_BAD)
	if multiplayer.is_server():
		_roster.rpc(players)
	roster_changed.emit()


func _on_connected() -> void:
	status_changed.emit("Connecté ! Chargement de la partie de l'hôte...")
	_register.rpc_id(1, my_profile())


func _on_connection_failed() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	status_changed.emit("Échec de la connexion : vérifiez le code, et que l'hôte a bien ouvert sa partie.")


func _on_server_disconnected() -> void:
	leave()
	Events.notify("L'hôte a fermé la partie. Retour à votre propre partie.", Events.COLOR_BAD)
	_following = true
	Router.go_to(Router.TAVERN)


@rpc("any_peer", "reliable")
func _register(profile: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if players.size() >= MAX_PLAYERS:
		multiplayer.multiplayer_peer.disconnect_peer(id)
		return
	players[id] = profile
	Events.notify("%s (%s niv. %d) a rejoint la partie !" % [str(profile.get("name", "?")),
		RaceDB.title(profile.get("appearance", {})), int(profile.get("level", 1))], Events.COLOR_GOLD)
	_roster.rpc(players)
	roster_changed.emit()
	var scene := get_tree().current_scene.scene_file_path if get_tree().current_scene != null else Router.TAVERN
	_goto.rpc_id(id, scene, GameState.dungeon_seed, GameState.active_quest)


@rpc("authority", "reliable")
func _roster(all: Dictionary) -> void:
	players = all
	roster_changed.emit()


# --- Changements de scène : le groupe suit l'hôte ------------------------------------------

## Appelé par Router avant chaque changement de scène.
func on_scene_change(path: String) -> void:
	if path == Router.MAIN_MENU or path == Router.CHARACTER_CREATION:
		return
	if is_host():
		_goto.rpc(path, GameState.dungeon_seed, GameState.active_quest)


@rpc("authority", "reliable")
func _goto(path: String, seed_value: int, quest: String) -> void:
	GameState.dungeon_seed = seed_value
	if path == Router.DUNGEON:
		GameState.flags["in_dungeon"] = true
		if not quest.is_empty() and GameState.active_quest.is_empty():
			GameState.active_quest = quest
	_following = true
	Router.go_to(path)


func take_following_flag() -> bool:
	var f := _following
	_following = false
	return f


# --- Niveau courant : ennemis et autres joueurs ----------------------------------------------

## Nouveau niveau : on oublie les ennemis et les joueurs distants de l'ancien.
func reset_level() -> void:
	_enemy_counter = 0
	_recv_seq = -1
	_enemies.clear()
	_clear_remotes()


func _clear_remotes() -> void:
	for id: int in _remotes:
		var r: Node = _remotes[id]
		if is_instance_valid(r):
			r.queue_free()
	_remotes.clear()


func register_enemy(e: Enemy) -> int:
	var id := e.net_id
	if id < 0:
		id = _enemy_counter
		_enemy_counter += 1
	_enemies[id] = weakref(e)
	return id


func _process(delta: float) -> void:
	if not is_online():
		return
	_state_timer -= delta
	if _state_timer <= 0.0:
		_state_timer = STATE_RATE
		_send_hero_state()
	if is_host():
		_enemy_timer -= delta
		if _enemy_timer <= 0.0:
			_enemy_timer = ENEMY_RATE
			_send_enemy_states()


func _current_scene() -> String:
	var s := get_tree().current_scene
	return s.scene_file_path if s != null else ""


func _send_hero_state() -> void:
	var h := get_tree().get_first_node_in_group("hero") as Hero
	if h == null:
		return
	var flags := 0
	if h.velocity.length() > 0.1:
		flags |= 1
	if h.casting_solo or h.planted or h.talents_caster.in_frenzy:
		flags |= 2
	if h.dashing:
		flags |= 4
	if h.dead:
		flags |= 8
	_hero_state.rpc(_current_scene(), h.global_position, h.model.rotation.y, flags, GameState.hp, GameState.max_hp())


@rpc("any_peer", "unreliable_ordered")
func _hero_state(scene: String, pos: Vector3, yaw: float, flags: int, hp: int, max_hp: int) -> void:
	var id := multiplayer.get_remote_sender_id()
	var level := get_tree().current_scene as Level
	var same_place := level != null and scene == _current_scene() and level.hero != null
	var existing: Variant = _remotes.get(id)
	var remote: RemoteHero = existing as RemoteHero if existing != null and is_instance_valid(existing) else null
	if not same_place:
		if remote != null and is_instance_valid(remote):
			remote.queue_free()
		_remotes.erase(id)
		return
	if remote == null or not is_instance_valid(remote):
		remote = RemoteHero.new()
		remote.peer_id = id
		remote.profile = players.get(id, {"name": "Joueur %d" % id, "appearance": RaceDB.DEFAULT_APPEARANCE, "level": 1})
		remote.position = pos
		level.add_child(remote)
		_remotes[id] = remote
	remote.apply_state(pos, yaw, flags, hp, max_hp)


func _send_enemy_states() -> void:
	var data := PackedFloat32Array()
	for id: int in _enemies.keys():
		var e := (_enemies[id] as WeakRef).get_ref() as Enemy
		if e == null:
			_enemies.erase(id)
			continue
		if e is TrainingDummy:
			continue
		data.append_array(PackedFloat32Array([id, e.global_position.x, e.global_position.z, e.model.rotation.y, e.hp, e.state]))
	if data.is_empty():
		return
	# Découpage en paquets plus petits que la taille maximale d'un paquet réseau (MTU) :
	# un grand donjon dépasse sinon 1 392 octets et le paquet se perd plus souvent.
	var per_packet := ENEMIES_PER_PACKET * 6
	var parts := ceili(float(data.size()) / per_packet)
	_enemy_seq += 1
	for part in parts:
		_enemy_states.rpc(_current_scene(), data.slice(part * per_packet, (part + 1) * per_packet), _enemy_seq, part, parts)


@rpc("authority", "unreliable_ordered")
func _enemy_states(scene: String, data: PackedFloat32Array, seq: int, _part: int, parts: int) -> void:
	if scene != _current_scene():
		return
	var level := get_tree().current_scene as Level
	if level == null:
		return
	if seq != _recv_seq:
		_recv_seq = seq
		_recv_seen = {}
		_recv_parts = 0
	var i := 0
	while i + 5 < data.size():
		var id := int(data[i])
		_recv_seen[id] = true
		var pos := Vector3(data[i + 1], 0.0, data[i + 2])
		var ref: WeakRef = _enemies.get(id)
		var e: Enemy = ref.get_ref() as Enemy if ref != null else null
		if e == null:
			# Ennemi apparu chez l'hôte seulement (renforts du boss) : on le crée ici aussi.
			e = Skeleton.new()
			e.net_id = id
			e.position = pos
			level.add_child(e)
		e.apply_net_state(pos, data[i + 3], int(data[i + 4]), int(data[i + 5]))
		i += 6
	_recv_parts += 1
	if _recv_parts < parts:
		return # la liste complète n'est connue qu'à la réception de tous les morceaux
	# Ennemis déjà éliminés chez l'hôte (on a rejoint en cours de route) : ils disparaissent.
	for id: int in _enemies.keys():
		if _recv_seen.has(id):
			continue
		var e := (_enemies[id] as WeakRef).get_ref() as Enemy
		if e != null and not (e is TrainingDummy) and e.is_alive():
			e.queue_free()
		_enemies.erase(id)


func send_enemy_damage(id: int, amount: int, from: Vector3, knockback: float, crit: bool, kind: String) -> void:
	if is_client():
		_enemy_damage.rpc_id(1, id, amount, from, knockback, crit, kind)


@rpc("any_peer", "reliable")
func _enemy_damage(id: int, amount: int, from: Vector3, knockback: float, crit: bool, kind: String) -> void:
	if not multiplayer.is_server():
		return
	var ref: WeakRef = _enemies.get(id)
	var e: Enemy = ref.get_ref() as Enemy if ref != null else null
	if e != null and e.is_alive():
		e.take_damage(amount, from, knockback, crit, kind)


## Un ennemi de l'hôte touche un autre joueur : c'est ce joueur qui encaisse chez lui.
func hit_player(peer_id: int, amount: int, from: Vector3) -> void:
	_hit_player.rpc_id(peer_id, amount, from)


@rpc("authority", "reliable")
func _hit_player(amount: int, from: Vector3) -> void:
	var h := get_tree().get_first_node_in_group("hero") as Hero
	if h != null:
		h.take_hit(amount, from, null)


## Soins de groupe : chacun soigne son propre personnage.
func heal_player(peer_id: int, amount: int) -> void:
	_heal_player.rpc_id(peer_id, amount)


@rpc("any_peer", "reliable")
func _heal_player(amount: int) -> void:
	var h := get_tree().get_first_node_in_group("hero") as Hero
	if h != null and not h.dead:
		GameState.heal_hero(amount)
		DamageNumber.spawn(h.get_parent(), h.global_position + Vector3(0, 2.3, 0), "+%d" % amount, Events.COLOR_GOOD)


# --- Sorts visibles par tous les joueurs ------------------------------------------------------

## Envoie l'effet d'un sort (apparence seulement) aux autres joueurs du même lieu.
func send_spell_fx(kind: String, data: Dictionary) -> void:
	if is_online():
		_spell_fx.rpc(_current_scene(), kind, data)


@rpc("any_peer", "reliable")
func _spell_fx(scene: String, kind: String, data: Dictionary) -> void:
	if scene != _current_scene():
		return
	var level := get_tree().current_scene as Level
	if level == null:
		return
	var existing: Variant = _remotes.get(multiplayer.get_remote_sender_id())
	var caster: Node3D = existing as Node3D if existing != null and is_instance_valid(existing) else null
	SpellFx.play(level, caster, kind, data, true)
	spell_fx_received.emit(kind, multiplayer.get_remote_sender_id())


## Ennemi du niveau courant par son identifiant réseau (le même chez tous les joueurs).
func enemy_by_id(id: int) -> Enemy:
	var ref: WeakRef = _enemies.get(id)
	var e: Enemy = ref.get_ref() as Enemy if ref != null else null
	return e if e != null and e.is_alive() else null
