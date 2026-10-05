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
## Riff électrique : une seule corde (la touche du sort), notes rapides, fenêtres plus serrées.
const RIFF_PANEL_W := 200.0
const RIFF_NOTE_SPEED := 620.0
const RIFF_WINDOW_PERFECT := 0.06
const RIFF_WINDOW_GOOD := 0.12
const RIFF_COLOR := Color(0.4, 0.95, 1.0)
## Épreuve de Back Jlack.

var _notes: Array[Dictionary] = []
var _t := 0.0
var _active := false
var _hits := 0
var _feedback := ""
var _feedback_color := Color.WHITE
var _feedback_t := 0.0
var _lane_flash := [0.0, 0.0, 0.0, 0.0]
var _lanes := LANES
var _end_t := 0.0
## "foudre" (Solo de la Foudre, 5 notes), "endiable" (Solo endiablé) ou "ballade" (Ballade
## réparatrice : le vrai solo de la musique de la taverne) ou "riff" (Riff électrique : une seule note à
## 160 BPM, la 1re jouée en lançant le sort) ou "epreuve" (épreuve de Back Jlack : le solo du sage « Chant de fer »
## en entier, une note sur chacune de ses notes, voir data/epreuve_solo.json ; il faut 80 %).
## Tous sauf le Solo de la Foudre et l'épreuve s'arrêtent à la première fausse note.
var mode := "foudre"
## Extrait musical de la Ballade : lancé quand _t atteint _clip_at, à partir de _clip_offset.
var _clip_source := ""
var _clip_offset := 0.0
var _clip_at := 0.0
var _clip_started := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	Events.solo_requested.connect(start)


func start(solo_mode: String = "foudre", note_count: int = Balance.SOLO_NOTES) -> void:
	mode = solo_mode
	_lanes = 1 if mode == "riff" else LANES
	_clip_started = true
	_clip_source = ""
	_notes.clear()
	var t := LEAD_TIME
	var last_lane := -1
	if mode == "ballade" or mode == "epreuve":
		# Ballade (le solo de la musique de la taverne) et épreuve de Back Jlack (le solo du sage en entier) :
		# une note par note du morceau, détectées dans l'enregistrement (tools/audio/detect_notes.py).
		note_count = 0
		var chart := chart_of(BALLADE_CHART_PATH if mode == "ballade" else EPREUVE_CHART_PATH)
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
	if mode == "riff":
		# La même note à 160 BPM : la 1re est partie avec le sort, les suivantes tombent sur chaque temps.
		var beat := 60.0 / Balance.RIFF_BPM
		for i in range(1, note_count):
			_notes.append({"lane": 0, "time": beat * i, "judged": false, "hit": false})
		t = beat * (note_count - 1)
		note_count = 0
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
	_feedback = "EN RYTHME !" if mode == "riff" else "PRÉPARE-TOI !"
	_feedback_color = Color(1.0, 0.85, 0.4)
	_feedback_t = 1.2
	_active = true
	visible = true
	if mode == "endiable":
		Sfx.play("solo_start", -4.0, 0.0)


func _process(delta: float) -> void:
	if not _active:
		return
	_t += delta
	if not _clip_started and _t >= _clip_at:
		_clip_started = true
		var volume := -4.0 + (EPREUVE_GAIN_DB if mode == "epreuve" else 0.0)
		Sfx.play_clip(_clip_source, _clip_offset + (_t - _clip_at), volume)
	_feedback_t -= delta
	for i in LANES:
		_lane_flash[i] = maxf(0.0, float(_lane_flash[i]) - delta * 4.0)
	for n in _notes:
		if not n["judged"] and _t > float(n["time"]) + _window_good():
			n["judged"] = true
			_set_feedback("RATÉ", Color(1.0, 0.35, 0.3))
			Sfx.play("dud", -10.0)
			if mode != "foudre" and mode != "epreuve":
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
	if not _active:
		return
	for lane in _lanes:
		if event.is_action_pressed("solo_lane_%d" % lane):
			_press(lane)
			get_viewport().set_input_as_handled()
			return


func _press(lane: int) -> void:
	_lane_flash[lane] = 1.0
	var best: Dictionary = {}
	var best_err := INF
	for n in _notes:
		if n["judged"] or int(n["lane"]) != lane:
			continue
		var err := absf(float(n["time"]) - _t)
		if err <= _window_good() and err < best_err:
			best_err = err
			best = n
	if best.is_empty():
		Sfx.play("dud", -14.0)
		if mode == "riff":
			# Riff : un appui à contretemps est une fausse note.
			_set_feedback("CONTRETEMPS", Color(1.0, 0.35, 0.3))
			_finish()
		return
	best["judged"] = true
	best["hit"] = true
	_hits += 1
	Events.solo_note_hit.emit(mode, _hits)
	if mode == "endiable": # les autres solos jouent un vrai morceau
		Sfx.play("note_%d" % lane, -3.0, 0.0)
	if best_err <= (RIFF_WINDOW_PERFECT if mode == "riff" else WINDOW_PERFECT):
		_set_feedback("PARFAIT !", Color(1.0, 0.9, 0.3))
	else:
		_set_feedback("BIEN", Color(0.6, 0.95, 0.6))
	if mode == "riff" and _all_judged():
		_finish() # dernière note du riff : la recharge démarre tout de suite


func _window_good() -> float:
	return RIFF_WINDOW_GOOD if mode == "riff" else WINDOW_GOOD


func _set_feedback(text: String, color: Color) -> void:
	_feedback = text
	_feedback_color = color
	_feedback_t = 0.6


func _finish() -> void:
	if _clip_source != "":
		Sfx.stop_clip()
	_active = false
	visible = false
	Events.solo_finished.emit(mode, _hits, _notes.size())


func _draw() -> void:
	if not _active:
		return
	var font := UiStyle.serif()
	var vp := get_viewport_rect().size
	# Panneau sur la droite de l'écran : l'action reste visible (le jeu n'est pas en pause).
	var size := Vector2(RIFF_PANEL_W, PANEL_SIZE.y) if mode == "riff" else PANEL_SIZE
	var origin := Vector2(vp.x - size.x - 40.0, (vp.y - size.y) * 0.5)
	var panel := Rect2(origin, size)
	draw_rect(panel, Color(0.05, 0.03, 0.04, 0.88))
	draw_rect(panel, UiStyle.BORDER, false, 3.0)
	var titles := {"endiable": "SOLO ENDIABLÉ", "ballade": "BALLADE RÉPARATRICE", "foudre": "SOLO DE LA FOUDRE", "riff": "RIFF", "epreuve": "L'ÉPREUVE DE BACK JLACK"}
	var tags := {"endiable": "TRANSE", "ballade": "SOINS", "foudre": "INVINCIBLE", "riff": "160 BPM", "epreuve": "80 % requis"}
	var riff := 1 if mode == "riff" else 0 # la 1re note du riff est partie avec le sort
	draw_string(font, origin + Vector2(0, 42), str(titles.get(mode, "SOLO")), HORIZONTAL_ALIGNMENT_CENTER, size.x, 30, Color(1.0, 0.8, 0.4))
	draw_string(font, origin + Vector2(0, 70), "%d / %d notes  •  %s" % [_hits + riff, _notes.size() + riff, str(tags.get(mode, ""))], HORIZONTAL_ALIGNMENT_CENTER, size.x, 18, Color(1.0, 0.85, 0.45))

	var lane_w := 76.0
	var lanes_x := origin.x + (size.x - lane_w * _lanes) * 0.5
	var top := origin.y + 90.0
	var hit_y := origin.y + size.y - 90.0
	var speed := RIFF_NOTE_SPEED if mode == "riff" else NOTE_SPEED
	for i in _lanes:
		var x := lanes_x + i * lane_w
		var c: Color = RIFF_COLOR if mode == "riff" else LANE_COLORS[i]
		var flash := float(_lane_flash[i])
		draw_rect(Rect2(x + 4, top, lane_w - 8, hit_y - top + 30), Color(c.r, c.g, c.b, 0.06 + flash * 0.25))
		draw_line(Vector2(x + lane_w * 0.5, top), Vector2(x + lane_w * 0.5, hit_y + 30), Color(0.8, 0.8, 0.8, 0.25), 2.0)
		# Cible.
		draw_arc(Vector2(x + lane_w * 0.5, hit_y), 26, 0, TAU, 32, c.lightened(flash * 0.5), 4.0)
		draw_string(font, Vector2(x, hit_y + 66), Controls.key_label("solo_lane_%d" % i), HORIZONTAL_ALIGNMENT_CENTER, lane_w, 30, UiStyle.BONE)
	draw_line(Vector2(lanes_x, hit_y), Vector2(lanes_x + lane_w * _lanes, hit_y), Color(1, 1, 1, 0.3), 2.0)
	# Notes.
	for n in _notes:
		if n["judged"] and n["hit"]:
			continue
		var y := hit_y - (float(n["time"]) - _t) * speed
		if y < top - 20 or y > hit_y + 40:
			continue
		var lane := int(n["lane"])
		var c: Color = RIFF_COLOR if mode == "riff" else LANE_COLORS[lane]
		if n["judged"]:
			c = Color(0.3, 0.3, 0.3)
		var center := Vector2(lanes_x + lane * lane_w + lane_w * 0.5, y)
		draw_circle(center, 22, c)
		draw_circle(center, 12, c.lightened(0.5))
	if _feedback_t > 0.0:
		var a := clampf(_feedback_t / 0.3, 0.0, 1.0)
		draw_string(font, Vector2(origin.x, origin.y + size.y * 0.45), _feedback, HORIZONTAL_ALIGNMENT_CENTER,
			size.x, 24 if mode == "riff" else 40, Color(_feedback_color.r, _feedback_color.g, _feedback_color.b, a))



const BALLADE_CHART_PATH := "res://data/ballade_solo.json"
const EPREUVE_CHART_PATH := "res://data/epreuve_solo.json"
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
