# Feuille de route

## ✅ v0.1 — Prototype jouable (actuel)
- [x] Taverne-hub complète : tables, chaises, comptoir, bouteilles, fenêtres au clair de lune, lanternes, cheminée, escalier
- [x] 6 PNJ avec dialogues à choix (Gérald, Brunhilde, Ozz, l'Inconnue, Borin, Sylvaine) + tableau des quêtes
- [x] Boutique (potions) et repos
- [x] Portail d'Ozz → donjon séparé du hub
- [x] Donjon procédural (graine sauvegardée, salle de départ la plus éloignée du boss)
- [x] Héros : coup de luth + Riff électrique (5 cibles) + Onde de choc (zone) + Solo de la Foudre (mini-jeu Guitar Hero → pluie d'éclairs)
- [x] IA squelettes : errance, détection 4 m, vitesse 0,25 × héros, 1 attaque / 2,5 s avec élan
- [x] Capitaine squelette, boss Gloubah (vagues, bond, phase 2, invocations), sauvetage de Plumeau
- [x] Règles D&D 5e : 6 caractéristiques, modificateurs, jets d'attaque, CA, sauvegardes, table d'XP, points à répartir
- [x] Butin : or, potions, 7 reliques
- [x] HUD, fiche de personnage, pause, mort et réveil à la taverne, sauvegarde / chargement
- [x] Éclairage dynamique, murs qui s'effacent devant le héros
- [x] Sons synthétisés (dont décharge électrique à volume moyen)
- [x] Test automatisé de toute la boucle de jeu

## ✅ v0.1.1 — Retours de jeu
- [x] Solo : touches 1 2 3 4, sans pause, héros invincible pendant le mini-jeu
- [x] Réplique de Gibson Flying V, tenue de guitariste metal (bras en IK)
- [x] Posture et démarche de Réprouvé (World of Warcraft)
- [x] Accordage de cordes au clic droit (ancien Riff électrique, 5 cibles)
- [x] Nouveau Riff électrique : une cible, combo rythmique jusqu'à ×3 + métronome dans le HUD
- [x] Salles et couloirs plus grands, torches espacées, rendu moins sombre

## ✅ v0.1.2 — Audio
- [x] Musiques metal de la taverne et du donjon
- [x] Menu Options > Audio : Musique / Sorts et effets / Dialogues, réglages sauvegardés
- [x] Voix babillées pendant les dialogues

## ✅ v0.1.3 — Personnage et talents
- [x] Création de personnage : nom, sexe, 6 races (1,8 à 2,5 m) avec bonus et traits, cornes, défenses, barbes, 4 coiffures longues, couleurs
- [x] Arbre de talents : 5 branches × 4 paliers (soins, protection, repoussement, contrôle, destruction), 1 point par niveau
- [x] 10 sorts actifs sur les touches 4 à 7 dont le Solo endiablé (headbang des ennemis)
- [x] Ennemis : états transe, peur, ralentissement, étourdissement

## ✅ v0.1.4 — Taverne vivante et donjon scénarisé
- [x] Taverne sur 3 niveaux : étage et chambres, sous-sol d'entraînement (3 mannequins groupés, 1 isolé, cible amicale pour les soins de groupe)
- [x] Clients générés avec l'outil de création de personnage : comptoir (≤ 20 s), table (≥ 40 s)
- [x] Brunhilde, ogresse 1,5 fois plus large ; Katrkar en fauteuil roulant
- [x] « ! » / « ? » verts au-dessus des donneurs de quête
- [x] Ennemis qui fixent le héros, salles cul-de-sac à 12 squelettes, compteur de victimes, récapitulatif des dégâts
- [x] Cage de Plumeau, clé de Gloubah ([E] ou clic), retrouvailles avec Gérald
- [x] Dialogue de Gloubah à 3 issues (combat, capture, amitié et XP doublée)

## ✅ v0.1.5 — Lune de Sang, coop et confort
- [x] Intro : cinématique de la lune de sang, cimetière et chapelle, route pavée d'environ 40 s sous l'orage (éclairs, flashs, tremblements, chauves-souris, cadavres)
- [x] Portes de la taverne qui se referment après l'intro (à rouvrir par une quête future : drapeau `tavern_doors_open`)
- [x] Glissade sur les genoux (Espace, 5 m, esquive totale, 20 s), saut à la Angus Young sur esquive passive
- [x] Ballade réparatrice : mini-jeu sur le solo extrait de la musique de la taverne
- [x] Mini-jeux ratés : recharge ×2,5
- [x] Médiators comme monnaie ; objets dans `data/items.json`
- [x] Sous-sol : dB illimités et portail démoniaque à tentacules ; l'Inconnue réinitialise les talents
- [x] Clients qui déplacent leur chaise, 2 debout au maximum, jurons ; Ozz fait les cent pas
- [x] Gloubah sur un pentagramme de bave, sang au sol et sur la bouche ; rats (3 PV)
- [x] Sauvegarder (hors combat) et Charger : 5 emplacements + automatique
- [x] Coop en ligne par code d'invitation (ENet + UPnP), chacun avec son personnage
- [x] Musique par défaut à 50 %

## ✅ v0.1.6 — Cel shading et vrais sons
- [x] Cel shading (lumière toon, contour encré des personnages, post-traitement plus marqué)
- [x] Proportions réalistes, démarche réaliste, mains à cinq doigts (jeu de guitare animé)
- [x] Coop 6 joueurs : +33 % d'ennemis et +25 % de PV ennemis par joueur supplémentaire, bouton « Héberger » sur l'écran titre, code affiché dans le HUD
- [x] Riff électrique : recharge 3 s, son `riff electrique.wav`
- [x] Ballade réparatrice sur `Healing.wav`, notes synchronisées
- [x] Musique d'orage `lightning_menu.mp3` (menu + intro) avec éclairs calés sur le tonnerre ; sons d'éclairs `short_lightning` / `short_thunder`

## ✅ v0.1.7 — Sons et taverne qui bouge
- [x] Onde de choc : son `ondes de chocs.wav`
- [x] Solo de la Foudre : morceau `solo_del_la_foudre.mp3`, 6 notes régulières, éclairs au son `short_thunder`
- [x] Clients qui marchent vraiment jusqu'au comptoir et reviennent avec une chope (2 debout au maximum) ; correction du suivi de chemin des PNJ

## ✅ v0.1.8 — Portes, portail de retour et repos au lit
- [x] Portes à ouvrir dans le donjon ; salles sombres et occupants endormis tant que la porte est fermée
- [x] Salle du boss fermée à clé ; clé portée par le chef des squelettes (25 % plus grand, tête de loup en capuche)
- [x] Touche K : arbre de talents ; touche T : portail bleu de retour à la taverne, donjon persistant jusqu'à la fin
- [x] Chambre louée : se coucher sur le lit pour récupérer (1 PV → 100 % en 10 s)

## ✅ v0.1.9 — Intro plus courte
- [x] Route de l'intro ramenée à ~20 s de marche, tracé sinueux (virages jusqu'à ~70°)

## ✅ v0.1.10 — Déplacement à la souris
- [x] Clic sur le sol : le héros y va (zone lumineuse au sol) ; clic maintenu : il suit la souris
- [x] Clic sur un ennemi : il va le frapper ; clic sur un PNJ ou un objet : il va interagir ; Maj + clic : frappe sur place

## ✅ v0.1.11 — Héros prédéfini
- [x] Création : choix « Riffald (prédéfini) » ou « Personnalisé » ; planche de référence et fiche dans docs/RIFFALD.md
- [x] Modèle Blender de Riffald d'après la planche, piloté par le squelette procédural (v0.1.12)
- [x] Guitare des héros modélisée dans Blender (v0.1.12)

## ✅ v0.1.13 — Coop : sorts visibles par tous
- [x] Tous les sorts et coups de chaque joueur sont rejoués chez les autres (SpellFx), son atténué avec la distance
- [x] Synchronisation des ennemis découpée en paquets sous le MTU (grands donjons)
- [x] Test réseau réel à deux instances (tests/coop_net_test.tscn)

## ✅ v0.1.14 — Vraies animations (Mixamo + AnimationTree)
- [x] 16 animations Mixamo transférées sur le squelette de Riffald dans Blender (art/riffald/retarget_mixamo.py)
- [x] AnimationTree : repos (voûté quand la vie est basse), marche, course accélérée à la vitesse du héros
- [x] Coups de guitare alternés (vertical / diagonal), guitare empoignée par le manche
- [x] Onde de choc (frappe du sol), sorts de soutien, solo en headbang, glissade, Stage Diving (vol + réception), victoire, mort, lit
- [x] Sursaut du haut du corps quand il est touché, hochement de tête sur les accords
- [x] IK après l'animation (SkeletonModifier3D) : guitare à la sangle, mains sur le manche et les cordes
- [ ] Doigts, cape et cheveux animés (os supplémentaires + SpringBoneSimulator3D)
- [ ] Animations des héros personnalisés et des PNJ (reciblage)

## ✅ v0.1.15 — Lumière
- [x] Filtre plein écran retiré (contours encrés, sépia, désaturation, vignette, grain)
- [x] Environnement plus lumineux, sans occlusion ambiante ni filtre de contraste
- [x] Ombres courtes : seule une lumière presque au zénith en projette (plus les lampes basses)
- [x] Export Windows (.pck) pour tester le multijoueur entre amis

## ✅ v0.1.16 — Coop par Internet sans UPnP
- [x] Plusieurs codes pour l'hôte : Internet (adresse publique, port ouvert à la main), VPN (Radmin VPN, Tailscale, ZeroTier...), réseau local
- [x] Rejoindre en tapant une adresse IP ; abandon au bout de 12 s sans réponse, avec des pistes

## ✅ v0.1.17 — Riffald v3, texturé
- [x] Modèle refait au plus près de la planche 3D : épaulières en chevron à quatre pointes, genouillères en écusson, bottes à revers clouté et bout ferré, crinière en mèches ondulées, visage encadré par les mèches
- [x] Mains gauche et droite remises à l'endroit
- [x] Textures peintes avec ombres (cuir froissé, acier rayé, tissu, peau, mèches) cuites dans un atlas 4096 (art/riffald/texture_riffald.py)
- [x] Cuir et acier assombris en jeu pour ne pas être délavés par les projecteurs
- [x] Mains sur la guitare : la gauche au bout du manche (près du sillet), doigts repliés sur la touche ; la droite qui gratte sur la caisse ; guitare de Riffald agrandie ×1,3 comme ses mains
- [x] Pas de sorts ni de coups de guitare dans la taverne (sauf au sous-sol d'entraînement) : la guitare passe dans le dos, manche vers le bas incliné à 45° vers la gauche

## ✅ v0.1.18 — Valkyriff, héroïne prédéfinie
- [x] Deuxième héros prédéfini, Valkyriff, d'après le modèle fourni (persoF1) : allégé à 40 000 triangles, mis à 1,74 m
- [x] Même squelette (17 os), mêmes 16 animations Mixamo et même Flying V que Riffald ; cape et tresse pondérées à part
- [x] Sélecteur « Héros » : Riffald, l'héroïne ou personnage personnalisé ; taille réelle affichée (docs/PERSOF1.md)

## ✅ v0.1.19 — Tout le monde bouge comme Riffald
- [x] Héros personnalisés, clients et PNJ : posture et déplacement de Riffald (mêmes clips Mixamo, recopiés sur le corps procédural)
- [x] Gérald, Ozz et l'Inconnue deviennent des corps articulés en costume (Ozz tient son bâton)
- [x] Intro : Espace ou Échap passe la cinématique

## ✅ v0.1.20 — Squelettes articulés
- [x] Les squelettes ennemis (et les futurs ennemis humanoïdes, via HumanoidBody) ont la posture et la démarche de Riffald
- [x] Coup d'épée par IK : élan au-dessus de l'épaule, frappe avec coup de poignet

## ✅ v0.1.21 — Squelettes zombies
- [x] Les squelettes ont le repos et la course de zombie de Mixamo (Zombie Idle, Zombie Running)

## ✅ v0.1.22 — Éditeur de donjon
- [x] Premier donjon fait main dans l'éditeur de Godot : sol peint case par case (GridMap), murs automatiques, salles, objets à glisser-déposer (docs/EDITEUR_NIVEAUX.md)
- [x] Vérification du donjon et test direct (F6) ; les donjons suivants restent générés

## ✅ v0.1.23 — Éditeur de taverne
- [x] La Chèvre Fringante fait main dans l'éditeur : sols et murs en cases de 1 m (murs, fenêtres éclairées par la lune, murets, cloisons), mobilier et points du jeu à glisser-déposer
- [x] Tables (places des clients), comptoir, escaliers reliés à leur arrivée, lit loué, salle d'entraînement, PNJ ; vérification et test direct (F6)

## ✅ v0.1.24 — PNJ et squelettes en 3D
- [x] Ozz (mage), Grokk le tavernier orc (remplace Brunhilde) et tous les squelettes ennemis : modèles 3D fournis, squelette de Riffald et clips Mixamo (docs/PNJ_3D.md)
- [x] Squelettes : course de zombie, coup d'épée animé, sursaut, mort ; épée, bouclier, casque et peau de loup accrochés aux os

## ✅ v0.1.25 — Ennemis de face, musiques des donjons
- [x] Rats et squelettes marchent et frappent face au joueur (l'orientation d'apparition passe au modèle, le corps reste droit)
- [x] Donjons : les 5 musiques de `audio/music/donjons/` en lecture aléatoire, enchaînées sans répétition
- [x] Grokk le tavernier : poids repeints à la main dans Blender, glb réexporté

## ✅ v0.1.26 — Continuer, tavernier imposant, Valkyriff retouchée
- [x] « Continuer » reprend la sauvegarde la plus récente, automatique ou manuelle (idem pour héberger une partie)
- [x] Grokk le tavernier agrandi de 25 % (foulée et étiquette suivent)
- [x] Valkyriff : poids repeints à la main dans Blender, glb réexporté

## ✅ v0.1.27 — Dialogues sans pause, rendu sans cel shading, pénombre
- [x] Parler à un PNJ ne met plus le jeu en pause : le monde continue (ennemis, autres joueurs), seul le héros attend
- [x] Cel shading retiré (lumière en aplats et contour encré) : éclairage réaliste
- [x] Un peu plus sombre (ambiance et exposition baissées), bien moins que les premières versions

## ✅ v0.1.28 — Valkyriff à 1,84 m
- [x] Valkyriff agrandie en jeu à 1,84 m, comme Riffald (préréglage `scale`, son .blend reste à 1,74 m)

## ✅ v0.1.29 — Belzeluth, le démon jouable
- [x] Troisième héros prédéfini : Belzeluth, démon d'après le modèle fourni (1,95 m, 17 os, animations de Riffald, Flying V)
- [x] Ébauche des poids automatique, peinture finie à la main par Ulysse dans Blender (docs/DEMON.md)

## ✅ v0.1.30 — Nouvelles poses de repos
- [x] Héros (Riffald, Valkyriff, Belzeluth, personnalisés) : repos « heroPose »
- [x] PNJ (clients, Gérald, Ozz...) : repos « pnjPose » ; Grokk le tavernier : « Orc Idle »

## ✅ v0.1.31 — Portraits de dialogue, alerte de vie basse
- [x] Guitare plus basse : main droite juste sous la ceinture (Riffald, Valkyriff, Belzeluth), manche plus relevé (35°)
- [x] Vie sous 20 % : aura rouge sur le pourtour de l'écran, qui clignote toutes les 0,75 s
- [x] Dialogues : portrait en direct du PNJ à gauche et du héros à droite (celui qui parle est éclairé)
- [x] Dialogues : clic gauche ou Espace affiche la réplique en entier au lieu du défilement

## ✅ v0.1.32 — Nouvelles portes à taille réelle
- [x] Donjon : porte de cachot, porte de crypte ou simple ouverture de pierre au hasard (1 m x 2,1 m), reste de l'ouverture muré
- [x] Salle du boss : double porte voûtée au crâne cornu, toujours scellée par les chaînes du chef
- [x] Taverne : double porte voûtée tout en bois, tête de chèvre au-dessus (art/portes/build_portes.py)

## ✅ v0.1.33 — Torches témoins, ambiance lugubre, guide de l'éditeur
- [x] Torches rouge orangé tant qu'une salle a des ennemis en vie, flamme normale une fois nettoyée
- [x] Ambiance plus sombre et plus froide dans le donjon, taverne plus tamisée
- [x] Guide de l'éditeur de donjon : PDF illustré (docs/guide_editeur) et vidéo commentée (locale)

## ✅ v0.1.34 — Onde de choc headbang, pénombre profonde
- [x] Onde de choc : les ennemis touchés headbanguent 1,25 s, figés (les boss sont sonnés)
- [x] Presque aussi sombre que la toute première version (ambiance et lumière principale très basses, torches maîtresses)

## ✅ v0.1.35 — Aussi sombre que la première version
- [x] Mêmes réglages d'ambiance que la v0.1 (sans ses filtres), plus de lumière principale : seules torches, lanternes et halo du héros éclairent

## ✅ v0.1.36 — Inventaire et échoppe de Grokk
- [x] Inventaire sur la touche B : reliques portées, descriptions, total des bonus
- [x] Grokk rachète les reliques (8 à 60 médiators selon la rareté) ; rachat possible des 10 dernières vendues

## ✅ v0.1.37 — Nouvelle histoire : la Chèvre Fringante et Gérald le fromager
- [x] Intro réécrite : Lune de Sang (cliché de métalleux), messe noire, les morts ENCORE échappés, thé glacé à la goyave
- [x] La taverne devient la Chèvre Fringante ; le héros s'y attable devant son thé et un plateau de fromages
- [x] Gérald, petit fromager aux pieds nus épilés, vient demander de l'aide ; refus possible, il revient à la charge jusqu'au fromage d'hibours (+20 % PV, 20 min)
- [x] Récompense : 50 médiators et le portrait de l'arrière-arrière-arrière-grand-mère ; Gloubah devient le Roi Grenouille ; portail de retour à côté du héros

## ✅ v0.1.38 — Version de test autonome
- [x] Riff électrique 70 % moins fort ; export Windows en un seul MetalBard.exe (pck intégré, modèles d'export officiels), sans Godot

## ✅ v0.1.39 — Équipement, butin sur les corps, mini-jeu du Riff
- [x] Équipement comme dans un MMO : 11 emplacements dans la fiche de personnage, sac, bonus seulement une fois équipé ; 3 nouveaux objets (Perfecto clouté, Bottes de roadie, Chevalière tête de bouc)
- [x] Butin sur les corps : on clique sur l'ennemi vaincu pour le fouiller ; le corps reste tant qu'il y a du butin et « respire » en doré s'il porte un équipement
- [x] Riff électrique en mini-jeu : une note à 160 BPM, jusqu'à 8 notes qui sautent d'ennemi en ennemi ; une fausse note triple la recharge
- [x] Sorts à 80 % de chances de toucher (mini-jeux : 100 %) ; coup de guitare : touche toujours, 1d6, 20 % plus rapide ; Accordage de cordes : 10 s de recharge
- [x] Torches rouges tant qu'on n'est pas passé à moins de 15 m, une torche de chaque côté des portes (sauf le boss)
- [x] Barres de vie qui se vident de la droite vers la gauche
- [x] Gérald revient à la charge au bout de 3 s, puis 2 s, puis 1 s
- [x] Hella, nouvelle héroïne jouable (modèle retravaillé par Ulysse) ; Ozz prend le modèle Mage V2

## ✅ v0.1.40 — Le portail à XP et la Légende de Back Jlack
- [x] Médiators ramassés automatiquement (ils filent vers le héros)
- [x] Portail à XP (portail démoniaque du sous-sol) : les Cryptes de la Cathédrale, ruisseaux de lave, démons au niveau du héros, Gardien et portail de retour ; régénérées à chaque passage
- [x] Nouveaux ennemis : diablotin ailé à hachette, démon cornu (et le Gardien des Cryptes), l'ange déchu (boss)
- [x] Chapitre 2 : l'Inconnue appelle le héros et raconte la légende de Back Jlack (cinématique d'orage, visage en contre-plongée)
- [x] L'autre univers : marches interminables, temple à tête de dragon, épreuve de 40 notes à 120 BPM (80 %), bénédiction +10 % de dégâts du premier coup, porte ouverte dans le tonnerre
- [x] Temple du Dragon : vitraux, nef à la fontaine de sang de l'ange déchu, embuscade de démons ailés puis éclair, ange déchu et partition maudite (qui foudroie sans le Pick du Destin)

## ✅ v0.1.41 — Vraies textures
- [x] Textures peintes (packs « Stylized » d'Ulysse, ramenées en 1K) sur les sols et les murs : pierre moussue et blocs de pierre (Catacombes), roche de lave et basalte (Cryptes), damier et pierre claire (Temple), parquet, briques et dalles (taverne), dalles et roche (parvis du temple), herbe, terre et pierres tombales (intro) — voir docs/TEXTURES.md
- [x] Lave : croûte de roche noire aux fissures incandescentes qui dérive sur le bouillonnement

## ✅ v0.1.42 — Le solo du sage
- [x] Épreuve de Back Jlack : le vrai solo du sage, « Chant de fer », joué en entier ; les 78 notes du mini-jeu tombent sur les notes du morceau (mélodie de la guitare solo suivie au demi-ton par tools/audio/detect_notes.py, data/epreuve_solo.json) ; la corde suit la hauteur

## ✅ v0.1.43 — Correctifs et portail incanté
- [x] Plumeau ne se coince plus dans les tonneaux : la navigation de la taverne reprend le plancher (Godot 4.7 ne lisait que le dessus des meubles) ; ses destinations sont ramenées sur la zone praticable
- [x] Rats morts : retournés sur le dos au-dessus des dalles (on peut les fouiller)
- [x] Tout corps qui porte encore du butin scintille (une simple potion comprise)
- [x] Portail bleu (T) : 3 s d'incantation (barre à l'écran), interrompue si le héros bouge, est touché ou entre en combat ; un seul portail par joueur (y compris dans les Cryptes)
- [x] Riff électrique à 90 BPM

## ✅ v0.1.44 — Options d'affichage
- [x] Options > Affichage : fenêtré ou plein écran, résolution (les courantes jusqu'à celle de l'écran), fluidité 60 / 90 / 120 / 140 images/s ; sauvegardées dans settings.cfg et appliquées au lancement (autoload Display)

## ✅ v0.1.45 — Gloubah et Plumeau en 3D
- [x] Gloubah, le Roi Grenouille : nouveau modèle 3D (crapaud debout couronné), 50 % plus grand que les héros (2,76 m), animé (repos, marche, coup de patte avec la langue, sursaut, mort) ; yeux luisants et langue accrochés à sa tête
- [x] Plumeau : nouveau modèle 3D de bébé hibours (1,2 m), qui marche et court en suivant le héros

## ✅ v0.1.46 — Nouveau HUD et menus de fer
- [x] Réservoir de vie : petite main cornue en pierre (bas à gauche), cœur de verre qui se remplit de liquide rouge animé ; réservoir de décibels : petite enceinte cloutée (bas à droite), cuve de liquide violet
- [x] Barre de sorts dans un cadre de fer à crânes, pointes et chaînes ; cases de fer
- [x] Panneaux et boutons des menus en fer noirci (rendus dans Blender, art/hud/build_hud.py) — voir docs/HUD.md

## ✅ v0.1.47 — Chapitre 3 : le Labyrinthe du Destin
- [x] Back Jlack renvoie le héros dans son époque avec la partition ; Ozz, le grand mage, connaît le « pic » du Destin : un labyrinthe en haut d'une montagne, gardé par le Minotaure (quête « labyrinthe_destin »)
- [x] Expédition en cinq niveaux générés (scenes/expedition.tscn) : prairie au pied de la montagne, flancs (boss : le Bigfoot), grottes des gobelins (boss : le troll des cavernes, qui se régénère), col sans murs au-dessus des précipices (boss : l'élémentaire de glace colossal), et un vrai labyrinthe de glace (DungeonGenerator.generate_maze)
- [x] Nouveaux ennemis : gobelins (gourdin, coutelas ou lance), élémentaires de roche et de glace
- [x] Le Minotaure : charge, fendoir, et à 5 % de PV un duel de guitare sur « Edge of the Cliff » (94 notes détectées, 80 % requis) ; le Pick du Destin sur son corps
- [x] Nouvelles textures : herbe, falaise, terre et roche des grottes, neige, glace

## ✅ v0.1.48 — Riffald's Twin
- [x] Cinquième héros prédéfini : Riffald's Twin (RiffaldV1.glb fourni par Ulysse), squelette de Riffald, 16 animations, Flying V (docs/TWIN.md)
- [x] Back Jlack : son modèle 3D (PNJ/Sage fourni par Ulysse), animé, sur le parvis du temple, dans les portraits de dialogue et dans la cinématique de la légende

## ✅ v0.1.49 — Guitare dans le dos, gobelins, Batguitare
- [x] Après 4 s de marche sans s'arrêter, le héros range sa guitare dans son dos ; il la reprend dès qu'il frappe ou joue un sort (visible aussi en coop)
- [x] Gobelins : le modèle 3D d'Ulysse (Ennemis/Gobelin), animé, avec son arme en main
- [x] Batguitare : la guitare de l'ange déchu, sur son corps ; nouvel emplacement d'équipement « Guitare » : équipée, elle passe dans les mains du héros
- [x] Riff black metal : avec la Batguitare, le Riff électrique devient un trait brumeux violet accompagné d'un vent brumeux
- [x] Back Jlack porte sa basse dans le dos (modèle d'Ulysse) ; Troll des cavernes : modèle 3D d'Ulysse, animé

## v0.2 — « Ça ressemble à un vrai jeu »
- [ ] Modèles 3D low-poly du héros (crinière, manteau, luth), des squelettes, de Gloubah, de Plumeau
- [ ] Animations squelettiques (AnimationTree) : marche, frappe, sorts, mort
- [ ] Musique metal adaptative (couches) + vrais bruitages
- [ ] Particules : étincelles, poussière d'os, éclaboussures
- [ ] Coffres, pièges, salles préfabriquées
- [ ] Options : plein écran, remappage des touches, accessibilité du solo
- [ ] Support manette

## v0.3 — Contenu
- [ ] 3 nouveaux ennemis (archer, banshee, golem de silence)
- [ ] Quêtes 2 et 3 (Beffroi Muet, Duel des Luths)
- [ ] Équipement complet (luth, médiator, ampli) avec affixes aléatoires
- [ ] Arbre de talents (Voies Thrash / Doom / Power)
- [ ] Forgeron-luthier

## v0.4 — Multijoueur
- [x] Hébergement / connexion ENet par code d'invitation, chacun avec son personnage (v0.1.5)
- [x] Synchronisation des héros et des ennemis ; coups des clients validés par l'hôte (v0.1.5)
- [x] Effets visuels et sons des sorts des autres joueurs (v0.1.13)
- [ ] Dialogues, coffres, portes et portail bleu partagés
- [ ] Relais en ligne (sans ouverture de port), lobby dans la taverne
- [ ] 2 nouvelles classes (Batteur-guerrier, Chanteur-clerc)

## v0.5 → v1.0
- [ ] Jusqu'à 6 joueurs, 6 classes, accords de groupe
- [ ] Donjon final et Morne, la Liche du Silence
- [ ] Intégration Steam, succès, sauvegarde cloud
- [ ] Équilibrage, localisation (anglais), démo publique
