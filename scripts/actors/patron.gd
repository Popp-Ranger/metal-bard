class_name Patron
extends Npc
## Client de la taverne avec une petite « simulation de vie » :
## assis à sa table au moins 40 s, puis il va au comptoir parler avec la tavernière
## (20 s au plus) avant de retourner s'asseoir. Les durées sont tirées au hasard pour
## que les clients ne bougent jamais tous en même temps.

enum Mode { SEATED, TO_BAR, AT_BAR, TO_SEAT }

const SEATED_MIN := 40.0
const SEATED_MAX := 110.0
const BAR_MIN := 6.0
const BAR_MAX := 20.0
const BAR_LINES := ["Une bière, Brunhilde !", "La même chose.", "Tu as entendu pour les squelettes ?",
	"Mets ça sur mon ardoise.", "Encore une tournée !", "Il paraît que la Liche revient...",
	"Ta soupe est... surprenante.", "Hydromel, et vite !", "Le barde joue ce soir ?"]

var seat_pos := Vector3.ZERO
var seat_yaw := 0.0
var seat_height := 0.49
## Taverne qui gère les places au comptoir (méthodes claim_bar_spot / release_bar_spot).
var tavern: Node
var wheelchair := false
var mode := Mode.SEATED

var _timer := 0.0
var _bar_index := -1
var _wheels: Array[Node3D] = []


func _ready() -> void:
	seated = true
	super._ready()
	if wheelchair:
		_build_wheelchair()
		walk_speed = 1.1
		seat_height = 0.55
	arrived.connect(_on_arrived)
	_sit_down()
	# Départ désynchronisé : certains iront au comptoir assez vite.
	_timer = randf_range(4.0, SEATED_MAX)


func _physics_process(delta: float) -> void:
	match mode:
		Mode.SEATED:
			_timer -= delta
			if _timer <= 0.0:
				_go_to_bar()
		Mode.AT_BAR:
			_timer -= delta
			rotation.y = lerp_angle(rotation.y, PI, delta * 4.0) # face au comptoir (vers -Z)
			if _timer <= 0.0:
				_leave_bar()
	if wheelchair and walker.walking:
		for w in _wheels:
			w.rotation.x += delta * walk_speed / 0.3


func _go_to_bar() -> void:
	_bar_index = int(tavern.call("claim_bar_spot"))
	if _bar_index < 0:
		_timer = randf_range(8.0, 15.0) # comptoir plein : on réessaiera
		return
	mode = Mode.TO_BAR
	if wheelchair:
		walker.walk_to(tavern.call("bar_spot", _bar_index), walk_speed)
	else:
		walk_to(tavern.call("bar_spot", _bar_index))


func _leave_bar() -> void:
	tavern.call("release_bar_spot", _bar_index)
	_bar_index = -1
	mode = Mode.TO_SEAT
	if wheelchair:
		walker.walk_to(seat_pos, walk_speed)
	else:
		walk_to(seat_pos)


func _on_arrived() -> void:
	match mode:
		Mode.TO_BAR:
			mode = Mode.AT_BAR
			_timer = randf_range(BAR_MIN, BAR_MAX)
			if randf() < 0.8:
				say(str(BAR_LINES.pick_random()))
		Mode.TO_SEAT:
			_sit_down()
			_timer = randf_range(SEATED_MIN, SEATED_MAX)


func _sit_down() -> void:
	mode = Mode.SEATED
	global_position = seat_pos
	rotation.y = seat_yaw
	sit(true, seat_height)


## Fauteuil roulant (Katrkar) : assise, dossier, deux grandes roues, deux roulettes.
func _build_wheelchair() -> void:
	var frame := Visuals.mat(Color(0.2, 0.2, 0.22), 0.4, 0.8)
	var wood := Visuals.mat(Color(0.35, 0.2, 0.1), 0.7)
	var chair := Node3D.new()
	add_child(chair)
	Visuals.box(chair, Vector3(0.6, 0.06, 0.55), Vector3(0, 0.52, 0), wood)
	Visuals.box(chair, Vector3(0.6, 0.6, 0.05), Vector3(0, 0.85, -0.27), wood)
	for side: float in [-1.0, 1.0]:
		var wheel := Node3D.new()
		wheel.position = Vector3(0.36 * side, 0.32, -0.05)
		chair.add_child(wheel)
		Visuals.torus(wheel, 0.28, 0.32, Vector3.ZERO, frame, Vector3(0, 0, 90))
		Visuals.box(wheel, Vector3(0.02, 0.56, 0.03), Vector3.ZERO, frame)
		Visuals.box(wheel, Vector3(0.02, 0.03, 0.56), Vector3.ZERO, frame)
		_wheels.append(wheel)
		Visuals.cylinder(chair, 0.07, 0.07, 0.04, Vector3(0.22 * side, 0.07, 0.28), frame, Vector3(0, 0, 90), 10)
		Visuals.box(chair, Vector3(0.03, 0.5, 0.03), Vector3(0.28 * side, 0.3, 0.25), frame) # repose-pieds
		Visuals.cylinder(chair, 0.02, 0.02, 0.25, Vector3(0.28 * side, 1.12, -0.35), frame, Vector3(90, 0, 0), 6) # poignées
	# Jambes brisées bandées, posées sur le repose-pieds.
	var bandage := Visuals.mat(Color(0.9, 0.87, 0.8), 0.9)
	for side: float in [-1.0, 1.0]:
		Visuals.capsule(chair, 0.1, 0.45, Vector3(0.12 * side, 0.58, 0.25), bandage, Vector3(90, 0, 0))
