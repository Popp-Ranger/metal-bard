# Modèles 3D des PNJ et ennemis

Modèles fournis par Ulysse (générés par IA, sans squelette) :
`Imagerie/Personnages/3D/PNJ/<dossier>/*.glb` (hors dépôt ; le mage : `Mage/V2`), références 2D dans `Personnages/2D/PNJ`.

| Modèle | Personnage du jeu | Taille | Clips |
|---|---|---|---|
| Mage V2 (rockeur en perfecto, lunettes violettes ; remplace le sorcier au chapeau pointu le 4 oct. 2026) | Ozz | 1,85 m | repos, marche, course |
| Tavernier (orc au tablier) | **Grokk Chope-de-Fer**, le tavernier (remplace Brunhilde) | 2,05 m (×1,25 en jeu : 2,56 m) | repos, marche, course |
| Squelette paysan | tous les squelettes ennemis (soldats, capitaines, chef) | 1,75 m | repos et course de zombie, coup d'épée, sursaut, mort |
| Gloubah (crapaud debout couronné, Ennemis/Gloubah) | **Gloubah**, le Roi Grenouille (boss des Catacombes) | 1,84 m (×1,5 en jeu : 2,76 m) | repos d'orc, marche, course, coup de patte (+ langue), sursaut, mort, victoire |
| Ours Hiboux (bébé hibours au harnais) | **Plumeau**, le bébé hibours de Gérald | 1,2 m | repos, marche, course, victoire |
| Sage (rockeur trapu, barbe grise, gilet clouté, t-shirt tie-dye) | **Back Jlack**, le sage du rock (parvis du Temple du Dragon, cinématique de la légende) (basse dans le dos : Imagerie/Guitares/3D/back jlack.glb, `art/guitare/prepare_guitares.py`) | 1,65 m | repos, marche, course |
| Gobelin (casque de cuir, épaulière au crâne, Ennemis/Gobelin) | tous les **gobelins** (chapitre 3) ; arme (gourdin, coutelas ou lance) accrochée à la main droite | 1,15 m | repos d'orc, marche, course, coup, sursaut, mort |
| Troll (peau bleu-vert, pantalon rapiécé, Ennemis/Troll) | **le Troll des cavernes** (boss des grottes, chapitre 3) ; massue en tronc d'arbre dans la main droite | 2,2 m (×1,45 en jeu : 3,2 m) | repos d'orc, marche, course, coup, sursaut, mort, victoire |

## Préparation (Blender, `art/pnj/build_pnj.py`)

```
blender --background --factory-startup --python art/pnj/build_pnj.py -- prepare <perso>
blender --background art/pnj/<perso>.blend --python art/pnj/build_pnj.py -- views <perso> <dossier>
blender --background art/pnj/<perso>.blend --python art/pnj/build_pnj.py -- rig <perso>
blender --background art/pnj/<perso>.blend --python art/riffald/retarget_mixamo.py -- export
```

`<perso>` = `mage`, `tavernier`, `squelette`, `gloubah`, `hibours`, `sage`, `gobelin` ou `troll`.
1. **prepare** : tranches ressoudées, 30 000 triangles, mis à la taille du jeu, textures 2K.
2. **views** : vues de face et de profil quadrillées, pour relever les articulations (dictionnaire `CHARS`).
3. **rig** : squelette de Riffald (17 os), pondération par distance aux os ; chapeau et barbe suivent la
   tête ; la robe du mage ne suit les jambes que sous le genou.
4. **export** : clips Mixamo du personnage → `assets/models/pnj/<perso>.glb`. Avant l'export, les vertices restés
   sans aucun poids (oubliés à la peinture) reprennent ceux de leurs voisins, et les poids sont normalisés
   (`fill_unweighted`) : sinon ils resteraient figés et étireraient de grands pans pendant l'animation.
   Seul le glb en profite, le .blend n'est pas modifié.

**Retouches à la main.** Après `rig`, on peut corriger les os et la peinture des poids directement dans le
`.blend`, puis relancer seulement l'**export**. Le squelette et le tavernier ont été retouchés ainsi : `rig squelette` (ou `rig tavernier`) refuse
désormais de tout recalculer (sauf avec `force`, qui effacerait les retouches).

## Dans le jeu

`CharacterSkin` charge le modèle, lui donne des matières mates (qui clignotent quand il est touché)
et joue ses clips (déplacement selon la vitesse, action par-dessus, sursaut, mort). On y accroche des
objets aux os : épée dans la main droite et bouclier sur l'avant-bras des squelettes, casque du capitaine,
peau de loup et clé du chef.

- PNJ : `Npc.SKINS` (identifiant du PNJ → modèle). Le tavernier garde l'identifiant interne `brunhilde`
  (dialogues, sauvegardes) ; son nom est dans `DialogueDB.NPCS`.
- Squelettes : `Skeleton` (coup d'épée = clip « Great Sword Slash » étiré sur l'élan de l'attaque).

Limites : pas de doigts animés ; les PNJ importés ne tournent pas la tête vers le héros ; Ozz n'a
plus son bâton (le modèle a les mains libres).
