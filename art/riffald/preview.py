# Rendu de contrôle Workbench : planche face / dos / profil / 3-4 en une image
# (instances de la collection Riffald côte à côte, l'original est masqué le temps du rendu).
import bpy, math, os
from mathutils import Vector

OUT = r"C:\Users\Ody\AppData\Local\Temp\claude\riffald_preview"


def _setup(res_x, res_y):
    sc = bpy.context.scene
    cam = bpy.data.objects.get("RF_cam")
    if cam is None:
        cam = bpy.data.objects.new("RF_cam", bpy.data.cameras.new("RF_cam"))
        sc.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    sc.camera = cam
    sc.render.engine = "BLENDER_WORKBENCH"
    sh = sc.display.shading
    sh.light = "STUDIO"
    sh.color_type = "MATERIAL"
    sh.show_cavity = True
    sh.show_object_outline = True
    sc.render.resolution_x = res_x
    sc.render.resolution_y = res_y
    sc.render.resolution_percentage = 100
    if sc.world:
        sc.world.color = (0.38, 0.38, 0.40)
    return sc, cam


def sheet(name="sheet", yaws=(0, 180, 90, 35), res=1400, focus=None):
    """focus=None : corps entier ; sinon (z, hauteur visible) pour un gros plan."""
    os.makedirs(OUT, exist_ok=True)
    src = bpy.data.collections["Riffald"]
    tmp = bpy.data.collections.get("RF_preview") or bpy.data.collections.new("RF_preview")
    if tmp.name not in bpy.context.scene.collection.children:
        bpy.context.scene.collection.children.link(tmp)
    for o in list(tmp.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    n = len(yaws)
    span = 0.95 if focus is None else 0.6
    for i, y in enumerate(yaws):
        if i == 0:
            continue  # slot 0 : l'original (face)
        e = bpy.data.objects.new(f"RF_inst{i}", None)
        e.instance_type = "COLLECTION"
        e.instance_collection = src
        e.location = (i * span, 0, 0)
        e.rotation_euler = (0, 0, math.radians(y))
        tmp.objects.link(e)



    zc, h = (0.93, 2.0) if focus is None else focus
    w = n * span
    sc, cam = _setup(res, int(res * h / w))
    cam.location = ((n - 1) / 2 * span, -6, zc)
    cam.rotation_euler = (math.radians(90), 0, 0)
    cam.data.ortho_scale = max(w, h) if focus is None else w
    p = os.path.join(OUT, name + ".png")
    sc.render.filepath = p
    bpy.ops.render.render(write_still=True)

    for o in list(tmp.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    bpy.data.collections.remove(tmp)
    return p
