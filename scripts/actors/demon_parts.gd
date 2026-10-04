class_name DemonParts
extends RefCounted
## Pièces communes des démons (diablotins, démons cornus, ange déchu), en primitives : cornes recourbées, ailes de
## chauve-souris ou de plumes, hachette, guitare infernale. Repère du modèle : il regarde vers +Z, +Y en haut.


## Corne recourbée de `length` m (trois segments qui se resserrent), plantée en `pos`, penchée vers l'extérieur
## du côté `side` (-1 / +1) puis vers l'arrière.
static func horn(parent: Node3D, pos: Vector3, side: float, mat: Material, length: float = 0.25, curl: float = 35.0) -> void:
	var p := Node3D.new()
	p.position = pos
	p.rotation_degrees = Vector3(-15, 0, -25 * side)
	parent.add_child(p)
	var seg := length / 3.0
	var r := length * 0.18
	var node := p
	for k in 3:
		Visuals.cylinder(node, r * (0.62 - 0.2 * k), r * (1.0 - 0.25 * k), seg, Vector3(0, seg * 0.5, 0), mat, Vector3.ZERO, 8)
		var next := Node3D.new()
		next.position = Vector3(0, seg * 0.95, 0)
		next.rotation_degrees = Vector3(-curl, 0, -10 * side)
		node.add_child(next)
		node = next
	Visuals.cylinder(node, 0.0, r * 0.35, seg * 0.8, Vector3(0, seg * 0.4, 0), mat, Vector3.ZERO, 6)


## Aile de chauve-souris (côté -1 / +1) : pivot sur le dos, trois baleines et une membrane. Renvoie le pivot
## (le faire battre en tournant rotation.y).
static func bat_wing(parent: Node3D, pos: Vector3, side: float, bone: Material, membrane: Material, span: float = 0.8) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pos
	parent.add_child(pivot)
	var wing := Node3D.new()
	wing.rotation_degrees = Vector3(0, 30 * side, 0)
	pivot.add_child(wing)
	for k in 3:
		var a := deg_to_rad(20.0 - 35.0 * k)
		var tip := Vector3(side * cos(a), sin(a), -0.15) * span * (1.0 - 0.15 * k)
		var rib := Visuals.cylinder(wing, 0.012, 0.022, tip.length(), tip * 0.5, bone, Vector3.ZERO, 5)
		rib.basis = Basis(Quaternion(Vector3.UP, tip.normalized()))
		# Membrane entre deux baleines : un triangle aplati (prisme à 3 faces très fin).
		var skin := Visuals.cylinder(wing, span * 0.32, span * 0.32, 0.01, tip * 0.55 + Vector3(0, -0.08, 0), membrane, Vector3.ZERO, 3)
		skin.basis = Basis.from_euler(Vector3(PI * 0.5, 0.0, a + PI * 0.5 * side)) * Basis.from_scale(Vector3(1.0, 1.0, 0.7))
	return pivot


## Aile de plumes noires (ange déchu) : rangées de plumes en éventail. Renvoie le pivot.
static func feather_wing(parent: Node3D, pos: Vector3, side: float, feather: Material, span: float = 1.6) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pos
	parent.add_child(pivot)
	var wing := Node3D.new()
	wing.rotation_degrees = Vector3(0, 25 * side, 0)
	pivot.add_child(wing)
	for row in 3:
		var count := 6 - row
		for k in count:
			var t := float(k) / float(count - 1)
			var a := deg_to_rad(55.0 - 95.0 * t)
			var length := span * (0.55 + 0.45 * (1.0 - absf(t - 0.35))) * (1.0 - 0.22 * row)
			var base := Vector3(side * 0.12 * k, 0.1 - 0.05 * row, -0.04 * row)
			var dir := Vector3(side * cos(a), sin(a), -0.12)
			var f := Visuals.box(wing, Vector3(0.16 - 0.03 * row, length, 0.025), base + dir * length * 0.5, feather)
			f.basis = Basis(Quaternion(Vector3.UP, dir.normalized()))
	return pivot


## Hachette (manche de bois, fer recourbé) tenue par le manche à l'origine, lame vers +Z au bout du manche.
static func hatchet(parent: Node3D, scale_k: float = 1.0) -> Node3D:
	var h := Node3D.new()
	h.scale = Vector3.ONE * scale_k
	parent.add_child(h)
	var wood := Visuals.mat(Color(0.28, 0.16, 0.08), 0.8)
	var iron := Visuals.mat(Color(0.32, 0.3, 0.3), 0.35, 0.8)
	Visuals.cylinder(h, 0.022, 0.026, 0.5, Vector3(0, 0, 0.18), wood, Vector3(90, 0, 0), 6)
	Visuals.box(h, Vector3(0.03, 0.2, 0.12), Vector3(0, 0.08, 0.38), iron)
	Visuals.box(h, Vector3(0.02, 0.26, 0.04), Vector3(0, 0.1, 0.45), Visuals.mat(Color(0.75, 0.2, 0.15), 0.3, 0.6)) # tranchant rougi
	return h


## Guitare électrique infernale (Flying V noire et rouge hérissée de pointes, cordes incandescentes), tenue au
## manche à l'origine, corps vers -Y.
static func infernal_guitar(parent: Node3D, scale_k: float = 1.0) -> Node3D:
	var g := Node3D.new()
	g.scale = Vector3.ONE * scale_k
	parent.add_child(g)
	var black := Visuals.mat(Color(0.05, 0.03, 0.03), 0.3, 0.4)
	var red := Visuals.mat(Color(0.55, 0.03, 0.02), 0.25, 0.3)
	var glow := Visuals.glow_mat(Color(1.0, 0.35, 0.05), 4.0)
	Visuals.box(g, Vector3(0.07, 0.85, 0.04), Vector3(0, -0.2, 0), black) # manche
	Visuals.box(g, Vector3(0.12, 0.18, 0.05), Vector3(0, 0.3, 0), red, Vector3(0, 0, 12)) # tête
	for side: float in [-1.0, 1.0]:
		Visuals.box(g, Vector3(0.16, 0.62, 0.06), Vector3(0.17 * side, -0.82, 0), red, Vector3(0, 0, -28 * side)) # ailes du V
		Visuals.cylinder(g, 0.0, 0.03, 0.14, Vector3(0.33 * side, -1.08, 0), black, Vector3(0, 0, -150 * side), 6) # pointes
	Visuals.box(g, Vector3(0.2, 0.18, 0.065), Vector3(0, -0.62, 0), black)
	for k in 4:
		Visuals.box(g, Vector3(0.006, 1.05, 0.006), Vector3(-0.024 + k * 0.016, -0.3, 0.035), glow) # cordes
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.35, 0.1)
	l.light_energy = 1.2
	l.omni_range = 2.5
	l.position = Vector3(0, -0.6, 0.2)
	g.add_child(l)
	return g
