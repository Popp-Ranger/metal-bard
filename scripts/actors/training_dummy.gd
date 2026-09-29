class_name TrainingDummy
extends Enemy
## Mannequin d'entraînement (sous-sol de la taverne) : ne bouge pas, ne riposte pas,
## ne meurt jamais. Affiche les dégâts reçus sur les 5 dernières secondes et au total.

var _label: Label3D
var _hits: Array[Vector2] = [] # (instant, dégâts)
var _total := 0


func _configure() -> void:
	display_name = "Mannequin"
	max_hp = 1000000
	armor_class = 10
	save_bonus = 0
	radius = 0.4
	height = 1.8
	xp_reward = 0


func _build_model() -> void:
	var wood := own_mat(Color(0.35, 0.22, 0.12), 0.8)
	var straw := own_mat(Color(0.75, 0.62, 0.3), 0.95)
	var sack := own_mat(Color(0.6, 0.5, 0.35), 0.95)
	Visuals.cylinder(model, 0.06, 0.06, 1.8, Vector3(0, 0.9, 0), wood, Vector3.ZERO, 8)
	Visuals.cylinder(model, 0.35, 0.45, 0.08, Vector3(0, 0.04, 0), wood, Vector3.ZERO, 12)
	Visuals.capsule(model, 0.3, 0.8, Vector3(0, 1.15, 0), straw)
	Visuals.box(model, Vector3(1.0, 0.1, 0.1), Vector3(0, 1.35, 0), wood) # bras
	Visuals.sphere(model, 0.2, Vector3(0, 1.75, 0), sack)
	# Cible rouge et blanche peinte sur le torse.
	Visuals.cylinder(model, 0.22, 0.22, 0.02, Vector3(0, 1.15, 0.29), own_mat(Color(0.9, 0.9, 0.85)), Vector3(90, 0, 0), 20)
	Visuals.cylinder(model, 0.15, 0.15, 0.025, Vector3(0, 1.15, 0.3), own_mat(Color(0.75, 0.1, 0.08)), Vector3(90, 0, 0), 20)
	Visuals.cylinder(model, 0.07, 0.07, 0.03, Vector3(0, 1.15, 0.31), own_mat(Color(0.9, 0.9, 0.85)), Vector3(90, 0, 0), 16)
	_label = Visuals.label(self, "", Vector3(0, 2.35, 0), Color(1.0, 0.85, 0.5), 28)


func _physics_process(delta: float) -> void:
	_anim_t += delta
	if state == State.TRANCE:
		model.rotation.x = absf(sin(_anim_t * 11.0)) * 0.3
	else:
		model.rotation.x = lerpf(model.rotation.x, 0.0, delta * 8.0)
	var now := Time.get_ticks_msec() / 1000.0
	while not _hits.is_empty() and now - _hits[0].x > 5.0:
		_hits.pop_front()
	var recent := 0
	for h in _hits:
		recent += int(h.y)
	_label.text = "5 s : %d  •  total : %d" % [recent, _total] if _total > 0 else "Cible d'entraînement"


func take_damage(amount: int, _from: Vector3, _knockback: float = 0.0, crit: bool = false, kind: String = "phys") -> void:
	var color := Color(1.0, 0.95, 0.85)
	match kind:
		"shock":
			color = Color(0.55, 0.85, 1.0)
		"sound":
			color = Color(0.8, 0.6, 1.0)
		"fire":
			color = Color(1.0, 0.55, 0.2)
	if crit:
		color = Color(1.0, 0.8, 0.2)
	DamageNumber.spawn(get_parent(), global_position + Vector3(0, 2.0, 0), "%d%s" % [amount, "!" if crit else ""], color, crit)
	_hits.append(Vector2(Time.get_ticks_msec() / 1000.0, amount))
	_total += amount
	_flash()
	# Le mannequin vacille sous le coup.
	var tw := create_tween()
	tw.tween_property(model, "rotation:z", randf_range(-0.25, 0.25), 0.06)
	tw.tween_property(model, "rotation:z", 0.0, 0.3).set_trans(Tween.TRANS_ELASTIC)
	Sfx.play("thud", -14.0, 0.2)


func show_miss() -> void:
	DamageNumber.spawn(get_parent(), global_position + Vector3(0, 2.0, 0), "Raté", Color(0.7, 0.7, 0.7))


func _die() -> void:
	pass # un mannequin ne meurt jamais
