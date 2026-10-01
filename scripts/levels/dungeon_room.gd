@tool
class_name DungeonRoom
extends Node3D
## Salle d'un donjon fait main (scène DungeonMap). Son coin nord-ouest (le plus petit x et z) est sa
## position, aimantée sur la grille de 2 m ; `size` est sa taille en cases. Une salle a des portes là où
## arrivent les couloirs, reste dans le noir tant qu'on ne l'a pas ouverte, et ses occupants dorment
## jusque-là. Il faut une salle de départ et une salle du boss (Gloubah, sa cage, scellée par la clé
## du chef des squelettes) ; la salle du boss doit faire au moins 11 × 11 cases.

enum Kind { NORMALE, DEPART, BOSS }
const COLORS := [Color(0.3, 0.8, 1.0), Color(0.3, 1.0, 0.4), Color(1.0, 0.3, 0.25)]
const NAMES := ["Salle", "Salle de départ", "Salle du boss"]

@export_enum("Normale", "Départ", "Boss") var kind := 0:
	set(value):
		kind = value
		_refresh()
@export var size := Vector2i(10, 10):
	set(value):
		size = Vector2i(maxi(value.x, 3), maxi(value.y, 3))
		_refresh()
## Remplit de sol (GridMap « Sol » du donjon) toutes les cases de la salle.
@export_tool_button("Peindre le sol de la salle") var paint_floor := _paint_floor

var _outline: Node3D


func _ready() -> void:
	set_notify_transform(true)
	_refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and Engine.is_editor_hint():
		var snapped := Vector3(roundf(position.x / DungeonDecor.CELL) * DungeonDecor.CELL, 0.0,
			roundf(position.z / DungeonDecor.CELL) * DungeonDecor.CELL)
		if not snapped.is_equal_approx(position) or rotation != Vector3.ZERO:
			transform = Transform3D(Basis.IDENTITY, snapped)


## Rectangle de la salle en cases de la grille (cases de 2 m, même repère que la GridMap).
func rect() -> Rect2i:
	var origin := Vector2i(roundi(position.x / DungeonDecor.CELL), roundi(position.z / DungeonDecor.CELL))
	return Rect2i(origin, size)


func _paint_floor() -> void:
	var map := get_parent() as DungeonMap
	if map == null or map.floor_map() == null:
		push_warning("La salle doit être un enfant direct du donjon (DungeonMap), qui contient la GridMap « Sol ».")
		return
	var r := rect()
	var grid := map.floor_map()
	for z in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			grid.set_cell_item(Vector3i(x, 0, z), DungeonMap.FLOOR_TILE)


## Contour et nom de la salle dans l'éditeur (rien n'est enregistré dans la scène).
func _refresh() -> void:
	if Engine.is_editor_hint() and is_inside_tree():
		build_preview()


## Construit l'aperçu (appelé par l'éditeur ; public pour les captures de contrôle).
func build_preview() -> void:
	if _outline != null:
		_outline.queue_free()
	_outline = Node3D.new()
	add_child(_outline, false, Node.INTERNAL_MODE_FRONT)
	var w := size.x * DungeonDecor.CELL
	var d := size.y * DungeonDecor.CELL
	var color: Color = COLORS[kind]
	var mesh := ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.no_depth_test = true
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, mat)
	for y: float in [0.05, DungeonDecor.WALL_HEIGHT]:
		var corners: Array[Vector3] = [Vector3(0, y, 0), Vector3(w, y, 0), Vector3(w, y, d), Vector3(0, y, d)]
		for k in 4:
			mesh.surface_add_vertex(corners[k])
			mesh.surface_add_vertex(corners[(k + 1) % 4])
	for c: Vector3 in [Vector3(0, 0, 0), Vector3(w, 0, 0), Vector3(w, 0, d), Vector3(0, 0, d)]:
		mesh.surface_add_vertex(c)
		mesh.surface_add_vertex(c + Vector3(0, DungeonDecor.WALL_HEIGHT, 0))
	mesh.surface_end()
	var lines := MeshInstance3D.new()
	lines.mesh = mesh
	_outline.add_child(lines)
	var tint := Visuals.box(_outline, Vector3(w, 0.02, d), Vector3(w * 0.5, 0.06, d * 0.5),
		Visuals.transparent_mat(Color(color.r, color.g, color.b, 0.12)))
	tint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var label := Visuals.label(_outline, "%s (%d × %d)" % [NAMES[kind], size.x, size.y], Vector3(w * 0.5, 3.2, d * 0.5), color, 48)
	label.no_depth_test = true
