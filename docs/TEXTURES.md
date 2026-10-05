# Textures des sols et des murs

Source : les packs « Stylized » fournis par Ulysse, déposés en zips (4K) dans `assets/textures/` (ignorés par git
et par Godot). Seules les matières retenues sont ramenées en **1024 px** dans `assets/textures/<nom>/` :
`<nom>_couleur.jpg`, `<nom>_normal.jpg` (convention OpenGL, celle de Godot) et, pour la roche de lave,
`<nom>_emission.jpg` (fissures incandescentes).

```
blender --background --factory-startup --python tools/textures/prepare_textures.py -- <dossier des zips décompressés>
```

Le dictionnaire `CHOIX` du script fait le lien nom du jeu → matière du pack. Pour changer une texture : changer la
matière dans `CHOIX`, relancer le script, puis rouvrir le projet dans Godot (ou `--headless --import`).

| Nom | Matière du pack | Où |
|---|---|---|
| `pierre_moussue` | Stylized_02_Stone_Ground | sol des Catacombes (et tuile « Sol (dalles) » de l'éditeur de donjon) |
| `blocs_pierre` | Stylized_StoneTiles_02 | murs des Catacombes, pierre du décor de la taverne (cheminée...), chapelle et auberge de l'intro |
| `dallage` | Stylized_16_Stone_Floor | sol des Cryptes |
| `coulee_lave` | Stylized_LavaRock_01 | croûte qui dérive sur les ruisseaux de lave |
| `roche` | Stone_01 | murs et bords de lave des Cryptes, rochers du parvis du temple |
| `damier` | Stylized_CeramicTilingFloor_02 | sol du Temple du Dragon (damier de 1 m) |
| `pierre_claire` | Stylized_CeramicTiles_02 | murs du Temple |
| `dalles` | Stylized_StoneTiles_01 | parvis et marches du temple, sous-sol de la taverne |
| `dalles_usees` | Stylized_StoneTiles_03 | pierres tombales du cimetière de Morneval |
| `parquet` | Stylized_03_Wood_Planks | plancher de la taverne |
| `briques` | Stylized_Rounded_Bricks_02 | murs de la taverne |
| `herbe_terre` | Stylized_HandpaintedGrassAndDirt_01 | campagne de l'intro |
| `terre` | Stylized_HandpaintedDirt_01 | bas-côtés, tas de terre et tombes ouvertes |

## Dans le jeu

- `Visuals.textured(nom, mètres, teinte)` : matériau projeté sur les trois axes **du monde** (triplanaire) ; la
  texture garde sa taille quelle que soit celle des blocs et se raccorde d'un bloc à l'autre. `mètres` = largeur
  couverte par une répétition ; la teinte multiplie la texture (on assombrit pour l'ambiance).
- `Visuals.stone_material(découpe, teinte, nom, mètres)` : murs (shader `stone_wall`, qui garde la découpe autour du
  héros) ; sans nom de texture, les anciennes briques procédurales.
- Donjons : `DungeonThemes.WALL_TEXTURES` / `FLOOR_TEXTURES` par thème (une dalle par case de 2 m, à peine nuancée).
- Taverne : les tuiles des GridMap (`assets/levels/taverne_sols.tres`, `taverne_murs.tres`) sont régénérées par
  `tools/levels/build_tavern_assets.gd` (sans l'argument « taverne », la scène n'est pas touchée).

## Licence

À vérifier avant de distribuer le jeu : les packs doivent autoriser la redistribution dans un jeu.
