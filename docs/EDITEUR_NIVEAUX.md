# Éditeur de niveaux

Les niveaux faits main se construisent directement dans l'éditeur de Godot : on peint le sol case par
case, puis on glisse-dépose les objets. En jeu, le code lit la scène et y branche toute la logique
(portes, salles dans le noir, ennemis endormis, boss, sauvegarde...).

Ouvrir le projet dans Godot (`project.godot`), puis la scène voulue depuis le panneau **Système de
fichiers** (en bas à gauche).

## Premier donjon : `scenes/levels/catacombes.tscn`

Le donjon de la quête « Le Petit Plumeau » (Catacombes Suintantes, Gloubah). Les donjons suivants
restent générés aléatoirement tant qu'on ne leur donne pas de scène (clé `"map"` de la quête dans
`scripts/rpg/quest_db.gd`).

La scène contient :

| Nœud | Rôle |
|---|---|
| **Sol** (GridMap) | le sol, peint case par case (cases de 2 m) |
| **Salle**, **Depart**, **Salle_du_boss**... | les salles (boîtes colorées) |
| **Ennemis**, **Decor**, **Torches** | des dossiers pour ranger les objets (facultatifs) |

### Peindre le sol

1. Sélectionner le nœud **Sol**. La palette des tuiles s'ouvre à droite de la vue 3D.
2. Choisir la tuile **Sol (dalles)**, puis cliquer-glisser dans la vue pour peindre.
   Clic droit (ou **Maj + clic**) : effacer.
3. Les **murs se posent tout seuls** autour du sol (aperçu gris dans l'éditeur). Inutile de les dessiner.
   Pour masquer cet aperçu : sélectionner la racine **Catacombes** et décocher *Show Walls*.

Astuce : une vue de dessus aide beaucoup (pavé numérique **7**, ou le menu de la vue *Perspective → Dessus*).

### Les salles

Une salle est une boîte : bleue (normale), **verte (départ)**, **rouge (boss)**.

- **Ajouter** : glisser `scenes/levels/pieces/donjon/salle.tscn` sur la racine **Catacombes** (dans
  l'arbre de la scène, à gauche). Une salle doit être un enfant direct de la racine.
- **Placer** : la déplacer avec les flèches de la vue. Son coin (le plus petit x et z) s'aimante sur la grille.
- **Taille et type** : dans l'**Inspecteur** (à droite), *Size* (largeur × profondeur en cases) et *Kind*
  (Normale, Départ, Boss).
- Bouton **Peindre le sol de la salle** (Inspecteur) : remplit de sol toute la boîte.

Ce que fait le jeu avec les salles :
- une **porte** à chaque arrivée de couloir (si le passage fait au plus 5 cases de large ; au-delà, côté ouvert) ;
- la salle reste **dans le noir**, ses occupants **endormis**, tant qu'on n'y entre pas ;
- **départ** : le héros y apparaît, avec le portail de retraite ;
- **boss** : Gloubah, son pentagramme, les cages (Plumeau) ; portes **scellées** jusqu'à ce qu'on ait la
  clé du chef des squelettes. Au moins 11 × 11 cases.

Les couloirs sont simplement du sol peint hors des salles.

### Les objets

Glisser-déposer depuis `scenes/levels/pieces/donjon/` dans la vue 3D (ou sur un dossier de l'arbre) :

| Pièce | En jeu |
|---|---|
| `squelette`, `capitaine` | squelettes (endormis tant que leur salle est fermée ; éveillés dans un couloir) |
| `chef_des_squelettes` | **un seul** : il porte la clé de la salle du boss |
| `rat` | rat |
| `coffre` | coffre (or, potion, parfois un objet) |
| `torche` | torche murale : à coller contre un mur, **la flèche vers la pièce** |
| `os`, `bave`, `pilier`, `tonneau` | décor (piliers et tonneaux bloquent le passage) |

On peut aussi changer le type d'un objet déjà posé (Inspecteur, *Kind*), le tourner (orientation de
l'ennemi ou du coffre) et le dupliquer (**Ctrl + D**).
En coop, des renforts s'ajoutent automatiquement dans chaque salle.

### Vérifier et tester

- Sélectionner la racine **Catacombes** → bouton **Vérifier le donjon** (Inspecteur) : la liste des
  problèmes s'affiche dans la **Sortie** (en bas). Par exemple : pas de salle de départ, chef manquant,
  salle du boss trop petite ou accessible par un trop large passage, objet posé hors du sol...
- **F6** (*Lancer la scène actuelle*) : nouvelle partie directement dans ce donjon, quête en cours.
- **Ctrl + S** pour enregistrer.

Une partie sauvegardée en plein donjon garde ses ennemis tués et ses portes ouvertes : après avoir
modifié le donjon, terminez-le (ou fuyez) avant de reprendre une ancienne sauvegarde.

### Repartir d'un donjon généré

`tools/levels/build_dungeon_assets.gd` recrée les tuiles et les pièces ; avec `-- catacombes`, il
**écrase** `catacombes.tscn` par un donjon tiré du générateur (graine 4242) :

```
Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tools/levels/build_dungeon_assets.gd -- catacombes
```
