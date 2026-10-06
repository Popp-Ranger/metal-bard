class_name Minotaur
extends Enemy
## LE MINOTAURE, gardien du trésor du Labyrinthe du Destin : le modèle 3D fourni par Ulysse (art/pnj « minotaure »,
## taureau noir aux yeux rouges, pantalon rouge rapiécé, sabots), agrandi à 3,3 m, animé (repos d'orc, marche, course,
## coups, sursaut, mort, victoire, headbang pendant le duel), avec une hache à double tranchant. Capacités :
##   • Coup de hache (au contact) et Fendoir (toutes les ~7 s) : un cercle devant lui, puis la hache s'abat ;
##   • Charge (toutes les ~8 s, si le héros est loin) : une traînée de cercles jusqu'au héros, puis il fonce et
##     renverse tout sur son passage (il s'arrête devant les murs) ;
##   • À 5 % de PV, il jette sa hache, sort sa guitare et IMPOSE UN DUEL : le héros doit jouer le solo
##     (audio/riffs/edge_of_the_cliff.mp3) avec au moins 80 % de notes justes. Gagné : le Minotaure s'incline et tombe.
##     Perdu : il ricane, foudroie le héros d'un accord, reprend 35 % de ses PV, et le combat continue (nouveau
##     duel à 5 %). Pendant le duel, il est intouchable.
## Butin : le Pick du Destin (objet de quête).

## Callable() fourni par le niveau : lance le duel (dialogue, puis mini-jeu).
var duel_requested: Callable
var dueling := false
## Seuil du duel : 5 % des PV max.
const DUEL_AT := 0.05
const DUEL_LOSS_HEAL := 0.35
## Joueur qui joue le duel (identifiant réseau ; 1 : l'hôte, ou hors ligne).
var duelist := 1
## Coopération : si le duelliste ne revient pas (déconnecté), le Minotaure reprend le combat au bout de ce délai (s).
const DUEL_TIMEOUT := 150.0
var _duel_time := 0.0

var skin: CharacterSkin
## Moment de l'impact dans les clips « slash » et « smash » (fraction de leur durée).
const STRIKE_AT := 0.55
const SMASH_AT := 0.7
var _axe: Node3D
var _guitar: Node3D
var _eyes: OmniLight3D
var _solo_t := 0.0
var _cleave_timer := 5.0
var _charge_timer := 6.0
var _busy := false
var _intro_done := false
var _phase := 1


func _ready() -> void:
	super()
	Net.story_received.connect(_on_story)


func _configure() -> void:
	var lvl := level - 1
	display_name = "Le Minotaure"
	is_boss = true
	max_hp = 340 + 45 * lvl
	armor_class = 15
	save_bonus = 5
	attack_bonus = 7 + floori(lvl / 2.0)
	damage_dice = Vector3i(2, 10, 4 + lvl)
	attack_range = 2.2
	detect_radius = 11.0
	lose_radius = 34.0
	xp_reward = 1400 + 150 * lvl
	gold_range = Vector2i(120, 200)
	radius = 0.95
	height = 3.3
	wander_radius = 2.0
	move_speed = Balance.HERO_SPEED * 0.3


func _build_model() -> void:
	skin = CharacterSkin.create("minotaure")
	model.add_child(skin)
	_flash_mats.append_array(skin.flash_materials)
	var iron := Visuals.mat(Color(0.3, 0.29, 0.3), 0.35, 0.8)
	# Hache à double tranchant dans la main droite (vers l'avant au bout du poing, à la pose de repos ; mesures avant
	# l'agrandissement du modèle).
	_axe = Node3D.new()
	skin.place(_axe, "hand.R", Basis.IDENTITY, 0.08, Vector3.ZERO)
	Visuals.cylinder(_axe, 0.035, 0.035, 1.55, Vector3(0, 0.0, 0.3), Visuals.mat(Color(0.22, 0.14, 0.07), 0.8), Vector3(90, 0, 0), 6)
	for s: float in [-1.0, 1.0]:
		Visuals.cylinder(_axe, 0.32, 0.32, 0.04, Vector3(0, 0.2 * s, 0.9), iron, Vector3(0, 0, 90), 12) # lames en demi-lune
	Visuals.sphere(_axe, 0.07, Vector3(0, 0, 0.9), iron)
	skin.attach("hand.R", _axe)
	# Guitare du duel (cachée jusqu'au duel) : en travers du ventre, manche vers sa main gauche.
	_guitar = Node3D.new()
	var y := Vector3(0.8, 0.6, 0.0).normalized()
	var z := Vector3(0.0, 0.0, 1.0)
	skin.place(_guitar, "chest", Basis(y.cross(z), y, z), 0.0, Vector3(0.38, 0.06, 0.42))
	DemonParts.infernal_guitar(_guitar, 0.95)
	_guitar.visible = false
	skin.attach("chest", _guitar)
	# Regard rouge (il s'embrase à mi-vie) et lumière d'arène.
	_eyes = OmniLight3D.new()
	_eyes.light_color = Color(1.0, 0.25, 0.1)
	_eyes.light_energy = 0.6
	_eyes.omni_range = 1.6
	skin.place(_eyes, "head", Basis.IDENTITY, 0.12, Vector3(0, 0, 0.3))
	skin.attach("head", _eyes)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.75, 0.45)
	glow.light_energy = 1.2
	glow.omni_range = 5.0
	glow.position = Vector3(0, 3.8, 1.3)
	model.add_child(glow)


func _animate(delta: float, _moving: bool) -> void:
	if dueling:
		# Il joue : headbang en boucle.
		_solo_t -= delta
		if _solo_t <= 0.0:
			_solo_t = float(skin.lengths.get("headbang", 1.0))
			skin.action("headbang", _solo_t)
	skin.step(delta, _speed_now > 0.05 and not dueling, _speed_now)


## Coup de hache : le clip « slash » étiré pour que l'impact tombe à la fin de l'élan.
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
		Events.camera_shake.emit(0.35, 0.8)
		Events.notify("Le Minotaure : « Le Pick du Destin ? Il faudra me passer sur le corps, petit troubadour. »", Color(1.0, 0.55, 0.35))
		Events.boss_health.emit(display_name, hp, max_hp)


## Seuil du duel (5 % des PV max, au moins 1).
func duel_threshold() -> int:
	return maxi(1, ceili(max_hp * DUEL_AT))


## Pendant le duel, il est intouchable ; le coup qui le ferait passer sous 5 % s'arrête à 5 % et déclenche le duel.
func take_damage(amount: int, from: Vector3, knockback: float = 0.0, crit: bool = false, kind: String = "phys") -> void:
	if state == State.DEAD:
		return
	if dueling:
		DamageNumber.spawn(get_parent(), global_position + Vector3(0, height + 0.3, 0), "Duel !", Color(1.0, 0.8, 0.3))
		return
	amount = resist(amount) # boss : -10 % (avant le seuil du duel)
	_resisted = true
	var limit := duel_threshold()
	if not remote_controlled and hp > limit and hp - amount <= limit:
		super.take_damage(hp - limit, from, 0.0, crit, kind)
		_resisted = false
		start_duel(Net.damage_source)
		return
	super.take_damage(amount, from, knockback, crit, kind)
	_resisted = false


## Il jette sa hache, sort sa guitare et impose le duel à `peer` : le joueur qui l'a fait tomber à 5 % (coopération :
## lui seul joue le duel, les autres le regardent en direct ; hors ligne, 1 = soi).
func start_duel(peer: int = 1) -> void:
	if dueling or state == State.DEAD:
		return
	dueling = true
	duelist = peer
	_duel_time = 0.0
	_busy = true
	state = State.STAGGER
	_stagger = 9999.0
	_solo_t = 0.0
	_axe.visible = false
	_guitar.visible = true
	Sfx.play("solo_thunder", -2.0)
	Events.camera_shake.emit(0.3, 0.6)
	if not remote_controlled:
		Net.send_story("duel_start", {"enemy": net_id, "duelist": peer}) # l'hôte prévient le groupe
	if peer == Net.my_id():
		if duel_requested.is_valid():
			duel_requested.call()
	else:
		Events.notify("Le Minotaure jette sa hache et défie %s en duel de guitare !" % Net.player_name(peer), Color(1.0, 0.55, 0.35))


## Résultat du duel, chez le joueur qui l'a joué (`hero_won` : 80 % au moins). L'hôte l'applique et prévient le groupe ;
## un client le lui envoie.
func duel_result(hero_won: bool) -> void:
	if remote_controlled:
		Net.send_story("duel_result", {"enemy": net_id, "won": hero_won})
		_end_duel_visual(hero_won)
		return
	_apply_duel_result(hero_won)


func _apply_duel_result(hero_won: bool) -> void:
	if not dueling:
		return
	Net.send_story("duel_end", {"enemy": net_id, "won": hero_won})
	if hero_won:
		lose_duel()
	else:
		win_duel()


## Chez un client : fin du duel joué par un autre (l'hôte fait autorité ; sa mort arrive avec ses PV).
func _end_duel_visual(hero_won: bool) -> void:
	dueling = false
	_guitar.visible = false
	if not hero_won:
		_axe.visible = true
		skin.action("victory", 1.4)


## Duel partagé (coopération) : début (chez les clients), résultat du duelliste (chez l'hôte), fin (chez les clients).
func _on_story(event: String, data: Dictionary, _peer: int) -> void:
	if int(data.get("enemy", -1)) != net_id:
		return
	match event:
		"duel_start":
			if remote_controlled:
				start_duel(int(data.get("duelist", 1)))
		"duel_result":
			if not remote_controlled:
				_apply_duel_result(bool(data.get("won", false)))
		"duel_end":
			if remote_controlled:
				_end_duel_visual(bool(data.get("won", false)))


## Le héros a gagné le duel : le Minotaure s'incline et tombe.
func lose_duel() -> void:
	if not dueling:
		return
	dueling = false
	_stagger = 0.0
	hp = 0
	_update_hp_bar()
	_die()


## Le héros a perdu le duel : il reprend des forces (35 % des PV) et le combat reprend.
func win_duel() -> void:
	if not dueling:
		return
	dueling = false
	hp = maxi(hp, roundi(max_hp * DUEL_LOSS_HEAL))
	_update_hp_bar()
	_guitar.visible = false
	_axe.visible = true
	skin.action("victory", 1.4) # il ricane, bras levés
	_stagger = 0.0
	state = State.CHASE
	_busy = false
	_charge_timer = 4.0
	_cleave_timer = 3.0


func _update_special(delta: float, dist: float) -> void:
	if dueling and duelist != Net.my_id():
		_duel_time += delta
		if _duel_time > DUEL_TIMEOUT:
			_apply_duel_result(false)
	if state == State.WANDER or state == State.DEAD or dueling:
		return
	if _phase == 1 and hp <= max_hp / 2.0:
		_phase = 2
		_eyes.light_energy = 2.5
		Sfx.play("croak", 0.0, 0.1)
		Events.notify("Le Minotaure gratte le sol de ses sabots, naseaux fumants...", Events.COLOR_BAD)
	if _busy:
		return
	_cleave_timer -= delta
	_charge_timer -= delta
	if _charge_timer <= 0.0 and dist > 4.0 and dist < 16.0:
		_charge()
	elif _cleave_timer <= 0.0 and dist < 5.0:
		_cleave()


## Fendoir : la hache s'abat sur un cercle de 2,5 m devant lui.
func _cleave() -> void:
	_busy = true
	_cleave_timer = 7.0 if _phase == 1 else 5.0
	var front := global_position + Vector3(sin(model.rotation.y), 0, cos(model.rotation.y)) * 2.3
	skin.action("smash", 1.0 / SMASH_AT) # la hache s'abat au moment de l'impact
	await BossMoves.strike(self, front, 2.5, 1.0, Vector3i(3, 8, 3 + level), "slam")
	_busy = false


## Charge : traînée de cercles jusqu'au héros (pas au-delà d'un mur), puis il fonce dessus.
func _charge() -> void:
	if hero == null or not is_instance_valid(hero):
		return
	_busy = true
	_charge_timer = 8.0 if _phase == 1 else 6.0
	var start := global_position
	var dir := hero.global_position - start
	dir.y = 0.0
	var length := minf(dir.length() + 2.0, 14.0)
	dir = dir.normalized()
	# On s'arrête avant le premier obstacle.
	var reach := 0.0
	while reach + 0.5 <= length:
		var p := start + dir * (reach + 0.5)
		if walkable_check.is_valid() and not bool(walkable_check.call(p)):
			break
		reach += 0.5
	if reach < 2.0:
		_busy = false
		return
	var steps := maxi(2, ceili(reach / 2.2))
	Sfx.play("croak", -2.0, 0.1)
	for k in steps:
		var t := float(k + 1) / steps
		BossMoves.strike(self, start + dir * reach * t, 1.3, 1.1 + t * 0.35, Vector3i(2, 10, 2 + level), "slam")
	model.rotation.y = atan2(dir.x, dir.z)
	skin.action("victory", 1.1) # il beugle avant de foncer
	await get_tree().create_timer(1.1, false).timeout
	if state == State.DEAD or dueling:
		_busy = false
		return
	var tw := create_tween()
	tw.tween_property(self, "global_position", start + dir * reach, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	Events.camera_shake.emit(0.25, 0.3)
	await get_tree().create_timer(0.5, false).timeout
	_busy = false


## Le Pick du Destin (et une potion) restent sur son corps.
func _drop_loot() -> void:
	super._drop_loot()
	loot.append({"kind": "quest", "item": "pick_du_destin"})
	loot.append({"kind": "potion"})


func _die() -> void:
	dueling = false
	super._die()
	Events.boss_health.emit(display_name, 0, max_hp)
	Events.boss_defeated.emit("minotaure")


func _death_anim() -> void:
	Sfx.play("boom", 0.0)
	Events.camera_shake.emit(0.5, 1.2)
	_guitar.visible = false
	skin.die()
	_corpse(3.0)
