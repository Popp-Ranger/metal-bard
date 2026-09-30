class_name Npc
extends Node3D
## Personnage non joueur. [E] (ou clic) pour lui parler (voir DialogueDB).
## Apparence : modèle dédié (Gérald, Zarathos, l'Inconnue) ou, si `look` est rempli,
## un modèle généré avec l'outil de création de personnage (clients, tavernière...).
## Peut marcher sur le maillage de navigation, s'asseoir, et afficher un point
## d'exclamation / d'interrogation vert s'il donne une quête.

signal arrived

var npc_id := ""
## Nom affiché (sinon celui de DialogueDB) et identifiant du dialogue (sinon npc_id).
var display_name := ""
var title_override := ""
var dialogue_id := ""
var interact_radius := 2.3
var seated := false
## Apparence façon création de personnage (RaceDB) ; vide = modèle dédié.
var look := {}
var walk_speed := 1.4
## Errance autour du point de départ (Zarathos fait les cent pas près de son portail).
var wander_radius := 0.0
var _home := Vector3.ZERO
var _home_yaw := 0.0
var _wander_timer := randf_range(4.0, 9.0)
var _going_home := false

var model: HeroModel
var walker: NavWalker
var _body: Node3D
var _head: Node3D
var _t := randf() * 10.0
var _hero: Node3D
var _labels: Node3D
var _marker: Label3D
var _quest_ids: Array[String] = []
var _bubble: Label3D
var _bubble_time := 0.0


static func create(id: String, pos: Vector3, facing_deg: float = 0.0, is_seated: bool = false) -> Npc:
	var n := Npc.new()
	n.npc_id = id
	n.position = pos
	n.rotation_degrees.y = facing_deg
	n.seated = is_seated
	return n


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("npcs")
	_body = Node3D.new()
	add_child(_body)
	if look.is_empty():
		_build()
	else:
		var full_look := look.duplicate()
		full_look["guitar"] = false
		full_look["hunched"] = false
		model = HeroModel.new()
		model.appearance = full_look
		_body.add_child(model)
	walker = NavWalker.new()
	add_child(walker)
	walker.arrived.connect(func() -> void: arrived.emit())
	_home = position
	_home_yaw = rotation.y
	arrived.connect(_on_walk_arrived)
	_labels = Node3D.new()
	add_child(_labels)
	var top := _top_height()
	var name_label := Visuals.label(_labels, get_display_name(), Vector3(0, top + 0.25, 0), DialogueDB.npc_color(npc_id), 34)
	name_label.modulate.a = 0.85
	var title := title_override
	if title.is_empty():
		title = str(DialogueDB.NPCS.get(npc_id, {}).get("title", ""))
	if not title.is_empty():
		Visuals.label(_labels, title, Vector3(0, top + 0.05, 0), Color(0.7, 0.65, 0.6), 24)
	# Donneur de quête : « ! » vert (quête disponible), « ? » vert (quête à rendre).
	for qid: String in QuestDB.QUESTS:
		if str(QuestDB.get_quest(qid).get("giver", "")) == npc_id:
			_quest_ids.append(qid)
	if not _quest_ids.is_empty():
		_marker = Visuals.label(_labels, "!", Vector3(0, top + 0.75, 0), Color(0.3, 1.0, 0.35), 120)
		_marker.outline_size = 16
		Events.quest_updated.connect(func(_q: String) -> void: _refresh_marker())
		_refresh_marker()
	if seated and model != null:
		model.set_seated(true)


## Hauteur du sommet de la tête (pour placer les étiquettes).
func _top_height() -> float:
	if model != null:
		return model.height() * (0.72 if seated else 1.0) + 0.15
	return 2.0 if seated else 2.2


func get_display_name() -> String:
	return display_name if not display_name.is_empty() else DialogueDB.npc_name(npc_id)


func _refresh_marker() -> void:
	if _marker == null:
		return
	_marker.visible = false
	for qid in _quest_ids:
		match GameState.quest_state(qid):
			QuestDB.State.AVAILABLE:
				_marker.text = "!"
				_marker.visible = true
			QuestDB.State.OBJECTIVE_DONE:
				_marker.text = "?"
				_marker.visible = true


func get_prompt() -> String:
	return "Parler à %s" % get_display_name()


func interact(_by: Node3D) -> void:
	if wander_radius > 0.0 and global_position.distance_to(_home) > 0.3:
		# Il revient à sa place (près du cercle de runes) pour ouvrir le portail.
		_going_home = true
		walk_to(_home, walk_speed * 1.5)
	Events.dialogue_requested.emit(dialogue_id if not dialogue_id.is_empty() else npc_id)


# --- Déplacements -----------------------------------------------------------------

func walk_to(pos: Vector3, speed: float = -1.0) -> void:
	sit(false)
	walker.walk_to(pos, walk_speed if speed < 0.0 else speed)


func is_walking() -> bool:
	return walker.walking


## Assis (sur une chaise orientée selon `yaw`) ou debout.
func sit(value: bool, seat_height: float = 0.49) -> void:
	seated = value
	if model != null:
		model.set_seated(value, seat_height)
	if _labels != null:
		for i in _labels.get_child_count():
			var l := _labels.get_child(i) as Label3D
			if l != null:
				l.position.y = _top_height() + [0.25, 0.05, 0.75][mini(i, 2)]


## Petite bulle de texte au-dessus de la tête (vie de la taverne).
func say(text: String, duration: float = 3.5) -> void:
	if _bubble == null:
		_bubble = Visuals.label(self, "", Vector3(0, _top_height() + 1.1, 0), Color(1.0, 0.95, 0.8), 30)
	_bubble.text = "« %s »" % text
	_bubble.position.y = _top_height() + 1.1
	_bubble.visible = true
	_bubble_time = duration


func _process(delta: float) -> void:
	_t += delta
	_update_wander(delta)
	if _bubble != null and _bubble.visible:
		_bubble_time -= delta
		if _bubble_time <= 0.0:
			_bubble.visible = false
	if _marker != null:
		_marker.position.y = _top_height() + 0.75 + sin(_t * 2.5) * 0.08
	var moving := walker != null and walker.walking and walker.direction.length() > 0.1
	if moving:
		rotation.y = lerp_angle(rotation.y, atan2(walker.direction.x, walker.direction.z), 1.0 - exp(-10.0 * delta))
	if model != null:
		model.set_moving(moving)
	else:
		_body.position.y = absf(sin(_t * 8.0)) * 0.05 if moving else sin(_t * 1.8) * 0.015
	if _hero == null or not is_instance_valid(_hero):
		_hero = get_tree().get_first_node_in_group("hero") as Node3D
		return
	# Tourne la tête vers le héros quand il est proche.
	var to := _hero.global_position - global_position
	to.y = 0.0
	var yaw := 0.0
	if to.length() < 5.0 and not moving:
		var local := global_transform.basis.inverse() * to
		yaw = clampf(atan2(local.x, local.z), -1.1, 1.1)
	if model != null:
		model.head_turn = lerp_angle(model.head_turn, yaw, delta * 5.0)
	elif _head != null:
		_head.rotation.y = lerp_angle(_head.rotation.y, yaw, delta * 5.0)


# --- Apparences ------------------------------------------------------------

func _build() -> void:
	var skin := Visuals.mat(Color(0.85, 0.66, 0.54), 0.6)
	match npc_id:
		"gerald":
			_humanoid(Color(0.45, 0.35, 0.2), Color(0.3, 0.25, 0.18), skin, 1.0)
			Visuals.cylinder(_head, 0.32, 0.32, 0.03, Vector3(0, 0.2, 0), Visuals.mat(Color(0.8, 0.7, 0.35)))
			Visuals.cylinder(_head, 0.1, 0.17, 0.16, Vector3(0, 0.28, 0), Visuals.mat(Color(0.8, 0.7, 0.35)))
			Visuals.box(_body, Vector3(0.44, 0.5, 0.05), Vector3(0, 1.05, 0.16), Visuals.mat(Color(0.3, 0.35, 0.55))) # salopette
		"brunhilde":
			_humanoid(Color(0.5, 0.15, 0.12), Color(0.25, 0.18, 0.12), skin, 1.1)
			Visuals.box(_body, Vector3(0.5, 0.7, 0.05), Vector3(0, 0.9, 0.2), Visuals.mat(Color(0.85, 0.8, 0.7))) # tablier
			var hair := Visuals.mat(Color(0.85, 0.6, 0.25))
			Visuals.sphere(_head, 0.2, Vector3(0, 0.07, -0.02), hair, Vector3(1.0, 0.8, 1.0))
			for s: float in [-1.0, 1.0]: # tresses
				Visuals.capsule(_head, 0.05, 0.5, Vector3(0.18 * s, -0.25, 0.02), hair)
		"zarathos":
			var robe := Visuals.mat(Color(0.2, 0.15, 0.4), 0.9)
			Visuals.cylinder(_body, 0.18, 0.42, 1.5, Vector3(0, 0.75, 0), robe)
			_head = _pivot(_body, Vector3(0, 1.62, 0))
			Visuals.sphere(_head, 0.16, Vector3.ZERO, skin)
			Visuals.cylinder(_head, 0.0, 0.3, 0.6, Vector3(0, 0.35, -0.03), robe, Vector3(-10, 0, 0)) # chapeau pointu
			Visuals.cylinder(_head, 0.32, 0.32, 0.03, Vector3(0, 0.1, 0), robe)
			Visuals.cylinder(_head, 0.02, 0.14, 0.55, Vector3(0, -0.28, 0.12), Visuals.mat(Color(0.9, 0.9, 0.9)), Vector3(180, 0, 0)) # barbe
			Visuals.cylinder(_body, 0.03, 0.03, 1.9, Vector3(0.4, 0.95, 0.1), Visuals.mat(Color(0.3, 0.2, 0.1))) # bâton
			Visuals.sphere(_body, 0.1, Vector3(0.4, 1.95, 0.1), Visuals.glow_mat(Color(0.6, 0.4, 1.0), 4.0))
			var l := Visuals.flicker_light(_body, Vector3(0.4, 2.0, 0.1), Color(0.6, 0.4, 1.0), 0.8, 3.5)
			l.flicker_amount = 0.4
		"inconnue":
			var cloak := Visuals.mat(Color(0.08, 0.06, 0.08), 0.9)
			Visuals.cylinder(_body, 0.2, 0.4, 1.55, Vector3(0, 0.78, 0), cloak)
			_head = _pivot(_body, Vector3(0, 1.65, 0))
			Visuals.sphere(_head, 0.2, Vector3(0, 0.02, -0.02), cloak, Vector3(1.0, 1.15, 1.1))
			Visuals.sphere(_head, 0.02, Vector3(-0.05, 0.0, 0.17), Visuals.glow_mat(Color(1.0, 0.2, 0.2), 4.0))
			Visuals.sphere(_head, 0.02, Vector3(0.05, 0.0, 0.17), Visuals.glow_mat(Color(1.0, 0.2, 0.2), 4.0))
		"borin":
			_humanoid(Color(0.35, 0.2, 0.1), Color(0.2, 0.15, 0.1), skin, 0.75)
			Visuals.cylinder(_head, 0.05, 0.2, 0.45, Vector3(0, -0.25, 0.1), Visuals.mat(Color(0.75, 0.35, 0.1)), Vector3(180, 0, 0)) # barbe
			Visuals.cylinder(_body, 0.07, 0.07, 0.16, Vector3(0.28, 0.9, 0.2), Visuals.mat(Color(0.6, 0.45, 0.2))) # chope
		"sylvaine":
			_humanoid(Color(0.15, 0.35, 0.3), Color(0.1, 0.2, 0.18), skin, 1.05)
			var hair := Visuals.mat(Color(0.9, 0.9, 0.85))
			Visuals.box(_head, Vector3(0.36, 0.55, 0.12), Vector3(0, -0.15, -0.12), hair)
			for s: float in [-1.0, 1.0]: # oreilles pointues
				Visuals.cylinder(_head, 0.0, 0.04, 0.16, Vector3(0.17 * s, 0.03, 0), skin, Vector3(0, 0, -70 * s))
			Visuals.sphere(_body, 0.2, Vector3(0.3, 0.95, 0.15), Visuals.mat(Color(0.8, 0.8, 0.85), 0.3, 0.7), Vector3(0.8, 1.1, 0.3)) # luth d'argent
		_:
			_humanoid(Color(0.4, 0.4, 0.4), Color(0.2, 0.2, 0.2), skin, 1.0)


func _humanoid(top: Color, bottom: Color, skin: Material, s: float) -> void:
	_body.scale = Vector3.ONE * s
	var top_mat := Visuals.mat(top)
	var bottom_mat := Visuals.mat(bottom)
	if seated:
		Visuals.capsule(_body, 0.1, 0.45, Vector3(-0.12, 0.5, 0.2), bottom_mat, Vector3(90, 0, 0))
		Visuals.capsule(_body, 0.1, 0.45, Vector3(0.12, 0.5, 0.2), bottom_mat, Vector3(90, 0, 0))
		Visuals.capsule(_body, 0.09, 0.45, Vector3(-0.12, 0.25, 0.42), bottom_mat)
		Visuals.capsule(_body, 0.09, 0.45, Vector3(0.12, 0.25, 0.42), bottom_mat)
		_body.position.y = -0.0
	else:
		Visuals.capsule(_body, 0.1, 0.9, Vector3(-0.12, 0.45, 0), bottom_mat)
		Visuals.capsule(_body, 0.1, 0.9, Vector3(0.12, 0.45, 0), bottom_mat)
	var base_y := 0.55 if seated else 0.9
	Visuals.capsule(_body, 0.26, 0.75, Vector3(0, base_y + 0.35, 0), top_mat)
	Visuals.capsule(_body, 0.08, 0.6, Vector3(-0.3, base_y + 0.35, 0.05), top_mat, Vector3(-20, 0, 8))
	Visuals.capsule(_body, 0.08, 0.6, Vector3(0.3, base_y + 0.35, 0.05), top_mat, Vector3(-20, 0, -8))
	_head = _pivot(_body, Vector3(0, base_y + 0.9, 0))
	Visuals.sphere(_head, 0.17, Vector3.ZERO, skin)
	Visuals.sphere(_head, 0.025, Vector3(-0.06, 0.02, 0.15), Visuals.mat(Color(0.05, 0.05, 0.05)))
	Visuals.sphere(_head, 0.025, Vector3(0.06, 0.02, 0.15), Visuals.mat(Color(0.05, 0.05, 0.05)))


func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var p := Node3D.new()
	p.position = pos
	parent.add_child(p)
	return p


# --- Errance (Zarathos) ------------------------------------------------------------

func _update_wander(delta: float) -> void:
	if wander_radius <= 0.0 or walker == null or walker.walking:
		return
	_wander_timer -= delta
	if _wander_timer > 0.0:
		return
	_wander_timer = randf_range(6.0, 12.0)
	# Pas d'errance pendant une conversation ou quand le héros est tout près.
	if _hero != null and is_instance_valid(_hero) and _hero.global_position.distance_to(global_position) < 3.0:
		return
	if randf() < 0.4 and global_position.distance_to(_home) > 0.3:
		walk_to(_home)
		return
	var a := randf() * TAU
	walk_to(_home + Vector3(cos(a), 0, sin(a)) * randf_range(0.8, wander_radius))


func _on_walk_arrived() -> void:
	if wander_radius > 0.0 and global_position.distance_to(_home) < 0.5:
		_going_home = false
		create_tween().tween_property(self, "rotation:y", _home_yaw, 0.4)
