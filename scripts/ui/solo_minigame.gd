class_name SoloMinigame
extends Control
## Mini-jeu du « Solo de la Foudre », façon Guitar Hero.
## 6 notes (calées sur solo_del_la_foudre.mp3) descendent sur 4 cordes ; il faut appuyer au bon moment
## (touches 1 2 3 4). Le jeu continue pendant le solo : le héros reste sur place,
## invincible, et les ennemis continuent d'avancer.
## Résultat : 6/6 = pluie d'éclairs à 100 %, 5/6 = 70 %, 3-4/6 = 45 %, moins = fausse note.

const LANES := 4
const NOTE_SPEED := 330.0 # pixels par seconde
const LEAD_TIME := 1.5 # temps de chute de la première note
const WINDOW_PERFECT := 0.08
const WINDOW_GOOD := 0.17
const LANE_COLORS := [Color(0.3, 0.9, 0.35), Color(0.95, 0.25, 0.2), Color(1.0, 0.85, 0.2), Color(0.3, 0.55, 1.0)]
const PANEL_SIZE := Vector2(400, 520)
## Épreuve de Back Jlack.

var _notes: Array[Dictionary] = []
var _t := 0.0
var _active := false
var _hits := 0
var _feedback := ""
var _feedback_color := Color.WHITE
var _feedback_t := 0.0
var _lane_flash := [0.0, 0.0, 0.0, 0.0]
var _end_t := 0.0
## "foudre" (Solo de la Foudre, 5 notes), "endiable" (Solo endiablé) ou "ballade" (Ballade
## réparatrice : le vrai solo de la musique de la taverne) ou "epreuve" (épreuve de Back Jlack : le solo du sage « Chant de fer »
## en entier, une note sur chacune de ses notes, voir data/epreuve_solo.json ; il faut 80 %) ou "duel" (duel contre le
## Minotaure, même principe sur « Edge of the Cliff », data/duel_minotaure.json ; 80 % aussi).
## Tous sauf le Solo de la Foudre, l'épreuve et le duel s'arrêtent à la première fausse note.
var mode := "foudre"
## Extrait musical de la Ballade : lancé quand _t atteint _clip_at, à partir de _clip_offset.
var _clip_source := ""
var _clip_offset := 0.0
var _clip_at := 0.0
var _clip_started := true
## Mini-jeux de l'histoire, lancés par un dialogue : en coopération, seul le joueur qui a lancé le dialogue les joue ;
## les autres joueurs du même lieu les regardent en direct (Net.send_minigame) : les notes qui tombent, les touches
## qu'il joue (PARFAIT, BIEN, RATÉ) et le morceau, calés sur le même temps.
const SHARED := ["epreuve", "duel"]
## On regarde le mini-jeu d'un autre joueur (ses touches arrivent par le réseau ; les nôtres restent libres).
var spectating := false
var _player_id := 0
var _player_name := ""
## Spectateur : si la fin n'arrive pas (joueur déconnecté), le panneau se ferme quand même au bout de ce délai (s).
const SPECTATE_GRACE := 4.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	Events.solo_requested.connect(start)
	Net.minigame_received.connect(_on_minigame_received)


## Lance le mini-jeu `solo_mode` ; `watch` : on regarde celui d'un autre joueur (voir SHARED).
func start(solo_mode: String = "foudre", note_count: int = Balance.SOLO_NOTES, watch: bool = false) -> void:
	if _active and _clip_source != "":
		Sfx.stop_clip() # on regardait un autre joueur : son morceau s'arrête
	spectating = watch
	mode = solo_mode
	_clip_started = true
	_clip_source = ""
	_notes.clear()
	var t := LEAD_TIME
	var last_lane := -1
	if mode in CHARTED:
		# Ballade (le solo de la musique de la taverne) et épreuve de Back Jlack (le solo du sage en entier) :
		# une note par note du morceau, détectées dans l'enregistrement (tools/audio/detect_notes.py).
		note_count = 0
		var chart := chart_of(str(CHARTED[mode]))
		for n: Dictionary in chart.get("notes", []):
			_notes.append({"lane": int(n["lane"]), "time": LEAD_TIME + float(n["t"]), "judged": false, "hit": false})
		t = LEAD_TIME + float(chart.get("duration", 10.0))
		# La musique démarre en avance pour que chaque note tombe sur la cible au moment où
		# elle résonne dans le morceau.
		# (si l'extrait commence au tout début du fichier, on attend que la 1re note ait eu
		# le temps de tomber avant de lancer le son).
		var start := float(chart.get("start", 0.0))
		_clip_source = str(chart.get("source", ""))
		_clip_offset = maxf(0.0, start - LEAD_TIME)
		_clip_at = maxf(0.0, LEAD_TIME - start)
		_clip_started = false
	elif mode == "foudre":
		# Solo de la Foudre : le morceau solo_del_la_foudre.mp3, avec des notes réparties
		# régulièrement du début à la fin (la 1re tombe quand le morceau démarre).
		var stream := load(Sfx.SOLO_FOUDRE_FILE) as AudioStream
		var length := stream.get_length() if stream != null else 8.0
		var margin := 0.25
		for i in note_count:
			var lane := randi_range(0, LANES - 1)
			if lane == last_lane:
				lane = (lane + randi_range(1, LANES - 1)) % LANES
			last_lane = lane
			var at := margin + (length - 2.0 * margin) * float(i) / float(maxi(1, note_count - 1))
			_notes.append({"lane": lane, "time": LEAD_TIME + at, "judged": false, "hit": false})
		t = LEAD_TIME + length - margin
		note_count = 0
		_clip_source = Sfx.SOLO_FOUDRE_FILE if stream != null else ""
		_clip_offset = 0.0
		_clip_at = LEAD_TIME
		_clip_started = stream == null
	for i in note_count:
		var lane := randi_range(0, LANES - 1)
		if lane == last_lane:
			lane = (lane + randi_range(1, LANES - 1)) % LANES
		last_lane = lane
		_notes.append({"lane": lane, "time": t, "judged": false, "hit": false})
		t += randf_range(0.34, 0.5) if mode == "endiable" else randf_range(0.38, 0.6)
	_end_t = t + 0.5
	_t = 0.0
	_hits = 0
	_feedback = "PRÉPARE-TOI !"
	_feedback_color = Color(1.0, 0.85, 0.4)
	_feedback_t = 1.2
	_active = true
	visible = true
	if mode == "endiable":
		Sfx.play("solo_start", -4.0, 0.0)
	if mode in SHARED and not spectating:
		Net.send_minigame("start", {"mode": mode}) # les autres joueurs le regardent en direct


func _process(delta: float) -> void:
	if not _active:
		return
	_t += delta
	if not _clip_started and _t >= _clip_at:
		_clip_started = true
		var volume := -4.0 + (EPREUVE_GAIN_DB if mode == "epreuve" else 0.0)
		# Solo de la Foudre : la musique de fond continue, baissée de 20 % ; les autres solos la coupent.
		Sfx.play_clip(_clip_source, _clip_offset + (_t - _clip_at), volume, 0.8 if mode == "foudre" else 0.0)
	_feedback_t -= delta
	for i in LANES:
		_lane_flash[i] = maxf(0.0, float(_lane_flash[i]) - delta * 4.0)
	if spectating:
		# Les notes ratées, jouées et la fin viennent du joueur (réseau) ; secours s'il s'est déconnecté.
		if _t >= _end_t + SPECTATE_GRACE:
			_finish()
		queue_redraw()
		return
	for i in _notes.size():
		var n := _notes[i]
		if not n["judged"] and _t > float(n["time"]) + _window_good():
			n["judged"] = true
			_set_feedback("RATÉ", Color(1.0, 0.35, 0.3))
			Sfx.play("dud", -10.0)
			if mode in SHARED:
				Net.send_minigame("miss", {"note": i})
			if mode not in ["foudre", "epreuve", "duel"]:
				_finish() # fausse note : la transe se brise / la ballade s'interrompt
				return
	if _t >= _end_t and _all_judged():
		_finish()
	queue_redraw()


func _all_judged() -> bool:
	for n in _notes:
		if not n["judged"]:
			return false
	return true


func _input(event: InputEvent) -> void:
	if not _active or spectating:
		return
	for lane in LANES:
		if event.is_action_pressed("solo_lane_%d" % lane):
			_press(lane)
			get_viewport().set_input_as_handled()
			return


func _press(lane: int) -> void:
	_lane_flash[lane] = 1.0
	var best: Dictionary = {}
	var best_i := -1
	var best_err := INF
	for i in _notes.size():
		var n := _notes[i]
		if n["judged"] or int(n["lane"]) != lane:
			continue
		var err := absf(float(n["time"]) - _t)
		if err <= _window_good() and err < best_err:
			best_err = err
			best = n
			best_i = i
	var perfect := best_err <= WINDOW_PERFECT
	if mode in SHARED:
		Net.send_minigame("press", {"lane": lane, "note": best_i, "perfect": perfect})
	if best.is_empty():
		Sfx.play("dud", -14.0)
		return
	best["judged"] = true
	best["hit"] = true
	_hits += 1
	Events.solo_note_hit.emit(mode, _hits)
	if mode == "endiable": # les autres solos jouent un vrai morceau
		Sfx.play("note_%d" % lane, -3.0, 0.0)
	if perfect:
		_set_feedback("PARFAIT !", Color(1.0, 0.9, 0.3))
	else:
		_set_feedback("BIEN", Color(0.6, 0.95, 0.6))


func _window_good() -> float:
	return WINDOW_GOOD


func _set_feedback(text: String, color: Color) -> void:
	_feedback = text
	_feedback_color = color
	_feedback_t = 0.6


func _finish() -> void:
	if _clip_source != "":
		Sfx.stop_clip()
	_active = false
	visible = false
	if spectating:
		spectating = false # on regardait : le résultat est celui du joueur (pas de solo_finished chez nous)
		return
	if mode in SHARED:
		Net.send_minigame("end", {"hits": _hits, "total": _notes.size()})
	Events.solo_finished.emit(mode, _hits, _notes.size())


## Mini-jeu d'un autre joueur (coopération) : on le regarde, en direct.
func _on_minigame_received(event: String, data: Dictionary, peer_id: int) -> void:
	if event == "start":
		if _active and not spectating:
			return # on joue déjà son propre mini-jeu
		_player_id = peer_id
		_player_name = Net.player_name(peer_id)
		start(str(data.get("mode", "")), 0, true)
		return
	if not (_active and spectating and peer_id == _player_id):
		return
	var i := int(data.get("note", -1))
	var known := i >= 0 and i < _notes.size()
	match event:
		"press":
			_lane_flash[clampi(int(data.get("lane", 0)), 0, LANES - 1)] = 1.0
			if not known:
				Sfx.play("dud", -14.0)
				return
			_notes[i]["judged"] = true
			_notes[i]["hit"] = true
			_hits += 1
			if bool(data.get("perfect", false)):
				_set_feedback("PARFAIT !", Color(1.0, 0.9, 0.3))
			else:
				_set_feedback("BIEN", Color(0.6, 0.95, 0.6))
		"miss":
			if known:
				_notes[i]["judged"] = true
			_set_feedback("RATÉ", Color(1.0, 0.35, 0.3))
			Sfx.play("dud", -10.0)
		"end":
			var hits := int(data.get("hits", _hits))
			var total := maxi(1, int(data.get("total", _notes.size())))
			Events.notify("%s : %d / %d notes justes (%d %%)" % [_player_name, hits, total, roundi(100.0 * hits / total)], Events.COLOR_GOLD)
			_finish()


func _draw() -> void:
	if not _active:
		return
	var font := UiStyle.serif()
	var vp := get_viewport_rect().size
	# Panneau sur la droite de l'écran : l'action reste visible (le jeu n'est pas en pause).
	var size := PANEL_SIZE
	var origin := Vector2(vp.x - size.x - 40.0, (vp.y - size.y) * 0.5)
	var panel := Rect2(origin, size)
	draw_rect(panel, Color(0.05, 0.03, 0.04, 0.88))
	draw_rect(panel, UiStyle.BORDER, false, 3.0)
	var titles := {"endiable": "SOLO ENDIABLÉ", "ballade": "BALLADE RÉPARATRICE", "foudre": "SOLO DE LA FOUDRE", "epreuve": "L'ÉPREUVE DE BACK JLACK", "duel": "DUEL : LE MINOTAURE"}
	var tags := {"endiable": "TRANSE", "ballade": "SOINS", "foudre": "INVINCIBLE", "epreuve": "80 % requis", "duel": "80 % requis"}
	var title := str(titles.get(mode, "SOLO"))
	draw_string(font, origin + Vector2(0, 42), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, 30, Color(1.0, 0.8, 0.4))
	draw_string(font, origin + Vector2(0, 70), "%d / %d notes  •  %s" % [_hits, _notes.size(), str(tags.get(mode, ""))], HORIZONTAL_ALIGNMENT_CENTER, size.x, 18, Color(1.0, 0.85, 0.45))

	var lane_w := 76.0
	var lanes_x := origin.x + (size.x - lane_w * LANES) * 0.5
	var top := origin.y + 90.0
	var hit_y := origin.y + size.y - 90.0
	var speed := NOTE_SPEED
	for i in LANES:
		var x := lanes_x + i * lane_w
		var c: Color = LANE_COLORS[i]
		var flash := float(_lane_flash[i])
		draw_rect(Rect2(x + 4, top, lane_w - 8, hit_y - top + 30), Color(c.r, c.g, c.b, 0.06 + flash * 0.25))
		draw_line(Vector2(x + lane_w * 0.5, top), Vector2(x + lane_w * 0.5, hit_y + 30), Color(0.8, 0.8, 0.8, 0.25), 2.0)
		# Cible.
		draw_arc(Vector2(x + lane_w * 0.5, hit_y), 26, 0, TAU, 32, c.lightened(flash * 0.5), 4.0)
		draw_string(font, Vector2(x, hit_y + 66), Controls.key_label("solo_lane_%d" % i), HORIZONTAL_ALIGNMENT_CENTER, lane_w, 30, UiStyle.BONE)
	draw_line(Vector2(lanes_x, hit_y), Vector2(lanes_x + lane_w * LANES, hit_y), Color(1, 1, 1, 0.3), 2.0)
	# Notes.
	for n in _notes:
		if n["judged"] and n["hit"]:
			continue
		var y := hit_y - (float(n["time"]) - _t) * speed
		if y < top - 20 or y > hit_y + 40:
			continue
		var lane := int(n["lane"])
		var c: Color = LANE_COLORS[lane]
		if n["judged"]:
			c = Color(0.3, 0.3, 0.3)
		var center := Vector2(lanes_x + lane * lane_w + lane_w * 0.5, y)
		draw_circle(center, 22, c)
		draw_circle(center, 12, c.lightened(0.5))
	if _feedback_t > 0.0:
		var a := clampf(_feedback_t / 0.3, 0.0, 1.0)
		draw_string(font, Vector2(origin.x, origin.y + size.y * 0.45), _feedback, HORIZONTAL_ALIGNMENT_CENTER,
			size.x, 40, Color(_feedback_color.r, _feedback_color.g, _feedback_color.b, a))
	if spectating:
		# Sous le panneau : qui joue (on le regarde en direct).
		draw_circle(origin + Vector2(22, size.y + 26), 7, Color(1.0, 0.2, 0.15, 0.6 + 0.4 * absf(sin(_t * 4.0))))
		draw_string(font, origin + Vector2(36, size.y + 33), "EN DIRECT : %s joue" % _player_name, HORIZONTAL_ALIGNMENT_LEFT,
			size.x - 36, 20, UiStyle.BONE)



const BALLADE_CHART_PATH := "res://data/ballade_solo.json"
const EPREUVE_CHART_PATH := "res://data/epreuve_solo.json"
## Duel contre le Minotaure (Labyrinthe du Destin) : « Edge of the Cliff », audio/riffs/edge_of_the_cliff.mp3.
const DUEL_CHART_PATH := "res://data/duel_minotaure.json"
## Solos joués sur un vrai morceau, une note du mini-jeu par note détectée (mode -> partition).
const CHARTED := {"ballade": BALLADE_CHART_PATH, "epreuve": EPREUVE_CHART_PATH, "duel": DUEL_CHART_PATH}
## Le Chant de fer joué 20 % plus fort que les autres solos (amplitude × 1,2, soit +1,6 dB).
const EPREUVE_GAIN_DB := 1.58
static var _chart_cache := {}


## Partition du solo de la Ballade réparatrice (voir data/ballade_solo.json).
static func ballade_chart() -> Dictionary:
	return chart_of(BALLADE_CHART_PATH)


## Partition d'un solo (data/*.json : source, duration, notes [{t, lane}]), mise en cache.
static func chart_of(path: String) -> Dictionary:
	if not _chart_cache.has(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		_chart_cache[path] = parsed if parsed is Dictionary else {}
	return _chart_cache[path]
