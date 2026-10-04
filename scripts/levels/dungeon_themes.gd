class_name DungeonThemes
extends RefCounted
## Décor propre à chaque thème de donjon (voir dungeon.gd, `theme`) :
##   • « crypte » (Cryptes de la Cathédrale) : ruisseaux de lave en fusion (avec ponts de pierre), basalte rougeoyant ;
##   • « temple » (Temple du Dragon) : vitraux, bancs d'église, candélabres, colonnes, et la fontaine de sang de
##     l'ange déchu au milieu de la nef.

const LAVA_WIDTH := 1.3


static func wall_color(theme: String) -> Color:
	match theme:
		"crypte":
			return Color(0.2, 0.14, 0.13)
		"temple":
			return Color(0.4, 0.38, 0.36)
	return Color(0.23, 0.22, 0.25)


# --- Lave -------------------------------------------------------------------------------------

static var _lava_mat: ShaderMaterial


## Lave en fusion : bouillonnement orange et jaune (bruit qui dérive), sans éclairage (elle brille d'elle-même).
static func lava_material() -> ShaderMaterial:
	if _lava_mat == null:
		var sh := Shader.new()
		sh.code = """
shader_type spatial;
render_mode unshaded;
uniform sampler2D noise_tex : repeat_enable, filter_linear;
varying vec3 wpos;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 p = wpos.xz * 0.3;
	float n = texture(noise_tex, p + vec2(TIME * 0.03, TIME * 0.02)).r;
	float m = texture(noise_tex, p * 2.3 - vec2(TIME * 0.05, 0.0)).r;
	float h = smoothstep(0.3, 0.75, n * 0.6 + m * 0.4);
	vec3 col = mix(vec3(0.3, 0.02, 0.0), vec3(1.0, 0.45, 0.05), h);
	col = mix(col, vec3(1.0, 0.85, 0.4), smoothstep(0.82, 0.95, h));
	ALBEDO = col * 1.8;
}
"""
		_lava_mat = ShaderMaterial.new()
		_lava_mat.shader = sh
		var tex := NoiseTexture2D.new()
		var noise := FastNoiseLite.new()
		noise.frequency = 0.02
		tex.noise = noise
		tex.seamless = true
		tex.width = 256
		tex.height = 256
		_lava_mat.set_shader_parameter("noise_tex", tex)
	return _lava_mat


## Ruisseau de lave rectiligne de `a` à `b` (au sol), bordé de basalte, avec des braises et une lueur orange.
## Renvoie sa zone au sol (pour les brûlures) : Rect2 dans le plan XZ.
static func lava_stream(parent: Node3D, a: Vector3, b: Vector3, width: float = LAVA_WIDTH) -> Rect2:
	var along := b - a
	var length := along.length()
	var mid := (a + b) * 0.5
	var yaw := atan2(along.x, along.z)
	var lava := Visuals.box(parent, Vector3(width, 0.04, length), mid + Vector3(0, 0.03, 0), lava_material())
	lava.rotation.y = yaw
	lava.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var basalt := Visuals.mat(Color(0.06, 0.04, 0.04), 0.9)
	var side := Vector3(cos(yaw), 0, -sin(yaw)) # perpendiculaire au ruisseau
	for s: float in [-1.0, 1.0]:
		var rim := Visuals.box(parent, Vector3(0.18, 0.1, length), mid + side * s * (width * 0.5 + 0.09) + Vector3(0, 0.05, 0), basalt)
		rim.rotation.y = yaw
	var lights := maxi(1, roundi(length / 6.0))
	for k in lights:
		var p := a + along * ((k + 0.5) / lights)
		var l := Visuals.flicker_light(parent, p + Vector3(0, 0.9, 0), Color(1.0, 0.4, 0.08), 1.6, 5.0)
		l.flicker_amount = 0.25
	var embers := CPUParticles3D.new()
	embers.position = mid + Vector3(0, 0.1, 0)
	embers.rotation.y = yaw
	embers.amount = maxi(8, roundi(length * 2.0))
	embers.lifetime = 2.2
	embers.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	embers.emission_box_extents = Vector3(width * 0.45, 0.02, length * 0.5)
	embers.gravity = Vector3(0, 0.5, 0)
	embers.initial_velocity_min = 0.1
	embers.initial_velocity_max = 0.4
	embers.scale_amount_min = 0.4
	embers.scale_amount_max = 1.0
	var spark := SphereMesh.new()
	spark.radius = 0.025
	spark.height = 0.05
	spark.material = Visuals.glow_mat(Color(1.0, 0.5, 0.1), 4.0)
	embers.mesh = spark
	parent.add_child(embers)
	var size := Vector2(absf(along.x), absf(along.z))
	if size.x >= size.y:
		size.y = width
	else:
		size.x = width
	return Rect2(Vector2(mid.x, mid.z) - size * 0.5, size)


## Pont de pierre (2,2 m) qui enjambe un ruisseau de lave en `pos`, dans le sens `along` du passage.
static func bridge(parent: Node3D, pos: Vector3, across: Vector3, stone: Material) -> void:
	var yaw := atan2(across.x, across.z)
	var slab := Visuals.box(parent, Vector3(1.8, 0.14, LAVA_WIDTH + 0.9), pos + Vector3(0, 0.08, 0), stone)
	slab.rotation.y = yaw
	var side := Vector3(cos(yaw), 0, -sin(yaw))
	for s: float in [-1.0, 1.0]:
		var rail := Visuals.box(parent, Vector3(0.12, 0.3, LAVA_WIDTH + 0.9), pos + side * s * 0.85 + Vector3(0, 0.25, 0), stone)
		rail.rotation.y = yaw


# --- Temple ---------------------------------------------------------------------------------

const GLASS_COLORS := [Color(0.85, 0.08, 0.1), Color(0.1, 0.25, 0.95), Color(0.1, 0.7, 0.3), Color(1.0, 0.75, 0.15),
	Color(0.55, 0.15, 0.85)]


## Vitrail en ogive contre un mur (`pos` au pied du mur, `inward` vers la salle) : verres de couleur lumineux sertis
## de plomb, et la lumière colorée qu'il projette dans la salle.
static func stained_glass(parent: Node3D, pos: Vector3, inward: Vector3, rng: RandomNumberGenerator) -> void:
	var w := Node3D.new()
	w.position = pos
	w.rotation.y = atan2(inward.x, inward.z)
	parent.add_child(w)
	var frame := Visuals.mat(Color(0.18, 0.17, 0.16), 0.9)
	var lead := Visuals.mat(Color(0.03, 0.03, 0.03), 0.6)
	Visuals.box(w, Vector3(1.3, 2.1, 0.08), Vector3(0, 1.45, 0.0), frame)
	Visuals.box(w, Vector3(1.05, 1.85, 0.03), Vector3(0, 1.4, 0.05), lead)
	var tint := Color.BLACK
	for row in 5:
		for col in 3:
			var c: Color = GLASS_COLORS[rng.randi() % GLASS_COLORS.size()]
			tint += c
			var pane := Visuals.box(w, Vector3(0.3, 0.32, 0.02), Vector3(-0.34 + col * 0.34, 0.65 + row * 0.36, 0.07), Visuals.glow_mat(c, 1.4))
			pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Visuals.sphere(w, 0.18, Vector3(0, 2.35, 0.07), Visuals.glow_mat(GLASS_COLORS[rng.randi() % GLASS_COLORS.size()], 1.6), Vector3(1.0, 1.0, 0.15)) # rosace
	var light := OmniLight3D.new()
	light.light_color = (tint / 15.0).lightened(0.2)
	light.light_energy = 1.2
	light.omni_range = 4.5
	light.position = Vector3(0, 1.6, 1.0)
	w.add_child(light)


## Banc d'église en bois sombre, tourné vers `yaw`.
static func pew(parent: Node3D, pos: Vector3, yaw: float) -> void:
	var p := Node3D.new()
	p.position = pos
	p.rotation.y = yaw
	parent.add_child(p)
	var wood := Visuals.mat(Color(0.22, 0.12, 0.06), 0.7)
	Visuals.box(p, Vector3(1.8, 0.08, 0.45), Vector3(0, 0.45, 0), wood)
	Visuals.box(p, Vector3(1.8, 0.55, 0.06), Vector3(0, 0.75, -0.22), wood)
	for s: float in [-1.0, 1.0]:
		Visuals.box(p, Vector3(0.07, 0.95, 0.5), Vector3(0.88 * s, 0.47, -0.02), wood)
	Visuals.solid(p, Vector3(1.8, 1.0, 0.5), Vector3(0, 0.5, 0))


## Candélabre de fer à trois bougies.
static func candelabra(parent: Node3D, pos: Vector3) -> void:
	var iron := Visuals.mat(Color(0.12, 0.11, 0.1), 0.4, 0.8)
	var wax := Visuals.mat(Color(0.9, 0.86, 0.75), 0.8)
	Visuals.cylinder(parent, 0.18, 0.22, 0.05, pos + Vector3(0, 0.03, 0), iron, Vector3.ZERO, 8)
	Visuals.cylinder(parent, 0.025, 0.03, 1.5, pos + Vector3(0, 0.78, 0), iron, Vector3.ZERO, 6)
	Visuals.box(parent, Vector3(0.5, 0.04, 0.04), pos + Vector3(0, 1.5, 0), iron)
	for k in 3:
		var p := pos + Vector3(-0.22 + k * 0.22, 1.6, 0)
		Visuals.cylinder(parent, 0.03, 0.03, 0.16, p, wax, Vector3.ZERO, 6)
		Visuals.sphere(parent, 0.025, p + Vector3(0, 0.11, 0), Visuals.glow_mat(Color(1.0, 0.75, 0.3), 6.0), Vector3(1.0, 1.6, 1.0))
	var l := Visuals.flicker_light(parent, pos + Vector3(0, 1.9, 0), Color(1.0, 0.72, 0.4), 1.4, 5.0)
	l.flicker_amount = 0.2
	Visuals.solid_cylinder(parent, 0.2, 1.8, pos + Vector3(0, 0.9, 0))


## Colonne de cathédrale (fût cannelé, chapiteau), plus haute que les murs.
static func column(parent: Node3D, pos: Vector3, stone: Material) -> void:
	Visuals.cylinder(parent, 0.5, 0.55, 0.3, pos + Vector3(0, 0.15, 0), stone, Vector3.ZERO, 8)
	Visuals.cylinder(parent, 0.36, 0.38, 3.2, pos + Vector3(0, 1.9, 0), stone, Vector3.ZERO, 12)
	Visuals.box(parent, Vector3(0.9, 0.25, 0.9), pos + Vector3(0, 3.6, 0), stone)
	Visuals.solid_cylinder(parent, 0.45, 3.0, pos + Vector3(0, 1.5, 0))


## Fontaine de la nef : l'ange déchu sculpté (trois fois la taille du héros) brandit une guitare infernale ; ce
## n'est pas de l'eau qui en jaillit, mais du sang, qui remplit le bassin. Regard vers `facing`.
static func blood_fountain(parent: Node3D, c: Vector3, facing: Vector3) -> void:
	var f := Node3D.new()
	f.position = c
	f.rotation.y = atan2(facing.x, facing.z)
	parent.add_child(f)
	var stone := Visuals.mat(Color(0.48, 0.46, 0.45), 0.85)
	var dark_stone := Visuals.mat(Color(0.2, 0.19, 0.19), 0.85)
	var blood := Visuals.mat(Color(0.35, 0.0, 0.01), 0.08)
	# Bassin octogonal plein de sang.
	Visuals.cylinder(f, 2.4, 2.5, 0.6, Vector3(0, 0.3, 0), dark_stone, Vector3.ZERO, 8)
	Visuals.cylinder(f, 2.15, 2.15, 0.05, Vector3(0, 0.55, 0), blood, Vector3.ZERO, 8)
	Visuals.cylinder(f, 0.7, 0.9, 1.3, Vector3(0, 1.15, 0), stone, Vector3.ZERO, 8) # piédestal
	# L'ange déchu (4,5 m) : robe, buste, tête baissée, ailes repliées vers le ciel, guitare levée.
	var statue := Node3D.new()
	statue.position = Vector3(0, 1.8, 0)
	f.add_child(statue)
	Visuals.cylinder(statue, 0.45, 0.75, 2.2, Vector3(0, 1.1, 0), stone, Vector3.ZERO, 10)
	Visuals.capsule(statue, 0.45, 1.3, Vector3(0, 2.6, 0), stone)
	Visuals.sphere(statue, 0.3, Vector3(0, 3.45, 0.08), stone, Vector3(0.9, 1.1, 0.95))
	for side: float in [-1.0, 1.0]:
		Visuals.sphere(statue, 0.045, Vector3(0.1 * side, 3.48, 0.33), Visuals.glow_mat(Color(1.0, 0.1, 0.05), 5.0)) # yeux
		Visuals.capsule(statue, 0.12, 1.0, Vector3(0.5 * side, 3.2, 0.2), stone, Vector3(-150, 0, -20 * side)) # bras levés
		var wing := DemonParts.feather_wing(statue, Vector3(0.2 * side, 3.0, -0.35), side, stone, 2.4)
		wing.rotation.x = -0.5
	var guitar := DemonParts.infernal_guitar(statue, 2.4)
	guitar.position = Vector3(0, 4.3, 0.35)
	guitar.rotation_degrees = Vector3(0, 0, 160)
	# Le sang jaillit des cordes de la guitare et retombe dans le bassin.
	var spout := CPUParticles3D.new()
	spout.position = Vector3(0, 5.2, 0.4)
	spout.amount = 90
	spout.lifetime = 1.6
	spout.direction = Vector3(0, 1, 0)
	spout.spread = 35.0
	spout.initial_velocity_min = 2.5
	spout.initial_velocity_max = 3.5
	spout.gravity = Vector3(0, -6.0, 0)
	spout.scale_amount_min = 0.6
	spout.scale_amount_max = 1.2
	var drop := SphereMesh.new()
	drop.radius = 0.06
	drop.height = 0.12
	drop.material = Visuals.mat(Color(0.5, 0.0, 0.02), 0.1)
	spout.mesh = drop
	f.add_child(spout)
	var up := OmniLight3D.new() # la statue éclairée par en dessous
	up.light_color = Color(0.75, 0.75, 1.0)
	up.light_energy = 1.6
	up.omni_range = 7.0
	up.position = Vector3(0, 2.5, 2.2)
	f.add_child(up)
	var glow := Visuals.flicker_light(f, Vector3(0, 1.2, 1.8), Color(1.0, 0.15, 0.1), 1.8, 7.0)
	glow.flicker_amount = 0.2
	Visuals.solid_cylinder(f, 2.5, 3.0, Vector3(0, 1.5, 0))
