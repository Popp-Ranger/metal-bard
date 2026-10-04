class_name Pickup
extends Node3D
## Butin au sol : médiators, potion ou équipement (coffres). Attiré par le héros quand il s'approche ; les médiators
## se ramassent tout seuls : après un petit saut, ils filent vers le héros où qu'il soit. Le reste du butin des
## ennemis attend sur leur corps (Enemy.loot).

var kind := "gold" # "gold", "potion", "item", "quest"
## Ramassage automatique (médiators) : délai du petit saut avant de filer vers le héros.
const AUTO_DELAY := 0.35
var value := 0
var item_id := ""
var _hero: Node3D
var _t := randf() * 10.0
var _visual: Node3D
var _age := 0.0


static func spawn(parent: Node, pos: Vector3, loot_kind: String, loot_value: int = 0, loot_item: String = "") -> Pickup:
	var p := Pickup.new()
	p.kind = loot_kind
	p.value = loot_value
	p.item_id = loot_item
	p.position = Vector3(pos.x + randf_range(-0.6, 0.6), 0.0, pos.z + randf_range(-0.6, 0.6))
	parent.add_child(p)
	return p


func _ready() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	match kind:
		"gold":
			# Médiators (la monnaie du jeu) : petits triangles arrondis, écaille, nacre et or.
			var pick_colors: Array[Color] = [Color(1.0, 0.78, 0.2), Color(0.95, 0.35, 0.15), Color(0.9, 0.88, 0.95)]
			for i in 3:
				Visuals.cylinder(_visual, 0.15, 0.15, 0.03, Vector3(randf_range(-0.1, 0.1), 0.3 + i * 0.05, randf_range(-0.1, 0.1)),
					Visuals.glow_mat(pick_colors[i], 1.2), Vector3(randf_range(-20, 20), randf_range(0, 120), 70), 3)
		"potion":
			Visuals.sphere(_visual, 0.16, Vector3(0, 0.35, 0), Visuals.glow_mat(Color(0.9, 0.1, 0.15), 1.5))
			Visuals.cylinder(_visual, 0.05, 0.05, 0.15, Vector3(0, 0.55, 0), Visuals.mat(Color(0.5, 0.35, 0.2)))
		"quest":
			# Objet de quête (partition maudite) : parchemin roulé qui crépite d'éclairs bleutés.
			Visuals.cylinder(_visual, 0.08, 0.08, 0.5, Vector3(0, 0.45, 0), Visuals.glow_mat(Color(0.95, 0.88, 0.7), 1.2), Vector3(0, 0, 90), 10)
			var l := OmniLight3D.new()
			l.light_color = Color(0.6, 0.7, 1.0)
			l.omni_range = 3.0
			l.light_energy = 2.0
			l.position.y = 0.7
			add_child(l)
		_:
			var c := ItemDB.color_of(item_id)
			Visuals.box(_visual, Vector3(0.3, 0.3, 0.3), Vector3(0, 0.4, 0), Visuals.glow_mat(c, 2.5), Vector3(45, 0, 45))
			var l := OmniLight3D.new()
			l.light_color = c
			l.omni_range = 2.5
			l.light_energy = 1.5
			l.position.y = 0.6
			add_child(l)


func _process(delta: float) -> void:
	_t += delta
	_visual.position.y = sin(_t * 3.0) * 0.08
	_visual.rotation.y += delta * 1.5
	if _hero == null or not is_instance_valid(_hero):
		_hero = get_tree().get_first_node_in_group("hero") as Node3D
		return
	var to := _hero.global_position - global_position
	to.y = 0.0
	var d := to.length()
	if kind == "gold":
		# Médiators : ramassés automatiquement, de plus en plus vite.
		if _age < AUTO_DELAY:
			_age += delta
			return
		_age += delta
		if d < 0.5:
			_collect()
		else:
			global_position += to.normalized() * minf(d, delta * (8.0 + 10.0 * _age))
		return
	if d < 0.7:
		_collect()
	elif d < 3.0:
		global_position += to.normalized() * minf(d, delta * 7.0)


func _collect() -> void:
	grant(get_parent(), global_position, kind, value, item_id)
	queue_free()


## Donne un butin au héros local (médiators, potion ou équipement), avec son petit effet : objets au sol (coffres)
## et corps fouillés (Enemy.loot_all).
static func grant(parent: Node, at: Vector3, loot_kind: String, loot_value: int = 0, loot_item: String = "") -> void:
	match loot_kind:
		"gold":
			GameState.add_gold(loot_value)
			Sfx.play("coin", -6.0)
			DamageNumber.spawn(parent, at + Vector3(0, 1.2, 0), "+%d médiators" % loot_value, Events.COLOR_GOLD)
		"potion":
			GameState.add_potion()
			Sfx.play("coin", -6.0, 0.2)
			Events.notify("Potion de soin ramassée (%d)" % GameState.potions, Events.COLOR_GOOD)
		"quest":
			Sfx.play("levelup", -4.0)
			GameState.add_quest_item(loot_item)
		_:
			Sfx.play("levelup", -8.0)
			GameState.add_item(loot_item)
