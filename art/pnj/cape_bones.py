# Cape en tissu : ajoute à un personnage des os de cape (3 chaînes de 4 os : côté droit, centre, côté gauche) et lie les
# vertex de la cape à ces os. Le jeu les simule comme du tissu (SpringBoneSimulator3D, voir scripts/actors/rigged_skin.gd) :
# la cape suit les mouvements avec inertie, retombe avec la gravité et ne traverse pas les jambes.
#
# Usage (sans interface ; le .blend est modifié, Blender en garde une copie en .blend1) :
#   blender --background art/hella/hella.blend --python art/pnj/cape_bones.py -- hella
# puis réexporter : blender --background art/hella/hella.blend --python art/riffald/retarget_mixamo.py -- export
#
# Seuls les vertex de la cape (repérés comme au rig : build_pnj._candidates) sont repondérés ; le reste du personnage
# (et toute peinture faite à la main ailleurs) ne bouge pas. Os : « cape_<R|C|L>_<0..3> », R du côté -X (comme .R).
import bpy, os, sys
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_pnj  # noqa: E402

NAME = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "hella"
build_pnj.ARGS = ["rig", NAME]
# Forme de la cape, relevée sur les vues de dos et de profil : niveaux (z, y de la cape, un peu à l'intérieur) du haut
# du dos jusqu'au bas ; écart des chaînes latérales en haut et en bas.
CAPES = {
    "hella": {"levels": [(1.30, 0.10), (1.02, 0.15), (0.74, 0.21), (0.46, 0.28), (0.20, 0.32)],
              "side_top": 0.15, "side_bottom": 0.38, "attach": (1.22, 1.32)},
}
SIDES = {"R": -1.0, "C": 0.0, "L": 1.0}

cape = CAPES[NAME]
cfg = build_pnj.CHARS[NAME]
body = bpy.data.objects[cfg["name"]]
rig = bpy.data.objects[cfg["name"] + "_rig"]
j = build_pnj.joints()
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

# Vertex de la cape : ceux que le rig met sur le bassin, le dos et le buste (pas la tresse, pas le corps).
groups = {g.name: g for g in body.vertex_groups}
for name in segs:
    if name not in groups:
        groups[name] = body.vertex_groups.new(name=name)
cape_verts = [v for v in body.data.vertices if build_pnj._candidates(v.co, j) == ["hips", "spine", "chest"]]
a0, a1 = cape["attach"]
for v in cape_verts:
    for g in list(v.groups):
        body.vertex_groups[g.group].remove([v.index])
    p = v.co
    ds = sorted((build_pnj._seg_dist(p, *segs[n]), n) for n in segs)[:3]
    ws = [1.0 / max(d, 0.01) ** 3 for d, _ in ds]
    tot = sum(ws)
    # En haut, la cape reste accrochée aux épaules : elle suit le buste.
    k = min(1.0, max(0.0, (p.z - a0) / (a1 - a0)))
    if k > 0.0:
        groups["chest"].add([v.index], k, "REPLACE")
    for (d, n), w in zip(ds, ws):
        if (1.0 - k) * w / tot > 0.02:
            groups[n].add([v.index], (1.0 - k) * w / tot, "REPLACE")
bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath)
print("CAPE %s : %d os, %d vertex de cape" % (NAME, len(segs), len(cape_verts)))
