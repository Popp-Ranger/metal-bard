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
    # arbre de nœuds remis à zéro (une passe de texture précédente y branche une image)
    nt = m.node_tree
    nt.nodes.clear()
    b = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(b.outputs[0], nt.nodes.new("ShaderNodeOutputMaterial").inputs[0])
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
    mat("sangle", (0.40, 0.25, 0.18), 0.6)
    mat("sangle_botte", (0.27, 0.17, 0.13), 0.6)
    mat("semelle", (0.12, 0.10, 0.10), 0.7)
    mat("trou", (0.10, 0.06, 0.05), 0.8)
    mat("levre", (0.86, 0.56, 0.46), 0.5)
    mat("metal", (0.17, 0.19, 0.26), 0.35, 0.45)  # acier sombre bleuté de la planche
    mat("metal_bord", (0.62, 0.66, 0.74), 0.3, 0.55)
    mat("argent", (0.64, 0.64, 0.66), 0.25, 0.9)
    mat("peau", (0.98, 0.72, 0.55), 0.55)
    mat("cheveux", (0.97, 0.47, 0.15), 0.45)
    mat("cheveux_ombre", (0.80, 0.28, 0.08), 0.6)
    mat("sourcils", (0.55, 0.21, 0.06), 0.7)
    mat("paupiere", (0.16, 0.08, 0.06), 0.7)
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


def solidify(o, t, offset=0.0, even=True):
    mod = o.modifiers.new("solid", "SOLIDIFY")
    mod.thickness = t
    mod.offset = offset
    mod.use_even_offset = even
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


def clip(o, planes):
    """Découpe par des demi-espaces (point, normale) : ne garde que leur intersection, côté des normales."""
    bm = bmesh.new()
    bm.from_mesh(o.data)
    for co, no in planes:
        bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=Vector(co),
                               plane_no=Vector(no), clear_inner=True)
    bm.to_mesh(o.data)
    bm.free()
    o.data.update()
    return o


def clip_band(o, outer, inner):
    """Bande entre deux régions convexes : dans outer, hors de inner (rebords d'armure)."""
    clip(o, outer)
    bm = bmesh.new()
    bm.from_mesh(o.data)
    for co, no in inner:
        bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=Vector(co),
                               plane_no=Vector(no))
    dead = [f for f in bm.faces
            if all((f.calc_center_median() - Vector(co)).dot(Vector(no)) > 0 for co, no in inner)]
    bmesh.ops.delete(bm, geom=dead, context="FACES")
    bm.to_mesh(o.data)
    bm.free()
    o.data.update()
    return o


def on_surface(bvh, p, d, sink=0.004):
    """Point de la surface touché en venant de l'extérieur le long de -d (base d'une pointe)."""
    d = Vector(d).normalized()
    hit = bvh.ray_cast(Vector(p) + d * 0.5, -d)[0]
    return (hit if hit is not None else Vector(p)) - d * sink


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


def plate(name, center, normal, up, outline, m, bone, bulge=0.02, rim=0.01, curv=0.0, rim_m=None, thick=0.012,
          facet=False):
    """Plaque bombée à rebord (genouillère) : contour 2D (u, v) en mètres, rebord biseauté net,
    dôme central lisse (ou à facettes, arêtes partant de chaque sommet du contour)."""
    n, u, r = basis(normal, up)
    c = Vector(center)
    # (échelle du contour, hauteur) : rebord extérieur, arête du rebord, gorge, puis dôme
    levels = [(1.0, 0.0), (0.93, rim), (0.84, rim * 0.35), (0.66, bulge * 0.55), (0.42, bulge * 0.85),
              (0.2, bulge * 0.97)]
    N = len(outline)

    def P(ou, ov, h):
        return c + r * ou + u * ov + n * (h - curv * ou * ou)

    verts, faces = [], []
    for (s, h) in levels:
        for (ou, ov) in outline:
            verts.append(P(ou * s, ov * s, h))
    verts.append(P(0, 0, bulge))
    ctr = len(verts) - 1
    L = len(levels)
    for li in range(L - 1):
        for k in range(N):
            a = li * N + k
            b = li * N + (k + 1) % N
            faces.append((a, b, b + N, a + N))
    for k in range(N):
        faces.append(((L - 1) * N + k, (L - 1) * N + (k + 1) % N, ctr))
    o = add(name, verts, faces, m, bone, smooth=False)
    for i, pg in enumerate(o.data.polygons):
        pg.use_smooth = i >= 2 * N and not facet  # dôme lisse, rebord à arêtes vives
        if rim_m and i < N:
            pg.material_index = 1
    if rim_m:
        o.data.materials.append(MATS[rim_m])
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
    # z, cy, rx, ry_avant, ry_dos — relevés sur la planche : menton 1,56 m, mâchoire carrée (±7 cm à 1,58),
    # pommettes (±8,6 cm à 1,665), yeux à 1,683, sourcils à 1,70, sommet du crâne 1,85
    H = [
        (1.560, -0.075, 0.026, 0.018, 0.020),
        (1.568, -0.068, 0.042, 0.030, 0.040),
        (1.582, -0.056, 0.057, 0.046, 0.055),
        (1.600, -0.043, 0.068, 0.064, 0.068),
        (1.618, -0.035, 0.076, 0.077, 0.074),
        (1.640, -0.027, 0.083, 0.087, 0.082),
        (1.665, -0.022, 0.087, 0.093, 0.088),
        (1.690, -0.018, 0.087, 0.096, 0.094),
        (1.720, -0.014, 0.085, 0.094, 0.100),
        (1.760, -0.010, 0.082, 0.088, 0.100),
        (1.800, -0.006, 0.070, 0.075, 0.090),
        (1.835, 0.000, 0.045, 0.050, 0.065),
        (1.852, 0.000, 0.015, 0.015, 0.020),
    ]
    loft("tete", [((0, cy, z), rx, ryf, ryb) for z, cy, rx, ryf, ryb in H], "peau", "head", segs=28, p=2.3)
    loft("cou", [((0, 0.0, 1.44), 0.068, 0.066), ((0, -0.015, 1.585), 0.060, 0.058)], "peau", "neck",
         segs=16, caps=(False, False))
    # nez droit, pointe à 1,636, ailes du nez marquées
    loft("nez", [((0, -0.106, 1.705), 0.005, 0.004), ((0, -0.118, 1.675), 0.0065, 0.008),
                 ((0, -0.128, 1.645), 0.0085, 0.010), ((0, -0.130, 1.637), 0.009, 0.008),
                 ((0, -0.124, 1.630), 0.009, 0.006)], "peau", "head", segs=10)
    for s in (1, -1):
        ellipsoid(sname("narine", s), (0.011 * s, -0.116, 1.634), (0.008, 0.007, 0.006), "peau", "head", 10, 6)
        ellipsoid(sname("oreille", s), (0.084 * s, -0.005, 1.645), (0.013, 0.022, 0.030), "peau", "head", 10, 6)
        # anneau d'argent au lobe, petit clou au-dessus
        c = Vector((0.089 * s, -0.004, 1.617))
        loft(sname("boucle_oreille", s), [(c + Vector((0, 0.0075 * math.cos(a), 0.0075 * math.sin(a))), 0.0018, 0.0018)
                                          for a in [2 * math.pi * k / 12 for k in range(13)]], "argent", "head", segs=6)
        stud(sname("clou_oreille", s), (0.0945 * s, -0.008, 1.632), 0.0025, "head")
        # yeux étroits sous une paupière lourde qui descend vers le nez
        ellipsoid(sname("oeil", s), (0.043 * s, -0.1005, 1.683), (0.021, 0.007, 0.0065), "oeil", "head", 12, 6)
        ellipsoid(sname("iris", s), (0.041 * s, -0.1063, 1.6825), (0.0105, 0.0042, 0.0068), "iris", "head", 10, 6)
        R = Matrix.Rotation(math.radians(-10 * s), 3, "Y")
        box(sname("paupiere", s), (0.043 * s, -0.1066, 1.6885), (0.048, 0.009, 0.0085), "paupiere", "head", rot=R)
        # sourcils épais, froncés : bout intérieur bas (1,692), bout extérieur haut (1,708)
        brow = [(0.015, -0.1085, 1.6925), (0.035, -0.1095, 1.699), (0.056, -0.1065, 1.7065), (0.072, -0.099, 1.7075)]
        loft(sname("sourcil", s), [((x * s, y, z), h, 0.0045) for (x, y, z), h in
                                   zip(brow, (0.0055, 0.0072, 0.0065, 0.0035))], "sourcils", "head", segs=8)
    # large sourire en coin : les deux coins remontent, le gauche du personnage davantage
    mouth = [(-0.038, -0.1015, 1.620), (-0.02, -0.1085, 1.6135), (0.0, -0.1105, 1.611), (0.022, -0.1085, 1.6145),
             (0.038, -0.1025, 1.620), (0.046, -0.0965, 1.625)]
    loft("bouche", [(p, 0.0024, 0.0024) for p in mouth], "bouche", "head", segs=6)
    ellipsoid("levre", (0.0, -0.1065, 1.6035), (0.016, 0.006, 0.0045), "levre", "head", 10, 6)


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
        for k in range(7):
            p = a.lerp(b, (k + 0.5) / 7)
            loc, nrm = snap(bvh, p, 0.018)
            stud(f"revers_clou{k}" + (".L" if s > 0 else ".R"), loc - Vector((0.012 * s, 0, 0.01)), 0.0065, "chest")
        for k in range(4):
            p = b.lerp(c, (k + 0.5) / 4)
            loc, nrm = snap(bvh, p, 0.018)
            stud(f"revers_clouB{k}" + (".L" if s > 0 else ".R"), loc + Vector((0, 0, 0.012)), 0.0065, "chest")
    # perfecto : fermeture décalée — deux rangées de clous asymétriques jusqu'à la ceinture
    for label, x, z0, n_studs in (("D", -0.104, 1.30, 8), ("G", 0.047, 1.22, 6)):
        for k in range(n_studs):
            loc, nrm = snap(bvh, (x, -0.3, z0 - k * (z0 - 1.035) / (n_studs - 1)), 0.004)
            stud(f"veste_clou{label}{k}", loc, 0.0058, "spine")
    # fermetures éclair : poche en biais sur la poitrine gauche du personnage, courte à droite
    for label, pa, pb in (("G", (0.172, 1.315), (0.096, 1.249)), ("D", (-0.157, 1.215), (-0.142, 1.165))):
        a, _ = snap(bvh, (pa[0], -0.3, pa[1]), 0.005)
        b, _ = snap(bvh, (pb[0], -0.3, pb[1]), 0.005)
        d = (b - a)
        n = Vector((0, -1, 0))
        r = d.normalized().cross(n).normalized()
        R = Matrix((r, n, d.normalized())).transposed()
        box("zip" + label, (a + b) / 2, (0.009, 0.005, d.length), "argent", "chest", rot=R)
        box("zip_tirette" + label, a + d * 0.12 + Vector((0, -0.004, 0)), (0.007, 0.004, 0.016), "argent", "chest",
            rot=R)


# ---------------------------------------------------------------- bras et mains
def build_arms():
    for s in (1, -1):
        side = ".L" if s > 0 else ".R"
        sh, el, wr, d2 = arm_points(s)
        d1 = (el - sh).normalized()
        # manche de cuir retroussée au coude
        loft("bras" + side, [(sh, 0.080, 0.078), (sh.lerp(el, 0.45), 0.081, 0.078), (el + d2 * 0.02, 0.073, 0.071)],
             "cuir", "upper_arm" + side, segs=14)
        # manche roulée au coude : bourrelet, clous côté extérieur, bouton-pression devant
        c = el + d2 * 0.012
        band("manchette" + side, c, 0.086, 0.083, 0.055, "cuir_use", "forearm" + side, axis=d2)
        x, y = frame(d2)
        a_out = math.pi if s > 0 else 0.0
        for k in range(7):
            a = a_out + math.radians(-75 + 25 * k) * s
            stud(f"clou_manchette{side}{k}", c + (x * math.cos(a) * 0.088 + y * math.sin(a) * 0.085), 0.0062,
                 "forearm" + side)
        a = a_out - math.radians(115) * s
        pb = c + (x * math.cos(a) * 0.089 + y * math.sin(a) * 0.086) + d2 * 0.012
        loft(f"pression{side}", [(pb + Vector((0, -0.003, 0)) + Vector((0.0068 * math.cos(t), 0, 0.0068 * math.sin(t))),
                                  0.0018, 0.0018) for t in [2 * math.pi * k / 10 for k in range(11)]],
             "argent", "forearm" + side, segs=5)
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
            dirv = (dirv + n * 0.42).normalized()  # les doigts se replient vers la paume
            p = p + dirv * seg
            pts.append(p)
        loft(f"doigt{fi}_gant{side}", [(pts[0], r + 0.002, r + 0.002), (pts[0].lerp(pts[1], 0.55), r + 0.002, r + 0.002)],
             "cuir", bone, segs=8, ref=w)
        loft(f"doigt{fi}{side}", [(pts[0].lerp(pts[1], 0.3), r, r), (pts[1], r, r), (pts[2], r * 0.95, r * 0.95),
                                  (pts[3], r * 0.85, r * 0.85)], "peau", bone, segs=8, ref=w)
    # pouce, côté paume : main gauche en +X, main droite en -X (chiralité correcte)
    p0 = wr + d * 0.035 + w * 0.045 + n * 0.012
    p1 = p0 + (d * 0.5 + w * 0.7 + n * 0.3).normalized() * 0.034
    p2 = p1 + (d * 0.8 + w * 0.3 + n * 0.45).normalized() * 0.029
    p3 = p2 + (d * 0.9 + n * 0.45).normalized() * 0.022
    loft("pouce_gant" + side, [(p0, 0.017, 0.017), (p0.lerp(p1, 0.6), 0.016, 0.016)], "cuir", bone, segs=8)
    loft("pouce" + side, [(p0.lerp(p1, 0.4), 0.015, 0.015), (p1, 0.015, 0.015), (p2, 0.0135, 0.0135),
                          (p3, 0.012, 0.012)], "peau", bone, segs=8)
    # mains surdimensionnées comme sur la planche (bout des doigts vers 0,70 m)
    S = Matrix.Diagonal(Vector((1.3, 1.3, 1.3)))
    for o in list(col().objects):
        if o.name not in before:
            xform(o, wr - d * 0.05, S)


# ---------------------------------------------------------------- jambes et bottes
# genouillère en écusson : haut légèrement bombé, plus large au tiers supérieur, pointe en bas
# (15,7 x 21,7 cm sur la planche)
HEX = [(-0.058, 0.103), (0.0, 0.109), (0.058, 0.103), (0.077, 0.072), (0.078, 0.018), (0.036, -0.05), (0.0, -0.108),
       (-0.036, -0.05), (-0.078, 0.018), (-0.077, 0.072)]


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
        plate("genouillere" + side, knee + Vector((0, -0.098, 0.014)), (0, -1, -0.06), (0, 0, 1), HEX, "metal",
              "shin" + side, bulge=0.042, rim=0.015, curv=4.0, rim_m="metal_bord", thick=0.02, facet=True)
        # sangle marron derrière la genouillère, rivet sur le côté extérieur
        cs = knee + Vector((0, 0.006, -0.004))
        band("genou_sangle" + side, cs, 0.084, 0.087, 0.02, "sangle_botte", "thigh" + side)
        stud("genou_rivet" + side, cs + Vector((0.085 * s, 0.0, 0)), 0.0055, "thigh" + side)
        build_boot(s)


def build_boot(s):
    side = ".L" if s > 0 else ".R"
    hip, knee, ankle = leg_points(s)
    fb = "foot" + side
    sb = "shin" + side
    top = 0.42
    loft("tige_botte" + side, [(leg_at(s, 0.09), 0.064, 0.072), (leg_at(s, 0.20), 0.070, 0.074),
                               (leg_at(s, 0.33), 0.075, 0.077), (leg_at(s, top), 0.079, 0.080)],
         "cuir", sb, segs=20, caps=(True, False))
    # revers : large sangle marron, pyramides et clous ronds alternés devant, boucle côté extérieur,
    # pointe côté intérieur
    c = leg_at(s, 0.39)
    band("botte_revers" + side, c, 0.086, 0.088, 0.066, "sangle_botte", sb, segs=24)
    for k in range(5):
        a = -math.pi / 2 + math.radians(-56 + 28 * k)
        dirv = Vector((math.cos(a), math.sin(a), 0))
        p = c + Vector((dirv.x * 0.087, dirv.y * 0.089, 0))
        if k % 2 == 0:
            spike(f"botte_pyramide{k}" + side, p, dirv + Vector((0, 0, 0.25)), 0.02, 0.012, sb)
        else:
            stud(f"botte_clou{k}" + side, p, 0.0085, sb)
    spike("botte_pointe" + side, c + Vector((-0.087 * s, -0.012, 0)), (-s, -0.15, 0.1), 0.026, 0.011, sb)
    buckle("botte_boucle0" + side, c + Vector((0.09 * s, 0.01, 0)), (s, 0, 0), (0, 0, 1), 0.058, 0.07, 0.009, sb)
    # sangle à mi-tige, grosse boucle côté extérieur
    c = leg_at(s, 0.25)
    band("botte_sangle" + side, c, 0.077, 0.079, 0.055, "sangle_botte", sb, segs=24)
    buckle("botte_boucle1" + side, c + Vector((0.081 * s, 0.004, 0)), (s, 0, 0), (0, 0, 1), 0.052, 0.066, 0.009, sb)
    stud("botte_rivet" + side, c + Vector((0.052 * s, -0.058, 0)), 0.006, sb)
    # pied (construit pointe vers -Y puis ouvert de FOOT_SPLAY) : bout large et arrondi
    ax, ay = ankle.x, ankle.y
    F = [  # y local, z centre, demi-hauteur, demi-largeur
        (0.075, 0.085, 0.062, 0.050),
        (0.030, 0.090, 0.080, 0.060),
        (-0.040, 0.088, 0.064, 0.066),  # cambrure dégagée entre talon et semelle
        (-0.110, 0.070, 0.058, 0.068),
        (-0.170, 0.060, 0.045, 0.068),
        (-0.215, 0.057, 0.039, 0.065),
        (-0.248, 0.054, 0.031, 0.055),
        (-0.268, 0.051, 0.021, 0.041),
        (-0.279, 0.049, 0.009, 0.021),
    ]
    parts = [loft("pied" + side, [((ax, ay + ly, zc), h, w) for ly, zc, h, w in F], "cuir", fb, segs=20, p=2.6)]
    # semelle épaisse qui suit le contour du pied, talon carré
    S = [(-0.286, 0.012), (-0.279, 0.034), (-0.264, 0.051), (-0.236, 0.063), (-0.19, 0.071), (-0.12, 0.073),
         (-0.05, 0.069), (-0.012, 0.062)]
    parts.append(loft("semelle" + side, [((ax, ay + ly, 0.016), 0.016, w) for ly, w in S], "semelle", fb,
                      segs=20, p=3.0))
    parts.append(box("talon" + side, (ax, ay + 0.04, 0.029), (0.104, 0.09, 0.058), "semelle", fb))
    # coque d'acier sur le bout, bord arrière clair, trois pointes et un clou
    cap = [((ax, ay + ly, zc + 0.003), h + 0.007, w + 0.007) for ly, zc, h, w in F[4:]]
    parts.append(loft("embout" + side, cap, "metal", fb, segs=20, p=2.6, caps=(False, True)))
    parts.append(loft("embout_bord" + side, [(cap[0][0], cap[0][1] + 0.004, cap[0][2] + 0.004),
                                             ((ax, ay - 0.182, 0.062), 0.051, 0.074)], "metal_bord", fb,
                      segs=20, p=2.6, caps=(False, False)))
    bvh = bvh_of(parts[-2])
    for nm, p, d, ln, r in (("pointe_bout", (ax + 0.012 * s, ay - 0.262, 0.066), (0.3 * s, -1, 0.7), 0.05, 0.016),
                            ("pointe_bout_ext", (ax + 0.052 * s, ay - 0.215, 0.058), (s, -0.3, 0.12), 0.056, 0.017),
                            ("pointe_bout_int", (ax - 0.052 * s, ay - 0.215, 0.058), (-s, -0.3, 0.12), 0.05, 0.016)):
        parts.append(spike(nm + side, on_surface(bvh, p, d), d, ln, r, fb))
    parts.append(stud("embout_clou" + side, on_surface(bvh, (ax, ay - 0.2, 0.1), (0, -0.3, 1), 0.001), 0.009, fb,
                      m="metal_bord"))
    parts.append(spike("eperon" + side, (ax, ay + 0.085, 0.07), (0, 1, 0.05), 0.035, 0.012, fb))
    # sangle de cheville inclinée (haute sur le cou-de-pied et dehors, basse au talon et dedans), clous devant,
    # boucle dehors
    ca = Vector((ax, ay - 0.012, 0.14))
    axis = Vector((-0.2 * s, 0.6, 1)).normalized()
    parts.append(band("cheville_sangle" + side, ca, 0.074, 0.086, 0.028, "sangle_botte", fb, axis=axis, segs=20))
    x, y = frame(axis)
    for k in range(5):
        a = -math.pi / 2 + math.radians(-50 + 25 * k)  # autour de l'avant
        dirv = (x * math.cos(a) + y * math.sin(a)).normalized()
        pt = ca + x * math.cos(a) * 0.075 + y * math.sin(a) * 0.087
        if k % 2 == 0:
            parts.append(spike(f"cheville_pyramide{k}" + side, pt, dirv + axis * 0.2, 0.012, 0.008, fb))
        else:
            parts.append(stud(f"cheville_clou{k}" + side, pt, 0.0062, fb))
    a = -FOOT_SPLAY if s > 0 else math.pi + FOOT_SPLAY  # plein côté extérieur une fois le pied ouvert
    pb = ca + x * math.cos(a) * 0.077 + y * math.sin(a) * 0.087
    parts.append(buckle("cheville_boucle" + side, pb, x * math.cos(a) + y * math.sin(a), axis, 0.046, 0.044, 0.008,
                        fb))
    R = Matrix.Rotation(FOOT_SPLAY * s, 3, "Z")
    for o in parts:
        xform(o, (ax, ay, 0), R)


# ---------------------------------------------------------------- tenue
def build_belt():
    loft("ceinture", [((0, 0.0, 0.961), 0.187, 0.148, 0.132), ((0, 0.0, 1.019), 0.187, 0.148, 0.132)], "sangle", "hips",
         segs=28, p=2.3, caps=(False, False))
    # deux rangées de clous, pointes aux hanches
    n = 30
    for row, z in enumerate((1.004, 0.976)):
        for k in range(n):
            a = 2 * math.pi * (k + 0.5 * row) / n
            ca, sa = math.cos(a), math.sin(a)
            px = spow(ca, 2 / 2.3) * 0.19
            py = spow(sa, 2 / 2.3) * (0.151 if sa < 0 else 0.135)
            if -0.085 < px < 0.075 and py < 0:
                continue
            stud(f"ceinture_clou{row}_{k}", (px, py, z), 0.0062, "hips")
    for s in (1, -1):
        for k, dz in enumerate((0.012, -0.012)):
            spike(f"ceinture_pointe{k}" + ("G" if s > 0 else "D"), (0.186 * s, -0.035, 0.99 + dz), (s, -0.35, 0), 0.02,
                  0.007, "hips")
    # grosse boucle décentrée, passant d'argent et bout de ceinture qui dépasse
    buckle("ceinture_boucle", (-0.023, -0.154, 0.99), (0, -1, 0), (0, 0, 1), 0.092, 0.074, 0.015, "hips",
           depth=0.012)
    box("ceinture_passant", (0.048, -0.153, 0.99), (0.013, 0.007, 0.066), "argent", "hips")
    R = Matrix.Rotation(math.radians(-18), 3, "Z")
    box("ceinture_bout", (0.098, -0.146, 0.99), (0.075, 0.007, 0.046), "sangle", "hips", rot=R)
    loft("ceinture_bout_pointe", [((0.134, -0.134, 0.99), 0.023, 0.0035), ((0.15, -0.126, 0.99), 0.004, 0.0035)],
         "sangle", "hips", segs=4, smooth=False)


def build_neck_gear():
    band("collier", (0, -0.004, 1.52), 0.070, 0.068, 0.032, "cuir", "neck", segs=18)
    # clous ronds sur l'avant, petites pointes sur les côtés
    for k in range(18):
        a = 2 * math.pi * (k + 0.5) / 18
        dirv = Vector((math.cos(a), math.sin(a), 0))
        p = Vector((0, -0.004, 1.52)) + Vector((dirv.x * 0.071, dirv.y * 0.069, 0))
        if dirv.y < -0.55:
            stud(f"collier_clou{k}", p, 0.0058, "neck")
        elif dirv.y < 0.3:
            spike(f"collier_pointe{k}", p, dirv, 0.014, 0.0058, "neck")
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
    loft("gemme", [((0, -0.145, 1.404), 0.001, 0.001), ((0, -0.149, 1.372), 0.021, 0.014),
                   ((0, -0.145, 1.338), 0.001, 0.001)], "gemme", "chest", segs=4, smooth=False)


def build_pauldrons():
    for s in (1, -1):
        side = ".L" if s > 0 else ".R"
        bone = "upper_arm" + side
        R = Matrix.Rotation(math.radians(20 * s), 3, "Y")
        c = Vector((0.272 * s, 0.0, 1.40))
        k = 0.77  # pente du chevron vu de face (et de dos)

        def region(w):
            """Contour du dôme vu de face, rétréci de w : bord intérieur vertical le long du col,
            biais descendant puis bord horizontal au-dessus du bras."""
            return [((0.178 * s + w * s, 0, 0), (s, 0, 0)), ((0, 0, 1.384 + w), (0, 0, 1)),
                    ((0.178 * s, 0, 1.457 + w * math.hypot(1, k)), (k * s, 0, 1))]

        def dome(name, m, e):
            """Dôme grossi de e, incliné vers l'extérieur : vu de face, carré à sommet plat (haut bord intérieur
            le long du col) ; de profil, cloche basse à flancs obliques."""
            secs = []
            for i in range(17):
                t = -0.3 + 1.3 * math.sin(math.pi / 2 * i / 16)
                fx = 1.0 if t <= 0 else max((1 - t ** 3) ** 0.5, 0.03)
                fy = 1.0 if t <= 0 else max((1 - t ** 1.6) ** 0.5, 0.03)
                secs.append(((c.x, c.y, c.z + t * (0.172 + e)), (0.13 + e) * fx, (0.162 + e) * fy))
            o = loft(name, secs, m, bone, segs=40, p=2.4, caps=(False, True))
            xform(o, c, R)
            return o

        def lame(name, m, e):
            """Lame basse : tronc de cône évasé vers le bas, sous le dôme."""
            secs = [((c.x + 0.012 * s, c.y, c.z + dz), (0.125 + e) * f, (0.15 + e) * f)
                    for dz, f in ((-0.11, 1.12), (-0.07, 1.06), (-0.03, 0.99), (0.01, 0.92))]
            o = loft(name, secs, m, bone, segs=40, p=2.4, caps=(False, False))
            xform(o, c, R)
            return o

        # dôme (coque épaisse) et rebord clair biseauté qui le borde
        o = clip(dome("epauliere" + side, "metal", 0.0), region(0))
        solidify(o, 0.016, offset=-1.0)
        bvh = bvh_of(o)
        rim = dome("epauliere_bord" + side, "metal_bord", 0.006)
        clip_band(rim, region(-0.005), region(0.026))
        solidify(rim, 0.024, offset=-1.0)
        # lame inférieure évasée, bord supérieur clair
        o = clip(lame("epauliere_lame" + side, "metal", 0.0),
                 [((0.27 * s, 0, 0), (s, 0, 0)), ((0, 0, 1.33), (0, 0, 1)), ((0, 0, 1.392), (0, 0, -1))])
        solidify(o, 0.013, offset=-1.0)
        o = clip(lame("epauliere_lame_bord" + side, "metal_bord", 0.005),
                 [((0.266 * s, 0, 0), (s, 0, 0)), ((0, 0, 1.362), (0, 0, 1)), ((0, 0, 1.392), (0, 0, -1))])
        solidify(o, 0.018, offset=-1.0)
        # pointes : dressée, vers l'extérieur, vers l'avant et vers l'arrière (cônes sur les faces)
        for nm, p, d, ln, r in (("pointe_haut", (0.282 * s, 0.0, 1.5), (0.25 * s, 0, 1), 0.115, 0.027),
                                ("pointe_ext", (0.345 * s, 0.0, 1.49), (1.3 * s, 0, 1), 0.112, 0.028),
                                ("pointe_faceA", (0.268 * s, -0.15, 1.45), (0.12 * s, -1, 0.75), 0.08, 0.025),
                                ("pointe_faceD", (0.268 * s, 0.15, 1.45), (0.12 * s, 1, 0.75), 0.08, 0.025)):
            spike(nm + side, on_surface(bvh, p, d), d, ln, r, bone)


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
            # croisement à 1,25 m devant (1,21 m dans le dos), boucle sous l'épaulière, sortie sur le flanc à 1,13 m
            if fy < 0:
                ctrl = [(0.22 * s, -0.3, 1.40), (-0.17 * s, -0.3, 1.132), (-0.222 * s, -0.12, 1.114),
                        (-0.236 * s, 0.0, 1.108)]
            else:
                ctrl = [(0.22 * s, 0.3, 1.39), (-0.175 * s, 0.3, 1.134), (-0.24 * s, 0.14, 1.112)]
            ctrl = [Vector(c) for c in ctrl]
            a, b = ctrl[0], ctrl[1]  # partie droite (boucle, trous)
            d = (b - a).normalized()
            pts = []
            for c0, c1 in zip(ctrl, ctrl[1:]):
                k = max(2, int((c1 - c0).length / 0.02))
                pts += [c0.lerp(c1, i / k) for i in range(k)]
            pts.append(ctrl[-1])
            verts, faces = [], []
            for i, p in enumerate(pts):
                t = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
                side = (Vector((0, 0, 1)) - t * t.z).normalized()  # largeur de la sangle ⟂ au trajet
                verts += [p - side * 0.023, p + side * 0.023]
            for i in range(len(pts) - 1):
                faces.append((2 * i, 2 * i + 1, 2 * i + 3, 2 * i + 2))
            o = add(sname("sangle_" + label, s), verts, faces, "sangle", "chest")
            shrink(o, target, 0.011)
            solidify(o, 0.01)
            # grosse boucle carrée en haut de la bandoulière
            pb = a.lerp(b, 0.16)
            loc, nrm = snap(bvh, pb, 0.024)
            buckle(sname("sangle_boucle_" + label, s), loc, nrm, -d, 0.068, 0.064, 0.012, "chest", depth=0.01)
            # trous de la sangle, sous la boucle et vers le croisement
            if fy < 0:
                for k, t in enumerate((0.24, 0.3, 0.36, 0.5)):
                    loc, nrm = snap(bvh, a.lerp(b, t), 0.0165)
                    stud(sname(f"sangle_trou{k}_", s), loc, 0.0042, "chest", m="trou")
    bpy.data.objects.remove(LISSE, do_unlink=True)


# ---------------------------------------------------------------- crinière
HAIR = [  # z, cy, rx, ry_avant, ry_dos  (volume de base en cloche ; les mèches ajoutent ~4 cm tout autour)
    (1.885, 0.010, 0.020, 0.020, 0.020),
    (1.870, 0.010, 0.050, 0.060, 0.065),
    (1.848, 0.005, 0.078, 0.090, 0.118),
    (1.825, 0.000, 0.100, 0.100, 0.145),
    (1.795, 0.000, 0.116, 0.100, 0.162),
    (1.775, 0.000, 0.126, 0.101, 0.172),
    (1.760, 0.006, 0.136, 0.098, 0.178),
    (1.742, 0.020, 0.146, 0.035, 0.184),
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


def env_frame(phi, z):
    """Point de l'enveloppe et normale sortante (différences finies)."""
    p = hair_env(phi, z)
    n = (hair_env(phi + 1e-3, z) - hair_env(phi - 1e-3, z)).cross(hair_env(phi, z + 1e-3) - hair_env(phi, z - 1e-3))
    radial = Vector((math.sin(phi), math.cos(phi), 0))
    if n.length < 1e-9:
        return p, radial
    n.normalize()
    return p, (n if n.dot(radial) >= 0 else -n)


def hair_strip(name, phi_c, z0, z1, half, height, amp, waves, ph, curl, lift=0.0, nz=44, nu=8):
    """Mèche en relief posée sur l'enveloppe : section en dôme (bords au ras de l'enveloppe), trajet en S,
    pointe effilée qui part sur le côté (curl, en radians) et se décolle."""
    verts, faces = [], []
    for j in range(nz + 1):
        t = j / nz
        z = z0 + (z1 - z0) * t
        pc = phi_c + amp * math.sin(2 * math.pi * waves * t + ph)
        k = max(0.0, (t - 0.72) / 0.28)
        pc += curl * k * k
        taper = min(1.0, 0.45 + t / 0.1) * (1 - k ** 1.6)
        for i in range(nu + 1):
            u = -1 + 2 * i / nu
            p, n = env_frame(pc + u * half * max(taper, 0.03), z)
            r = lift + height * (0.25 + 0.75 * taper) * (1 - u * u) ** 0.6 + 0.02 * k * k
            verts.append(p + n * r)
    for j in range(nz):
        for i in range(nu):
            a = j * (nu + 1) + i
            faces.append((a, a + 1, a + nu + 2, a + nu + 1))
    o = add(name, verts, faces, "cheveux", "head")
    solidify(o, 0.004, offset=-1.0, even=False)  # pointes dégénérées : pas d'épaisseur « égale »
    return o


def build_hair():
    # l'enveloppe HAIR guide les mèches ; le volume visible est en retrait dessous (ombre entre les mèches)
    # et s'arrête au-dessus des pointes, qui pendent librement
    env = loft("cheveux_env", [((hair_dx(z), cy, z), rx, ryf, ryb) for z, cy, rx, ryf, ryb in HAIR], "cheveux_ombre",
               "head", segs=32, p=2.0)
    bvh = bvh_of(env)
    bpy.data.objects.remove(env, do_unlink=True)
    # (plus étroit sous 1,62 m : ne déborde pas à côté du cou, vu de face)
    rows = [((hair_dx(z), cy, z), rx - 0.016 - (0.05 if z < 1.62 else 0.0), max(ryf - 0.016, 0.0), ryb - 0.016)
            for z, cy, rx, ryf, ryb in HAIR if z >= 1.42]
    base = loft("cheveux", rows + [((0.0, 0.118, 1.40), 0.11, 0.0, 0.075)], "cheveux_ombre", "head", segs=32, p=2.0)
    rnd = random.Random(5)
    n_lock = [0]

    hb = bvh_of(bpy.data.objects["tete"])

    def over(p):
        """Posé sur la peau (+1,2 cm) sous 1,75 m, ailleurs sur ce qui est le plus à l'extérieur (peau ou
        enveloppe) : l'enveloppe n'a pas de devant sous le front."""
        b, nb = snap(hb, p)
        b = b + nb * 0.012
        if p.z < 1.75:
            return b, nb
        a, na = snap(bvh, p)
        c = Vector((0, 0.0, p.z))
        return (a, na) if (a - c).length >= (b - c).length else (b, nb)

    def make_lock(raw, width, bone="head", curl=0.03, waves=1.5, snapper=None):
        n = len(raw)
        snapped = [snapper(p) if snapper else snap(bvh, p) for p in raw]
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
            w = width * min(1.0, 0.6 + 1.8 * s) * (1 - s ** 2.5) * (1 + 0.08 * math.cos(4 * math.pi * waves * s)) + 0.003
            th = max(0.008, 0.6 * w)
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
    # dos : mèches en relief jointives, ondulées en S, pointes recourbées sur le côté
    N = 11
    sp = math.radians(210 / (N - 1))
    for i in range(N):
        phi0 = math.radians(-105 + 210 * i / (N - 1))
        side = abs(phi0) / math.radians(118)
        z1 = 1.305 + 0.25 * side ** 1.6 + rnd.uniform(-0.01, 0.02)
        curl = sp * (1.0 if i % 2 else -1.0) if abs(phi0) < math.radians(70) else -sp * math.copysign(1, phi0)
        hair_strip(f"meche_dos{i}", phi0, 1.875, z1, sp * 0.58, 0.028, sp * 0.55, 2.6, 0.4 + rnd.uniform(-0.3, 0.3),
                   curl)
    # seconde couche par-dessus, plus courte, décalée d'une demi-mèche
    for i in range(N - 1):
        phi0 = math.radians(-105 + 210 * (i + 0.5) / (N - 1))
        side = abs(phi0) / math.radians(118)
        z1 = 1.47 + 0.12 * side ** 2 + rnd.uniform(-0.03, 0.05)
        curl = sp * (1.0 if i % 2 else -1.0) if abs(phi0) < math.radians(70) else -sp * math.copysign(1, phi0)
        hair_strip(f"meche_dos_b{i}", phi0, 1.83, z1, sp * 0.52, 0.025, sp * 0.55, 2.0, 0.4 + rnd.uniform(-0.3, 0.3),
                   curl, lift=0.016)
    # boucles qui encadrent le visage (tempes -> épaules), pointes relevées vers l'extérieur
    for s in (1, -1):
        for k in range(4):
            phi0 = s * math.radians(112 + 9 * k)
            make_lock(path(phi0, 1.80, 1.50 + 0.016 * k, math.radians(9), 1.4, n=24, ph=k), 0.052, curl=0.06,
                      waves=1.4)
    # rideaux : de la raie (un peu à gauche du personnage), les mèches passent au-dessus des tempes et tombent le
    # long des joues, pointes relevées vers l'extérieur ; le front reste dégagé au milieu
    part = 0.022
    for s, reach in ((-1, 1.60), (1, 1.56)):
        for k, (dx, dy) in enumerate(((0.0, 0.0), (0.026, 0.028), (0.05, 0.056))):
            ctrl = [(part, -0.02 + dy * 0.5, 1.885), (part + s * (0.045 + dx * 0.6), -0.095 + dy, 1.855),
                    (s * (0.07 + dx), -0.105 + dy, 1.79), (s * (0.09 + dx), -0.08 + dy, 1.73),
                    (s * (0.097 + dx), -0.055 + dy, 1.67), (s * (0.10 + dx), -0.04 + dy, reach + 0.04 - k * 0.01),
                    (s * (0.13 + dx), -0.03 + dy, reach - k * 0.01)]
            make_lock(catmull(ctrl, 28), 0.032, curl=0.05, waves=1.2, snapper=over)
    # houppe : du front, grosses mèches qui montent et se rabattent, surtout vers la gauche du personnage
    for k, (x0, sw) in enumerate(((-0.06, -0.10), (-0.02, 0.12), (0.02, 0.16), (0.06, 0.17), (-0.085, -0.13))):
        ctrl = [(x0, -0.098, 1.782), (x0 + sw * 0.25, -0.10, 1.845), (x0 + sw * 0.6, -0.04, 1.885),
                (x0 + sw * 0.9, 0.05, 1.865), (x0 + sw, 0.12, 1.79), (x0 + sw * 1.05, 0.16, 1.70)]
        make_lock(catmull(ctrl, 26), 0.05, curl=0.0, waves=1.0)
    # pointe de cheveux au milieu du front (descend jusqu'à 1,752 m)
    pk = [Vector(p) for p in ((0.0, -0.099, 1.795), (0.0, -0.103, 1.778), (0.002, -0.1045, 1.763), (0.004, -0.1045, 1.752))]
    ribbon("meche_pointe", pk, [Vector((0, -1, 0.15)).normalized()] * 4, [0.03, 0.024, 0.013, 0.003],
           [0.006, 0.006, 0.005, 0.003], "cheveux", "head", segs=8)
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
