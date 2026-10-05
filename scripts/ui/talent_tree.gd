class_name TalentTree
extends PanelContainer
## Écran de l'arbre de talents (touche T) : 5 branches × 4 paliers.
## Clic sur une carte disponible = apprendre le talent (1 point).
## Talents actifs appris : le bouton « Touche » les fait tourner sur les emplacements 4 → 7.

const CARD_SIZE := Vector2(236, 128)

var _columns: HBoxContainer
var _header: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.5
	anchor_bottom = 0.5
	offset_left = -640
	offset_right = 640
	offset_top = -390
	offset_bottom = 380
	var style := UiStyle.frame(false, 26)
	add_theme_stylebox_override("panel", style)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	add_child(vb)
	_header = UiStyle.label("", 26, Color(1.0, 0.8, 0.45))
	_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_header)
	var hint := UiStyle.label("Clic sur une carte : apprendre (1 point par niveau)  •  Sorts actifs : bouton « Touche » pour choisir 4, 5, 6 ou 7", 14, UiStyle.DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(hint)
	_columns = HBoxContainer.new()
	_columns.add_theme_constant_override("separation", 12)
	_columns.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(_columns)
	var close_btn := Button.new()
	close_btn.text = "Fermer [%s]" % Controls.key_label("talents")
	close_btn.custom_minimum_size = Vector2(0, 38)
	close_btn.pressed.connect(close)
	vb.add_child(close_btn)
	visible = false
	Events.talents_changed.connect(_refresh)


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open() -> void:
	visible = true
	get_tree().paused = true
	_refresh()


func close() -> void:
	visible = false
	get_tree().paused = false


func _refresh() -> void:
	if not visible:
		return
	_header.text = "ARBRE DE TALENTS — %d point%s disponible%s" % [
		GameState.talent_points, "s" if GameState.talent_points > 1 else "", "s" if GameState.talent_points > 1 else ""]
	for c in _columns.get_children():
		_columns.remove_child(c)
		c.queue_free()
	for branch: Dictionary in TalentDB.BRANCHES:
		_columns.add_child(_build_column(branch))


func _build_column(branch: Dictionary) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	var color: Color = branch["color"]
	var title := UiStyle.label(str(branch["name"]), 22, color)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var role := UiStyle.label(str(branch["role"]), 14, color.darkened(0.2))
	role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(role)
	var talents: Array = branch["talents"]
	for i in talents.size():
		if i > 0:
			var arrow := UiStyle.label("▼", 14, color.darkened(0.4))
			arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			col.add_child(arrow)
		col.add_child(_build_card(str(talents[i]), color))
	return col


func _build_card(id: String, color: Color) -> Control:
	var t := TalentDB.get_talent(id)
	var learned := GameState.has_talent(id)
	var reason := GameState.talent_block_reason(id)
	var available := reason.is_empty()
	var card := PanelContainer.new()
	card.custom_minimum_size = CARD_SIZE
	var border := color if learned else (color.darkened(0.2) if available else Color(0.25, 0.22, 0.2))
	var bg := Color(0.12, 0.09, 0.07, 0.95) if learned else Color(0.07, 0.055, 0.05, 0.95)
	var style := UiStyle.box(bg, border, 3 if learned else 2)
	style.set_content_margin_all(8)
	card.add_theme_stylebox_override("panel", style)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.tooltip_text = str(t.get("desc", ""))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(vb)
	var name_label := UiStyle.label(str(t.get("name", id)), 16, color if (learned or available) else Color(0.5, 0.47, 0.44))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(name_label)
	var kind := "Passif"
	if bool(t.get("active", false)):
		kind = "Actif — %d dB, %d s" % [roundi(float(t.get("cost", 0.0))), roundi(float(t.get("cooldown", 0.0)))]
	var kind_label := UiStyle.label(kind, 12, UiStyle.DIM)
	kind_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(kind_label)
	var desc := UiStyle.label(str(t.get("desc", "")), 11, UiStyle.BONE if (learned or available) else Color(0.45, 0.43, 0.4))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(CARD_SIZE.x - 18, 0)
	desc.max_lines_visible = 4
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(desc)
	if learned:
		if bool(t.get("active", false)):
			var slot := GameState.spell_slots.find(id)
			var btn := Button.new()
			btn.text = "Touche : %s" % (Controls.key_label("talent_%d" % (slot + 1)) if slot != -1 else "aucune")
			btn.add_theme_font_size_override("font_size", 13)
			btn.pressed.connect(func() -> void: GameState.cycle_slot(id))
			vb.add_child(btn)
		else:
			var ok := UiStyle.label("✔ Appris", 13, Color(0.55, 0.95, 0.55))
			ok.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vb.add_child(ok)
	else:
		var status := UiStyle.label("Cliquer pour apprendre" if available else reason, 12,
			Color(1.0, 0.85, 0.35) if available else Color(0.6, 0.45, 0.4))
		status.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(status)
		if available:
			card.gui_input.connect(_on_card_input.bind(id))
	return card


func _on_card_input(event: InputEvent, id: String) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		if GameState.learn_talent(id):
			Sfx.play("levelup", -6.0, 0.0)


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("pause") or event.is_action_pressed("talents")):
		get_viewport().set_input_as_handled()
		close()
