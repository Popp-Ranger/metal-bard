class_name Balance
extends RefCounted
## Toutes les valeurs d'équilibrage du jeu, réunies en un seul endroit.
## Modifie ce fichier pour rendre le jeu plus facile / plus dur sans toucher au code.

# --- Héros -----------------------------------------------------------------
const HERO_SPEED := 5.5 # m/s
const HERO_BASE_HP := 30 # PV au niveau 1 (avant modificateur de CON)
const HERO_HP_PER_CON := 4 # PV gagnés par point de modificateur de CON au niveau 1
const HERO_HP_PER_LEVEL := 7 # PV par niveau (dé de vie du barde : d8 → 5 en moyenne, arrondi « héroïque »)
const HERO_BASE_MANA := 50.0 # « Décibels » (dB), la ressource des sorts
const HERO_MANA_PER_CHA := 8.0
const HERO_MANA_PER_LEVEL := 6.0
const HERO_MANA_REGEN := 4.0 # dB par seconde
const HERO_BASE_AC := 11 # Armure de cuir cloutée : 11 + mod. DEX
const MAX_LEVEL := 20
const POINTS_PER_LEVEL := 2 # Points de caractéristique par niveau (variante « Oblivion »)
const ABILITY_CAP := 20

## XP totale requise pour atteindre le niveau (index + 1). Table officielle D&D 5e.
const XP_TABLE := [0, 300, 900, 2700, 6500, 14000, 23000, 34000, 48000, 64000,
	85000, 100000, 120000, 140000, 165000, 195000, 225000, 265000, 305000, 355000]

# --- Compétences -----------------------------------------------------------
const MELEE_COOLDOWN := 0.65
const MELEE_RANGE := 1.9
const MELEE_KNOCKBACK := 2.5

# Accordage de cordes (clic droit) : arc électrique qui rebondit.
const TUNING_COST := 12.0
const TUNING_COOLDOWN := 1.2
const TUNING_MAX_TARGETS := 5 # « arc électrique qui touche jusqu'à 5 ennemis »
const TUNING_FIRST_RANGE := 11.0
const TUNING_JUMP_RANGE := 6.0
const TUNING_FALLOFF := 0.12 # -12 % de dégâts à chaque rebond
const ZAP_VOLUME_DB := -8.0 # volume « moyen » demandé pour le son d'arc électrique

# Riff électrique (touche 1) : une seule cible, combo rythmique.
const RIFF_COST := 6.0
const RIFF_BEAT := 0.7 # tempo du riff : un appui toutes les 0,7 s (~86 BPM)
const RIFF_BEAT_TOLERANCE := 0.16 # fenêtre acceptée autour du temps (± s)
const RIFF_MIN_INTERVAL := 0.3 # anti-spam
const RIFF_MAX_STACKS := 4 # « se multiplie jusqu'à 4 fois »...
const RIFF_MAX_MULT := 3.0 # ... « pour atteindre au maximum 3 fois sa puissance »
const RIFF_RANGE := 12.0

const WAVE_COST := 20.0
const WAVE_COOLDOWN := 4.0
const WAVE_RADIUS := 5.0
const WAVE_KNOCKBACK := 5.5

const SOLO_COST := 45.0
const SOLO_COOLDOWN := 18.0
const SOLO_NOTES := 5
const SOLO_SCREEN_RADIUS := 20.0

const POTION_HEAL_RATIO := 0.4
const POTION_PRICE := 25
const REST_PRICE := 10

# --- Ennemis ---------------------------------------------------------------
const ENEMY_DETECT_RADIUS := 4.0 # « une fois à 4 mètres du héros... »
const ENEMY_LOSE_RADIUS := 9.0 # Distance à laquelle ils abandonnent la poursuite
const ENEMY_SPEED_RATIO := 0.25 # « ... ils se déplacent à 0,25 × la vitesse du héros »
const ENEMY_ATTACK_COOLDOWN := 2.5 # « ... 1 attaque toutes les 2,5 secondes »
const ENEMY_ATTACK_WINDUP := 0.45 # Temps d'élan (télégraphie) avant le coup

const DROP_GOLD_CHANCE := 0.45
const DROP_POTION_CHANCE := 0.12
const DROP_ITEM_CHANCE := 0.08

const DEATH_GOLD_PENALTY := 0.25
