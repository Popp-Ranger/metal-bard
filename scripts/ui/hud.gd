class_name Hud
extends CanvasLayer
## Interface en jeu : réservoirs de vie (la main cornue, en bas à gauche) et de décibels (l'enceinte, en bas à droite),
## barre d'XP, barre de compétences dans son cadre de fer (art/hud/build_hud.py) avec recharges,
## suivi de quête, messages, invite d'interaction, barre de vie du boss,
## et les fenêtres (dialogue, solo, fiche, pause, mort).

const SKILLS := [
	{"id": "attack", "name": "Guitare", "action": "attack", "cost": 0.0, "color": Color(0.8, 0.6, 0.4)},
	{"id": "dash", "name": "Glissade", "action": "dash", "cost": 0.0, "color": Color(0.7, 0.85, 1.0)},
	{"id": "tuning", "name": "Accordage\nde cordes", "action": "spell_tuning", "cost": Balance.TUNING_COST, "color": Color(0.5, 0.8, 1.0)},
	{"id": "riff", "name": "Riff\nélectrique", "action": "spell_riff", "cost": Balance.RIFF_COST, "color": Color(0.4, 0.95, 1.0)},
	{"id": "wave", "name": "Onde\nde choc", "action": "spell_wave", "cost": Balance.WAVE_COST, "color": Color(0.75, 0.55, 1.0)},
	{"id": "solo", "name": "Solo de\nla Foudre", "action": "spell_solo", "cost": Balance.SOLO_COST, "color": Color(1.0, 0.85, 0.35)},
	{"id": "tslot_0", "name": "—", "action": "talent_1", "cost": 0.0, "color": Color(0.55, 0.55, 0.55)},
	{"id": "tslot_1", "name": "—", "action": "talent_2", "cost": 0.0, "color": Color(0.55, 0.55, 0.55)},
	{"id": "tslot_2", "name": "—", "action": "talent_3", "cost": 0.0, "color": Color(0.55, 0.55, 0.55)},
	{"id": "tslot_3", "name": "—", "action": "talent_4", "cost": 0.0, "color": Color(0.55, 0.55, 0.55)},
	{"id": "potion", "name": "Potion", "action": "potion", "cost": 0.0, "color": Color(0.95, 0.3, 0.3)},
]

var dialogue: DialogueBox
var solo: SoloMinigame
var sheet: CharacterSheet
var inventory: InventoryWindow
var options: OptionsMenu
var save_menu: SaveMenu
var coop_menu: CoopMenu

var _root: Control
## Réservoirs : la vie (main cornue) et les décibels (enceinte).
var life: Reservoir
var decibels: Reservoir
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
## Barre d'incantation (portail bleu), au-dessus de la barre de sorts.
var cast_box: VBoxContainer
## Barre de sorts (dans son cadre) et ligne d'aide : masquées pendant les dialogues.
var skill_bar: TextureRect
var _help: Label
var _cast_bar: ProgressBar
var _cast_label: Label
var _flash: ColorRect
## Aura rouge clignotante sur le pourtour de l'écran quand la vie passe sous LOW_HP.
var _low_hp: ColorRect
var _low_hp_t := 0.0
const LOW_HP := 0.2
const LOW_HP_PERIOD := 0.75
var _slots := {} # id -> {"overlay": ColorRect, "panel": Panel, "remaining": float, "duration": float, "extra": Label}
var _pause_menu: PanelContainer
var _death_screen: Control
var _talent_slot_of := {} # id de talent -> clé d'emplacement ("tslot_0"...)
var talent_tree: TalentTree
var _kills_label: Label
var _recap: PanelContainer
var _death_recap: Label
var _coop_label: Label


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
	_build_cast_bar()
	_build_messages()
	dialogue = DialogueBox.new()
	_root.add_child(dialogue)
	solo = SoloMinigame.new()
	_root.add_child(solo)
	sheet = CharacterSheet.new()
	_root.add_child(sheet)
	inventory = InventoryWindow.new()
	_root.add_child(inventory)
	talent_tree = TalentTree.new()
	_root.add_child(talent_tree)
	options = OptionsMenu.new()
	_root.add_child(options)
	options.closed.connect(_on_options_closed)
	save_menu = SaveMenu.new()
	save_menu.level = get_parent() as Level
	_root.add_child(save_menu)
	save_menu.closed.connect(_on_options_closed)
	coop_menu = CoopMenu.new()
	_root.add_child(coop_menu)
	coop_menu.closed.connect(_on_options_closed)
	_build_pause_menu()
	_build_death_screen()
	_connect_events()
	_refresh_quest("")
	_coop_label = UiStyle.label("", 16, Color(0.55, 0.85, 1.0))
	_coop_label.position = Vector2(20, 118)
	_root.add_child(_coop_label)
	Net.roster_changed.connect(_refresh_coop)
	Net.code_ready.connect(_on_coop_code)
	_refresh_coop()


func _connect_events() -> void:
	Events.hero_hp_changed.connect(_on_hp)
	Events.hero_mana_changed.connect(_on_mana)
	Events.xp_changed.connect(_on_xp)
	Events.gold_changed.connect(func(g: int) -> void: _gold_label.text = "%d médiators" % g)
	Events.potions_changed.connect(_on_potions)
	Events.toast.connect(_on_toast)
	Events.interaction_prompt.connect(func(t: String) -> void: _prompt.text = t)
	Events.cooldown_started.connect(_on_cooldown)
	Events.talents_changed.connect(_refresh_talent_slots)
	Events.shield_changed.connect(func(_s: int) -> void: _on_hp(GameState.hp, GameState.max_hp()))
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
	_low_hp = ColorRect.new()
	_low_hp.set_anchors_preset(Control.PRESET_FULL_RECT)
	_low_hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	sm.shader = preload("res://shaders/low_hp.gdshader")
	_low_hp.material = sm
	_low_hp.visible = false
	_root.add_child(_low_hp)


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
	head.add_child(UiStyle.label(GameState.hero_name, 22, Color(1.0, 0.8, 0.45)))
	_level_label = UiStyle.label("Niv. 1", 18, UiStyle.BONE)
	head.add_child(_level_label)
	_gold_label = UiStyle.label("0 médiators", 18, Events.COLOR_GOLD)
	head.add_child(_gold_label)
	_xp_bar = UiStyle.bar(Color(0.8, 0.6, 0.15), Vector2(300, 8))
	vb.add_child(_xp_bar)
	# Réservoirs : la main cornue (vie) en bas à gauche, l'enceinte (décibels) en bas à droite.
	life = Reservoir.create("main_vie", LIFE_SIZE, Color(0.28, 0.0, 0.02), Color(1.0, 0.12, 0.06), Color(1.0, 0.62, 0.45))
	_corner(life, false)
	decibels = Reservoir.create("enceinte_db", DB_SIZE, Color(0.16, 0.02, 0.3), Color(0.72, 0.25, 1.0), Color(0.95, 0.75, 1.0))
	_corner(decibels, true)


const LIFE_SIZE := Vector2(150, 200) # main_vie.png (420 × 560) réduite
const DB_SIZE := Vector2(143, 200) # enceinte_db.png (400 × 560) réduite
## Cadre de la barre de sorts (barre_sorts.png, 1050 × 210) réduit à 95 % ; son ouverture, où se posent les cases.
const BAR_SIZE := Vector2(998, 200)
const BAR_WINDOW_CENTER := Vector2(499, 111)
const SLOT := 72.0
const BOTTOM_MARGIN := 30.0


## Pose un réservoir dans un coin bas de l'écran (`right` : à droite).
func _corner(r: Reservoir, right: bool) -> void:
	r.anchor_top = 1.0
	r.anchor_bottom = 1.0
	r.anchor_left = 1.0 if right else 0.0
	r.anchor_right = r.anchor_left
	var w := r.custom_minimum_size.x
	r.offset_left = -w - 24.0 if right else 24.0
	r.offset_right = r.offset_left + w
	r.offset_top = -r.custom_minimum_size.y - BOTTOM_MARGIN + 6.0
	r.offset_bottom = r.offset_top + r.custom_minimum_size.y
	_root.add_child(r)


func _build_skills() -> void:
	var frame := TextureRect.new()
	frame.texture = load("res://assets/ui/barre_sorts.png")
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.anchor_left = 0.5
	frame.anchor_right = 0.5
	frame.anchor_top = 1.0
	frame.anchor_bottom = 1.0
	frame.offset_left = -BAR_SIZE.x * 0.5
	frame.offset_right = BAR_SIZE.x * 0.5
	frame.offset_top = -BAR_SIZE.y - BOTTOM_MARGIN
	frame.offset_bottom = -BOTTOM_MARGIN
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(frame)
	skill_bar = frame
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	var width := SKILLS.size() * SLOT + (SKILLS.size() - 1) * 6.0
	bar.position = BAR_WINDOW_CENTER - Vector2(width, SLOT) * 0.5
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(bar)
	for s: Dictionary in SKILLS:
		var panel := Panel.new()
		panel.custom_minimum_size = Vector2(SLOT, SLOT)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var c: Color = s["color"]
		var bg := UiStyle.box(Color(0.06, 0.045, 0.045, 0.95), c.darkened(0.45), 1, 2)
		bg.shadow_size = 0
		panel.add_theme_stylebox_override("panel", bg)
		bar.add_child(panel)
		var rim := TextureRect.new() # cadre de fer de la case, par-dessus
		rim.texture = load("res://assets/ui/case.png")
		rim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rim.size = Vector2(SLOT, SLOT)
		rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rim.z_index = 1
		panel.add_child(rim)
		var name_label := UiStyle.label(str(s["name"]), 11, c)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		name_label.offset_top = 12
		name_label.offset_bottom = -12
		panel.add_child(name_label)
		var key := UiStyle.label(Controls.key_label(str(s["action"])), 12, UiStyle.BONE)
		key.position = Vector2(8, 4)
		key.z_index = 2
		panel.add_child(key)
		var extra := UiStyle.label("", 11, Color(0.8, 0.6, 1.0))
		extra.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		extra.position = Vector2(8, SLOT - 21) # coût (ou nombre de potions) en bas à droite
		extra.size = Vector2(SLOT - 16, 16)
		extra.z_index = 2
		var cost: float = s["cost"]
		if cost > 0.0:
			extra.text = "%d dB" % roundi(cost)
		panel.add_child(extra)
		var overlay := ColorRect.new()
		overlay.color = Color(0, 0, 0, 0.65)
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.size = Vector2(SLOT, 0)
		panel.add_child(overlay)
		_slots[s["id"]] = {"overlay": overlay, "panel": panel, "remaining": 0.0, "duration": 1.0, "extra": extra, "cost": cost, "name": name_label}
	_on_potions(GameState.potions)
	_refresh_talent_slots()
	var help := UiStyle.label("ZQSD / clic : se déplacer  •  Clic sur un ennemi : frapper  •  Maj + clic : frapper sur place  •  Espace : glissade  •  %s / clic : parler  •  %s : fiche  •  %s : inventaire  •  %s : talents  •  %s : portail  •  Échap : pause" % [
		Controls.key_label("interact"), Controls.key_label("character_sheet"), Controls.key_label("inventory"), Controls.key_label("talents"), Controls.key_label("town_portal")], 13, UiStyle.DIM)
	help.anchor_left = 0.5
	help.anchor_right = 0.5
	help.anchor_top = 1.0
	help.anchor_bottom = 1.0
	help.offset_left = -400
	help.offset_right = 400
	help.offset_top = -26
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(help)
	_help = help
	_prompt = UiStyle.label("", 20, Color(1.0, 0.9, 0.6))
	_prompt.anchor_left = 0.5
	_prompt.anchor_right = 0.5
	_prompt.anchor_top = 1.0
	_prompt.anchor_bottom = 1.0
	_prompt.offset_left = -400
	_prompt.offset_right = 400
	_prompt.offset_top = -BAR_SIZE.y - BOTTOM_MARGIN - 34
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_prompt)


func _build_quest_tracker() -> void:
	var panel := PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -384 # 320 px de texte + les marges du cadre de fer
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


func _build_cast_bar() -> void:
	cast_box = VBoxContainer.new()
	cast_box.anchor_left = 0.5
	cast_box.anchor_right = 0.5
	cast_box.anchor_top = 1.0
	cast_box.anchor_bottom = 1.0
	cast_box.offset_left = -160
	cast_box.offset_right = 160
	cast_box.offset_top = -BAR_SIZE.y - BOTTOM_MARGIN - 84
	cast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(cast_box)
	_cast_label = UiStyle.label("", 16, Color(0.6, 0.85, 1.0))
	_cast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cast_box.add_child(_cast_label)
	_cast_bar = UiStyle.bar(Color(0.3, 0.6, 1.0), Vector2(320, 12))
	_cast_bar.max_value = 1.0
	_cast_bar.step = 0.0
	cast_box.add_child(_cast_bar)
	cast_box.visible = false
	Events.cast_progress.connect(_on_cast_progress)


func _on_cast_progress(label: String, ratio: float) -> void:
	cast_box.visible = ratio >= 0.0
	if ratio >= 0.0:
		_cast_label.text = label
		_cast_bar.value = ratio


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
	_pause_menu.offset_top = -290
	_pause_menu.offset_bottom = 290
	_root.add_child(_pause_menu)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	_pause_menu.add_child(vb)
	var title := UiStyle.label("PAUSE", 32, Color(1.0, 0.8, 0.45))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	for entry: Array in [["Reprendre", _toggle_pause], ["Fiche de personnage", _open_sheet_from_pause], ["Arbre de talents", _open_talents_from_pause], ["Sauvegarder", _open_save_from_pause.bind("save")],
			["Charger", _open_save_from_pause.bind("load")], ["Coopération (inviter des amis)", _open_coop_from_pause], ["Options", _open_options_from_pause],
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
	vb.offset_top = -190
	vb.offset_bottom = 190
	_death_screen.add_child(vb)
	var t := UiStyle.label("VOUS ÊTES TOMBÉ", 54, Color(0.85, 0.15, 0.1))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	var sub := UiStyle.label("Le silence retombe sur les catacombes... Mais un barde ne meurt jamais vraiment.", 18, UiStyle.BONE)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(sub)
	_death_recap = UiStyle.label("", 17, Color(0.9, 0.75, 0.65))
	_death_recap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_death_recap)
	var b := Button.new()
	b.text = "Se réveiller à la taverne (-%d %% des médiators)" % roundi(ItemDB.death_money_penalty() * 100.0)
	b.custom_minimum_size = Vector2(0, 44)
	b.pressed.connect(_revive)
	vb.add_child(b)
	_death_screen.visible = false


# --- Mise à jour --------------------------------------------------------------

func _process(delta: float) -> void:
	_update_low_hp(delta)
	# Pendant un dialogue, la barre de sorts s'efface (son cadre dépasserait autour de la boîte de dialogue).
	var talking := dialogue.visible
	skill_bar.visible = not talking
	_help.visible = not talking
	for id: String in _slots:
		var slot: Dictionary = _slots[id]
		var remaining := maxf(0.0, float(slot["remaining"]) - delta)
		slot["remaining"] = remaining
		var ratio := remaining / maxf(0.01, float(slot["duration"]))
		var overlay: ColorRect = slot["overlay"]
		overlay.size = Vector2(SLOT, SLOT * ratio)
		overlay.position = Vector2(0, SLOT * (1.0 - ratio))
		var cost: float = slot["cost"]
		var panel: Panel = slot["panel"]
		panel.modulate = Color(0.5, 0.5, 0.6) if cost > GameState.mana else Color.WHITE


## Vie sous 20 % : le pourtour de l'écran clignote en rouge, une fois toutes les 0,75 s.
func _update_low_hp(delta: float) -> void:
	var low := GameState.hp > 0 and GameState.hp < GameState.max_hp() * LOW_HP
	_low_hp.visible = low
	if not low:
		_low_hp_t = 0.0
		return
	_low_hp_t = fmod(_low_hp_t + delta, LOW_HP_PERIOD)
	var pulse := 0.5 - 0.5 * cos(TAU * _low_hp_t / LOW_HP_PERIOD)
	(_low_hp.material as ShaderMaterial).set_shader_parameter("intensity", pulse)


func _unhandled_input(event: InputEvent) -> void:
	if _death_screen.visible or options.visible or talent_tree.visible or _recap != null or save_menu.visible or coop_menu.visible:
		return
	if event.is_action_pressed("pause"):
		if inventory.visible:
			inventory.close()
		elif sheet.visible:
			sheet.close()
		elif not dialogue.visible and not solo.visible:
			_toggle_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("character_sheet") and not dialogue.visible and not solo.visible and not _pause_menu.visible:
		sheet.toggle()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("inventory") and not dialogue.visible and not solo.visible and not _pause_menu.visible and not sheet.visible:
		inventory.toggle()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("talents") and not dialogue.visible and not solo.visible and not _pause_menu.visible and not sheet.visible:
		talent_tree.open()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("town_portal") and not dialogue.visible and not solo.visible and not _pause_menu.visible:
		Events.town_portal_requested.emit()
		get_viewport().set_input_as_handled()


func show_area_name(text: String) -> void:
	_area_label.text = text
	var tw := create_tween()
	tw.tween_property(_area_label, "modulate:a", 1.0, 0.8)
	tw.tween_interval(2.0)
	tw.tween_property(_area_label, "modulate:a", 0.0, 1.2)


func _on_hp(hp: int, max_hp: int) -> void:
	var text := "VIE %d %%  ·  %d / %d" % [roundi(100.0 * hp / maxf(1.0, max_hp)), hp, max_hp]
	if GameState.shield > 0:
		text += "  +%d" % GameState.shield
	life.set_value(hp, max_hp, text)


func _on_mana(mana: float, max_mana: float) -> void:
	decibels.set_value(mana, max_mana, "dB %d %%  ·  %d / %d" % [roundi(100.0 * mana / maxf(1.0, max_mana)), roundi(mana), roundi(max_mana)])


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
	var key: String = skill_id if _slots.has(skill_id) else str(_talent_slot_of.get(skill_id, ""))
	if not _slots.has(key):
		return
	var slot: Dictionary = _slots[key]
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
	_quest_text.text = QuestDB.objective_text(qid)


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


func _open_talents_from_pause() -> void:
	_pause_menu.visible = false
	talent_tree.open()


func _open_save_from_pause(save_mode: String) -> void:
	_pause_menu.visible = false
	save_menu.open(save_mode)


func _open_coop_from_pause() -> void:
	_pause_menu.visible = false
	coop_menu.open_host()


func _open_options_from_pause() -> void:
	_pause_menu.visible = false
	options.open()


## Retour au menu pause après les options (le jeu reste en pause).
func _on_options_closed() -> void:
	if get_tree().paused:
		_pause_menu.visible = true


func _open_sheet_from_pause() -> void:
	_pause_menu.visible = false
	sheet.toggle()


func _to_main_menu() -> void:
	GameState.save_game()
	Net.leave()
	Router.go_to(Router.MAIN_MENU)


func _on_hero_died() -> void:
	await get_tree().create_timer(1.2).timeout
	if _kills_label != null:
		_death_recap.text = recap_text()
	_death_screen.visible = true
	_death_screen.modulate.a = 0.0
	create_tween().tween_property(_death_screen, "modulate:a", 1.0, 0.8)
	get_tree().paused = true


func _revive() -> void:
	GameState.apply_death_penalty()
	GameState.location = {"scene": Router.TAVERN}
	GameState.flags["in_dungeon"] = true
	GameState.save_game()
	Router.go_to(Router.TAVERN)


## Met à jour les emplacements 4 à 7 selon les talents actifs assignés.
func _refresh_talent_slots() -> void:
	_talent_slot_of.clear()
	for i in TalentDB.SLOT_COUNT:
		var key := "tslot_%d" % i
		var slot: Dictionary = _slots[key]
		var id: String = GameState.spell_slots[i]
		var name_label: Label = slot["name"]
		var extra: Label = slot["extra"]
		var panel: Panel = slot["panel"]
		if id.is_empty():
			name_label.text = "—"
			name_label.add_theme_color_override("font_color", Color(0.45, 0.45, 0.45))
			extra.text = ""
			slot["cost"] = 0.0
			panel.add_theme_stylebox_override("panel", UiStyle.box(Color(0.07, 0.05, 0.05, 0.7), Color(0.25, 0.22, 0.2), 2))
			continue
		var t := TalentDB.get_talent(id)
		var color: Color = TalentDB.branch_of(id).get("color", Color.WHITE)
		name_label.text = str(t.get("name", id)).replace(" ", "\n")
		name_label.add_theme_color_override("font_color", color)
		slot["cost"] = float(t.get("cost", 0.0))
		extra.text = "%d dB" % roundi(float(slot["cost"]))
		panel.add_theme_stylebox_override("panel", UiStyle.box(Color(0.07, 0.05, 0.05, 0.92), color.darkened(0.3), 2))
		_talent_slot_of[id] = key


# --- Donjon : compteur de victimes et récapitulatif -----------------------------------

## Compteur de victimes affiché sous la barre de vie du boss (donjons uniquement).
func show_kill_counter() -> void:
	if _kills_label != null:
		return
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 150)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(panel)
	_kills_label = UiStyle.label("", 18, Color(1.0, 0.75, 0.6))
	panel.add_child(_kills_label)
	Events.run_stats_changed.connect(_refresh_kills)
	_refresh_kills()


func _refresh_kills() -> void:
	if _kills_label != null:
		_kills_label.text = "☠ Victimes : %d" % int(GameState.run.get("kills", 0))


## Texte du récapitulatif : victimes, dégâts infligés / subis / évités, durée.
static func recap_text() -> String:
	var r := GameState.run
	var secs := GameState.run_seconds()
	return "\n".join(PackedStringArray([
		"Ennemis vaincus : %d" % int(r.get("kills", 0)),
		"Dégâts infligés : %d" % int(r.get("dealt", 0)),
		"Dégâts subis : %d" % int(r.get("taken", 0)),
		"Dégâts évités (esquives, glissades, boucliers, solos) : %d" % int(r.get("avoided", 0)),
		"Durée : %d min %02d s" % [floori(secs / 60.0), secs % 60],
	]))


## Fenêtre de fin de donjon ; `on_continue` est appelé par le bouton « Continuer ».
func show_recap(title: String, on_continue: Callable) -> void:
	if _recap != null:
		return
	get_tree().paused = true
	_recap = PanelContainer.new()
	_recap.anchor_left = 0.5
	_recap.anchor_right = 0.5
	_recap.anchor_top = 0.5
	_recap.anchor_bottom = 0.5
	_recap.offset_left = -300
	_recap.offset_right = 300
	_recap.offset_top = -190
	_recap.offset_bottom = 190
	_root.add_child(_recap)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	_recap.add_child(vb)
	var t := UiStyle.label(title, 32, Color(1.0, 0.8, 0.45))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	var sub := UiStyle.label("Récapitulatif du donjon", 18, UiStyle.DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(sub)
	var body := UiStyle.label(recap_text(), 20, UiStyle.BONE)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(body)
	var b := Button.new()
	b.text = "Continuer"
	b.custom_minimum_size = Vector2(0, 44)
	b.pressed.connect(_close_recap.bind(on_continue))
	vb.add_child(b)
	b.grab_focus()


func _close_recap(on_continue: Callable) -> void:
	if on_continue.is_valid():
		on_continue.call()


func is_recap_open() -> bool:
	return _recap != null


# --- Coopération -------------------------------------------------------------------------

func _refresh_coop() -> void:
	if not Net.is_online():
		_coop_label.text = ""
		return
	var n := Net.player_count()
	if Net.is_host():
		_coop_label.text = "Coop %d/%d  •  code : %s" % [n, Net.MAX_PLAYERS, Net.code if not Net.code.is_empty() else "…"]
	else:
		_coop_label.text = "Coop %d/%d  •  partie d'un ami" % [n, Net.MAX_PLAYERS]
	if n > 1:
		_coop_label.text += "  •  ennemis +%d %%, PV +%d %%" % [
			roundi((Balance.coop_enemy_count_mult(n) - 1.0) * 100.0), roundi((Balance.coop_enemy_hp_mult(n) - 1.0) * 100.0)]


func _on_coop_code(code: String, _note: String) -> void:
	_refresh_coop()
	Events.notify("Partie ouverte ! Code d'invitation : %s (Échap → Coopération pour le copier)" % code, Events.COLOR_GOLD)
