# Hella, héroïne prédéfinie

Quatrième héros prédéfini du jeu, à choisir dans la création de personnage (sélecteur « Héros »). Nom et titre
dans `scripts/rpg/race_db.gd` (`PRESETS["hella"]`) ; humaine, 1,75 m.

Modèle retravaillé par Ulysse dans Blender : `Imagerie/Personnages/3D/Humain/Féminin/Hella.glb` (hors dépôt,
4 oct. 2026) : crinière rousse et tresses (deux devant, une grosse dans le dos), haut déchiré, épaulières et
brassards à pointes, genouillères d'acier, cape bordeaux. Son essai de squelette Mixamo
(`art/portes/SOLOTESTHELLA.blend`) n'était pas relié au maillage : il n'est pas utilisé.

## Préparation (Blender, `art/pnj/build_pnj.py`, personnage `hella`)

```
blender --background --factory-startup --python art/pnj/build_pnj.py -- prepare hella
blender --background art/hella/hella.blend --python art/pnj/build_pnj.py -- views hella <dossier>
blender --background art/hella/hella.blend --python art/pnj/build_pnj.py -- rig hella
blender --background art/hella/hella.blend --python art/riffald/retarget_mixamo.py -- export
```

1. **prepare** : maillage ressoudé, allégé à 40 000 triangles, mis à **1,75 m** ; textures 2K / 1K →
   `art/hella/hella.blend`.
2. **rig** : les 17 os de Riffald, placés sur les vues à grille. Poids par distance aux os : crinière et tresse du
   dos sur la tête, le cou et le buste ; cape (même maillage que le corps) sur le bassin et le dos seulement, les
   faces qui la soudaient aux jambes sont retirées (comme pour le démon).
3. **export** : les 16 animations Mixamo de Riffald → `assets/models/hella/hella.glb`.

**Retouches à la main.** On peut repeindre les poids dans `hella.blend` puis ne relancer que l'**export** (les
vertices laissés sans poids y sont complétés d'après leurs voisins). Après une retouche, ajouter `"retouche": True`
à `hella` dans `CHARS` (`build_pnj.py`) pour que `rig` ne puisse plus l'effacer par erreur.

## Dans le jeu

- `RaceDB.PRESETS["hella"]` : apparence (humaine, rousse), modèle, taille (1,75 m), réglages de la guitare (`rig`,
  comme Valkyriff : main droite juste sous la ceinture).
