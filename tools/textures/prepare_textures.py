# Prépare les textures du jeu à partir des packs d'Ulysse (assets/textures/*.zip, 4K) : pour chaque matière
# retenue, couleur, normale (convention OpenGL, celle de Godot) et émission éventuelle, ramenées en 1024 px et
# écrites en JPEG dans assets/textures/<nom>/.
#
# Usage (les zips décompressés dans un dossier SOURCE, hors du projet) :
#   blender --background --factory-startup --python tools/textures/prepare_textures.py -- <SOURCE>
import bpy, glob, os, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
OUT = os.path.join(ROOT, "assets", "textures")
SIZE = 1024

# nom dans le jeu -> matière du pack
CHOIX = {
    "pierre_moussue": "Stylized_02_Stone_Ground",       # sol des Catacombes
    "blocs_pierre": "Stylized_StoneTiles_02",           # murs des Catacombes
    "roche_lave": "Stylized_LavaRock_02",               # sol des Cryptes (fissures rougeoyantes)
    "coulee_lave": "Stylized_LavaRock_01",              # ruisseaux de lave
    "roche": "Stone_01",                                # murs des Cryptes (basalte)
    "damier": "Stylized_CeramicTilingFloor_02",         # sol du Temple du Dragon
    "pierre_claire": "Stylized_CeramicTiles_02",        # murs du Temple
    "dalles": "Stylized_StoneTiles_01",                 # parvis, marches, sous-sol de la taverne
    "dalles_usees": "Stylized_StoneTiles_03",           # pierres tombales
    "parquet": "Stylized_03_Wood_Planks",               # plancher de la taverne
    "briques": "Stylized_Rounded_Bricks_02",            # murs de la taverne
    "herbe_terre": "Stylized_HandpaintedGrassAndDirt_01",  # cimetière
    "terre": "Stylized_HandpaintedDirt_01",             # tombes ouvertes, tas de terre
}


def find(src, name, suffixes):
    for suf in suffixes:
        hits = glob.glob(os.path.join(src, "**", f"{name}*_{suf}.jpg"), recursive=True)
        if hits:
            return hits[0]
    return None


def convert(path, out):
    img = bpy.data.images.load(path)
    img.colorspace_settings.name = "Non-Color"  # pas de conversion de couleurs à l'enregistrement
    if img.size[0] != SIZE:
        img.scale(SIZE, SIZE)
    sc = bpy.context.scene
    sc.render.image_settings.file_format = "JPEG"
    sc.render.image_settings.quality = 90
    img.save_render(out, scene=sc)
    bpy.data.images.remove(img)


def main():
    src = sys.argv[sys.argv.index("--") + 1]
    for nom, mat in CHOIX.items():
        d = os.path.join(OUT, nom)
        os.makedirs(d, exist_ok=True)
        maps = {"couleur": find(src, mat, ["basecolor"]), "normal": find(src, mat, ["normalogl", "normalOgl"]),
                "emission": find(src, mat, ["Emissive"])}
        for kind, p in maps.items():
            if p:
                convert(p, os.path.join(d, f"{nom}_{kind}.jpg"))
        print(f"[textures] {nom} <- {mat} : {', '.join(k for k, p in maps.items() if p)}")


main()
