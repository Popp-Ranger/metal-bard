# Guitare des héros — Flying V démoniaque

Planche de référence : [concept/guitare_planche.jpg](concept/guitare_planche.jpg) (face, dos, deux vues de biais).
Les sangles de la planche ne sont pas modélisées.

## Modèle 3D (Blender)
- Source : `art/guitare/build_guitare.py` (construction procédurale, rejouable dans Blender 5.2 :
  `exec(open(...).read())`, puis `build_guitar()`, `join_guitar()`, `export_guitar(path)`) ;
  il réutilise les utilitaires de `art/riffald/build_riffald.py`. Fichier `art/guitare/guitare.blend`.
- Calage : `art/riffald/compare.py`, profil `use("guitare")` (624 px/m ; les deux vues de biais de la planche
  sont à environ 65° et 75°). Recouvrement des silhouettes : 81 % (les sangles de la vue de dos comptent contre).
- Export : `assets/models/guitare/guitare_heros.glb` — un maillage unique (~4 000 faces, 13 matériaux),
  1,14 m de long, 0,62 m d'envergure.
- Repère (comme `_build_flying_v` dans HeroModel) : manche vers +Y, face avant vers +Z,
  origine à la jonction manche / corps (la pointe du V).

## Pièces
- Tête en écusson d'acier sombre, deux cornes en croissant, crâne d'argent et dague, 3 + 3 mécaniques.
- Manche en bois brun, touche sombre, 22 frettes, repères nacrés, sillet en os.
- Corps en V bordeaux cerclé d'acier (tranche rivetée), plaque de protection en acier sombre rivetée,
  deux micros double bobinage, chevalet, trois boutons, cordier en croissant serti d'une gemme rouge.
- Épaulières d'armure de part et d'autre du manche (corne recourbée, pointes), embouts en pointe de flèche
  au bout des ailes (gemme rouge, pointes). Dos : écusson riveté avec petite gemme.
- Matériaux utiles pour le jeu : `MB_g_cordes` (cordes, à rendre lumineuses pendant le solo),
  `MB_g_gemme` (gemmes, émissives).

## Dans le jeu (v0.1.12)
- Remplace la Flying V procédurale pour tous les héros (`HeroModel._build_imported_guitar`).
- Main gauche placée proportionnellement au manche (sillet à 0,385 m au lieu de 0,64 m).
- `MB_g_cordes` lumineux (plus vif pendant le solo), `MB_g_gemme` émissif.
