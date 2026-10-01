# Valkyriff, héroïne prédéfinie (modèle persoF1)

Deuxième héros prédéfini, proposé à la création de personnage après Riffald
(sélecteur « Héros »). Nom et titre dans `scripts/rpg/race_db.gd` (`PRESETS["persof1"]`,
clés `name` et `title`) ; l'identifiant interne reste `persof1`.

## Source

Modèle fourni par Ulysse : `Imagerie/3D/Féminin/persoF1.glb` (hors dépôt, 64 Mo) — généré par IA,
2 millions de triangles, textures 8K (couleur + métal/rugosité), sans squelette, pose debout bras le
long du corps, poings fermés.

## Préparation (Blender, `art/persof1/build_persof1.py`)

```
blender --background --factory-startup --python art/persof1/build_persof1.py -- prepare
blender --background art/persof1/persof1.blend --python art/persof1/build_persof1.py -- rig
blender --background art/persof1/persof1.blend --python art/riffald/retarget_mixamo.py -- export
```

1. **prepare** : les 70 tranches du générateur sont ressoudées, le maillage est allégé à 40 000
   triangles, mis à **1,74 m** (Riffald : 1,84 m), pieds au sol, centré sur le bassin ; textures
   ramenées à 2K / 1K. Résultat : `art/persof1/persof1.blend`.
2. **rig** : squelette identique à celui de Riffald (mêmes 17 os : bassin, colonne, buste, cou, tête,
   bras, avant-bras, mains, cuisses, tibias, pieds), articulations relevées sur les vues de face et de
   profil. Pondération par distance aux os, avec deux cas particuliers :
   - **cape** (repérée à sa couleur bordeaux) : ne suit que le bassin et le buste ; le générateur l'avait
     soudée aux jambes et aux bras par endroits, ces ponts sont découpés ;
   - **tresse dans le dos** : suit la tête, le cou et le buste, pas les bras.
3. **export** : les 16 animations Mixamo de Riffald sont transférées sur son squelette (même script que
   Riffald, le personnage est choisi d'après le `.blend` ouvert) → `assets/models/persof1/persof1.glb`.

## Dans le jeu

- `RaceDB.PRESETS["persof1"]` : apparence (humaine, rousse), modèle, taille, réglages de guitare (`rig`).
- Même Flying V que Riffald, un peu moins agrandie (×1,1 contre ×1,3, ses mains sont plus petites),
  mêmes animations, même IK des mains sur la guitare (HeroAnimator).

## Limites connues

- Les fragments de cape collés sous les bras s'étirent un peu quand elle lève les bras (sorts).
- Pas d'os pour les tresses ni la cape : elles suivent le buste (SpringBones possibles plus tard).
- Poings fermés : pas de doigts animés (comme Riffald).
