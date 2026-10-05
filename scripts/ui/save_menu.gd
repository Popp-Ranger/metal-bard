class_name SaveMenu
extends PanelContainer
## Fenêtre Sauvegarder / Charger : 5 emplacements manuels + la sauvegarde automatique
## (chargement seulement). Utilisée par le menu pause et par l'écran titre.
## On ne peut pas sauvegarder en plein combat (voir Level.in_combat).

signal closed

var mode := "load" # "save" ou "load"
## Niveau en cours (pour le lieu de la sauvegarde) ; null depuis l'écran titre.
var level: Level

var _title: Label
var _list: VBoxContainer
var _info: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.5
	anchor_bottom = 0.5
	offset_left = -380
	offset_right = 380
	offset_top = -250
	offset_bottom = 250
	var style := UiStyle.frame(true, 30) # cadre de fer, voile sombre derrière
	add_theme_stylebox_override("panel", style)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	add_child(vb)
	_title = UiStyle.label("", 30, Color(1.0, 0.8, 0.45))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_title)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	vb.add_child(_list)
	_info = UiStyle.label("", 16, UiStyle.DIM)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_info)
	var back := Button.new()
	back.text = "Retour"
	back.custom_minimum_size = Vector2(0, 40)
	back.pressed.connect(close)
	vb.add_child(back)
	visible = false


func open(open_mode: String) -> void:
	mode = open_mode
	_title.text = "SAUVEGARDER" if mode == "save" else "CHARGER UNE PARTIE"
	_info.text = ""
	_refresh()
	visible = true
	if mode == "save" and level != null and level.in_combat():
		_info.text = "Impossible de sauvegarder en plein combat !"
		_info.add_theme_color_override("font_color", Events.COLOR_BAD)
	else:
		_info.remove_theme_color_override("font_color")


func close() -> void:
	visible = false
	closed.emit()


func _refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	var first_slot := 0 if mode == "load" else 1
	for slot in range(first_slot, GameState.SAVE_SLOTS + 1):
		var summary := GameState.slot_summary(slot)
		var label := "Sauvegarde automatique" if slot == 0 else "Emplacement %d" % slot
		var b := Button.new()
		b.text = "%s  —  %s" % [label, summary if not summary.is_empty() else "vide"]
		b.custom_minimum_size = Vector2(0, 46)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.disabled = mode == "load" and summary.is_empty()
		if mode == "save" and level != null and level.in_combat():
			b.disabled = true
		b.pressed.connect(_on_slot.bind(slot))
		_list.add_child(b)


func _on_slot(slot: int) -> void:
	if mode == "save":
		if level != null and level.in_combat():
			_info.text = "Impossible de sauvegarder en plein combat !"
			return
		if level != null:
			GameState.location = level.save_location()
		if GameState.save_to_slot(slot):
			Sfx.play("coin", -6.0)
			_info.text = "Partie sauvegardée dans l'emplacement %d." % slot
			Events.notify("Partie sauvegardée (emplacement %d)" % slot, Events.COLOR_GOOD)
		_refresh()
		return
	if GameState.load_slot(slot):
		Sfx.play("levelup", -8.0, 0.0)
		visible = false
		get_tree().paused = false
		Router.go_to(GameState.resume_scene())


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()
