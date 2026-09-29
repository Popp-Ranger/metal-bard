class_name OptionsMenu
extends PanelContainer
## Menu Options > Audio : un curseur indépendant par canal
## (Musique, Sorts et effets, Dialogues). Les réglages sont appliqués en direct
## et sauvegardés à la fermeture. Accessible depuis l'écran titre et le menu pause.

signal closed

var _value_labels := {} # nom du bus -> Label « 80 % »


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.5
	anchor_bottom = 0.5
	offset_left = -260
	offset_right = 260
	offset_top = -125
	offset_bottom = 125
	var style := UiStyle.box(Color(0.07, 0.055, 0.055, 1.0), UiStyle.BORDER, 3)
	style.shadow_size = 2000 # voile sombre sur tout l'écran derrière le panneau
	style.shadow_color = Color(0, 0, 0, 0.7)
	style.set_content_margin_all(22)
	add_theme_stylebox_override("panel", style)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	add_child(vb)
	var title := UiStyle.label("OPTIONS — AUDIO", 30, Color(1.0, 0.8, 0.45))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	for channel: Array in Sfx.CHANNELS:
		vb.add_child(_slider_row(str(channel[0]), str(channel[1])))
	var back := Button.new()
	back.text = "Retour"
	back.custom_minimum_size = Vector2(0, 42)
	back.pressed.connect(close)
	vb.add_child(back)
	visible = false


func _slider_row(bus_name: String, label_text: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var name_label := UiStyle.label(label_text, 20)
	name_label.custom_minimum_size = Vector2(170, 0)
	row.add_child(name_label)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.custom_minimum_size = Vector2(220, 28)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value = roundi(Sfx.get_volume(bus_name) * 100.0)
	slider.value_changed.connect(_on_slider_changed.bind(bus_name))
	slider.drag_ended.connect(_on_drag_ended.bind(bus_name))
	row.add_child(slider)
	var value_label := UiStyle.label("%d %%" % roundi(slider.value), 18, UiStyle.DIM)
	value_label.custom_minimum_size = Vector2(60, 0)
	row.add_child(value_label)
	_value_labels[bus_name] = value_label
	return row


func open() -> void:
	visible = true
	# Premier curseur sélectionné : réglable aussi au clavier / à la manette.
	var first := find_children("*", "HSlider", true, false)
	if not first.is_empty():
		(first[0] as Control).grab_focus()


func close() -> void:
	Sfx.save_settings()
	visible = false
	closed.emit()


func _on_slider_changed(value: float, bus_name: String) -> void:
	Sfx.set_volume(bus_name, value / 100.0)
	var label: Label = _value_labels[bus_name]
	label.text = "%d %%" % roundi(value)


## Petit son d'essai quand on relâche le curseur (la musique, elle, joue déjà).
func _on_drag_ended(_changed: bool, bus_name: String) -> void:
	if bus_name == Sfx.BUS_SFX:
		Sfx.play("zap", Balance.ZAP_VOLUME_DB)
	elif bus_name == Sfx.BUS_DIALOGUE:
		for i in 3:
			Sfx.play_voice(1.0)
			await get_tree().create_timer(0.09, true).timeout


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()
