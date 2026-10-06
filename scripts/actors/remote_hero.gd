class_name RemoteHero
extends Node3D
## Un autre joueur de la partie (coopération) : son personnage tel qu'il l'a créé
## (apparence, nom, niveau), déplacé d'après l'état qu'il envoie ~15 fois par seconde.
## Chez l'hôte, les ennemis peuvent le prendre pour cible : les coups sont transmis à
## son propriétaire. Les soins de groupe le soignent aussi (groupe « allies »).
## Ses sorts (éclairs, ondes, bouclier, amplis...) sont rejoués ici par SpellFx.

var peer_id := 0
var profile := {}
var dead := false
var radius := 0.35
var hp := 1
var max_hp := 1

var model: HeroModel
var _target_pos := Vector3.ZERO
var _target_yaw := 0.0
var _flags := 0
var _label: Label3D
var _hp_label: Label3D
var _shield: MeshInstance3D


func _ready() -> void:
	add_to_group("heroes")
	add_to_group("allies")
	model = HeroModel.new()
	model.move_speed = Balance.HERO_SPEED
	var look: Dictionary = profile.get("appearance", {}).duplicate()
	for key: String in RaceDB.DEFAULT_APPEARANCE:
		if not look.has(key):
			look[key] = RaceDB.DEFAULT_APPEARANCE[key]
	model.appearance = look
	add_child(model)
	radius = 0.35 * model.scale.x
	_target_pos = position
	var top := model.height() + 0.35
	_label = Visuals.label(self, "%s (niv. %d)" % [str(profile.get("name", "?")), int(profile.get("level", 1))],
		Vector3(0, top + 0.2, 0), Color(0.55, 0.85, 1.0), 34)
	_hp_label = Visuals.label(self, "", Vector3(0, top, 0), Color(0.9, 0.4, 0.35), 26)
	var halo := OmniLight3D.new()
	halo.position = Vector3(0.8, 2.6, 0.8)
	halo.light_color = Color(0.7, 0.8, 1.0)
	halo.light_energy = 1.0
	halo.omni_range = 7.0
	add_child(halo)


func apply_state(pos: Vector3, yaw: float, flags: int, net_hp: int, net_max_hp: int) -> void:
	var was_dashing := (_flags & 4) != 0
	var was_soloing := (_flags & 2) != 0
	_target_pos = pos
	_target_yaw = yaw
	_flags = flags
	hp = net_hp
	max_hp = maxi(1, net_max_hp)
	model.tired = hp <= max_hp * 0.3
	_hp_label.text = "%d / %d PV" % [hp, max_hp]
	var now_dead := (flags & 8) != 0
	if now_dead and not dead:
		model.die()
	dead = now_dead
	if (flags & 4) != 0 and not was_dashing:
		model.knee_slide(0.6)
	if ((flags & 2) != 0) != was_soloing:
		model.solo_pose((flags & 2) != 0)


func _process(delta: float) -> void:
	global_position = global_position.lerp(_target_pos, 1.0 - exp(-14.0 * delta))
	model.rotation.y = lerp_angle(model.rotation.y, _target_yaw, 1.0 - exp(-14.0 * delta))
	model.set_moving((_flags & 1) != 0)
	var level := Level.of(self)
	model.set_guitar_slung((level != null and not level.spells_allowed_at(global_position)) or (_flags & 16) != 0)
	model.set_guitar_shown((_flags & 32) == 0) # bit 32 : ce joueur n'a pas de guitare équipée


## Mur de Larsen de ce joueur (SpellFx « shield ») : bulle affichée chez les autres joueurs.
func set_shield_visible(on: bool) -> void:
	if _shield == null:
		if not on:
			return
		_shield = SpellFx.shield_bubble(self, model.scale.y)
	_shield.visible = on


## Appelé par les ennemis de l'hôte : le propriétaire encaisse le coup chez lui.
func take_hit(amount: int, from: Vector3, _attacker: Node3D = null) -> void:
	if not dead:
		Net.hit_player(peer_id, amount, from)


func receive_heal(amount: int) -> void:
	if not dead:
		Net.heal_player(peer_id, amount)
		DamageNumber.spawn(get_parent(), global_position + Vector3(0, 2.3, 0), "+%d" % amount, Events.COLOR_GOOD)
