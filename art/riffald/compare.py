# Comparaison avec une planche de référence : rend le modèle dans les vues de la planche, à la même
# échelle et à la même position, puis produit une superposition (onion skin), un diff de silhouettes
# et une planche côte à côte. Profils : "riffald" (docs/concept/riffald_planche2_3d.jpg) et
# "guitare" (docs/concept/guitare_planche.jpg). Usage : exec(...) ; use("guitare") ; compare("v1").
import bpy, math, os
import numpy as np
from mathutils import Vector

ROOT = r"C:\Users\Ody\OneDrive\Bureau\Claude Code\metal-bard"
OUT = r"C:\Users\Ody\AppData\Local\Temp\claude\riffald_preview"
# vue : (lacet caméra, x pixel de l'axe, y pixel de z = 0, colonnes de la bande dans la planche)
PROFILES = {
    "riffald": dict(ref=ROOT + r"\docs\concept\riffald_planche2_3d.jpg", px=350.0, coll="Riffald", views={
        "front": (0, 281.5, 722, 0, 500),
        "back": (180, 705.0, 717, 500, 940),
        "side": (-70, 1120.0, 727, 940, 1290),  # profil droit tourné de 20° vers l'avant (calé par IoU)
    }),
    "guitare": dict(ref=ROOT + r"\docs\concept\guitare_planche.jpg", px=624.0, coll="Guitare", views={
        "front": (0, 264.0, 400, 0, 480),
        "back": (180, 696.5, 400, 480, 915),
        "side1": (65, 1025.0, 400, 915, 1140),  # vues de biais (calées par IoU)
        "side2": (75, 1237.0, 400, 1140, 1320),
    }),
}
P = PROFILES["riffald"]


def use(name):
    global P
    P = PROFILES[name]
    return P


def img_to_np(img):
    w, h = img.size
    a = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(a)
    return a.reshape(h, w, 4)[::-1]


def np_to_png(arr, path):
    h, w = arr.shape[:2]
    if arr.shape[2] == 3:
        arr = np.concatenate([arr, np.ones((h, w, 1), np.float32)], axis=2)
    name = "_cmp_out"
    img = bpy.data.images.get(name)
    if img is not None and tuple(img.size) != (w, h):
        bpy.data.images.remove(img)
        img = None
    if img is None:
        img = bpy.data.images.new(name, w, h, alpha=True)
    img.pixels.foreach_set(np.ascontiguousarray(arr[::-1]).ravel())
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    return path


def reference():
    key = "ref_" + P["coll"]
    img = bpy.data.images.get(key)
    if img is None:
        img = bpy.data.images.load(P["ref"])
        img.name = key
    return img_to_np(img)[:, :, :3]


def ref_mask(ref):
    bg = np.median(ref[:20, :20].reshape(-1, 3), axis=0)
    return np.abs(ref - bg).max(axis=2) > 0.08


def _camera(W, H):
    sc = bpy.context.scene
    cam = bpy.data.objects.get("RF_cam")
    if cam is None:
        cam = bpy.data.objects.new("RF_cam", bpy.data.cameras.new("RF_cam"))
        sc.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = W / P["px"]
    cam.data.clip_start = 0.1
    cam.data.clip_end = 20
    sc.camera = cam
    sc.render.engine = "BLENDER_WORKBENCH"
    sh = sc.display.shading
    sh.light = "STUDIO"
    sh.color_type = "MATERIAL"
    sh.show_cavity = True
    sh.show_specular_highlight = False
    sh.show_object_outline = True
    sh.object_outline_color = (0.05, 0.03, 0.03)
    sc.render.resolution_x, sc.render.resolution_y = W, H
    sc.render.resolution_percentage = 100
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.look = "None"
    return sc, cam


def _isolate():
    """N'affiche que la collection du profil courant ; renvoie l'état à restaurer."""
    saved = {}
    colls = {p["coll"] for p in PROFILES.values()}
    for lc in bpy.context.view_layer.layer_collection.children:
        if lc.name in colls:
            saved[lc.name] = lc.exclude
            lc.exclude = lc.name != P["coll"]
    return saved


def _restore(saved):
    for lc in bpy.context.view_layer.layer_collection.children:
        if lc.name in saved:
            lc.exclude = saved[lc.name]


def render_views(views=None):
    """Rend chaque vue alignée sur la planche et les assemble en une image RGBA de la taille de la planche."""
    os.makedirs(OUT, exist_ok=True)
    H, W = reference().shape[:2]
    saved = _isolate()
    sc, cam = _camera(W, H)
    canvas = np.zeros((H, W, 4), np.float32)
    for name, (yaw, cx, gy, lo, hi) in (views or P["views"]).items():
        a = math.radians(yaw)
        right = Vector((math.cos(a), math.sin(a), 0))  # droite de l'image dans le monde
        fwd = Vector((-math.sin(a), math.cos(a), 0))  # direction de visée
        off = (cx - W / 2) / P["px"]
        zc = (gy - H / 2) / P["px"]
        cam.location = -right * off - fwd * 6 + Vector((0, 0, zc))
        cam.rotation_euler = (math.radians(90), 0, a)
        p = os.path.join(OUT, f"_v_{name}.png")
        sc.render.filepath = p
        bpy.ops.render.render(write_still=True)
        im = bpy.data.images.load(p, check_existing=False)
        arr = img_to_np(im)
        bpy.data.images.remove(im)
        canvas[:, lo:hi] = np.where(arr[:, lo:hi, 3:4] > 0.01, arr[:, lo:hi], canvas[:, lo:hi])
    sc.render.film_transparent = False
    _restore(saved)
    return canvas


def compare(tag="cmp"):
    ref = reference()
    rm = ref_mask(ref)
    mod = render_views()
    mm = mod[:, :, 3] > 0.5
    alpha = mod[:, :, 3:4]
    bg = np.full_like(ref, float(np.median(ref[:20, :20])))
    model_only = mod[:, :, :3] * alpha + bg * (1 - alpha)
    onion = ref * 0.5 + model_only * 0.5
    # diff de silhouettes : rouge = référence seule, bleu = modèle seul, gris = commun
    diff = np.full_like(ref, 0.95)
    diff[rm & mm] = (0.55, 0.55, 0.55)
    diff[rm & ~mm] = (0.9, 0.15, 0.1)
    diff[~rm & mm] = (0.1, 0.35, 0.95)
    iou = (rm & mm).sum() / max(1, (rm | mm).sum())
    both = np.concatenate([ref, model_only], axis=0)
    paths = [np_to_png(onion, os.path.join(OUT, f"{tag}_onion.png")),
             np_to_png(diff, os.path.join(OUT, f"{tag}_diff.png")),
             np_to_png(both, os.path.join(OUT, f"{tag}_both.png"))]
    return iou, paths


def view_iou(name, yaw, cx):
    """IoU d'une seule vue (pour caler l'angle et la position d'une vue de la planche)."""
    yaw0, cx0, gy, lo, hi = P["views"][name]
    rm = ref_mask(reference())[:, lo:hi]
    mm = render_views({name: (yaw, cx, gy, lo, hi)})[:, lo:hi, 3] > 0.5
    return (rm & mm).sum() / max(1, (rm | mm).sum())


def crop(tag, x0, y0, x1, y1, scale=3, model=False):
    """Agrandit une zone de la planche (ou du rendu aligné) pour l'étudier."""
    src = reference() if not model else render_views()[:, :, :3]
    c = src[y0:y1, x0:x1]
    c = np.repeat(np.repeat(c, scale, axis=0), scale, axis=1)
    return np_to_png(c, os.path.join(OUT, f"crop_{tag}.png"))


def crop2(tag, x0, y0, x1, y1, scale=2):
    """Zone agrandie : planche à gauche, modèle aligné à droite."""
    ref = reference()
    mod = render_views()
    a = mod[:, :, 3:4]
    m = mod[:, :, :3] * a + float(np.median(ref[:20, :20])) * (1 - a)
    c = np.concatenate([ref[y0:y1, x0:x1], m[y0:y1, x0:x1]], axis=1)
    c = np.repeat(np.repeat(c, scale, axis=0), scale, axis=1)
    return np_to_png(c, os.path.join(OUT, f"crop2_{tag}.png"))


def sample(pts, r=3):
    ref = reference()
    out = {}
    for k, (x, y) in pts.items():
        c = ref[y - r:y + r + 1, x - r:x + r + 1].reshape(-1, 3).mean(axis=0)
        out[k] = tuple(round(float(v), 3) for v in c)
    return out
