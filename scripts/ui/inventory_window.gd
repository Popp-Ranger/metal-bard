class_name InventoryWindow
extends PanelContainer
## Inventaire (touche [B]), façon MMO :
##   • à gauche, le sac : une grille de petites cases, chaque objet est une icône carrée (ItemIcon) ; sous le sac, les
##     potions et les médiators ;
##   • au centre (donc au centre de l'écran), le héros en gros plan, de la tête aux pieds, avec la guitare équipée (un
##     cliqué-glissé le fait pivoter), entouré de ses 12 emplacements d'équipement (le seul à donner ses bonus) ;
##   • à droite, les bonus de l'équipement et les objets de quête.
## En passant la souris sur un objet, une bulle d'info s'affiche sous le curseur : nom (couleur de rareté), rareté et
## emplacement, bonus, effet sur les sorts, description, prix de revente, et ce que fait un clic.
## Clic (gauche ou droit) : équiper un objet du sac, retirer un objet porté, jouer la partition maudite.
## Chez Grokk (« Vendre ou racheter de l'équipement »), il s'ouvre en boutique : un clic sur un objet du sac le vend
## quelques médiators selon sa rareté (on ne vend pas ce qu'on porte), et à droite, les 10 derniers vendus peuvent être
## rachetés au même prix.
## Le jeu ne se met pas en pause ; le héros reste immobile tant que la fenêtre est ouverte (InventoryWindow.active).

static var active := false
var shop := false
var _content: VBoxContainer
## Aperçu 3D du héros (son propre petit monde : lumières, caméra).
var preview: SubViewportContainer
var preview_model: HeroModel
var _preview_cam: Camera3D
var _dragging := false
const PREVIEW_SIZE := Vector2(300, 520)
## Rotation du héros par pixel glissé (rad).
const DRAG_TURN := 0.012
## Sac : 6 colonnes, au moins 8 rangées (d'autres s'ajoutent s'il déborde).
const BAG_COLUMNS := 6
const BAG_ROWS := 8
## Emplacements d'équipement autour du héros : à sa droite (à gauche de l'écran) et à sa gauche.
const EQUIP_LEFT := ["tete", "cou", "torse", "poignets", "ceinture", "pieds"]
const EQUIP_RIGHT := ["guitare", "anneau", "talisman", "mediator", "cordes", "grimoire"]
## Largeur des colonnes du sac et de droite (égales : le héros reste au milieu de la fenêtre).
const SIDE_WIDTH := 344.0
## Bulle d'info (sous le curseur) et la case survolée.
var tip: PanelContainer
var _tip_box: VBoxContainer
var _tip_slot: InventorySlot
## Cases de la dernière mise à jour (tests) : objets du sac, emplacements d'équipement.
var bag_slots: Array[InventorySlot] = []
var worn_slots: Array[InventorySlot] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.5
	anchor_bottom = 0.5
	offset_left = -590
	offset_right = 590
	offset_top = -340
	offset_bottom = 340
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 8)
	add_child(_content)
	_build_preview()
	_build_tip()
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
	_hide_tip()


func _exit_tree() -> void:
	if visible:
		active = false
	if preview != null and preview.get_parent() == null:
		preview.free() # aperçu détaché : libéré avec la fenêtre


func _process(_delta: float) -> void:
	if tip.visible:
		_place_tip()


func _refresh() -> void:
	if not visible:
		return
	_hide_tip()
	if preview.get_parent() != null:
		preview.get_parent().remove_child(preview) # l'aperçu 3D est gardé d'une fois sur l'autre
	for c in _content.get_children():
		_content.remove_child(c)
		c.queue_free()
	bag_slots.clear()
	worn_slots.clear()
	var title := "Échoppe de Grokk — cliquer sur un objet du sac pour le vendre" if shop else "Inventaire"
	_content.add_child(UiStyle.label(title, 26, Color(1.0, 0.8, 0.45)))
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 14)
	_content.add_child(columns)
	# Le sac.
	var bag := _column(columns, "Sac (%d)" % GameState.inventory.size())
	var grid := _grid(bag)
	var cells := maxi(BAG_COLUMNS * BAG_ROWS, ceili(GameState.inventory.size() / float(BAG_COLUMNS)) * BAG_COLUMNS)
	for i in cells:
		var s := _slot(grid, GameState.inventory[i] if i < GameState.inventory.size() else "", "", "sell" if shop else "bag")
		if not s.item_id.is_empty():
			bag_slots.append(s)
	var purse := HBoxContainer.new()
	purse.add_theme_constant_override("separation", 10)
	bag.add_child(purse)
	_slot(purse, "potion" if GameState.potions > 0 else "", "", "potion", GameState.potions)
	purse.add_child(UiStyle.label("Potions : %d\nMédiators : %d" % [GameState.potions, GameState.gold], 16, Color(1.0, 0.82, 0.4)))
	# Le héros au centre, entre ses emplacements d'équipement.
	columns.add_child(_equip_column(EQUIP_LEFT))
	preview.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	columns.add_child(preview)
	preview_model.set_guitar_model(GameState.guitar_model())
	columns.add_child(_equip_column(EQUIP_RIGHT))
	# À droite : bonus et objets de quête, ou le rachat chez Grokk.
	if shop:
		var back := _column(columns, "Rachat — %d dernières ventes" % GameState.BUYBACK_MAX)
		var back_grid := _grid(back)
		for i in BAG_COLUMNS * 2:
			_slot(back_grid, GameState.buyback[i] if i < GameState.buyback.size() else "", "", "buyback")
		var info := UiStyle.label("Cliquer sur un objet vendu pour le racheter au même prix.", 14, UiStyle.DIM)
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		back.add_child(info)
	else:
		var side := _column(columns, "Bonus de l'équipement")
		var total := {}
		for id: String in GameState.equipment.values():
			var bonus: Dictionary = ItemDB.active_bonus(id)
			for ab: String in bonus:
				total[ab] = int(total.get(ab, 0)) + int(bonus[ab])
		if total.is_empty():
			side.add_child(UiStyle.label("(aucun)", 15, UiStyle.DIM))
		for ab: String in ["FOR", "DEX", "CON", "INT", "SAG", "CHA"]:
			if total.has(ab):
				side.add_child(UiStyle.label("%s +%d" % [ab, int(total[ab])], 17, Color(0.6, 0.95, 0.6)))
		side.add_child(HSeparator.new())
		side.add_child(UiStyle.label("Objets de quête", 19, Color(1.0, 0.8, 0.45)))
		var quest_grid := _grid(side)
		for i in maxi(BAG_COLUMNS, GameState.quest_items.size()):
			_slot(quest_grid, GameState.quest_items[i] if i < GameState.quest_items.size() else "", "", "quest")
		side.add_child(HSeparator.new())
		var hint := UiStyle.label("Clic sur un objet du sac : l'équiper. Clic sur un objet porté : le retirer.\nGrokk, à la Chèvre Fringante, rachète l'équipement du sac contre quelques médiators.", 14, UiStyle.DIM)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		side.add_child(hint)
	var close_btn := Button.new()
	close_btn.text = "Fermer [%s]" % ("Échap" if shop else Controls.key_label("inventory"))
	close_btn.pressed.connect(close)
	_content.add_child(close_btn)


func _column(parent: Control, title: String) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(SIDE_WIDTH, 0)
	col.add_theme_constant_override("separation", 6)
	parent.add_child(col)
	col.add_child(UiStyle.label(title, 19, Color(1.0, 0.8, 0.45)))
	return col


func _grid(parent: Control) -> GridContainer:
	var g := GridContainer.new()
	g.columns = BAG_COLUMNS
	g.add_theme_constant_override("h_separation", 4)
	g.add_theme_constant_override("v_separation", 4)
	parent.add_child(g)
	return g


## Colonne de 6 emplacements d'équipement (objet porté, ou silhouette de l'emplacement vide).
func _equip_column(slots: Array) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 12)
	for slot: String in slots:
		worn_slots.append(_slot(col, str(GameState.equipment.get(slot, "")), slot, "worn"))
	return col


## Une case : `role` = "bag" (sac), "sell" (sac, chez Grokk), "worn" (porté), "buyback" (rachat), "quest", "potion".
func _slot(parent: Control, id: String, equip_slot: String, role: String, amount: int = 0) -> InventorySlot:
	var s := InventorySlot.make(id, equip_slot, amount)
	s.set_meta("role", role)
	s.activated.connect(_on_slot_activated)
	s.hovered.connect(_on_slot_hovered)
	parent.add_child(s)
	return s


func _on_slot_activated(s: InventorySlot) -> void:
	var id := s.item_id
	match str(s.get_meta("role", "")):
		"bag":
			_equip(id)
		"sell":
			_sell(id)
		"worn":
			_unequip(s.equip_slot)
		"buyback":
			_buy(id)
		"quest":
			if id == "partition_maudite":
				_play_partition()
			return
		_:
			return
	_refresh()


# --- Bulle d'info -------------------------------------------------------------------------

func _build_tip() -> void:
	tip = PanelContainer.new()
	tip.top_level = true
	tip.z_index = 100
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := UiStyle.box(Color(0.04, 0.03, 0.03, 0.96), UiStyle.BORDER, 2, 4)
	bg.content_margin_left = 12
	bg.content_margin_right = 12
	bg.content_margin_top = 8
	bg.content_margin_bottom = 8
	tip.add_theme_stylebox_override("panel", bg)
	_tip_box = VBoxContainer.new()
	_tip_box.add_theme_constant_override("separation", 3)
	_tip_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip.add_child(_tip_box)
	tip.visible = false
	add_child(tip)


func _on_slot_hovered(s: InventorySlot, inside: bool) -> void:
	if not inside:
		if _tip_slot == s:
			_hide_tip()
		return
	if s.item_id.is_empty() and s.equip_slot.is_empty():
		_hide_tip()
		return
	_show_tip(s)


func _hide_tip() -> void:
	_tip_slot = null
	if tip != null:
		tip.visible = false


## Remplit la bulle d'info de la case `s` et l'affiche sous le curseur.
func _show_tip(s: InventorySlot) -> void:
	_tip_slot = s
	for c in _tip_box.get_children():
		_tip_box.remove_child(c)
		c.free()
	var id := s.item_id
	var role := str(s.get_meta("role", ""))
	if id.is_empty():
		_tip_line(ItemDB.slot_name(s.equip_slot), 18, UiStyle.BONE)
		_tip_line("Emplacement vide", 14, UiStyle.DIM)
	elif role == "potion":
		var potion: Dictionary = (ItemDB.data().get("consommables", {}) as Dictionary).get("potion_soin", {})
		_tip_line(str(potion.get("nom", "Potion de soin")), 20, Color(1.0, 0.45, 0.4))
		_tip_line("Consommable — %d en réserve" % GameState.potions, 14, UiStyle.DIM)
		_tip_line(str(potion.get("desc", "")), 14, UiStyle.DIM, true)
		_tip_line("Touche %s : boire une potion" % Controls.key_label("potion"), 13, Color(0.75, 0.75, 0.7))
	elif role == "quest":
		var q := ItemDB.quest_item(id)
		_tip_line(str(q.get("nom", id)), 20, Color(1.0, 0.85, 0.4))
		_tip_line("Objet de quête", 14, UiStyle.DIM)
		_tip_line(str(q.get("desc", "")), 14, UiStyle.DIM, true)
		if id == "partition_maudite":
			_tip_line("Clic : jouer la partition (à vos risques et périls)", 13, Color(0.75, 0.75, 0.7))
	else:
		var item := ItemDB.get_item(id)
		var rarity := str(item.get("rarity", "commun"))
		_tip_line(str(item.get("name", id)), 20, ItemDB.color_of(id))
		_tip_line("%s — %s" % [rarity.capitalize(), ItemDB.slot_name(ItemDB.slot_of(id))], 14, UiStyle.DIM)
		if role == "worn":
			_tip_line("Équipé", 14, Color(0.6, 0.85, 1.0))
		if not bool(item.get("enabled", true)):
			_tip_line("Désactivé : ne donne plus rien", 15, Color(1.0, 0.4, 0.35))
		var bonus: Dictionary = item.get("bonus", {})
		for ab: String in bonus:
			_tip_line("+%d %s" % [int(bonus[ab]), ab], 16, Color(0.6, 0.95, 0.6))
		var variant := ItemDB.riff_variant(id)
		if not variant.is_empty():
			var style := ItemDB.riff_style(variant)
			_tip_line("Le Riff électrique devient %s" % str(style.get("name", variant)), 15, style.get("color", Color.WHITE), true)
		_tip_line(str(item.get("desc", "")), 14, UiStyle.DIM, true)
		var price := ItemDB.sell_price(id)
		_tip_line("Revente : %d médiator%s" % [price, "s" if price > 1 else ""], 13, Color(1.0, 0.82, 0.4))
		match role:
			"bag":
				_tip_line("Clic : équiper", 13, Color(0.75, 0.75, 0.7))
			"worn":
				_tip_line("Clic : retirer", 13, Color(0.75, 0.75, 0.7))
			"sell":
				_tip_line("Clic : vendre à Grokk (%d)" % price, 13, Color(0.75, 0.75, 0.7))
			"buyback":
				if GameState.gold >= price and not GameState.owns(id):
					_tip_line("Clic : racheter (%d)" % price, 13, Color(0.75, 0.75, 0.7))
				else:
					_tip_line("Rachat impossible (pas assez de médiators, ou déjà possédé)", 13, Color(1.0, 0.4, 0.35), true)
	tip.reset_size()
	tip.visible = true
	_place_tip()


func _tip_line(text: String, font_size: int, color: Color, wrap: bool = false) -> void:
	if text.is_empty():
		return
	var l := UiStyle.label(text, font_size, color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(280, 0)
	_tip_box.add_child(l)


## La bulle se place sous le curseur, sans sortir de l'écran.
func _place_tip() -> void:
	var vp := get_viewport_rect().size
	var m := get_global_mouse_position()
	var pos := m + Vector2(-tip.size.x * 0.5, 26.0)
	if pos.y + tip.size.y > vp.y:
		pos.y = m.y - tip.size.y - 12.0 # en bas de l'écran : au-dessus du curseur
	pos.x = clampf(pos.x, 4.0, maxf(4.0, vp.x - tip.size.x - 4.0))
	tip.global_position = pos


# --- Actions -------------------------------------------------------------------------------

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
