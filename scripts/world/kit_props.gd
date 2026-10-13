class_name KitProps
extends RefCounted
## Pièces des kits d'assets tiers (assets/models/kits/, voir son LISEZMOI) : maillages et emprises gardés en cache,
## pose d'une pièce au sol. Chemins relatifs à kits/ (« halloween/grave_A.gltf », « cimetiere/coffin.glb »...).
## Utilisé par le Cimetière maudit (necropolis.gd) et l'intro (cimetière de Morneval).

const KITS := "res://assets/models/kits/"

static var _pieces := {}
static var _aabbs := {}


## Maillage d'une pièce et son repère dans le fichier : [Mesh, Transform3D].
static func piece(path: String) -> Array:
	if not _pieces.has(path):
		var inst := (load(KITS + path) as PackedScene).instantiate() as Node3D
		var mi: MeshInstance3D = null
		for n in inst.find_children("*", "MeshInstance3D", true, false):
			mi = n as MeshInstance3D
			break
		var xf := Transform3D.IDENTITY
		var n: Node = mi
		while n != null and n != inst:
			if n is Node3D:
				xf = (n as Node3D).transform * xf
			n = n.get_parent()
		_pieces[path] = [mi.mesh, xf]
		inst.free()
	return _pieces[path]


## Emprise d'une pièce (toutes ses parties, échelle 1).
static func aabb(path: String) -> AABB:
	if not _aabbs.has(path):
		var inst := (load(KITS + path) as PackedScene).instantiate() as Node3D
		var acc: Array = [null]
		_merge(inst, Transform3D.IDENTITY, acc)
		_aabbs[path] = acc[0] if acc[0] != null else AABB()
		inst.free()
	return _aabbs[path]


static func _merge(n: Node, xf: Transform3D, acc: Array) -> void:
	var t := xf
	if n is Node3D:
		t = xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var a: AABB = t * (n as MeshInstance3D).mesh.get_aabb()
		acc[0] = a if acc[0] == null else (acc[0] as AABB).merge(a)
	for c in n.get_children():
		_merge(c, t, acc)


## Pose la pièce `path` dans `parent`, au sol en `pos` (sa hauteur est gardée), tournée de `yaw`, à l'échelle `s` ;
## `centered` : l'emprise de la pièce est centrée sur `pos`.
static func place(parent: Node, path: String, pos: Vector3, yaw: float = 0.0, s: float = 1.0, centered: bool = false) -> Node3D:
	var inst := (load(KITS + path) as PackedScene).instantiate() as Node3D
	var basis := Basis(Vector3.UP, yaw)
	var origin := pos
	if centered:
		var box := aabb(path)
		var mid := (box.position + box.size * 0.5) * s
		origin -= basis * Vector3(mid.x, 0, mid.z)
	inst.transform = Transform3D(basis.scaled(Vector3.ONE * s), origin)
	parent.add_child(inst)
	return inst


## Centre au sol et taille (échelle `s`) de l'emprise d'une pièce posée comme avec place().
static func footprint(path: String, pos: Vector3, yaw: float, s: float, centered: bool) -> Array:
	var box := aabb(path)
	var mid := (box.position + box.size * 0.5) * s
	var basis := Basis(Vector3.UP, yaw)
	var center := pos if centered else pos + basis * Vector3(mid.x, 0, mid.z)
	return [Vector3(center.x, 0.0, center.z), box.size * s]
