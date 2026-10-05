# Objets du jeu

Tous les objets sont définis dans **[`data/items.json`](../data/items.json)**. Ce fichier se modifie avec n'importe quel éditeur de texte : le jeu le relit à chaque lancement.

## Liste actuelle

### Monnaie

| Objet | Détail | Réglages dans le fichier |
|---|---|---|
| **Médiator** | La monnaie du royaume. Ramassés automatiquement : ils jaillissent du corps des ennemis et filent vers le héros. | `chance_butin` (45 %), `perte_a_la_mort` (25 %), `depart` (30) |

### Consommables

| Objet | Effet | Prix | Réglages dans le fichier |
|---|---|---|---|
| **Potion de soin** | Rend 40 % des PV max (touche R). | 25 médiators (Brunhilde) | `prix`, `soin`, `chance_butin` (12 %), `depart` (2) |
| **Nuit à l'auberge** | Se paie à Brunhilde ; il faut ensuite se coucher sur le lit de la chambre 2 (PV et dB de 1 à 100 % en 10 s). | 10 médiators | `prix` |

### Objet de quête

| Objet | Rôle |
|---|---|
| **Clé rouillée de la cage** | Lâchée par Gloubah (ou offerte si elle devient amicale). Ouvre la cage de Plumeau. |
| **Partition maudite du Riff Ultime** | Sur le corps de l'ange déchu (Temple du Dragon). Visible dans l'inventaire (B), section « Objets de quête » ; bouton « Jouer » : sans le Pick du Destin, la foudre frappe (30 % des PV, jamais mortel). Servira contre Mèhn-Strïm. |

### Équipement (section « reliques » du fichier)

Comme dans un MMO : chaque objet a un **emplacement**, et ses bonus ne comptent **que s'il est équipé**. Un objet
ramassé va dans le **sac** ; on l'équipe depuis la fiche de personnage (**C** : colonne « Équipement », bouton
« Équiper » du sac, clic sur un objet porté pour le retirer) ou depuis l'inventaire (**B**). Équiper un objet sur un
emplacement occupé renvoie l'ancien dans le sac. Les sauvegardes d'avant la v0.1.39 équipent d'office les reliques
qu'on avait.

Emplacements : guitare, tête, cou, torse, poignets, ceinture, pieds, anneau, talisman, médiator, cordes, grimoire
(`guitare`, `tete`, `cou`, `torse`, `poignets`, `ceinture`, `pieds`, `anneau`, `talisman`, `mediator`, `cordes`, `grimoire`).

| Identifiant | Nom | Emplacement | Bonus | Rareté | Tombe sur les ennemis ? |
|---|---|---|---|---|---|
| `mediator_os` | Médiator en os | médiator | DEX +1 | commun | oui |
| `ceinture_cloutee` | Ceinture cloutée | ceinture | CON +1 | commun | oui |
| `bracelet_force` | Bracelet à pointes | poignets | FOR +1 | commun | oui |
| `perfecto_cloute` | Perfecto clouté | torse | CON +1 | commun | oui |
| `bottes_roadie` | Bottes de roadie | pieds | DEX +1 | commun | oui |
| `cordes_dragon` | Cordes en boyau de dragon | cordes | CHA +1 | peu commun | oui |
| `grimoire_tablatures` | Grimoire de tablatures | grimoire | INT +1, SAG +1 | peu commun | oui |
| `chevaliere_bouc` | Chevalière tête de bouc | anneau | CHA +1, INT +1 | peu commun | oui |
| `pendentif_plume` | Pendentif de plume de hibours | cou | CHA +1, SAG +1 | rare | non (plus distribué) |
| `portrait_aieule` | Portrait de l'arrière-arrière-arrière-grand-mère de Gérald | talisman | SAG +1, CHA +1 | rare | non (récompense de Gérald, avec 50 médiators) |
| `couronne_gloubah` | Couronne de nénuphar de Gloubah | tête | CON +2, CHA +1 | épique | non (butin de Gloubah) |
| `batguitare` | Batguitare de l'Ange déchu | guitare | CHA +2, INT +1 | épique | non (sur le corps de l'ange déchu, Temple du Dragon) |
| `xplode` | Xplode | guitare | FOR +1, CHA +1 | rare | non (sur le Gardien des Cryptes, une fois ; revendue 1 médiator) |

**Butin sur les corps** : ce que lâche un ennemi (médiators, potion, équipement) reste sur son corps ; on le ramasse
en **cliquant sur le corps** (ou [E] à côté). Le corps ne disparaît pas tant qu'il reste du butin, et s'il porte un
équipement il « respire » en jaune doré (fondu d'une seconde). L'équipement tombe sur 8 % des ennemis
(`DROP_ITEM_CHANCE` dans `scripts/rpg/balance.gd`, jamais un objet déjà possédé) et dans les coffres des salles
cul-de-sac (au sol, attiré par le héros).

### Inventaire et revente (touche B)

- **B** ouvre l'inventaire : le sac (bouton « Équiper »), l'équipement porté (bouton « Retirer ») et le total de
  ses bonus. Le jeu ne se met pas en pause, mais le héros ne bouge plus tant que la fenêtre est ouverte.
- Chez **Grokk**, le choix « Vendre ou racheter de l'équipement » ouvre la même fenêtre en boutique : chaque objet
  **du sac** se vend selon sa rareté (`monnaie.vente` dans `data/items.json` : commun 8, peu commun 15, rare 30,
  épique 60 médiators). Un objet porté ne se vend pas : il faut d'abord le retirer.
- Les **10 derniers objets vendus** peuvent être rachetés, au prix où Grokk les a payés (ils reviennent dans le sac ;
  historique sauvegardé avec la partie).

## Modifier un objet

Chaque objet d'équipement ressemble à ceci :

```json
"bracelet_force": {
	"nom": "Bracelet à pointes",
	"desc": "Pour frapper plus fort et accessoirement faire peur.",
	"bonus": {"FOR": 1},
	"rarete": "commun",
	"butin": true,
	"emplacement": "poignets",
	"actif": true
}
```

- **`nom`, `desc`** : texte affiché dans le jeu.
- **`bonus`** : caractéristiques augmentées, parmi `FOR`, `DEX`, `CON`, `INT`, `SAG`, `CHA` ; plusieurs possibles, valeurs négatives acceptées.
- **`rarete`** : `commun`, `peu commun`, `rare` ou `épique` (change la couleur).
- **`butin`** : `true` si l'objet peut tomber sur les ennemis et dans les coffres.
- **`emplacement`** : où il se porte (voir la liste plus haut) ; sans emplacement (ou inconnu), il va en talisman.
- **`actif`** : `false` pour désactiver la relique. Elle ne tombe plus, et ses bonus ne s'appliquent plus même si le personnage la possède déjà.
- **`modele`** (guitares seulement) : modèle 3D (.glb) que le héros tient quand la guitare est équipée (même repère que `assets/models/guitare/guitare_heros.glb`, voir docs/GUITARE.md).

## Ajouter un équipement

Copier un bloc, lui donner un nouvel identifiant (sans espace ni accent, par ex. `"collier_crocs"`), puis régler ses valeurs. Avec `"butin": true`, elle tombe aussitôt sur les ennemis.

Attention à la syntaxe JSON : une virgule entre deux blocs, pas de virgule après le dernier. Si le fichier devient illisible, le jeu repart sur les objets par défaut et affiche un avertissement dans la console de Godot.

## Guitares (emplacement « Guitare »)

- **Batguitare de l'Ange déchu** (`batguitare`) : la guitare de l'ange déchu, qui en joue pendant le combat ; elle
  reste sur son corps (Temple du Dragon). Modèle fourni par Ulysse (`Imagerie/Guitares/3D/batguitare.glb`), préparé
  par `art/guitare/prepare_guitares.py` (300 000 → 24 000 faces) dans le même repère que la guitare des héros
  (origine à la jonction manche / corps, sillet à 0,385 m) → `assets/models/guitare/batguitare.glb`.
- Équipée, elle remplace la Flying V dans les mains du héros (`GameState.guitar_model()`, `HeroModel.set_guitar_model`) ;
  retirée, il reprend la Flying V.
- **Riff black metal** : avec la Batguitare équipée, le Riff électrique (touche 1) devient le Riff black metal (clé
  `sort_riff` : `black_metal`) : même mini-jeu et mêmes dégâts (violets), mais un **trait brumeux violet** (`MistTrail`)
  au lieu de l'éclair, et un **vent brumeux** synthétisé (`Sfx` « mist_wind ») au lieu du son du riff. Vu et entendu
  par tous les joueurs.
- **Xplode** (`xplode`, rare, FOR +1, CHA +1) : une Explorer de bois calciné (`Imagerie/Guitares/3D/explorer.glb`,
  `art/guitare/prepare_guitares.py -- xplode`) sur le corps du **Gardien des Cryptes** (le boss du portail à XP). Elle
  ne tombe que si le héros ne l'a pas déjà (sac ou main) : on ne la loote qu'une fois, mais une fois vendue à Grokk —
  pour **1 médiator** (clé `prix_vente`) — elle retombe au passage suivant.
- **FIREBALL** : avec la Xplode équipée, le Riff électrique (touche 1) devient FIREBALL (`sort_riff` : `fireball`) :
  même mini-jeu et mêmes dégâts (orange), mais chaque note lance une **boule de feu** (`Fireball`) de la guitare vers
  l'ennemi, faite avec les textures de feu d'Ulysse (`assets/textures/feu` : flammes, halo, et la
  texture de Voronoi qui fait bouillonner le cœur, `shaders/fireball_core.gdshader`), avec un son de **boule de feu crépitante** synthétisé (`Sfx` « fireball »). Apparence du sort selon la
  guitare : `ItemDB.RIFF_STYLES`.
