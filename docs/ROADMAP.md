# Feuille de route

## ✅ v0.1 — Prototype jouable (actuel)
- [x] Taverne-hub complète : tables, chaises, comptoir, bouteilles, fenêtres au clair de lune, lanternes, cheminée, escalier
- [x] 6 PNJ avec dialogues à choix (Gérald, Brunhilde, Zarathos, l'Inconnue, Borin, Sylvaine) + tableau des quêtes
- [x] Boutique (potions) et repos
- [x] Portail de Zarathos → donjon séparé du hub
- [x] Donjon procédural (graine sauvegardée, salle de départ la plus éloignée du boss)
- [x] Héros : coup de luth + Riff électrique (5 cibles) + Onde de choc (zone) + Solo de la Foudre (mini-jeu Guitar Hero → pluie d'éclairs)
- [x] IA squelettes : errance, détection 4 m, vitesse 0,25 × héros, 1 attaque / 2,5 s avec élan
- [x] Capitaine squelette, boss Gloubah (vagues, bond, phase 2, invocations), sauvetage de Plumeau
- [x] Règles D&D 5e : 6 caractéristiques, modificateurs, jets d'attaque, CA, sauvegardes, table d'XP, points à répartir
- [x] Butin : or, potions, 7 reliques
- [x] HUD, fiche de personnage, pause, mort et réveil à la taverne, sauvegarde / chargement
- [x] Ambiance sombre : éclairage dynamique, post-traitement encré, murs qui s'effacent devant le héros
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
- [x] Clients qui déplacent leur chaise, 2 debout au maximum, jurons ; Zarathos fait les cent pas
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
