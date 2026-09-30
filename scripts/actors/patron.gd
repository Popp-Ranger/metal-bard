class_name Patron
extends Npc
## Client de la taverne avec une petite « simulation de vie » :
## assis à sa table au moins 40 s, il recule sa chaise, se lève et va au comptoir parler
## avec la tavernière (20 s au plus), prend une chope, puis revient, s'assoit et rapproche sa chaise.
## La taverne n'autorise jamais plus de 2 clients debout en même temps (claim_standing).
## Les clients sont un peu grossiers : ils lâchent des jurons de temps en temps.

enum Mode { SEATED, STANDING_UP, TO_BAR, AT_BAR, TO_SEAT, SITTING_DOWN }

const SEATED_MIN := 40.0
const SEATED_MAX := 110.0
const BAR_MIN := 6.0
const BAR_MAX := 20.0
const CHAIR_PULL := 0.5 # recul de la chaise (m) pour se lever
const BAR_LINES := ["Une bière, Brunhilde !", "La même chose, et plus vite que ça !", "Tu as entendu pour les squelettes ?",
	"Mets ça sur mon ardoise.", "Encore une tournée, bordel !", "Il paraît que la Liche revient... enfer et damnation.",
	"Ta soupe est... surprenante.", "Hydromel, et vite !", "Le barde joue ce soir ? Ça, c'est Metal !"]
## Jurons lancés au hasard depuis la table.
const BARKS := ["Yeah !", "Enfer !", "Damnation !", "Enfer et damnation !", "Bordel !", "Ça, c'est Metal !",
	"Bordel de cordes !", "Par les enfers, cette bière !", "YEAAAH !", "Nom d'un ampli !", "Que le diable m'emporte !"]

var seat_pos := Vector3.ZERO
var seat_yaw := 0.0
var seat_height := 0.49
## Chaise du client (déplacée quand il se lève et remise en place quand il se rassoit).
var chair: Node3D
## Taverne : places au comptoir (claim_bar_spot...) et nombre de clients debout (claim_standing...).
var tavern: Node
var wheelchair := false
var mode := Mode.SEATED

var _timer := 0.0
var _bark_timer := randf_range(8.0, 40.0)
var _bar_index := -1
var _wheels: Array[Node3D] = []
var _chair_home := Vector3.ZERO
## Chope servie au comptoir, rapportée à table (vidée et reposée au prochain lever).
var _mug: Node3D


func _ready() -> void:
	seated = true
	super._ready()
	if wheelchair:
		_build_wheelchair()
		walk_speed = 1.1
		seat_height = 0.55
	if chair != null:
		_chair_home = chair.position
	arrived.connect(_on_arrived)
	_sit_down()
	# Départ désynchronisé : certains iront au comptoir assez vite.
	_timer = randf_range(4.0, SEATED_MAX)


func _physics_process(delta: float) -> void:
	match mode:
		Mode.SEATED:
			_timer -= delta
			_bark_timer -= delta
			if _bark_timer <= 0.0:
				_bark_timer = randf_range(20.0, 60.0)
				if randf() < 0.6:
					say(str(BARKS.pick_random()), 2.5)
			if _timer <= 0.0:
				_try_stand_up()
		Mode.AT_BAR:
			_timer -= delta
			rotation.y = lerp_angle(rotation.y, PI, delta * 4.0) # face au comptoir (vers -Z)
			if _timer <= 0.0:
				_leave_bar()
	if wheelchair and walker.walking:
		for w in _wheels:
			w.rotation.x += delta * walk_speed / 0.3


## Se lever : il faut une place au comptoir ET qu'il y ait moins de 2 clients debout.
func _try_stand_up() -> void:
	if not bool(tavern.call("claim_standing")):
		_timer = randf_range(5.0, 12.0) # trop de monde debout : on patiente
		return
	_bar_index = int(tavern.call("claim_bar_spot"))
	if _bar_index < 0:
		tavern.call("release_standing")
		_timer = randf_range(8.0, 15.0) # comptoir plein : on réessaiera
		return
	_drop_mug()
	mode = Mode.STANDING_UP
	var back := _pull_dir() * CHAIR_PULL
	var tw := create_tween()
	# La chaise recule (avec le client dessus), puis il se lève.
	if chair != null:
		tw.tween_property(chair, "position", _chair_home + back, 0.5).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(self, "global_position", seat_pos + back, 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(_go_to_bar)


func _go_to_bar() -> void:
	mode = Mode.TO_BAR
	if wheelchair:
		walker.walk_to(tavern.call("bar_spot", _bar_index), walk_speed)
	else:
		walk_to(tavern.call("bar_spot", _bar_index))


func _leave_bar() -> void:
	_take_mug()
	tavern.call("release_bar_spot", _bar_index)
	_bar_index = -1
	mode = Mode.TO_SEAT
	var target := seat_pos + _pull_dir() * CHAIR_PULL # devant la chaise reculée
	if wheelchair:
		walker.walk_to(target, walk_speed)
	else:
		walk_to(target)


func _on_arrived() -> void:
	match mode:
		Mode.TO_BAR:
			mode = Mode.AT_BAR
			_timer = randf_range(BAR_MIN, BAR_MAX)
			if randf() < 0.8:
				say(str(BAR_LINES.pick_random()))
		Mode.TO_SEAT:
			# Il s'assoit sur la chaise reculée, puis la rapproche de la table.
			mode = Mode.SITTING_DOWN
			global_position = seat_pos + _pull_dir() * CHAIR_PULL
			rotation.y = seat_yaw
			sit(true, seat_height)
			var tw := create_tween()
			tw.tween_interval(0.3)
			if chair != null:
				tw.tween_property(chair, "position", _chair_home, 0.5).set_trans(Tween.TRANS_SINE)
			tw.parallel().tween_property(self, "global_position", seat_pos, 0.5).set_trans(Tween.TRANS_SINE)
			tw.tween_callback(_on_seated_again)


func _on_seated_again() -> void:
	tavern.call("release_standing")
	_sit_down()
	_timer = randf_range(SEATED_MIN, SEATED_MAX)


func _sit_down() -> void:
	mode = Mode.SEATED
	global_position = seat_pos
	rotation.y = seat_yaw
	sit(true, seat_height)


## La tavernière sert une chope : le client la tient dans la main droite.
func _take_mug() -> void:
	_drop_mug()
	if model == null or model._hand_r == null:
		return
	_mug = Node3D.new()
	model._hand_r.add_child(_mug)
	_mug.position = Vector3(0.0, -0.08, 0.06)
	var wood := Visuals.mat(Color(0.5, 0.33, 0.16), 0.7)
	Visuals.cylinder(_mug, 0.05, 0.045, 0.13, Vector3.ZERO, wood, Vector3.ZERO, 10)
	Visuals.cylinder(_mug, 0.047, 0.047, 0.012, Vector3(0, 0.06, 0), Visuals.mat(Color(0.95, 0.9, 0.75), 0.9), Vector3.ZERO, 10) # mousse
	Visuals.torus(_mug, 0.03, 0.045, Vector3(0.06, 0.0, 0), wood, Vector3(90, 0, 0))


func _drop_mug() -> void:
	if _mug != null and is_instance_valid(_mug):
		_mug.queue_free()
	_mug = null


func has_mug() -> bool:
	return _mug != null and is_instance_valid(_mug)


## Direction dans laquelle la chaise recule (à l'opposé de la table).
func _pull_dir() -> Vector3:
	return -Vector3(sin(seat_yaw), 0, cos(seat_yaw))


## Fauteuil roulant (Katrkar) : assise, dossier, deux grandes roues, deux roulettes.
func _build_wheelchair() -> void:
	var frame := Visuals.mat(Color(0.2, 0.2, 0.22), 0.4, 0.8)
	var wood := Visuals.mat(Color(0.35, 0.2, 0.1), 0.7)
	var wc := Node3D.new()
	add_child(wc)
	Visuals.box(wc, Vector3(0.6, 0.06, 0.55), Vector3(0, 0.52, 0), wood)
	Visuals.box(wc, Vector3(0.6, 0.6, 0.05), Vector3(0, 0.85, -0.27), wood)
	for side: float in [-1.0, 1.0]:
		var wheel := Node3D.new()
		wheel.position = Vector3(0.36 * side, 0.32, -0.05)
		wc.add_child(wheel)
		Visuals.torus(wheel, 0.28, 0.32, Vector3.ZERO, frame, Vector3(0, 0, 90))
		Visuals.box(wheel, Vector3(0.02, 0.56, 0.03), Vector3.ZERO, frame)
		Visuals.box(wheel, Vector3(0.02, 0.03, 0.56), Vector3.ZERO, frame)
		_wheels.append(wheel)
		Visuals.cylinder(wc, 0.07, 0.07, 0.04, Vector3(0.22 * side, 0.07, 0.28), frame, Vector3(0, 0, 90), 10)
		Visuals.box(wc, Vector3(0.03, 0.5, 0.03), Vector3(0.28 * side, 0.3, 0.25), frame) # repose-pieds
		Visuals.cylinder(wc, 0.02, 0.02, 0.25, Vector3(0.28 * side, 1.12, -0.35), frame, Vector3(90, 0, 0), 6) # poignées
	# Jambes brisées bandées, posées sur le repose-pieds.
	var bandage := Visuals.mat(Color(0.9, 0.87, 0.8), 0.9)
	for side: float in [-1.0, 1.0]:
		Visuals.capsule(wc, 0.1, 0.45, Vector3(0.12 * side, 0.58, 0.25), bandage, Vector3(90, 0, 0))
