extends Node
## Déclare les actions d'entrée au démarrage, en touches PHYSIQUES :
## ZQSD (AZERTY) et WASD (QWERTY) fonctionnent sans aucune configuration.
## Les touches affichées à l'écran utilisent la disposition réelle du clavier.

const KEY_ACTIONS := {
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"attack": [], # clic gauche (ajouté plus bas)
	"dash": [KEY_SPACE], # Glissade sur les genoux
	"spell_riff": [], # clic droit (ajouté plus bas) : Riff électrique (FIREBALL, Riff black metal)
	"spell_tuning": [KEY_1, KEY_KP_1], # Accordage de cordes (mini-jeu)
	"spell_wave": [KEY_2, KEY_KP_2],
	"spell_solo": [KEY_3, KEY_KP_3],
	"potion": [KEY_R],
	"interact": [KEY_E],
	"character_sheet": [KEY_C],
	"inventory": [KEY_B],
	"talents": [KEY_K],
	"town_portal": [KEY_T], # Portail de retour en ville (donjon)
	"talent_1": [KEY_4, KEY_KP_4],
	"talent_2": [KEY_5, KEY_KP_5],
	"talent_3": [KEY_6, KEY_KP_6],
	"talent_4": [KEY_7, KEY_KP_7],
	"pause": [KEY_ESCAPE],
	# Mini-jeu du solo (façon Guitar Hero) : touches 1 2 3 4 (rangée du haut ou pavé numérique).
	# Pendant le solo, ces touches sont réservées au mini-jeu (elles ne lancent pas de sort).
	"solo_lane_0": [KEY_1, KEY_KP_1],
	"solo_lane_1": [KEY_2, KEY_KP_2],
	"solo_lane_2": [KEY_3, KEY_KP_3],
	"solo_lane_3": [KEY_4, KEY_KP_4],
}


func _ready() -> void:
	for action: String in KEY_ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		for code: int in KEY_ACTIONS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = code as Key
			InputMap.action_add_event(action, ev)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("attack", click)
	var right_click := InputEventMouseButton.new()
	right_click.button_index = MOUSE_BUTTON_RIGHT
	InputMap.action_add_event("spell_riff", right_click)


## Libellé de la première touche clavier associée à une action,
## traduit selon la disposition du clavier (ex. « Z » sur AZERTY pour move_up).
func key_label(action: String) -> String:
	if not InputMap.has_action(action):
		return "?"
	for ev: InputEvent in InputMap.action_get_events(action):
		var mouse_ev := ev as InputEventMouseButton
		if mouse_ev != null:
			return "Clic D" if mouse_ev.button_index == MOUSE_BUTTON_RIGHT else "Clic G"
		var key_ev := ev as InputEventKey
		if key_ev == null:
			continue
		if key_ev.physical_keycode >= KEY_0 and key_ev.physical_keycode <= KEY_9:
			return str(key_ev.physical_keycode - KEY_0) # chiffres : même sur AZERTY on affiche « 1 », pas « & »
		var logical: Key = key_ev.physical_keycode
		if DisplayServer.get_name() != "headless":
			logical = DisplayServer.keyboard_get_keycode_from_physical(key_ev.physical_keycode)
		var label := OS.get_keycode_string(logical)
		if label == "Space":
			return "Espace"
		return label
	return "?"
