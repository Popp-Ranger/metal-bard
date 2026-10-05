class_name BossMoves
extends RefCounted
## Coups de zone communs aux ennemis de la montagne (Bigfoot, troll des cavernes, élémentaire de glace colossal,
## Minotaure) : un cercle rouge au sol prévient (Telegraph), puis le coup tombe sur les héros restés dedans.


## Cercle d'impact en `pos` (rayon `radius`), qui frappe au bout de `delay` s : `dice` (nombre, faces, bonus) à chaque
## héros encore dedans. `fx` : « rock » (rochers qui éclatent), « ice » (pics de glace), « slam » (poussière).
## Rien ne tombe si l'ennemi est mort entre-temps. Coroutine : `await` pour attendre l'impact.
static func strike(enemy: Enemy, pos: Vector3, radius: float, delay: float, dice: Vector3i, fx: String = "slam") -> void:
	var parent := enemy.get_parent()
	pos.y = 0.0
	Telegraph.spawn(parent, pos, radius, delay)
	await enemy.get_tree().create_timer(delay, false).timeout
	if not is_instance_valid(enemy) or not enemy.is_alive() or not is_instance_valid(parent):
		return
	match fx:
		"ice":
			for k in 5:
				var a := TAU * k / 5.0 + randf() * 0.5
				ice_spike(parent, pos + Vector3(cos(a), 0, sin(a)) * radius * randf_range(0.2, 0.8), randf_range(0.9, 1.6))
			ice_spike(parent, pos, 2.0)
			Sfx.play("clack", -4.0, 0.6)
		"rock":
			burst(parent, pos, Color(0.42, 0.38, 0.34), 22)
			Sfx.play("boom", -8.0)
		_:
			burst(parent, pos, Color(0.55, 0.5, 0.42), 14)
			Sfx.play("thud", -4.0, 0.3)
	Events.camera_shake.emit(0.18, 0.3)
	hit_heroes(enemy, pos, radius, Dice.roll(dice.x, dice.y, dice.z))


## Inflige `dmg` à chaque héros (local ou distant) dans le cercle.
static func hit_heroes(enemy: Enemy, pos: Vector3, radius: float, dmg: int) -> void:
	for h in enemy.get_tree().get_nodes_in_group("heroes"):
		var target := h as Node3D
		if Enemy.is_down(target):
			continue
		var d := Vector2(target.global_position.x - pos.x, target.global_position.z - pos.z).length()
		if d <= radius + float(target.get("radius")):
			target.call("take_hit", dmg, pos, enemy)


## Éclats (pierre, terre ou glace) projetés en gerbe depuis `pos`.
static func burst(parent: Node, pos: Vector3, color: Color, count: int) -> void:
	var p := CPUParticles3D.new()
	p.position = pos + Vector3(0, 0.2, 0)
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = count
	p.lifetime = 0.9
	p.direction = Vector3.UP
	p.spread = 55.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 6.0
	p.gravity = Vector3(0, -14.0, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	var m := BoxMesh.new()
	m.size = Vector3(0.12, 0.1, 0.12)
	m.material = Visuals.mat(color, 0.9)
	p.mesh = m
	p.emitting = true
	parent.add_child(p)
	p.get_tree().create_timer(1.5, false).timeout.connect(p.queue_free)


## Pic de glace qui jaillit du sol en `pos` (haut de `size` m), puis fond.
static func ice_spike(parent: Node, pos: Vector3, size: float = 1.4) -> void:
	var s := Node3D.new()
	s.position = Vector3(pos.x, 0.0, pos.z)
	s.rotation = Vector3(randf_range(-0.25, 0.25), randf() * TAU, randf_range(-0.25, 0.25))
	parent.add_child(s)
	Visuals.cylinder(s, 0.0, 0.22 * size, size, Vector3(0, size * 0.5, 0), ice_material(), Vector3.ZERO, 5)
	s.scale = Vector3(1, 0.05, 1)
	var tw := s.create_tween()
	tw.tween_property(s, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.9)
	tw.tween_property(s, "scale", Vector3(0.6, 0.02, 0.6), 0.5)
	tw.tween_callback(s.queue_free)


static var _ice: StandardMaterial3D


## Glace translucide, bleutée et légèrement lumineuse.
static func ice_material() -> StandardMaterial3D:
	if _ice == null:
		_ice = Visuals.transparent_mat(Color(0.65, 0.85, 1.0, 0.75), 0.6)
		_ice.emission = Color(0.4, 0.7, 1.0)
		_ice.roughness = 0.15
		_ice.metallic_specular = 0.9
	return _ice
