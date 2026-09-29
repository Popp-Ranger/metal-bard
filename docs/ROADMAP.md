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

## v0.2 — « Ça ressemble à un vrai jeu »
- [ ] Modèles 3D low-poly du héros (crinière, manteau, luth), des squelettes, de Gloubah, de Plumeau
- [ ] Animations squelettiques (AnimationTree) : marche, frappe, sorts, mort
- [ ] Musique metal adaptative (couches) + vrais bruitages
- [ ] Particules : étincelles, poussière d'os, éclaboussures
- [ ] Coffres, pièges, salles préfabriquées
- [ ] Options : volume, plein écran, remappage des touches, accessibilité du solo
- [ ] Support manette

## v0.3 — Contenu
- [ ] 3 nouveaux ennemis (archer, banshee, golem de silence)
- [ ] Quêtes 2 et 3 (Beffroi Muet, Duel des Luths)
- [ ] Équipement complet (luth, médiator, ampli) avec affixes aléatoires
- [ ] Arbre de talents (Voies Thrash / Doom / Power)
- [ ] Forgeron-luthier

## v0.4 — Multijoueur
- [ ] Refonte `GameState` → état par joueur
- [ ] Hébergement / connexion ENet, lobby dans la taverne
- [ ] Synchronisation héros / ennemis / butin, compétences en RPC validées par le serveur
- [ ] 2 nouvelles classes (Batteur-guerrier, Chanteur-clerc)

## v0.5 → v1.0
- [ ] Jusqu'à 6 joueurs, 6 classes, accords de groupe
- [ ] Donjon final et Morne, la Liche du Silence
- [ ] Intégration Steam, succès, sauvegarde cloud
- [ ] Équilibrage, localisation (anglais), démo publique
