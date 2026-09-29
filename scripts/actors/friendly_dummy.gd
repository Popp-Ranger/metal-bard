class_name FriendlyDummy
extends Node3D
## Cible amicale (sous-sol de la taverne) pour essayer les sorts de soins.
## Elle fait partie du groupe « allies », comme le héros (et, plus tard, les autres
## joueurs en coopération) : les sorts de soin de groupe la soignent aussi.
## Elle perd lentement des PV pour qu'on puisse toujours la soigner.

var max_hp := 100
var hp := 50
var _label: Label3D
var _bar_fill: MeshInstance3D
var _drain := 0.0
var _body: Node3D


func _ready() -> void:
	add_to_group("allies")
	_body = Node3D.new()
	add_child(_body)
	var wood := Visuals.mat(Color(0.35, 0.22, 0.12), 0.8)
	var straw := Visuals.mat(Color(0.75, 0.62, 0.3), 0.95)
	Visuals.cylinder(_body, 0.06, 0.06, 1.8, Vector3(0, 0.9, 0), wood, Vector3.ZERO, 8)
	Visuals.cylinder(_body, 0.35, 0.45, 0.08, Vector3(0, 0.04, 0), wood, Vector3.ZERO, 12)
	Visuals.capsule(_body, 0.3, 0.8, Vector3(0, 1.15, 0), straw)
	Visuals.box(_body, Vector3(0.64, 0.7, 0.05), Vector3(0, 1.15, 0.3), Visuals.mat(Color(0.15, 0.5, 0.2))) # tabard vert
	Visuals.box(_body, Vector3(0.1, 0.4, 0.06), Vector3(0, 1.2, 0.33), Visuals.mat(Color(0.95, 0.95, 0.9)))
	Visuals.box(_body, Vector3(0.3, 0.1, 0.06), Vector3(0, 1.25, 0.33), Visuals.mat(Color(0.95, 0.95, 0.9)))
	Visuals.sphere(_body, 0.2, Vector3(0, 1.75, 0), straw)
	Visuals.label(self, "Cible amicale (soins)", Vector3(0, 2.55, 0), Color(0.5, 1.0, 0.55), 30)
	_label = Visuals.label(self, "", Vector3(0, 2.3, 0), Color(0.85, 1.0, 0.85), 26)
	var bar_bg := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 0.1)
	bar_bg.mesh = q
	var bg := StandardMaterial3D.new()
	bg.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg.albedo_color = Color(0.05, 0.05, 0.05)
	bg.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	bg.billboard_keep_scale = true
	bg.no_depth_test = true
	bar_bg.material_override = bg
	bar_bg.position.y = 2.1
	add_child(bar_bg)
	_bar_fill = MeshInstance3D.new()
	var q2 := QuadMesh.new()
	q2.size = Vector2(0.96, 0.07)
	_bar_fill.mesh = q2
	var fg := bg.duplicate() as StandardMaterial3D
	fg.albedo_color = Color(0.3, 0.9, 0.35)
	fg.render_priority = 1
	_bar_fill.material_override = fg
	_bar_fill.position.y = 2.1
	add_child(_bar_fill)


func _process(delta: float) -> void:
	# Perd 2 PV par seconde jusqu'à 20 % (il a toujours besoin de soins).
	_drain += delta * 2.0
	if _drain >= 1.0:
		var d := floori(_drain)
		_drain -= d
		hp = maxi(roundi(max_hp * 0.2), hp - d)
	_label.text = "%d / %d PV" % [hp, max_hp]
	_bar_fill.scale.x = clampf(float(hp) / max_hp, 0.01, 1.0)


## Appelé par les sorts de soin de groupe.
func receive_heal(amount: int) -> void:
	var gained := mini(amount, max_hp - hp)
	hp += gained
	DamageNumber.spawn(get_parent(), global_position + Vector3(0, 2.2, 0), "+%d" % amount, Events.COLOR_GOOD)
	var tw := create_tween()
	tw.tween_property(_body, "scale", Vector3(1.08, 1.08, 1.08), 0.1)
	tw.tween_property(_body, "scale", Vector3.ONE, 0.2)
