class_name Npc
extends Node3D
## Personnage non joueur de la taverne. [E] pour lui parler (voir DialogueDB).

var npc_id := ""
var interact_radius := 2.3
var seated := false

var _body: Node3D
var _head: Node3D
var _t := randf() * 10.0
var _hero: Node3D


static func create(id: String, pos: Vector3, facing_deg: float = 0.0, is_seated: bool = false) -> Npc:
	var n := Npc.new()
	n.npc_id = id
	n.position = pos
	n.rotation_degrees.y = facing_deg
	n.seated = is_seated
	return n


func _ready() -> void:
	add_to_group("interactable")
	_body = Node3D.new()
	add_child(_body)
	_build()
	var name_label := Visuals.label(self, DialogueDB.npc_name(npc_id), Vector3(0, 2.45 if not seated else 2.0, 0),
		DialogueDB.npc_color(npc_id), 34)
	name_label.modulate.a = 0.85
	var title: String = DialogueDB.NPCS.get(npc_id, {}).get("title", "")
	if not title.is_empty():
		Visuals.label(self, title, Vector3(0, 2.25 if not seated else 1.8, 0), Color(0.7, 0.65, 0.6), 24)


func get_prompt() -> String:
	return "Parler à %s" % DialogueDB.npc_name(npc_id)


func interact(_by: Node3D) -> void:
	Events.dialogue_requested.emit(npc_id)


func _process(delta: float) -> void:
	_t += delta
	_body.position.y = sin(_t * 1.8) * 0.015
	if _hero == null or not is_instance_valid(_hero):
		_hero = get_tree().get_first_node_in_group("hero") as Node3D
		return
	# Tourne la tête vers le héros quand il est proche.
	var to := _hero.global_position - global_position
	to.y = 0.0
	if to.length() < 5.0 and _head != null:
		var local := global_transform.basis.inverse() * to
		var yaw := clampf(atan2(local.x, local.z), -1.1, 1.1)
		_head.rotation.y = lerp_angle(_head.rotation.y, yaw, delta * 5.0)
	elif _head != null:
		_head.rotation.y = lerp_angle(_head.rotation.y, 0.0, delta * 3.0)


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
