@tool
class_name TavernMap
extends Node3D
## Taverne faite main, à construire dans l'éditeur de Godot (voir docs/EDITEUR_NIVEAUX.md) :
##  - GridMap « Sol » : planchers et dalles, case par case (cases de 1 m) ;
##  - GridMap « Murs » : murs, fenêtres, murets, cloisons, posés sur le bord nord de leur case et tournés
##    avec la touche S (les fenêtres laissent entrer le clair de lune) ;
##  - marqueurs (TavernMarker, n'importe où dans la scène) : mobilier, décor et points du jeu.
## Le rez-de-chaussée, l'étage et le sous-sol sont des zones éloignées de la même scène, reliées par les
## escaliers (« Escalier qui monte / descend » vers une « Arrivée d'escalier »).
## En jeu, tavern.gd charge cette scène et y branche toute la vie de la taverne. F6 sur la scène lance
## directement la taverne pour la tester.

## Tuiles de la GridMap « Murs » (voir tools/levels/build_tavern_assets.gd).
const WALL := 0
const WINDOW := 1
const LOW_WALL := 2
const PARTITION := 3

## Affiche dans la sortie les problèmes qui empêcheraient de jouer cette taverne.
@export_tool_button("Vérifier la taverne") var check_button := _print_check


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if get_tree().current_scene == self:
		_play_test.call_deferred()


func floor_map() -> GridMap:
	return get_node_or_null("Sol") as GridMap


func wall_map() -> GridMap:
	return get_node_or_null("Murs") as GridMap


func markers() -> Array[TavernMarker]:
	var out: Array[TavernMarker] = []
	_collect(self, out)
	return out


func _collect(n: Node, out: Array[TavernMarker]) -> void:
	for c in n.get_children():
		if c is TavernMarker:
			out.append(c as TavernMarker)
		_collect(c, out)


## Premier marqueur d'un type (null s'il n'y en a pas).
func first(kind: int) -> TavernMarker:
	for m in markers():
		if m.kind == kind:
			return m
	return null


func check() -> Array[String]:
	var problems: Array[String] = []
	if floor_map() == null or wall_map() == null:
		problems.append("Il manque les GridMap « Sol » et « Murs » (enfants directs de la taverne).")
	var count := {}
	var npcs := {}
	var rented := 0
	for m in markers():
		count[m.kind] = int(count.get(m.kind, 0)) + 1
		if m.kind == TavernMarker.Kind.PNJ:
			npcs[m.npc] = int(npcs.get(m.npc, 0)) + 1
		if m.kind == TavernMarker.Kind.LIT and m.option:
			rented += 1
		if m.kind in [TavernMarker.Kind.ESCALIER_MONTANT, TavernMarker.Kind.ESCALIER_DESCENDANT]:
			var dest := m.destination_marker()
			if dest == null:
				problems.append("L'escalier « %s » ne mène nulle part (propriété Destination : une « Arrivée d'escalier »)." % m.name)
	for k: int in [TavernMarker.Kind.APPARITION, TavernMarker.Kind.CERCLE_RUNES, TavernMarker.Kind.PORTAIL_BLEU]:
		if int(count.get(k, 0)) != 1:
			problems.append("Il faut exactement un « %s » (il y en a %d)." % [TavernMarker.NAMES[k], int(count.get(k, 0))])
	if int(count.get(TavernMarker.Kind.COMPTOIR, 0)) < 1:
		problems.append("Il faut un comptoir (les clients y vont commander).")
	if int(count.get(TavernMarker.Kind.TABLE, 0)) < 1:
		problems.append("Il faut au moins une table (les clients s'y assoient).")
	if rented != 1:
		problems.append("Il faut exactement un lit loué par le héros (Lit, case Option) ; il y en a %d." % rented)
	for i in TavernMarker.NPCS.size():
		if int(npcs.get(i, 0)) != 1:
			problems.append("Il faut exactement un PNJ « %s » (il y en a %d)." % [TavernMarker.NPC_NAMES[i], int(npcs.get(i, 0))])
	return problems


func _print_check() -> void:
	var problems := check()
	if problems.is_empty():
		print("Taverne « %s » : tout est bon (F6 pour la tester)." % name)
		return
	push_warning("Taverne « %s » : %d problème(s)." % [name, problems.size()])
	for p in problems:
		push_warning(" - " + p)


## F6 dans l'éditeur : nouvelle partie (intro passée) directement dans cette taverne.
## (Autoloads lus par leur chemin : ce script sert aussi aux outils lancés hors du jeu.)
func _play_test() -> void:
	var state := get_node("/root/GameState")
	state.call("new_game")
	(state.get("flags") as Dictionary)["intro_done"] = true
	(state.get("flags") as Dictionary)["test_tavern"] = scene_file_path
	get_tree().change_scene_to_file(str(get_node("/root/Router").get("TAVERN")))
