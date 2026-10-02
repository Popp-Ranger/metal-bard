# Héroïne prédéfinie « persoF1 » : préparation du modèle généré (glb) pour le jeu.
#
# Source : modèle fourni par Ulysse (généré par IA, ~2 M triangles, textures 8K, sans squelette),
#   C:\Users\Ody\OneDrive\Bureau\GODOT\Jeux\Metal Bards\Imagerie\3D\Féminin\persoF1.glb
#
# Usage (sans interface) :
#   blender --background --factory-startup --python art/persof1/build_persof1.py -- prepare
#       -> art/persof1/persof1.blend : maillage ressoudé et allégé, à la taille du jeu, textures 2K
#   blender --background art/persof1/persof1.blend --python art/persof1/build_persof1.py -- rig
#       -> squelette identique à celui de Riffald (mêmes 17 os) + pondération, enregistré dans le .blend
# Les animations sont ensuite transférées par art/riffald/retarget_mixamo.py (voir docs/ANIMATIONS.md).
#
# Axes Blender : Z en haut, le personnage regarde vers -Y (devient +Z dans Godot après export glTF).
import bpy, bmesh, math, os, sys
from mathutils import Vector

SRC = r"C:\Users\Ody\OneDrive\Bureau\GODOT\Jeux\Metal Bards\Imagerie\3D\Féminin\persoF1.glb"
HERE = os.path.dirname(os.path.abspath(__file__))
BLEND = os.path.join(HERE, "persof1.blend")
NAME = "PersoF1"
RIG = "PersoF1_rig"
HEIGHT = 1.74  # sommet de la tête (Riffald : 1,84 m)
TARGET_TRIS = 40000
TEX_COLOR = 2048
TEX_OTHER = 1024


def col():
    c = bpy.data.collections.get(NAME)
    if c is None:
        c = bpy.data.collections.new(NAME)
        bpy.context.scene.collection.children.link(c)
    return c


def prepare():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=SRC)
    body = next(o for o in bpy.data.objects if o.type == "MESH")
    # Le générateur découpe le volume en 70 tranches : on les ressoude avant d'alléger.
    bm = bmesh.new()
    bm.from_mesh(body.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bm.to_mesh(body.data)
    bm.free()
    faces = len(body.data.polygons)
    dec = body.modifiers.new("Decimate", "DECIMATE")
    dec.ratio = TARGET_TRIS / max(1, faces)
    dec.use_collapse_triangulate = True
    with bpy.context.temp_override(object=body, active_object=body):
        bpy.ops.object.modifier_apply(modifier=dec.name)
    # À la taille du jeu : pieds au sol, centré.
    body.data.transform(body.matrix_world)
    body.matrix_world.identity()
    vs = [v.co for v in body.data.vertices]
    zmin = min(v.z for v in vs)
    zmax = max(v.z for v in vs)
    cx = (min(v.x for v in vs) + max(v.x for v in vs)) * 0.5
    s = HEIGHT / (zmax - zmin)
    for v in body.data.vertices:
        v.co = Vector(((v.co.x - cx) * s, v.co.y * s, (v.co.z - zmin) * s))
    # Le corps doit être centré en profondeur sur l'axe des hanches (la cape dépasse derrière) :
    # on prend le milieu des vertices du bassin, devant la cape.
    pelvis = [v.co for v in body.data.vertices if 0.85 < v.co.z < 0.95 and abs(v.co.x) < 0.12]
    pelvis.sort(key=lambda p: p.y)
    front, back = pelvis[0].y, pelvis[int(len(pelvis) * 0.6)].y
    cy = (front + back) * 0.5
    for v in body.data.vertices:
        v.co.y -= cy
    body.data.update()
    body.name = NAME
    body.data.name = NAME
    for c in list(body.users_collection):
        c.objects.unlink(body)
    col().objects.link(body)
    for o in list(bpy.data.objects):
        if o != body:
            bpy.data.objects.remove(o, do_unlink=True)
    # Textures 8K -> 2K (couleur) et 1K (métal/rugosité), intégrées au .blend.
    for img in bpy.data.images:
        if img.size[0] == 0:
            continue
        target = TEX_COLOR if _is_color(img) else TEX_OTHER
        if img.size[0] > target:
            img.scale(target, target)
        img.pack()
    mat = body.data.materials[0]
    mat.name = "PF_corps"
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    print("PREPARED faces=%d height=%.3f" % (len(body.data.polygons), HEIGHT))


def _is_color(img):
    for m in bpy.data.materials:
        if not m.node_tree:
            continue
        for n in m.node_tree.nodes:
            if n.type == "TEX_IMAGE" and n.image == img:
                for link in n.outputs["Color"].links:
                    if link.to_node.type == "BSDF_PRINCIPLED" and link.to_socket.name == "Base Color":
                        return True
    return False


# ---------------------------------------------------------------- squelette
# Articulations relevées sur les vues de face et de profil (repère du modèle à 1,74 m), puis recalées
# au centre de la section du membre (voir _snap). (x, y, z) ; .L = côté +X (gauche du personnage).
JOINTS = {
    "hips": (0.0, 0.0, 0.92), "spine": (0.0, 0.0, 1.03), "chest": (0.0, 0.0, 1.19),
    "neck": (0.0, 0.015, 1.40), "head": (0.0, 0.03, 1.50), "head_top": (0.0, 0.03, 1.74),
    "shoulder.L": (0.19, 0.05, 1.35), "elbow.L": (0.265, 0.10, 1.10), "wrist.L": (0.295, 0.04, 0.89),
    "shoulder.R": (-0.19, 0.05, 1.35), "elbow.R": (-0.265, 0.10, 1.10), "wrist.R": (-0.295, 0.04, 0.89),
    "hip.L": (0.09, 0.0, 0.92), "knee.L": (0.14, 0.0, 0.53), "ankle.L": (0.19, 0.06, 0.115),
    "hip.R": (-0.09, 0.0, 0.92), "knee.R": (-0.16, 0.0, 0.53), "ankle.R": (-0.23, 0.06, 0.115),
}
# Joints recalés : rayon de recherche autour de l'estimation (m) et filtre (jambes devant la cape).
SNAP = {"elbow": 0.06, "wrist": 0.06, "ankle": 0.07}
HAND_LEN = 0.085  # poignet -> articulations des doigts (poing fermé)
FOOT_LEN = 0.17  # cheville -> pointe du pied (vers l'avant, -Y)


def _snap(body, name, p):
    """Centre de la section horizontale du membre autour de `p` (vertices à ±1,5 cm de hauteur)."""
    key = name.split(".")[0]
    r = SNAP.get(key)
    if r is None:
        return Vector(p)
    pts = [v.co for v in body.data.vertices
           if abs(v.co.z - p[2]) < 0.015 and (v.co.x - p[0]) ** 2 + (v.co.y - p[1]) ** 2 < r * r
           and (key not in ("knee", "ankle") or v.co.y < 0.10)]
    if len(pts) < 8:
        return Vector(p)
    xs = sorted(q.x for q in pts)
    ys = sorted(q.y for q in pts)
    # milieu de l'enveloppe (robuste aux zones plus denses d'un côté)
    return Vector(((xs[0] + xs[-1]) * 0.5, (ys[0] + ys[-1]) * 0.5, p[2]))


def joints(body):
    j = {n: _snap(body, n, p) for n, p in JOINTS.items()}
    for s in ("L", "R"):
        d = (j["wrist." + s] - j["elbow." + s]).normalized()
        j["knuckles." + s] = j["wrist." + s] + d * HAND_LEN
        sx = 1.0 if s == "L" else -1.0
        j["toe." + s] = j["ankle." + s] + Vector((0.025 * sx, -FOOT_LEN, -0.075))
    return j


def bone_layout(j):
    b = {
        "hips": (j["hips"], j["spine"], None),
        "spine": (j["spine"], j["chest"], "hips"),
        "chest": (j["chest"], j["neck"], "spine"),
        "neck": (j["neck"], j["head"], "chest"),
        "head": (j["head"], j["head_top"], "neck"),
    }
    for s in ("L", "R"):
        side = "." + s
        b["upper_arm" + side] = (j["shoulder" + side], j["elbow" + side], "chest")
        b["forearm" + side] = (j["elbow" + side], j["wrist" + side], "upper_arm" + side)
        b["hand" + side] = (j["wrist" + side], j["knuckles" + side], "forearm" + side)
        b["thigh" + side] = (j["hip" + side], j["knee" + side], "hips")
        b["shin" + side] = (j["knee" + side], j["ankle" + side], "thigh" + side)
        b["foot" + side] = (j["ankle" + side], j["toe" + side], "shin" + side)
    return b


def _seg_dist(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-9)))
    return (a + ab * t - p).length


def _texture_sampler(body):
    """Couleur de la texture de base (sRGB 0..1) au point UV d'un vertex."""
    mat = body.data.materials[0]
    img = None
    for n in mat.node_tree.nodes:
        if n.type == "TEX_IMAGE":
            for link in n.outputs["Color"].links:
                if link.to_node.type == "BSDF_PRINCIPLED" and link.to_socket.name == "Base Color":
                    img = n.image
    w, h = img.size
    px = list(img.pixels[:])
    uv = body.data.uv_layers.active.data
    vcol = {}
    for poly in body.data.polygons:
        for li in poly.loop_indices:
            vi = body.data.loops[li].vertex_index
            if vi in vcol:
                continue
            u, v = uv[li].uv
            x = min(w - 1, max(0, int(u * w)))
            y = min(h - 1, max(0, int(v * h)))
            k = (y * w + x) * 4
            vcol[vi] = (px[k], px[k + 1], px[k + 2])
    return vcol


def _is_cape(co, c):
    """Cape bordeaux : rouge sombre très saturé (les tresses, rousses, sont plus claires et moins saturées),
    sous les épaules, derrière le corps ou sur les côtés."""
    r, g, b = c
    red = r > 0.04 and g < r * 0.45 and b < r * 0.7 and r < 0.55
    return red and co.z < 1.36 and (co.y > 0.02 or abs(co.x) > 0.22)


LIMBS = ("thigh", "shin", "foot", "upper_arm", "forearm", "hand")


def _nearest_bone(p, segs):
    return min(segs, key=lambda bn: _seg_dist(p, *segs[bn]))


def cut_cape(body, segs):
    """Le générateur a soudé la cape au corps par endroits (jambes, poings) : ces ponts s'étireraient
    dès que le membre bouge. On supprime les faces qui relient la cape à une jambe ou à un avant-bras."""
    mask = cape_mask(body, segs)
    bm = bmesh.new()
    bm.from_mesh(body.data)
    bm.verts.ensure_lookup_table()
    # Le classement est gardé dans un attribut : il survit à la découpe (les indices changent).
    layer = bm.verts.layers.int.new("cape")
    for v in bm.verts:
        v[layer] = 1 if mask[v.index] else 0
    limb = {}
    for v in bm.verts:
        if not mask[v.index]:
            limb[v.index] = _nearest_bone(v.co, segs).split(".")[0] in LIMBS
    bridges = []
    for f in bm.faces:
        idx = [v.index for v in f.verts]
        has_cape = any(mask[i] for i in idx)
        has_limb = any(limb.get(i, False) for i in idx)
        if has_cape and has_limb and f.calc_center_median().z < 1.25:
            bridges.append(f)
    bmesh.ops.delete(bm, geom=bridges, context="FACES")
    loose = [v for v in bm.verts if not v.link_faces]
    bmesh.ops.delete(bm, geom=loose, context="VERTS")
    bm.to_mesh(body.data)
    bm.free()
    body.data.update()
    return len(bridges)


def cape_mask(body, segs=None):
    """Vertices de la cape : couleur bordeaux, puis lissage par les voisins (plis clairs de la doublure
    rattrapés, taches isolées sur les bottes ou les épaulières écartées)."""
    colors = _texture_sampler(body)
    me = body.data
    mask = [_is_cape(v.co, colors.get(v.index, (0.5, 0.5, 0.5))) for v in me.vertices]
    for v in me.vertices:
        co = v.co
        if co.z < 0.35 and abs(co.x) < 0.3 and co.y < 0.08:  # bottes
            mask[v.index] = False
    nbrs = [[] for _ in me.vertices]
    for e in me.edges:
        a, b = e.vertices
        nbrs[a].append(b)
        nbrs[b].append(a)
    for _ in range(3):
        new = list(mask)
        for i, ns in enumerate(nbrs):
            if not ns:
                continue
            frac = (sum(mask[n] for n in ns) + mask[i]) / (len(ns) + 1)
            co = me.vertices[i].co
            new[i] = frac >= 0.5 and co.z < 1.36 and (co.y > 0.0 or abs(co.x) > 0.2)
        mask = new
    # Ourlets clairs sur les bords : au-delà des jambes et des poings, à cette hauteur, c'est la cape
    # (sauf le bas des poings, qui descend jusque-là).
    for v in me.vertices:
        co = v.co
        if (co.z < 0.35 and abs(co.x) > 0.33) or (0.35 <= co.z < 0.85 and abs(co.x) > 0.24):
            near_hand = segs is not None and min(_seg_dist(co, *segs[bn]) for bn in
                                                 ("hand.L", "hand.R", "forearm.L", "forearm.R")) < 0.075
            if not near_hand:
                mask[v.index] = True
    if segs is not None:
        arms = [segs[bn] for bn in ("upper_arm.L", "upper_arm.R", "forearm.L", "forearm.R", "hand.L", "hand.R")]
        for v in me.vertices:
            co = v.co
            d_arm = min(_seg_dist(co, *s) for s in arms)
            # Doublure claire de la cape le long des bras : derrière, hors des bras.
            if 1.0 < co.z < 1.25 and co.y > 0.05 and abs(co.x) > 0.19 and d_arm > 0.08:
                mask[v.index] = True
            # À l'inverse, rien sur le bras lui-même n'est de la cape.
            if d_arm < 0.055:
                mask[v.index] = False
    return mask


def _is_back_hair(co):
    """Tresse qui pend dans le dos (au-dessus de la cape) : suit la tête, le cou et le buste seulement."""
    return abs(co.x) < 0.13 and co.y > 0.08 and 0.95 < co.z < 1.55


def _candidates(co, cape):
    if cape:
        return ["hips", "spine", "chest"]
    if _is_back_hair(co):
        return ["head", "neck", "chest"]
    return None  # tous les os


def rig():
    body = bpy.data.objects[NAME]
    for o in list(bpy.data.objects):
        if o.type == "ARMATURE":
            bpy.data.objects.remove(o, do_unlink=True)
    body.vertex_groups.clear()
    for m in list(body.modifiers):
        body.modifiers.remove(m)
    j = joints(body)
    layout = bone_layout(j)
    arm_data = bpy.data.armatures.new(RIG)
    rig_obj = bpy.data.objects.new(RIG, arm_data)
    col().objects.link(rig_obj)
    bpy.context.view_layer.objects.active = rig_obj
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    rig_obj.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    for name, (h, t, parent) in layout.items():
        eb = arm_data.edit_bones.new(name)
        eb.head, eb.tail = Vector(h), Vector(t)
        eb.roll = 0.0
    for name, (h, t, parent) in layout.items():
        if parent:
            eb = arm_data.edit_bones[name]
            eb.parent = arm_data.edit_bones[parent]
            eb.use_connect = (Vector(layout[parent][1]) - Vector(h)).length < 1e-4
    bpy.ops.object.mode_set(mode="OBJECT")
    segs = {n: (Vector(h), Vector(t)) for n, (h, t, p) in layout.items()}
    for bn in segs:
        body.vertex_groups.new(name=bn)
    n_cut = cut_cape(body, segs)
    mask = [d.value == 1 for d in body.data.attributes["cape"].data]
    n_cape = sum(mask)
    print("CUT bridges=%d" % n_cut)
    for v in body.data.vertices:
        p = v.co
        cape = mask[v.index]
        cands = _candidates(p, cape) or list(segs)
        ds = sorted((_seg_dist(p, *segs[bn]), bn) for bn in cands)[:2]
        wts = [1.0 / max(d, 0.01) ** 4 for d, _ in ds]
        tot = sum(wts)
        for (d, bn), wi in zip(ds, wts):
            if wi / tot > 0.02:
                body.vertex_groups[bn].add([v.index], wi / tot, "REPLACE")
    body.parent = rig_obj
    mod = body.modifiers.new("Armature", "ARMATURE")
    mod.object = rig_obj
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    for n in ("shoulder.L", "elbow.L", "wrist.L", "knee.L", "ankle.L", "shoulder.R", "elbow.R", "wrist.R",
              "knee.R", "ankle.R"):
        print("JOINT %-11s %s" % (n, tuple(round(c, 3) for c in j[n])))
    print("RIGGED cape_verts=%d of %d" % (n_cape, len(body.data.vertices)))


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else ["prepare"]
    if args[0] == "prepare":
        prepare()
    elif args[0] == "rig":
        # Os et poids retouchés à la main par Ulysse dans le .blend : rig les effacerait.
        if "force" not in args:
            print("REFUS : Valkyriff a été retouchée à la main dans persof1.blend ; relancer seulement "
                  "l'export, ou « rig force » pour tout recalculer (retouches perdues).")
        else:
            rig()
