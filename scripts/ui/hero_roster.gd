class_name HeroRoster
extends PanelContainer
## « Mes héros » (écran titre) : tous les héros enregistrés (un fichier chacun, leur sauvegarde automatique), le plus
## récemment joué en premier. Pour chacun :
##   • « Jouer » : reprend ce héros là où il en était ;
##   • « Choisir » : il devient le héros actuel (« Continuer », « Héberger » et « Rejoindre » le prennent) ;
##   • « Supprimer » : après confirmation, efface définitivement sa sauvegarde.
## Créer un nouveau héros (« Nouvelle partie ») n'efface plus les autres.

signal changed

var _list: VBoxContainer
var _info: Label
var _confirm: ConfirmationDialog
var _pending_delete := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.5
	anchor_bottom = 0.5
	offset_left = -470
	offset_right = 470
	offset_top = -300
	offset_bottom = 300
	add_theme_stylebox_override("panel", UiStyle.frame(true, 30))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	add_child(vb)
	var title := UiStyle.label("MES HÉROS", 30, Color(1.0, 0.8, 0.45))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 400)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)
	_info = UiStyle.label("", 16, UiStyle.DIM)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_info)
	var back := Button.new()
	back.text = "Retour"
	back.custom_minimum_size = Vector2(0, 40)
	back.pressed.connect(close)
	vb.add_child(back)
	_confirm = ConfirmationDialog.new()
	_confirm.title = "Supprimer un héros"
	_confirm.ok_button_text = "Supprimer définitivement"
	_confirm.cancel_button_text = "Annuler"
	_confirm.confirmed.connect(_on_delete_confirmed)
	add_child(_confirm)
	visible = false


func open() -> void:
	GameState.import_legacy_save()
	_info.text = ""
	_refresh()
	visible = true


func close() -> void:
	visible = false


func _refresh() -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	var current := GameState.current_hero_id()
	var all := GameState.heroes()
	if all.is_empty():
		_list.add_child(UiStyle.label("Aucun héros pour l'instant : « Nouvelle partie » pour en créer un.", 17, UiStyle.DIM))
	for h: Dictionary in all:
		var id := str(h["id"])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var text := UiStyle.label(("★ " if id == current else "") + str(h["summary"]), 16,
			Color(1.0, 0.85, 0.45) if id == current else UiStyle.BONE)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.clip_text = true
		text.tooltip_text = "Héros actuel (Continuer, Héberger, Rejoindre)" if id == current else ""
		text.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(text)
		row.add_child(_button("Jouer", _on_play.bind(id)))
		var choose := _button("Choisir", _on_choose.bind(id))
		choose.disabled = id == current
		row.add_child(choose)
		row.add_child(_button("Supprimer", _on_delete.bind(id, str(h["name"]))))
		_list.add_child(row)


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 40)
	b.pressed.connect(cb)
	return b


func _on_play(id: String) -> void:
	if GameState.load_hero(id):
		Sfx.play("levelup", -8.0, 0.0)
		visible = false
		Router.go_to(GameState.resume_scene())


## Le héros devient le héros actuel, sans lancer la partie (pour « Héberger » ou « Rejoindre » avec lui).
func _on_choose(id: String) -> void:
	if GameState.load_hero(id):
		_info.text = "%s est votre héros actuel." % GameState.hero_name
		_refresh()
		changed.emit()


func _on_delete(id: String, hero_name: String) -> void:
	_pending_delete = id
	_confirm.dialog_text = "Supprimer définitivement %s et toute sa progression ?\nCette action est irréversible." % hero_name
	_confirm.popup_centered()


func _on_delete_confirmed() -> void:
	if _pending_delete.is_empty():
		return
	GameState.delete_hero(_pending_delete)
	_pending_delete = ""
	_info.text = "Héros supprimé."
	_refresh()
	changed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()
