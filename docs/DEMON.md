# Belzeluth, démon prédéfini (modèle « Démon »)

Troisième héros prédéfini du jeu, à choisir dans la création de personnage (sélecteur « Héros »). Nom et titre
dans `scripts/rpg/race_db.gd` (`PRESETS["demon"]`) ; race Démon (+10 % de dégâts des sorts).

Modèle fourni par Ulysse : `Imagerie/Personnages/3D/Démon/*.glb` (hors dépôt), généré par IA d'après la planche
`Imagerie/Personnages/2D/Démon/Démon.jpg` : peau écarlate, cornes de bélier, crinière noire, épaulières et
brassards à pointes, cape bordeaux.

## Préparation (Blender, `art/pnj/build_pnj.py`, personnage `demon`)

```
blender --background --factory-startup --python art/pnj/build_pnj.py -- prepare demon
blender --background art/demon/demon.blend --python art/pnj/build_pnj.py -- views demon <dossier>
blender --background art/demon/demon.blend --python art/pnj/build_pnj.py -- rig demon force
blender --background art/demon/demon.blend --python art/riffald/retarget_mixamo.py -- export
```

1. **prepare** : maillage ressoudé, allégé à 40 000 triangles, mis à **1,95 m** cornes comprises ;
   textures 2K / 1K → `art/demon/demon.blend`.
2. **rig** : les 17 os de Riffald, placés sur les vues à grille. Ébauche des poids par distance aux os :
   cornes sur la tête, cheveux du dos sur la tête, le cou et le buste, cape (même maillage que le corps,
   repérée par sa position) sur le bassin et le dos seulement. Les faces qui soudaient la cape aux jambes
   sont retirées, sinon elles s'étiraient à chaque pas.
3. **Peinture des poids finie à la main par Ulysse** dans `demon.blend` (2 oct. 2026) : `rig demon` refuse
   désormais de tout recalculer, sauf avec `force` (retouches perdues). Pour une nouvelle retouche, ne relancer
   que l'**export** ; les vertices laissés sans poids y sont complétés d'après leurs voisins.
4. **export** : les 16 animations Mixamo de Riffald → `assets/models/demon/demon.glb`.

## Dans le jeu

- `RaceDB.PRESETS["demon"]` : apparence (race démon), modèle, taille (1,95 m), réglages de la guitare (`rig`).
