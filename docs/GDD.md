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

Riffald, barde errant à la crinière rousse et au manteau de cuir, affronte avec sa **guitare électrique Flying V** les légions de morts-vivants de **Morne, la Liche du Silence**, qui veut réduire le monde au mutisme en volant tout ce qui fait du bruit. Depuis la taverne du **Chèvre Fringante**, il accepte des quêtes, traverse les portails d'Ozz, le grand mage, et plonge dans des donjons générés procéduralement où chaque sort est un morceau de metal.

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
                         │ Ozz ouvre un portail     │ portail de retour
                         ▼                               │
   DONJON PROCÉDURAL : salles → squelettes → butin → capitaine → BOSS → sauvetage
                         │
                         └─ mort : réveil à la taverne, -25 % d'or, quête conservée
```

**Micro-boucle (30 s)** : repérer un groupe → l'attirer (rayon de détection 4 m) → le regrouper → Onde de choc → Accordage de cordes (mini-jeu à 90 BPM) qui rebondit d'ennemi en ennemi → Riff électrique toutes les secondes → finir à la guitare → fouiller les corps.
**Méso-boucle (15 min)** : un donjon complet, montée en tension vers le boss.
**Macro-boucle (heures)** : niveaux, reliques, nouvelles quêtes, arc narratif contre Morne.

## 4. Univers

### 4.1 Le monde
Le royaume de **Dissonance**, fantasy classique D&D où la musique est une force magique. Depuis un mois, les morts ne restent plus couchés et **volent tout ce qui fait du bruit** : cloches, tambours, poules, instruments. Derrière eux : **Morne, la Liche du Silence**, ancien chef d'orchestre banni qui veut imposer le silence éternel.

### 4.2 Lieux
| Lieu | Rôle | Ambiance |
|---|---|---|
| **La Chèvre Fringante** | Hub, taverne | Bois sombre, cheminée, lanternes, clair de lune par les fenêtres |
| **Catacombes Suintantes** | Donjon 1 (implémenté) | Pierre humide, mousse, flaques de bave verte, torches |
| **Cryptes de la Cathédrale** | Portail à XP (sous-sol de la taverne, implémenté) | Sous-sol d'une cathédrale, basalte rougeoyant, ruisseaux de lave en fusion (ponts de pierre) ; régénérées à chaque passage |
| **Temple du Dragon** | Chapitre 2, autre univers (implémenté) | Marches interminables sous l'orage, parvis, façade à tête de dragon ; dedans : vitraux, damier de marbre, nef à la fontaine de sang |
| **La montagne du Destin** | Chapitre 3 (implémenté) | Prairie au pied de la montagne, flancs rocheux, grottes des gobelins, col enneigé au-dessus des précipices |
| **Le Labyrinthe du Destin** | Chapitre 3 (implémenté) | Labyrinthe de murs de glace au sommet de la montagne ; au centre, l'arène du Minotaure |
| Le Beffroi Muet | Donjon 2 | Cloches arrachées, vent, corbeaux squelettes |
| La Fosse aux Tambours | Donjon 3 | Forge souterraine, rythmes tribaux inversés |
| L'Opéra Englouti | Donjon final | Salle de concert noyée, orgue d'os, Morne |

### 4.3 Personnages
- **Riffald, Barde du Tonnerre** (joueur) — mélange de Dave Mustaine (crinière rousse, attitude) et Ronnie James Dio (médaillon à cornes, charisme mystique), en version dark fantasy. Manteau de cuir, épaulières à pointes. Il joue d'une **réplique de Gibson Flying V** (finition cerise, plaque blanche, deux humbuckers, cordier en V, tête en flèche) portée bas à la sangle, manche vers le haut, comme un guitariste de metal. **Posture et démarche de Réprouvé (World of Warcraft)** : dos voûté, épaules haussées, tête projetée en avant, genoux fléchis, pas traînants et boiteux, balancement du buste et petites saccades nerveuses de la tête. Pendant le solo : cambré en arrière, manche dressé, headbang.
- **Gérald Pissenlit** — petit fromager « de la Comt... du coin », pieds nus fort bien épilés, éleveur de hibours (pour le lait). Donneur de la première quête ; si on refuse, il revient à la charge jusqu'à offrir du fromage d'hibours.
- **Plumeau** — bébé hibours adoré de Gérald, mascotte ; suit le héros après le sauvetage et apparaît ensuite dans la taverne.
- **Grokk Chope-de-Fer** — tavernier orc de la Chèvre Fringante (réputée pour le meilleur brie de tous les comtés) : potions, chambre, rachat de reliques, rumeurs.
- **Ozz** — le grand mage des portails (rockeur en perfecto et lunettes violettes), transport vers les donjons.
- **L'Inconnue encapuchonnée** — fil rouge narratif, annonce Morne.
- **Borin Barbe-de-Bière** — nain ivre, répliques aléatoires.
- **Sylvaine Luth-d'Argent** — barde elfe rivale ; futur duel de solos.
- **Gloubah, le Roi Grenouille** — boss 1, roi de tous les squelettes des Catacombes (pourquoi ? là n'est pas la question), serviteur de Morne.
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
| Riff électrique (FIREBALL, Riff black metal) | Clic droit | RB |
| Accordage de cordes (mini-jeu, 90 BPM) | 1 | A |
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
- **Décibels (dB) max** = (50 + 8 × mod CHA + 6 × (niveau − 1)) × 0,75 (réserve réduite de 25 % le 6 oct. 2026 : on en avait trop pour lancer les sorts en continu) ; régénération 4 dB/s × (1 + 0,15 × mod SAG)
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
- **Coup de guitare** : touche **toujours** (pas de jet d'attaque) ; 1 chance sur 20 de critique (dés doublés, chiffre doré).
- **Sorts** : **80 % de chances de toucher** leur cible sans amélioration (« Raté » sinon, chaque cible tirée à part). Les sorts joués en **mini-jeu** (Accordage de cordes, Solo de la Foudre, solos des talents) touchent toujours. Certains autorisent un **jet de sauvegarde** de la cible (d20 + bonus ≥ DD) pour diviser les dégâts par deux.
- **Ennemis** : même jet d'attaque contre la CA du héros ; « Esquive » s'affiche en cas d'échec. Chaque coup est précédé d'un **élan visible de 0,45 s** : reculer permet d'esquiver.

### 8.2 Arsenal du barde
| Capacité | Touche | Coût | Recharge | Effet |
|---|---|---|---|---|
| **Coup de guitare** | Clic gauche | — | 0,54 s | La Flying V empoignée par le manche, levée au-dessus de l'épaule puis abattue (20 % plus rapide depuis la v0.1.39). **1d6 + FOR**, touche toujours, cône frontal de 1,9 m, recul. |
| **Riff électrique** | Clic droit | 6 dB | **aucune** | Un éclair sur l'ennemi visé (12 m), 1d10 + CHA, avec le grésillement d'arc électrique (−8 dB). Plus de mini-jeu (il est passé à l'Accordage, 6 oct. 2026). Avec la **Batguitare** : **Riff black metal**, trait brumeux violet et vent brumeux. Avec la **Xplode** : **FIREBALL**, boule de feu crépitante. Aucune recharge pour les trois (6 oct. 2026) : un éclair par clic, seuls les dB le limitent. |
| **Accordage de cordes** | 1 | 12 dB | **10 s** | **Mini-jeu** (celui de l'ancien Riff électrique, avec le son riff electrique.wav) : une seule note (la touche 1), rapide, **90 BPM**. La 1re part avec le sort : un arc électrique frappe l'ennemi visé (11 m) ; chaque note suivante réussie rejoue le riff et **l'arc rebondit sur l'ennemi suivant** (6 m), **une note par cible, 5 cibles** (s'il ne reste personne, il refrappe le même). 2d6 + CHA, −12 % par rebond, touche toujours. **Une seule fausse note** (ou un appui à contretemps) l'arrête et **triple la recharge** (30 s). |
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
| **Diablotin** | 9 (+3/niv.) | 12 | +4, 1d6+1 (hachette) | Petit démon rouge cornu, ailes de chauve-souris : vole droit sur le héros (0,45 × sa vitesse), détecte à 6 m |
| **Démon cornu** | 32 (+9/niv.) | 14 | +5, 2d6+2 (grande hache) | Colosse de 2,4 m aux cornes de bélier et sabots ; le **Gardien des Cryptes** (30 % plus grand) garde la sortie des Cryptes et porte la Xplode (guitare) |
| **L'Ange déchu** (boss) | 260 (+40/niv.) | 14 | +6, 2d8+2 (guitare) | Boss du Temple du Dragon : riff infernal (la foudre tombe sur trois cercles), phase 2 sous 50 % (trois diablotins), garde la partition maudite ; laisse sa guitare, la Batguitare |
| **Gobelin** | 10 (+3/niv.) | 12 | +4, 1d6+1 | Modèle 3D d'Ulysse ; petit et vert, rapide (0,32 × la vitesse du héros), détecte à 5 m ; gourdin, coutelas ou lance (plus d'allonge) |
| **Élémentaire de roche** | 30 (+8/niv.) | 15 | +5, 2d6+2 | Rochers empilés liés par du magma ; très lent, coriace |
| **Élémentaire de glace** | 20 (+6/niv.) | 13 | +5, 1d8+2 | Cristaux de glace flottants, rapide (0,28) |
| **Le Bigfoot** (boss) | 210 (+32/niv.) | 13 | +6, 2d8+3 | Flancs de la montagne : lancer de rocher (cercle au sol), martèlement (onde de 4 m), rage sous 50 % |
| **Le Troll des cavernes** (boss) | 260 (+35/niv.) | 14 | +6, 2d10+3 | Grottes : écrasement à la massue, régénération (1,5 % PV/s sans coup reçu depuis 3 s), appelle 4 gobelins à 50 % |
| **L'Élémentaire de glace colossal** (boss) | 230 (+35/niv.) | 15 | +6, 2d8+3 | Col : pics de glace (trois cercles), blizzard sous 50 % (deux élémentaires de glace) |
| **Le Minotaure** (boss) | 340 (+45/niv.) | 15 | +7, 2d10+4 | Labyrinthe : fendoir, charge (traînée de cercles) ; à 5 % de PV, **duel de guitare** (voir 10.4) |
| *Prévus* : squelette archer, banshee (hurlement qui coupe la régénération de dB), golem de silence (immunisé au son), chef d'orchestre liche | | | | |

Machine à états des ennemis : **Errance → Poursuite (≤ 4 m) → Attaque (au contact) → Sonné (après un gros recul) → Mort**. Ils abandonnent la poursuite au-delà de 9 m et réagissent immédiatement s'ils sont touchés.

### 8.5 Boss : Gloubah, Grenouille des Marées Mortes
Trône au centre d'une mare croupie, garde Plumeau dans une cage.
- **Vague déferlante** (toutes les ~6 s) : un mur d'eau en arc de 110° part vers le héros → **s'écarter sur le côté**.
- **Bond écrasant** (toutes les 9-12 s, si le héros est loin) : cercle rouge au sol puis impact de zone (2d8+2).
- **Coup de langue** au contact (1 / 2,5 s).
- **Phase 2 (< 50 % PV)** : yeux rouges, rage, vagues toutes les ~4 s en **anneau complet avec une brèche de 70°** (il faut trouver la brèche), invocation de 2 squelettes.
- Butin (sur son corps) : Couronne de nénuphar (équipement épique, tête), potion, 450 XP.

## 9. Butin et économie
- **Le butin reste sur le corps** des ennemis vaincus : on le ramasse en **cliquant sur le corps** (ou [E] à côté). Tant qu'il reste quelque chose, le corps ne disparaît pas ; s'il porte un **équipement**, il « respire » en **jaune doré** (fondu d'une seconde). Coffres : butin au sol, attiré par le héros.
- **Médiators** (45 % des squelettes) : ramassés **automatiquement** (ils jaillissent du corps et filent vers le héros), **potions** (12 %), **équipement** (8 %, sans doublon).
- **Équipement, comme dans un MMO** : chaque objet a son emplacement (tête, cou, torse, poignets, ceinture, pieds, anneau, talisman, médiator, cordes, grimoire). Ramassé, il va dans le **sac** ; ses bonus de caractéristiques ne comptent qu'une fois **équipé** (fiche de personnage [C] ou inventaire [B]). 11 objets (Médiator en os, Perfecto clouté, Bottes de roadie, Chevalière tête de bouc, Couronne de Gloubah…), voir docs/OBJETS.md.
- **Boutique** (Brunhilde) : potion 25 po, chambre 10 po (restaure PV et dB).
- **Mort** : −25 % de l'or, réveil à la taverne, la quête reste en cours.
- **Prévu** : équipement complet (luths, médiators, amplis enchantés = emplacements d'arme / anneau / amulette), affixes aléatoires façon Diablo, forgeron-luthier pour améliorer les luths.

## 10. Quêtes

### 10.1 Quête 1 — « Le Petit Plumeau » (implémentée)
0. **Intro** : une nuit de Lune de Sang (encore un truc cliché de métalleux). Au sortir de la messe noire, le héros voit que les morts se sont ENCORE échappés du cimetière ; il fait mine de rien et file boire un thé glacé à la goyave à la Chèvre Fringante.
1. **Taverne** : attablé devant son thé et un plateau de fromages, le héros voit arriver Gérald, le fromager du coin : son hibours Plumeau a été enlevé par des squelettes. Il promet 50 médiators et le portrait de son arrière-arrière-arrière-grand-mère. *[Accepter / Refuser]* — à chaque refus il revient (« Et maintenant, tu veux bien ? », « Et maintenant ? », « Et là ? », « Allééééé… », « Je te donnerai du fromage d'hibours ! ») ; le fromage, offert une fois, donne +20 % de PV max pendant 20 min.
2. **Ozz** ouvre un portail sur le cercle de runes.
3. **Catacombes Suintantes** (faites main dans l'éditeur) : squelettes, rats, capitaines ; le **chef des squelettes** porte la clé de la salle du boss.
4. **Salle du boss** : Gloubah, le Roi Grenouille, garde Plumeau en cage (dialogue : combat, reddition ou amitié).
5. Victoire : la cage s'ouvre, Plumeau suit le héros ; le portail d'Ozz s'ouvre juste à côté du héros (c'est un mage, il fait des trucs de mage).
6. **Taverne** : rendre la quête → 300 XP, 50 médiators, Portrait de l'aïeule (+1 SAG, +1 CHA). Plumeau reste dans la taverne. L'Inconnue révèle que Gloubah servait Morne.

### 10.2 Portail à XP — les Cryptes de la Cathédrale (implémenté)
Le portail démoniaque du sous-sol de la taverne plonge dans les **Cryptes de la Cathédrale** : sous-sol d'une cathédrale traversé de ruisseaux de lave en fusion (1d4 + niveau de brûlure toutes les demi-secondes ; un ou deux ponts de pierre pour passer), peuplé de squelettes, diablotins, démons cornus et rats, **au niveau du héros**. Au fond, le **Gardien des Cryptes** et ses diablotins gardent le portail qui ramène au portail de la taverne. Les Cryptes **se régénèrent à chaque passage** (nouvelle graine) : on y retourne pour gagner de l'XP. Le portail bleu (T) y sert de sortie.

### 10.3 Quête 2 — « La Légende de Back Jlack » (implémentée)
1. **Taverne**, après Plumeau : la silhouette mystérieuse (l'Inconnue) appelle le héros (« Psst... Barde ! »). Elle raconte la légende d'un guitariste et chanteur, le sage **Back Jlack**, qui vainquit avec l'aide de Satan un mal bien plus grand : **Mèhn-Strïm**, un dragon qui voulait éradiquer le métal.
2. **Cinématique** : sur fond noir, le visage du sage en gros plan, en contre-plongée, sur fond d'orage ; « Plutôt que de raconter cette légende... vous allez la vivre ! »
3. **Autre univers** : au pied de marches interminables (un portail y ramène à la taverne de notre époque, pour se reposer). En haut, le parvis d'un temple à l'immense tête de dragon, et Back Jlack : le métal est menacé par Mèhn-Strïm, il faut le battre avec des riffs toujours plus hardcore ; ici, ce sont des démons corrompus... par d'autres démons.
4. **L'épreuve** : jouer le solo du sage, **« Chant de fer »** (`audio/riffs/chant_de_fer.mp3`, 24,7 s), **en entier** : une note du mini-jeu sur chacune des 78 notes du morceau (détectées dans l'enregistrement par `tools/audio/detect_notes.py` → `data/epreuve_solo.json`, la corde suit la hauteur de la note) ; il faut **80 %** de notes justes au moins. Échec : « reviens quand tu seras à la hauteur ». Réussite du premier coup : **+10 % de dégâts pendant 20 min**. La porte du temple s'ouvre dans un coup de tonnerre, des éclairs tombent du ciel ; Back Jlack demande de retrouver le **Pick du Destin** (un médiator, quoi) qui permettrait de jouer le riff ultime.
5. **Temple du Dragon** (donjon généré, thème « temple ») : allée centrale de la nef, **fontaine immense** (trois fois la taille du héros) : un ange déchu à la guitare infernale d'où jaillit du **sang**. Passé la fontaine, **une dizaine de démons rouges ailés** fondent sur le héros, hachettes levées ; vaincus, un **éclair** frappe dans un coup de tonnerre. Puis des salles à vitraux, démons et squelettes.
6. **Boss : l'ange déchu** et sa guitare. Il laisse la **partition maudite du Riff Ultime**, qui ne se joue qu'avec le Pick du Destin (sinon la foudre frappe : bouton « Jouer » dans l'inventaire). Elle servira plus tard contre Mèhn-Strïm.
7. **Back Jlack**, sur le parvis : 1200 XP, 150 médiators. Le Pick du Destin reste à trouver... Back Jlack renvoie le héros dans son époque, à la taverne.

### 10.4 Quête 3 — « Le Labyrinthe du Destin » (implémentée)
1. **Retour dans notre époque** : la partition en poche, Back Jlack renvoie le héros à la Chèvre Fringante. Reste à trouver le Pick du Destin.
2. **Ozz, le grand mage**, connaît le « pic » du Destin : il est dans la montagne du Dest... dans le **Labyrinthe du Destin**, un labyrinthe en haut d'une montagne, dont le trésor (le pick, justement) est gardé par, ni plus ni moins, **LE MINOTAURE**. Il ouvre un portail jusqu'au pied de la montagne, puis un autre après chaque étape.
3. **L'expédition** (`scenes/expedition.tscn`), cinq niveaux générés qui se suivent ; chacun reste tel quel tant qu'il n'est pas terminé (portail bleu T, retour à la taverne : on reprend au même niveau) :
   1. **La prairie au pied de la montagne** : haies, arbres, fleurs ; gobelins et quelques élémentaires de roche. Au bout, une bande de gobelins garde le sentier.
   2. **Les flancs de la montagne** : falaises, sapins, congères ; gobelins et élémentaires de roche. **Boss : le Bigfoot.**
   3. **Les grottes des gobelins**, à l'intérieur de la montagne : campements (feux, tentes), champignons lumineux, cristaux. **Boss : le troll des cavernes.**
   4. **Le col de la montagne** : **pas de murs, des précipices** (sentiers étroits au-dessus du vide, la vallée dans la brume, drapeaux de prière, neige au vent) ; élémentaires de glace et de roche. **Boss : l'élémentaire de glace colossal.**
   5. **Le Labyrinthe du Destin** : un **vrai labyrinthe** de glace (allées de 4 m, culs-de-sac, petites salles où rôdent les élémentaires de glace et de roche, aventuriers pris dans la glace), généré à chaque passage ; au bout, l'arène du Minotaure.
4. **Le Minotaure** : à **5 % de ses PV**, il jette sa hache, sort sa guitare et impose un **duel de guitare** : le solo « Edge of the Cliff » (`audio/riffs/edge_of_the_cliff.mp3`), une note du mini-jeu sur chacune des 94 notes détectées (`data/duel_minotaure.json`), **80 %** de notes justes au moins. Gagné : il s'incline et tombe, le **Pick du Destin** sur son corps. Perdu : il foudroie le héros d'un accord (25 % des PV, jamais mortel), reprend 35 % de ses PV, et le combat reprend (nouveau duel à 5 %).
5. Le pick ramassé, un portail d'Ozz ramène à la taverne ; **Ozz** : 2 500 XP, 300 médiators. Avec le pick, la partition maudite ne foudroie plus... mais le Riff Ultime attendra Mèhn-Strïm.

### 10.5 Quêtes suivantes (à produire)
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
7. **Torches** réparties sur tout le donjon (salles et couloirs) avec **au moins 11 m entre deux torches** : elles éclairent des zones précises et laissent des passages dans la pénombre. Les murs du fond (visibles depuis la caméra) sont servis en priorité. **Une torche de chaque côté de chaque porte** (sauf celle du boss). Les torches brûlent **rouge orangé tant que le héros n'est pas passé à moins de 15 m** d'elles, puis normalement pour de bon (sauvegardé) : on sait d'un coup d'œil où l'on est déjà venu.
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
- **La taverne devient un lobby** : les joueurs s'y retrouvent, chacun avec son personnage ; le portail d'Ozz embarque tout le groupe.
- **Classes du groupe** (un rôle par musicien) : Barde-guitariste (dégâts à distance), **Batteur-guerrier** (tank, rythme), **Bassiste-paladin** (soutien, auras de basse), **Chanteur-clerc** (soins par hymnes), **Claviériste-sorcier** (contrôle), **Cornemuseur-rôdeur** (pièges, DoT). Synergie : jouer en rythme entre joueurs déclenche des « accords de groupe ».
- **Mise à l'échelle** : PV des ennemis × (1 + 0,6 × (joueurs − 1)), butin instancié par joueur.
- **Déjà préparé dans le code** : les ennemis ciblent le héros via un groupe (`"hero"`) et non une référence unique ; les états de jeu passent par un bus de signaux ; l'état persistant est centralisé dans `GameState` (à répliquer côté serveur).

## 14. Interface
- **HUD** : PV / décibels / XP (en haut à gauche), suivi de quête (en haut à droite), barre de vie du boss (en haut au centre), barre de compétences avec recharges et coûts (en bas), invite d'interaction, messages flottants, nombres de dégâts colorés (blanc = physique, bleu = électrique, violet = son, or = critique).
- **Fenêtres** : dialogues à choix (texte qui défile, clic ou Espace pour l’afficher en entier, choix au clavier 1-2-3, portraits en direct du PNJ à gauche et du héros à droite ; le jeu continue, seul le héros qui parle attend), fiche de personnage D&D, pause, écran de mort, mini-jeu du solo.

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
| | Tempo hypnotique | Passif | Chaque note de l'Accordage de cordes ralentit l'ennemi touché de 40 % pendant 2 s |
| | Growl de l'Abîme | Actif 20 dB / 16 s | Les ennemis à 6 m fuient 3,5 s (boss : sonnés) |
| | Maître du tempo | Passif | Solo endiablé : 16 notes, chaque note réussie inflige 1d6 + CHA aux ennemis en transe |
| **Thrash** (destruction) | Distorsion | Passif | Accordage de cordes : 6 notes (6 cibles), +15 % |
| | Enceinte de façade | Actif 25 dB / 14 s | Enceinte posée au curseur : 6 pulsations de 1d8 + CHA (4 m) |
| | Overdrive | Passif | Riff électrique (FIREBALL, Riff black metal) : +25 % de dégâts |
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
