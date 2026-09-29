extends Node
## Scène « vitrine » scriptée pour produire des captures d'écran (README, vérifications visuelles).
## Utilisation (Movie Maker de Godot) :
##   Godot_v4.7.2-stable_win64_console.exe --path . --write-movie shots/frame.png --fixed-fps 30 res://tests/showcase.tscn
## La scène se ferme toute seule à la fin.

var _dungeon: Node
var _hero: Hero


func _ready() -> void:
	GameState.new_game()
	# 0) Taverne : vue d'ensemble puis dialogue avec Gérald (frames ~0-90).
	var tavern: Level = load("res://scenes/tavern.tscn").instantiate()
	add_child(tavern)
	await _frames(5)
	tavern.hero.global_position = Vector3(-1.5, 0, 2.5)
	tavern.camera.zoom = 17.0
	tavern.camera.snap_to_target()
	await _frames(40) # ≈ frame 45 : vue de la taverne
	Events.dialogue_requested.emit("gerald")
	await _frames(45) # ≈ frame 90 : dialogue
	tavern.hud.dialogue.close()
	GameState.accept_quest("plumeau")
	GameState.run_dialogue_action("portal")
	tavern.hero.global_position = Vector3(5.0, 0, 3.5)
	await _frames(40) # ≈ frame 130 : portail ouvert
	tavern.queue_free()
	await _frames(2)
	GameState.dungeon_seed = 4242
	_dungeon = load("res://scenes/dungeon.tscn").instantiate()
	add_child(_dungeon)
	await _frames(15)
	_hero = get_tree().get_first_node_in_group("hero") as Hero
	var boss: FrogBoss = null
	var skeletons: Array[Enemy] = []
	for n in get_tree().get_nodes_in_group("enemies"):
		if n is FrogBoss:
			boss = n
		elif skeletons.size() < 4:
			skeletons.append(n as Enemy)
	# 1) Combat : squelettes autour du héros, riff électrique puis onde de choc.
	for i in skeletons.size():
		var a := TAU * i / skeletons.size() + 0.3
		skeletons[i].global_position = _hero.global_position + Vector3(cos(a), 0, sin(a)) * (2.5 + i * 0.6)
	await _frames(40) # ≈ frame 55 : squelettes qui approchent
	_hero.aim_point = skeletons[0].global_position
	_hero.cast_arc()
	await _frames(35) # ≈ frame 92
	_hero.cast_wave()
	await _frames(30) # ≈ frame 122
	# 2) Mini-jeu du solo.
	_hero.cast_solo()
	await _frames(55) # ≈ frame 178 : notes en train de tomber
	var solo := (_dungeon as Level).hud.solo
	solo._hits = Balance.SOLO_NOTES # on simule un solo parfait
	solo._finish()
	await _frames(20) # ≈ frame 200 : pluie d'éclairs
	# 3) Boss : Gloubah et sa vague.
	if boss != null:
		_hero.global_position = boss.global_position + Vector3(5.0, 0, 5.0)
		_hero.camera.snap_to_target()
		GameState.hp = GameState.max_hp()
		await _frames(10)
		boss._wave_timer = 0.3
		await _frames(50) # ≈ frame 260 : vague déferlante
	await _frames(40)
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
