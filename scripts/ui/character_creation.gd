extends Node3D
## Création du personnage (après « Nouvelle partie ») : héros prédéfini (Riffald) ou
## personnage personnalisé : nom, sexe, race, cornes (démon),
## défenses (orc, troll, ogre), barbe (hommes), coiffure longue, couleur de cheveux.
## Aperçu 3D sur une petite scène : le modèle tourne, on peut le faire pivoter à la souris.

## Par défaut : Riffald, le héros prédéfini (on peut passer en personnage personnalisé).
var appearance := RaceDB.preset_appearance("riffald")

var _model: HeroModel
var _camera: Camera3D
var _rows: VBoxContainer
var _name_edit: LineEdit
var _info: Label
var _dragging := false
var _spin := 0.0


func _ready() -> void:
	_build_stage()
	_build_ui()
	_refresh()
	Sfx.play_music("res://audio/music/tavern_theme.mp3", -12.0)


# --- Scène 3D -------------------------------------------------------------------

func _build_stage() -> void:
	var we := Visuals.make_environment("tavern")
	we.environment.background_color = Color(0.03, 0.02, 0.025)
	add_child(we)
	# Petite scène de concert : estrade, projecteurs.
	Visuals.cylinder(self, 1.6, 1.7, 0.3, Vector3(0, -0.15, 0), Visuals.mat(Color(0.16, 0.1, 0.06), 0.6), Vector3.ZERO, 40)
	Visuals.torus(self, 1.62, 1.72, Vector3(0, 0.0, 0), Visuals.glow_mat(Color(0.9, 0.25, 0.1), 2.0))
	Visuals.box(self, Vector3(30, 0.1, 30), Vector3(0, -0.35, 0), Visuals.mat(Color(0.03, 0.025, 0.025)))
	var key := SpotLight3D.new()
	key.position = Vector3(1.5, 5.0, 3.5)
	key.light_color = Color(1.0, 0.85, 0.7)
	key.light_energy = 6.0
	key.spot_range = 12.0
	key.spot_angle = 30.0
	key.shadow_enabled = true
	add_child(key)
	key.look_at(Vector3(0, 1.0, 0), Vector3.UP)
	var fill := OmniLight3D.new() # lumière de face douce pour lire le visage
	fill.position = Vector3(0, 2.0, 3.0)
	fill.light_color = Color(1.0, 0.9, 0.8)
	fill.light_energy = 1.2
	fill.omni_range = 8.0
	add_child(fill)
	var rim := SpotLight3D.new()
	rim.position = Vector3(-2.0, 4.0, -3.0)
	rim.light_color = Color(0.6, 0.3, 1.0)
	rim.light_energy = 5.0
	rim.spot_range = 12.0
	rim.spot_angle = 35.0
	add_child(rim)
	rim.look_at(Vector3(0, 1.2, 0), Vector3.UP)
	_camera = Camera3D.new()
	_camera.fov = 32.0
	add_child(_camera)
	_camera.current = true
	add_child(PostFx.new())


func _place_camera() -> void:
	var h := _model.height()
	var dist := 3.2 + h * 1.4
	_camera.position = Vector3(0, h * 0.62, dist)
	_camera.look_at(Vector3(0, h * 0.5, 0), Vector3.UP)
	_camera.h_offset = -dist * 0.22 # le personnage apparaît à droite, le panneau à gauche


func _process(delta: float) -> void:
	if _model != null and not _dragging:
		_spin += delta * 0.4
		_model.rotation.y = sin(_spin) * 0.6


func _unhandled_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		_dragging = mb.pressed
	var motion := event as InputEventMouseMotion
	if motion != null and _dragging and _model != null:
		_model.rotation.y += motion.relative.x * 0.01


# --- Interface --------------------------------------------------------------------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiStyle.theme()
	layer.add_child(root)
	var panel := PanelContainer.new()
	panel.position = Vector2(40, 40)
	panel.custom_minimum_size = Vector2(560, 820)
	var style := UiStyle.box(Color(0.05, 0.04, 0.045, 0.93), UiStyle.BORDER, 3)
	style.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", style)
	root.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)
	vb.add_child(UiStyle.label("CRÉATION DU PERSONNAGE", 30, Color(1.0, 0.8, 0.45)))
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 10)
	var name_label := UiStyle.label("Nom", 19)
	name_label.custom_minimum_size = Vector2(170, 0)
	name_row.add_child(name_label)
	_name_edit = LineEdit.new()
	_name_edit.text = GameState.DEFAULT_NAME
	_name_edit.max_length = 20
	_name_edit.custom_minimum_size = Vector2(300, 36)
	name_row.add_child(_name_edit)
	vb.add_child(name_row)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 6)
	vb.add_child(_rows)
	vb.add_child(HSeparator.new())
	_info = UiStyle.label("", 15)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size = Vector2(520, 150)
	vb.add_child(_info)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	vb.add_child(buttons)
	for entry: Array in [["Aléatoire", _randomize], ["Retour", _back], ["Commencer l'aventure", _confirm]]:
		var b := Button.new()
		b.text = str(entry[0])
		b.custom_minimum_size = Vector2(0, 46)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(entry[1] as Callable)
		buttons.add_child(b)
	var tip := UiStyle.label("Glissez la souris sur le personnage pour le faire pivoter.", 13, UiStyle.DIM)
	tip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	tip.offset_left = -520
	tip.offset_top = -40
	root.add_child(tip)


## Reconstruit les lignes de choix (certaines dépendent de la race et du sexe).
func _refresh() -> void:
	for c in _rows.get_children():
		_rows.remove_child(c)
		c.queue_free()
	var preset := str(appearance.get("preset", ""))
	_rows.add_child(_selector("Héros", ["Riffald (prédéfini)", "Personnalisé"], 0 if preset == "riffald" else 1, _set_hero_mode))
	_name_edit.editable = preset.is_empty()
	if not preset.is_empty():
		var p: Dictionary = RaceDB.PRESETS[preset]
		_name_edit.text = str(p["name"])
		var desc := UiStyle.label("%s
%s" % [p["title"], p["desc"]], 16, Color(0.9, 0.82, 0.7))
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size = Vector2(520, 0)
		_rows.add_child(desc)
		_update_info()
		_update_model()
		return
	var race_id := str(appearance["race"])
	var race := RaceDB.get_race(race_id)
	_rows.add_child(_selector("Sexe", ["Homme", "Femme"], 0 if appearance["sex"] == "m" else 1,
		func(i: int) -> void: appearance["sex"] = "m" if i == 0 else "f"))
	var race_names: Array[String] = []
	for id: String in RaceDB.RACE_ORDER:
		var r := RaceDB.get_race(id)
		race_names.append("%s (%s m)" % [r["name"], String.num(float(r["height"]), 1).replace(".", ",")])
	_rows.add_child(_selector("Race", race_names, RaceDB.RACE_ORDER.find(race_id),
		func(i: int) -> void: appearance["race"] = RaceDB.RACE_ORDER[i]))
	if race.get("horns", false):
		_rows.add_child(_option_row("Cornes", RaceDB.HORNS, "horns"))
	if race.get("tusks", false):
		_rows.add_child(_option_row("Défenses", RaceDB.TUSKS, "tusks"))
	if RaceDB.can_have_beard(appearance):
		_rows.add_child(_option_row("Barbe", RaceDB.BEARDS, "beard"))
	_rows.add_child(_option_row("Coiffure", RaceDB.HAIRSTYLES, "hair"))
	_rows.add_child(_option_row("Cheveux", RaceDB.HAIR_COLOR_NAMES, "hair_color"))
	_update_info()
	_update_model()


func _option_row(title: String, options: Array, key: String) -> Control:
	var names: Array[String] = []
	for o: Variant in options:
		names.append(str(o))
	return _selector(title, names, int(appearance[key]), func(i: int) -> void: appearance[key] = i)


## Ligne « Titre   ◀  valeur  ▶ ».
func _selector(title: String, options: Array[String], current: int, on_change: Callable) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label := UiStyle.label(title, 19)
	label.custom_minimum_size = Vector2(170, 0)
	row.add_child(label)
	var prev := Button.new()
	prev.text = "◀"
	prev.custom_minimum_size = Vector2(40, 36)
	row.add_child(prev)
	var value := UiStyle.label(options[current], 18, Color(1.0, 0.85, 0.55))
	value.custom_minimum_size = Vector2(250, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(value)
	var next := Button.new()
	next.text = "▶"
	next.custom_minimum_size = Vector2(40, 36)
	row.add_child(next)
	var change := func(step: int) -> void:
		on_change.call(posmod(current + step, options.size()))
		Sfx.play("coin", -16.0)
		_refresh.call_deferred()
	prev.pressed.connect(change.bind(-1))
	next.pressed.connect(change.bind(1))
	return row


func _update_info() -> void:
	var race_id := str(appearance["race"])
	var race := RaceDB.get_race(race_id)
	var bonus: Dictionary = race.get("bonus", {})
	var parts: PackedStringArray = []
	for ab: String in CharacterStats.ABILITIES:
		if bonus.has(ab):
			parts.append("%s %+d" % [ab, int(bonus[ab])])
	_info.text = "%s — %s m\nBonus de caractéristiques : %s\nTrait racial : %s\n\nClasse : Barde (Charisme, Flying V électrique). Vous choisirez vos talents dans l'arbre (touche %s)." % [
		RaceDB.title(appearance), String.num(float(race["height"]), 1).replace(".", ","), ", ".join(parts),
		race.get("trait", ""), Controls.key_label("talents")]


func _update_model() -> void:
	if _model == null:
		_model = HeroModel.new()
		_model.appearance = appearance.duplicate()
		add_child(_model)
	else:
		_model.set_appearance(appearance)
	_place_camera()


## « Héros » : 0 = Riffald prédéfini, 1 = personnage personnalisé (part de l'apparence actuelle).
func _set_hero_mode(i: int) -> void:
	if i == 0:
		appearance = RaceDB.preset_appearance("riffald")
	else:
		appearance["preset"] = ""


func _randomize() -> void:
	appearance["preset"] = ""
	appearance["sex"] = ["m", "f"].pick_random()
	appearance["race"] = RaceDB.RACE_ORDER.pick_random()
	appearance["horns"] = randi_range(0, RaceDB.HORNS.size() - 1)
	appearance["tusks"] = randi_range(0, RaceDB.TUSKS.size() - 1)
	appearance["beard"] = randi_range(0, RaceDB.BEARDS.size() - 1)
	appearance["hair"] = randi_range(0, RaceDB.HAIRSTYLES.size() - 1)
	appearance["hair_color"] = randi_range(0, RaceDB.HAIR_COLORS.size() - 1)
	_refresh()


func _back() -> void:
	Router.go_to(Router.MAIN_MENU)


func _confirm() -> void:
	var hero_name := _name_edit.text.strip_edges()
	GameState.hero_name = hero_name if not hero_name.is_empty() else GameState.DEFAULT_NAME
	GameState.appearance = appearance.duplicate()
	GameState.hp = GameState.max_hp()
	GameState.mana = GameState.max_mana()
	GameState.save_game()
	Sfx.play("levelup", -4.0, 0.0)
	Router.go_to(Router.INTRO) # la partie commence au cimetière, par la nuit de la Lune de Sang
