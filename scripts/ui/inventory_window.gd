class_name InventoryWindow
extends PanelContainer
## Inventaire (touche [B]) : le sac (objets ramassés, à équiper), l'équipement porté (seul à donner ses bonus),
## potions et médiators. Chez Grokk (« Vendre ou racheter de l'équipement »), il s'ouvre en boutique : chaque
## objet du sac se vend quelques médiators selon sa rareté (on ne vend pas ce qu'on porte), et les 10 derniers
## vendus peuvent être rachetés au même prix.
## Le jeu ne se met pas en pause ; le héros reste immobile tant que la fenêtre est ouverte (InventoryWindow.active).

static var active := false
var shop := false
var _content: VBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.5
	anchor_bottom = 0.5
	offset_left = -420
	offset_right = 420
	offset_top = -290
	offset_bottom = 290
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 6)
	add_child(_content)
	visible = false
	Events.stats_changed.connect(_refresh)
	Events.gold_changed.connect(func(_g: int) -> void: _refresh())
	Events.shop_requested.connect(open.bind(true))


func open(as_shop: bool = false) -> void:
	shop = as_shop
	visible = true
	active = true
	Events.interaction_prompt.emit("")
	_refresh()


func toggle() -> void:
	if visible:
		close()
	else:
		open(false)


func close() -> void:
	visible = false
	active = false


func _exit_tree() -> void:
	if visible:
		active = false


func _refresh() -> void:
	if not visible:
		return
	for c in _content.get_children():
		_content.remove_child(c)
		c.queue_free()
	var title := "Échoppe de Grokk — vendre et racheter" if shop else "Inventaire"
	_content.add_child(UiStyle.label(title, 28, Color(1.0, 0.8, 0.45)))
	_content.add_child(UiStyle.label("Médiators : %d   •   Potions de soin : %d" % [GameState.gold, GameState.potions], 17, UiStyle.DIM))
	_content.add_child(HSeparator.new())

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(columns)
	var mine := _column(columns, "Sac (%d)" % GameState.inventory.size())
	if GameState.inventory.is_empty():
		mine.add_child(UiStyle.label("(vide : fouillez les corps des ennemis)", 15, UiStyle.DIM))
	for id in GameState.inventory:
		if shop:
			mine.add_child(_row(id, "Vendre (%d)" % ItemDB.sell_price(id), _sell.bind(id), true))
		else:
			mine.add_child(_row(id, "Équiper", _equip.bind(id), true))
	if shop:
		var back := _column(columns, "Rachat — %d dernières vendues" % GameState.BUYBACK_MAX)
		if GameState.buyback.is_empty():
			back.add_child(UiStyle.label("(rien à racheter)", 15, UiStyle.DIM))
		for id in GameState.buyback:
			var price := ItemDB.sell_price(id)
			var ok := GameState.gold >= price and not GameState.owns(id)
			back.add_child(_row(id, "Racheter (%d)" % price, _buy.bind(id), ok))
	else:
		var worn := _column(columns, "Équipement porté")
		if GameState.equipment.is_empty():
			worn.add_child(UiStyle.label("(rien : équipez un objet du sac)", 15, UiStyle.DIM))
		for slot: String in ItemDB.SLOTS:
			if GameState.equipment.has(slot):
				worn.add_child(_row(str(GameState.equipment[slot]), "Retirer", _unequip.bind(slot), true))
		var hint := worn
		hint.add_child(HSeparator.new())
		hint.add_child(UiStyle.label("Bonus de l'équipement", 17, Color(1.0, 0.8, 0.45)))
		var total := {}
		for id: String in GameState.equipment.values():
			var bonus: Dictionary = ItemDB.active_bonus(id)
			for ab: String in bonus:
				total[ab] = int(total.get(ab, 0)) + int(bonus[ab])
		if total.is_empty():
			hint.add_child(UiStyle.label("(aucun)", 15, UiStyle.DIM))
		for ab: String in ["FOR", "DEX", "CON", "INT", "SAG", "CHA"]:
			if total.has(ab):
				hint.add_child(UiStyle.label("%s +%d" % [ab, int(total[ab])], 17, Color(0.6, 0.95, 0.6)))
		hint.add_child(UiStyle.label("Grokk, à la Chèvre Fringante, rachète l'équipement du sac contre quelques médiators.", 14, UiStyle.DIM))

	_content.add_child(HSeparator.new())
	var close_btn := Button.new()
	close_btn.text = "Fermer [%s]" % ("Échap" if shop else Controls.key_label("inventory"))
	close_btn.pressed.connect(close)
	_content.add_child(close_btn)


func _column(parent: Control, title: String) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 4)
	parent.add_child(col)
	col.add_child(UiStyle.label(title, 19, Color(1.0, 0.8, 0.45)))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 360)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	return list


## Un objet : nom (couleur de rareté), emplacement, bonus et description, avec un bouton facultatif.
func _row(id: String, button_text: String, action: Callable, enabled: bool) -> Control:
	var item := ItemDB.get_item(id)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	text.add_child(UiStyle.label("%s — %s (%s)" % [item.get("name", id), ItemDB.slot_name(ItemDB.slot_of(id)), ItemDB.bonus_text(id)], 16, ItemDB.color_of(id)))
	var desc := UiStyle.label(str(item.get("desc", "")), 13, UiStyle.DIM)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(220, 0)
	text.add_child(desc)
	if not button_text.is_empty():
		var b := Button.new()
		b.text = button_text
		b.disabled = not enabled
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(action)
		row.add_child(b)
	return row


func _equip(id: String) -> void:
	if GameState.equip(id):
		Sfx.play("coin", -8.0, 0.3)


func _unequip(slot: String) -> void:
	if GameState.unequip(slot):
		Sfx.play("swoosh", -12.0)


func _sell(id: String) -> void:
	var price := ItemDB.sell_price(id)
	if GameState.sell_item(id):
		Sfx.play("coin", -4.0)
		Events.notify("%s vendu à Grokk : +%d médiators" % [ItemDB.get_item(id).get("name", id), price], Events.COLOR_GOLD)


func _buy(id: String) -> void:
	if GameState.buy_back(id):
		Sfx.play("coin", -4.0)
		Events.notify("%s racheté." % ItemDB.get_item(id).get("name", id), Events.COLOR_GOOD)
	else:
		Events.notify("Pas assez de médiators.", Events.COLOR_BAD)
