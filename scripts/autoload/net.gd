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
## Si l'UPnP est indisponible, l'hôte reçoit plusieurs codes (build_codes) : Internet (adresse
## publique, valable si le port 24565 UDP est ouvert à la main sur la box), VPN (Radmin VPN,
## Tailscale, ZeroTier...) et réseau local. On peut aussi rejoindre en tapant une adresse IP.

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
## Service qui renvoie l'adresse IP publique (texte brut), quand la box ne répond pas en UPnP.
const PUBLIC_IP_URL := "https://api.ipify.org"
## Abandon d'une connexion restée sans réponse de l'hôte (s).
const JOIN_TIMEOUT := 12.0
const NO_ANSWER := "Aucune réponse de l'hôte. Vérifiez qu'il est en jeu, sa partie ouverte, et le code. Par Internet, son port 24565 (UDP) doit être ouvert sur sa box ; sinon, installez tous les deux Radmin VPN ou Tailscale et utilisez son code VPN."
## Mots-clés des cartes réseau VPN -> nom affiché.
const VPN_NAMES := {"radmin": "Radmin VPN", "tailscale": "Tailscale", "zerotier": "ZeroTier", "hamachi": "Hamachi",
	"wireguard": "WireGuard", "openvpn": "OpenVPN"}

## peer_id -> {"name", "appearance", "level"} (tous les joueurs, hôte compris).
var players := {}
var code := ""
## Codes d'invitation de l'hôte, le plus utile en premier : [{"label", "code", "hint"}].
var codes: Array[Dictionary] = []
## false : pas d'ouverture automatique du port sur la box (tests automatiques).
var upnp_enabled := true
## false : pas de requête vers PUBLIC_IP_URL (tests automatiques).
var public_lookup_enabled := true
var _join_attempt := 0

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


## Adresse du PC sur le réseau local (Wi-Fi / Ethernet), hors cartes VPN.
static func local_ip() -> String:
	var best := ""
	for iface: Dictionary in IP.get_local_interfaces():
		if _is_vpn_interface(iface):
			continue
		for a: String in iface.get("addresses", []):
			if a.begins_with("192.168."):
				return a
			if best.is_empty() and (a.begins_with("10.") or _in_172_private(a)):
				best = a
	return best if not best.is_empty() else "127.0.0.1"


## Adresses IPv4 des VPN installés (Radmin VPN, Tailscale, ZeroTier, Hamachi, WireGuard...) :
## [{"name", "ip"}]. Un ami connecté au même VPN rejoint avec ce code, sans toucher à la box.
static func vpn_addresses() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for iface: Dictionary in IP.get_local_interfaces():
		if not _is_vpn_interface(iface):
			continue
		for a: String in iface.get("addresses", []):
			if _is_ipv4(a) and not a.begins_with("169.254.") and not a.begins_with("127."):
				out.append({"name": _vpn_name(iface), "ip": a})
	return out


static func _is_vpn_interface(iface: Dictionary) -> bool:
	var n := str(iface.get("friendly", "")).to_lower()
	for key: String in VPN_NAMES:
		if n.contains(key):
			return true
	for a: String in iface.get("addresses", []):
		if a.begins_with("26.") or _in_cgnat(a): # Radmin VPN (26.x), Tailscale (100.64/10)
			return true
	return false


static func _vpn_name(iface: Dictionary) -> String:
	var n := str(iface.get("friendly", "")).to_lower()
	for key: String in VPN_NAMES:
		if n.contains(key):
			return str(VPN_NAMES[key])
	for a: String in iface.get("addresses", []):
		if a.begins_with("26."):
			return "Radmin VPN"
		if _in_cgnat(a):
			return "Tailscale"
	return "VPN"


static func _is_ipv4(a: String) -> bool:
	return a.is_valid_ip_address() and a.split(".").size() == 4


static func _in_172_private(a: String) -> bool:
	var p := a.split(".")
	return p.size() == 4 and p[0] == "172" and int(p[1]) >= 16 and int(p[1]) <= 31


static func _in_cgnat(a: String) -> bool:
	var p := a.split(".")
	return p.size() == 4 and p[0] == "100" and int(p[1]) >= 64 and int(p[1]) <= 127


## Codes proposés à l'hôte, le plus utile en premier : [{"label", "code", "hint"}].
## `internet_ip` : adresse publique (vide si inconnue) ; `port_open` : port ouvert par UPnP.
static func build_codes(internet_ip: String, port_open: bool, vpns: Array[Dictionary], lan_ip: String) -> Array[Dictionary]:
	var internet: Array[Dictionary] = []
	if _is_ipv4(internet_ip):
		var hint := "Pour les amis n'importe où : le port a été ouvert automatiquement."
		if not port_open:
			hint = "Pour les amis n'importe où, SEULEMENT si le port %d (UDP) est ouvert vers ce PC (%s) sur votre box." % [PORT, lan_ip]
		internet.append({"label": "Internet", "code": encode_code(internet_ip, PORT), "hint": hint})
	var vpn: Array[Dictionary] = []
	for v: Dictionary in vpns:
		vpn.append({"label": str(v["name"]), "code": encode_code(str(v["ip"]), PORT),
			"hint": "Pour les amis connectés au même réseau %s." % str(v["name"])})
	var lan: Array[Dictionary] = [{"label": "Réseau local", "code": encode_code(lan_ip, PORT),
		"hint": "Pour les joueurs sur la même box (même Wi-Fi ou câble)."}]
	# Port ouvert : le code Internet marche à coup sûr ; sinon un VPN est plus fiable.
	var out: Array[Dictionary] = []
	if port_open:
		out.append_array(internet)
		out.append_array(vpn)
	else:
		out.append_array(vpn)
		out.append_array(internet)
	out.append_array(lan)
	return out


## Code ou adresse saisis par un ami : « XXXXX-XXXXX », « 26.1.2.3 » ou « 26.1.2.3:24565 ».
static func parse_invite(text: String) -> Dictionary:
	var t := text.strip_edges()
	var ip := t
	var port := PORT
	if t.count(":") == 1:
		ip = t.get_slice(":", 0)
		port = int(t.get_slice(":", 1))
	if _is_ipv4(ip) and port > 0 and port < 65536:
		return {"ip": ip, "port": port}
	return decode_code(t)


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
	codes = build_codes("", false, vpn_addresses(), local_ip())
	code = str(codes[0]["code"])
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
	if not external.is_empty():
		_upnp = upnp
		_publish_codes(external, true)
	elif public_lookup_enabled:
		# Pas d'UPnP : on demande l'adresse publique pour un code Internet (valable si le
		# port a été ouvert à la main sur la box).
		status_changed.emit("La box n'ouvre pas le port automatiquement : recherche de l'adresse publique...")
		_lookup_public_ip()
	else:
		_publish_codes("", false)


func _lookup_public_ip() -> void:
	var http := HTTPRequest.new()
	http.timeout = 6.0
	add_child(http)
	http.request_completed.connect(func(result: int, response: int, _h: PackedStringArray, body: PackedByteArray) -> void: _on_public_ip(http, result, response, body))
	if http.request(PUBLIC_IP_URL) != OK:
		http.queue_free()
		_publish_codes("", false)


func _on_public_ip(http: HTTPRequest, result: int, response: int, body: PackedByteArray) -> void:
	http.queue_free()
	var ip := body.get_string_from_utf8().strip_edges()
	if result != HTTPRequest.RESULT_SUCCESS or response != 200 or not _is_ipv4(ip):
		ip = ""
	if is_host():
		_publish_codes(ip, false)


func _publish_codes(internet_ip: String, port_open: bool) -> void:
	codes = build_codes(internet_ip, port_open, vpn_addresses(), local_ip())
	code = str(codes[0]["code"])
	var note := "Port %d ouvert automatiquement : vos amis peuvent vous rejoindre par Internet." % PORT
	if not port_open:
		note = "Votre box n'a pas ouvert le port automatiquement (UPnP désactivé). Par Internet : ouvrez le port %d (UDP) vers %s sur la box, ou installez tous les deux un VPN (Radmin VPN, Tailscale) — voir LISEZMOI." % [PORT, local_ip()]
	code_ready.emit(code, note)
	status_changed.emit("Partie ouverte — code : %s" % code)


func join(invite: String) -> String:
	var target := parse_invite(invite)
	if target.is_empty():
		return "Code invalide."
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(str(target["ip"]), int(target["port"]))
	if err != OK:
		return "Connexion impossible (%s)." % error_string(err)
	multiplayer.multiplayer_peer = peer
	status_changed.emit("Connexion à %s..." % invite.strip_edges().to_upper())
	_join_attempt += 1
	var attempt := _join_attempt
	get_tree().create_timer(JOIN_TIMEOUT, true, false, true).timeout.connect(func() -> void: _on_join_timeout(attempt))
	return ""


## Pas de réponse de l'hôte : on abandonne avec des pistes (ENet attendrait bien plus longtemps).
func _on_join_timeout(attempt: int) -> void:
	var peer := multiplayer.multiplayer_peer
	if attempt != _join_attempt or peer == null or peer is OfflineMultiplayerPeer:
		return
	if peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTING:
		return
	peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	status_changed.emit(NO_ANSWER)


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
	codes.clear()
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
	status_changed.emit(NO_ANSWER)


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
	_goto.rpc_id(id, scene, _seed_for(scene), GameState.active_quest)


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
		_goto.rpc(path, _seed_for(path), GameState.active_quest)


## Graine du donjon de la scène : celle des Cryptes (tirée à chaque passage) ou celle du donjon de quête.
func _seed_for(path: String) -> int:
	return GameState.crypt_seed if path == Router.CRYPT else GameState.dungeon_seed


@rpc("authority", "reliable")
func _goto(path: String, seed_value: int, quest: String) -> void:
	if path == Router.CRYPT:
		GameState.crypt_seed = seed_value
	else:
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
