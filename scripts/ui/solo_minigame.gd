class_name SoloMinigame
extends Control
## Mini-jeu du « Solo de la Foudre », façon Guitar Hero.
## 5 notes descendent sur 4 cordes ; il faut appuyer au bon moment
## (touches 1 2 3 4). Le jeu continue pendant le solo : le héros reste sur place,
## invincible, et les ennemis continuent d'avancer.
## Résultat : 5/5 = pluie d'éclairs à 100 %, 4/5 = 70 %, 3/5 = 45 %, moins = fausse note.

const LANES := 4
const NOTE_SPEED := 330.0 # pixels par seconde
const LEAD_TIME := 1.5 # temps de chute de la première note
const WINDOW_PERFECT := 0.08
const WINDOW_GOOD := 0.17
const LANE_COLORS := [Color(0.3, 0.9, 0.35), Color(0.95, 0.25, 0.2), Color(1.0, 0.85, 0.2), Color(0.3, 0.55, 1.0)]
const PANEL_SIZE := Vector2(400, 520)

var _notes: Array[Dictionary] = []
var _t := 0.0
var _active := false
var _hits := 0
var _feedback := ""
var _feedback_color := Color.WHITE
var _feedback_t := 0.0
var _lane_flash := [0.0, 0.0, 0.0, 0.0]
var _end_t := 0.0
## "foudre" (Solo de la Foudre, 5 notes) ou "endiable" (Solo endiablé : s'arrête à la 1re fausse note).
var mode := "foudre"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	Events.solo_requested.connect(start)


func start(solo_mode: String = "foudre", note_count: int = Balance.SOLO_NOTES) -> void:
	mode = solo_mode
	_notes.clear()
	var t := LEAD_TIME
	var last_lane := -1
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
	Sfx.play("solo_start", -4.0, 0.0)


func _process(delta: float) -> void:
	if not _active:
		return
	_t += delta
	_feedback_t -= delta
	for i in LANES:
		_lane_flash[i] = maxf(0.0, float(_lane_flash[i]) - delta * 4.0)
	for n in _notes:
		if not n["judged"] and _t > float(n["time"]) + WINDOW_GOOD:
			n["judged"] = true
			_set_feedback("RATÉ", Color(1.0, 0.35, 0.3))
			Sfx.play("dud", -10.0)
			if mode == "endiable":
				_finish() # fausse note : la transe se brise
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
	for lane in LANES:
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
		if err <= WINDOW_GOOD and err < best_err:
			best_err = err
			best = n
	if best.is_empty():
		Sfx.play("dud", -14.0)
		return
	best["judged"] = true
	best["hit"] = true
	_hits += 1
	Events.solo_note_hit.emit(mode, _hits)
	Sfx.play("note_%d" % lane, -3.0, 0.0)
	if best_err <= WINDOW_PERFECT:
		_set_feedback("PARFAIT !", Color(1.0, 0.9, 0.3))
	else:
		_set_feedback("BIEN", Color(0.6, 0.95, 0.6))


func _set_feedback(text: String, color: Color) -> void:
	_feedback = text
	_feedback_color = color
	_feedback_t = 0.6


func _finish() -> void:
	_active = false
	visible = false
	Events.solo_finished.emit(mode, _hits, _notes.size())


func _draw() -> void:
	if not _active:
		return
	var font := UiStyle.serif()
	var vp := get_viewport_rect().size
	# Panneau sur la droite de l'écran : l'action reste visible (le jeu n'est pas en pause).
	var origin := Vector2(vp.x - PANEL_SIZE.x - 40.0, (vp.y - PANEL_SIZE.y) * 0.5)
	var panel := Rect2(origin, PANEL_SIZE)
	draw_rect(panel, Color(0.05, 0.03, 0.04, 0.88))
	draw_rect(panel, UiStyle.BORDER, false, 3.0)
	draw_string(font, origin + Vector2(0, 42), "SOLO ENDIABLÉ" if mode == "endiable" else "SOLO DE LA FOUDRE", HORIZONTAL_ALIGNMENT_CENTER, PANEL_SIZE.x, 30, Color(1.0, 0.8, 0.4))
	draw_string(font, origin + Vector2(0, 70), ("%d / %d notes  •  TRANSE" if mode == "endiable" else "%d / %d notes  •  INVINCIBLE") % [_hits, _notes.size()], HORIZONTAL_ALIGNMENT_CENTER, PANEL_SIZE.x, 18, Color(1.0, 0.85, 0.45))

	var lane_w := 76.0
	var lanes_x := origin.x + (PANEL_SIZE.x - lane_w * LANES) * 0.5
	var top := origin.y + 90.0
	var hit_y := origin.y + PANEL_SIZE.y - 90.0
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
		var y := hit_y - (float(n["time"]) - _t) * NOTE_SPEED
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
		draw_string(font, Vector2(origin.x, origin.y + PANEL_SIZE.y * 0.45), _feedback, HORIZONTAL_ALIGNMENT_CENTER,
			PANEL_SIZE.x, 40, Color(_feedback_color.r, _feedback_color.g, _feedback_color.b, a))

