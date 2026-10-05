class_name InventoryWindow
extends PanelContainer
## Inventaire (touche [B]) : le sac (objets ramassés, à équiper), l'équipement porté (seul à donner ses bonus),
## potions et médiators. Chez Grokk (« Vendre ou racheter de l'équipement »), il s'ouvre en boutique : chaque
## objet du sac se vend quelques médiators selon sa rareté (on ne vend pas ce qu'on porte), et les 10 derniers
## vendus peuvent être rachetés au même prix.
## Au centre de la fenêtre (donc de l'écran), le héros en gros plan, de la tête aux pieds, avec la guitare équipée : un
## cliqué-glissé le fait pivoter.
## Le jeu ne se met pas en pause ; le héros reste immobile tant que la fenêtre est ouverte (InventoryWindow.active).

static var active := false
var shop := false
var _content: VBoxContainer
## Aperçu 3D du héros (son propre petit monde : lumières, caméra).
var preview: SubViewportContainer
var preview_model: HeroModel
var _preview_cam: Camera3D
var _dragging := false
const PREVIEW_SIZE := Vector2(360, 540)
## Rotation du héros par pixel glissé (rad).
const DRAG_TURN := 0.012


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.5
	anchor_bottom = 0.5
	offset_left = -640
	offset_right = 640
	offset_top = -335
	offset_bottom = 335
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 6)
	add_child(_content)
	_build_preview()
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
	if preview != null and preview.get_parent() == null:
		preview.free() # aperçu détaché (boutique) : libéré avec la fenêtre


func _refresh() -> void:
	if not visible:
		return
	if preview.get_parent() != null:
		preview.get_parent().remove_child(preview) # l'aperçu 3D est gardé d'une fois sur l'autre
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
		columns.add_child(preview) # le héros au centre, entre le sac et son équipement
		preview_model.set_guitar_model(GameState.guitar_model())
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
		if not GameState.quest_items.is_empty():
			hint.add_child(HSeparator.new())
			hint.add_child(UiStyle.label("Objets de quête", 17, Color(1.0, 0.8, 0.45)))
			for id in GameState.quest_items:
				hint.add_child(_quest_row(id))

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
	scroll.custom_minimum_size = Vector2(0, 470)
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


## Objet de quête : nom, description ; la partition maudite peut être jouée (à vos risques et périls).
func _quest_row(id: String) -> Control:
	var q := ItemDB.quest_item(id)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	text.add_child(UiStyle.label(str(q.get("nom", id)), 16, Color(1.0, 0.85, 0.4)))
	var desc := UiStyle.label(str(q.get("desc", "")), 13, UiStyle.DIM)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(220, 0)
	text.add_child(desc)
	if id == "partition_maudite":
		var b := Button.new()
		b.text = "Jouer"
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(_play_partition)
		row.add_child(b)
	return row


## Jouer la partition maudite sans le Pick du Destin : la foudre frappe celui qui ose (30 % des PV, jamais mortel).
func _play_partition() -> void:
	close()
	var hero := get_tree().get_first_node_in_group("hero") as Hero
	if hero == null:
		return
	if GameState.quest_items.has("pick_du_destin"):
		# Avec le Pick du Destin, la partition ne foudroie plus... mais le Riff Ultime est réservé à Mèhn-Strïm.
		Sfx.play("note_0", -6.0, 0.0)
		Events.notify("Le Pick du Destin vibre entre vos doigts : la partition s'illumine... Le Riff Ultime attendra Mèhn-Strïm.", Events.COLOR_GOLD)
		return
	var top := hero.global_position + Vector3(0.6, 18.0, -0.6)
	ArcBolt.spawn(hero.get_parent(), top, hero.global_position + Vector3(0, 1.0, 0), 0.45, 0.5, Color(0.8, 0.85, 1.0))
	Sfx.play("solo_thunder", 0.0)
	Events.screen_flash.emit(Color(0.85, 0.9, 1.0, 0.6), 0.35)
	Events.camera_shake.emit(0.4, 0.5)
	hero.take_hit(clampi(roundi(GameState.max_hp() * 0.3), 1, maxi(1, GameState.hp - 1)), hero.global_position)
	Events.notify("Sans le Pick du Destin, la partition vous foudroie ! Back Jlack vous avait prévenu...", Events.COLOR_BAD)


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


# --- Aperçu du héros ----------------------------------------------------------------------

## Le héros (son apparence, sa guitare équipée) dans un petit monde 3D à lui : projecteur, contre-jour, fond transparent
## (le panneau de la fenêtre se voit derrière).
func _build_preview() -> void:
	preview = SubViewportContainer.new()
	preview.stretch = true
	preview.custom_minimum_size = PREVIEW_SIZE
	preview.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	preview.mouse_filter = Control.MOUSE_FILTER_STOP
	preview.mouse_default_cursor_shape = Control.CURSOR_DRAG
	preview.tooltip_text = "Cliquer-glisser pour faire pivoter le personnage"
	preview.gui_input.connect(_on_preview_input)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	preview.add_child(vp)
	var we := WorldEnvironment.new()
	we.environment = Environment.new()
	we.environment.background_mode = Environment.BG_CLEAR_COLOR
	we.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	we.environment.ambient_light_color = Color(0.75, 0.68, 0.62)
	we.environment.ambient_light_energy = 0.55
	we.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment.glow_enabled = true
	vp.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, 25, 0)
	key.light_color = Color(1.0, 0.9, 0.78)
	key.light_energy = 1.5
	vp.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, 160, 0)
	rim.light_color = Color(0.65, 0.4, 1.0)
	rim.light_energy = 1.2
	vp.add_child(rim)
	preview_model = HeroModel.new()
	preview_model.set_guitar_model(GameState.guitar_model())
	vp.add_child(preview_model)
	_preview_cam = Camera3D.new()
	_preview_cam.fov = 30.0
	vp.add_child(_preview_cam)
	_frame_preview()


## Cadrage : le héros entier (de la tête aux pieds, guitare comprise) au milieu de l'image.
func _frame_preview() -> void:
	var h := preview_model.height()
	var reach := h * 0.55 + 0.08 # demi-hauteur à montrer, avec une marge
	var dist := reach / tan(deg_to_rad(_preview_cam.fov * 0.5))
	_preview_cam.transform = Transform3D(Basis.IDENTITY, Vector3(0, h * 0.5, dist)) # de face, à mi-hauteur


## Cliqué-glissé : le héros pivote.
func _on_preview_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		_dragging = mb.pressed
		accept_event()
	var motion := event as InputEventMouseMotion
	if motion != null and _dragging:
		preview_model.rotation.y += motion.relative.x * DRAG_TURN
		accept_event()
