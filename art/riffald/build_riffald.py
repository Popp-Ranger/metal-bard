# Riffald — construction procédurale du modèle 3D (Blender 5.2), v2 calée sur la planche 3D.
# Référence : docs/concept/riffald_planche2_3d.jpg (face, dos, profil ; pose A).
# Mesures relevées sur la planche à 350 px/m (compare.py superpose le modèle à la planche).
# Axes Blender : Z en haut, le personnage regarde vers -Y (devient +Z dans Godot après export glTF).
# Chaque pièce porte une propriété "bone" (os de rattachement pour le rig).
#
# Usage dans Blender : exec(open(PATH).read()) puis build_all() ; build_rig() ; export_glb(path).
import bpy, bmesh, math, random
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

COL_NAME = "Riffald"
COL = None
MATS = {}
LISSE = None  # buste lisse (sans encolure) servant de support aux sangles et aux revers


# ---------------------------------------------------------------- utilitaires
def reset():
    global COL
    COL = bpy.data.collections.get(COL_NAME)
    if COL is None:
        COL = bpy.data.collections.new(COL_NAME)
        bpy.context.scene.collection.children.link(COL)
    for o in list(COL.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for me in list(bpy.data.meshes):
        if me.users == 0:
            bpy.data.meshes.remove(me)
    for a in list(bpy.data.armatures):
        if a.users == 0:
            bpy.data.armatures.remove(a)
    cube = bpy.data.objects.get("Cube")
    if cube:
        bpy.data.objects.remove(cube, do_unlink=True)


def col():
    global COL
    if COL is None or COL.name not in bpy.data.collections:
        COL = bpy.data.collections.get(COL_NAME)
        if COL is None:
            reset()
    return COL


def srgb_to_lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def mat(name, srgb, rough=0.6, metal=0.0, emit=0.0):
    """Couleurs données en sRGB (valeurs lues sur la planche), converties en linéaire."""
    lin = tuple(srgb_to_lin(c) for c in srgb)
    key = "MB_" + name
    m = bpy.data.materials.get(key) or bpy.data.materials.new(key)
    try:
        m.use_nodes = True
    except Exception:
        pass
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = (*lin, 1.0)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    b.inputs["Emission Strength"].default_value = emit
    if emit > 0:
        b.inputs["Emission Color"].default_value = (*lin, 1.0)
    m.diffuse_color = (*lin, 1.0)
    m.metallic = metal
    m.roughness = rough
    MATS[name] = m
    return m


def materials():
    mat("cuir", (0.15, 0.13, 0.14), 0.45)
    mat("cuir_use", (0.23, 0.21, 0.23), 0.5)
    mat("sangle", (0.55, 0.34, 0.22), 0.6)
    mat("metal", (0.26, 0.27, 0.33), 0.35, 0.45)
    mat("metal_bord", (0.60, 0.61, 0.67), 0.3, 0.55)
    mat("argent", (0.76, 0.74, 0.74), 0.25, 0.9)
    mat("peau", (0.98, 0.72, 0.55), 0.55)
    mat("cheveux", (0.97, 0.47, 0.15), 0.45)
    mat("cheveux_ombre", (0.80, 0.28, 0.08), 0.6)
    mat("sourcils", (0.70, 0.30, 0.10), 0.7)
    mat("paupiere", (0.36, 0.18, 0.12), 0.7)
    mat("cape", (0.38, 0.10, 0.17), 0.8)
    mat("maillot", (0.50, 0.12, 0.16), 0.6, 0.0, 0.15)
    mat("gemme", (0.95, 0.10, 0.18), 0.15, 0.0, 3.0)
    mat("oeil", (0.90, 0.88, 0.85), 0.4)
    mat("iris", (0.14, 0.09, 0.07), 0.3)
    mat("bouche", (0.45, 0.20, 0.16), 0.6)


def add(name, verts, faces, m, bone, smooth=True):
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in verts], [], faces)
    me.update()
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(MATS[m])
    for p in me.polygons:
        p.use_smooth = smooth
    o = bpy.data.objects.new(name, me)
    col().objects.link(o)
    o["bone"] = bone
    return o


def sname(name, s):
    return name + (".L" if s > 0 else ".R")


def spow(v, e):
    return math.copysign(abs(v) ** e, v)


def frame(t, ref=None):
    t = t.normalized()
    if ref is None:
        ref = Vector((0, 1, 0)) if abs(t.y) < 0.9 else Vector((1, 0, 0))
    x = ref.cross(t).normalized()
    y = t.cross(x).normalized()
    return x, y


def ring_pts(c, x, y, rx, ry, segs, p=2.0, ry_b=None):
    """Anneau superelliptique ; ry côté -y (l'avant pour un anneau vertical), ry_b côté +y (le dos)."""
    e = 2.0 / p
    pts = []
    for k in range(segs):
        a = 2 * math.pi * k / segs
        ca, sa = math.cos(a), math.sin(a)
        r_y = ry if (sa < 0 or ry_b is None) else ry_b
        pts.append(c + x * spow(ca, e) * rx + y * spow(sa, e) * r_y)
    return pts


def loft(name, secs, m, bone, segs=16, p=2.0, caps=(True, True), ref=None, smooth=True):
    """secs : (centre, rx, ry) ou (centre, rx, ry_avant, ry_dos). Sections perpendiculaires au trajet."""
    cs = [Vector(s[0]) for s in secs]
    verts, faces = [], []
    n = len(secs)
    for i, s in enumerate(secs):
        t = cs[min(i + 1, n - 1)] - cs[max(i - 1, 0)]
        x, y = frame(t, ref)
        verts += ring_pts(cs[i], x, y, s[1], s[2], segs, p, s[3] if len(s) > 3 else None)
    for i in range(n - 1):
        for k in range(segs):
            a = i * segs + k
            b = i * segs + (k + 1) % segs
            faces.append((a, b, b + segs, a + segs))
    if caps[0]:
        verts.append(cs[0])
        c = len(verts) - 1
        for k in range(segs):
            faces.append((c, (k + 1) % segs, k))
    if caps[1]:
        verts.append(cs[-1])
        c = len(verts) - 1
        base = (n - 1) * segs
        for k in range(segs):
            faces.append((c, base + k, base + (k + 1) % segs))
    return add(name, verts, faces, m, bone, smooth)


def ellipsoid(name, loc, scale, m, bone, segs=16, rings=10, rot=None, smooth=True, p=2.0, cap=None):
    """Superellipsoïde (p=2 : ellipsoïde). cap=angle (rad) : calotte ouverte en bas (coque)."""
    e = 2.0 / p
    verts, faces = [], []
    n_ring = rings - 1 if cap is None else rings
    for r in range(1, n_ring + 1):
        th = (math.pi if cap is None else cap) * r / rings
        st, ct = math.sin(th), math.cos(th)
        for k in range(segs):
            ph = 2 * math.pi * k / segs
            verts.append(Vector((spow(st, e) * spow(math.cos(ph), e), spow(st, e) * spow(math.sin(ph), e),
                                 spow(ct, e))))
    verts.append(Vector((0, 0, 1)))
    top = len(verts) - 1
    for r in range(n_ring - 1):
        for k in range(segs):
            a = r * segs + k
            b = r * segs + (k + 1) % segs
            faces.append((a, b, b + segs, a + segs))
    for k in range(segs):
        faces.append((top, (k + 1) % segs, k))
    if cap is None:
        verts.append(Vector((0, 0, -1)))
        bot = len(verts) - 1
        base = (n_ring - 1) * segs
        for k in range(segs):
            faces.append((bot, base + k, base + (k + 1) % segs))
    R = rot if rot is not None else Matrix.Identity(3)
    vs = [Vector(loc) + R @ Vector((v.x * scale[0], v.y * scale[1], v.z * scale[2])) for v in verts]
    return add(name, vs, faces, m, bone, smooth)


def cone(name, base, tip, r, m, bone, segs=8):
    base, tip = Vector(base), Vector(tip)
    x, y = frame(tip - base)
    verts = ring_pts(base, x, y, r, r, segs)
    verts += [tip, base]
    t, c = segs, segs + 1
    faces = []
    for k in range(segs):
        faces.append((k, (k + 1) % segs, t))
        faces.append(((k + 1) % segs, k, c))
    return add(name, verts, faces, m, bone, smooth=False)


def spike(name, base, direction, length, r, bone, m="argent"):
    d = Vector(direction).normalized()
    return cone(name, base, Vector(base) + d * length, r, m, bone)


def box(name, center, size, m, bone, rot=None, smooth=False):
    hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
    R = rot if rot is not None else Matrix.Identity(3)
    c = Vector(center)
    corners = [(-hx, -hy, -hz), (hx, -hy, -hz), (hx, hy, -hz), (-hx, hy, -hz),
               (-hx, -hy, hz), (hx, -hy, hz), (hx, hy, hz), (-hx, hy, hz)]
    verts = [c + R @ Vector(v) for v in corners]
    faces = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
    return add(name, verts, faces, m, bone, smooth)


def basis(normal, up):
    n = Vector(normal).normalized()
    u = Vector(up).normalized()
    r = u.cross(n).normalized()
    u = n.cross(r).normalized()
    return n, u, r


def buckle(name, center, normal, up, w, h, bar, bone, m="argent", depth=0.007):
    """Boucle carrée : cadre dans le plan perpendiculaire à normal, avec ardillon."""
    n, u, r = basis(normal, up)
    c = Vector(center)
    verts, faces = [], []
    for dz in (-depth / 2, depth / 2):
        for (ww, hh) in ((w / 2, h / 2), (w / 2 - bar, h / 2 - bar)):
            for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
                verts.append(c + r * sx * ww + u * sy * hh + n * dz)
    for k in range(4):
        k2 = (k + 1) % 4
        faces.append((k + 8, k2 + 8, k2 + 12, k + 12))
        faces.append((k, k + 4, k2 + 4, k2))
        faces.append((k, k2, k2 + 8, k + 8))
        faces.append((k + 4, k + 12, k2 + 12, k2 + 4))
    o = add(name, verts, faces, m, bone, smooth=False)
    box(name + "_pin", c + n * 0.004, (0.005, 0.005, h * 0.85), m, bone, rot=Matrix((r, n, u)).transposed())
    return o


def band(name, center, rx, ry, height, m, bone, axis=(0, 0, 1), segs=16, p=2.0):
    """Anneau (sangle, ceinture, bracelet) autour d'un axe."""
    c = Vector(center)
    a = Vector(axis).normalized()
    return loft(name, [(c - a * height / 2, rx, ry), (c + a * height / 2, rx, ry)], m, bone,
                segs=segs, p=p, caps=(False, False), smooth=True)


def stud(name, p, r, bone, m="argent"):
    return ellipsoid(name, p, (r, r, r), m, bone, 6, 4)


def apply_mods(o):
    dg = bpy.context.evaluated_depsgraph_get()
    ev = o.evaluated_get(dg)
    me = bpy.data.meshes.new_from_object(ev)
    old = o.data
    o.modifiers.clear()
    o.data = me
    bpy.data.meshes.remove(old)


def solidify(o, t, offset=0.0):
    mod = o.modifiers.new("solid", "SOLIDIFY")
    mod.thickness = t
    mod.offset = offset
    mod.use_even_offset = True
    apply_mods(o)


def shrink(o, target, offset):
    sw = o.modifiers.new("wrap", "SHRINKWRAP")
    sw.target = target
    sw.wrap_method = "NEAREST_SURFACEPOINT"
    sw.offset = offset
    apply_mods(o)


def bvh_of(o):
    return BVHTree.FromObject(o, bpy.context.evaluated_depsgraph_get())


def snap(bvh, p, off=0.0):
    loc, nrm, idx, d = bvh.find_nearest(Vector(p))
    return loc + nrm * off, nrm


def xform(o, pivot, R):
    pv = Vector(pivot)
    for v in o.data.vertices:
        v.co = pv + R @ (v.co - pv)
    o.data.update()


def grid_patch(name, corners, nu, nv, m, bone):
    p00, p10, p11, p01 = [Vector(c) for c in corners]
    verts, faces = [], []
    for j in range(nv + 1):
        for i in range(nu + 1):
            u, v = i / nu, j / nv
            verts.append(p00.lerp(p10, u).lerp(p01.lerp(p11, u), v))
    for j in range(nv):
        for i in range(nu):
            a = j * (nu + 1) + i
            faces.append((a, a + 1, a + nu + 2, a + nu + 1))
    return add(name, verts, faces, m, bone)


def arc_shell(name, rings, a0, a1, segs, m, bone):
    """Coque ouverte (col, cape) : arcs d'ellipse ; phi mesuré depuis le dos (+Y)."""
    verts, faces = [], []
    for (c, rx, ry) in rings:
        for k in range(segs + 1):
            phi = a0 + (a1 - a0) * k / segs
            verts.append(Vector(c) + Vector((math.sin(phi) * rx, math.cos(phi) * ry, 0)))
    for i in range(len(rings) - 1):
        for k in range(segs):
            a = i * (segs + 1) + k
            faces.append((a, a + 1, a + segs + 2, a + segs + 1))
    return add(name, verts, faces, m, bone)


def plate(name, center, normal, up, outline, m, bone, bulge=0.02, rim=0.01, curv=0.0, rim_m=None, thick=0.012):
    """Plaque bombée à rebord (genouillère) : contour 2D (u, v) en mètres, facettes franches."""
    n, u, r = basis(normal, up)
    c = Vector(center)
    levels = [(1.0, 0.0), (0.92, rim), (0.80, rim * 0.3)]
    N = len(outline)

    def P(ou, ov, h):
        return c + r * ou + u * ov + n * (h - curv * ou * ou)

    verts, faces = [], []
    for (s, h) in levels:
        for (ou, ov) in outline:
            verts.append(P(ou * s, ov * s, h))
    verts.append(P(0, 0, bulge))
    ctr = len(verts) - 1
    for L in range(2):
        for k in range(N):
            a = L * N + k
            b = L * N + (k + 1) % N
            faces.append((a, b, b + N, a + N))
    for k in range(N):
        faces.append((2 * N + k, 2 * N + (k + 1) % N, ctr))
    o = add(name, verts, faces, m, bone, smooth=False)
    if rim_m:
        o.data.materials.append(MATS[rim_m])
        for i, pg in enumerate(o.data.polygons):
            if i < N:
                pg.material_index = 1
    solidify(o, thick, offset=-1.0)
    return o


def ribbon(name, pts, nrms, widths, thicks, m, bone, segs=8):
    """Mèche : tube aplati qui suit pts, large dans le plan de la surface, fin selon la normale."""
    verts, faces = [], []
    n = len(pts)
    for i in range(n):
        t = pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]
        nr = nrms[i]
        wdir = t.cross(nr).normalized()
        for k in range(segs):
            a = 2 * math.pi * k / segs
            verts.append(pts[i] + wdir * math.cos(a) * widths[i] + nr * math.sin(a) * thicks[i])
    for i in range(n - 1):
        for k in range(segs):
            a = i * segs + k
            b = i * segs + (k + 1) % segs
            faces.append((a, b, b + segs, a + segs))
    verts.append(pts[-1])
    c = len(verts) - 1
    base = (n - 1) * segs
    for k in range(segs):
        faces.append((c, base + k, base + (k + 1) % segs))
    return add(name, verts, faces, m, bone)


def catmull(ctrl, n):
    """Courbe de Catmull-Rom passant par les points de contrôle, n points."""
    P = [Vector(c) for c in ctrl]
    P = [P[0] * 2 - P[1]] + P + [P[-1] * 2 - P[-2]]
    out = []
    segs = len(P) - 3
    for i in range(n):
        g = i / (n - 1) * segs
        k = min(int(g), segs - 1)
        t = g - k
        p0, p1, p2, p3 = P[k], P[k + 1], P[k + 2], P[k + 3]
        out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t
                          + (-p0 + 3 * p1 - 3 * p2 + p3) * t * t * t))
    return out


# ---------------------------------------------------------------- proportions (planche : 350 px/m)
FOOT_SPLAY = math.radians(18)  # pointes des pieds légèrement ouvertes


def arm_points(s):
    sh = Vector((0.275 * s, 0.0, 1.40))
    el = Vector((0.365 * s, 0.01, 1.16))
    wr = Vector((0.43 * s, -0.02, 0.965))
    return sh, el, wr, (wr - el).normalized()


def leg_points(s):
    hip = Vector((0.10 * s, 0.0, 0.93))
    knee = Vector((0.155 * s, -0.01, 0.54))
    ankle = Vector((0.20 * s, 0.01, 0.105))
    return hip, knee, ankle


def leg_at(s, z):
    """Point de l'axe genou-cheville à la hauteur z."""
    hip, knee, ankle = leg_points(s)
    return ankle.lerp(knee, (z - ankle.z) / (knee.z - ankle.z))


# ---------------------------------------------------------------- tête
def build_head():
    #  z, cy, rx, ry_avant, ry_dos : visage long, mâchoire carrée, menton marqué
    H = [
        (1.543, -0.080, 0.028, 0.020, 0.018),
        (1.558, -0.068, 0.052, 0.034, 0.040),
        (1.575, -0.057, 0.064, 0.048, 0.052),
        (1.598, -0.042, 0.074, 0.062, 0.066),
        (1.628, -0.030, 0.080, 0.083, 0.076),
        (1.665, -0.022, 0.087, 0.093, 0.086),
        (1.700, -0.018, 0.087, 0.096, 0.094),
        (1.740, -0.014, 0.082, 0.092, 0.100),
        (1.790, -0.010, 0.074, 0.080, 0.098),
        (1.830, -0.004, 0.056, 0.058, 0.076),
        (1.856, 0.000, 0.020, 0.020, 0.028),
    ]
    loft("tete", [((0, cy, z), rx, ryf, ryb) for z, cy, rx, ryf, ryb in H], "peau", "head", segs=24, p=2.2)
    loft("cou", [((0, 0.0, 1.44), 0.068, 0.066), ((0, -0.012, 1.59), 0.058, 0.056)], "peau", "neck",
         segs=14, caps=(False, False))
    # nez droit
    loft("nez", [((0, -0.106, 1.712), 0.006, 0.006), ((0, -0.122, 1.672), 0.008, 0.010),
                 ((0, -0.128, 1.649), 0.011, 0.011), ((0, -0.122, 1.639), 0.010, 0.008)], "peau", "head", segs=8)
    for s in (1, -1):
        ellipsoid(sname("oreille", s), (0.082 * s, 0.000, 1.668), (0.014, 0.024, 0.034), "peau", "head", 10, 6)
        # boucle d'oreille (anneau d'argent au lobe)
        c = Vector((0.090 * s, 0.004, 1.628))
        loft(sname("boucle_oreille", s), [(c + Vector((0, 0.009 * math.cos(a), 0.009 * math.sin(a))), 0.0022, 0.0022)
                                          for a in [2 * math.pi * k / 10 for k in range(11)]], "argent", "head", segs=6)
        # yeux plissés, paupière lourde, sourcils épais froncés
        ellipsoid(sname("oeil", s), (0.034 * s, -0.101, 1.700), (0.020, 0.007, 0.0085), "oeil", "head", 10, 6)
        ellipsoid(sname("iris", s), (0.031 * s, -0.107, 1.699), (0.0092, 0.004, 0.0085), "iris", "head", 8, 6)
        R = Matrix.Rotation(math.radians(-10 * s), 3, "Y")
        box(sname("paupiere", s), (0.034 * s, -0.106, 1.7085), (0.046, 0.010, 0.0075), "paupiere", "head", rot=R)
        R = Matrix.Rotation(math.radians(-17 * s), 3, "Y") @ Matrix.Rotation(math.radians(10 * s), 3, "Z")
        box(sname("sourcil", s), (0.037 * s, -0.106, 1.724), (0.050, 0.016, 0.013), "sourcils", "head", rot=R)
    # sourire en coin (coin gauche relevé)
    mouth = [(-0.027, -0.104, 1.606), (-0.01, -0.110, 1.604), (0.008, -0.110, 1.606), (0.024, -0.105, 1.613),
             (0.032, -0.099, 1.621)]
    loft("bouche", [(p, 0.0035, 0.003) for p in mouth], "bouche", "head", segs=6)
    ellipsoid("menton", (0, -0.082, 1.556), (0.030, 0.020, 0.018), "peau", "head", 10, 6)


# ---------------------------------------------------------------- buste
def build_torso():
    global LISSE
    loft("maillot", [((0, 0.0, 1.22), 0.17, 0.135, 0.118), ((0, 0.0, 1.50), 0.12, 0.10, 0.088)], "maillot", "chest",
         segs=16, p=2.5)
    T = [  # z, cy, rx, ry
        (0.960, 0.000, 0.178, 0.125),
        (1.050, 0.000, 0.172, 0.120),
        (1.150, -0.005, 0.182, 0.127),
        (1.250, -0.010, 0.200, 0.136),
        (1.340, -0.010, 0.213, 0.142),
        (1.420, -0.005, 0.210, 0.132),
        (1.480, 0.000, 0.170, 0.110),
        (1.520, 0.000, 0.095, 0.080),
    ]
    o = loft("veste", [((0, cy, z), rx, ry * 1.12, ry) for z, cy, rx, ry in T], "cuir", "spine", segs=28, p=2.4)
    LISSE = o.copy()
    LISSE.data = o.data.copy()
    LISSE.name = "veste_lisse"
    col().objects.link(LISSE)
    # encolure en V : l'avant du haut de la veste s'ouvre sur le maillot
    for v in o.data.vertices:
        co = v.co
        if co.y < -0.03 and co.z > 1.29:
            depth = (co.z - 1.29) / 0.23
            if abs(co.x) < 0.012 + 0.085 * depth:
                co.y += 0.05
    # épaules larges sous les épaulières
    for s in (1, -1):
        ellipsoid(sname("epaule", s), (0.255 * s, 0.0, 1.41), (0.09, 0.095, 0.085), "cuir", sname("upper_arm", s),
                  14, 8)
    # col montant derrière la nuque
    o = arc_shell("col", [((0, 0.0, 1.47), 0.090, 0.085), ((0, 0.010, 1.53), 0.100, 0.092),
                          ((0, 0.020, 1.56), 0.115, 0.105)], math.radians(-85), math.radians(85), 16,
                  "cuir", "chest")
    solidify(o, 0.012)
    # bassin (pantalon)
    loft("bassin", [((0, 0.0, 0.84), 0.10, 0.08), ((0, 0.0, 0.88), 0.165, 0.112), ((0, 0.0, 0.95), 0.18, 0.122),
                    ((0, 0.0, 1.00), 0.177, 0.122)], "cuir", "hips", segs=22, p=2.3)


def build_lapels():
    """Larges revers cloutés le long du V, collés au buste."""
    bvh = bvh_of(LISSE)
    for s in (1, -1):
        corners = [(0.018 * s, -0.25, 1.30), (0.13 * s, -0.25, 1.375), (0.215 * s, -0.25, 1.47),
                   (0.075 * s, -0.25, 1.52)]
        o = grid_patch(sname("revers", s), corners, 6, 6, "cuir_use", "chest")
        shrink(o, LISSE, 0.01)
        solidify(o, 0.01)
        # clous le long du bord extérieur
        a, b, c = Vector(corners[3]), Vector(corners[2]), Vector(corners[1])
        for k in range(5):
            p = a.lerp(b, (k + 0.5) / 5)
            loc, nrm = snap(bvh, p, 0.018)
            stud(f"revers_clou{k}" + (".L" if s > 0 else ".R"), loc - Vector((0.012 * s, 0, 0.01)), 0.0065, "chest")
        for k in range(3):
            p = b.lerp(c, (k + 0.5) / 3)
            loc, nrm = snap(bvh, p, 0.018)
            stud(f"revers_clouB{k}" + (".L" if s > 0 else ".R"), loc + Vector((0, 0, 0.012)), 0.0065, "chest")
    # rangées de clous le long des pans de la veste
    for s in (1, -1):
        for k in range(7):
            loc, nrm = snap(bvh, (0.05 * s, -0.3, 1.27 - k * 0.036), 0.004)
            stud(f"veste_clou{k}" + (".L" if s > 0 else ".R"), loc, 0.0062, "spine")
    # fermetures éclair en biais sur la poitrine
    for s in (1, -1):
        a, _ = snap(bvh, (0.15 * s, -0.2, 1.24), 0.006)
        b, _ = snap(bvh, (0.10 * s, -0.2, 1.17), 0.006)
        d = (b - a)
        n = Vector((0, -1, 0))
        r = d.normalized().cross(n).normalized()
        box(sname("zip", s), (a + b) / 2, (0.008, 0.006, d.length), "argent", "chest",
            rot=Matrix((r, n, d.normalized())).transposed())


# ---------------------------------------------------------------- bras et mains
def build_arms():
    for s in (1, -1):
        side = ".L" if s > 0 else ".R"
        sh, el, wr, d2 = arm_points(s)
        d1 = (el - sh).normalized()
        # manche de cuir retroussée au coude
        loft("bras" + side, [(sh, 0.080, 0.078), (sh.lerp(el, 0.5), 0.077, 0.074), (el + d2 * 0.02, 0.072, 0.07)],
             "cuir", "upper_arm" + side, segs=14)
        for k, t in enumerate((0.38, 0.7)):
            band(f"pli{k}" + side, sh.lerp(el, t), 0.081, 0.078, 0.014, "cuir_use", "upper_arm" + side, axis=d1)
        c = el + d2 * 0.012
        band("manchette" + side, c, 0.086, 0.083, 0.055, "cuir_use", "forearm" + side, axis=d2)
        x, y = frame(d2)
        for k in range(9):
            a = 2 * math.pi * k / 9
            stud(f"clou_manchette{side}{k}", c + (x * math.cos(a) * 0.088 + y * math.sin(a) * 0.085), 0.0065,
                 "forearm" + side)
        # avant-bras nu, musclé
        loft("avant_bras" + side, [(el, 0.062, 0.060), (el.lerp(wr, 0.35), 0.066, 0.059),
                                   (el.lerp(wr, 0.8), 0.052, 0.047), (wr, 0.046, 0.043)],
             "peau", "forearm" + side, segs=14)
        build_hand(s, wr, (d2 + Vector((0, 0, -0.9))).normalized())  # mains pendantes, doigts vers le bas


def build_hand(s, wr, d):
    side = ".L" if s > 0 else ".R"
    bone = "hand" + side
    before = set(col().objects.keys())
    # repère : d vers les doigts, w vers l'avant (pouce), n = paume tournée vers la cuisse
    w = Vector((-0.55 * s, -0.85, 0)).normalized()  # dos de la main tourné vers l'avant-extérieur
    n = d.cross(w).normalized() * s
    w = n.cross(d).normalized() * s
    # manchette de la mitaine
    loft("mitaine" + side, [(wr - d * 0.05, 0.047, 0.047), (wr - d * 0.005, 0.050, 0.050),
                            (wr + d * 0.02, 0.046, 0.05)], "cuir", bone, segs=14, caps=(True, False))
    band("mitaine_bord" + side, wr - d * 0.048, 0.05, 0.05, 0.012, "cuir_use", bone, axis=d, segs=14)
    # paume gantée (grande main stylisée)
    loft("paume" + side, [(wr, 0.034, 0.050), (wr + d * 0.05, 0.032, 0.058), (wr + d * 0.105, 0.026, 0.057),
                          (wr + d * 0.12, 0.019, 0.050)], "cuir", bone, segs=12, p=2.6, ref=w)
    offs = [-0.039, -0.013, 0.013, 0.038]  # auriculaire .. index
    lens = [(0.032, 0.022, 0.019), (0.038, 0.027, 0.022), (0.041, 0.029, 0.023), (0.038, 0.026, 0.021)]
    radii = [0.0120, 0.0135, 0.0140, 0.0138]
    for fi, (o, L, r) in enumerate(zip(offs, lens, radii)):
        p = wr + d * 0.112 + w * o
        dirv = d.copy()
        pts = [p]
        for seg in L:
            dirv = (dirv - n * 0.42).normalized()
            p = p + dirv * seg
            pts.append(p)
        loft(f"doigt{fi}_gant{side}", [(pts[0], r + 0.002, r + 0.002), (pts[0].lerp(pts[1], 0.55), r + 0.002, r + 0.002)],
             "cuir", bone, segs=8, ref=w)
        loft(f"doigt{fi}{side}", [(pts[0].lerp(pts[1], 0.3), r, r), (pts[1], r, r), (pts[2], r * 0.95, r * 0.95),
                                  (pts[3], r * 0.85, r * 0.85)], "peau", bone, segs=8, ref=w)
    # pouce
    p0 = wr + d * 0.035 + w * 0.045 - n * 0.012
    p1 = p0 + (d * 0.5 + w * 0.7 - n * 0.3).normalized() * 0.034
    p2 = p1 + (d * 0.8 + w * 0.3 - n * 0.45).normalized() * 0.029
    p3 = p2 + (d * 0.9 - n * 0.45).normalized() * 0.022
    loft("pouce_gant" + side, [(p0, 0.017, 0.017), (p0.lerp(p1, 0.6), 0.016, 0.016)], "cuir", bone, segs=8)
    loft("pouce" + side, [(p0.lerp(p1, 0.4), 0.015, 0.015), (p1, 0.015, 0.015), (p2, 0.0135, 0.0135),
                          (p3, 0.012, 0.012)], "peau", bone, segs=8)
    # mains surdimensionnées comme sur la planche (bout des doigts vers 0,70 m)
    S = Matrix.Diagonal(Vector((1.3, 1.3, 1.3)))
    for o in list(col().objects):
        if o.name not in before:
            xform(o, wr - d * 0.05, S)


# ---------------------------------------------------------------- jambes et bottes
HEX = [(0.0, 0.118), (0.088, 0.064), (0.088, -0.05), (0.0, -0.108), (-0.088, -0.05), (-0.088, 0.064)]


def build_legs():
    for s in (1, -1):
        side = ".L" if s > 0 else ".R"
        hip, knee, ankle = leg_points(s)
        loft("cuisse" + side, [(hip + Vector((0, 0, 0.06)), 0.105, 0.112), (hip.lerp(knee, 0.45), 0.099, 0.101),
                               (knee + Vector((0, 0, 0.05)), 0.083, 0.086), (knee, 0.080, 0.083)],
             "cuir", "thigh" + side, segs=16)
        loft("jambe" + side, [(knee, 0.080, 0.083), (leg_at(s, 0.44), 0.078, 0.080), (leg_at(s, 0.30), 0.068, 0.07)],
             "cuir", "shin" + side, segs=16)
        # genouillère hexagonale à rebord
        plate("genouillere" + side, knee + Vector((0, -0.082, 0.02)), (0, -1, 0.08), (0, 0, 1), HEX, "metal",
              "shin" + side, bulge=0.028, rim=0.012, curv=4.0, rim_m="metal_bord")
        band("genou_sangle_h" + side, knee + Vector((0, 0.004, 0.085)), 0.086, 0.089, 0.018, "cuir_use", "thigh" + side)
        band("genou_sangle_b" + side, knee + Vector((0, 0.004, -0.07)), 0.083, 0.086, 0.018, "cuir_use", "shin" + side)
        build_boot(s)


def build_boot(s):
    side = ".L" if s > 0 else ".R"
    hip, knee, ankle = leg_points(s)
    fb = "foot" + side
    sb = "shin" + side
    top = 0.40
    loft("tige_botte" + side, [(leg_at(s, 0.09), 0.062, 0.070), (leg_at(s, 0.20), 0.064, 0.070),
                               (leg_at(s, 0.33), 0.070, 0.074), (leg_at(s, top), 0.076, 0.079)],
         "cuir", sb, segs=18, caps=(True, False))
    # revers clouté à pointes sous le genou
    c = leg_at(s, top + 0.005)
    band("botte_revers" + side, c, 0.082, 0.085, 0.045, "cuir_use", sb, segs=18)
    for k in range(11):
        a = math.radians(-100 + 200 * k / 10) - math.pi / 2  # autour de l'avant
        dirv = Vector((math.cos(a), math.sin(a), 0))
        spike(f"botte_pointe{k}" + side, c + Vector((dirv.x * 0.082, dirv.y * 0.085, 0)), dirv, 0.02, 0.0085, sb)
    # sangle et boucle à mi-mollet
    c = leg_at(s, 0.27)
    band("botte_sangle" + side, c, 0.074, 0.078, 0.028, "cuir_use", sb, segs=18)
    buckle("botte_boucle" + side, c + Vector((0.068 * s, -0.04, 0)), (s * 0.87, -0.5, 0), (0, 0, 1), 0.036,
           0.034, 0.007, sb)
    # pied (construit pointe vers -Y puis ouvert de FOOT_SPLAY)
    ax, ay = ankle.x, ankle.y
    F = [  # y local, z centre, demi-hauteur, demi-largeur
        (0.070, 0.078, 0.060, 0.050),
        (0.020, 0.082, 0.078, 0.058),
        (-0.050, 0.070, 0.070, 0.062),
        (-0.130, 0.055, 0.052, 0.062),
        (-0.200, 0.050, 0.040, 0.054),
        (-0.242, 0.053, 0.026, 0.038),
        (-0.258, 0.055, 0.008, 0.012),
    ]
    parts = [loft("pied" + side, [((ax, ay + ly, zc), h, w) for ly, zc, h, w in F], "cuir", fb, segs=16, p=2.3)]
    parts.append(box("semelle" + side, (ax, ay - 0.095, 0.013), (0.12, 0.31, 0.026), "cuir_use", fb))
    parts.append(box("talon" + side, (ax, ay + 0.042, 0.035), (0.09, 0.07, 0.05), "cuir_use", fb))
    parts.append(ellipsoid("embout" + side, (ax, ay - 0.21, 0.052), (0.054, 0.055, 0.044), "metal", fb, 12, 8))
    parts.append(spike("pointe_bout_ext" + side, (ax + 0.046 * s, ay - 0.205, 0.055), (s, -0.45, 0.25), 0.045, 0.014, fb))
    parts.append(spike("pointe_bout" + side, (ax + 0.012 * s, ay - 0.252, 0.058), (0.25 * s, -1, 0.35), 0.042, 0.013, fb))
    parts.append(spike("pointe_bout_int" + side, (ax - 0.042 * s, ay - 0.21, 0.055), (-s, -0.5, 0.25), 0.03, 0.011, fb))
    parts.append(spike("eperon" + side, (ax, ay + 0.08, 0.055), (0, 1, 0.05), 0.035, 0.012, fb))
    # sangle de cheville en biais, à pointes
    ca = Vector((ax, ay - 0.005, 0.135))
    axis = Vector((0, -0.45, 1)).normalized()
    parts.append(band("cheville_sangle" + side, ca, 0.070, 0.078, 0.024, "cuir_use", fb, axis=axis, segs=16))
    x, y = frame(axis)
    for k in range(6):
        a = math.radians(-60 + 24 * k) if s > 0 else math.radians(180 + 60 - 24 * k)  # côté extérieur
        dirv = (x * math.cos(a) + y * math.sin(a)).normalized()
        parts.append(spike(f"cheville_pointe{k}" + side, ca + x * math.cos(a) * 0.07 + y * math.sin(a) * 0.078, dirv,
                           0.018, 0.0075, fb))
    R = Matrix.Rotation(FOOT_SPLAY * s, 3, "Z")
    for o in parts:
        xform(o, (ax, ay, 0), R)


# ---------------------------------------------------------------- tenue
def build_belt():
    loft("ceinture", [((0, 0.0, 0.961), 0.187, 0.148, 0.132), ((0, 0.0, 1.019), 0.187, 0.148, 0.132)], "sangle", "hips",
         segs=28, p=2.3, caps=(False, False))
    n = 24
    for k in range(n):
        a = 2 * math.pi * (k + 0.5) / n
        ca, sa = math.cos(a), math.sin(a)
        px = spow(ca, 2 / 2.3) * 0.19
        py = spow(sa, 2 / 2.3) * (0.151 if sa < 0 else 0.135)
        if abs(px) < 0.06 and py < 0:
            continue
        stud(f"ceinture_clou{k}", (px, py, 0.99), 0.0075, "hips")
    buckle("ceinture_boucle", (0, -0.153, 0.99), (0, -1, 0), (0, 0, 1), 0.092, 0.066, 0.015, "hips", depth=0.01)


def build_neck_gear():
    band("collier", (0, -0.004, 1.52), 0.070, 0.068, 0.032, "cuir", "neck", segs=18)
    for k in range(14):
        a = 2 * math.pi * k / 14
        dirv = Vector((math.cos(a), math.sin(a), 0))
        p = Vector((0, -0.004, 1.52)) + Vector((dirv.x * 0.071, dirv.y * 0.069, 0))
        if k % 2:
            spike(f"collier_pointe{k}", p, dirv, 0.016, 0.0065, "neck")
        else:
            stud(f"collier_clou{k}", p, 0.006, "neck")
    # trois chaînes d'argent sur la poitrine
    for ci, (drop, spread) in enumerate(((0.05, 0.058), (0.092, 0.068), (0.135, 0.078))):
        n = 20 + ci * 5
        for k in range(n + 1):
            t = k / n * 2 - 1
            x = t * spread
            z = 1.505 - drop * (1 - t * t)
            y = -0.075 - (1.515 - z) * 0.45 - (0.012 if abs(t) > 0.8 else 0)
            stud(f"chaine{ci}_{k}", (x, y, z), 0.0048, "chest")
    # médaillon : gemme rouge en losange
    stud("monture", (0, -0.136, 1.372), 0.012, "chest")
    loft("gemme", [((0, -0.145, 1.402), 0.001, 0.001), ((0, -0.148, 1.372), 0.019, 0.008),
                   ((0, -0.145, 1.338), 0.001, 0.001)], "gemme", "chest", segs=4, smooth=False)


def build_pauldrons():
    for s in (1, -1):
        side = ".L" if s > 0 else ".R"
        bone = "upper_arm" + side
        R1 = Matrix.Rotation(math.radians(22 * s), 3, "Y")
        R2 = Matrix.Rotation(math.radians(48 * s), 3, "Y")
        c1 = Vector((0.29 * s, 0.0, 1.445))
        c2 = Vector((0.345 * s, 0.0, 1.325))
        # coque haute + lame basse (calottes épaisses), bord clair biseauté
        cap = math.radians(100)
        o = ellipsoid("epauliere" + side, c1, (0.138, 0.145, 0.095), "metal", bone, 24, 10, rot=R1, p=2.6, cap=cap)
        solidify(o, 0.018, offset=-1.0)
        band("epauliere_bord" + side, c1 + R1 @ Vector((0, 0, -0.02)), 0.142, 0.149, 0.02, "metal_bord", bone,
             axis=R1 @ Vector((0, 0, 1)), segs=24, p=2.6)
        o = ellipsoid("epauliere_lame" + side, c2, (0.095, 0.142, 0.07), "metal", bone, 24, 8, rot=R2, p=2.2,
                      cap=cap)
        solidify(o, 0.014, offset=-1.0)
        band("epauliere_lame_bord" + side, c2 + R2 @ Vector((0, 0, -0.014)), 0.099, 0.146, 0.016, "metal_bord",
             bone, axis=R2 @ Vector((0, 0, 1)), segs=24, p=2.2)
        # pointes : une dressée, une vers l'extérieur ; cônes sombres devant et derrière
        spike("pointe_haut" + side, (0.275 * s, 0.0, 1.53), (0.18 * s, 0, 1), 0.115, 0.034, bone)
        spike("pointe_ext" + side, (0.37 * s, 0.0, 1.485), (s, 0, 0.65), 0.10, 0.032, bone)
        for fy in (-1, 1):
            spike(f"pointe_face{'A' if fy < 0 else 'D'}{side}", (0.30 * s, 0.13 * fy, 1.45), (0.25 * s, fy, 0.35),
                  0.05, 0.026, bone, m="metal_bord")
        for k, ph in enumerate((-60, -90, -120, 60, 90, 120)):
            a = math.radians(ph)
            p = c1 + R1 @ Vector((0.128 * math.cos(a), 0.14 * math.sin(a), 0.005))
            stud(f"rivet{k}" + side, p, 0.0075, bone)


def build_cape():
    """Cape bordeaux : attachée sous les épaulières, évasée derrière, lambeaux en dents de scie."""
    rnd = random.Random(7)
    cols, rows = 48, 26
    top_z = 1.42
    jag = [rnd.uniform(0.0, 0.05) for _ in range(cols + 1)]
    verts, faces = [], []
    for j in range(cols + 1):
        u = j / cols * 2 - 1
        phi = u * math.radians(106)
        tooth = abs(((j / cols * 7.5) % 1.0) - 0.5) * 2
        bottom = 0.19 + 0.16 * abs(u) ** 1.2 + 0.15 * tooth + jag[j]
        for i in range(rows + 1):
            v = i / rows
            z = top_z - v * (top_z - bottom)
            drop = top_z - z
            rx = 0.245 + drop * 0.21
            ry = 0.150 + drop * 0.15
            fold = 1.0 + 0.045 * v * math.sin(phi * 6.0)
            x = math.sin(phi) * rx * fold
            y = math.cos(phi) * ry * fold + 0.01 + drop * 0.06
            verts.append((x, y, z))
    for j in range(cols):
        for i in range(rows):
            a = j * (rows + 1) + i
            b = (j + 1) * (rows + 1) + i
            faces.append((a, a + 1, b + 1, b))
    o = add("cape", verts, faces, "cape", "chest")
    solidify(o, 0.012)
    return o


def build_straps(cape):
    """Deux bandoulières : chacune passe sur une épaule et descend vers la hanche opposée,
    devant (sur la veste) et derrière (par-dessus la cape)."""
    for target, fy, label in ((LISSE, -1, "torse"), (cape, 1, "dos")):
        bvh = bvh_of(target)
        for s in (1, -1):
            a = Vector((0.22 * s, 0.3 * fy, 1.41))
            b = Vector((-0.20 * s, 0.3 * fy, 1.05))
            d = (b - a).normalized()
            side = Vector((0, fy, 0)).cross(d).normalized()
            verts, faces = [], []
            n = 26
            for i in range(n + 1):
                p = a.lerp(b, i / n)
                verts += [p - side * 0.028, p + side * 0.028]
            for i in range(n):
                faces.append((2 * i, 2 * i + 1, 2 * i + 3, 2 * i + 2))
            o = add(sname("sangle_" + label, s), verts, faces, "sangle", "chest")
            shrink(o, target, 0.011)
            solidify(o, 0.01)
            # grosse boucle carrée en haut de la bandoulière
            pb = a.lerp(b, 0.2)
            loc, nrm = snap(bvh, pb, 0.022)
            buckle(sname("sangle_boucle_" + label, s), loc, nrm, -d, 0.056, 0.052, 0.011, "chest", depth=0.009)
    bpy.data.objects.remove(LISSE, do_unlink=True)


# ---------------------------------------------------------------- crinière
HAIR = [  # z, cy, rx, ry_avant, ry_dos  (volume de base en cloche ; les mèches ajoutent ~4 cm tout autour)
    (1.885, 0.010, 0.020, 0.020, 0.020),
    (1.870, 0.010, 0.050, 0.060, 0.065),
    (1.848, 0.005, 0.078, 0.090, 0.118),
    (1.825, 0.000, 0.100, 0.100, 0.145),
    (1.795, 0.000, 0.116, 0.095, 0.162),
    (1.775, 0.005, 0.126, 0.082, 0.172),
    (1.750, 0.020, 0.140, 0.040, 0.182),
    (1.710, 0.035, 0.158, 0.012, 0.190),
    (1.660, 0.045, 0.180, 0.000, 0.195),
    (1.610, 0.055, 0.205, 0.000, 0.195),
    (1.560, 0.070, 0.215, 0.000, 0.185),
    (1.500, 0.090, 0.212, 0.000, 0.165),
    (1.440, 0.110, 0.196, 0.000, 0.132),
    (1.380, 0.125, 0.172, 0.000, 0.100),
    (1.340, 0.133, 0.150, 0.000, 0.072),
    (1.310, 0.138, 0.112, 0.000, 0.045),
    (1.295, 0.140, 0.050, 0.000, 0.018),
]


def hair_dx(z):
    """Le haut de la crinière est balayé vers la gauche du personnage (+X)."""
    return 0.05 * max(0.0, min(1.0, (z - 1.72) / 0.14))


def hair_env(phi, z):
    """Point approximatif du volume de base (phi = 0 dans le dos, ±pi devant)."""
    T = HAIR
    z = max(T[-1][0], min(T[0][0], z))
    for i in range(len(T) - 1):
        if T[i + 1][0] <= z <= T[i][0]:
            f = (z - T[i + 1][0]) / (T[i][0] - T[i + 1][0])
            row = [T[i + 1][k] + (T[i][k] - T[i + 1][k]) * f for k in range(5)]
            break
    _, cy, rx, ryf, ryb = row
    c = math.cos(phi)
    return Vector((math.sin(phi) * rx + hair_dx(z), cy + c * (ryb if c >= 0 else ryf), z))


def build_hair():
    base = loft("cheveux", [((hair_dx(z), cy, z), rx, ryf, ryb) for z, cy, rx, ryf, ryb in HAIR], "cheveux_ombre", "head",
                segs=32, p=2.0)
    bvh = bvh_of(base)
    rnd = random.Random(5)
    n_lock = [0]

    def make_lock(raw, width, bone="head", curl=0.03, waves=1.5):
        n = len(raw)
        snapped = [snap(bvh, p) for p in raw]
        locs = [l for l, _ in snapped]
        nr = [v for _, v in snapped]
        for _ in range(3):  # trajet et normales lissés : pas de dents de scie sur les facettes
            nr = [(nr[max(i - 1, 0)] + nr[i] * 2 + nr[min(i + 1, n - 1)]).normalized() for i in range(n)]
            locs = [(locs[max(i - 1, 0)] + locs[i] * 2 + locs[min(i + 1, n - 1)]) / 4 for i in range(n)]
        pts, nrms, ws, ths = [], [], [], []
        for i in range(n):
            s = i / (n - 1)
            loc, nrm = locs[i], nr[i]
            # grosse boucle : renflements réguliers, pointe effilée
            w = width * min(1.0, 0.6 + 1.8 * s) * (1 - s ** 2.5) * (1 + 0.16 * math.cos(4 * math.pi * waves * s)) + 0.003
            th = max(0.007, 0.5 * w)
            lift = th * 0.55
            if s > 0.75:  # la pointe s'enroule vers l'extérieur
                k = (s - 0.75) / 0.25
                lift += curl * k * k
                loc = loc + Vector((0, 0, 0.03 * k))
            pts.append(loc + nrm * lift)
            nrms.append(nrm)
            ws.append(w)
            ths.append(th)
        n_lock[0] += 1
        return ribbon(f"meche{n_lock[0]}", pts, nrms, ws, ths, "cheveux", bone, segs=10)

    def path(phi0, z0, z1, amp, waves, n=28, ph=0.0):
        return [hair_env(phi0 + amp * math.sin(2 * math.pi * waves * i / (n - 1) + ph), z0 + (z1 - z0) * i / (n - 1))
                for i in range(n)]

    # grosses boucles en S du dos et des côtés, pointes sous les épaules
    N = 11
    for i in range(N):
        phi0 = math.radians(-112 + 224 * i / (N - 1))
        side = abs(phi0) / math.radians(118)
        z1 = 1.305 + 0.25 * side ** 1.6 + rnd.uniform(-0.01, 0.02)
        make_lock(path(phi0, 1.86, z1, math.radians(14), 2.2, ph=rnd.uniform(0, 6.3)), 0.064, curl=0.05, waves=2.2)
    # seconde couche, plus courte, décalée d'une demi-mèche
    for i in range(N - 1):
        phi0 = math.radians(-101 + 202 * i / (N - 2))
        side = abs(phi0) / math.radians(118)
        z1 = 1.47 + 0.14 * side ** 2 + rnd.uniform(-0.02, 0.04)
        make_lock(path(phi0, 1.79, z1, math.radians(15), 1.8, ph=rnd.uniform(0, 6.3)), 0.06, curl=0.045, waves=1.8)
    # boucles qui encadrent le visage (tempes -> épaules), pointes relevées vers l'extérieur
    for s in (1, -1):
        for k in range(3):
            phi0 = s * math.radians(130 + 16 * k)
            make_lock(path(phi0, 1.80, 1.54 + 0.025 * k, math.radians(8), 1.0, n=22, ph=k), 0.062, curl=0.05,
                      waves=1.0)
    # houppe : du front, grosses mèches qui montent et se rabattent, surtout vers la gauche du personnage
    for k, (x0, sw) in enumerate(((-0.06, -0.10), (-0.02, 0.12), (0.02, 0.16), (0.06, 0.17), (-0.085, -0.13))):
        ctrl = [(x0, -0.10, 1.785), (x0 + sw * 0.25, -0.10, 1.85), (x0 + sw * 0.6, -0.04, 1.885),
                (x0 + sw * 0.9, 0.05, 1.865), (x0 + sw, 0.12, 1.79), (x0 + sw * 1.05, 0.16, 1.70)]
        make_lock(catmull(ctrl, 26), 0.064, curl=0.0, waves=1.0)
    return base


# ---------------------------------------------------------------- assemblage
def build_body():
    reset()
    materials()
    build_head()
    build_torso()
    build_arms()
    build_legs()


def build_outfit():
    build_lapels()
    build_belt()
    build_neck_gear()
    build_pauldrons()
    cape = build_cape()
    build_straps(cape)


def build_all():
    build_body()
    build_outfit()
    build_hair()


# ---------------------------------------------------------------- squelette et skinning
# Os nommés comme les pivots de HeroModel (hanches, torse, tête, bras, jambes, mains).
SOFT = {  # pièces déformables : candidates pour la pondération par distance aux os
    "veste": ["hips", "spine", "chest"], "maillot": ["spine", "chest"], "cou": ["chest", "neck", "head"],
    "bassin": ["hips", "thigh.L", "thigh.R"], "col": ["chest", "neck"],
    "sangle_torse.L": ["spine", "chest"], "sangle_torse.R": ["spine", "chest"],
    "sangle_dos.L": ["spine", "chest"], "sangle_dos.R": ["spine", "chest"],
    "cape": ["hips", "spine", "chest"], "cheveux": ["neck", "head", "chest"],
}
for _s in ("L", "R"):
    SOFT.update({
        f"epaule.{_s}": ["chest", f"upper_arm.{_s}"],
        f"bras.{_s}": ["chest", f"upper_arm.{_s}", f"forearm.{_s}"],
        f"manchette.{_s}": [f"upper_arm.{_s}", f"forearm.{_s}"],
        f"avant_bras.{_s}": [f"upper_arm.{_s}", f"forearm.{_s}", f"hand.{_s}"],
        f"cuisse.{_s}": ["hips", f"thigh.{_s}", f"shin.{_s}"],
        f"jambe.{_s}": [f"thigh.{_s}", f"shin.{_s}", f"foot.{_s}"],
        f"tige_botte.{_s}": [f"shin.{_s}", f"foot.{_s}"],
        f"mitaine.{_s}": [f"forearm.{_s}", f"hand.{_s}"],
    })


def bone_layout():
    b = {
        "hips": ((0, 0, 0.90), (0, 0, 1.02), None),
        "spine": ((0, 0, 1.02), (0, 0, 1.20), "hips"),
        "chest": ((0, 0, 1.20), (0, 0, 1.44), "spine"),
        "neck": ((0, 0, 1.44), (0, -0.01, 1.57), "chest"),
        "head": ((0, -0.01, 1.57), (0, -0.01, 1.84), "neck"),
    }
    for s in (1, -1):
        side = ".L" if s > 0 else ".R"
        sh, el, wr, d2 = arm_points(s)
        hip, knee, ankle = leg_points(s)
        toe = ankle + Matrix.Rotation(FOOT_SPLAY * s, 3, "Z") @ Vector((0, -0.21, -0.07))
        b["upper_arm" + side] = (tuple(sh), tuple(el), "chest")
        b["forearm" + side] = (tuple(el), tuple(wr), "upper_arm" + side)
        b["hand" + side] = (tuple(wr), tuple(wr + d2 * 0.14), "forearm" + side)
        b["thigh" + side] = (tuple(hip), tuple(knee), "hips")
        b["shin" + side] = (tuple(knee), tuple(ankle), "thigh" + side)
        b["foot" + side] = (tuple(ankle), tuple(toe), "shin" + side)
    return b


def _seg_dist(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-9)))
    return (a + ab * t - p).length


def build_rig():
    """Crée l'armature, pondère chaque pièce puis fusionne tout en un maillage « Riffald »."""
    layout = bone_layout()
    arm_data = bpy.data.armatures.new("Riffald_rig")
    rig = bpy.data.objects.new("Riffald_rig", arm_data)
    col().objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    rig.select_set(True)
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

    meshes = [o for o in col().objects if o.type == "MESH"]
    for o in meshes:
        tag = o.get("bone", "chest")
        cands = SOFT.get(o.name) or (SOFT["cheveux"] if o.name.startswith("meche") else None)
        mw = o.matrix_world
        for bn in (cands or [tag]):
            if bn not in o.vertex_groups:
                o.vertex_groups.new(name=bn)
        if not cands:
            o.vertex_groups[tag].add(range(len(o.data.vertices)), 1.0, "REPLACE")
            continue
        for v in o.data.vertices:
            p = mw @ v.co
            ds = sorted(((_seg_dist(p, *segs[bn]), bn) for bn in cands))[:2]
            w = [1.0 / max(d, 0.01) ** 4 for d, _ in ds]
            tot = sum(w)
            for (d, bn), wi in zip(ds, w):
                if wi / tot > 0.02:
                    o.vertex_groups[bn].add([v.index], wi / tot, "REPLACE")
    with bpy.context.temp_override(active_object=meshes[0], selected_editable_objects=meshes,
                                   selected_objects=meshes):
        bpy.ops.object.join()
    body = meshes[0]
    body.name = "Riffald"
    body.data.name = "Riffald"
    body.parent = rig
    mod = body.modifiers.new("Armature", "ARMATURE")
    mod.object = rig
    return rig, body


def export_glb(path):
    bpy.ops.object.select_all(action="DESELECT")
    for o in col().objects:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=False,
                              export_yup=True, export_animations=False)
