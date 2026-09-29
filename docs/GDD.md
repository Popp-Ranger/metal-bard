# METAL BARD — Game Design Document

> *« Quand le Silence viendra, barde, joue plus fort que lui. »*

| | |
|---|---|
| **Genre** | Hack'n'slash / action-RPG isométrique |
| **Moteur** | Godot 4.7 (GDScript, rendu Forward+) |
| **Plateformes** | PC (Windows / Linux / macOS), manette envisagée |
| **Joueurs** | Solo (v0.x) → coopération jusqu'à 6 joueurs (v1.0) |
| **Références** | *Diablo II/IV* (vue, rythme), *Darkest Dungeon* (direction artistique), *Donjons & Dragons 5e* (règles), *TES IV : Oblivion* (progression libre), *Guitar Hero* (mini-jeu), *Brütal Legend* (ton) |
| **Public** | Joueurs d'ARPG, fans de metal et de fantasy qui aiment l'humour noir |

---

## 1. Pitch

Riffald, barde errant à la crinière rousse et au manteau de cuir, affronte avec son **luth électrique** les légions de morts-vivants de **Morne, la Liche du Silence**, qui veut réduire le monde au mutisme en volant tout ce qui fait du bruit. Depuis la taverne du **Crâne Hurlant**, il accepte des quêtes, traverse les portails du vieux mage Zarathos et plonge dans des donjons générés procéduralement où chaque sort est un morceau de metal.

## 2. Piliers de conception

1. **Le metal EST la magie.** Chaque capacité est un geste musical : un riff, une onde, un solo. L'audio est un élément de gameplay, pas un décor.
2. **Sombre mais drôle.** Direction artistique lugubre façon *Darkest Dungeon* ; écriture pleine d'humour absurde (squelettes qui chantent faux, grenouille couronnée, nain philosophe).
3. **Des règles lisibles et justes.** Les jets de dés D&D sont visibles (« Raté », « Esquive », critiques dorés) ; chaque attaque ennemie est télégraphiée.
4. **Une boucle courte et addictive.** Taverne → quête → donjon (15-20 min) → boss → retour, récompense, progression.
5. **Pensé pour la coop.** Chaque système est conçu pour passer ensuite en multijoueur (autorité serveur, pas d'état global caché).

## 3. Boucle de jeu

```
         ┌──────────────────────── TAVERNE (hub) ────────────────────────┐
         │  PNJ • quêtes • boutique • repos • fiche de perso • sauvegarde │
         └───────────────┬───────────────────────────────▲───────────────┘
                         │ Zarathos ouvre un portail     │ portail de retour
                         ▼                               │
   DONJON PROCÉDURAL : salles → squelettes → butin → capitaine → BOSS → sauvetage
                         │
                         └─ mort : réveil à la taverne, -25 % d'or, quête conservée
```

**Micro-boucle (30 s)** : repérer un groupe → l'attirer (rayon de détection 4 m) → le regrouper → Onde de choc → Riff électrique en chaîne → finir au luth → ramasser le butin.
**Méso-boucle (15 min)** : un donjon complet, montée en tension vers le boss.
**Macro-boucle (heures)** : niveaux, reliques, nouvelles quêtes, arc narratif contre Morne.

## 4. Univers

### 4.1 Le monde
Le royaume de **Dissonance**, fantasy classique D&D où la musique est une force magique. Depuis un mois, les morts ne restent plus couchés et **volent tout ce qui fait du bruit** : cloches, tambours, poules, instruments. Derrière eux : **Morne, la Liche du Silence**, ancien chef d'orchestre banni qui veut imposer le silence éternel.

### 4.2 Lieux
| Lieu | Rôle | Ambiance |
|---|---|---|
| **Le Crâne Hurlant** | Hub, taverne | Bois sombre, cheminée, lanternes, clair de lune par les fenêtres |
| **Catacombes Suintantes** | Donjon 1 (implémenté) | Pierre humide, mousse, flaques de bave verte, torches |
| Le Beffroi Muet | Donjon 2 | Cloches arrachées, vent, corbeaux squelettes |
| La Fosse aux Tambours | Donjon 3 | Forge souterraine, rythmes tribaux inversés |
| L'Opéra Englouti | Donjon final | Salle de concert noyée, orgue d'os, Morne |

### 4.3 Personnages
- **Riffald, Barde du Tonnerre** (joueur) — mélange de Dave Mustaine (crinière rousse, attitude) et Ronnie James Dio (médaillon à cornes, charisme mystique), en version dark fantasy. Manteau de cuir, épaulières à pointes, luth électrique aux cordes lumineuses.
- **Gérald Pissenlit** — fermier éploré, propriétaire de Plumeau. Donneur de la première quête.
- **Plumeau** — bébé ours-hibou, mascotte ; suit le héros après le sauvetage et apparaît ensuite dans la taverne.
- **Brunhilde Chope-de-Fer** — tenancière, boutique (potions, chambre), rumeurs.
- **Zarathos le Grisonnant** — vieux mage des portails, transport vers les donjons.
- **L'Inconnue encapuchonnée** — fil rouge narratif, annonce Morne.
- **Borin Barbe-de-Bière** — nain ivre, répliques aléatoires.
- **Sylvaine Luth-d'Argent** — barde elfe rivale ; futur duel de solos.
- **Gloubah, Grenouille des Marées Mortes** — boss 1, servante de Morne.
- **Morne, la Liche du Silence** — antagoniste final.

## 5. Direction artistique

- **Palette** : bruns et noirs désaturés, accents chauds (torches, feu) et froids (lune, éclairs). Seuls les sorts et les objets rares sont saturés.
- **Lumière** : le héros porte un halo chaud (la « torche » de *Darkest Dungeon*) ; le reste du donjon est plongé dans le noir, ponctué de torches vacillantes.
- **Post-traitement** (`shaders/post_fx.gdshader`) : contours encrés (filtre de Sobel), désaturation 30 %, teinte sépia froide, vignette lourde, grain de pellicule.
- **Caméra** : isométrique orthographique à 45°, zoom à la molette, secousses sur les impacts. Les murs entre la caméra et le héros sont tramés (*cutaway* façon Diablo, `shaders/stone_wall.gdshader`).
- **Prototype** : tous les modèles sont construits en primitives (capsules, sphères, boîtes). Cible : modèles low-poly texturés à la main (Blender) avec contours épais, animations squelettiques.
- **UI** : parchemin sombre, bordures de fer, police à empattements (Cinzel / Georgia).

## 6. Contrôles

| Action | Clavier / souris | Manette (prévu) |
|---|---|---|
| Se déplacer | ZQSD (AZERTY) / WASD (QWERTY) / flèches | Stick gauche |
| Viser | Souris | Stick droit |
| Coup de luth | Espace / clic gauche (maintenir = enchaîner) | X |
| Riff électrique | 1 | A |
| Onde de choc | 2 | B |
| Solo de la Foudre | 3 | Y |
| Mini-jeu du solo | ← ↓ ↑ → ou D F J K | Croix directionnelle |
| Potion | R | LB |
| Interagir / parler | E | A (près d'un PNJ) |
| Fiche de personnage | C | Select |
| Pause | Échap | Start |
| Zoom | Molette | — |

Les touches sont déclarées en **touches physiques** : aucune configuration à faire entre AZERTY et QWERTY, et l'interface affiche la vraie lettre du clavier.

## 7. Système de personnage (D&D 5e adapté)

### 7.1 Caractéristiques
| Carac. | Départ | Effet en jeu |
|---|---|---|
| **FOR** Force | 12 (+1) | Jet d'attaque et dégâts du coup de luth |
| **DEX** Dextérité | 14 (+2) | Classe d'armure |
| **CON** Constitution | 13 (+1) | Points de vie |
| **INT** Intelligence | 10 (+0) | -4 % de temps de recharge par point de modificateur |
| **SAG** Sagesse | 8 (-1) | +15 % de régénération des décibels par point de modificateur |
| **CHA** Charisme | 16 (+3) | Dégâts des sorts, DD de sauvegarde, réserve de décibels |

Modificateur = ⌊(valeur − 10) / 2⌋, comme dans D&D. Plafond de base : 20 (les reliques peuvent dépasser).

### 7.2 Valeurs dérivées
- **PV max** = 30 + 4 × mod CON + (niveau − 1) × (7 + mod CON)
- **Décibels (dB) max** = 50 + 8 × mod CHA + 6 × (niveau − 1) ; régénération 4 dB/s × (1 + 0,15 × mod SAG)
- **Classe d'armure** = 11 (cuir clouté) + mod DEX
- **Bonus de maîtrise** = +2 (niv. 1-4), +3 (5-8), +4 (9-12)…
- **DD des sorts** = 8 + maîtrise + mod CHA

### 7.3 Progression
- **XP** : table officielle D&D 5e (300 XP pour le niveau 2, 900 pour le 3, 2 700 pour le 4…), niveau max 20.
- **Sources d'XP** : ennemis (squelette 50, capitaine 150, Gloubah 450) + quêtes (Plumeau 300).
- **Montée de niveau** : PV et dB restaurés, **+2 points de caractéristique à répartir librement** (variante « Oblivion » plus généreuse que les ASI de D&D tous les 4 niveaux).
- **Prévu** : arbre de talents par « Voie » (Thrash = vitesse, Doom = contrôle, Power = soutien de groupe) aux niveaux 3, 6, 10, 14, 18.

## 8. Combat

### 8.1 Résolution
- **Attaque au corps-à-corps** : d20 + maîtrise + mod FOR contre la CA de la cible. 1 naturel = échec, 20 naturel = critique (dés doublés, chiffre doré).
- **Sorts** : touchent automatiquement ; certains autorisent un **jet de sauvegarde** de la cible (d20 + bonus ≥ DD) pour diviser les dégâts par deux.
- **Ennemis** : même jet d'attaque contre la CA du héros ; « Esquive » s'affiche en cas d'échec. Chaque coup est précédé d'un **élan visible de 0,45 s** : reculer permet d'esquiver.

### 8.2 Arsenal du barde
| Capacité | Touche | Coût | Recharge | Effet |
|---|---|---|---|---|
| **Coup de luth** | Espace | — | 0,65 s | On frappe en tenant le luth par le manche. 1d8 + FOR, cône frontal de 1,9 m, recul. |
| **Riff électrique** | 1 | 12 dB | 1,2 s | Arc électrique qui rebondit sur **jusqu'à 5 ennemis** (portée 11 m, rebond 6 m). 2d6 + CHA, −12 % par rebond. Son de décharge électrique à volume moyen (−8 dB). |
| **Onde de choc** | 2 | 20 dB | 4 s | Onde sonore qui touche **tous les ennemis dans un rayon de 5 m**. 2d8 + CHA (sauvegarde : moitié), fort recul qui étourdit. |
| **Solo de la Foudre** | 3 | 45 dB | 18 s | Lance le **mini-jeu** ; en cas de réussite, **pluie d'éclairs sur tout l'écran** : 4d10 + CHA sur chaque ennemi visible. |
| **Potion de soin** | R | 1 potion | 1 s | Rend 40 % des PV max. |

### 8.3 Le mini-jeu du Solo (façon Guitar Hero)
- Le monde se fige, un manche à 4 cordes apparaît. **5 notes** tombent sur des cordes aléatoires (jamais deux fois la même d'affilée), espacées de 0,38 à 0,6 s.
- Touches : **← ↓ ↑ →** ou **D F J K**. Fenêtre « PARFAIT » ±80 ms, « BIEN » ±170 ms.
- Chaque note réussie joue un **power chord distordu** (gamme pentatonique de mi).
- Résultat : **5/5 → 100 %**, 4/5 → 70 %, 3/5 → 45 %, moins → **fausse note** (le sort échoue, la moitié des dB est perdue).
- Évolutions prévues : longueur du solo qui augmente avec le niveau, notes tenues, accords (2 touches), solos écrits à la main pour les boss.

### 8.4 Bestiaire
| Ennemi | PV | CA | Attaque | Particularités |
|---|---|---|---|---|
| **Squelette** | 13 (+4/niv.) | 13 | +4, 1d6+2 | Erre au hasard ; détecte à **4 m** ; se déplace à **0,25 × la vitesse du héros** ; **1 attaque / 2,5 s** |
| **Capitaine squelette** | 30 (+8/niv.) | 15 | +5, 1d10+3 | Casque à cornes, garde la salle voisine du boss, 150 XP |
| **Gloubah** (boss) | 120 | 12 | +5, 2d6+3 (langue) | Voir ci-dessous |
| *Prévus* : squelette archer, banshee (hurlement qui coupe la régénération de dB), golem de silence (immunisé au son), chef d'orchestre liche | | | | |

Machine à états des ennemis : **Errance → Poursuite (≤ 4 m) → Attaque (au contact) → Sonné (après un gros recul) → Mort**. Ils abandonnent la poursuite au-delà de 9 m et réagissent immédiatement s'ils sont touchés.

### 8.5 Boss : Gloubah, Grenouille des Marées Mortes
Trône au centre d'une mare croupie, garde Plumeau dans une cage.
- **Vague déferlante** (toutes les ~6 s) : un mur d'eau en arc de 110° part vers le héros → **s'écarter sur le côté**.
- **Bond écrasant** (toutes les 9-12 s, si le héros est loin) : cercle rouge au sol puis impact de zone (2d8+2).
- **Coup de langue** au contact (1 / 2,5 s).
- **Phase 2 (< 50 % PV)** : yeux rouges, rage, vagues toutes les ~4 s en **anneau complet avec une brèche de 70°** (il faut trouver la brèche), invocation de 2 squelettes.
- Butin : Couronne de nénuphar (relique épique), potion, 60-90 po, 450 XP.

## 9. Butin et économie
- **Or** (45 % des squelettes), **potions** (12 %), **reliques** (8 %, sans doublon).
- **Reliques** : bonus permanents de caractéristiques (commun → épique). 7 reliques dans la v0.1 (Médiator en os, Cordes en boyau de dragon, Pendentif de plume, Couronne de Gloubah…).
- **Boutique** (Brunhilde) : potion 25 po, chambre 10 po (restaure PV et dB).
- **Mort** : −25 % de l'or, réveil à la taverne, la quête reste en cours.
- **Prévu** : équipement complet (luths, médiators, amplis enchantés = emplacements d'arme / anneau / amulette), affixes aléatoires façon Diablo, forgeron-luthier pour améliorer les luths.

## 10. Quêtes

### 10.1 Quête 1 — « Le Petit Plumeau » (implémentée)
1. **Taverne** : Gérald supplie le héros de retrouver Plumeau, son bébé ours-hibou enlevé par des squelettes. *[Accepter]*
2. **Zarathos** ouvre un portail violet sur le cercle de runes.
3. **Catacombes Suintantes** (procédurales, ~10 salles) : squelettes, capitaine, butin.
4. **Salle du trône** : Gloubah garde Plumeau en cage. Combat de boss.
5. Victoire : la cage s'ouvre, Plumeau suit le héros ; Zarathos ouvre un portail de retour.
6. **Taverne** : rendre la quête → 300 XP, 100 po, Pendentif de plume (+1 CHA, +1 SAG). Plumeau reste dans la taverne. L'Inconnue révèle que Gloubah servait Morne.

### 10.2 Quêtes suivantes (à produire)
| Quête | Donneur | Donjon | Boss | Mécanique nouvelle |
|---|---|---|---|---|
| La Cloche Muette | Le prêtre du village | Beffroi Muet | Le Sonneur Décharné | Zones de silence où les sorts sont impossibles |
| Le Duel des Luths | Sylvaine | (taverne) | Sylvaine | Duel de solos : mini-jeu compétitif |
| Les Tambours de Guerre | Borin | Fosse aux Tambours | Le Roi-Tambour | Ennemis synchronisés sur un tempo |
| L'Opéra Englouti | L'Inconnue | Opéra | Morne | Boss en 3 actes, solo final écrit à la main |

**Quêtes secondaires procédurales** (tableau des quêtes) : « tuer X capitaines », « récupérer l'instrument volé de… », « escorter un ménestrel ».

## 11. Génération procédurale des donjons
Implémentée dans `scripts/world/dungeon_generator.gd` (logique pure, testée sur 50 graines à chaque exécution des tests) :
1. Grille 64 × 64 cases de 2 m. Placement de la **salle du boss (11 × 11)** puis de salles aléatoires (5-9 × 5-8) sans chevauchement (marge 3 cases).
2. **Arbre couvrant minimal (Prim)** entre les salles normales → tout est accessible.
3. **1-2 couloirs en boucle** pour éviter un donjon linéaire.
4. La salle du boss n'est reliée qu'à **une seule** salle : cul-de-sac final.
5. **Salle de départ = la plus éloignée du boss** en distance de parcours (BFS).
6. Peuplement : 1-3 squelettes par salle, un capitaine dans la salle la plus proche du boss, décor aléatoire (piles d'os, flaques de bave, piliers, tonneaux), torches sur les murs du fond.
7. Graine stockée dans la sauvegarde (`dungeon_seed`) : un même portail donne le même donjon.

**Prévu** : salles « préfabriquées » (autel, bibliothèque, arène à pièges), coffres et pièges, salles secrètes, étages multiples, biomes par donjon, difficulté dynamique.

## 12. Audio
- **Tous les sons du prototype sont synthétisés par code** (`scripts/autoload/sfx.gd`) : décharge électrique, onde de choc, power chords distordus, tonnerre, coassements, os qui claquent, ambiances en boucle (bourdon du donjon, feu de cheminée).
- **Cible** : bande-son heavy / doom metal originale ; la musique s'intensifie en combat (couches adaptatives : batterie seule → + basse → + guitares au contact du boss) ; le Solo de la Foudre se cale sur le tempo de la musique.
- Volume des sorts calibré (Riff électrique à −8 dB, « volume moyen »).

## 13. Multijoueur (jusqu'à 6) — conception
- **Modèle** : serveur autoritaire (un joueur héberge), API haut niveau de Godot (`MultiplayerAPI`, `MultiplayerSpawner`, `MultiplayerSynchronizer`) sur ENet ; Steam (GodotSteam) pour le matchmaking.
- **La taverne devient un lobby** : les joueurs s'y retrouvent, chacun avec son personnage ; le portail de Zarathos embarque tout le groupe.
- **Classes du groupe** (un rôle par musicien) : Barde-guitariste (dégâts à distance), **Batteur-guerrier** (tank, rythme), **Bassiste-paladin** (soutien, auras de basse), **Chanteur-clerc** (soins par hymnes), **Claviériste-sorcier** (contrôle), **Cornemuseur-rôdeur** (pièges, DoT). Synergie : jouer en rythme entre joueurs déclenche des « accords de groupe ».
- **Mise à l'échelle** : PV des ennemis × (1 + 0,6 × (joueurs − 1)), butin instancié par joueur.
- **Déjà préparé dans le code** : les ennemis ciblent le héros via un groupe (`"hero"`) et non une référence unique ; les états de jeu passent par un bus de signaux ; l'état persistant est centralisé dans `GameState` (à répliquer côté serveur).

## 14. Interface
- **HUD** : PV / décibels / XP (en haut à gauche), suivi de quête (en haut à droite), barre de vie du boss (en haut au centre), barre de compétences avec recharges et coûts (en bas), invite d'interaction, messages flottants, nombres de dégâts colorés (blanc = physique, bleu = électrique, violet = son, or = critique).
- **Fenêtres** : dialogues à choix (texte qui défile, choix au clavier 1-2-3), fiche de personnage D&D, pause, écran de mort, mini-jeu du solo.

## 15. Feuille de route
Voir [ROADMAP.md](ROADMAP.md).

## 16. Risques
| Risque | Impact | Parade |
|---|---|---|
| Multijoueur ajouté trop tard | Réécriture massive | Architecture serveur-autoritaire dès la v0.4 ; tests réseau tôt |
| Production d'assets 3D | Retard | Style low-poly + contours ; packs CC0 (Kenney, Quaternius) pour les placeholders |
| Musique originale | Coût | Compositeur freelance ou musique générative en couches |
| Mini-jeu frustrant | Abandon du sort | Fenêtres de timing larges, réussite partielle récompensée, option d'accessibilité (solo auto à 70 %) |
