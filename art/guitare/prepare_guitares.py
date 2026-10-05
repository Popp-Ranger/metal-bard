# Batguitare (guitare chauve-souris fournie par Ulysse, Imagerie/Guitares/3D/batguitare.glb) : préparation pour le jeu.
# Butin de l'ange déchu (Temple du Dragon), à équiper dans l'emplacement « Guitare » (voir docs/GUITARE.md).
#
# Usage (sans interface, depuis la racine du dépôt) :
#   blender --background --factory-startup --python art/guitare/prepare_batguitare.py
#       -> assets/models/guitare/batguitare.glb
#
# Même repère que la guitare des héros (guitare_heros.glb) : manche vers +Y, face vers +Z (dans Godot), origine à la
# jonction du manche et du corps, sillet à 0,385 m au-dessus : les mains des héros tombent au même endroit.
import bpy, bmesh, os
from mathutils import Matrix, Vector

SRC = r"C:\Users\Ody\OneDrive\Bureau\GODOT\Jeux\Metal Bards\Imagerie\Guitares\3D\batguitare.glb"
ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
OUT = os.path.join(ROOT, "assets", "models", "guitare", "batguitare.glb")
TARGET_FACES = 24000
TEX = 2048
# Relevés sur la vue de face du modèle source (1 m de haut, centré) : jonction manche / corps et sillet.
JUNCTION_Z = -0.05
NUT_Z = 0.305
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
g.data.transform(Matrix.Scale(k, 4) @ Matrix.Translation(Vector((0, 0, -JUNCTION_Z))))
g.name = "Batguitare"
g.data.name = "Batguitare"
for o in list(bpy.data.objects):
    if o != g:
        bpy.data.objects.remove(o, do_unlink=True)
for img in bpy.data.images:
    if img.size[0] > TEX:
        img.scale(TEX, TEX)
for m in g.data.materials:
    m.name = "MB_batguitare"
vs = [v.co for v in g.data.vertices]
print("BATGUITARE faces=%d hauteur=%.3f (de %.3f à %.3f)" % (len(g.data.polygons), max(v.z for v in vs) - min(v.z for v in vs),
      min(v.z for v in vs), max(v.z for v in vs)))
os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_yup=True, export_image_format="JPEG")
