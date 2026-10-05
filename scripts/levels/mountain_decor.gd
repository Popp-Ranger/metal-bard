class_name MountainDecor
extends RefCounted
## Décor de l'expédition vers le Labyrinthe du Destin (scripts/world/expedition.gd), en primitives : prairie (buissons,
## arbres, fleurs, rochers), flancs de la montagne (sapins, congères, cairns), grottes des gobelins (champignons
## lumineux, cristaux, stalagmites, campements), col (drapeaux de prière, rochers enneigés), labyrinthe de glace
## (cristaux, aventuriers gelés).


static func _rng_color(rng: RandomNumberGenerator, c: Color, spread: float = 0.08) -> Color:
	var k := rng.randf_range(1.0 - spread, 1.0 + spread)
	return Color(c.r * k, c.g * k, c.b * k)


## Rocher irrégulier (sphère à peu de faces), texturé ; `solid` : on bute dessus.
static func boulder(parent: Node3D, p: Vector3, size: float, rng: RandomNumberGenerator, tint: Color = Color(0.55, 0.52, 0.5),
		snowy: bool = false, solid: bool = true) -> void:
	var m := SphereMesh.new()
	m.radius = size
	m.height = size * 1.6
	m.radial_segments = 7
	m.rings = 4
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = Visuals.textured("falaise", 2.0, _rng_color(rng, tint))
	mi.position = p + Vector3(0, size * 0.45, 0)
	mi.rotation = Vector3(rng.randf_range(-0.3, 0.3), rng.randf() * TAU, rng.randf_range(-0.3, 0.3))
	parent.add_child(mi)
	if snowy:
		Visuals.sphere(parent, size * 0.8, p + Vector3(0, size * 1.05, 0), Visuals.textured("neige", 3.0, Color(0.95, 0.97, 1.0)), Vector3(1.0, 0.35, 1.0))
	if solid:
		Visuals.solid_cylinder(parent, size * 0.85, size * 1.6, p + Vector3(0, size * 0.8, 0))


## Buisson (trois boules de feuillage).
static func bush(parent: Node3D, p: Vector3, rng: RandomNumberGenerator, size: float = 0.6) -> void:
	var leaf := Visuals.mat(_rng_color(rng, Color(0.2, 0.36, 0.12), 0.15), 0.9)
	for k in 3:
		var o := Vector3(rng.randf_range(-0.35, 0.35), 0, rng.randf_range(-0.35, 0.35)) * size
		Visuals.sphere(parent, size * rng.randf_range(0.55, 0.8), p + o + Vector3(0, size * 0.45, 0), leaf, Vector3(1.0, 0.8, 1.0))


## Feuillu (tronc, houppier en boules) ou sapin (`pine` : trois cônes empilés), haut de `h` m.
static func tree(parent: Node3D, p: Vector3, rng: RandomNumberGenerator, h: float = 4.0, pine: bool = false, snowy: bool = false) -> void:
	var bark := Visuals.mat(Color(0.25, 0.16, 0.09), 0.9)
	Visuals.cylinder(parent, 0.12 * h / 4.0, 0.2 * h / 4.0, h * 0.45, p + Vector3(0, h * 0.22, 0), bark, Vector3.ZERO, 7)
	if pine:
		var needles := Visuals.mat(_rng_color(rng, Color(0.1, 0.24, 0.14), 0.12), 0.9)
		var snow := Visuals.mat(Color(0.92, 0.95, 1.0), 0.8)
		for k in 3:
			var r := h * (0.32 - 0.08 * k)
			var y := h * (0.35 + 0.2 * k)
			Visuals.cylinder(parent, 0.0, r, h * 0.36, p + Vector3(0, y, 0), needles, Vector3.ZERO, 8)
			if snowy:
				Visuals.cylinder(parent, 0.0, r * 0.75, h * 0.16, p + Vector3(0, y + h * 0.1, 0), snow, Vector3.ZERO, 8)
	else:
		var leaf := Visuals.mat(_rng_color(rng, Color(0.22, 0.38, 0.13), 0.15), 0.9)
		for k in 4:
			var o := Vector3(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.2, 0.4), rng.randf_range(-0.5, 0.5)) * h * 0.25
			Visuals.sphere(parent, h * rng.randf_range(0.17, 0.24), p + Vector3(0, h * 0.62, 0) + o, leaf)
	Visuals.solid_cylinder(parent, 0.3, 2.0, p + Vector3(0, 1.0, 0))


## Touffe de fleurs des champs (petites boules de couleur sur des tiges).
static func flowers(parent: Node3D, p: Vector3, rng: RandomNumberGenerator) -> void:
	var colors := [Color(0.95, 0.85, 0.2), Color(0.9, 0.3, 0.35), Color(0.6, 0.45, 0.95), Color(1.0, 1.0, 0.95)]
	var c: Color = colors[rng.randi() % colors.size()]
	var petal := Visuals.mat(c, 0.7)
	var stem := Visuals.mat(Color(0.25, 0.45, 0.15), 0.9)
	for k in rng.randi_range(5, 9):
		var o := Vector3(rng.randf_range(-0.6, 0.6), 0, rng.randf_range(-0.6, 0.6))
		var h := rng.randf_range(0.18, 0.35)
		Visuals.cylinder(parent, 0.01, 0.01, h, p + o + Vector3(0, h * 0.5, 0), stem, Vector3.ZERO, 4)
		Visuals.sphere(parent, 0.05, p + o + Vector3(0, h, 0), petal)


## Touffe de hautes herbes.
static func grass_tuft(parent: Node3D, p: Vector3, rng: RandomNumberGenerator) -> void:
	var g := Visuals.mat(_rng_color(rng, Color(0.35, 0.5, 0.18), 0.15), 0.9)
	for k in 6:
		var a := TAU * k / 6.0
		Visuals.cylinder(parent, 0.0, 0.03, rng.randf_range(0.35, 0.6), p + Vector3(cos(a), 0, sin(a)) * 0.08 + Vector3(0, 0.22, 0), g,
			Vector3(rad_to_deg(sin(a)) * 0.3, 0, rad_to_deg(cos(a)) * 0.3), 3)


## Plaque de neige au sol.
static func snow_patch(parent: Node3D, p: Vector3, rng: RandomNumberGenerator) -> void:
	var s := Visuals.cylinder(parent, rng.randf_range(0.8, 1.6), rng.randf_range(1.0, 1.8), 0.06, p + Vector3(0, 0.03, 0),
		Visuals.textured("neige", 3.0, Color(0.95, 0.97, 1.0)), Vector3.ZERO, 9)
	s.scale = Vector3(1.0, 1.0, rng.randf_range(0.6, 1.0))
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Cairn : pierres plates empilées (balise des sentiers de montagne).
static func cairn(parent: Node3D, p: Vector3, rng: RandomNumberGenerator) -> void:
	var stone := Visuals.textured("falaise", 1.0, Color(0.6, 0.58, 0.55))
	var y := 0.0
	for k in 5:
		var r := 0.32 - 0.05 * k
		var h := rng.randf_range(0.12, 0.18)
		Visuals.cylinder(parent, r * 0.9, r, h, p + Vector3(rng.randf_range(-0.03, 0.03), y + h * 0.5, 0), stone,
			Vector3(rng.randf_range(-6, 6), rng.randf() * 90, rng.randf_range(-6, 6)), 7)
		y += h
	Visuals.solid_cylinder(parent, 0.3, 1.0, p + Vector3(0, 0.5, 0))


## Champignons lumineux des grottes (bleus ou verts), avec leur petite lueur.
static func glow_mushrooms(parent: Node3D, p: Vector3, rng: RandomNumberGenerator) -> void:
	var c := Color(0.3, 0.85, 1.0) if rng.randf() < 0.5 else Color(0.45, 1.0, 0.35)
	var cap := Visuals.glow_mat(c, 2.2)
	var stem := Visuals.mat(Color(0.85, 0.82, 0.72), 0.8)
	for k in rng.randi_range(3, 6):
		var o := Vector3(rng.randf_range(-0.45, 0.45), 0, rng.randf_range(-0.45, 0.45))
		var h := rng.randf_range(0.15, 0.45)
		Visuals.cylinder(parent, 0.03, 0.04, h, p + o + Vector3(0, h * 0.5, 0), stem, Vector3.ZERO, 6)
		Visuals.sphere(parent, h * 0.45, p + o + Vector3(0, h, 0), cap, Vector3(1.0, 0.45, 1.0))
	var l := OmniLight3D.new()
	l.light_color = c
	l.light_energy = 0.9
	l.omni_range = 3.5
	l.position = p + Vector3(0, 0.6, 0)
	parent.add_child(l)


## Stalagmite (cône de roche), avec collision.
static func stalagmite(parent: Node3D, p: Vector3, rng: RandomNumberGenerator) -> void:
	var h := rng.randf_range(1.0, 2.4)
	Visuals.cylinder(parent, 0.0, h * 0.22, h, p + Vector3(0, h * 0.5, 0), Visuals.textured("roche_grotte", 1.5, Color(0.55, 0.5, 0.45)), Vector3.ZERO, 7)
	Visuals.solid_cylinder(parent, h * 0.15, h, p + Vector3(0, h * 0.5, 0))


## Grappe de cristaux (améthyste dans les grottes, glace dans le labyrinthe), lumineux.
static func crystals(parent: Node3D, p: Vector3, rng: RandomNumberGenerator, color: Color) -> void:
	var m := Visuals.glow_mat(color, 1.8)
	for k in rng.randi_range(3, 5):
		var h := rng.randf_range(0.4, 1.1)
		Visuals.cylinder(parent, 0.0, h * 0.16, h, p + Vector3(rng.randf_range(-0.25, 0.25), h * 0.4, rng.randf_range(-0.25, 0.25)), m,
			Vector3(rng.randf_range(-25, 25), rng.randf() * 90, rng.randf_range(-25, 25)), 5)
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = 0.8
	l.omni_range = 3.0
	l.position = p + Vector3(0, 0.8, 0)
	parent.add_child(l)
	Visuals.solid_cylinder(parent, 0.35, 1.0, p + Vector3(0, 0.5, 0))


## Feu de camp des gobelins : pierres en cercle, bûches, flammes et lueur vacillante.
static func campfire(parent: Node3D, p: Vector3) -> void:
	var stone := Visuals.mat(Color(0.3, 0.28, 0.26), 0.9)
	for k in 8:
		var a := TAU * k / 8.0
		Visuals.sphere(parent, 0.13, p + Vector3(cos(a), 0.06, sin(a)) * 0.55, stone, Vector3(1.0, 0.7, 1.0))
	var wood := Visuals.mat(Color(0.2, 0.12, 0.06), 0.9)
	for k in 3:
		Visuals.cylinder(parent, 0.05, 0.05, 0.8, p + Vector3(0, 0.12, 0), wood, Vector3(70, 60 * k, 0), 6)
	Visuals.cylinder(parent, 0.0, 0.25, 0.55, p + Vector3(0, 0.35, 0), Visuals.glow_mat(Color(1.0, 0.5, 0.1), 4.0), Vector3.ZERO, 6)
	Visuals.cylinder(parent, 0.0, 0.14, 0.4, p + Vector3(0.05, 0.4, 0.03), Visuals.glow_mat(Color(1.0, 0.85, 0.3), 5.0), Vector3.ZERO, 5)
	var l := Visuals.flicker_light(parent, p + Vector3(0, 1.0, 0), Color(1.0, 0.55, 0.2), 2.2, 7.0)
	l.flicker_amount = 0.3
	Visuals.solid_cylinder(parent, 0.6, 0.6, p + Vector3(0, 0.3, 0))
	# Broche : un rat qui rôtit (les gobelins ne sont pas difficiles).
	Visuals.cylinder(parent, 0.015, 0.015, 1.3, p + Vector3(0, 0.75, 0), wood, Vector3(0, 0, 90), 4)
	Visuals.capsule(parent, 0.07, 0.3, p + Vector3(0, 0.75, 0), Visuals.mat(Color(0.35, 0.2, 0.1), 0.6), Vector3(0, 0, 90))


## Tente de gobelin : peaux tendues sur des perches, ouverture vers +Z tourné de `yaw`.
static func tent(parent: Node3D, p: Vector3, yaw: float, rng: RandomNumberGenerator) -> void:
	var t := Node3D.new()
	t.position = p
	t.rotation.y = yaw
	parent.add_child(t)
	var hide := Visuals.mat(_rng_color(rng, Color(0.45, 0.32, 0.2), 0.12), 0.95)
	var pole := Visuals.mat(Color(0.25, 0.16, 0.08), 0.9)
	Visuals.cylinder(t, 0.0, 1.2, 1.7, Vector3(0, 0.85, 0), hide, Vector3.ZERO, 6)
	for k in 4:
		var a := TAU * k / 4.0 + 0.4
		Visuals.cylinder(t, 0.025, 0.025, 2.1, Vector3(cos(a) * 0.2, 1.0, sin(a) * 0.2), pole, Vector3(rad_to_deg(sin(a)) * 0.2, 0, rad_to_deg(cos(a)) * -0.2), 4)
	Visuals.box(t, Vector3(0.6, 0.9, 0.05), Vector3(0, 0.45, 1.05), Visuals.mat(Color(0.05, 0.04, 0.03)), Vector3(-30, 0, 0)) # entrée
	Visuals.sphere(t, 0.1, Vector3(0, 1.75, 0), Visuals.mat(Color(0.9, 0.88, 0.8)), Vector3(0.9, 1.1, 1.0)) # crâne au sommet
	Visuals.solid_cylinder(t, 1.0, 1.7, Vector3(0, 0.85, 0))


## Drapeaux de prière tendus entre deux perches, qui claquent au vent.
static func prayer_flags(parent: Node3D, a: Vector3, b: Vector3, rng: RandomNumberGenerator) -> void:
	var pole := Visuals.mat(Color(0.3, 0.2, 0.1), 0.9)
	for p: Vector3 in [a, b]:
		Visuals.cylinder(parent, 0.04, 0.05, 2.4, p + Vector3(0, 1.2, 0), pole, Vector3.ZERO, 5)
		Visuals.solid_cylinder(parent, 0.1, 2.4, p + Vector3(0, 1.2, 0))
	var colors := [Color(0.2, 0.35, 0.9), Color(0.95, 0.95, 0.9), Color(0.85, 0.15, 0.1), Color(0.15, 0.6, 0.2), Color(0.95, 0.8, 0.1)]
	var n := maxi(4, roundi(a.distance_to(b) / 0.45))
	for k in n:
		var t := (k + 0.5) / n
		var p := a.lerp(b, t) + Vector3(0, 2.3 - sin(t * PI) * 0.45, 0)
		var f := Visuals.box(parent, Vector3(0.28, 0.32, 0.01), p - Vector3(0, 0.18, 0), Visuals.mat(colors[k % colors.size()], 0.9))
		f.rotation.y = atan2(b.x - a.x, b.z - a.z) + PI * 0.5
		f.rotation.x = rng.randf_range(-0.3, 0.3)
		f.create_tween().set_loops().tween_property(f, "rotation:x", f.rotation.x + 0.35, rng.randf_range(0.3, 0.6)).set_trans(Tween.TRANS_SINE)


## Aventurier pris dans la glace : silhouette figée (épée levée) dans un bloc translucide.
static func frozen_adventurer(parent: Node3D, p: Vector3, rng: RandomNumberGenerator) -> void:
	var f := Node3D.new()
	f.position = p
	f.rotation.y = rng.randf() * TAU
	parent.add_child(f)
	var body := Visuals.mat(Color(0.25, 0.3, 0.38), 0.6)
	Visuals.capsule(f, 0.2, 1.1, Vector3(0, 0.95, 0), body)
	Visuals.sphere(f, 0.15, Vector3(0, 1.68, 0), body)
	Visuals.capsule(f, 0.06, 0.6, Vector3(0.25, 1.65, 0.05), body, Vector3(0, 0, -160))
	Visuals.box(f, Vector3(0.05, 0.9, 0.02), Vector3(0.32, 2.25, 0.05), Visuals.mat(Color(0.6, 0.62, 0.65), 0.3, 0.8), Vector3(0, 0, 10))
	Visuals.box(f, Vector3(0.9, 2.9, 0.8), Vector3(0, 1.45, 0), BossMoves.ice_material(), Vector3(rng.randf_range(-4, 4), 0, rng.randf_range(-4, 4)))
	Visuals.solid(f, Vector3(0.9, 2.9, 0.8), Vector3(0, 1.45, 0))
