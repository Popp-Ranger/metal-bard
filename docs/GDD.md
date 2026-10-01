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

Riffald, barde errant à la crinière rousse et au manteau de cuir, affronte avec sa **guitare électrique Flying V** les légions de morts-vivants de **Morne, la Liche du Silence**, qui veut réduire le monde au mutisme en volant tout ce qui fait du bruit. Depuis la taverne du **Crâne Hurlant**, il accepte des quêtes, traverse les portails du vieux mage Zarathos et plonge dans des donjons générés procéduralement où chaque sort est un morceau de metal.

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

**Micro-boucle (30 s)** : repérer un groupe → l'attirer (rayon de détection 4 m) → le regrouper → Onde de choc → Accordage de cordes en chaîne → Riff électrique en rythme sur le plus coriace → finir à la guitare → ramasser le butin.
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
- **Riffald, Barde du Tonnerre** (joueur) — mélange de Dave Mustaine (crinière rousse, attitude) et Ronnie James Dio (médaillon à cornes, charisme mystique), en version dark fantasy. Manteau de cuir, épaulières à pointes. Il joue d'une **réplique de Gibson Flying V** (finition cerise, plaque blanche, deux humbuckers, cordier en V, tête en flèche) portée bas à la sangle, manche vers le haut, comme un guitariste de metal. **Posture et démarche de Réprouvé (World of Warcraft)** : dos voûté, épaules haussées, tête projetée en avant, genoux fléchis, pas traînants et boiteux, balancement du buste et petites saccades nerveuses de la tête. Pendant le solo : cambré en arrière, manche dressé, headbang.
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
- **Lumière** : le héros porte un halo chaud (la « torche » de *Darkest Dungeon*) ; le donjon reste sombre mais lisible (lumière ambiante froide), ponctué de torches vacillantes bien espacées.
- **Post-traitement** (`shaders/post_fx.gdshader`) : contours encrés (filtre de Sobel), désaturation 20 %, teinte sépia froide, vignette, grain de pellicule.
- **Caméra** : isométrique orthographique à 45°, zoom à la molette, secousses sur les impacts. Les murs entre la caméra et le héros sont tramés (*cutaway* façon Diablo, `shaders/stone_wall.gdshader`).
- **Prototype** : tous les modèles sont construits en primitives (capsules, sphères, boîtes). Cible : modèles low-poly texturés à la main (Blender) avec contours épais, animations squelettiques.
- **UI** : parchemin sombre, bordures de fer, police à empattements (Cinzel / Georgia).

## 6. Contrôles

| Action | Clavier / souris | Manette (prévu) |
|---|---|---|
| Se déplacer | ZQSD (AZERTY) / WASD (QWERTY) / flèches | Stick gauche |
| Viser | Souris | Stick droit |
| Coup de guitare | Espace / clic gauche (maintenir = enchaîner) | X |
| Accordage de cordes | Clic droit | RB |
| Riff électrique (en rythme) | 1 | A |
| Onde de choc | 2 | B |
| Solo de la Foudre | 3 | Y |
| Mini-jeu du solo | 1 2 3 4 | Croix directionnelle |
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
| **FOR** Force | 12 (+1) | Jet d'attaque et dégâts du coup de guitare |
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
- **Talents** : 1 point par niveau à dépenser dans l'arbre de talents (voir 14 ter).

## 8. Combat

### 8.1 Résolution
- **Attaque au corps-à-corps** : d20 + maîtrise + mod FOR contre la CA de la cible. 1 naturel = échec, 20 naturel = critique (dés doublés, chiffre doré).
- **Sorts** : touchent automatiquement ; certains autorisent un **jet de sauvegarde** de la cible (d20 + bonus ≥ DD) pour diviser les dégâts par deux.
- **Ennemis** : même jet d'attaque contre la CA du héros ; « Esquive » s'affiche en cas d'échec. Chaque coup est précédé d'un **élan visible de 0,45 s** : reculer permet d'esquiver.

### 8.2 Arsenal du barde
| Capacité | Touche | Coût | Recharge | Effet |
|---|---|---|---|---|
| **Coup de guitare** | Espace | — | 0,65 s | La Flying V empoignée par le manche, levée au-dessus de l'épaule puis abattue. 1d8 + FOR, cône frontal de 1,9 m, recul. |
| **Accordage de cordes** | Clic droit | 12 dB | 1,2 s | Arc électrique qui rebondit sur **jusqu'à 5 ennemis** (portée 11 m, rebond 6 m). 2d6 + CHA, −12 % par rebond. Son de décharge électrique à volume moyen (−8 dB). |
| **Riff électrique** | 1 | 6 dB | 0,3 s | Éclair sur **une seule cible** (la plus proche du curseur, 12 m). 1d10 + CHA. **Combo rythmique** : chaque appui au tempo (toutes les 0,7 s ± 0,16 s) augmente le multiplicateur en 4 paliers : ×1 → ×1,67 → ×2,33 → **×3 (maximum)**. Tant que le joueur reste en rythme, le riff continue à ×3 ; un contretemps remet le combo à ×1. Chaque palier joue une note plus aiguë ; un métronome dans le HUD se remplit et passe au vert dans la fenêtre d'appui. |
| **Onde de choc** | 2 | 20 dB | 4 s | Onde sonore qui touche **tous les ennemis dans un rayon de 5 m**. 2d8 + CHA (sauvegarde : moitié), fort recul qui étourdit. |
| **Solo de la Foudre** | 3 | 45 dB | 18 s | Lance le **mini-jeu** ; en cas de réussite, **pluie d'éclairs sur tout l'écran** : 4d10 + CHA sur chaque ennemi visible. |
| **Potion de soin** | R | 1 potion | 1 s | Rend 40 % des PV max. |

### 8.3 Le mini-jeu du Solo (façon Guitar Hero)
- **Le jeu ne se met pas en pause** : un manche à 4 cordes apparaît sur la droite de l'écran pendant que les ennemis continuent d'attaquer. Le héros reste planté sur place mais est **invincible** jusqu'à la fin du solo (aura dorée, coups affichés « Invincible »).
- **5 notes** tombent sur des cordes aléatoires (jamais deux fois la même d'affilée), espacées de 0,38 à 0,6 s.
- Touches : **1 2 3 4** (rangée du haut ou pavé numérique) ; pendant le solo elles ne lancent pas de sort. Fenêtre « PARFAIT » ±80 ms, « BIEN » ±170 ms.
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
1. Grille 100 × 100 cases de 2 m. Placement de la **salle du boss (15 × 15 cases = 30 m)** puis de salles aléatoires (8-13 × 8-12 cases, soit 16 à 26 m) sans chevauchement (marge 3 cases). Couloirs larges de **3 cases (6 m)**.
2. **Arbre couvrant minimal (Prim)** entre les salles normales → tout est accessible.
3. **1-2 couloirs en boucle** pour éviter un donjon linéaire.
4. La salle du boss n'est reliée qu'à **une seule** salle : cul-de-sac final.
5. **Salle de départ = la plus éloignée du boss** en distance de parcours (BFS).
6. Peuplement : 2-4 squelettes par salle, un capitaine dans la salle la plus proche du boss, décor aléatoire (piles d'os, flaques de bave, piliers, tonneaux).
7. **Torches** réparties sur tout le donjon (salles et couloirs) avec **au moins 11 m entre deux torches** : elles éclairent des zones précises et laissent des passages dans la pénombre. Les murs du fond (visibles depuis la caméra) sont servis en priorité.
8. Graine stockée dans la sauvegarde (`dungeon_seed`) : un même portail donne le même donjon.

**Prévu** : salles « préfabriquées » (autel, bibliothèque, arène à pièges), coffres et pièges, salles secrètes, étages multiples, biomes par donjon, difficulté dynamique.

## 12. Audio
- **Musiques** (`audio/music/`) : `tavern_theme.mp3` en boucle dans la taverne (3 min 21, `Sfx.play_music()`) ; dans les donjons, les morceaux de `audio/music/donjons/` joués au hasard l’un après l’autre (`Sfx.play_playlist()`, sans répéter deux fois de suite le même) : déposer un MP3/OGG dans ce dossier suffit à l’ajouter. `dungeon_theme.mp3` n’est plus utilisé.
- **Dialogues** : chaque lettre affichée fait « babiller » le personnage (syllabes synthétisées à partir de formants de voyelles), avec un timbre propre à chacun (Riffald grave, Plumeau aigu).
- **Bruitages synthétisés par code** (`scripts/autoload/sfx.gd`) : décharge électrique, onde de choc, power chords distordus, tonnerre, coassements, os qui claquent. Le bourdon d'ambiance ne sert plus qu'à l'écran titre.
- **Trois canaux (bus) réglables séparément** dans **Options > Audio** (écran titre et menu pause) : *Musique*, *Sorts et effets*, *Dialogues*. Réglages appliqués en direct et sauvegardés dans `user://settings.cfg`.
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

## 14 bis. Création de personnage

Écran dédié après « Nouvelle partie » (`scenes/character_creation.tscn`), aperçu 3D sur une estrade éclairée par des projecteurs ; le personnage tourne et se fait pivoter à la souris. Bouton « Aléatoire ».

- **Nom** libre (repris dans les dialogues) et **sexe** : les PNJ accordent leurs phrases (« le barde » / « la barde », « un héros » / « une héroïne »...), la voix babillée du héros change de timbre.
- **Races** (taille réelle du modèle et de la collision) :

| Race | Taille | Carrure | Bonus | Trait racial |
|---|---|---|---|---|
| Humain | 1,8 m | normale | +1 à toutes les caractéristiques | Polyvalent : +10 % d'XP |
| Squelette | 1,8 m | fine | DEX +2, CON +1 | Un des leurs : les squelettes ennemis détectent à 3 m au lieu de 4 |
| Orc | 2,0 m | large | FOR +2, CON +1 | Rage sanguinaire : +2 aux dégâts du coup de guitare |
| Troll | 2,2 m | large | CON +2, FOR +1 | Régénération : 1 PV toutes les 2 s |
| Ogre | 2,5 m | massive | FOR +2, CON +2, DEX −1 | Colosse : +15 PV max |
| Démon | 1,8 m | normale | CHA +2, INT +1 | Sang infernal : +10 % de dégâts des sorts |

- **Cornes** (démon) : bélier, taureau, infernales. **Défenses** (orc, troll, ogre) : petites, grandes, brisées.
- **Barbes** (hommes, sauf squelette) : courte, longue tressée à anneaux de fer, bouc.
- **Coiffures** (toutes longues) : tresses, queue de cheval, longs lâchés, glam-metal ; 5 couleurs (roux sombre, noir corbeau, blond platine, blanc d'argent, violet).
- Détails de race : oreilles pointues (orc, démon), très longues (troll), long nez (troll), mâchoire massive (orc, troll, ogre), crâne et côtes apparentes (squelette), yeux lumineux de couleur propre à chaque race.

## 14 ter. Arbre de talents

5 branches × 4 paliers (`scripts/rpg/talent_db.gd`), **1 point de talent par niveau** (dont 1 au niveau 1). Dans une branche, chaque palier nécessite le précédent ; les points se répartissent librement entre les branches (spécialiste ou hybride). Les sorts actifs appris se placent automatiquement sur les touches **4 à 7** et se réassignent dans l'arbre (touche **T**, ou menu pause).

| Branche | Talent | Type | Effet |
|---|---|---|---|
| **Ballade** (soins) | Ballade réparatrice | Actif 25 dB / 12 s | 2d8 + CHA, puis 5 % PV max/s pendant 4 s |
| | Rappel | Passif | Chaque ennemi vaincu rend 3 PV et 4 dB |
| | Hymne du Phénix | Actif 35 dB / 30 s | Cercle de flammes (4 m, 8 s) : 6 % PV max/s |
| | Encore ! | Passif | Survit à un coup mortel à 1 PV + soin de 50 % (1 fois / 2 min) |
| **Mur du Son** (protection) | Mur de Larsen | Actif 20 dB / 15 s | Bouclier 10 + 3 × CHA + 2 × niveau pendant 8 s |
| | Cuir clouté renforcé | Passif | +2 CA |
| | Pile d'amplis | Actif 30 dB / 25 s | 6 s : dégâts reçus ÷ 2, riposte 1d6 + CHA sur l'attaquant |
| | Sustain | Passif | −10 % de dégâts ; le bouclier brisé explose et repousse |
| **Mosh Pit** (repoussement) | Wall of Death | Actif 15 dB / 6 s | Cône 7 m : 1d8 + CHA, projection violente |
| | Larsen persistant | Passif | Onde de choc : +2 m de rayon, recul +50 % |
| | Stage Diving | Actif 25 dB / 10 s | Saut (8 m, s'arrête aux murs), impact 4 m : 2d6 + CHA + recul |
| | Pogo | Passif | Les ennemis fortement repoussés sont assommés 1,5 s |
| **Transe** (contrôle) | **Solo endiablé** | Actif 30 dB / 25 s | Mini-jeu : les ennemis à 12 m se figent en headbang tant que les notes sont réussies (12 max) ; 1re fausse note = fin. Le héros peut se déplacer (60 % de vitesse). En transe, les ennemis ne bougent plus du tout, même frappés. |
| | Tempo hypnotique | Passif | Le Riff électrique ralentit sa cible de 40 % pendant 2 s |
| | Growl de l'Abîme | Actif 20 dB / 16 s | Les ennemis à 6 m fuient 3,5 s (boss : sonnés) |
| | Maître du tempo | Passif | Solo endiablé : 16 notes, chaque note réussie inflige 1d6 + CHA aux ennemis en transe |
| **Thrash** (destruction) | Distorsion | Passif | Accordage de cordes : 6 cibles, +15 % |
| | Enceinte de façade | Actif 25 dB / 14 s | Enceinte posée au curseur : 6 pulsations de 1d8 + CHA (4 m) |
| | Overdrive | Passif | Riff électrique : 5 paliers, ×4 max |
| | Pyrotechnie | Actif 40 dB / 20 s | 6 colonnes de feu autour du héros après 0,8 s : 4d6 chacune |

**Rôles en coop (à venir)** : Ballade = soigneur, Mur du Son = tank, Mosh Pit = contrôle de zone, Transe = contrôle de foule (idéal pour que les alliés frappent pendant que les ennemis headbanguent), Thrash = dégâts.

## 15. Feuille de route
Voir [ROADMAP.md](ROADMAP.md).

## 16. Risques
| Risque | Impact | Parade |
|---|---|---|
| Multijoueur ajouté trop tard | Réécriture massive | Architecture serveur-autoritaire dès la v0.4 ; tests réseau tôt |
| Production d'assets 3D | Retard | Style low-poly + contours ; packs CC0 (Kenney, Quaternius) pour les placeholders |
| Musique originale | Coût | Compositeur freelance ou musique générative en couches |
| Mini-jeu frustrant | Abandon du sort | Fenêtres de timing larges, réussite partielle récompensée, option d'accessibilité (solo auto à 70 %) |
