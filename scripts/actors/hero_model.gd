class_name HeroModel
extends Node3D
## Apparence du héros, construite selon le personnage créé (RaceDB) :
## sexe, race (taille et carrure), cornes, défenses, barbe, coiffure longue, couleur de cheveux.
## Tenue commune : manteau de cuir noir, médaillon à cornes (hommage à Ronnie James Dio).
## Les PNJ ont leur propre tenue (appearance["outfit"]) et pas de guitare.
## Il joue d'une réplique de Gibson Flying V, portée bas à la sangle comme un guitariste
## de metal. Debout, il a la posture et la démarche de Riffald (mêmes clips Mixamo, voir
## LocoAnimator) ; assis, en solo, en glissade, au lit ou mort, le squelette procédural prend
## le relais (ancienne posture voûtée des Réprouvés de World of Warcraft). Le modèle regarde vers +Z.
##
## Les bras sont pilotés par une petite IK à deux os : la main gauche reste sur le manche,
## la main droite gratte les cordes (ou empoigne le manche pour frapper).

const UPPER_ARM := 0.29
const FOREARM := 0.26
const THIGH := 0.45
const SHIN := 0.43
const HIP_Y := 0.93 # hauteur du bassin pour un personnage de 1,8 m
const HIP_HALF_WIDTH := 0.1 # écart des hanches de part et d'autre du bassin
const HEAD_SCALE := 0.78 # tête ≈ 1/7,5 de la taille (proportions réalistes)
const TORSO_LEAN := 0.12 # dos légèrement voûté (attitude metal)
## Doigts : longueur des phalanges (proximale, moyenne, distale) ; le pouce en a deux.
const PHALANGES := [0.034, 0.024, 0.019]
## Guitariste droitier : manche vers la gauche du héros (+X, le modèle regarde vers +Z), caisse sur
## la hanche droite, main gauche sur les cases, main droite qui gratte. Attention : les pivots de bras
## « _l » sont du côté -X (anatomiquement la main DROITE) et « _r » du côté +X (main GAUCHE).
const GUITAR_REST := Vector3(-0.38, 0.0, -0.8) # manche vers le haut, à gauche du héros, table face au public
const GUITAR_REST_POS := Vector3(-0.04, 0.06, 0.26)
const GUITAR_SOLO := Vector3(-0.5, 0.0, -0.5) # manche dressé vers le ciel pour le solo
const GUITAR_WINDUP := Vector3(-0.6, 0.0, -2.9) # guitare levée au-dessus de l'épaule, tenue par le manche
const GUITAR_STRIKE := Vector3(1.2, 0.0, -2.9) # abattue vers l'avant
## Modèles importés de Blender (voir docs/RIFFALD.md et docs/GUITARE.md).
const RIFFALD_MODEL := "res://assets/models/riffald/riffald.glb"
const GUITAR_MODEL := "res://assets/models/guitare/guitare_heros.glb"
## Longueur du manche de la Flying V procédurale (sillet), pour placer la main gauche.
const PROC_NUT := 0.64
## Main gauche sur le bout du manche, près du sillet (fraction jonction → sillet) ; pendant le solo,
## elle court entre SOLO_FRETS.
const FRET_AT := 0.86
const SOLO_FRETS := Vector2(0.5, 0.86)
## Guitare portée dans le dos (là où l'on ne joue pas) : jonction manche/caisse au milieu du dos
## (repère du torse), manche vers le bas incliné de 45° vers la gauche du héros, cordes vers l'arrière.
const GUITAR_BACK_POS := Vector3(0.0, 0.3, -0.19)
## Animation « sleep » (allongé sur le dos) : rotation et décalage du modèle pour que le corps
## soit dans l'axe du lit, tête sur l'oreiller (-Z), dos sur le matelas (voir Hero.lie_down).
const SLEEP_YAW := -1.97
const SLEEP_OFFSET := Vector3(0.06, 0.6, -0.04)

## Apparence à afficher (clés de RaceDB.DEFAULT_APPEARANCE). Vide = celle de GameState.
var appearance := {}
## Style de déplacement du corps procédural (HeroAnimator.STYLES) : "pnj_corps" pour les PNJ.
var anim_style := ""

var _torso: Node3D
var _head: Node3D
var _hip_l: Node3D
var _hip_r: Node3D
var _knee_l: Node3D
var _knee_r: Node3D
var _upper_l: Node3D
var _upper_r: Node3D
var _fore_l: Node3D
var _fore_r: Node3D
var _ankle_l: Node3D
var _ankle_r: Node3D
var _hand_l: Node3D
var _hand_r: Node3D
## Doigts de chaque main : 5 listes de pivots (pouce, index, majeur, annulaire, auriculaire).
var _fingers_l: Array = []
var _fingers_r: Array = []
var _pick: MeshInstance3D
var _fret_finger := 0 # doigt qui appuie sur une case pendant le jeu
var _fret_timer := 0.0
var _guitar: Node3D
var _hair_back: Node3D
var _aura: Node3D
var _aura_light: OmniLight3D
var _strings_mat: StandardMaterial3D
var _flash_mats: Array[StandardMaterial3D] = []
## Modèle importé piloté par le squelette procédural (héros prédéfini Riffald), ou null.
var _skin: RiggedSkin
## Animations du modèle importé (AnimationTree + IK de la guitare), ou null : voir HeroAnimator.
var _anim: HeroAnimator
## Pivots du corps procédural, animés avec la posture et la démarche de Riffald (voir HumanoidBody).
var _body: HumanoidBody
var _loco_on := false
var _dead := false
var _lying := false
## Point (repère du torse) que la main du côté +X empoigne : bâton d'un PNJ ; ZERO = main libre.
var prop_grip := Vector3.ZERO
## Vie basse : posture de repos voûtée, à bout de souffle (modèle animé).
var tired := false
## Rapport de longueur du manche de la guitare utilisée / Flying V procédurale.
var _neck_scale := 1.0
## Guitare dans le dos, bras libres (voir set_guitar_slung).
var guitar_slung := false

var _t := 0.0
var _walk := 0.0 # 0 = immobile, 1 = marche (lissé)
var _moving := false
var _busy := false
var _soloing := false
var _strum := 0.0 # animation du grattage (0..1)
var _smash := 0.0 # 1 = les deux mains sur le manche (coup de guitare)
## Vitesse de déplacement (m/s) : règle la cadence et l'amplitude de la foulée.
var move_speed := 1.4
var _phase := 0.0
## Assis (PNJ attablés, fauteuil roulant).
var seated := false
var _seat_height := 0.49
## Rotation additionnelle de la tête (un PNJ qui regarde le héros).
var head_turn := 0.0
## Pose spéciale temporaire : "slide" (glissade à genoux) ou "hop" (saut sur une jambe, Angus Young).
var _pose := ""
var _pose_time := 0.0


func _ready() -> void:
	if appearance.is_empty():
		appearance = GameState.appearance.duplicate()
	_build()


## Change l'apparence (écran de création de personnage) et reconstruit le modèle.
func set_appearance(a: Dictionary) -> void:
	appearance = a.duplicate()
	if not is_inside_tree():
		return
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_flash_mats.clear()
	_build()


## Hauteur réelle du personnage (m).
func height() -> float:
	return RaceDB.hero_height(appearance)


func _build() -> void:
	_skin = null
	_anim = null
	_body = null
	_loco_on = false
	_dead = false
	_lying = false
	_neck_scale = 1.0
	guitar_slung = false
	var race_id := str(appearance.get("race", "humain"))
	var race := RaceDB.get_race(race_id)
	var female: bool = appearance.get("sex", "m") == "f"
	var skeleton := race_id == "squelette"
	# Taille et carrure : le modèle de base mesure 1,8 m.
	var h := float(race.get("height", 1.8)) / 1.8
	var w := float(race.get("width", 1.0)) * (0.9 if female else 1.0) * float(appearance.get("width_mult", 1.0))
	scale = Vector3(w * sqrt(h), h, w * sqrt(h))

	# Tenue : cuir noir et long manteau, ou celle d'un PNJ (appearance["outfit"] : couleurs "top" (buste),
	# "legs" (jambes), "coat" (manches, bottes) et "plain" = vêtements simples, sans manteau ni épaulières).
	var outfit: Dictionary = appearance.get("outfit", {})
	var plain: bool = outfit.get("plain", false)
	var leather := _own_mat(outfit.get("top", Color(0.2, 0.15, 0.13)), 0.6)
	var coat := _own_mat(outfit.get("coat", Color(0.13, 0.1, 0.11)), 0.8)
	var legs := _own_mat(outfit["legs"], 0.7) if outfit.has("legs") else leather
	var skin := _own_mat(race.get("skin", Color(0.8, 0.63, 0.52)), 0.55 if skeleton else 0.65)
	var hair_colors: Array = RaceDB.HAIR_COLORS
	var hair := _own_mat(hair_colors[clampi(int(appearance.get("hair_color", 0)), 0, hair_colors.size() - 1)], 0.75)
	var metal := Visuals.mat(Color(0.78, 0.78, 0.82), 0.25, 0.9)

	# Proportions réalistes (modèle de base de 1,8 m) : jambes ≈ 52 % de la taille,
	# tête ≈ 1/7,5 de la taille, épaules ≈ 2 têtes de large.
	# --- Jambes : hanche → genou → cheville → pied.
	_hip_l = _pivot(self, Vector3(-HIP_HALF_WIDTH, HIP_Y, 0))
	_hip_r = _pivot(self, Vector3(HIP_HALF_WIDTH, HIP_Y, 0))
	_knee_l = _build_leg(_hip_l, legs, coat)
	_knee_r = _build_leg(_hip_r, legs, coat)
	_ankle_l = _knee_l.get_child(_knee_l.get_child_count() - 1) as Node3D
	_ankle_r = _knee_r.get_child(_knee_r.get_child_count() - 1) as Node3D

	# --- Torse (pivot au bassin) : bassin, taille, cage thoracique, cou.
	_torso = _pivot(self, Vector3(0, HIP_Y, 0))
	_torso.rotation.x = TORSO_LEAN
	var chest := 0.17 if female else 0.19
	Visuals.sphere(_torso, 0.16, Vector3(0, 0.02, 0), leather, Vector3(1.05 if female else 0.95, 0.7, 0.75)) # bassin
	Visuals.cylinder(_torso, chest * 0.8, 0.14 if female else 0.15, 0.26, Vector3(0, 0.15, 0), leather, Vector3.ZERO, 14).scale = Vector3(1, 1, 0.72) # taille
	Visuals.cylinder(_torso, chest, chest * 0.8, 0.26, Vector3(0, 0.39, 0), leather, Vector3.ZERO, 14).scale = Vector3(1, 1, 0.66) # thorax
	Visuals.sphere(_torso, chest, Vector3(0, 0.5, 0), leather, Vector3(1.08, 0.42, 0.66)) # haut des épaules
	if female:
		for side: float in [-1.0, 1.0]:
			Visuals.sphere(_torso, 0.065, Vector3(0.07 * side, 0.4, 0.09), leather, Vector3(1.0, 0.9, 0.85))
	if skeleton:
		# Côtes apparentes entre les pans du manteau.
		for i in 4:
			Visuals.box(_torso, Vector3(0.16 - i * 0.015, 0.025, 0.02), Vector3(0, 0.46 - i * 0.065, 0.12), skin)
	Visuals.cylinder(_torso, 0.05, 0.055, 0.12, Vector3(0, 0.58, 0.01), skin, Vector3.ZERO, 10) # cou
	# Long manteau de cuir : deux pans qui tombent jusqu'aux genoux, col relevé.
	if not plain:
		for side: float in [-1.0, 1.0]:
			Visuals.box(_torso, Vector3(0.17, 0.78, 0.03), Vector3(0.1 * side, 0.02, -0.12), coat, Vector3(-6, 0, 3 * side))
			Visuals.box(_torso, Vector3(0.05, 0.62, 0.2), Vector3(0.17 * side, 0.2, -0.02), coat, Vector3(0, 0, 4 * side))
			Visuals.box(_torso, Vector3(0.1, 0.1, 0.03), Vector3(0.09 * side, 0.6, -0.06), coat, Vector3(-20, 0, 18 * side)) # col
	Visuals.cylinder(_torso, 0.16, 0.16, 0.06, Vector3(0, 0.03, 0), coat, Vector3.ZERO, 14).scale = Vector3(1, 1, 0.75) # ceinture
	for i in 5:
		var a := -0.9 + i * 0.45
		Visuals.sphere(_torso, 0.016, Vector3(sin(a) * 0.155, 0.03, cos(a) * 0.12), metal)
	if not plain:
		Visuals.sphere(_torso, 0.03, Vector3(0, 0.44, 0.13), Visuals.glow_mat(Color(1.0, 0.2, 0.1), 2.5)) # médaillon
	# Épaules et épaulières à pointes.
	var shoulder := 0.18 if female else 0.2
	for side: float in [-1.0, 1.0]:
		Visuals.sphere(_torso, 0.075, Vector3(shoulder * side, 0.5, 0.0), coat, Vector3(1.2, 0.8, 1.1))
		if not plain:
			Visuals.cylinder(_torso, 0.0, 0.025, 0.1, Vector3((shoulder + 0.04) * side, 0.57, 0.0), metal, Vector3(0, 0, -30 * side))
	# Sangle de guitare en travers du torse.
	if appearance.get("guitar", true):
		Visuals.box(_torso, Vector3(0.04, 0.6, 0.015), Vector3(0.01, 0.3, 0.125), Visuals.mat(Color(0.12, 0.1, 0.1)), Vector3(0, 0, -33))

	# --- Tête (à l'échelle réaliste) légèrement projetée en avant.
	_head = _pivot(_torso, Vector3(0, 0.6, 0.03))
	_head.rotation.x = -0.1
	_build_head(race_id, race, female, skin, hair)
	_head.scale = Vector3.ONE * HEAD_SCALE

	# --- Guitare Flying V (seulement pour le héros ; les PNJ n'en ont pas).
	_guitar = null
	_strings_mat = null
	if appearance.get("guitar", true):
		_guitar = _pivot(_torso, GUITAR_REST_POS)
		_guitar.rotation = GUITAR_REST
		_guitar.scale = Vector3.ONE * 1.05
		_build_flying_v(_guitar, metal)

	# --- Bras (IK à deux os) et mains à cinq doigts.
	_upper_l = _pivot(_torso, Vector3(-shoulder - 0.02, 0.48, 0.0))
	_upper_r = _pivot(_torso, Vector3(shoulder + 0.02, 0.48, 0.0))
	_fore_l = _build_arm(_upper_l, coat, skin)
	_fore_r = _build_arm(_upper_r, coat, skin)
	var glove := _own_mat(skin.albedo_color if not appearance.get("guitar", true) else Color(0.16, 0.12, 0.1), 0.6)
	_hand_l = _build_hand(_fore_l, skin, glove, -1.0)
	_hand_r = _build_hand(_fore_r, skin, glove, 1.0)
	if appearance.get("guitar", true):
		# Médiator entre le pouce et l'index de la main droite (pivot « _l », côté -X).
		_pick = Visuals.cylinder(_hand_l, 0.018, 0.018, 0.004, Vector3(0.0, -0.075, 0.03),
			Visuals.mat(Color(1.0, 0.75, 0.2), 0.3), Vector3(90, 0, 0), 3)
	_make_body()

	# --- Aura dorée du solo (invincibilité).
	_aura = Node3D.new()
	add_child(_aura)
	Visuals.torus(_aura, 0.75, 0.85, Vector3(0, 0.05, 0), Visuals.glow_mat(Color(1.0, 0.8, 0.3), 3.0))
	Visuals.torus(_aura, 0.55, 0.6, Vector3(0, 0.05, 0), Visuals.glow_mat(Color(1.0, 0.9, 0.5), 2.0))
	_aura_light = OmniLight3D.new()
	_aura_light.position = Vector3(0, 1.2, 0.3)
	_aura_light.light_color = Color(1.0, 0.8, 0.4)
	_aura_light.light_energy = 2.5
	_aura_light.omni_range = 4.0
	_aura.add_child(_aura_light)
	_aura.visible = _soloing
	_update_arms()
	var preset_model := RaceDB.preset_model(str(appearance.get("preset", "")))
	if not preset_model.is_empty() and ResourceLoader.exists(preset_model):
		# Modèle importé à sa taille réelle, sauf agrandissement prévu par le préréglage.
		scale = Vector3.ONE * float((RaceDB.PRESETS.get(str(appearance.get("preset", "")), {}) as Dictionary).get("scale", 1.0))
		_use_skin(preset_model)


## Pivots du corps rassemblés pour LocoAnimator (même hiérarchie que HumanoidBody.build).
func _make_body() -> void:
	var b := HumanoidBody.new()
	b.root = self
	b.torso = _torso
	b.head = _head
	b.hip_l = _hip_l
	b.hip_r = _hip_r
	b.knee_l = _knee_l
	b.knee_r = _knee_r
	b.ankle_l = _ankle_l
	b.ankle_r = _ankle_r
	b.upper_l = _upper_l
	b.upper_r = _upper_r
	b.fore_l = _fore_l
	b.fore_r = _fore_r
	b.hand_l = _hand_l
	b.hand_r = _hand_r
	b.hip_y = HIP_Y
	b.hip_half = HIP_HALF_WIDTH
	b.thigh = THIGH
	b.shin = SHIN
	b.upper_arm = UPPER_ARM
	b.forearm = FOREARM
	b.style = anim_style
	_body = b


# --- Tête : visage, oreilles, cornes, défenses, barbe, coiffure ------------------

func _build_head(race_id: String, race: Dictionary, female: bool, skin: Material, hair: Material) -> void:
	var skeleton := race_id == "squelette"
	var eye_mat := Visuals.glow_mat(race.get("eyes", Color(0.6, 0.85, 1.0)), 2.2)
	Visuals.box(_head, Vector3(0.1, 0.12, 0.1), Vector3(0, 0.04, -0.02), skin) # cou
	var head_scale := Vector3(0.92, 1.1, 1.0)
	match race_id:
		"ogre":
			head_scale = Vector3(1.15, 1.05, 1.1)
		"troll":
			head_scale = Vector3(0.9, 1.15, 1.05)
		"orc":
			head_scale = Vector3(1.0, 1.05, 1.0)
	if female:
		head_scale *= 0.94
	Visuals.sphere(_head, 0.155, Vector3(0, 0.2, 0.03), skin, head_scale)
	if skeleton:
		# Crâne : orbites creuses, trou du nez, mâchoire.
		var dark := Visuals.mat(Color(0.03, 0.02, 0.02))
		for side: float in [-1.0, 1.0]:
			Visuals.sphere(_head, 0.045, Vector3(0.055 * side, 0.22, 0.14), dark)
		Visuals.box(_head, Vector3(0.03, 0.035, 0.02), Vector3(0, 0.165, 0.17), dark)
		Visuals.box(_head, Vector3(0.14, 0.05, 0.1), Vector3(0, 0.1, 0.08), skin)
	else:
		# Mâchoire (plus massive chez les orcs, trolls et ogres).
		var jaw := Vector3(0.16, 0.06, 0.1)
		if race.get("tusks", false):
			jaw = Vector3(0.22 if race_id == "ogre" else 0.19, 0.08, 0.12)
		Visuals.box(_head, jaw, Vector3(0, 0.12, 0.08), skin)
	Visuals.sphere(_head, 0.022, Vector3(-0.055, 0.23, 0.16), eye_mat)
	Visuals.sphere(_head, 0.022, Vector3(0.055, 0.23, 0.16), eye_mat)
	# Nez et oreilles selon la race.
	if race_id == "troll":
		Visuals.cylinder(_head, 0.0, 0.035, 0.12, Vector3(0, 0.19, 0.2), skin, Vector3(80, 0, 0), 8)
	elif race_id == "ogre":
		Visuals.sphere(_head, 0.04, Vector3(0, 0.18, 0.18), skin, Vector3(1.3, 1.0, 1.0))
	if race_id in ["orc", "troll", "demon"]:
		var ear_len := 0.22 if race_id == "troll" else 0.12
		for side: float in [-1.0, 1.0]:
			Visuals.cylinder(_head, 0.0, 0.035, ear_len, Vector3((0.15 + ear_len * 0.35) * side, 0.24, 0.0), skin,
				Vector3(0, 0, -75 * side), 6)
	# Cornes (démon).
	if race.get("horns", false):
		_build_horns(int(appearance.get("horns", 0)))
	# Défenses (orc, troll, ogre).
	if race.get("tusks", false):
		_build_tusks(int(appearance.get("tusks", 0)))
	# Barbe (hommes, sauf squelettes).
	if RaceDB.can_have_beard(appearance):
		_build_beard(int(appearance.get("beard", 0)), hair)
	_build_hair(int(appearance.get("hair", 2)), hair)


func _build_horns(kind: int) -> void:
	var horn := Visuals.mat(Color(0.32, 0.27, 0.22), 0.3) # corne polie, un peu claire pour ressortir dans le noir
	for side: float in [-1.0, 1.0]:
		match kind:
			0: # bélier : spirales enroulées sur les tempes
				Visuals.torus(_head, 0.06, 0.13, Vector3(0.16 * side, 0.27, -0.02), horn, Vector3(0, 0, 90))
				Visuals.cylinder(_head, 0.0, 0.03, 0.08, Vector3(0.17 * side, 0.2, 0.06), horn, Vector3(60, 0, 0), 8)
			1: # taureau : vers l'extérieur puis vers le haut
				Visuals.cylinder(_head, 0.04, 0.055, 0.16, Vector3(0.19 * side, 0.32, 0.0), horn, Vector3(0, 0, -80 * side), 8)
				Visuals.cylinder(_head, 0.0, 0.04, 0.18, Vector3(0.28 * side, 0.42, 0.0), horn, Vector3(0, 0, -15 * side), 8)
			_: # infernales : longues, balayées vers l'arrière, avec une petite paire devant
				Visuals.cylinder(_head, 0.0, 0.055, 0.38, Vector3(0.08 * side, 0.45, -0.1), horn, Vector3(-40, 0, -12 * side), 8)
				Visuals.cylinder(_head, 0.0, 0.025, 0.1, Vector3(0.06 * side, 0.36, 0.1), horn, Vector3(20, 0, -10 * side), 6)


func _build_tusks(kind: int) -> void:
	var ivory := Visuals.mat(Color(0.92, 0.88, 0.75), 0.4)
	for side: float in [-1.0, 1.0]:
		var length := 0.06
		var tilt := 10.0
		match kind:
			1:
				length = 0.14
				tilt = 25.0
			2:
				length = 0.13 if side < 0.0 else 0.035 # une défense brisée
		Visuals.cylinder(_head, 0.0, 0.018, length, Vector3(0.07 * side, 0.13 + length * 0.5, 0.14), ivory,
			Vector3(-10, 0, -tilt * side), 6)


func _build_beard(kind: int, hair: Material) -> void:
	match kind:
		0: # courte
			Visuals.box(_head, Vector3(0.2, 0.1, 0.1), Vector3(0, 0.1, 0.1), hair)
		1: # longue barbe tressée, anneaux de fer
			Visuals.box(_head, Vector3(0.18, 0.1, 0.1), Vector3(0, 0.1, 0.1), hair)
			Visuals.cylinder(_head, 0.02, 0.05, 0.36, Vector3(0, -0.07, 0.15), hair, Vector3(-10, 0, 0), 8)
			for i in 2:
				Visuals.torus(_head, 0.035, 0.05, Vector3(0, -0.02 - i * 0.12, 0.155), Visuals.mat(Color(0.5, 0.5, 0.55), 0.3, 0.8))
		2: # bouc
			Visuals.cylinder(_head, 0.01, 0.04, 0.12, Vector3(0, 0.04, 0.15), hair, Vector3(180, 0, 0), 8)
		_: # rasé de près
			pass


## Coiffures (toujours longues) : tresses, queue de cheval, longs lâchés, glam-metal ; -1 = aucune
## (tête couverte d'une capuche).
func _build_hair(style: int, hair: Material) -> void:
	_hair_back = _pivot(_head, Vector3(0, 0.2, -0.1))
	if style < 0:
		return
	match style:
		0: # tresses : calotte + deux tresses sur l'avant des épaules + dos
			Visuals.sphere(_head, 0.165, Vector3(0, 0.26, -0.01), hair, Vector3(1.05, 0.9, 1.05))
			Visuals.box(_hair_back, Vector3(0.28, 0.42, 0.07), Vector3(0, -0.22, -0.02), hair)
			for side: float in [-1.0, 1.0]:
				for i in 5:
					Visuals.sphere(_head, 0.04 - i * 0.003, Vector3(0.14 * side, 0.12 - i * 0.08, 0.06 + i * 0.012), hair)
		1: # queue de cheval haute
			Visuals.sphere(_head, 0.163, Vector3(0, 0.26, -0.01), hair, Vector3(1.02, 0.88, 1.05))
			Visuals.sphere(_hair_back, 0.05, Vector3(0, 0.1, -0.05), hair)
			Visuals.capsule(_hair_back, 0.055, 0.6, Vector3(0, -0.2, -0.08), hair, Vector3(-12, 0, 0))
		2: # longs lâchés
			Visuals.sphere(_head, 0.17, Vector3(0, 0.26, -0.01), hair, Vector3(1.05, 0.95, 1.05))
			Visuals.box(_hair_back, Vector3(0.32, 0.62, 0.09), Vector3(0, -0.32, -0.02), hair)
			Visuals.box(_head, Vector3(0.07, 0.5, 0.12), Vector3(-0.16, -0.06, 0.02), hair, Vector3(0, 0, -5))
			Visuals.box(_head, Vector3(0.07, 0.5, 0.12), Vector3(0.16, -0.06, 0.02), hair, Vector3(0, 0, 5))
			Visuals.box(_head, Vector3(0.18, 0.08, 0.05), Vector3(0, 0.34, 0.14), hair) # frange
		_: # glam-metal : volume crêpé énorme
			Visuals.sphere(_head, 0.22, Vector3(0, 0.34, -0.12), hair, Vector3(1.35, 0.95, 1.0))
			for side: float in [-1.0, 1.0]:
				Visuals.sphere(_head, 0.14, Vector3(0.21 * side, 0.12, -0.08), hair, Vector3(0.8, 1.6, 0.9))
			Visuals.sphere(_hair_back, 0.2, Vector3(0, -0.2, -0.04), hair, Vector3(1.4, 1.8, 0.6))
			Visuals.box(_head, Vector3(0.2, 0.08, 0.06), Vector3(0, 0.36, 0.15), hair, Vector3(-20, 0, 0))


## Jambe : cuisse fuselée, genou, tibia, cheville et botte (le dernier enfant du genou
## est la cheville, qui porte le pied).
func _build_leg(hip: Node3D, leather: Material, coat: Material) -> Node3D:
	Visuals.cylinder(hip, 0.085, 0.065, THIGH, Vector3(0, -THIGH * 0.5, 0), leather, Vector3.ZERO, 12) # cuisse
	var knee := _pivot(hip, Vector3(0, -THIGH, 0))
	Visuals.sphere(knee, 0.065, Vector3.ZERO, leather)
	Visuals.cylinder(knee, 0.062, 0.048, SHIN, Vector3(0, -SHIN * 0.5, 0), leather, Vector3.ZERO, 12) # tibia
	Visuals.cylinder(knee, 0.06, 0.055, 0.2, Vector3(0, -SHIN + 0.1, 0.005), coat, Vector3.ZERO, 12) # tige de botte
	var ankle := _pivot(knee, Vector3(0, -SHIN, 0))
	Visuals.box(ankle, Vector3(0.1, 0.07, 0.25), Vector3(0, -0.03, 0.06), coat) # pied (botte)
	Visuals.box(ankle, Vector3(0.105, 0.025, 0.26), Vector3(0, -0.07, 0.06), Visuals.mat(Color(0.03, 0.03, 0.03))) # semelle
	return knee


## Bras : haut du bras fuselé, coude, avant-bras (la main est ajoutée par _build_hand).
func _build_arm(upper: Node3D, sleeve: Material, _skin_mat: Material) -> Node3D:
	Visuals.cylinder(upper, 0.05, 0.042, UPPER_ARM, Vector3(0, -UPPER_ARM * 0.5, 0), sleeve, Vector3.ZERO, 10)
	var fore := _pivot(upper, Vector3(0, -UPPER_ARM, 0))
	Visuals.sphere(fore, 0.043, Vector3.ZERO, sleeve)
	Visuals.cylinder(fore, 0.042, 0.03, FOREARM, Vector3(0, -FOREARM * 0.5, 0), sleeve, Vector3.ZERO, 10)
	return fore


## Main : paume, quatre doigts à trois phalanges et un pouce à deux phalanges.
## Repère de la main : doigts vers -Y (dans le prolongement de l'avant-bras), paume vers +Z.
## `side` = -1 main gauche, +1 main droite (position du pouce).
func _build_hand(fore: Node3D, skin: Material, glove: Material, side: float) -> Node3D:
	var hand := _pivot(fore, Vector3(0, -FOREARM, 0))
	Visuals.box(hand, Vector3(0.075, 0.085, 0.028), Vector3(0, -0.045, 0), glove) # paume (mitaine de cuir)
	var fingers: Array = []
	# Pouce : part du côté de la paume, vers l'avant.
	var thumb_root := _pivot(hand, Vector3(-0.035 * side, -0.025, 0.012))
	thumb_root.rotation = Vector3(-0.5, 0.0, 0.7 * side)
	fingers.append(_build_finger(thumb_root, skin, 0.011, 2))
	# Index → auriculaire.
	for i in 4:
		var x := (0.027 - i * 0.018) * -side
		var root := _pivot(hand, Vector3(x, -0.088, 0.0))
		var s: float = [1.0, 1.08, 1.0, 0.82][i]
		root.scale = Vector3.ONE * float(s)
		fingers.append(_build_finger(root, skin, 0.0085, 3))
	if side < 0.0:
		_fingers_l = fingers
	else:
		_fingers_r = fingers
	return hand


## Doigt : chaîne de pivots (une phalange par pivot), renvoie la liste des pivots.
func _build_finger(root: Node3D, skin: Material, r: float, count: int) -> Array:
	var joints: Array = []
	var parent := root
	for k in count:
		var length: float = PHALANGES[k + (1 if count == 2 else 0)]
		var j := _pivot(parent, Vector3.ZERO if k == 0 else Vector3(0, -float(PHALANGES[k - 1 + (1 if count == 2 else 0)]), 0))
		Visuals.capsule(j, r * (1.0 - k * 0.12), length + r, Vector3(0, -length * 0.5, 0), skin)
		joints.append(j)
		parent = j
	return joints


## Replie les doigts d'une main : `curls` = angle (rad) par doigt [pouce, index, majeur, annulaire, auriculaire].
func _curl_fingers(fingers: Array, curls: Array) -> void:
	for f in fingers.size():
		var joints: Array = fingers[f]
		var c: float = curls[f]
		for k in joints.size():
			var j: Node3D = joints[k]
			j.rotation.x = -c * (1.0 if k == 0 else 1.2) # les phalanges se replient vers la paume (+Z)


## Réplique de Gibson Flying V (finition cerise, plaque de protection blanche,
## deux micros double bobinage, chevalet Tune-o-matic, cordier en V, 3 boutons en ligne).
## Repère local : manche vers +Y, face avant vers +Z, pointe du V à l'origine.
func _build_flying_v(g: Node3D, chrome: Material) -> void:
	if ResourceLoader.exists(GUITAR_MODEL):
		_build_imported_guitar(g)
		return
	var cherry := Visuals.mat(Color(0.5, 0.04, 0.05), 0.22, 0.1)
	var pickguard := Visuals.mat(Color(0.92, 0.9, 0.85), 0.4)
	var mahogany := Visuals.mat(Color(0.33, 0.14, 0.06), 0.5)
	var rosewood := Visuals.mat(Color(0.1, 0.05, 0.03), 0.6)
	var black := Visuals.mat(Color(0.03, 0.03, 0.03), 0.4)
	var pearl := Visuals.mat(Color(0.95, 0.93, 0.88), 0.2)
	# Corps en V : deux ailes qui s'écartent depuis la jonction du manche.
	Visuals.box(g, Vector3(0.12, 0.48, 0.045), Vector3(-0.1, -0.21, 0), cherry, Vector3(0, 0, -24))
	Visuals.box(g, Vector3(0.12, 0.48, 0.045), Vector3(0.1, -0.21, 0), cherry, Vector3(0, 0, 24))
	Visuals.box(g, Vector3(0.17, 0.2, 0.045), Vector3(0, -0.07, 0), cherry)
	Visuals.sphere(g, 0.085, Vector3(0, 0.0, 0), cherry, Vector3(1.0, 0.7, 0.26))
	# Plaque de protection blanche (épouse le haut du V).
	Visuals.box(g, Vector3(0.15, 0.18, 0.006), Vector3(0, -0.07, 0.025), pickguard)
	Visuals.box(g, Vector3(0.06, 0.18, 0.006), Vector3(-0.085, -0.17, 0.025), pickguard, Vector3(0, 0, -24))
	Visuals.box(g, Vector3(0.06, 0.18, 0.006), Vector3(0.085, -0.17, 0.025), pickguard, Vector3(0, 0, 24))
	# Micros humbucker (cadres chromés).
	for y: float in [-0.03, -0.12]:
		Visuals.box(g, Vector3(0.085, 0.045, 0.012), Vector3(0, y, 0.03), chrome)
		Visuals.box(g, Vector3(0.075, 0.035, 0.018), Vector3(0, y, 0.032), black)
	# Chevalet Tune-o-matic + cordier en V.
	Visuals.box(g, Vector3(0.085, 0.014, 0.018), Vector3(0, -0.18, 0.03), chrome)
	Visuals.box(g, Vector3(0.012, 0.09, 0.006), Vector3(-0.022, -0.25, 0.026), chrome, Vector3(0, 0, -25))
	Visuals.box(g, Vector3(0.012, 0.09, 0.006), Vector3(0.022, -0.25, 0.026), chrome, Vector3(0, 0, 25))
	# Trois boutons alignés sur l'aile droite.
	for i in 3:
		Visuals.cylinder(g, 0.014, 0.014, 0.02, Vector3(0.1 + i * 0.03, -0.27 - i * 0.06, 0.03), black, Vector3(90, 0, 0), 8)
	# Manche en acajou, touche en palissandre, repères nacrés.
	Visuals.box(g, Vector3(0.05, 0.62, 0.035), Vector3(0, 0.33, -0.005), mahogany)
	Visuals.box(g, Vector3(0.048, 0.6, 0.008), Vector3(0, 0.33, 0.016), rosewood)
	for y: float in [0.1, 0.17, 0.23, 0.29, 0.38, 0.47, 0.53]:
		Visuals.sphere(g, 0.006, Vector3(0, y, 0.021), pearl)
	# Tête en flèche, légèrement renversée, avec 6 mécaniques.
	var head := _pivot(g, Vector3(0, 0.64, -0.005))
	head.rotation.x = deg_to_rad(-12)
	Visuals.box(head, Vector3(0.07, 0.17, 0.018), Vector3(0, 0.085, 0), black)
	Visuals.box(head, Vector3(0.04, 0.05, 0.02), Vector3(-0.03, 0.17, 0), black, Vector3(0, 0, 20))
	Visuals.box(head, Vector3(0.04, 0.05, 0.02), Vector3(0.03, 0.17, 0), black, Vector3(0, 0, -20))
	for i in 3:
		for s: float in [-1.0, 1.0]:
			Visuals.cylinder(head, 0.008, 0.008, 0.035, Vector3(0.045 * s, 0.04 + i * 0.045, -0.005), chrome, Vector3(0, 0, 90), 6)
	# Cordes (légère lueur magique).
	_strings_mat = Visuals.glow_mat(Color(0.55, 0.85, 1.0), 0.8)
	Visuals.box(g, Vector3(0.03, 0.84, 0.003), Vector3(0, 0.23, 0.036), _strings_mat)


# --- Modèles importés de Blender ---------------------------------------------------------

## Héros prédéfini : le modèle Blender remplace le corps procédural, qui reste en place mais
## invisible et continue de calculer toutes les animations (voir RiggedSkin).
func _use_skin(path: String) -> void:
	var skin := RiggedSkin.create(self, path)
	if skin == null:
		return
	for mi in find_children("*", "MeshInstance3D", true, false):
		var n := mi as Node3D
		if (_guitar != null and _guitar.is_ancestor_of(n)) or _aura.is_ancestor_of(n):
			continue
		n.visible = false
	add_child(skin)
	_skin = skin
	_flash_mats.append_array(_skin.flash_materials)
	# Modèle avec ses propres animations : AnimationTree. Sinon, il recopie le squelette procédural.
	_anim = HeroAnimator.attach(self, skin)
	if _anim == null:
		_skin.capture_rest()
		_skin.drive()


## Guitare des héros modélisée dans Blender (même repère que la Flying V procédurale :
## manche vers +Y, face vers +Z, pointe du V à l'origine).
func _build_imported_guitar(g: Node3D) -> void:
	var inst := (load(GUITAR_MODEL) as PackedScene).instantiate()
	g.add_child(inst)
	g.scale = Vector3.ONE
	_neck_scale = 0.385 / PROC_NUT # sillet de la nouvelle guitare
	for node in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i) as StandardMaterial3D
			if src == null:
				continue
			var m := src.duplicate() as StandardMaterial3D
			match src.resource_name:
				"MB_g_cordes":
					# Cordes : légère lueur magique, plus vive pendant le solo (solo_pose).
					m.emission_enabled = true
					m.emission = Color(0.55, 0.85, 1.0)
					m.emission_energy_multiplier = 0.8
					_strings_mat = m
				"MB_g_gemme":
					m.emission_enabled = true
					m.emission = Color(1.0, 0.1, 0.08)
					m.emission_energy_multiplier = 1.6
			mi.set_surface_override_material(i, m)
	if _strings_mat == null:
		_strings_mat = Visuals.glow_mat(Color(0.55, 0.85, 1.0), 0.8)


func _own_mat(color: Color, roughness: float) -> StandardMaterial3D:
	var m := Visuals.char_mat(color, roughness)
	m.emission_enabled = true
	m.emission = Color.BLACK
	_flash_mats.append(m)
	return m


func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var p := Node3D.new()
	p.position = pos
	parent.add_child(p)
	return p


func set_moving(moving: bool) -> void:
	_moving = moving


## Pose assise (chaise, tabouret, fauteuil roulant). `seat_height` = hauteur de l'assise en mètres.
func set_seated(value: bool, seat_height: float = 0.49) -> void:
	seated = value
	_seat_height = seat_height


func _process(delta: float) -> void:
	_t += delta
	_walk = move_toward(_walk, 1.0 if _moving and not seated else 0.0, delta * 5.0)
	var hunched: bool = appearance.get("hunched", true)
	if _strings_mat != null:
		_strings_mat.emission_energy_multiplier = (3.0 if _soloing else 0.8) + sin(_t * 6.0) * 0.3

	# Cadence et amplitude selon la vitesse : marche (PNJ, 1,4 m/s) ou course (héros, 5,5 m/s).
	var run := clampf((move_speed - 1.5) / 4.0, 0.0, 1.0)
	_phase += delta * lerpf(5.2, 9.5, run) * _walk
	var p := _phase
	var breath := sin(_t * 1.8)
	if _animated():
		# Debout : posture et déplacement de Riffald (clips Mixamo, voir LocoAnimator).
		_body.head_turn = head_turn
		_body.loco.advance(delta, _walk, move_speed * (1.0 if _moving else 0.0), tired)
		_body.loco.apply_body()
	else:
		_procedural_body(delta, run, p, breath, hunched)
	_hair_back.rotation.x = -0.1 - _walk * lerpf(0.1, 0.3, run) - (absf(sin(_t * 9.0)) * 0.3 if _soloing else 0.0)

	# Grattage permanent pendant le solo ; doigts de la main gauche qui changent de case.
	if _soloing:
		_strum = absf(sin(_t * 18.0))
	else:
		_strum = move_toward(_strum, 0.0, delta * 4.0)
	_fret_timer -= delta
	if _fret_timer <= 0.0:
		_fret_timer = 0.12 if (_soloing or _strum > 0.1) else 0.6
		_fret_finger = randi_range(1, 4)
	_apply_special_pose(delta)
	_aura.visible = _soloing
	if _soloing:
		_aura.rotation.y += delta * 2.0
		_aura_light.light_energy = 2.2 + sin(_t * 10.0) * 0.5
	_update_arms()
	if _skin != null and _anim == null:
		_skin.drive()


## Posture et déplacement animés (LocoAnimator) : debout et hors des poses spéciales (assis, solo,
## glissade, saut, lit, mort), pour le modèle procédural seulement (les modèles importés ont HeroAnimator).
func _animated() -> bool:
	var want := _anim == null and not seated and not _soloing and _pose.is_empty() and not _dead and not _lying
	if _body == null or (want and not _body.ensure_loco()) or _body.loco == null:
		return false
	if want != _loco_on:
		_loco_on = want
		if not want:
			_reset_pose()
	return want


## Retour au squelette procédural : pivots du corps remis à leur repos (les bras sont recalculés par IK).
func _reset_pose() -> void:
	for n: Node3D in [_hip_l, _hip_r, _knee_l, _knee_r, _ankle_l, _ankle_r, _torso, _head]:
		n.quaternion = Quaternion.IDENTITY # la tête garde son échelle
	_hip_l.position = Vector3(-HIP_HALF_WIDTH, HIP_Y, 0)
	_hip_r.position = Vector3(HIP_HALF_WIDTH, HIP_Y, 0)
	_torso.position = Vector3(0, HIP_Y, 0)


## Squelette procédural : assis, ou marche voûtée (solo, glissade, saut, lit, mort).
func _procedural_body(delta: float, run: float, p: float, breath: float, hunched: bool) -> void:
	if seated:
		# Assis : cuisses à l'horizontale, tibias vers le sol, bassin à hauteur de l'assise.
		var hip_y := _seat_height / maxf(scale.y, 0.01) + 0.04
		_hip_l.rotation.x = -1.45
		_hip_r.rotation.x = -1.45
		_knee_l.rotation.x = 1.45
		_knee_r.rotation.x = 1.45
		_ankle_l.rotation.x = 0.0
		_ankle_r.rotation.x = 0.0
		_torso.position.y = hip_y + breath * 0.004
		_hip_l.position.y = hip_y
		_hip_r.position.y = hip_y
		_torso.rotation.z = sin(_t * 0.9) * 0.02
		_torso.rotation.y = 0.0
	else:
		# Cycle de marche : chaque jambe avance (cuisse), plie le genou pendant la phase
		# d'oscillation, pose le talon puis déroule le pied ; le bassin monte et descend
		# deux fois par cycle, les épaules tournent à l'inverse des hanches.
		var thigh_amp := lerpf(0.42, 0.75, run) * _walk
		var knee_amp := lerpf(0.75, 1.35, run) * _walk
		for leg in 2:
			var ph := p + (0.0 if leg == 0 else PI)
			var hip: Node3D = _hip_l if leg == 0 else _hip_r
			var knee: Node3D = _knee_l if leg == 0 else _knee_r
			var ankle: Node3D = _ankle_l if leg == 0 else _ankle_r
			var thigh := -sin(ph) * thigh_amp - 0.03
			var bend := 0.05 + knee_amp * pow(maxf(0.0, cos(ph - 0.35)), 1.6) + 0.12 * run * _walk
			hip.rotation.x = thigh
			knee.rotation.x = bend
			# Pied à plat au sol, pointe qui se lève au passage et talon qui décolle à la poussée.
			ankle.rotation.x = -(thigh + bend) * 0.85 + 0.25 * maxf(0.0, -cos(ph)) * _walk
		var bob := (absf(cos(p)) * lerpf(0.025, 0.06, run) - 0.02 * run) * _walk + breath * 0.004 * (1.0 - _walk)
		var base_y := HIP_Y - 0.02 * _walk
		_torso.position.y = base_y + bob
		_hip_l.position.y = base_y + bob
		_hip_r.position.y = base_y + bob
		_torso.rotation.y = sin(p) * 0.14 * _walk # contre-rotation des épaules
		_torso.rotation.z = sin(p) * 0.035 * _walk + sin(_t * 0.7) * 0.01 * (1.0 - _walk) # transfert du poids
	var lean := (TORSO_LEAN if hunched else 0.03) + lerpf(0.04, 0.2, run) * _walk # on se penche en courant
	if seated:
		lean = 0.08
	if _soloing:
		lean = -0.14 # cambré en arrière pour le solo
	_torso.rotation.x = lerpf(_torso.rotation.x, lean, delta * 8.0)

	# Tête : le regard reste à l'horizontale (compense l'inclinaison du dos), headbang en solo.
	_head.rotation.y = head_turn - _torso.rotation.y * 0.6
	if _soloing:
		_head.rotation.x = -0.1 + absf(sin(_t * 9.0)) * 0.55
	else:
		var rest := -lean * 0.7
		_head.rotation.x = lerpf(_head.rotation.x, rest + sin(p * 2.0) * 0.02 * _walk, delta * 8.0)


# --- IK des bras et des mains ------------------------------------------------------------

func _update_arms() -> void:
	if _guitar == null or guitar_slung:
		# Sans guitare (PNJ) ou guitare dans le dos : bras de l'animation de Riffald debout, sinon
		# bras qui balancent à l'opposé des jambes, mains sur la table assis.
		if _loco_on:
			_body.loco.apply_arms()
		else:
			var swing := sin(_phase) * lerpf(0.1, 0.2, clampf((move_speed - 1.5) / 4.0, 0.0, 1.0)) * _walk
			var l := Vector3(-0.27, 0.02, 0.03 - swing)
			var r := Vector3(0.27, 0.02, 0.03 + swing)
			if seated:
				l = Vector3(-0.17, 0.28, 0.38)
				r = Vector3(0.17, 0.28 + sin(_t * 1.3) * 0.03, 0.38)
			_solve_arm(_upper_l, _fore_l, l, Vector3(-0.4, -0.2, -1.0))
			_solve_arm(_upper_r, _fore_r, r, Vector3(0.4, -0.2, -1.0))
			var palm_l := Vector3(0, -1, 0) if seated else Vector3(1, 0, 0.2)
			var palm_r := Vector3(0, -1, 0) if seated else Vector3(-1, 0, 0.2)
			_orient_hand(_upper_l, _fore_l, _hand_l, palm_l, 0.0)
			_orient_hand(_upper_r, _fore_r, _hand_r, palm_r, 0.0)
		var relaxed := [0.3, 0.25, 0.3, 0.35, 0.4] if not seated else [0.15, 0.1, 0.12, 0.15, 0.18]
		_curl_fingers(_fingers_l, relaxed)
		_curl_fingers(_fingers_r, relaxed)
		if prop_grip != Vector3.ZERO and not seated:
			# Bâton (PNJ) : avant-bras vers l'avant, paume tournée vers le corps, poing serré.
			_solve_arm(_upper_r, _fore_r, prop_grip, Vector3(0.6, -1.0, -0.6))
			_orient_hand(_upper_r, _fore_r, _hand_r, Vector3(-1, 0, 0), 0.0)
			_curl_fingers(_fingers_r, [1.2, 1.5, 1.5, 1.5, 1.5])
		return
	var gt := _guitar.transform
	var nut := PROC_NUT * _neck_scale
	var fret := FRET_AT * nut # main gauche au bout du manche, près du sillet
	if _soloing:
		fret = lerpf(SOLO_FRETS.x, SOLO_FRETS.y, 0.5 + 0.5 * sin(_t * 5.0)) * nut # elle court sur le manche
	# Main gauche (pivots « _r », côté +X) derrière le manche : pouce dessous, doigts par-dessus la touche.
	var left_target := gt * Vector3(0.02, fret, -0.025)
	# Main droite au centre de la caisse, entre les micros ; le poignet un peu au-dessus (vers le bord
	# haut de la caisse) pour que les doigts et le médiator tombent sur les cordes.
	var pick := gt * Vector3(-0.035, -0.1 + _strum * 0.06, 0.08 + _strum * 0.03)
	var right_target := pick.lerp(gt * Vector3(0, 0.3 * _neck_scale, -0.02), _smash)
	_solve_arm(_upper_r, _fore_r, left_target, Vector3(1.0, -0.4, -0.3))
	_solve_arm(_upper_l, _fore_l, right_target, Vector3(-1.0, -0.6, -0.4))
	var neck_front := gt.basis.z.normalized()
	_orient_hand(_upper_r, _fore_r, _hand_r, neck_front, 0.0)
	_orient_hand(_upper_l, _fore_l, _hand_l, -neck_front, -0.5 + _strum * 0.6) # coup de poignet
	# Main gauche : doigts recourbés sur la touche, un doigt appuie plus fort sur une case.
	var chord := [0.35, 1.05, 1.1, 1.15, 1.2]
	if _smash < 0.5:
		chord[_fret_finger] = 1.45
	else:
		chord = [1.2, 1.5, 1.5, 1.5, 1.5] # poing serré sur le manche pour frapper
	_curl_fingers(_fingers_r, chord)
	# Main droite : médiator pincé entre le pouce et l'index, autres doigts repliés.
	var grip := [0.55, 1.1, 1.45, 1.5, 1.55] if _smash < 0.5 else [1.2, 1.5, 1.5, 1.5, 1.5]
	_curl_fingers(_fingers_l, grip)


## Oriente la main dans le prolongement de l'avant-bras, paume tournée vers `palm_dir`
## (espace du torse) ; `wrist_pitch` plie le poignet.
func _orient_hand(upper: Node3D, fore: Node3D, hand: Node3D, palm_dir: Vector3, wrist_pitch: float) -> void:
	HumanoidBody.orient_hand(upper, fore, hand, palm_dir, wrist_pitch)


## IK analytique à deux segments dans l'espace du torse.
func _solve_arm(upper: Node3D, fore: Node3D, target: Vector3, pole: Vector3) -> void:
	var s := upper.position
	var to := target - s
	var d := clampf(to.length(), 0.05, (UPPER_ARM + FOREARM) * 0.999)
	var dir := to.normalized()
	var cos_a := clampf((UPPER_ARM * UPPER_ARM + d * d - FOREARM * FOREARM) / (2.0 * UPPER_ARM * d), -1.0, 1.0)
	var a := acos(cos_a)
	var perp := (pole - dir * pole.dot(dir)).normalized()
	var elbow := s + (dir * cos(a) + perp * sin(a)) * UPPER_ARM
	var hand := s + dir * d
	upper.basis = _basis_pointing(elbow - s)
	fore.basis = upper.basis.inverse() * _basis_pointing(hand - elbow)


## Base dont l'axe -Y pointe vers `v` (les segments de membres pendent le long de -Y).
func _basis_pointing(v: Vector3) -> Basis:
	var y := -v.normalized()
	var ref := Vector3(0, 0, 1) if absf(y.z) < 0.9 else Vector3(1, 0, 0)
	var x := ref.cross(y).normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z)


# --- Actions ---------------------------------------------------------------------

## Coup de guitare : empoignée par le manche, levée au-dessus de l'épaule puis abattue.
func swing() -> void:
	if guitar_slung:
		return
	if _anim != null:
		if not _soloing:
			_anim.attack()
		return
	if _busy or _soloing or _guitar == null:
		return
	_busy = true
	var tw := create_tween()
	tw.tween_property(self, "_smash", 1.0, 0.05)
	tw.parallel().tween_property(_guitar, "rotation", GUITAR_WINDUP, 0.09)
	tw.parallel().tween_property(_guitar, "position", Vector3(-0.1, 0.45, 0.2), 0.09)
	tw.tween_property(_guitar, "rotation", GUITAR_STRIKE, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_guitar, "position", Vector3(-0.05, 0.3, 0.45), 0.09)
	tw.tween_interval(0.07)
	tw.tween_property(_guitar, "rotation", GUITAR_REST, 0.2)
	tw.parallel().tween_property(_guitar, "position", GUITAR_REST_POS, 0.2)
	tw.parallel().tween_property(self, "_smash", 0.0, 0.2)
	tw.tween_callback(func() -> void: _busy = false)


## Accord rageur (lancement de sort) : la guitare se relève, grattage appuyé.
func strum() -> void:
	if _soloing or _guitar == null or guitar_slung:
		return
	if _anim != null:
		# Grattage appuyé (IK de la main droite) et hochement de tête.
		var st := create_tween()
		st.tween_property(self, "_strum", 1.0, 0.06)
		st.tween_property(self, "_strum", 0.0, 0.12)
		_anim.nod()
		return
	var tw := create_tween()
	tw.tween_property(_guitar, "rotation", GUITAR_SOLO, 0.06)
	tw.parallel().tween_property(self, "_strum", 1.0, 0.06)
	tw.tween_property(self, "_strum", 0.0, 0.12)
	tw.tween_property(_guitar, "rotation", GUITAR_REST, 0.25)


## Posture de solo (pendant le mini-jeu) : cambré, manche levé, headbang, aura dorée.
func solo_pose(active: bool) -> void:
	if _guitar == null:
		return
	_soloing = active
	if _anim != null:
		_anim.play("solo" if active else "loco")
		_strings_mat.emission = Color(1.0, 0.9, 0.55) if active else Color(0.55, 0.85, 1.0)
		return
	var tw := create_tween()
	tw.tween_property(_guitar, "rotation", GUITAR_SOLO if active else GUITAR_REST, 0.15)
	_strings_mat.emission = Color(1.0, 0.9, 0.55) if active else Color(0.55, 0.85, 1.0)


## Guitare dans le dos (taverne hors du sous-sol) ou reprise en main. Avec les animations importées,
## c'est HeroAnimator qui la place (il lit `guitar_slung`).
func set_guitar_slung(value: bool) -> void:
	if value == guitar_slung or _guitar == null:
		return
	guitar_slung = value
	if _anim != null:
		return
	_soloing = false
	_smash = 0.0
	if value:
		_guitar.position = GUITAR_BACK_POS
		_guitar.quaternion = back_basis().get_rotation_quaternion()
	else:
		_guitar.position = GUITAR_REST_POS
		_guitar.rotation = GUITAR_REST


## Orientation de la guitare portée dans le dos (repère du modèle : +X à gauche du héros, +Z devant) :
## manche (+Y de la guitare) vers le bas et la gauche à 45°, cordes (+Z de la guitare) vers l'arrière.
static func back_basis() -> Basis:
	var y := Vector3(1.0, -1.0, 0.0).normalized()
	var z := Vector3(0.0, 0.0, -1.0)
	return Basis(y.cross(z), y, z)


func flash(color: Color = Color(1.0, 0.1, 0.05)) -> void:
	if _anim != null:
		_anim.hurt()
	for m in _flash_mats:
		m.emission = color
	await get_tree().create_timer(0.1, false).timeout
	for m in _flash_mats:
		m.emission = Color.BLACK


func die() -> void:
	_soloing = false
	_moving = false
	_dead = true
	if _anim != null:
		_anim.play("die")
		return
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "rotation:x", -PI * 0.5, 0.6).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position:y", 0.25, 0.6)


# --- Poses spéciales ---------------------------------------------------------------

## Glissade sur les genoux, guitare dressée, dos cambré (la glissade de scène du metal).
func knee_slide(duration: float) -> void:
	if _anim != null:
		_anim.play("slide")
		return
	_pose = "slide"
	_pose_time = duration
	if _guitar != null and not guitar_slung:
		create_tween().tween_property(_guitar, "rotation", GUITAR_SOLO, 0.08)


## Petit saut sur une jambe façon Angus Young (esquive passive réussie).
func angus_hop(duration: float = 0.6) -> void:
	if _anim != null:
		_anim.nod()
		return
	if _pose == "slide":
		return
	_pose = "hop"
	_pose_time = duration


## Sort lancé : `kind` = "area" (onde de choc, frappe du sol) ou "cast" (sort de soutien).
## Sans animations importées : simple accord rageur.
func act(kind: String) -> void:
	if _anim != null and not _soloing:
		_anim.play(kind)
	else:
		strum()


## Stage Diving : vol bras écartés au-dessus de la foule, puis réception.
func dive(flying: bool) -> void:
	if _anim != null:
		_anim.play("fall" if flying else "land")
		return
	solo_pose(flying)


## Poings levés (boss vaincu, prisonnier libéré).
func victory() -> void:
	if _anim != null and not _soloing:
		_anim.play("victory")


## Allongé sur un lit : renvoie true si le modèle a sa propre animation (il reste alors debout
## dans son repère, voir SLEEP_YAW) ; sinon l'appelant couche le modèle entier.
func lie(active: bool) -> bool:
	if _anim == null:
		_lying = active # squelette procédural, immobile : l'appelant couche le modèle
		return false
	_anim.play("sleep" if active else "loco")
	return true


func _apply_special_pose(delta: float) -> void:
	if _pose.is_empty():
		return
	_pose_time -= delta
	if _pose_time <= 0.0:
		_pose = ""
		if _guitar != null and not _soloing and not _busy and not guitar_slung:
			create_tween().tween_property(_guitar, "rotation", GUITAR_REST, 0.2)
		return
	match _pose:
		"slide":
			# À genoux : cuisses verticales, tibias à plat vers l'arrière, bassin abaissé.
			var y := THIGH + 0.06
			_hip_l.rotation.x = -0.15
			_hip_r.rotation.x = -0.15
			_knee_l.rotation.x = 1.55
			_knee_r.rotation.x = 1.55
			_torso.position.y = y
			_hip_l.position.y = y
			_hip_r.position.y = y
			_torso.rotation.x = -0.45 # cambré en arrière
			_head.rotation.x = -0.35
			_strum = absf(sin(_t * 20.0))
		"hop":
			# Jambe gauche repliée, sautillements sur la jambe droite.
			var hop := absf(sin(_t * 16.0)) * 0.16
			_hip_l.rotation.x = -1.2
			_knee_l.rotation.x = 1.5
			_hip_r.rotation.x = 0.0
			_knee_r.rotation.x = 0.1
			_torso.position.y = HIP_Y + hop
			_hip_l.position.y = HIP_Y + hop
			_hip_r.position.y = HIP_Y + hop
			_torso.rotation.x = -0.05
			_torso.rotation.z = sin(_t * 8.0) * 0.12
			_head.rotation.x = absf(sin(_t * 16.0)) * 0.3
