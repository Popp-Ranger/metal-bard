# Portes du donjon (et de la taverne) : modèles proposés à Ulysse avant intégration.
#
# Usage (sans interface) :
#   blender --background --factory-startup --python art/portes/build_portes.py
#       -> art/portes/portes.blend (une collection par porte) et assets/models/portes/<porte>.glb
#
# Taille réelle, à l'échelle des héros (Riffald : 1,84 m) : battant simple de 1,0 x 2,1 m environ ;
# double porte (salle du boss) de 1,8 m. Murs du donjon : 2,6 m de haut.
# Repère Blender : Z en haut, la face avant de la porte regarde -Y (devient +Z dans Godot).
# Chaque glb contient « cadre » (pierres autour de l'ouverture, fixe) et « battant » (ou « battant_g » /
# « battant_d ») dont l'origine est sur l'axe des gonds, au sol : le jeu le fait pivoter autour de Z (Y Godot).
import bpy, bmesh, math, os, random
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(ROOT, "assets", "models", "portes")
BLEND = os.path.join(HERE, "portes.blend")
THICK = 0.07  # épaisseur des planches

rng = random.Random(7)


# ------------------------------------------------------------------ matériaux

def material(name, color, rough=0.8, metal=0.0):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    m.diffuse_color = (*color, 1.0)
    return m



# ------------------------------------------------------------------ textures (veinage, grain)

def _image(name, rgb):
    import numpy as np
    h, w = rgb.shape[:2]
    rgba = np.concatenate([np.clip(rgb, 0, 1), np.ones((h, w, 1))], axis=2).astype(np.float32)
    img = bpy.data.images.new(name, w, h)
    img.pixels.foreach_set(rgba.ravel())
    img.pack()
    return img


def wood_texture(name, color, seed):
    """Veinage vertical (fil du bois), ondulé, avec fines stries et quelques nœuds ; 1 m de bois par image."""
    import numpy as np
    r = np.random.default_rng(seed)
    w, h = 256, 512
    x = np.linspace(0, 1, w, endpoint=False)[None, :]
    y = np.linspace(0, 1, h, endpoint=False)[:, None]
    p = r.uniform(0, 6.3, 4)
    warp = 0.012 * np.sin(y * 6.28 * 2 + p[0]) + 0.006 * np.sin(y * 6.28 * 7 + p[1])
    rings = np.sin((x + warp) * 6.28 * 34 + 2.0 * np.sin(x * 6.28 * 3 + p[2]))
    fine = np.repeat(r.normal(0, 1, (1, w)), h, axis=0)
    fine = (fine + np.roll(fine, 1, axis=1) + np.roll(fine, -1, axis=1)) / 3.0
    v = 0.86 + 0.09 * rings + 0.05 * fine + 0.03 * r.normal(0, 1, (h, w))
    for _ in range(3):  # nœuds
        cx, cy = r.uniform(0, 1), r.uniform(0, 1)
        d = np.sqrt(((x - cx) * 4.0) ** 2 + ((y - cy) * 1.2) ** 2)
        v -= 0.25 * np.exp(-(d * 18) ** 2) - 0.06 * np.sin(d * 120) * np.exp(-(d * 8) ** 2)
    rgb = np.clip(v, 0.4, 1.2)[:, :, None] * np.array(color)[None, None, :]
    return _image(name, rgb)


def stone_texture(name, color, seed):
    """Grain de pierre : bruit à plusieurs échelles et petites taches sombres."""
    import numpy as np
    r = np.random.default_rng(seed)
    n = 256
    v = np.zeros((n, n))
    for scale, amp in ((8, 0.12), (32, 0.07), (128, 0.05)):
        base = r.normal(0, 1, (scale, scale))
        v += amp * np.kron(base, np.ones((n // scale, n // scale)))
    v += 0.03 * r.normal(0, 1, (n, n))
    k = np.ones(5) / 5.0
    for _ in range(4):  # flou circulaire (les blocs du bruit grossier disparaissent)
        v = np.apply_along_axis(lambda a: np.convolve(np.concatenate([a[-2:], a, a[:2]]), k, "valid"), 0, v)
        v = np.apply_along_axis(lambda a: np.convolve(np.concatenate([a[-2:], a, a[:2]]), k, "valid"), 1, v)
    v += 0.025 * r.normal(0, 1, (n, n))
    rgb = np.clip(0.9 + v, 0.5, 1.2)[:, :, None] * np.array(color)[None, None, :]
    return _image(name, rgb)


def textured(name, img, rough=0.85):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = 0.0
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    return m

def mats():
    woods = [(0.26, 0.14, 0.065), (0.3, 0.17, 0.08), (0.23, 0.12, 0.055), (0.28, 0.16, 0.075)]
    darks = [(0.12, 0.065, 0.035), (0.15, 0.08, 0.045), (0.105, 0.055, 0.03)]
    return {
        "bois": [textured("P_bois_%d" % i, wood_texture("bois_%d" % i, c, i)) for i, c in enumerate(woods)],
        "bois_sombre": [textured("P_bois_sombre_%d" % i, wood_texture("bois_sombre_%d" % i, c, 10 + i)) for i, c in enumerate(darks)],
        "fer": material("P_fer", (0.09, 0.09, 0.1), 0.45, 0.85),
        "fer_rouille": material("P_fer_rouille", (0.2, 0.11, 0.06), 0.7, 0.5),
        "pierre": textured("P_pierre", stone_texture("pierre", (0.27, 0.26, 0.28), 1), 0.95),
        "pierre_sombre": textured("P_pierre_sombre", stone_texture("pierre_sombre", (0.2, 0.19, 0.21), 2), 0.95),
        "os": material("P_os", (0.62, 0.57, 0.46), 0.6),
        "noir": material("P_noir", (0.01, 0.01, 0.01), 1.0),
    }


# ------------------------------------------------------------------ formes

def _obj(name, me, mat, coll):
    o = bpy.data.objects.new(name, me)
    coll.objects.link(o)
    if mat is not None:
        o.data.materials.append(mat)
    return o


def _bevel(o, w=0.006, seg=2):
    b = o.modifiers.new("Bevel", "BEVEL")
    b.width = w
    b.segments = seg
    b.limit_method = "ANGLE"
    return o


def box(coll, mat, size, loc, rot=(0, 0, 0), bevel=0.006, name="b"):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    bm.to_mesh(me)
    bm.free()
    o = _obj(name, me, mat, coll)
    o.location = loc
    o.rotation_euler = [math.radians(a) for a in rot]
    return _bevel(o, bevel) if bevel > 0 else o


def prism(coll, mat, x0, x1, z0, top0, top1, y0, y1, bevel=0.006, name="p"):
    """Planche verticale de x0 à x1, du sol z0 jusqu'à un bord haut incliné (top0 à gauche, top1 à droite)."""
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    v = [bm.verts.new(p) for p in [
        (x0, y0, z0), (x1, y0, z0), (x1, y0, top1), (x0, y0, top0),
        (x0, y1, z0), (x1, y1, z0), (x1, y1, top1), (x0, y1, top0)]]
    for f in [(0, 1, 2, 3), (5, 4, 7, 6), (4, 0, 3, 7), (1, 5, 6, 2), (3, 2, 6, 7), (4, 5, 1, 0)]:
        bm.faces.new([v[i] for i in f])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    return _bevel(_obj(name, me, mat, coll), bevel)


def cyl(coll, mat, r, depth, loc, rot=(90, 0, 0), verts=12, name="c", r2=None):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=verts, radius1=r, radius2=r if r2 is None else r2, depth=depth)
    bm.to_mesh(me)
    bm.free()
    o = _obj(name, me, mat, coll)
    o.location = loc
    o.rotation_euler = [math.radians(a) for a in rot]
    return o


def torus(coll, mat, major, minor, loc, rot=(90, 0, 0), name="t"):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, major_segments=20, minor_segments=8,
                                     location=loc, rotation=[math.radians(a) for a in rot])
    o = bpy.context.active_object
    o.name = name
    for c in list(o.users_collection):
        c.objects.unlink(o)
    coll.objects.link(o)
    o.data.materials.append(mat)
    return o


def stud(coll, m, x, z, y, r=0.018):
    """Clou forgé à tête bombée sur la face avant (-Y)."""
    return cyl(coll, m["fer"], r, 0.02, (x, y - 0.008, z), verts=8, r2=r * 0.55)


def join(objs, name, origin=(0, 0, 0)):
    """Fusionne les pièces (modificateurs appliqués) en un seul objet, origine sur `origin`."""
    deps = bpy.context.evaluated_depsgraph_get()
    bm = bmesh.new()
    mats_list = []
    for o in objs:
        ev = o.evaluated_get(deps)
        me = ev.to_mesh()
        me.transform(o.matrix_world)
        offset = len(mats_list)
        for mt in o.data.materials:
            mats_list.append(mt)
        tmp = bmesh.new()
        tmp.from_mesh(me)
        for f in tmp.faces:
            f.material_index += offset
        tmp_me = bpy.data.meshes.new("tmp")
        tmp.to_mesh(tmp_me)
        tmp.free()
        bm.from_mesh(tmp_me)
        bpy.data.meshes.remove(tmp_me)
        ev.to_mesh_clear()
    coll = objs[0].users_collection[0]
    for o in objs:
        bpy.data.objects.remove(o, do_unlink=True)
    # UV en projection cubique dans le repère du monde (1 m = une image de texture) : le fil du bois
    # reste vertical sur les faces avant et arrière.
    uv = bm.loops.layers.uv.get("UVMap") or bm.loops.layers.uv.new("UVMap")
    for extra in [l for l in bm.loops.layers.uv.keys() if l != "UVMap"]:
        bm.loops.layers.uv.remove(bm.loops.layers.uv[extra])
    for f in bm.faces:
        n = f.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        for lp in f.loops:
            co = lp.vert.co
            lp[uv].uv = (co.x, co.y) if ax == 2 else ((co.y, co.z) if ax == 0 else (co.x, co.z))
    me = bpy.data.meshes.new(name)
    bm.transform(Matrix.Translation(-Vector(origin)))
    bm.to_mesh(me)
    bm.free()
    # Matériaux dédoublonnés.
    uniq = []
    remap = []
    for mt in mats_list:
        if mt not in uniq:
            uniq.append(mt)
        remap.append(uniq.index(mt))
    for p in me.polygons:
        p.material_index = remap[p.material_index]
    for mt in uniq:
        me.materials.append(mt)
    for p in me.polygons:
        p.use_smooth = False
    o = bpy.data.objects.new(name, me)
    coll.objects.link(o)
    o.location = origin
    return o


# ------------------------------------------------------------------ éléments communs

def planks(coll, m, x0, width, n, height_at, y_front=-THICK * 0.5, dark=False, gap=0.006):
    """n planches verticales jointives de x0 à x0 + width ; height_at(x) donne le haut du battant."""
    parts = []
    w = width / n
    pal = m["bois_sombre"] if dark else m["bois"]
    for i in range(n):
        a = x0 + i * w + gap * 0.5
        b = x0 + (i + 1) * w - gap * 0.5
        parts.append(prism(coll, pal[rng.randrange(len(pal))], a, b, 0.0, height_at(a), height_at(b),
                           y_front, y_front + THICK, name="planche"))
    # Joints sombres entre les planches (on voit le fond).
    parts.append(box(coll, m["noir"], (width - 0.02, 0.01, min(height_at(x0), height_at(x0 + width)) - 0.04),
                     (x0 + width * 0.5, y_front + THICK * 0.5, (min(height_at(x0), height_at(x0 + width)) - 0.04) * 0.5),
                     bevel=0, name="fond"))
    return parts


def strap(coll, m, x0, x1, z, y, h=0.055, studs=True, tip=True):
    """Penture de fer forgé (bande horizontale cloutée), bout arrondi côté opposé aux gonds."""
    parts = [box(coll, m["fer"], (abs(x1 - x0), 0.012, h), ((x0 + x1) * 0.5, y - 0.006, z), bevel=0.003, name="penture")]
    if tip:
        parts.append(cyl(coll, m["fer"], h * 0.75, 0.012, (x1, y - 0.006, z), verts=16, name="bout"))
    if studs:
        k = max(2, int(abs(x1 - x0) / 0.16))
        for i in range(k + 1):
            parts.append(stud(coll, m, x0 + (x1 - x0) * (0.06 + 0.88 * i / k), z, y - 0.012, 0.012))
    return parts


def ring_pull(coll, m, x, z, y):
    return [cyl(coll, m["fer"], 0.045, 0.015, (x, y - 0.007, z), verts=16, name="platine"),
            torus(coll, m["fer"], 0.06, 0.009, (x, y - 0.03, z - 0.06), rot=(90, 0, 0), name="anneau")]


def keyhole(coll, m, x, z, y):
    return [box(coll, m["fer"], (0.07, 0.01, 0.12), (x, y - 0.005, z), bevel=0.004, name="serrure"),
            box(coll, m["noir"], (0.014, 0.012, 0.04), (x, y - 0.008, z), bevel=0, name="trou")]


def stone_jambs(coll, m, half, top, depth=0.5, jamb=0.24, lintel=0.3, rough=True):
    """Montants et linteau de pierre autour d'une ouverture rectangulaire (largeur 2*half, hauteur top)."""
    parts = []
    z = 0.0
    k = 0
    while z < top - 0.01:
        hgt = min(0.32 + rng.uniform(-0.05, 0.06), top - z)
        for s in (-1, 1):
            w = jamb + (0.05 if (k + (s > 0)) % 2 else 0.0)
            parts.append(box(coll, m["pierre"] if rng.random() > 0.3 else m["pierre_sombre"],
                             (w - 0.012, depth + rng.uniform(0, 0.03), hgt - 0.012),
                             (s * (half + w * 0.5), 0, z + hgt * 0.5), bevel=0.02, name="pierre"))
        z += hgt
        k += 1
    w = half * 2 + jamb * 2 + 0.1
    parts.append(box(coll, m["pierre"], (w, depth + 0.04, lintel), (0, 0, top + lintel * 0.5), bevel=0.025, name="linteau"))
    return parts


def stone_arch(coll, m, half, spring, depth=0.5, ring=0.26, n=11, keystone_mat=None):
    """Montants jusqu'à `spring` puis arc en plein cintre de voussoirs (rayon intérieur = half)."""
    parts = stone_jambs(coll, m, half, spring, depth, jamb=ring, lintel=0.0)
    bpy.data.objects.remove(parts.pop(), do_unlink=True)  # pas de linteau : l'arc le remplace
    for i in range(n):
        a0 = math.pi * i / n
        a1 = math.pi * (i + 1) / n
        r0, r1 = half, half + ring + (0.04 if i == n // 2 else 0.0)
        me = bpy.data.meshes.new("voussoir")
        bm = bmesh.new()
        g = 0.006
        pts = []
        for (r, a) in [(r0, a0 + g), (r1, a0 + g), (r1, a1 - g), (r0, a1 - g)]:
            pts.append((math.cos(a) * r, math.sin(a) * r + spring))
        vs = [bm.verts.new((x, -depth * 0.5, z)) for x, z in pts] + [bm.verts.new((x, depth * 0.5, z)) for x, z in pts]
        for f in [(0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]:
            bm.faces.new([vs[j] for j in f])
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(me)
        bm.free()
        mt = keystone_mat if (keystone_mat is not None and i == n // 2) else (m["pierre"] if i % 2 else m["pierre_sombre"])
        parts.append(_bevel(_obj("voussoir", me, mt, coll), 0.015))
    return parts


def new_coll(name):
    c = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(c)
    return c


# ------------------------------------------------------------------ les portes

W = 1.0    # largeur d'un battant simple
H = 2.1    # hauteur d'un battant rectangulaire


def porte_cachot(m):
    """1. Porte de cachot : planches de chêne, deux longues pentures cloutées, anneau et serrure, linteau de pierre."""
    c = new_coll("cachot")
    leaf = planks(c, m, 0.0, W, 6, lambda x: H)
    yf = -THICK * 0.5
    for z in (0.35, H - 0.35):
        leaf += strap(c, m, 0.02, W * 0.82, z, yf)
    leaf += ring_pull(c, m, W - 0.15, 1.0, yf)
    leaf += keyhole(c, m, W - 0.15, 1.18, yf)
    # Traverses au dos.
    for z in (0.35, H - 0.35):
        leaf.append(box(c, m["bois_sombre"][0], (W - 0.06, 0.04, 0.12), (W * 0.5, -yf + 0.02, z), name="traverse"))
    battant = join(leaf, c.name + "_battant", (0, 0, 0))
    battant.location = (-W * 0.5, 0, 0)
    cadre = join(stone_jambs(c, m, W * 0.5 + 0.02, H + 0.02), c.name + "_cadre")
    return c


def porte_voutee(m):
    """2. Porte voûtée : battant en plein cintre, clous en quinconce, arc de voussoirs."""
    c = new_coll("voutee")
    r = W * 0.5
    spring = 1.75

    def top(x):
        dx = min(r, abs(x - r))
        return spring + math.sqrt(max(0.0, r * r - dx * dx))
    leaf = planks(c, m, 0.0, W, 7, top)
    yf = -THICK * 0.5
    for z in (0.3, 1.45):
        leaf += strap(c, m, 0.02, W * 0.85, z, yf, studs=False)
    for row, z in enumerate([0.6, 0.85, 1.1]):
        for i in range(5):
            x = 0.14 + i * 0.18 + (0.09 if row % 2 else 0.0)
            if x < W - 0.08:
                leaf.append(stud(c, m, x, z, yf, 0.016))
    leaf += ring_pull(c, m, W - 0.16, 1.0, yf)
    for z in (0.3, 1.45):
        leaf.append(box(c, m["bois_sombre"][0], (W - 0.06, 0.04, 0.12), (W * 0.5, -yf + 0.02, z), name="traverse"))
    battant = join(leaf, c.name + "_battant", (0, 0, 0))
    battant.location = (-W * 0.5, 0, 0)
    cadre = join(stone_arch(c, m, r + 0.02, spring), c.name + "_cadre")
    return c


def porte_crypte(m):
    """3. Porte de crypte : planches sombres en Z, cerclage de fer, judas à barreaux, gros verrous."""
    c = new_coll("crypte")
    leaf = planks(c, m, 0.0, W, 5, lambda x: H, dark=True)
    yf = -THICK * 0.5
    # Cadre de fer tout autour + écharpe en Z.
    leaf.append(box(c, m["fer"], (W, 0.014, 0.06), (W * 0.5, yf - 0.007, H - 0.03), bevel=0.003, name="cercle"))
    leaf.append(box(c, m["fer"], (W, 0.014, 0.06), (W * 0.5, yf - 0.007, 0.03), bevel=0.003, name="cercle"))
    for x in (0.03, W - 0.03):
        leaf.append(box(c, m["fer"], (0.06, 0.014, H), (x, yf - 0.007, H * 0.5), bevel=0.003, name="cercle"))
    for z in (0.5, 1.45):
        leaf.append(box(c, m["bois"][2], (W - 0.1, 0.045, 0.13), (W * 0.5, yf - 0.02, z), bevel=0.008, name="barre"))
    ang = math.degrees(math.atan2(1.45 - 0.5, W - 0.2))
    leaf.append(box(c, m["bois"][2], (math.hypot(W - 0.2, 0.95), 0.045, 0.12), (W * 0.5, yf - 0.02, 0.975),
                    rot=(0, -ang, 0), bevel=0.008, name="echarpe"))
    for x in (0.03, W - 0.03):
        for z in (0.03, 0.5, 1.0, 1.45, H - 0.03):
            leaf.append(stud(c, m, x, z, yf - 0.014, 0.017))
    # Judas : ouverture sombre et trois barreaux.
    jz = 1.72
    leaf.append(box(c, m["noir"], (0.26, 0.02, 0.18), (W * 0.5, yf - 0.002, jz), bevel=0, name="judas"))
    leaf.append(box(c, m["fer"], (0.3, 0.016, 0.22), (W * 0.5, yf - 0.012, jz), bevel=0.003, name="judas_cadre"))
    leaf.append(box(c, m["noir"], (0.26, 0.03, 0.18), (W * 0.5, yf - 0.012, jz), bevel=0, name="judas_trou"))
    for i in range(3):
        leaf.append(cyl(c, m["fer"], 0.01, 0.2, (W * 0.5 - 0.08 + i * 0.08, yf - 0.03, jz), rot=(0, 0, 0), verts=8, name="barreau"))
    # Verrou à glissière et poignée.
    leaf.append(box(c, m["fer_rouille"], (0.3, 0.03, 0.05), (W - 0.2, yf - 0.03, 1.05), bevel=0.005, name="verrou"))
    leaf.append(cyl(c, m["fer_rouille"], 0.02, 0.08, (W - 0.24, yf - 0.06, 1.05), rot=(90, 0, 0), verts=8, name="tirette"))
    leaf += ring_pull(c, m, W - 0.16, 0.9, yf - 0.014)
    battant = join(leaf, c.name + "_battant", (0, 0, 0))
    battant.location = (-W * 0.5, 0, 0)
    cadre = join(stone_jambs(c, m, W * 0.5 + 0.02, H + 0.02, jamb=0.28, lintel=0.34), c.name + "_cadre")
    return c


def porte_boss(m):
    """4. Salle du boss : grande double porte voûtée, bois noirci, fer à pointes, crâne cornu, heurtoirs."""
    c = new_coll("boss")
    half = 0.9          # chaque battant fait 0,9 m : ouverture de 1,8 m
    spring = 1.3
    R = half            # arc en plein cintre au-dessus des deux battants (sommet à 2,45 m)
    yf = -THICK * 0.5
    leaves = []
    for side in (-1, 1):
        # Battant de x=0 (gonds) vers le centre ; on le construit vers +X puis on le retourne pour la gauche.
        def top(x, side=side):
            # x : distance aux gonds (0..half) ; le centre de l'arc est au milieu des deux battants.
            dx = half - x
            return spring + math.sqrt(max(0.0, R * R - dx * dx))
        leaf = planks(c, m, 0.0, half, 6, top, dark=True)
        for z in (0.35, 1.0):
            leaf += strap(c, m, 0.02, half * 0.92, z, yf, h=0.07)
        for i in range(3):
            leaf.append(cyl(c, m["fer"], 0.022, 0.07, (0.15 + i * 0.25, yf - 0.04, 1.55), verts=8, r2=0.0, name="pointe"))
        leaf.append(box(c, m["fer"], (half * 0.9, 0.012, 0.06), (half * 0.47, yf - 0.006, 1.55), bevel=0.003, name="bande"))
        leaf.append(cyl(c, m["fer"], 0.05, 0.015, (half - 0.2, yf - 0.007, 1.15), verts=16, name="platine"))
        leaf.append(torus(c, m["fer"], 0.09, 0.013, (half - 0.2, yf - 0.035, 1.05), rot=(90, 0, 0), name="heurtoir"))
        leaf.append(box(c, m["bois_sombre"][0], (half - 0.06, 0.04, 0.14), (half * 0.5, -yf + 0.02, 0.35), name="traverse"))
        leaf.append(box(c, m["bois_sombre"][0], (half - 0.06, 0.04, 0.14), (half * 0.5, -yf + 0.02, 1.0), name="traverse"))
        o = join(leaf, c.name + ("_battant_d" if side > 0 else "_battant_g"), (0, 0, 0))
        if side > 0:
            # Battant droit : miroir (gonds à droite, il s'étend vers le centre, -X).
            o.data.transform(Matrix.Scale(-1, 4, (1, 0, 0)))
            o.data.flip_normals()
        o.location = (side * half, 0, 0)
        leaves.append(o)
    # Crâne cornu sur la clé de voûte.
    cadre_parts = stone_arch(c, m, half + 0.02, spring, ring=0.25, n=13, keystone_mat=m["pierre_sombre"])
    kz = spring + half + 0.15
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.13, location=(0, -0.3, kz), segments=16, ring_count=10)
    skull = bpy.context.active_object
    skull.scale = (1.0, 0.85, 1.05)
    for cl in list(skull.users_collection):
        cl.objects.unlink(skull)
    c.objects.link(skull)
    skull.data.materials.append(m["os"])
    cadre_parts.append(skull)
    for s in (-1, 1):
        cadre_parts.append(cyl(c, m["noir"], 0.032, 0.03, (s * 0.05, -0.41, kz + 0.02), verts=10, name="orbite"))
        cadre_parts.append(cyl(c, m["os"], 0.035, 0.22, (s * 0.15, -0.28, kz + 0.1), rot=(0, s * 55, 0), verts=8, r2=0.004, name="corne"))
    cadre_parts.append(box(c, m["noir"], (0.03, 0.02, 0.04), (0, -0.41, kz - 0.05), bevel=0, name="nez"))
    join(cadre_parts, c.name + "_cadre")
    return c



def porte_ouverture(m):
    """1 bis. Simple ouverture : le cadre de pierre de la porte de cachot, sans battant."""
    c = new_coll("ouverture")
    rng.seed(7)
    join(stone_jambs(c, m, W * 0.5 + 0.02, H + 0.02), c.name + "_cadre")
    return c


def sphere(coll, mat, r, loc, scale=(1, 1, 1), rot=(0, 0, 0), name="s", seg=16):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=loc, segments=seg, ring_count=max(6, seg // 2),
                                         rotation=[math.radians(a) for a in rot])
    o = bpy.context.active_object
    o.name = name
    o.scale = scale
    for cl in list(o.users_collection):
        cl.objects.unlink(o)
    coll.objects.link(o)
    o.data.materials.append(mat)
    return o


def tube(coll, mat, pts, radii, name="tube", seg=10):
    """Tube le long des points `pts`, rayon `radii` à chaque point (corne, barbe...). Repère transporté
    d'un anneau à l'autre (pas de vrille quand la courbe tourne)."""
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    rings = []
    a = None
    for i, (p, r) in enumerate(zip(pts, radii)):
        p = Vector(p)
        d = (Vector(pts[min(i + 1, len(pts) - 1)]) - Vector(pts[max(i - 1, 0)])).normalized()
        a = d.orthogonal().normalized() if a is None else (a - d * a.dot(d)).normalized()
        b = d.cross(a).normalized()
        rings.append([bm.verts.new(p + (a * math.cos(k * math.tau / seg) + b * math.sin(k * math.tau / seg)) * r)
                      for k in range(seg)])
    for i in range(len(rings) - 1):
        for k in range(seg):
            bm.faces.new([rings[i][k], rings[i][(k + 1) % seg], rings[i + 1][(k + 1) % seg], rings[i + 1][k]])
    bm.faces.new(list(reversed(rings[0])))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    return _obj(name, me, mat, coll)


def shield(coll, mat, x, y0, y1, top, mid, tip, half):
    """Écusson de bois en forme de blason : bord droit en haut, pointe en bas."""
    me = bpy.data.meshes.new("ecusson")
    bm = bmesh.new()
    outline = [(-half, top), (half, top), (half, mid), (0.0, tip), (-half, mid)]
    front = [bm.verts.new((x + px, y0, pz)) for px, pz in outline]
    back = [bm.verts.new((x + px, y1, pz)) for px, pz in outline]
    bm.faces.new(front)
    bm.faces.new(list(reversed(back)))
    n = len(outline)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new([front[i], back[i], back[j], front[j]])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    return _bevel(_obj("ecusson", me, mat, coll), 0.015)


def goat_head(c, m, base):
    """Tête de chèvre en trophée sur un écusson de bois (face avant vers -Y) : tête allongée qui avance et
    pique du nez, oreilles tombantes, cornes qui partent vers l'arrière, barbiche sous le menton."""
    fur = textured("P_chevre", stone_texture("chevre", (0.32, 0.26, 0.19), 21), 0.95)
    fur_dark = textured("P_chevre_sombre", stone_texture("chevre_sombre", (0.15, 0.12, 0.09), 22), 0.95)
    horn = textured("P_corne", wood_texture("corne", (0.17, 0.14, 0.11), 23), 0.55)
    x, y, z = base
    parts = [shield(c, m["bois_sombre"][1], x, y - 0.03, y + 0.03, z + 0.24, z - 0.18, z - 0.46, 0.25)]
    hy = y - 0.1
    # Crâne, puis chanfrein et museau qui descendent vers l'avant.
    parts.append(sphere(c, fur, 0.1, (x, hy, z + 0.02), scale=(1.0, 1.0, 1.15), name="crane"))
    parts.append(sphere(c, fur, 0.075, (x, hy - 0.1, z - 0.07), scale=(0.95, 1.7, 0.9), rot=(-40, 0, 0), name="chanfrein"))
    parts.append(sphere(c, fur, 0.058, (x, hy - 0.2, z - 0.16), scale=(1.0, 1.1, 0.9), name="museau"))
    parts.append(sphere(c, fur_dark, 0.028, (x, hy - 0.25, z - 0.15), scale=(1.4, 0.6, 0.7), name="nez"))
    for s in (-1, 1):
        parts.append(sphere(c, m["noir"], 0.016, (x + s * 0.07, hy - 0.07, z + 0.03), name="oeil"))
        parts.append(sphere(c, fur_dark, 0.04, (x + s * 0.14, hy - 0.01, z - 0.01), scale=(2.0, 0.45, 0.75),
                            rot=(0, s * 35, 0), name="oreille"))
        pts, radii = [], []
        for i in range(14):
            t = i / 13
            a = t * 2.5
            pts.append((x + s * (0.04 + 0.12 * t), hy + 0.02 + 0.2 * (1 - math.cos(a)), z + 0.1 + 0.2 * math.sin(a)))
            radii.append(0.03 * (1 - t) + 0.004)
        parts.append(tube(c, horn, pts, radii, name="corne"))
    # Barbiche sous le menton.
    parts.append(tube(c, fur_dark, [(x, hy - 0.2, z - 0.2), (x, hy - 0.21, z - 0.27), (x, hy - 0.19, z - 0.36)],
                      [0.03, 0.022, 0.004], name="barbe"))
    return parts


def wedge(coll, mat, x0, x1, z0a, z0b, z1a, z1b, y0, y1, name="w"):
    """Bloc dont le dessous va de (x0, z0a) à (x1, z0b) et le dessus de (x0, z1a) à (x1, z1b)."""
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    pts = [(x0, z0a), (x1, z0b), (x1, z1b), (x0, z1a)]
    vs = [bm.verts.new((px, y0, pz)) for px, pz in pts] + [bm.verts.new((px, y1, pz)) for px, pz in pts]
    for fc in [(0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]:
        bm.faces.new([vs[j] for j in fc])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    return _bevel(_obj(name, me, mat, coll), 0.012)


def porte_taverne(m):
    """5. Entrée de la taverne : double porte voûtée tout en bois (chevilles, poignées et barres de bois),
    cadre de poutres, panneaux de planches à hauteur du muret (ouverture de 4 m), tête de chèvre au-dessus."""
    c = new_coll("taverne")
    half = 1.25          # battants de 1,25 m : passage de 2,5 m
    spring = 2.0
    rise = 0.32          # arc surbaissé : sommet à 2,32 m
    R = (half * half + rise * rise) / (2 * rise)
    yf = -THICK * 0.5

    def arc_z(dx):
        return spring + rise - (R - math.sqrt(max(0.0, R * R - dx * dx)))
    for side in (-1, 1):
        leaf = planks(c, m, 0.0, half, 7, lambda x: arc_z(half - x))
        for z in (0.4, 1.6):
            leaf.append(box(c, m["bois_sombre"][0], (half * 0.94, 0.03, 0.13), (half * 0.5, yf - 0.015, z), bevel=0.008, name="barre"))
            for i in range(6):
                leaf.append(cyl(c, m["bois"][3], 0.016, 0.02, (0.1 + i * 0.2, yf - 0.035, z), verts=8, name="cheville"))
        ang = math.degrees(math.atan2(1.2, half * 0.8))
        leaf.append(box(c, m["bois_sombre"][1], (math.hypot(half * 0.8, 1.2), 0.03, 0.11), (half * 0.5, yf - 0.015, 1.0),
                        rot=(0, -ang, 0), bevel=0.008, name="echarpe"))
        # Poignée de bois (anse) près du centre.
        leaf.append(box(c, m["bois_sombre"][2], (0.05, 0.05, 0.3), (half - 0.16, yf - 0.07, 1.05), bevel=0.012, name="poignee"))
        for dz in (-0.13, 0.13):
            leaf.append(box(c, m["bois_sombre"][2], (0.04, 0.06, 0.04), (half - 0.16, yf - 0.035, 1.05 + dz), bevel=0.006, name="tenon"))
        for z in (0.4, 1.6):
            leaf.append(box(c, m["bois_sombre"][0], (half - 0.06, 0.04, 0.12), (half * 0.5, -yf + 0.02, z), name="traverse"))
        o = join(leaf, c.name + ("_battant_d" if side > 0 else "_battant_g"), (0, 0, 0))
        if side > 0:
            o.data.transform(Matrix.Scale(-1, 4, (1, 0, 0)))
            o.data.flip_normals()
        o.location = (side * half, 0, 0)
    # Cadre : poteaux, arc de bois en segments, panneaux de planches à hauteur du muret jusqu'à ±2 m.
    frame = []
    post = 0.24
    edge = half + post + 0.01
    panel_w = 2.0 - edge
    for s in (-1, 1):
        frame.append(box(c, m["bois_sombre"][0], (post, 0.34, spring + 0.1), (s * (half + post * 0.5 + 0.01), 0, (spring + 0.1) * 0.5),
                         bevel=0.015, name="poteau"))
        frame.append(box(c, m["bois_sombre"][1], (post + 0.06, 0.38, 0.12), (s * (half + post * 0.5 + 0.01), 0, 0.06), bevel=0.01, name="socle"))
        for i in range(3):
            pw = panel_w / 3
            x0 = s * edge + (i * pw if s > 0 else -(i + 1) * pw)
            frame.append(prism(c, m["bois"][rng.randrange(4)], x0 + 0.003, x0 + pw - 0.003, 0.0, 0.9, 0.9, -0.05, 0.05, name="panneau"))
        frame.append(box(c, m["bois_sombre"][1], (panel_w, 0.16, 0.08), (s * (edge + panel_w * 0.5), 0, 0.94), bevel=0.01, name="lisse"))

    def zin(x):
        return arc_z(abs(x)) if abs(x) <= half else spring + 0.1
    n = 9
    for i in range(n):
        x0 = -edge + 2 * edge * i / n
        x1 = -edge + 2 * edge * (i + 1) / n
        za, zb = zin(x0), zin(x1)
        frame.append(wedge(c, m["bois_sombre"][i % 3], x0 + 0.004, x1 - 0.004, za, zb, za + 0.26, zb + 0.26, -0.17, 0.17, name="arc"))
    frame += goat_head(c, m, (0, -0.17, spring + rise + 0.62))
    join(frame, c.name + "_cadre")
    return c

def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    m = mats()
    os.makedirs(OUT, exist_ok=True)
    for build in (porte_cachot, porte_voutee, porte_crypte, porte_boss, porte_ouverture, porte_taverne):
        coll = build(m)
        for o in bpy.data.objects:
            o.select_set(False)
        for o in coll.objects:
            o.select_set(True)
        path = os.path.join(OUT, coll.name + ".glb")
        bpy.ops.export_scene.gltf(filepath=path, use_selection=True, export_apply=True, export_yup=True)
        dims = [tuple(round(v, 2) for v in o.dimensions) for o in coll.objects]
        print("PORTE", coll.name, [o.name for o in coll.objects], dims)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)


main()
