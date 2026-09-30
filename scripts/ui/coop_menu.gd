class_name CoopMenu
extends PanelContainer
## Fenêtre Coopération.
##  • En jeu (menu pause) : « Ouvrir ma partie » → affiche le code d'invitation à envoyer
##    aux amis, la liste des joueurs connectés, et permet de fermer la partie.
##  • Écran titre : « Rejoindre une partie » → coller le code reçu ; on arrive avec son
##    propre personnage (celui de la dernière sauvegarde), quel que soit son niveau.

signal closed

var _title: Label
var _body: VBoxContainer
var _status: Label
var _code_label: Label
var _note: Label
var _players: Label
var _code_edit: LineEdit
var _host_mode := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.5
	anchor_bottom = 0.5
	offset_left = -400
	offset_right = 400
	offset_top = -320
	offset_bottom = 320
	var style := UiStyle.box(Color(0.07, 0.055, 0.055, 1.0), UiStyle.BORDER, 3)
	style.shadow_size = 2000
	style.shadow_color = Color(0, 0, 0, 0.7)
	style.set_content_margin_all(20)
	add_theme_stylebox_override("panel", style)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	add_child(vb)
	_title = UiStyle.label("COOPÉRATION", 30, Color(1.0, 0.8, 0.45))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_title)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 10)
	vb.add_child(_body)
	_status = UiStyle.label("", 16, UiStyle.DIM)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_status)
	var back := Button.new()
	back.text = "Retour"
	back.custom_minimum_size = Vector2(0, 40)
	back.pressed.connect(close)
	vb.add_child(back)
	visible = false
	Net.status_changed.connect(func(t: String) -> void: _status.text = t)
	Net.code_ready.connect(_on_code_ready)
	Net.roster_changed.connect(_refresh_players)


func _clear() -> void:
	for c in _body.get_children():
		c.queue_free()
	_code_label = null
	_note = null
	_players = null
	_code_edit = null


## En jeu : ouvrir la partie aux amis (ou voir qui est connecté).
func open_host() -> void:
	_host_mode = true
	_clear()
	visible = true
	if Net.is_client():
		_body.add_child(_text("Vous êtes dans la partie d'un ami.", 20, UiStyle.BONE))
		_players = _text("", 18, Color(0.55, 0.85, 1.0))
		_body.add_child(_players)
		_body.add_child(_button("Quitter la partie", _leave))
		_refresh_players()
		return
	_body.add_child(_text("Invitez jusqu'à 5 amis : envoyez-leur le code qui correspond à leur situation. Ils le collent dans « Rejoindre une partie » sur l'écran titre et arrivent avec leur propre personnage.", 16, UiStyle.BONE))
	if Net.is_online() and not Net.codes.is_empty():
		# Un code par façon de se connecter (Internet, VPN, réseau local), avec son usage.
		for entry: Dictionary in Net.codes:
			var line := HBoxContainer.new()
			line.add_theme_constant_override("separation", 12)
			_body.add_child(line)
			var name_label := _text(str(entry["label"]), 18, UiStyle.BONE)
			name_label.custom_minimum_size = Vector2(150, 0)
			line.add_child(name_label)
			var code_label := _text(str(entry["code"]), 30, Color(1.0, 0.85, 0.35))
			code_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			line.add_child(code_label)
			if _code_label == null:
				_code_label = code_label
			line.add_child(_button("Copier", _copy.bind(str(entry["code"]))))
			_body.add_child(_text(str(entry["hint"]), 13, UiStyle.DIM))
	else:
		_code_label = _text(Net.code if not Net.code.is_empty() else "—", 40, Color(1.0, 0.85, 0.35))
		_code_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_body.add_child(_code_label)
	_note = _text("", 13, Color(1.0, 0.7, 0.45))
	_body.add_child(_note)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_body.add_child(row)
	if not Net.is_online():
		row.add_child(_button("Ouvrir ma partie", _open_game))
	else:
		row.add_child(_button("Fermer la partie", _leave))
	_players = _text("", 18, Color(0.55, 0.85, 1.0))
	_body.add_child(_players)
	_refresh_players()


## Écran titre : rejoindre avec un code.
func open_join() -> void:
	_host_mode = false
	_clear()
	visible = true
	_title.text = "REJOINDRE UNE PARTIE"
	if not GameState.has_save():
		_body.add_child(_text("Créez d'abord un personnage (Nouvelle partie) : c'est lui qui rejoindra la partie de votre ami.", 18, Events.COLOR_BAD))
		return
	_body.add_child(_text("Collez le code d'invitation envoyé par l'hôte (ou son adresse IP). Vous jouerez avec le personnage de votre dernière sauvegarde :", 17, UiStyle.BONE))
	_body.add_child(_text(GameState.slot_summary(0), 17, Color(1.0, 0.8, 0.45)))
	_code_edit = LineEdit.new()
	_code_edit.placeholder_text = "XXXXX-XXXXX ou adresse IP"
	_code_edit.max_length = 24
	_code_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_code_edit.custom_minimum_size = Vector2(0, 50)
	_code_edit.add_theme_font_size_override("font_size", 28)
	_code_edit.text_submitted.connect(func(_t: String) -> void: _join())
	_body.add_child(_code_edit)
	_body.add_child(_button("Rejoindre", _join))
	_code_edit.grab_focus()


func close() -> void:
	visible = false
	_title.text = "COOPÉRATION"
	closed.emit()


func _open_game() -> void:
	var err := Net.host()
	if not err.is_empty():
		_status.text = err
		return
	open_host()


func _on_code_ready(new_code: String, note: String) -> void:
	if _code_label != null and is_instance_valid(_code_label):
		_code_label.text = new_code
	if _note != null and is_instance_valid(_note):
		_note.text = note
	if visible and _host_mode:
		open_host()
		_note.text = note


func _copy(value: String) -> void:
	DisplayServer.clipboard_set(value)
	_status.text = "Code copié dans le presse-papiers : %s" % value


func _leave() -> void:
	Net.leave()
	open_host()


func _join() -> void:
	if _code_edit == null:
		return
	if not GameState.load_game():
		_status.text = "Impossible de charger votre personnage."
		return
	var err := Net.join(_code_edit.text)
	if not err.is_empty():
		_status.text = err


func _refresh_players() -> void:
	if _players == null or not is_instance_valid(_players):
		return
	if not Net.is_online():
		_players.text = ""
		return
	var names: PackedStringArray = []
	for id: int in Net.players:
		var p: Dictionary = Net.players[id]
		names.append("• %s — %s niv. %d%s" % [str(p.get("name", "?")), RaceDB.title(p.get("appearance", {})),
			int(p.get("level", 1)), " (hôte)" if id == 1 else ""])
	_players.text = "Joueurs (%d/%d) :\n%s" % [Net.players.size(), Net.MAX_PLAYERS, "\n".join(names)]


func _text(t: String, size: int, color: Color) -> Label:
	var l := UiStyle.label(t, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(660, 0)
	return l


func _button(t: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(0, 44)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(cb)
	return b


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()
