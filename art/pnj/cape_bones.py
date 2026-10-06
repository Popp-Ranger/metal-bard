# Cape en tissu : ajoute à un personnage des os de cape (3 chaînes de 4 os : côté droit, centre, côté gauche) et lie les
# vertex de la cape à ces os. Le jeu les simule comme du tissu (SpringBoneSimulator3D, voir scripts/actors/rigged_skin.gd) :
# la cape suit les mouvements avec inertie, retombe avec la gravité et ne traverse pas les jambes.
#
# Usage (sans interface ; le .blend est modifié, Blender en garde une copie en .blend1) :
#   blender --background art/hella/hella.blend --python art/pnj/cape_bones.py -- hella
#   blender --background art/riffald/riffald.blend --python art/pnj/cape_bones.py -- riffald
# puis réexporter : blender --background <le .blend> --python art/riffald/retarget_mixamo.py -- export
#
# Seuls les vertex de la cape sont repondérés ; le reste du personnage (et toute peinture faite à la main ailleurs) ne
# bouge pas. La cape est repérée comme au rig (build_pnj._candidates : Hella) ou par son matériau (Riffald : MB_cape,
# avec les sangles posées dessus dans le dos). Os : « cape_<R|C|L>_<0..3> », R du côté -X (comme .R).
import bpy, os, sys
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_pnj  # noqa: E402

NAME = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "hella"
# levels : niveaux (z, y de la cape, un peu à l'intérieur) du haut du dos jusqu'au bas, relevés sur les vues de dos et
# de profil ; sinon (« auto ») déduits de la cape elle-même. side_top / side_bottom : écart des chaînes latérales.
# attach : de z0 à z1, la cape passe progressivement du buste (accrochée aux épaules) aux os de cape.
CAPES = {
    "hella": {"levels": [(1.30, 0.10), (1.02, 0.15), (0.74, 0.21), (0.46, 0.28), (0.20, 0.32)],
              "side_top": 0.15, "side_bottom": 0.38, "attach": (1.22, 1.32)},
    # Riffald : cape rouge sous les épaulières jusqu'aux mollets (build_riffald.py, matériau MB_cape) ; les sangles
    # croisées du dos (MB_sangle, derrière y > 0,12) sont cousues dessus.
    "riffald": {"object": "Riffald", "rig": "Riffald_rig", "material": "MB_cape", "with": {"MB_sangle": 0.12},
                "auto": True, "top": 1.32, "bottom": 0.3, "attach": (1.24, 1.36)},
}
SIDES = {"R": -1.0, "C": 0.0, "L": 1.0}

cape = CAPES[NAME]
body = bpy.data.objects[cape.get("object") or build_pnj.CHARS[NAME]["name"]]
rig = bpy.data.objects[cape.get("rig") or build_pnj.CHARS[NAME]["name"] + "_rig"]


def cape_vertices():
    """Indices des vertex de la cape."""
    if "material" not in cape:
        build_pnj.ARGS = ["rig", NAME]
        j = build_pnj.joints()
        return [v.index for v in body.data.vertices if build_pnj._candidates(v.co, j) == ["hips", "spine", "chest"]]
    mats = {i: m.name for i, m in enumerate(body.data.materials) if m}
    out = set()
    extra = cape.get("with", {})
    for p in body.data.polygons:
        name = mats.get(p.material_index, "")
        if name == cape["material"]:
            out.update(p.vertices)
        elif name in extra:
            out.update(i for i in p.vertices if body.data.vertices[i].co.y > extra[name])
    return sorted(out)


verts = cape_vertices()
cos = [body.data.vertices[i].co for i in verts]
if cape.get("auto"):
    # Niveaux déduits de la cape : au dos (y > 0,05), la profondeur médiane de la cape à chaque hauteur, et son
    # étendue latérale (les chaînes latérales aux deux tiers).
    top, bottom = cape["top"], cape["bottom"]
    levels, widths = [], []
    for k in range(5):
        z = top + (bottom - top) * k / 4.0
        near = [c for c in cos if abs(c.z - z) < 0.06 and c.y > 0.05] or [c for c in cos if abs(c.z - z) < 0.12]
        ys = sorted(c.y for c in near)
        levels.append((z, ys[len(ys) // 2] - 0.02))
        widths.append(max(abs(c.x) for c in near))
    cape["levels"] = levels
    cape["side_top"] = widths[0] * 0.6
    cape["side_bottom"] = widths[-1] * 0.65
levels = cape["levels"]
z_top, z_bot = levels[0][0], levels[-1][0]


def joint(side, k):
    z, y = levels[k]
    t = (z_top - z) / (z_top - z_bot)
    x = SIDES[side] * (cape["side_top"] + (cape["side_bottom"] - cape["side_top"]) * t)
    return Vector((x, y, z))


# Os de la cape (remplacés s'ils existent déjà).
bpy.context.view_layer.objects.active = rig
for o in bpy.context.view_layer.objects:
    o.select_set(False)
rig.select_set(True)
bpy.ops.object.mode_set(mode="EDIT")
eb = rig.data.edit_bones
for b in [b for b in eb if b.name.startswith("cape_")]:
    eb.remove(b)
segs = {}
for side in SIDES:
    parent = eb["chest"]
    for k in range(len(levels) - 1):
        b = eb.new("cape_%s_%d" % (side, k))
        b.head, b.tail = joint(side, k), joint(side, k + 1)
        b.roll = 0.0
        b.parent = parent
        b.use_connect = k > 0
        segs[b.name] = (b.head.copy(), b.tail.copy())
        parent = b
bpy.ops.object.mode_set(mode="OBJECT")

# Poids : les 3 os de cape les plus proches ; en haut, la cape suit le buste (accrochée aux épaules).
groups = {g.name: g for g in body.vertex_groups}
for name in segs:
    if name not in groups:
        groups[name] = body.vertex_groups.new(name=name)
a0, a1 = cape["attach"]
for i in verts:
    v = body.data.vertices[i]
    for g in list(v.groups):
        body.vertex_groups[g.group].remove([i])
    p = v.co
    ds = sorted((build_pnj._seg_dist(p, *segs[n]), n) for n in segs)[:3]
    ws = [1.0 / max(d, 0.01) ** 3 for d, _ in ds]
    tot = sum(ws)
    k = min(1.0, max(0.0, (p.z - a0) / (a1 - a0)))
    if k > 0.0:
        groups["chest"].add([i], k, "REPLACE")
    for (d, n), w in zip(ds, ws):
        if (1.0 - k) * w / tot > 0.02:
            groups[n].add([i], (1.0 - k) * w / tot, "REPLACE")
bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath)
print("CAPE %s : %d os, %d vertex de cape, niveaux %s" % (NAME, len(segs), len(verts),
      ", ".join("(%.2f, %.2f)" % l for l in levels)))
