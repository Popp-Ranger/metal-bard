# Éditeur de niveaux

Les niveaux faits main se construisent directement dans l'éditeur de Godot : on peint le sol case par
case, puis on glisse-dépose les objets. En jeu, le code lit la scène et y branche toute la logique
(portes, salles dans le noir, ennemis endormis, boss, sauvegarde...).

Débutant ? Commencez par le guide illustré `docs/guide_editeur/Guide_editeur_donjon.pdf` (et sa vidéo).

Ouvrir le projet dans Godot (`project.godot`), puis la scène voulue depuis le panneau **Système de
fichiers** (en bas à gauche).

| Niveau | Scène |
|---|---|
| La taverne (la Chèvre Fringante) | `scenes/levels/taverne.tscn` |
| Le premier donjon (Catacombes Suintantes) | `scenes/levels/catacombes.tscn` |

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

## La taverne : `scenes/levels/taverne.tscn`

La Chèvre Fringante sur trois zones de la même scène, éloignées les unes des autres et reliées par les
escaliers : le **rez-de-chaussée** (autour de l'origine), l'**étage** (70 m au nord) et le **sous-sol**
(70 m à l'est). Dans l'arbre de la scène, les objets sont rangés dans les dossiers **Rez-de-chaussee**,
**Etage** et **Sous-sol** (facultatifs).

### Sols et murs (cases de 1 m)

- **Sol** (GridMap) : tuiles **Plancher** et **Dalles**.
- **Murs** (GridMap) : **Mur** (4 m), **Fenêtre**, **Muret** (bas, infranchissable), **Cloison**
  (s'efface quand le héros passe derrière). Un mur se pose sur le **bord** de sa case : avant de
  peindre, tourner la tuile avec **S** (un quart de tour) pour choisir le bord.
  Astuce : les murs d'enceinte sont posés dans les cases juste à l'extérieur du plancher, ce qui évite
  que deux murs se disputent la même case dans les angles.
- Chaque **fenêtre** fait entrer le clair de lune du côté où il y a du plancher. Deux fenêtres côte à
  côte forment une seule baie (une seule lumière).

### Les objets

Glisser-déposer depuis `scenes/levels/pieces/taverne/`. Les réglages propres à chaque objet sont dans
l'Inspecteur (seuls ceux qui servent s'affichent). Tourner un objet : son devant est la flèche (+Z).

| Pièce | Réglages | En jeu |
|---|---|---|
| `table` | *Option* : place laissée au fauteuil de Katrkar | table ronde et ses 4 chaises : les clients s'y assoient |
| `comptoir` | *Size* x : longueur | les clients viennent commander devant (disques bleus = places) |
| `chaise`, `etagere_bouteilles`, `cheminee`, `tonneau`, `caisse`, `pilier_lanterne`, `lanterne`, `banniere`, `tapis`, `malle`, `table_de_chevet`, `grimoires`, `orbe`, `dormeur`, `fantome`, `ratelier`, `torche` | taille (*Size*), couleur (*Color*, *Variant*) selon l'objet ; échelle du nœud pour un plus gros tonneau | décor (la plupart bloquent le passage) |
| `lit` | *Variant* : couverture (0 à 3) ; *Option* : **lit loué par le héros** (un seul) | le héros s'y repose une fois la chambre louée |
| `ecriteau` | *Text*, *Color* | texte flottant |
| `tableau_des_quetes` | | on y lit les quêtes |
| `arrivee_du_heros` | | où apparaît le héros (un seul) |
| `cercle_de_runes` | | portail d'Ozz vers le donjon ; on y revient du donjon (un seul) |
| `portail_bleu` | | portail bleu de retour au donjon (un seul) |
| `portes_entree` | | portes verrouillées (laisser une ouverture de 4 cases dans le muret) |
| `escalier_qui_monte`, `escalier_qui_descend` | *Text* : invite ; *Destination* : une `arrivee_escalier` ; *Variant* : nombre de marches | on change de zone avec un fondu |
| `arrivee_escalier` | *Text* : nom du lieu affiché à l'arrivée | |
| `zone_entrainement` | *Size* | dedans, sorts et décibels illimités |
| `mannequin`, `mannequin_allie`, `portail_demoniaque` | | salle d'entraînement |
| `pnj` | *Npc* : Brunhilde, Ozz, l'Inconnue, Gérald (chacun une fois) | |

Pour relier un escalier : sélectionner l'escalier, puis dans l'Inspecteur cliquer sur *Destination*
→ **Assigner** et choisir l'arrivée dans la liste.

### Vérifier et tester

- Racine **Taverne** → bouton **Vérifier la taverne** : problèmes dans la **Sortie** (un seul lit loué,
  escalier qui ne mène nulle part, PNJ manquant...).
- **F6** : nouvelle partie directement dans la taverne (intro passée).

### Repartir de la taverne d'origine

`tools/levels/build_tavern_assets.gd` recrée les tuiles et les pièces ; avec `-- taverne`, il **écrase**
`taverne.tscn` par la Chèvre Fringante d'origine :

```
Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tools/levels/build_tavern_assets.gd -- taverne
```
