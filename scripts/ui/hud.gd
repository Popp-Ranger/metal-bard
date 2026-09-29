class_name Hud
extends CanvasLayer
## Interface en jeu : barres (PV / décibels / XP), barre de compétences avec recharges,
## suivi de quête, messages, invite d'interaction, barre de vie du boss,
## et les fenêtres (dialogue, solo, fiche, pause, mort).

const SKILLS := [
	{"id": "attack", "name": "Luth", "action": "attack", "cost": 0.0, "color": Color(0.8, 0.6, 0.4)},
	{"id": "arc", "name": "Riff\nélectrique", "action": "spell_arc", "cost": Balance.ARC_COST, "color": Color(0.5, 0.8, 1.0)},
	{"id": "wave", "name": "Onde\nde choc", "action": "spell_wave", "cost": Balance.WAVE_COST, "color": Color(0.75, 0.55, 1.0)},
	{"id": "solo", "name": "Solo de\nla Foudre", "action": "spell_solo", "cost": Balance.SOLO_COST, "color": Color(1.0, 0.85, 0.35)},
	{"id": "potion", "name": "Potion", "action": "potion", "cost": 0.0, "color": Color(0.95, 0.3, 0.3)},
]

var dialogue: DialogueBox
var solo: SoloMinigame
var sheet: CharacterSheet

var _root: Control
var _hp_bar: ProgressBar
var _hp_label: Label
var _mana_bar: ProgressBar
var _mana_label: Label
var _xp_bar: ProgressBar
var _level_label: Label
var _gold_label: Label
var _quest_title: Label
var _quest_text: Label
var _prompt: Label
var _toasts: VBoxContainer
var _area_label: Label
var _boss_box: VBoxContainer
var _boss_bar: ProgressBar
var _boss_name: Label
var _flash: ColorRect
var _slots := {} # id -> {"overlay": ColorRect, "panel": Panel, "remaining": float, "duration": float, "extra": Label}
var _pause_menu: PanelContainer
var _death_screen: Control


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UiStyle.theme()
	add_child(_root)
	_build_flash()
	_build_status()
	_build_skills()
	_build_quest_tracker()
	_build_boss_bar()
	_build_messages()
	dialogue = DialogueBox.new()
	_root.add_child(dialogue)
	solo = SoloMinigame.new()
	_root.add_child(solo)
	sheet = CharacterSheet.new()
	_root.add_child(sheet)
	_build_pause_menu()
	_build_death_screen()
	_connect_events()
	_refresh_quest("")


func _connect_events() -> void:
	Events.hero_hp_changed.connect(_on_hp)
	Events.hero_mana_changed.connect(_on_mana)
	Events.xp_changed.connect(_on_xp)
	Events.gold_changed.connect(func(g: int) -> void: _gold_label.text = "%d po" % g)
	Events.potions_changed.connect(_on_potions)
	Events.toast.connect(_on_toast)
	Events.interaction_prompt.connect(func(t: String) -> void: _prompt.text = t)
	Events.cooldown_started.connect(_on_cooldown)
	Events.quest_updated.connect(_refresh_quest)
	Events.portal_opened.connect(func() -> void: _refresh_quest(""))
	Events.boss_health.connect(_on_boss_health)
	Events.screen_flash.connect(_on_flash)
	Events.hero_died.connect(_on_hero_died)
	Events.level_up.connect(func(_l: int) -> void: Sfx.play("levelup", -2.0, 0.0))


# --- Construction -------------------------------------------------------------

func _build_flash() -> void:
	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(1, 1, 1, 0)
	_root.add_child(_flash)


func _build_status() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	panel.add_child(vb)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	vb.add_child(head)
	head.add_child(UiStyle.label(GameState.HERO_NAME, 22, Color(1.0, 0.8, 0.45)))
	_level_label = UiStyle.label("Niv. 1", 18, UiStyle.BONE)
	head.add_child(_level_label)
	_gold_label = UiStyle.label("0 po", 18, Events.COLOR_GOLD)
	head.add_child(_gold_label)
	_hp_bar = UiStyle.bar(Color(0.65, 0.08, 0.06), Vector2(300, 22))
	vb.add_child(_hp_bar)
	_hp_label = UiStyle.label("", 14)
	_hp_label.set_anchors_preset(Control.PRESET_CENTER)
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hp_bar.add_child(_hp_label)
	_mana_bar = UiStyle.bar(Color(0.35, 0.2, 0.75), Vector2(300, 16))
	vb.add_child(_mana_bar)
	_mana_label = UiStyle.label("", 12)
	_mana_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mana_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mana_bar.add_child(_mana_label)
	_xp_bar = UiStyle.bar(Color(0.8, 0.6, 0.15), Vector2(300, 6))
	vb.add_child(_xp_bar)


func _build_skills() -> void:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	bar.anchor_left = 0.5
	bar.anchor_right = 0.5
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_left = -(SKILLS.size() * 96) * 0.5
	bar.offset_top = -126
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bar)
	for s: Dictionary in SKILLS:
		var panel := Panel.new()
		panel.custom_minimum_size = Vector2(84, 84)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var c: Color = s["color"]
		panel.add_theme_stylebox_override("panel", UiStyle.box(Color(0.07, 0.05, 0.05, 0.92), c.darkened(0.3), 2))
		bar.add_child(panel)
		var name_label := UiStyle.label(str(s["name"]), 13, c)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		name_label.offset_top = 18
		name_label.offset_bottom = -4
		panel.add_child(name_label)
		var key := UiStyle.label(Controls.key_label(str(s["action"])), 13, UiStyle.BONE)
		key.position = Vector2(6, 2)
		panel.add_child(key)
		var extra := UiStyle.label("", 12, Color(0.7, 0.6, 1.0))
		extra.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		extra.position = Vector2(30, 3)
		extra.size = Vector2(48, 16)
		var cost: float = s["cost"]
		if cost > 0.0:
			extra.text = "%d dB" % roundi(cost)
		panel.add_child(extra)
		var overlay := ColorRect.new()
		overlay.color = Color(0, 0, 0, 0.65)
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.size = Vector2(84, 0)
		panel.add_child(overlay)
		_slots[s["id"]] = {"overlay": overlay, "panel": panel, "remaining": 0.0, "duration": 1.0, "extra": extra, "cost": cost}
	_on_potions(GameState.potions)
	var help := UiStyle.label("ZQSD/WASD : se déplacer  •  Souris : viser  •  Molette : zoom  •  %s : parler  •  %s : fiche  •  Échap : pause" % [
		Controls.key_label("interact"), Controls.key_label("character_sheet")], 13, UiStyle.DIM)
	help.anchor_left = 0.5
	help.anchor_right = 0.5
	help.anchor_top = 1.0
	help.anchor_bottom = 1.0
	help.offset_left = -400
	help.offset_right = 400
	help.offset_top = -30
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(help)
	_prompt = UiStyle.label("", 20, Color(1.0, 0.9, 0.6))
	_prompt.anchor_left = 0.5
	_prompt.anchor_right = 0.5
	_prompt.anchor_top = 1.0
	_prompt.anchor_bottom = 1.0
	_prompt.offset_left = -400
	_prompt.offset_right = 400
	_prompt.offset_top = -168
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_prompt)


func _build_quest_tracker() -> void:
	var panel := PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -360
	panel.offset_right = -16
	panel.offset_top = 16
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(panel)
	var vb := VBoxContainer.new()
	panel.add_child(vb)
	_quest_title = UiStyle.label("", 18, Color(1.0, 0.8, 0.45))
	vb.add_child(_quest_title)
	_quest_text = UiStyle.label("", 15, UiStyle.BONE)
	_quest_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_quest_text.custom_minimum_size = Vector2(320, 0)
	vb.add_child(_quest_text)


func _build_boss_bar() -> void:
	_boss_box = VBoxContainer.new()
	_boss_box.anchor_left = 0.5
	_boss_box.anchor_right = 0.5
	_boss_box.offset_left = -300
	_boss_box.offset_right = 300
	_boss_box.offset_top = 18
	_boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_boss_box)
	_boss_name = UiStyle.label("", 20, Color(0.7, 1.0, 0.6))
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_box.add_child(_boss_name)
	_boss_bar = UiStyle.bar(Color(0.25, 0.55, 0.2), Vector2(600, 18))
	_boss_box.add_child(_boss_bar)
	_boss_box.visible = false


func _build_messages() -> void:
	_area_label = UiStyle.label("", 40, Color(0.95, 0.85, 0.65))
	_area_label.anchor_left = 0.5
	_area_label.anchor_right = 0.5
	_area_label.offset_left = -500
	_area_label.offset_right = 500
	_area_label.offset_top = 120
	_area_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_area_label.modulate.a = 0.0
	_root.add_child(_area_label)
	_toasts = VBoxContainer.new()
	_toasts.anchor_left = 0.5
	_toasts.anchor_right = 0.5
	_toasts.offset_left = -450
	_toasts.offset_right = 450
	_toasts.offset_top = 190
	_toasts.alignment = BoxContainer.ALIGNMENT_BEGIN
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_toasts)


func _build_pause_menu() -> void:
	_pause_menu = PanelContainer.new()
	_pause_menu.anchor_left = 0.5
	_pause_menu.anchor_right = 0.5
	_pause_menu.anchor_top = 0.5
	_pause_menu.anchor_bottom = 0.5
	_pause_menu.offset_left = -170
	_pause_menu.offset_right = 170
	_pause_menu.offset_top = -150
	_pause_menu.offset_bottom = 150
	_root.add_child(_pause_menu)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	_pause_menu.add_child(vb)
	var title := UiStyle.label("PAUSE", 32, Color(1.0, 0.8, 0.45))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	for entry: Array in [["Reprendre", _toggle_pause], ["Fiche de personnage", _open_sheet_from_pause],
			["Menu principal", _to_main_menu], ["Quitter le jeu", func() -> void: get_tree().quit()]]:
		var b := Button.new()
		b.text = str(entry[0])
		b.custom_minimum_size = Vector2(0, 40)
		b.pressed.connect(entry[1] as Callable)
		vb.add_child(b)
	_pause_menu.visible = false


func _build_death_screen() -> void:
	_death_screen = ColorRect.new()
	(_death_screen as ColorRect).color = Color(0.1, 0.0, 0.0, 0.75)
	_death_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_death_screen)
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 16)
	vb.offset_left = -300
	vb.offset_right = 300
	vb.offset_top = -120
	vb.offset_bottom = 120
	_death_screen.add_child(vb)
	var t := UiStyle.label("VOUS ÊTES TOMBÉ", 54, Color(0.85, 0.15, 0.1))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	var sub := UiStyle.label("Le silence retombe sur les catacombes... Mais un barde ne meurt jamais vraiment.", 18, UiStyle.BONE)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(sub)
	var b := Button.new()
	b.text = "Se réveiller à la taverne (-%d %% de l'or)" % roundi(Balance.DEATH_GOLD_PENALTY * 100.0)
	b.custom_minimum_size = Vector2(0, 44)
	b.pressed.connect(_revive)
	vb.add_child(b)
	_death_screen.visible = false


# --- Mise à jour --------------------------------------------------------------

func _process(delta: float) -> void:
	for id: String in _slots:
		var slot: Dictionary = _slots[id]
		var remaining := maxf(0.0, float(slot["remaining"]) - delta)
		slot["remaining"] = remaining
		var ratio := remaining / maxf(0.01, float(slot["duration"]))
		var overlay: ColorRect = slot["overlay"]
		overlay.size = Vector2(84, 84.0 * ratio)
		overlay.position = Vector2(0, 84.0 * (1.0 - ratio))
		var cost: float = slot["cost"]
		var panel: Panel = slot["panel"]
		panel.modulate = Color(0.5, 0.5, 0.6) if cost > GameState.mana else Color.WHITE


func _unhandled_input(event: InputEvent) -> void:
	if _death_screen.visible:
		return
	if event.is_action_pressed("pause"):
		if sheet.visible:
			sheet.close()
		elif not dialogue.visible and not solo.visible:
			_toggle_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("character_sheet") and not dialogue.visible and not solo.visible and not _pause_menu.visible:
		sheet.toggle()
		get_viewport().set_input_as_handled()


func show_area_name(text: String) -> void:
	_area_label.text = text
	var tw := create_tween()
	tw.tween_property(_area_label, "modulate:a", 1.0, 0.8)
	tw.tween_interval(2.0)
	tw.tween_property(_area_label, "modulate:a", 0.0, 1.2)


func _on_hp(hp: int, max_hp: int) -> void:
	_hp_bar.max_value = max_hp
	_hp_bar.value = hp
	_hp_label.text = "%d / %d PV" % [hp, max_hp]


func _on_mana(mana: float, max_mana: float) -> void:
	_mana_bar.max_value = max_mana
	_mana_bar.value = mana
	_mana_label.text = "%d / %d dB" % [roundi(mana), roundi(max_mana)]


func _on_xp(xp: int, next_xp: int, level: int) -> void:
	var prev := GameState.previous_level_xp()
	_xp_bar.max_value = maxi(1, next_xp - prev)
	_xp_bar.value = xp - prev
	var pts := GameState.stats.unspent_points
	_level_label.text = "Niv. %d%s" % [level, "  (+%d pts)" % pts if pts > 0 else ""]


func _on_potions(count: int) -> void:
	var extra: Label = _slots["potion"]["extra"]
	extra.text = "x%d" % count


func _on_cooldown(skill_id: String, duration: float) -> void:
	if not _slots.has(skill_id):
		return
	var slot: Dictionary = _slots[skill_id]
	slot["remaining"] = duration
	slot["duration"] = duration


func _on_toast(text: String, color: Color) -> void:
	var l := UiStyle.label(text, 20, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(900, 0)
	_toasts.add_child(l)
	while _toasts.get_child_count() > 4:
		var old := _toasts.get_child(0)
		_toasts.remove_child(old)
		old.queue_free()
	var tw := l.create_tween()
	tw.tween_interval(3.2)
	tw.tween_property(l, "modulate:a", 0.0, 0.8)
	tw.tween_callback(l.queue_free)


func _refresh_quest(_id: String) -> void:
	var qid := GameState.active_quest
	if qid.is_empty():
		for id: String in QuestDB.QUESTS:
			if GameState.quest_state(id) == QuestDB.State.AVAILABLE:
				_quest_title.text = "Quête disponible"
				_quest_text.text = "Parlez à %s dans la taverne." % DialogueDB.npc_name(str(QuestDB.get_quest(id).get("giver", "")))
				return
		_quest_title.text = "Aucune quête"
		_quest_text.text = "D'autres aventures arrivent bientôt..."
		return
	var q := QuestDB.get_quest(qid)
	_quest_title.text = str(q.get("title", qid))
	match GameState.quest_state(qid):
		QuestDB.State.ACTIVE:
			if GameState.flags.get("portal_open", false) or GameState.flags.get("in_dungeon", false):
				_quest_text.text = str(q.get("objective", ""))
			else:
				_quest_text.text = str(q.get("objective_talk_mage", q.get("objective", "")))
		QuestDB.State.OBJECTIVE_DONE:
			_quest_text.text = str(q.get("objective_done", ""))
		_:
			_quest_text.text = ""


func _on_boss_health(boss_name: String, hp: int, max_hp: int) -> void:
	_boss_box.visible = hp > 0
	_boss_name.text = boss_name
	_boss_bar.max_value = max_hp
	_boss_bar.value = hp


func _on_flash(color: Color, duration: float) -> void:
	_flash.color = color
	var tw := create_tween()
	tw.tween_property(_flash, "color:a", 0.0, duration)


func _toggle_pause() -> void:
	_pause_menu.visible = not _pause_menu.visible
	get_tree().paused = _pause_menu.visible


func _open_sheet_from_pause() -> void:
	_pause_menu.visible = false
	sheet.toggle()


func _to_main_menu() -> void:
	GameState.save_game()
	Router.go_to(Router.MAIN_MENU)


func _on_hero_died() -> void:
	await get_tree().create_timer(1.2).timeout
	_death_screen.visible = true
	_death_screen.modulate.a = 0.0
	create_tween().tween_property(_death_screen, "modulate:a", 1.0, 0.8)
	get_tree().paused = true


func _revive() -> void:
	GameState.apply_death_penalty()
	GameState.flags["in_dungeon"] = true
	GameState.save_game()
	Router.go_to(Router.TAVERN)
