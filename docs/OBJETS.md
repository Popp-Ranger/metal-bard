# Objets du jeu

Tous les objets sont définis dans **[`data/items.json`](../data/items.json)**. Ce fichier se modifie avec n'importe quel éditeur de texte : le jeu le relit à chaque lancement.

## Liste actuelle

### Monnaie

| Objet | Détail | Réglages dans le fichier |
|---|---|---|
| **Médiator** | La monnaie du royaume. | `chance_butin` (45 %), `perte_a_la_mort` (25 %), `depart` (30) |

### Consommables

| Objet | Effet | Prix | Réglages dans le fichier |
|---|---|---|---|
| **Potion de soin** | Rend 40 % des PV max (touche R). | 25 médiators (Brunhilde) | `prix`, `soin`, `chance_butin` (12 %), `depart` (2) |
| **Nuit à l'auberge** | Se paie à Brunhilde ; il faut ensuite se coucher sur le lit de la chambre 2 (PV et dB de 1 à 100 % en 10 s). | 10 médiators | `prix` |

### Objet de quête

| Objet | Rôle |
|---|---|
| **Clé rouillée de la cage** | Lâchée par Gloubah (ou offerte si elle devient amicale). Ouvre la cage de Plumeau. |

### Reliques (bonus permanents aux caractéristiques)

| Identifiant | Nom | Bonus | Rareté | Tombe sur les ennemis ? |
|---|---|---|---|---|
| `mediator_os` | Médiator en os | DEX +1 | commun | oui |
| `ceinture_cloutee` | Ceinture cloutée | CON +1 | commun | oui |
| `bracelet_force` | Bracelet à pointes | FOR +1 | commun | oui |
| `cordes_dragon` | Cordes en boyau de dragon | CHA +1 | peu commun | oui |
| `grimoire_tablatures` | Grimoire de tablatures | INT +1, SAG +1 | peu commun | oui |
| `pendentif_plume` | Pendentif de plume de hibours | CHA +1, SAG +1 | rare | non (plus distribué) |
| `portrait_aieule` | Portrait de l'arrière-arrière-arrière-grand-mère de Gérald | SAG +1, CHA +1 | rare | non (récompense de Gérald, avec 50 médiators) |
| `couronne_gloubah` | Couronne de nénuphar de Gloubah | CON +2, CHA +1 | épique | non (butin de Gloubah) |

Les reliques communes tombent sur les ennemis (8 % de chance, `DROP_ITEM_CHANCE` dans `scripts/rpg/balance.gd`) et dans les coffres des salles cul-de-sac.

### Inventaire et revente (touche B)

- **B** ouvre l'inventaire : reliques portées (avec leur description) et total de leurs bonus. Le jeu ne se met
  pas en pause, mais le héros ne bouge plus tant que la fenêtre est ouverte.
- Chez **Grokk**, le choix « Vendre ou racheter des reliques » ouvre la même fenêtre en boutique : chaque relique
  se vend selon sa rareté (`monnaie.vente` dans `data/items.json` : commun 8, peu commun 15, rare 30, épique 60
  médiators). Une relique vendue perd ses bonus.
- Les **10 dernières reliques vendues** peuvent être rachetées, au prix où Grokk les a payées (historique
  sauvegardé avec la partie).

## Modifier un objet

Chaque relique ressemble à ceci :

```json
"bracelet_force": {
	"nom": "Bracelet à pointes",
	"desc": "Pour frapper plus fort et accessoirement faire peur.",
	"bonus": {"FOR": 1},
	"rarete": "commun",
	"butin": true,
	"actif": true
}
```

- **`nom`, `desc`** : texte affiché dans le jeu.
- **`bonus`** : caractéristiques augmentées, parmi `FOR`, `DEX`, `CON`, `INT`, `SAG`, `CHA` ; plusieurs possibles, valeurs négatives acceptées.
- **`rarete`** : `commun`, `peu commun`, `rare` ou `épique` (change la couleur).
- **`butin`** : `true` si la relique peut tomber sur les ennemis et dans les coffres.
- **`actif`** : `false` pour désactiver la relique. Elle ne tombe plus, et ses bonus ne s'appliquent plus même si le personnage la possède déjà.

## Ajouter une relique

Copier un bloc, lui donner un nouvel identifiant (sans espace ni accent, par ex. `"collier_crocs"`), puis régler ses valeurs. Avec `"butin": true`, elle tombe aussitôt sur les ennemis.

Attention à la syntaxe JSON : une virgule entre deux blocs, pas de virgule après le dernier. Si le fichier devient illisible, le jeu repart sur les objets par défaut et affiche un avertissement dans la console de Godot.
