class_name CaveTroll
extends Enemy
## Le troll des cavernes, boss des grottes des gobelins : le modèle 3D fourni par Ulysse (art/pnj « troll », peau
## bleu-vert, pantalon rapiécé), agrandi à 3,2 m, animé (repos d'orc, marche, course, coup, sursaut, mort, victoire),
## avec une massue faite d'un tronc d'arbre dans la main droite. Capacités :
##   • Coup de massue (au contact) et Écrasement (toutes les ~7 s) : un cercle devant lui, puis la massue s'abat ;
##   • Régénération : s'il n'a pas été touché depuis 3 s, il récupère 1,5 % de ses PV par seconde (il faut le harceler) ;
##   • À 50 % PV : il appelle ses gobelins à la rescousse (quatre d'un coup).

var spawn_minion: Callable # Callable(pos: Vector3) fourni par le niveau

var skin: CharacterSkin
## Moment de l'impact dans le clip « slash » (fraction de sa durée).
const STRIKE_AT := 0.55
var _smash_timer := 5.0
var _busy := false
var _called := false
var _intro_done := false
var _since_hit := 0.0
var _regen := 0.0
var _regen_fx: CPUParticles3D


func _configure() -> void:
	var lvl := level - 1
	display_name = "Le Troll des cavernes"
	is_boss = true
	max_hp = 260 + 35 * lvl
	armor_class = 14
	save_bonus = 4
	attack_bonus = 6 + floori(lvl / 2.0)
	damage_dice = Vector3i(2, 10, 3 + lvl)
	attack_range = 2.2
	attack_cooldown = 3.0
	detect_radius = 10.0
	lose_radius = 30.0
	xp_reward = 800 + 90 * lvl
	gold_range = Vector2i(60, 100)
	radius = 0.95
	height = 3.2
	wander_radius = 1.5
	move_speed = Balance.HERO_SPEED * 0.22


func _build_model() -> void:
	skin = CharacterSkin.create("troll")
	model.add_child(skin)
	_flash_mats.append_array(skin.flash_materials)
	# Massue : un tronc d'arbre noueux dans la main droite (vers l'avant au bout du poing, à la pose de repos).
	var club := Node3D.new()
	skin.place(club, "hand.R", Basis.IDENTITY, 0.08, Vector3.ZERO)
	var wood := Visuals.mat(Color(0.28, 0.18, 0.1), 0.9)
	Visuals.cylinder(club, 0.2, 0.08, 1.4, Vector3(0, 0.0, 0.55), wood, Vector3(90, 0, 0), 8)
	for k in 4:
		Visuals.sphere(club, 0.08, Vector3(randf_range(-0.15, 0.15), randf_range(-0.15, 0.15), 0.9 + k * 0.1), wood)
	skin.attach("hand.R", club)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.75, 0.4)
	glow.light_energy = 1.2
	glow.omni_range = 5.0
	glow.position = Vector3(0, 3.6, 1.2)
	model.add_child(glow)
	_regen_fx = CPUParticles3D.new()
	_regen_fx.position.y = 1.8
	_regen_fx.amount = 18
	_regen_fx.lifetime = 1.0
	_regen_fx.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_regen_fx.emission_sphere_radius = 1.0
	_regen_fx.gravity = Vector3(0, 1.2, 0)
	var dot := SphereMesh.new()
	dot.radius = 0.05
	dot.height = 0.1
	dot.material = Visuals.glow_mat(Color(0.4, 1.0, 0.35), 2.0)
	_regen_fx.mesh = dot
	_regen_fx.emitting = false
	model.add_child(_regen_fx)


func _animate(delta: float, _moving: bool) -> void:
	skin.step(delta, _speed_now > 0.05, _speed_now)


## Coup de massue : le clip « slash » étiré pour que l'impact tombe à la fin de l'élan.
func _attack_anim(windup: float) -> void:
	skin.action("slash", windup / STRIKE_AT)


func _flash() -> void:
	if skin != null:
		skin.hurt()
	super()


func _aggro() -> void:
	var was_wandering := state == State.WANDER
	super._aggro()
	if was_wandering and not _intro_done:
		_intro_done = true
		Sfx.play("croak", 0.0, 0.0)
		Events.camera_shake.emit(0.3, 0.7)
		Events.notify("Le Troll des cavernes : « QUI... FAIT... DU BRUIT... DANS... MA... GROTTE ? »", Color(0.6, 0.85, 0.45))
		Events.boss_health.emit(display_name, hp, max_hp)


func take_damage(amount: int, from: Vector3, knockback: float = 0.0, crit: bool = false, kind: String = "phys") -> void:
	_since_hit = 0.0
	super.take_damage(amount, from, knockback, crit, kind)


func _update_special(delta: float, dist: float) -> void:
	if state == State.WANDER or state == State.DEAD:
		return
	_update_regen(delta / attack_speed) # (delta accéléré pour les attaques des boss ; la régénération, elle, ne l'est pas)
	if not _called and hp <= max_hp / 2.0:
		_call_goblins()
	if _busy:
		return
	_smash_timer -= delta
	if _smash_timer <= 0.0 and dist < 6.0:
		_smash()


## Régénération du troll : sans coup reçu depuis 3 s, il récupère 1,5 % de ses PV par seconde.
func _update_regen(delta: float) -> void:
	_since_hit += delta
	var healing := _since_hit >= 3.0 and hp < max_hp
	_regen_fx.emitting = healing
	if not healing:
		return
	_regen += max_hp * 0.015 * delta
	if _regen >= 1.0:
		var gain := floori(_regen)
		_regen -= gain
		hp = mini(max_hp, hp + gain)
		_update_hp_bar()


## Écrasement : la massue s'abat devant lui, sur un cercle de 2,4 m.
func _smash() -> void:
	_busy = true
	_smash_timer = 7.0
	var front := global_position + Vector3(sin(model.rotation.y), 0, cos(model.rotation.y)) * 2.4
	skin.action("slash", 1.1 / STRIKE_AT) # la massue s'abat au moment de l'impact
	await BossMoves.strike(self, front, 2.4, 1.1, Vector3i(3, 8, 3 + level), "rock")
	_busy = false


func _call_goblins() -> void:
	_called = true
	Sfx.play("croak", 0.0, 0.2)
	skin.action("victory", 1.4) # il beugle, bras levés
	Events.notify("Le troll beugle : « GOBELINS ! À MOI ! » Des pas précipités résonnent dans la grotte...", Events.COLOR_BAD)
	if spawn_minion.is_valid():
		for k in 4:
			var a := TAU * k / 4.0 + 0.4
			spawn_minion.call(global_position + Vector3(cos(a), 0, sin(a)) * 4.0)


func _drop_loot() -> void:
	super._drop_loot()
	loot.append({"kind": "potion"})


func _die() -> void:
	_regen_fx.emitting = false
	super._die()
	Events.boss_health.emit(display_name, 0, max_hp)
	Events.boss_defeated.emit("troll")


func _death_anim() -> void:
	Sfx.play("boom", 0.0)
	Events.camera_shake.emit(0.5, 1.0)
	skin.die()
	_corpse(3.0)
