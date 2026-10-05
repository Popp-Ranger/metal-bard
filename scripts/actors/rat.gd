class_name Rat
extends Enemy
## Rat des catacombes : 3 PV, petit, nerveux, mord pour 1d3. Il détale en zigzag
## et couine quand il meurt. On en croise dans le premier donjon.

var _tail: Node3D
var _legs: Array[Node3D] = []


func _configure() -> void:
	display_name = "Rat des catacombes"
	max_hp = 3
	armor_class = 10
	attack_bonus = 2
	damage_dice = Vector3i(1, 3, 0)
	save_bonus = 0
	xp_reward = 10
	gold_range = Vector2i(0, 2)
	radius = 0.3
	height = 0.6
	attack_range = 0.5
	wander_radius = 4.0
	move_speed = Balance.HERO_SPEED * 0.4 # un peu plus vif que les squelettes


func _build_model() -> void:
	var fur := own_mat(Color(0.42, 0.37, 0.33), 0.9)
	model.scale = Vector3.ONE * 1.5 # assez gros pour être lisible en vue isométrique
	var pink := own_mat(Color(0.8, 0.5, 0.5), 0.7)
	var eye := Visuals.glow_mat(Color(1.0, 0.1, 0.05), 3.0)
	Visuals.sphere(model, 0.2, Vector3(0, 0.18, -0.02), fur, Vector3(0.85, 0.75, 1.4))
	Visuals.sphere(model, 0.12, Vector3(0, 0.2, 0.26), fur, Vector3(0.9, 0.85, 1.3))
	Visuals.cylinder(model, 0.0, 0.07, 0.14, Vector3(0, 0.19, 0.4), fur, Vector3(90, 0, 0), 8) # museau
	Visuals.sphere(model, 0.025, Vector3(0, 0.19, 0.47), pink)
	for side: float in [-1.0, 1.0]:
		Visuals.sphere(model, 0.06, Vector3(0.07 * side, 0.32, 0.2), pink, Vector3(1.0, 1.0, 0.4)) # oreilles
		Visuals.sphere(model, 0.018, Vector3(0.055 * side, 0.25, 0.34), eye)
		for front: float in [-1.0, 1.0]:
			var leg := Node3D.new()
			leg.position = Vector3(0.1 * side, 0.1, 0.14 * front)
			model.add_child(leg)
			Visuals.capsule(leg, 0.025, 0.12, Vector3(0, -0.05, 0), pink)
			_legs.append(leg)
	_tail = Node3D.new()
	_tail.position = Vector3(0, 0.15, -0.28)
	model.add_child(_tail)
	Visuals.cylinder(_tail, 0.008, 0.025, 0.45, Vector3(0, 0, -0.22), pink, Vector3(-80, 0, 0), 6)


func _animate(_delta: float, moving: bool) -> void:
	_tail.rotation.y = sin(_anim_t * (14.0 if moving else 4.0)) * 0.5
	for i in _legs.size():
		_legs[i].rotation.x = sin(_anim_t * 20.0 + i * PI * 0.5) * 0.6 if moving else 0.0
	model.position.y = absf(sin(_anim_t * 20.0)) * 0.03 if moving else 0.0


func _attack_anim(windup: float) -> void:
	var tw := create_tween()
	tw.tween_property(model, "position:z", -0.1, windup * 0.8)
	tw.tween_property(model, "position:z", 0.2, 0.06)
	tw.tween_property(model, "position:z", 0.0, 0.2)


func _death_anim() -> void:
	Sfx.play("clack", -8.0, 0.3)
	# Sur le dos : il se retourne autour de ses pattes, on le remonte pour que le corps reste au-dessus du sol
	# (sinon il disparaît sous les dalles et on ne peut plus le fouiller).
	var tw := create_tween().set_parallel(true)
	tw.tween_property(model, "rotation:z", PI, 0.25)
	tw.tween_property(model, "position:y", 0.6, 0.25)
	_corpse(1.45)


func _vanish() -> void:
	var tw := create_tween()
	tw.tween_property(model, "scale", Vector3(1.5, 0.07, 1.5), 0.4)
	tw.tween_callback(queue_free)


func _corpse_center() -> Vector3:
	return global_position # retourné sur place
