class_name Npc
extends Node3D
## Personnage non joueur. [E] (ou clic) pour lui parler (voir DialogueDB).
## Apparence : un modèle généré avec l'outil de création de personnage (HeroModel, `look`) ; les PNJ
## à costume (Gérald, Zarathos, l'Inconnue) y ajoutent leurs accessoires (voir COSTUMES et _dress).
## Tous ont la posture et la démarche de Riffald (voir LocoAnimator).
## Peut marcher sur le maillage de navigation, s'asseoir, et afficher un point
## d'exclamation / d'interrogation vert s'il donne une quête.

signal arrived

## Apparence des PNJ sans `look` (même format que RaceDB.DEFAULT_APPEARANCE, plus "outfit" : voir
## HeroModel) ; "hat" = hauteur du chapeau au-dessus de la tête (étiquettes).
const COSTUMES := {
	"gerald": {"sex": "m", "race": "humain", "beard": 0, "hair": 2, "hair_color": 2,
		"outfit": {"plain": true, "top": Color(0.45, 0.35, 0.2), "legs": Color(0.3, 0.35, 0.55), "coat": Color(0.3, 0.25, 0.18)}},
	"zarathos": {"sex": "m", "race": "humain", "beard": 1, "hair": 2, "hair_color": 3, "hat": 0.45,
		"outfit": {"plain": true, "top": Color(0.2, 0.15, 0.4), "legs": Color(0.2, 0.15, 0.4), "coat": Color(0.2, 0.15, 0.4)}},
	"inconnue": {"sex": "f", "race": "humain", "hair": -1,
		"outfit": {"plain": true, "top": Color(0.08, 0.06, 0.08), "legs": Color(0.08, 0.06, 0.08), "coat": Color(0.08, 0.06, 0.08)}},
}
const DEFAULT_COSTUME := {"sex": "m", "race": "humain", "beard": 0, "hair": 1, "hair_color": 1,
	"outfit": {"plain": true, "top": Color(0.4, 0.4, 0.4), "legs": Color(0.2, 0.2, 0.2)}}
## PNJ au modèle 3D importé (art/pnj, CharacterSkin) : Zarathos (mage) et le tavernier orc ; les autres
## sont générés (HeroModel). Sans le modèle, on revient au costume.
const SKINS := {"zarathos": "mage", "brunhilde": "tavernier"}
## Bâton de Zarathos : point empoigné (repère du torse), le bâton passe dans le poing.
const STAFF_GRIP := Vector3(0.27, 0.18, 0.25)

var npc_id := ""
## Nom affiché (sinon celui de DialogueDB) et identifiant du dialogue (sinon npc_id).
var display_name := ""
var title_override := ""
var dialogue_id := ""
## Échelle du personnage par rapport à sa race (Gérald, petit homme : 0,8), pour placer les étiquettes.
var size_k := 1.0
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
var skin: CharacterSkin
var walker: NavWalker
var _body: Node3D
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
	if SKINS.has(npc_id):
		skin = CharacterSkin.create(str(SKINS[npc_id]))
	if skin != null:
		_body.add_child(skin)
	else:
		if look.is_empty():
			look = COSTUMES.get(npc_id, DEFAULT_COSTUME)
		var full_look := RaceDB.DEFAULT_APPEARANCE.duplicate()
		full_look.merge(look, true)
		full_look["guitar"] = false
		full_look["hunched"] = false
		model = HeroModel.new()
		model.anim_style = "pnj_corps" # repos « pnjPose »
		model.appearance = full_look
		_body.add_child(model)
		_dress()
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


## Hauteur du sommet de la tête, chapeau compris (pour placer les étiquettes).
func _top_height() -> float:
	if skin != null:
		return skin.height + 0.15
	return model.height() * size_k * (0.72 if seated else 1.0) + 0.15 + float(look.get("hat", 0.0))


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
	if skin != null:
		skin.step(delta, moving, walker.speed if walker != null else 0.0)
	else:
		if walker != null:
			model.move_speed = walker.speed
		model.set_moving(moving)
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


# --- Costumes ----------------------------------------------------------------

## Accessoires des PNJ costumés, posés sur les pivots du modèle : ils suivent ses mouvements.
func _dress() -> void:
	var m := model
	match npc_id:
		"gerald":
			# Fermier : chapeau de paille, salopette en toile bleue.
			var straw := Visuals.mat(Color(0.8, 0.7, 0.35))
			Visuals.cylinder(m._head, 0.4, 0.4, 0.035, Vector3(0, 0.34, 0.02), straw, Vector3.ZERO, 18)
			Visuals.cylinder(m._head, 0.14, 0.21, 0.2, Vector3(0, 0.44, 0.0), straw, Vector3.ZERO, 14)
			var denim := Visuals.mat(Color(0.3, 0.35, 0.55))
			Visuals.box(m._torso, Vector3(0.24, 0.28, 0.03), Vector3(0, 0.3, 0.12), denim, Vector3(5, 0, 0)) # bavette
			for s: float in [-1.0, 1.0]:
				Visuals.box(m._torso, Vector3(0.035, 0.32, 0.03), Vector3(0.085 * s, 0.42, 0.04), denim, Vector3(-30, 0, 0)) # bretelles
			# Petit homme aux pieds nus (fort bien épilés) : plus de bottes, des orteils.
			size_k = 0.8
			m.scale *= size_k
			var skin := Visuals.mat(Color(0.93, 0.74, 0.6), 0.7)
			for ankle: Node3D in [m._ankle_l, m._ankle_r]:
				var parts := ankle.get_children()
				(parts[0] as MeshInstance3D).material_override = skin # pied
				(parts[1] as Node3D).visible = false # semelle
				var shaft := ankle.get_parent().get_child(2) as MeshInstance3D # tige de botte → bas du pantalon
				shaft.material_override = denim
				for k in 5:
					Visuals.sphere(ankle, 0.017 - k * 0.0015, Vector3(-0.036 + k * 0.018, -0.04, 0.19), skin)
		"zarathos":
			# Mage : robe jusqu'aux pieds, chapeau pointu à large bord, bâton surmonté d'un orbe.
			var robe := Visuals.mat(Color(0.2, 0.15, 0.4), 0.9)
			Visuals.cylinder(m._torso, 0.19, 0.45, 1.03, Vector3(0, -0.415, 0), robe, Vector3.ZERO, 16)
			Visuals.cylinder(m._head, 0.42, 0.42, 0.035, Vector3(0, 0.36, 0.02), robe, Vector3.ZERO, 18)
			Visuals.cylinder(m._head, 0.0, 0.24, 0.75, Vector3(0, 0.72, -0.05), robe, Vector3(-10, 0, 0), 14)
			var staff := Node3D.new()
			staff.position = STAFF_GRIP + Vector3(0.0, 0.0, 0.05)
			m._torso.add_child(staff)
			Visuals.cylinder(staff, 0.03, 0.03, 1.9, Vector3(0, -0.15, 0), Visuals.mat(Color(0.3, 0.2, 0.1)))
			Visuals.sphere(staff, 0.1, Vector3(0, 0.82, 0), Visuals.glow_mat(Color(0.6, 0.4, 1.0), 4.0))
			var l := Visuals.flicker_light(staff, Vector3(0, 0.88, 0), Color(0.6, 0.4, 1.0), 0.8, 3.5)
			l.flicker_amount = 0.4
			m.prop_grip = STAFF_GRIP
		"inconnue":
			# Long manteau noir, capuche d'où ne luisent que deux yeux rouges.
			var cloak := Visuals.mat(Color(0.08, 0.06, 0.08), 0.9)
			Visuals.cylinder(m._torso, 0.19, 0.42, 1.03, Vector3(0, -0.415, 0), cloak, Vector3.ZERO, 16)
			Visuals.sphere(m._head, 0.21, Vector3(0, 0.22, -0.01), cloak, Vector3(1.0, 1.15, 1.1))
			var eyes := Visuals.glow_mat(Color(1.0, 0.2, 0.2), 4.0)
			for s: float in [-1.0, 1.0]:
				Visuals.sphere(m._head, 0.022, Vector3(0.05 * s, 0.22, 0.225), eyes)


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
