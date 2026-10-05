# Guitares fournies par Ulysse (Imagerie/Guitares/3D/*.glb) : préparation pour le jeu.
#   - batguitare : la Batguitare, butin de l'ange déchu (Temple du Dragon), emplacement « Guitare » (docs/OBJETS.md) ;
#   - guitare_backjlack : la basse que Back Jlack porte dans le dos ;
#   - xplode : la Xplode (explorer.glb), butin du Gardien des Cryptes (portail à XP), emplacement « Guitare ».
#
# Usage (sans interface, depuis la racine du dépôt) :
#   blender --background --factory-startup --python art/guitare/prepare_guitares.py -- <guitare>
#       -> assets/models/guitare/<guitare>.glb
#
# Même repère que la guitare des héros (guitare_heros.glb) : manche vers +Y, face vers +Z (dans Godot), origine à la
# jonction du manche et du corps, sillet à 0,385 m au-dessus : les mains des héros tombent au même endroit.
import bpy, bmesh, os, sys
from mathutils import Matrix, Vector

SRC_DIR = r"C:\Users\Ody\OneDrive\Bureau\GODOT\Jeux\Metal Bards\Imagerie\Guitares\3D"
# Guitare -> (fichier source, jonction manche / corps, sillet, axe du manche) : hauteurs et décalage latéral relevés
# sur la vue de face du modèle source (1 m de haut, centré sur l'origine).
GUITARS = {
    "batguitare": ("batguitare.glb", -0.05, 0.305, 0.0),
    "guitare_backjlack": ("back jlack.glb", -0.11, 0.305, 0.0),
    "xplode": ("explorer.glb", -0.07, 0.315, 0.028),  # la Xplode, butin du Gardien des Cryptes
}
NAME = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "batguitare"
ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
SRC = os.path.join(SRC_DIR, GUITARS[NAME][0])
OUT = os.path.join(ROOT, "assets", "models", "guitare", NAME + ".glb")
TARGET_FACES = 24000
TEX = 2048
JUNCTION_Z = GUITARS[NAME][1]
NUT_Z = GUITARS[NAME][2]
NECK_X = GUITARS[NAME][3]
NUT = 0.385  # sillet de la guitare des héros (m au-dessus de l'origine)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
meshes = [o for o in bpy.data.objects if o.type == "MESH"]
for o in bpy.data.objects:
    o.select_set(o in meshes)
bpy.context.view_layer.objects.active = meshes[0]
if len(meshes) > 1:
    bpy.ops.object.join()
g = bpy.context.view_layer.objects.active
g.data.transform(g.matrix_world)
g.parent = None
g.matrix_world.identity()
bm = bmesh.new()
bm.from_mesh(g.data)
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
bm.to_mesh(g.data)
bm.free()
faces = len(g.data.polygons)
if faces > TARGET_FACES:
    dec = g.modifiers.new("Decimate", "DECIMATE")
    dec.ratio = TARGET_FACES / faces
    with bpy.context.temp_override(object=g, active_object=g):
        bpy.ops.object.modifier_apply(modifier=dec.name)
k = NUT / (NUT_Z - JUNCTION_Z)
g.data.transform(Matrix.Scale(k, 4) @ Matrix.Translation(Vector((-NECK_X, 0, -JUNCTION_Z))))
g.name = NAME
g.data.name = NAME
for o in list(bpy.data.objects):
    if o != g:
        bpy.data.objects.remove(o, do_unlink=True)
for img in bpy.data.images:
    if img.size[0] > TEX:
        img.scale(TEX, TEX)
for m in g.data.materials:
    m.name = "MB_" + NAME
vs = [v.co for v in g.data.vertices]
print("GUITARE %s faces=%d hauteur=%.3f (de %.3f à %.3f)" % (NAME, len(g.data.polygons), max(v.z for v in vs) - min(v.z for v in vs),
      min(v.z for v in vs), max(v.z for v in vs)))
os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_yup=True, export_image_format="JPEG")
