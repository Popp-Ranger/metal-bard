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
## Réserve de dB réduite de 25 % (6 oct. 2026) : on en avait trop pour lancer les sorts en continu.
const MANA_RESERVE := 0.75
const HERO_MANA_REGEN := 4.0 # dB par seconde
const HERO_BASE_AC := 11 # Armure de cuir cloutée : 11 + mod. DEX
const MAX_LEVEL := 20
const POINTS_PER_LEVEL := 2 # Points de caractéristique par niveau (variante « Oblivion »)
const ABILITY_CAP := 20

## XP totale requise pour atteindre le niveau (index + 1). Table officielle D&D 5e.
const XP_TABLE := [0, 300, 900, 2700, 6500, 14000, 23000, 34000, 48000, 64000,
	85000, 100000, 120000, 140000, 165000, 195000, 225000, 265000, 305000, 355000]

# --- Compétences -----------------------------------------------------------
## Sorts sans mini-jeu (Riff électrique, Onde de choc, talents) : 8 chances sur 10 de toucher. Accordage, Solo de
## la Foudre et les solos des talents (mini-jeux) touchent toujours, comme le coup de guitare.
const SPELL_HIT_CHANCE := 0.8
## Coup de guitare : touche toujours (pas de jet d'attaque), 1d6 + FOR, 20 % plus rapide qu'avant (0,65 s → 0,54 s).
const MELEE_COOLDOWN := 0.54
const MELEE_HIT_DELAY := 0.125 # instant du coup dans l'animation (0,5 s)
const MELEE_DICE := 6
const MELEE_RANGE := 1.9
const MELEE_KNOCKBACK := 2.5

# Accordage de cordes (touche 1) : mini-jeu (celui de l'ancien Riff électrique, 6 oct. 2026). Une seule note, à 90 BPM :
# la 1re part en lançant le sort, puis chaque note réussie rejoue le riff et l'arc électrique rebondit sur l'ennemi
# suivant (une note par cible, 5 cibles). Une fausse note arrête l'accordage et triple la recharge.
const TUNING_COST := 12.0
const TUNING_COOLDOWN := 10.0
const TUNING_MAX_TARGETS := 5 # « arc électrique qui touche jusqu'à 5 ennemis » : 5 notes
const TUNING_FIRST_RANGE := 11.0
const TUNING_JUMP_RANGE := 6.0
const TUNING_FALLOFF := 0.12 # -12 % de dégâts à chaque rebond
const TUNING_BPM := 90.0
const TUNING_FAIL_COOLDOWN_MULT := 3.0
const ZAP_VOLUME_DB := -8.0 # volume « moyen » demandé pour le son d'arc électrique

## Portail bleu de retour à la taverne (touche T) : durée d'incantation (s).
const TOWN_PORTAL_CAST := 3.0

# Riff électrique (clic droit) : un éclair sur l'ennemi visé, sans mini-jeu ni recharge : seuls les dB le limitent (FIREBALL
# avec la Xplode, Riff black metal avec la Batguitare).
const RIFF_COST := 6.0
const RIFF_RANGE := 12.0 # portée

const WAVE_COST := 20.0
const WAVE_COOLDOWN := 4.0
const WAVE_RADIUS := 5.0
const WAVE_KNOCKBACK := 5.5
const WAVE_HEADBANG := 1.25 # s : les ennemis touchés headbanguent, figés

const SOLO_COST := 45.0
const SOLO_COOLDOWN := 18.0
const SOLO_NOTES := 6 # réparties régulièrement sur solo_del_la_foudre.mp3
const SOLO_SCREEN_RADIUS := 20.0

# Glissade sur les genoux (barre Espace) : esquive toutes les attaques.
const DASH_DISTANCE := 5.0
const DASH_DURATION := 0.42
const DASH_COOLDOWN := 20.0

## Mini-jeux ratés (fausse note) : la recharge du sort est 2,5 fois plus longue.
const MINIGAME_FAIL_COOLDOWN_MULT := 2.5
## Ballade réparatrice : chaque seconde de musique jouée sans faute soigne 9 % des PV max
## (10 s = 90 % d'une barre de vie ; Healing.wav dure 12,3 s).
const BALLADE_HEAL_PER_SECOND := 0.09
## Lit de la taverne (chambre louée) : de 1 PV à 100 % en 10 s allongé.
const BED_FULL_HEAL_TIME := 10.0

# Potion, chambre, médiators : voir data/items.json (ItemDB).

# --- Ennemis ---------------------------------------------------------------
const ENEMY_DETECT_RADIUS := 4.0 # « une fois à 4 mètres du héros... »
const ENEMY_LOSE_RADIUS := 9.0 # Distance à laquelle ils abandonnent la poursuite
const ENEMY_SPEED_RATIO := 0.25 # « ... ils se déplacent à 0,25 × la vitesse du héros »
const ENEMY_ATTACK_COOLDOWN := 2.5 # « ... 1 attaque toutes les 2,5 secondes »
const ENEMY_ATTACK_WINDUP := 0.45 # Temps d'élan (télégraphie) avant le coup

const DROP_ITEM_CHANCE := 0.08

# --- Coopération (jusqu'à 6 joueurs) ---------------------------------------------
const COOP_MAX_PLAYERS := 6
const COOP_ENEMIES_PER_EXTRA_PLAYER := 0.33 # +33 % d'ennemis par joueur supplémentaire
const COOP_ENEMY_HP_PER_EXTRA_PLAYER := 0.25 # +25 % de PV ennemis par joueur supplémentaire


## Multiplicateur du nombre d'ennemis selon le nombre de joueurs (1 à 6).
static func coop_enemy_count_mult(players: int) -> float:
	return 1.0 + COOP_ENEMIES_PER_EXTRA_PLAYER * float(clampi(players, 1, COOP_MAX_PLAYERS) - 1)


## Multiplicateur des PV ennemis selon le nombre de joueurs.
static func coop_enemy_hp_mult(players: int) -> float:
	return 1.0 + COOP_ENEMY_HP_PER_EXTRA_PLAYER * float(clampi(players, 1, COOP_MAX_PLAYERS) - 1)

