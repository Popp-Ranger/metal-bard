class_name CharacterSheet
extends PanelContainer
## Fiche de personnage D&D : caractéristiques (+ répartition des points gagnés
## à chaque niveau), statistiques dérivées et équipement, comme dans un MMO : un emplacement par type
## d'objet (tête, cou, torse...), et le sac. Seul l'équipement porté donne ses bonus. Touche [C].

var _content: VBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.5
	anchor_bottom = 0.5
	offset_left = -610
	offset_right = 610
	offset_top = -330
	offset_bottom = 330
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 6)
	add_child(_content)
	visible = false
	Events.stats_changed.connect(_refresh)


func toggle() -> void:
	if visible:
		close()
	else:
		visible = true
		get_tree().paused = true
		_refresh()


func close() -> void:
	visible = false
	get_tree().paused = false


func _refresh() -> void:
	if not visible:
		return
	for c in _content.get_children():
		_content.remove_child(c)
		c.queue_free()
	var s := GameState.stats
	_content.add_child(UiStyle.label("%s, %s" % [GameState.hero_name, GameState.HERO_TITLE], 28, Color(1.0, 0.8, 0.45)))
	_content.add_child(UiStyle.label("%s — Niveau %d   •   XP %d / %d" % [RaceDB.title(GameState.appearance), s.level, s.xp, GameState.next_level_xp()], 18, UiStyle.DIM))
	_content.add_child(UiStyle.label("Trait racial — %s" % RaceDB.get_race(GameState.race()).get("trait", ""), 15, Color(0.75, 0.9, 0.7)))
	_content.add_child(HSeparator.new())

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 22)
	_content.add_child(columns)

	# Caractéristiques.
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(350, 0)
	columns.add_child(left)
	var points_color := Color(1.0, 0.85, 0.3) if s.unspent_points > 0 else UiStyle.DIM
	left.add_child(UiStyle.label("Points à répartir : %d" % s.unspent_points, 18, points_color))
	for ab: String in CharacterStats.ABILITIES:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var total := GameState.ability(ab)
		var m := GameState.mod(ab)
		var name_label := UiStyle.label("%s  %s" % [ab, CharacterStats.NAMES[ab]], 18)
		name_label.custom_minimum_size = Vector2(180, 0)
		name_label.tooltip_text = str(CharacterStats.DESCRIPTIONS[ab])
		name_label.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(name_label)
		var value := UiStyle.label("%d" % total, 20, UiStyle.BONE)
		value.custom_minimum_size = Vector2(40, 0)
		row.add_child(value)
		row.add_child(UiStyle.label("(%s%d)" % ["+" if m >= 0 else "", m], 18, Color(0.6, 0.85, 1.0)))
		var plus := Button.new()
		plus.text = "+"
		plus.custom_minimum_size = Vector2(34, 30)
		plus.disabled = s.unspent_points <= 0 or s.base(ab) >= Balance.ABILITY_CAP
		plus.pressed.connect(_on_plus.bind(ab))
		row.add_child(plus)
		left.add_child(row)
		var desc := UiStyle.label("      " + str(CharacterStats.DESCRIPTIONS[ab]), 13, UiStyle.DIM)
		left.add_child(desc)

	# Statistiques dérivées.
	var middle := VBoxContainer.new()
	middle.custom_minimum_size = Vector2(300, 0)
	columns.add_child(middle)
	middle.add_child(UiStyle.label("Combat", 20, Color(1.0, 0.8, 0.45)))
	for line: String in [
		"Points de vie : %d / %d" % [GameState.hp, GameState.max_hp()],
		"Décibels : %d / %d" % [roundi(GameState.mana), roundi(GameState.max_mana())],
		"Classe d'armure : %d" % GameState.armor_class(),
		"Bonus de maîtrise : +%d" % GameState.proficiency(),
		"DD des sorts : %d" % GameState.spell_dc(),
		"Coup de guitare : 1d%d%+d (touche toujours)" % [Balance.MELEE_DICE, GameState.mod("FOR")],
		"Sorts : %d %% de chances de toucher" % roundi(GameState.spell_hit_chance() * 100.0),
		"Riff électrique : (1d10%+d) × 0,67, 6 m (sans recharge)" % GameState.mod("CHA"),
		"Accordage de cordes : 2d6%+d par note (%d notes, une par cible)" % [GameState.mod("CHA"), Balance.TUNING_MAX_TARGETS + (1 if GameState.has_talent("distorsion") else 0)],
		"Onde de choc : 2d8%+d, headbang %s s" % [GameState.mod("CHA"), String.num(Balance.WAVE_HEADBANG, 2).replace(".", ",")],
		"Solo de la Foudre : 4d10%+d" % GameState.mod("CHA"),
		"Médiators : %d   •   Potions : %d" % [GameState.gold, GameState.potions],
	]:
		middle.add_child(UiStyle.label(line, 15))
	middle.add_child(UiStyle.label("Riff, Solo de la Foudre et solos des talents (mini-jeux) touchent toujours.", 13, UiStyle.DIM))
	for c in middle.get_children():
		if c is Label:
			(c as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# Équipement porté et sac.
	var gear := VBoxContainer.new()
	gear.custom_minimum_size = Vector2(470, 0)
	gear.add_theme_constant_override("separation", 3)
	columns.add_child(gear)
	_build_equipment(gear)

	_content.add_child(HSeparator.new())
	var close_btn := Button.new()
	close_btn.text = "Fermer [%s]" % Controls.key_label("character_sheet")
	close_btn.pressed.connect(close)
	_content.add_child(close_btn)


## Emplacements (clic sur un objet porté : il retourne dans le sac) puis le sac (« Équiper »).
func _build_equipment(gear: VBoxContainer) -> void:
	gear.add_child(UiStyle.label("Équipement", 20, Color(1.0, 0.8, 0.45)))
	for slot: String in ItemDB.SLOTS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var slot_label := UiStyle.label(ItemDB.slot_name(slot), 14, UiStyle.DIM)
		slot_label.custom_minimum_size = Vector2(82, 0)
		row.add_child(slot_label)
		var id := str(GameState.equipment.get(slot, ""))
		var b := Button.new()
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.add_theme_font_size_override("font_size", 14)
		if id.is_empty():
			b.text = "— vide —"
			b.disabled = true
		else:
			var item := ItemDB.get_item(id)
			b.text = "%s  (%s)" % [item.get("name", id), ItemDB.bonus_text(id)]
			b.add_theme_color_override("font_color", ItemDB.color_of(id))
			b.tooltip_text = "%s\n%s\n\nClic : retirer (retourne dans le sac)" % [item.get("name", id), item.get("desc", "")]
			b.pressed.connect(_on_unequip.bind(slot))
		row.add_child(b)
		gear.add_child(row)
	gear.add_child(HSeparator.new())
	gear.add_child(UiStyle.label("Sac (%d)" % GameState.inventory.size(), 18, Color(1.0, 0.8, 0.45)))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 120)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	gear.add_child(scroll)
	var bag := VBoxContainer.new()
	bag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(bag)
	if GameState.inventory.is_empty():
		bag.add_child(UiStyle.label("(vide : fouillez les corps des ennemis)", 14, UiStyle.DIM))
	for id in GameState.inventory:
		var item := ItemDB.get_item(id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var eq := Button.new()
		eq.text = "Équiper"
		eq.add_theme_font_size_override("font_size", 13)
		eq.pressed.connect(_on_equip.bind(id))
		row.add_child(eq)
		var l := UiStyle.label("%s — %s (%s)" % [item.get("name", id), ItemDB.slot_name(ItemDB.slot_of(id)), ItemDB.bonus_text(id)], 14, ItemDB.color_of(id))
		l.tooltip_text = str(item.get("desc", ""))
		l.mouse_filter = Control.MOUSE_FILTER_PASS
		l.clip_text = true
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		bag.add_child(row)


func _on_plus(ab: String) -> void:
	if GameState.spend_point(ab):
		Sfx.play("coin", -10.0)


func _on_equip(id: String) -> void:
	if GameState.equip(id):
		Sfx.play("coin", -8.0, 0.3)


func _on_unequip(slot: String) -> void:
	if GameState.unequip(slot):
		Sfx.play("swoosh", -12.0)
