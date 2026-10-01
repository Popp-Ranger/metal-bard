class_name DungeonDecor
extends RefCounted
## Décor des donjons (torches murales, tas d'os, bave, piliers, tonneaux, coffre), partagé par le jeu
## (dungeon.gd) et par les aperçus de l'éditeur de niveau (DungeonMarker).

const CELL := 2.0
const WALL_HEIGHT := 2.6


## Torche murale en `pos`, l'applique contre le mur, la flamme vers `inward` (vers l'intérieur de la pièce).
static func torch(parent: Node3D, pos: Vector3, inward: Vector3, shadows: bool = false) -> Node3D:
	var iron := Visuals.mat(Color(0.18, 0.17, 0.17), 0.4, 0.8)
	var t := Node3D.new()
	t.position = pos
	t.rotation.y = atan2(inward.x, inward.z) # +Z local = vers l'intérieur de la pièce
	parent.add_child(t)
	Visuals.box(t, Vector3(0.22, 0.08, 0.06), Vector3(0, 1.75, 0.02), iron) # applique
	Visuals.box(t, Vector3(0.05, 0.3, 0.05), Vector3(0, 1.85, 0.14), iron, Vector3(30, 0, 0))
	Visuals.cylinder(t, 0.05, 0.035, 0.45, Vector3(0, 2.0, 0.22), Visuals.mat(Color(0.25, 0.14, 0.07)), Vector3(25, 0, 0), 8)
	Visuals.sphere(t, 0.1, Vector3(0, 2.27, 0.33), Visuals.glow_mat(Color(1.0, 0.5, 0.12), 6.0), Vector3(1.0, 1.6, 1.0))
	Visuals.sphere(t, 0.06, Vector3(0, 2.35, 0.33), Visuals.glow_mat(Color(1.0, 0.85, 0.4), 8.0), Vector3(1.0, 1.5, 1.0))
	var flame := CPUParticles3D.new()
	flame.position = Vector3(0, 2.35, 0.33)
	flame.amount = 10
	flame.lifetime = 0.5
	flame.gravity = Vector3(0, 1.5, 0)
	flame.initial_velocity_min = 0.1
	flame.initial_velocity_max = 0.3
	flame.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	flame.emission_sphere_radius = 0.05
	flame.scale_amount_min = 0.5
	flame.scale_amount_max = 1.0
	var spark := SphereMesh.new()
	spark.radius = 0.035
	spark.height = 0.07
	spark.material = Visuals.glow_mat(Color(1.0, 0.6, 0.2), 5.0)
	flame.mesh = spark
	t.add_child(flame)
	var light := Visuals.flicker_light(t, Vector3(0, 2.4, 0.8), Color(1.0, 0.6, 0.3), 3.2, 11.0, shadows)
	light.flicker_amount = 0.2
	return t


## Tas d'os : quelques os éparpillés et un crâne.
static func bones(parent: Node3D, p: Vector3, rng: RandomNumberGenerator) -> void:
	var bone := Visuals.mat(Color(0.75, 0.72, 0.6))
	for b in 5:
		Visuals.capsule(parent, 0.04, 0.4, p + Vector3(rng.randf_range(-0.4, 0.4), 0.05, rng.randf_range(-0.4, 0.4)),
			bone, Vector3(90, rng.randf_range(0, 180), 0))
	Visuals.sphere(parent, 0.13, p + Vector3(0.2, 0.12, 0.1), bone)


## Flaque de bave verte luminescente.
static func slime(parent: Node3D, p: Vector3) -> void:
	Visuals.cylinder(parent, 0.7, 0.8, 0.02, p + Vector3(0, 0.02, 0), Visuals.glow_mat(Color(0.35, 0.8, 0.25), 0.6))


## Pilier brisé (bloque le passage si `solid`).
static func pillar(parent: Node3D, p: Vector3, stone: Material, solid: bool) -> void:
	Visuals.cylinder(parent, 0.35, 0.4, 1.2, p + Vector3(0, 0.6, 0), stone, Vector3(0, 0, 0), 8)
	if solid:
		Visuals.solid_cylinder(parent, 0.4, 2.0, p + Vector3(0, 1.0, 0))


## Tonneau cerclé de fer (bloque le passage si `solid`).
static func barrel(parent: Node3D, p: Vector3, solid: bool) -> void:
	Visuals.cylinder(parent, 0.3, 0.3, 0.8, p + Vector3(0, 0.4, 0), Visuals.mat(Color(0.25, 0.15, 0.08)))
	Visuals.torus(parent, 0.28, 0.32, p + Vector3(0, 0.6, 0), Visuals.mat(Color(0.2, 0.2, 0.22), 0.4, 0.7))
	if solid:
		Visuals.solid_cylinder(parent, 0.32, 1.0, p + Vector3(0, 0.5, 0))


## Coffre (fermé) : renvoie [nœud du coffre, couvercle, lueur].
static func chest(parent: Node3D, p: Vector3, yaw: float = 0.0) -> Array:
	var c := Node3D.new()
	c.position = p
	c.rotation.y = yaw
	parent.add_child(c)
	var wood := Visuals.mat(Color(0.35, 0.2, 0.1), 0.7)
	var gold := Visuals.mat(Color(0.85, 0.65, 0.2), 0.3, 0.9)
	Visuals.box(c, Vector3(1.1, 0.6, 0.7), Vector3(0, 0.3, 0), wood)
	var lid := Visuals.box(c, Vector3(1.15, 0.2, 0.75), Vector3(0, 0.7, 0), wood)
	for x: float in [-0.4, 0.4]:
		Visuals.box(c, Vector3(0.08, 0.82, 0.78), Vector3(x, 0.41, 0), gold)
	var shine := OmniLight3D.new()
	shine.position = Vector3(0, 1.0, 0)
	shine.light_color = Color(1.0, 0.8, 0.4)
	shine.light_energy = 1.2
	shine.omni_range = 3.0
	c.add_child(shine)
	return [c, lid, shine]
