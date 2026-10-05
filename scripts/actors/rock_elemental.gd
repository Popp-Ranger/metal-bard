class_name RockElemental
extends Enemy
## Élémentaire de roche : 2,1 m de rochers empilés qui flottent les uns au-dessus des autres, liés par une lueur de
## magma ambré (yeux et fissures). Très lent, très coriace ; il frappe des deux poings. Les rochers sont texturés
## (assets/textures/falaise).

var _core: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _slam := 0.0
var _glow_mats: Array[StandardMaterial3D] = []


func _configure() -> void:
	var lvl := level - 1
	display_name = "Élémentaire de roche"
	max_hp = 30 + 8 * lvl
	armor_class = 15
	attack_bonus = 5 + floori(lvl / 2.0)
	damage_dice = Vector3i(2, 6, 2 + lvl)
	save_bonus = 3
	xp_reward = 140 + 20 * lvl
	gold_range = Vector2i(5, 14)
	radius = 0.6
	height = 2.1
	attack_range = 1.4
	move_speed = Balance.HERO_SPEED * 0.18


func _build_model() -> void:
	var rock := own_mat(Color(0.5, 0.46, 0.42), 0.95)
	rock.albedo_texture = Visuals.texture("falaise", "couleur")
	rock.uv1_triplanar = true
	rock.uv1_scale = Vector3.ONE * 0.8
	var dark := own_mat(Color(0.3, 0.27, 0.25), 0.95)
	var magma := Visuals.glow_mat(Color(1.0, 0.55, 0.15), 3.0)
	_glow_mats.append(magma)
	_core = Node3D.new()
	model.add_child(_core)
	# Bas : un amas de cailloux qui flotte au-dessus du sol.
	for k in 5:
		var a := TAU * k / 5.0
		_rock(_core, Vector3(cos(a) * 0.3, 0.25, sin(a) * 0.3), 0.18, dark)
	_rock(_core, Vector3(0, 0.55, 0), 0.32, rock)
	_rock(_core, Vector3(0, 1.1, 0), 0.48, rock, Vector3(1.15, 0.95, 0.9)) # torse
	Visuals.sphere(_core, 0.2, Vector3(0, 1.1, 0.3), magma, Vector3(1.0, 1.3, 0.3)) # cœur de magma
	_rock(_core, Vector3(0, 1.72, 0.05), 0.24, rock, Vector3(1.1, 0.85, 1.0)) # tête
	for side: float in [-1.0, 1.0]:
		Visuals.box(_core, Vector3(0.07, 0.035, 0.04), Vector3(0.09 * side, 1.74, 0.25), magma)
		var arm := Node3D.new()
		arm.position = Vector3(0.6 * side, 1.35, 0)
		_core.add_child(arm)
		_rock(arm, Vector3.ZERO, 0.22, rock)
		_rock(arm, Vector3(0.05 * side, -0.38, 0.05), 0.18, dark)
		_rock(arm, Vector3(0.06 * side, -0.78, 0.12), 0.27, rock, Vector3(1.0, 1.1, 1.0)) # poing
		if side < 0.0:
			_arm_l = arm
		else:
			_arm_r = arm
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.55, 0.2)
	glow.light_energy = 0.8
	glow.omni_range = 3.0
	glow.position = Vector3(0, 1.2, 0.6)
	model.add_child(glow)


## Rocher irrégulier (sphère à peu de faces, aplatie au hasard).
func _rock(parent: Node3D, pos: Vector3, r: float, mat: Material, sc: Vector3 = Vector3.ONE) -> void:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 6
	m.rings = 3
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	mi.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
	mi.scale = sc * Vector3(randf_range(0.85, 1.15), randf_range(0.8, 1.1), randf_range(0.85, 1.15))
	parent.add_child(mi)


func _animate(_delta: float, moving: bool) -> void:
	var sway := sin(_anim_t * 3.0) if moving else 0.0
	_core.position.y = 0.12 + sin(_anim_t * 1.6) * 0.06
	_core.rotation.z = sway * 0.06
	_arm_l.rotation.x = lerpf(-sway * 0.3, -2.3, _slam)
	_arm_r.rotation.x = lerpf(sway * 0.3, -2.3, _slam)


func _attack_anim(windup: float) -> void:
	var tw := create_tween()
	tw.tween_property(self, "_slam", 1.0, windup * 0.85).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "_slam", -0.4, 0.1)
	tw.tween_callback(func() -> void: BossMoves.burst(get_parent(), global_position + model.basis.z * 1.0, Color(0.45, 0.4, 0.36), 8))
	tw.tween_property(self, "_slam", 0.0, 0.4)


func _death_anim() -> void:
	Sfx.play("boom", -8.0)
	for m in _glow_mats:
		m.emission_energy_multiplier = 0.0
	BossMoves.burst(get_parent(), global_position + Vector3(0, 0.8, 0), Color(0.45, 0.4, 0.36), 18)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_core, "position:y", -0.5, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(_core, "rotation:x", -0.5, 0.5)
	_corpse(2.0)
