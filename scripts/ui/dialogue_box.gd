class_name DialogueBox
extends PanelContainer
## Boîte de dialogue en bas de l'écran : texte qui défile, puis choix de réponses.
## Le jeu est en pause pendant le dialogue.

var _speaker: Label
var _text: RichTextLabel
var _hint: Label
var _choices: VBoxContainer
var _lines: Array = []
var _choice_data: Array = []
var _index := 0
var _npc_id := ""
var _typing := false
var _open := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	custom_minimum_size = Vector2(860, 0)
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = -430
	offset_right = 430
	offset_top = -200
	offset_bottom = -30
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	add_child(vb)
	_speaker = UiStyle.label("", 22, Color(1.0, 0.8, 0.45))
	vb.add_child(_speaker)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.custom_minimum_size = Vector2(820, 70)
	_text.add_theme_font_size_override("normal_font_size", 19)
	vb.add_child(_text)
	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 4)
	vb.add_child(_choices)
	_hint = UiStyle.label("", 14, UiStyle.DIM)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vb.add_child(_hint)
	visible = false
	Events.dialogue_requested.connect(open)


func open(dialogue_id: String) -> void:
	var data := DialogueDB.get_dialogue(dialogue_id)
	if not _open:
		_npc_id = dialogue_id
	_lines = data.get("lines", [])
	_choice_data = data.get("choices", [])
	_index = 0
	_open = true
	visible = true
	get_tree().paused = true
	Events.interaction_prompt.emit("")
	_show_line()


func close() -> void:
	_open = false
	visible = false
	get_tree().paused = false
	Events.dialogue_closed.emit()


func _show_line() -> void:
	_clear_choices()
	if _lines.is_empty():
		_show_choices()
		return
	var line: Array = _lines[_index]
	var speaker := str(line[0])
	_speaker.text = speaker
	var color := Color(1.0, 0.8, 0.45)
	if speaker == DialogueDB.HERO:
		color = Color(0.55, 0.85, 1.0)
	_speaker.add_theme_color_override("font_color", color)
	_text.text = str(line[1])
	_text.visible_ratio = 0.0
	_typing = true
	var duration := clampf(_text.text.length() * 0.018, 0.2, 2.0)
	var tw := create_tween()
	tw.tween_property(_text, "visible_ratio", 1.0, duration)
	tw.tween_callback(_on_typed)
	_hint.text = ""


func _on_typed() -> void:
	_typing = false
	if _index >= _lines.size() - 1:
		_show_choices()
	else:
		_hint.text = "[%s / clic] Continuer" % Controls.key_label("interact")


func _show_choices() -> void:
	_clear_choices()
	if _choice_data.is_empty():
		_hint.text = "[%s / clic] Fermer" % Controls.key_label("interact")
		return
	_hint.text = ""
	var n := 1
	for c: Array in _choice_data:
		var b := Button.new()
		b.text = "%d. %s" % [n, str(c[0])]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_on_choice.bind(c))
		_choices.add_child(b)
		n += 1
	var first := _choices.get_child(0) as Button
	first.grab_focus()


func _clear_choices() -> void:
	for c in _choices.get_children():
		_choices.remove_child(c)
		c.queue_free()


func _on_choice(choice: Array) -> void:
	var action := str(choice[1])
	var keep_open := choice.size() > 2 and bool(choice[2])
	if action == "close":
		close()
		return
	if action.begins_with("goto:"):
		open(action.substr(5))
		return
	GameState.run_dialogue_action(action)
	if keep_open:
		# Rafraîchit le texte (ex. or restant) sans rejouer tout le dialogue.
		var data := DialogueDB.get_dialogue(_npc_id)
		_lines = data.get("lines", [])
		_choice_data = data.get("choices", [])
		_index = maxi(0, _lines.size() - 1)
		if not _lines.is_empty():
			var line: Array = _lines[_index]
			_text.text = str(line[1])
			_text.visible_ratio = 1.0
		_typing = false
		_show_choices()
	else:
		close()


func _input(event: InputEvent) -> void:
	if not _open:
		return
	# Choix au clavier (1, 2, 3...).
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and _choices.get_child_count() > 0:
		var idx := int(key.physical_keycode) - int(KEY_1)
		if idx >= 0 and idx < _choices.get_child_count():
			(_choices.get_child(idx) as Button).emit_signal("pressed")
			get_viewport().set_input_as_handled()
			return
	var advance := event.is_action_pressed("interact") or event.is_action_pressed("ui_accept")
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		advance = true
	if not advance:
		return
	if _choices.get_child_count() > 0:
		return # on laisse les boutons gérer
	get_viewport().set_input_as_handled()
	if _typing:
		_text.visible_ratio = 1.0
		return
	if _index < _lines.size() - 1:
		_index += 1
		_show_line()
	elif _choice_data.is_empty():
		close()
