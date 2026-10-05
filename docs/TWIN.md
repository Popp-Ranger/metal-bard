# Riffald's Twin, héros prédéfini

Cinquième héros prédéfini du jeu, à choisir dans la création de personnage (sélecteur « Héros »). Nom et titre
dans `scripts/rpg/race_db.gd` (`PRESETS["twin"]`) ; humain, 1,84 m.

Modèle fourni par Ulysse : `Imagerie/Personnages/3D/Humain/Masculin/RiffaldV1.glb` (hors dépôt, 5 oct. 2026) :
crinière rousse, cuir noir et sangles croisées, épaulières à pointes, gemme rouge au col, genouillères d'acier,
bottes à boucles, cape bordeaux en lambeaux.

## Préparation (Blender, `art/pnj/build_pnj.py`, personnage `twin`)

```
blender --background --factory-startup --python art/pnj/build_pnj.py -- prepare twin
blender --background art/twin/twin.blend --python art/pnj/build_pnj.py -- views twin <dossier>
blender --background art/twin/twin.blend --python art/pnj/build_pnj.py -- rig twin
blender --background art/twin/twin.blend --python art/riffald/retarget_mixamo.py -- export
```

1. **prepare** : maillage ressoudé, allégé à 40 000 triangles (297 000 au départ), mis à **1,84 m** ; textures 2K / 1K →
   `art/twin/twin.blend`.
2. **rig** : les 17 os de Riffald, placés sur les vues à grille. Poids par distance aux os : crinière sur la tête, le
   cou et le buste ; cape (même maillage que le corps) sur le bassin et le dos seulement, les faces qui la soudaient
   aux jambes sont retirées (comme pour le démon et Hella).
3. **export** : les 16 animations Mixamo de Riffald → `assets/models/twin/twin.glb`.

**Retouches à la main.** On peut repeindre les poids dans `twin.blend` puis ne relancer que l'**export**. Après une
retouche, ajouter `"retouche": True` à `twin` dans `CHARS` (`build_pnj.py`) pour que `rig` ne puisse plus l'effacer.
