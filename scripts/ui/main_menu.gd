extends Control
## Écran titre : Nouvelle partie / Continuer (le héros actuel) / Mes héros / Charger / Héberger / Rejoindre (coop) /
## Contrôles / Options / Quitter.

var _flash: ColorRect
var _controls_panel: PanelContainer
var _options: OptionsMenu
var _saves: SaveMenu
## « Mes héros » ; « Continuer » et « Héberger » portent le nom du héros actuel.
var _roster: HeroRoster
var _cont: Button
var _host_button: Button
var _coop: CoopMenu


func _ready() -> void:
	theme = UiStyle.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.02, 0.025)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_flash = ColorRect.new()
	_flash.color = Color(0.7, 0.8, 1.0, 0.0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)

	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vb.offset_left = -320
	vb.offset_right = 320
	vb.offset_top = -350
	vb.offset_bottom = 350
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 14)
	add_child(vb)
	var title := UiStyle.label("METAL BARD", 88, Color(0.85, 0.2, 0.12))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_constant_override("outline_size", 14)
	vb.add_child(title)
	var sub := UiStyle.label("La Ballade du Hibours", 26, UiStyle.BONE)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(sub)
	var tag := UiStyle.label("Un luth électrique. Trois sorts. Une armée de squelettes.", 16, UiStyle.DIM)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(tag)
	vb.add_child(Control.new())

	var new_game := _button("Nouvelle partie", _on_new_game)
	vb.add_child(new_game)
	_cont = _button("Continuer", _on_continue)
	vb.add_child(_cont)
	vb.add_child(_button("Mes héros", func() -> void: _roster.open()))
	var load_button := _button("Charger", func() -> void: _saves.open("load"))
	var any_save := false
	for slot in range(0, GameState.SAVE_SLOTS + 1):
		any_save = any_save or GameState.has_slot(slot)
	load_button.disabled = not any_save
	vb.add_child(load_button)
	_host_button = _button("Héberger une partie (coop, 6 joueurs)", _on_host)
	vb.add_child(_host_button)
	vb.add_child(_button("Rejoindre une partie (coop)", func() -> void: _coop.open_join()))
	vb.add_child(_button("Contrôles", func() -> void: _controls_panel.visible = not _controls_panel.visible))
	vb.add_child(_button("Options", func() -> void: _options.open()))
	vb.add_child(_button("Quitter", func() -> void: get_tree().quit()))
	_refresh_hero()
	(_cont if not _cont.disabled else new_game).grab_focus()

	_controls_panel = PanelContainer.new()
	_controls_panel.anchor_left = 1.0
	_controls_panel.anchor_right = 1.0
	_controls_panel.anchor_top = 0.5
	_controls_panel.anchor_bottom = 0.5
	_controls_panel.offset_left = -440
	_controls_panel.offset_right = -30
	_controls_panel.offset_top = -210
	_controls_panel.offset_bottom = 210
	add_child(_controls_panel)
	var help := UiStyle.label("\n".join(PackedStringArray([
		"CONTRÔLES",
		"",
		"Souris : viser   •   Molette : zoom",
		"Clic gauche : aller là (maintenu : suivre la souris), frapper un ennemi, parler / interagir",
		"Maj + clic gauche : frapper sur place",
		"Espace : Glissade sur les genoux (5 m, esquive tout, recharge 20 s)",
		"Clic droit : Riff électrique (un éclair par clic ; maintenu, toutes les 0,30 s)",
		"%s : Accordage de cordes (arc électrique, jusqu'à 5 cibles)" % Controls.key_label("spell_tuning"),
		"%s : Onde de choc sonore (zone)" % Controls.key_label("spell_wave"),
		"%s : Solo de la Foudre (mini-jeu)" % Controls.key_label("spell_solo"),
		"   → mini-jeu : touches 1 2 3 4 (invincible)",
		"%s : boire une potion" % Controls.key_label("potion"),
		"%s : parler / interagir" % Controls.key_label("interact"),
		"%s : fiche de personnage" % Controls.key_label("character_sheet"),
		"%s : arbre de talents" % Controls.key_label("talents"),
		"%s : portail de retour à la taverne (donjon)" % Controls.key_label("town_portal"),
		"Échap : pause",
	])), 17)
	_controls_panel.add_child(help)
	_controls_panel.visible = false

	var credits := UiStyle.label("Alpha v%s — Godot 4.7" % ProjectSettings.get_setting("application/config/version", "?"), 13, UiStyle.DIM)
	credits.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	credits.offset_left = 16
	credits.offset_top = -30
	add_child(credits)
	_options = OptionsMenu.new()
	add_child(_options)
	_saves = SaveMenu.new()
	add_child(_saves)
	_roster = HeroRoster.new()
	add_child(_roster)
	_roster.changed.connect(_refresh_hero)
	_coop = CoopMenu.new()
	add_child(_coop)
	Sfx.play_storm_music() # orage (lightning_menu.mp3) : les éclairs tombent sur ses coups de tonnerre
	Sfx.music_strike.connect(_on_strike)


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 48)
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(cb)
	return b


func _process(delta: float) -> void:
	_flash.color.a = maxf(0.0, _flash.color.a - delta * 1.5)


## Coup de tonnerre dans la musique : éclair à l'écran.
func _on_strike(force: float) -> void:
	_flash.color.a = 0.2 + 0.4 * force


func _on_new_game() -> void:
	GameState.new_game()
	Router.go_to(Router.CHARACTER_CREATION)


## Reprend la dernière partie et l'ouvre aussitôt aux amis (le code s'affiche en jeu).
func _on_host() -> void:
	if not GameState.load_game():
		return
	var err := Net.host()
	if not err.is_empty():
		Events.notify(err, Events.COLOR_BAD)
		return
	Router.go_to(GameState.resume_scene())


func _on_continue() -> void:
	if GameState.load_game():
		Router.go_to(GameState.resume_scene())


## Le héros actuel (Continuer, Héberger, Rejoindre) : son nom sur les boutons.
func _refresh_hero() -> void:
	var has := GameState.has_save()
	var current := GameState.current_hero_id()
	var hero_name := ""
	for h: Dictionary in GameState.heroes():
		if str(h["id"]) == current:
			hero_name = str(h["name"])
	_cont.text = "Continuer — %s" % hero_name if has and not hero_name.is_empty() else "Continuer"
	_cont.disabled = not has
	_host_button.disabled = not has
