# Riffald — fiche de référence

Héros prédéfini proposé à la création de personnage (choix « Héros : Riffald (prédéfini) »).
Planche de référence : [concept/riffald_turnaround.jpg](concept/riffald_turnaround.jpg)
(vues de face, dos, profils, dessus, dessous, en T-pose stricte, bras à 90°, paumes vers l'avant).

Le modèle détaillé sera réalisé dans Blender puis exporté en `.glb` pour Godot. En attendant,
le jeu utilise le modèle généré le plus proche : humain, rasé de près, coiffure « Glam-metal »,
cheveux « Roux flamboyant ».

## Silhouette
- Humain, 1,8 m, corps sec et élancé, posture droite et fière.
- Visage anguleux, mâchoire marquée, regard dur, sourcils froncés, pas de barbe ; boucle d'oreille.

## Cheveux
- Longue crinière **orange vif**, très volumineuse et bouclée, qui tombe sous les épaules
  (voir « Hair-Flow Guide » : mèches ondulées en pointes).

## Tenue (cuir noir usé)
- **Veste de cuir noir** cloutée, col montant, torse ouvert sur un maillot sombre.
- **Épaulières de métal sombre à pointes** (3 pointes argentées chacune), fixées par sangles et boucles.
- **Sangles croisées** sur le torse avec boucles carrées en fer.
- **Col clouté** avec **chaînes** qui pendent sur la poitrine ; **gemme rouge** (médaillon).
- **Ceinture** cloutée à grosse boucle ; pantalon de cuir noir, **genouillères** en métal.
- **Mitaines** de cuir noir (doigts nus).
- **Bottes hautes** à sangles et boucles, clous et **pointes** sur le bout et le talon.
- **Cape bordeaux** longue, **déchirée en lambeaux** en bas, attachée sous les épaulières.

## Palette
| Élément | Couleur |
|---|---|
| Cuir usé | noir / gris anthracite |
| Cape | bordeaux (rouge vin sombre) |
| Pointes, clous, boucles | argent / acier |
| Gemme | rouge rubis |
| Cheveux | orange vif |

## Pour le jeu
- Garder la **Flying V** (accessoire séparé) et les **mains à cinq doigts** (jeu de guitare animé).
- Squelette d'animation compatible avec les poses actuelles : marche, course, frappe, solo,
  glissade sur les genoux, saut à la Angus Young, allongé au lit.
- Style **cel shading** : aplats de couleur, contour encré ; peu de polygones.

## Modèle 3D (Blender)
- Planche 3D : [concept/riffald_planche2_3d.jpg](concept/riffald_planche2_3d.jpg) (face, dos, profil, pose A).
- Source : `art/riffald/build_riffald.py` (construction procédurale, rejouable dans Blender 5.2 :
  `exec(open(...).read())`, puis `build_all()`, `build_rig()`, `export_glb(path)`), fichier `art/riffald/riffald.blend`.
  `art/` est ignoré par Godot (`.gdignore`).
- Calage sur la planche : `art/riffald/compare.py` rend face / dos / profil à la même échelle que la planche
  (350 px/m ; le profil de la planche est tourné d'environ 20° vers l'avant) et produit une superposition,
  un diff de silhouettes et une planche côte à côte. Recouvrement des silhouettes : 86 %.
  Couleurs relevées sur la planche (sRGB, converties en linéaire dans les matériaux).
- Proportions retenues : 1,80 m sous les cheveux (1,93 m crinière comprise), épaulières jusqu'à ±0,41 m,
  épaules à ±0,275 m, avant-bras nus sous des manches retroussées, grandes mains (bout des doigts vers 0,70 m),
  jambes écartées (chevilles à ±0,20 m), pieds ouverts de 18°.
- Export : `assets/models/riffald/riffald.glb` — un maillage unique (~23 k faces, 17 matériaux),
  armature de 17 os nommés comme les pivots de HeroModel (`hips`, `spine`, `chest`, `neck`, `head`,
  `upper_arm/forearm/hand.L/R`, `thigh/shin/foot.L/R`), pose A, regarde vers +Z dans Godot.
- Dans le jeu (v0.1.12) : choisi avec « Héros : Riffald (prédéfini) ». `RiggedSkin` (scripts/actors/rigged_skin.gd)
  fait suivre ce squelette au squelette procédural invisible de HeroModel : buste et tête en rotation relative,
  bras et jambes en IK à deux os avec les longueurs du modèle (mains sur la guitare, pieds au sol). Côtés :
  « _l » de HeroModel (côté -X) = os « .R ». Matières mates sans reflet toon, peau et cheveux un peu assombris.
- Reste à faire : os des doigts, cape et mèches animées (os secondaires).
