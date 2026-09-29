class_name CharacterSheet
extends PanelContainer
## Fiche de personnage D&D : caractéristiques (+ répartition des points gagnés
## à chaque niveau), statistiques dérivées et reliques. Touche [C].

var _content: VBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.5
	anchor_bottom = 0.5
	offset_left = -380
	offset_right = 380
	offset_top = -300
	offset_bottom = 300
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
	_content.add_child(UiStyle.label("%s, %s" % [GameState.HERO_NAME, GameState.HERO_TITLE], 28, Color(1.0, 0.8, 0.45)))
	_content.add_child(UiStyle.label("Barde humain — Niveau %d   •   XP %d / %d" % [s.level, s.xp, GameState.next_level_xp()], 18, UiStyle.DIM))
	_content.add_child(HSeparator.new())

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 30)
	_content.add_child(columns)

	# Caractéristiques.
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(390, 0)
	columns.add_child(left)
	var points_color := Color(1.0, 0.85, 0.3) if s.unspent_points > 0 else UiStyle.DIM
	left.add_child(UiStyle.label("Points à répartir : %d" % s.unspent_points, 18, points_color))
	for ab: String in CharacterStats.ABILITIES:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var total := GameState.ability(ab)
		var m := GameState.mod(ab)
		var name_label := UiStyle.label("%s  %s" % [ab, CharacterStats.NAMES[ab]], 18)
		name_label.custom_minimum_size = Vector2(190, 0)
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

	# Statistiques dérivées + reliques.
	var right := VBoxContainer.new()
	columns.add_child(right)
	right.add_child(UiStyle.label("Combat", 20, Color(1.0, 0.8, 0.45)))
	for line: String in [
		"Points de vie : %d / %d" % [GameState.hp, GameState.max_hp()],
		"Décibels : %d / %d" % [roundi(GameState.mana), roundi(GameState.max_mana())],
		"Classe d'armure : %d" % GameState.armor_class(),
		"Bonus de maîtrise : +%d" % GameState.proficiency(),
		"DD des sorts : %d" % GameState.spell_dc(),
		"Coup de guitare : 1d8%+d" % GameState.mod("FOR"),
		"Accordage de cordes : 2d6%+d (5 cibles)" % GameState.mod("CHA"),
		"Riff électrique : 1d10%+d (×3 en rythme)" % GameState.mod("CHA"),
		"Onde de choc : 2d8%+d" % GameState.mod("CHA"),
		"Solo de la Foudre : 4d10%+d" % GameState.mod("CHA"),
		"Or : %d po   •   Potions : %d" % [GameState.gold, GameState.potions],
	]:
		right.add_child(UiStyle.label(line, 16))
	right.add_child(HSeparator.new())
	right.add_child(UiStyle.label("Reliques", 20, Color(1.0, 0.8, 0.45)))
	if GameState.inventory.is_empty():
		right.add_child(UiStyle.label("(aucune)", 16, UiStyle.DIM))
	for id in GameState.inventory:
		var item := ItemDB.get_item(id)
		var l := UiStyle.label("• %s (%s)" % [item.get("name", id), ItemDB.bonus_text(id)], 15, ItemDB.color_of(id))
		l.tooltip_text = str(item.get("desc", ""))
		l.mouse_filter = Control.MOUSE_FILTER_PASS
		right.add_child(l)

	_content.add_child(HSeparator.new())
	var close_btn := Button.new()
	close_btn.text = "Fermer [%s]" % Controls.key_label("character_sheet")
	close_btn.pressed.connect(close)
	_content.add_child(close_btn)


func _on_plus(ab: String) -> void:
	if GameState.spend_point(ab):
		Sfx.play("coin", -10.0)
