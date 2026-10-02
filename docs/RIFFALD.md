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
- Style dessiné (ombres peintes dans la texture), peu de polygones ; rendu sans cel shading depuis v0.1.27.

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
- Export : `assets/models/riffald/riffald.glb` (~7 Mo) — un maillage unique (~40 k faces, 21 matériaux) avec son
  atlas peint en JPEG (Godot l'extrait en `riffald_riffald_v3_couleur.jpg`), armature de 17 os nommés comme les
  pivots de HeroModel (`hips`, `spine`, `chest`, `neck`, `head`, `upper_arm/forearm/hand.L/R`,
  `thigh/shin/foot.L/R`), pose A, regarde vers +Z dans Godot, et les 16 animations Mixamo.
- Mise à jour du jeu : `build_all()`, `build_rig()`, `texture_all(4096, 8)` dans Blender, enregistrer
  `art/riffald/riffald.blend`, puis `blender --background art/riffald/riffald.blend --python
  art/riffald/retarget_mixamo.py -- export` (transfert des animations et export du glb).
- Dans le jeu (v0.1.12) : choisi avec « Héros : Riffald (prédéfini) ». `RiggedSkin` (scripts/actors/rigged_skin.gd)
  fait suivre ce squelette au squelette procédural invisible de HeroModel : buste et tête en rotation relative,
  bras et jambes en IK à deux os avec les longueurs du modèle (mains sur la guitare, pieds au sol). Côtés :
  « _l » de HeroModel (côté -X) = os « .R ». Matières mates sans reflet toon (dont l'acier sombre, `MB_metal` étant
  presque non métallique) ; peau et cheveux un peu assombris, cuir et acier davantage (les projecteurs du jeu
  les délavaient en gris).
- Reste à faire : os des doigts, cape et mèches animées (os secondaires).

## Version 3 (dans le jeu depuis la v0.1.17)
- `art/riffald/build_riffald.py` construit la v3 (~40 k faces, 21 matériaux, mêmes 17 os que la v2).
- Mains : gauche et droite remises à l'endroit (pouce côté intérieur, doigts repliés vers la paume).
- Épaulières : dôme découpé en chevron vu de face (bord intérieur vertical le long du col, biais puis bord
  horizontal), rebord clair biseauté, lame basse évasée, quatre pointes (dressée, extérieure, avant, arrière).
- Genouillères en écusson à facettes ; bottes : revers clouté (pyramides et clous) à boucle, sangle à mi-tige,
  sangle de cheville inclinée, bout ferré à trois pointes, semelle épaisse et talon.
- Crinière : mèches en relief jointives ondulées en S dans le dos (deux couches), pointes recourbées ;
  mèches autour du visage et houppe balayée vers la gauche du personnage.
- Acier bleuté sombre (`MB_metal`), bords clairs (`MB_metal_bord`), semelles `MB_semelle`.
- Devant de la crinière : raie un peu à gauche du personnage, trois mèches de chaque côté qui encadrent le front
  et tombent le long des joues ; visage un peu affiné (pommettes à ±8,7 cm), sourcils plus sombres.
- Textures peintes : `art/riffald/texture_riffald.py` (après `build_all()` et `build_rig()` :
  `texture_all(4096, 8)`, puis `export_textured(chemin)`). Chaque matière a un shader procédural (cuir froissé
  et rayé, sangles grainées, acier brossé et rayé, tissu plissé, peau, mèches striées) avec ombres : occlusion
  ambiante, lumière douce venant du haut à droite du personnage, ombres colorées, arêtes usées claires, reflets
  peints. Le tout est cuit (Cycles, passe EMIT, ~30 s en 4096) dans un atlas unique
  `art/riffald/textures/riffald_v3_couleur.png` ; les matériaux gardent leurs noms `MB_*` et lisent l'atlas
  en couleur de base (JPEG dans le glb, ~6 Mo). Les ombres étant peintes, un rendu mat ou toon suffit dans Godot.
- Aperçu : `compare.py`, `shading("TEXTURE", "FLAT")` montre l'atlas seul.
