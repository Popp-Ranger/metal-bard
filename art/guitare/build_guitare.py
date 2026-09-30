# Guitare des héros — Flying V « démoniaque » (Blender 5.2), calée sur docs/concept/guitare_planche.jpg.
# Repère : manche vers +Z, face avant vers -Y, origine à la jonction manche / corps.
# Après export glTF : manche vers +Y, face vers +Z, comme _build_flying_v dans HeroModel.
# Échelle : 1,15 m de long, 0,575 m d'envergure (624 px/m sur la planche). Sangles non modélisées.
#
# Usage dans Blender : exec(open(PATH).read()) puis build_guitar() ; join_guitar() ; export_guitar(path).
import bpy, math
from mathutils import Vector, Matrix

_HERE = r"C:\Users\Ody\OneDrive\Bureau\Claude Code\metal-bard\art"
exec(open(_HERE + r"\riffald\build_riffald.py", encoding="utf-8").read())  # utilitaires communs

COL_NAME = "Guitare"
COL = None
MATS = {}
T = 0.05  # épaisseur du corps
YF = -T / 2  # face avant du corps
BORDER = 0.017  # largeur du cadre d'acier


def materials_g():
    mat("g_cadre", (0.46, 0.47, 0.52), 0.3, 0.6)
    mat("g_armure", (0.40, 0.41, 0.45), 0.3, 0.6)
    mat("g_acier", (0.25, 0.24, 0.26), 0.4, 0.6)
    mat("g_plaque", (0.21, 0.22, 0.26), 0.45, 0.5)
    mat("g_bordeaux", (0.45, 0.08, 0.19), 0.7)
    mat("g_touche", (0.17, 0.11, 0.09), 0.6)
    mat("g_manche", (0.32, 0.20, 0.14), 0.55)
    mat("g_argent", (0.76, 0.76, 0.78), 0.25, 0.9)
    mat("g_cordes", (0.82, 0.82, 0.85), 0.2, 1.0)
    mat("g_nacre", (0.88, 0.84, 0.70), 0.3)
    mat("g_noir", (0.07, 0.07, 0.08), 0.5)
    mat("g_os", (0.90, 0.87, 0.78), 0.4)
    mat("g_gemme", (0.90, 0.06, 0.20), 0.15, 0.0, 3.0)


# ---------------------------------------------------------------- contours 2D (x, z) et extrusions
def _area(pts):
    return 0.5 * sum(pts[i][0] * pts[(i + 1) % len(pts)][1] - pts[(i + 1) % len(pts)][0] * pts[i][1]
                     for i in range(len(pts)))


def offset_poly(pts, d):
    """Décale un contour fermé de d vers l'intérieur (onglets aux sommets, limités aux pointes)."""
    s = 1.0 if _area(pts) < 0 else -1.0
    n = len(pts)
    out = []
    for i in range(n):
        p0, p1, p2 = Vector(pts[i - 1]), Vector(pts[i]), Vector(pts[(i + 1) % n])
        e1 = (p1 - p0).normalized()
        e2 = (p2 - p1).normalized()
        n1 = Vector((e1.y, -e1.x)) * s
        n2 = Vector((e2.y, -e2.x)) * s
        m = n1 + n2
        m = m.normalized() if m.length > 1e-6 else n1
        k = d / max(0.3, m.dot(n1))
        q = p1 + m * k
        out.append((q.x, q.y))
    return out


def extrude(name, pts, y0, y1, m, bone="guitare", wall_m=None):
    """Prisme : contour (x, z) extrudé de y0 (avant) à y1 (arrière)."""
    n = len(pts)
    verts = [(x, y0, z) for x, z in pts] + [(x, y1, z) for x, z in pts]
    faces = [tuple(range(n)), tuple(n + i for i in reversed(range(n)))]
    faces += [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    o = add(name, verts, faces, m, bone, smooth=False)
    if wall_m:
        o.data.materials.append(MATS[wall_m])
        for pg in o.data.polygons[2:]:
            pg.material_index = 1
    return o


def frame_ring(name, outer, inner, y0, y1, m, bone="guitare", wall_m=None):
    """Cadre entre deux contours de même nombre de sommets (bord d'acier biseauté)."""
    n = len(outer)
    verts = ([(x, y0, z) for x, z in outer] + [(x, y0, z) for x, z in inner] +
             [(x, y1, z) for x, z in outer] + [(x, y1, z) for x, z in inner])
    faces, walls = [], []
    for i in range(n):
        j = (i + 1) % n
        faces.append((i, j, n + j, n + i))  # avant
        faces.append((2 * n + i, 3 * n + i, 3 * n + j, 2 * n + j))  # arrière
        walls.append((i, 2 * n + i, 2 * n + j, j))  # paroi extérieure
        faces.append((n + i, n + j, 3 * n + j, 3 * n + i))  # paroi intérieure
    o = add(name, verts, faces + walls, m, bone, smooth=False)
    if wall_m:
        o.data.materials.append(MATS[wall_m])
        for pg in o.data.polygons[len(faces):]:
            pg.material_index = 1
    return o


def rod(name, a, b, r, m, bone="guitare", segs=4):
    return loft(name, [(Vector(a), r, r), (Vector(b), r, r)], m, bone, segs=segs, caps=(False, False),
                smooth=False)


def gem(name, c, h, w, depth, y_dir=-1):
    """Gemme en losange à facettes, posée face vers y_dir."""
    c = Vector(c)
    d = Vector((0, y_dir, 0))
    return loft(name, [(c, h, w), (c + d * depth * 0.6, h * 0.7, w * 0.7), (c + d * depth, 0.001, 0.001)],
                "g_gemme", "guitare", segs=4, smooth=False)


def mirror_pts(right):
    """Contour symétrique : moitié droite de haut en bas (x >= 0), refermée par la moitié gauche."""
    left = [(-x, z) for x, z in reversed(right[1:-1])]
    return right + left


# ---------------------------------------------------------------- corps en V
BODY_R = [(0.0, 0.012), (0.118, 0.012), (0.138, -0.045), (0.124, -0.078), (0.136, -0.10), (0.236, -0.40),
          (0.268, -0.495), (0.286, -0.553), (0.238, -0.535), (0.18, -0.488), (0.062, -0.338), (0.034, -0.314),
          (0.0, -0.304)]
PLATE = [(-0.055, -0.02), (0.068, -0.02), (0.108, -0.065), (0.128, -0.125), (0.21, -0.39), (0.175, -0.372),
         (0.085, -0.262), (0.05, -0.232), (0.0, -0.225), (-0.05, -0.232), (-0.085, -0.262), (-0.152, -0.29),
         (-0.125, -0.16), (-0.095, -0.07)]
SHIELD = [(-0.062, 0.05), (0.062, 0.05), (0.056, -0.06), (0.032, -0.16), (0.0, -0.225), (-0.032, -0.16),
          (-0.056, -0.06)]


def build_body():
    outline = mirror_pts(BODY_R)
    core = offset_poly(outline, BORDER)
    extrude("corps", core, YF, -YF, "g_bordeaux")
    frame_ring("corps_cadre", outline, core, YF - 0.005, -YF + 0.005, "g_cadre", wall_m="g_acier")
    # rivets sur la tranche des ailes
    for s in (1, -1):
        for kind, a, b, n in (("ext", (0.136, -0.10), (0.236, -0.40), 6), ("int", (0.062, -0.338), (0.18, -0.488), 3)):
            a, b = Vector(a), Vector(b)
            e = (b - a).normalized()
            out = Vector((-e.y, e.x)) if kind == "ext" else Vector((e.y, -e.x))  # normale vers l'extérieur
            for k in range(n):
                q = a.lerp(b, (k + 0.5) / n) + out * 0.001
                stud(f"rivet_{kind}{k}" + ("D" if s > 0 else "G"), (q.x * s, 0.0, q.y), 0.0055, "guitare",
                     m="g_argent")
    # plaque de protection en acier sombre, rivetée, bord clair
    extrude("plaque", PLATE, YF - 0.004, YF + 0.001, "g_plaque")
    frame_ring("plaque_bord", PLATE, offset_poly(PLATE, 0.004), YF - 0.0048, YF + 0.001, "g_cadre")
    inner = offset_poly(PLATE, 0.011)
    for i, (a, b) in enumerate(zip(inner, inner[1:] + inner[:1])):
        a, b = Vector(a), Vector(b)
        n = max(1, int((b - a).length / 0.045))
        for k in range(n):
            p = a.lerp(b, k / n)
            stud(f"rivet_plaque{i}_{k}", (p.x, YF - 0.004, p.y), 0.0038, "guitare", m="g_argent")
    # micros double bobinage
    for k, z in enumerate((-0.045, -0.148)):
        box(f"micro_cadre{k}", (0.004, YF - 0.008, z), (0.092, 0.01, 0.04), "g_argent", "guitare")
        box(f"micro{k}", (0.004, YF - 0.012, z), (0.08, 0.006, 0.029), "g_noir", "guitare")
        for j in range(6):
            stud(f"micro{k}_plot{j}", (0.004 - 0.0275 + 0.011 * j, YF - 0.0152, z + 0.006), 0.0028, "guitare",
                 m="g_argent")
    # chevalet
    box("chevalet", (0.004, YF - 0.01, -0.196), (0.098, 0.012, 0.016), "g_argent", "guitare")
    for j in range(6):
        box(f"pontet{j}", (0.004 - 0.026 + 0.0104 * j, YF - 0.0165, -0.196), (0.007, 0.004, 0.01), "g_acier",
            "guitare")
    # trois boutons sur l'aile droite
    for k, (x, z) in enumerate(((0.106, -0.224), (0.127, -0.272), (0.148, -0.32))):
        loft(f"bouton{k}", [((x, YF - 0.002, z), 0.012, 0.012), ((x, YF - 0.016, z), 0.011, 0.011)], "g_argent",
             "guitare", segs=12)
        stud(f"bouton{k}_c", (x, YF - 0.016, z), 0.005, "guitare", m="g_noir")
    # cordier : croissant d'acier au-dessus de l'échancrure, serti d'une gemme
    arch = [(-0.108, -0.365), (-0.078, -0.332), (-0.046, -0.306), (0.0, -0.293), (0.046, -0.306), (0.078, -0.332),
            (0.108, -0.365)]
    rw = [0.003, 0.013, 0.016, 0.017, 0.016, 0.013, 0.003]
    loft("croissant", [((x, YF - 0.009, z), w, 0.012) for (x, z), w in zip(arch, rw)], "g_armure", "guitare", segs=8)
    orn = [(-0.07, -0.275), (-0.045, -0.262), (-0.02, -0.25), (0.02, -0.25), (0.045, -0.262), (0.07, -0.275)]
    loft("volute", [((x, YF - 0.006, z), 0.0045, 0.004) for x, z in orn], "g_argent", "guitare", segs=6)
    loft("sertissure", [((0, YF - 0.001, -0.245), 0.031, 0.024), ((0, YF - 0.008, -0.245), 0.027, 0.02)],
         "g_argent", "guitare", segs=4, smooth=False)
    gem("gemme_cordier", (0, YF - 0.008, -0.245), 0.02, 0.014, 0.012)
    # dos : écusson d'acier riveté, petite gemme
    extrude("ecusson", SHIELD, -YF - 0.001, -YF + 0.004, "g_plaque")
    frame_ring("ecusson_bord", SHIELD, offset_poly(SHIELD, 0.005), -YF - 0.001, -YF + 0.0048, "g_cadre")
    gem("gemme_dos", (0, -YF + 0.004, 0.028), 0.011, 0.008, 0.007, y_dir=1)
    for k, (x, z) in enumerate(((-0.04, 0.03), (0.04, 0.03), (-0.03, -0.1), (0.03, -0.1))):
        stud(f"rivet_ecusson{k}", (x, -YF + 0.004, z), 0.0045, "guitare", m="g_argent")


ARMOR = [(0.099, 0.045), (0.05, 0.008), (0.054, -0.035), (0.097, -0.048), (0.15, -0.018), (0.153, 0.012)]
LAME = [(0.054, -0.03), (0.098, -0.044), (0.152, -0.014), (0.15, -0.045), (0.096, -0.077), (0.056, -0.068)]


def build_shoulders():
    """Épaulières d'armure de part et d'autre du manche : deux plaques biseautées, corne recourbée, pointes."""
    for s in (1, -1):
        side = "D" if s > 0 else "G"
        for nm, poly, th in (("epaule", ARMOR, 0.04), ("epaule_lame", LAME, 0.044)):
            pts = [(x * s, z) for x, z in poly]
            extrude(nm + side, offset_poly(pts, 0.007), -th, th, "g_armure")
            frame_ring(nm + "_bord" + side, pts, offset_poly(pts, 0.007), -th - 0.003, th + 0.003, "g_cadre",
                       wall_m="g_armure")
        # corne recourbée vers le haut et l'extérieur
        horn = [(0.096, 0.035), (0.104, 0.062), (0.116, 0.084), (0.129, 0.104)]
        loft("epaule_corne" + side, [((x * s, 0.0, z), r, r) for (x, z), r in zip(horn, (0.018, 0.013, 0.007, 0.001))],
             "g_armure", "guitare", segs=10)
        for fy in (-1, 1):
            spike(f"epaule_pointe{'A' if fy < 0 else 'D'}{side}", (0.1 * s, 0.043 * fy, 0.0), (0.1 * s, fy, -0.3),
                  0.022, 0.011, "guitare", m="g_acier")
        for k, (x, z, dz) in enumerate(((0.153, 0.0, 0.15), (0.151, -0.045, -0.3))):
            spike(f"epaule_pointe_lat{k}" + side, (x * s, 0.0, z), (s, 0, dz), 0.03, 0.009, "guitare", m="g_armure")
        spike("bord_pointe" + side, (0.132 * s, 0.0, -0.088), (s, 0, -0.25), 0.026, 0.008, "guitare", m="g_armure")


def build_tips():
    """Embouts en pointe de flèche au bout des ailes : gemme rouge et pointes."""
    for s in (1, -1):
        side = "D" if s > 0 else "G"
        T0 = Vector((0.286 * s, -0.556))
        u = Vector((-0.571 * s, 0.821))
        v = Vector((0.821 * s, 0.571))
        kite = [T0, T0 + u * 0.11 - v * 0.062, T0 + u * 0.15 - v * 0.05, T0 + u * 0.136,
                T0 + u * 0.15 + v * 0.05, T0 + u * 0.11 + v * 0.062]
        kite = [(p.x, p.y) for p in kite]
        extrude("embout" + side, offset_poly(kite, 0.006), -0.03, 0.03, "g_acier")
        frame_ring("embout_bord" + side, kite, offset_poly(kite, 0.006), -0.032, 0.032, "g_cadre", wall_m="g_acier")
        g = T0 + u * 0.075
        for fy in (-1, 1):
            loft(f"embout_serti{side}{fy}", [((g.x, 0.032 * fy, g.y), 0.026, 0.02),
                                             ((g.x, 0.035 * fy, g.y), 0.023, 0.018)], "g_cadre", "guitare", segs=4,
                 smooth=False)
            gem(f"embout_gemme{side}{fy}", (g.x, 0.035 * fy, g.y), 0.019, 0.014, 0.01, y_dir=fy)
        for k, (a, b, dv, du) in enumerate(((0.118, 0.052, 1.0, 0.35), (0.07, 0.04, 1.0, -0.25),
                                            (0.07, -0.04, -1.0, -0.3))):
            base = T0 + u * a + v * b
            d = v * dv + u * du
            spike(f"embout_pointe{k}" + side, (base.x, 0.0, base.y), (d.x, 0, d.y), 0.034, 0.011, "guitare",
                  m="g_armure")


# ---------------------------------------------------------------- manche et tête
NUT_Z = 0.385
SCALE = 0.581  # diapason : sillet (z 0,385) -> chevalet (z -0,196)
FB_Y0, FB_Y1 = -0.037, -0.029  # touche : face avant, dessous


def neck_hw(z):
    return 0.0335 + (0.030 - 0.0335) * (z + 0.035) / (NUT_Z + 0.035)


def build_neck():
    extrude("touche", [(-0.030, NUT_Z), (0.030, NUT_Z), (0.0335, -0.035), (-0.0335, -0.035)], FB_Y0, FB_Y1,
            "g_touche")
    loft("manche", [((0, FB_Y1, z), neck_hw(z), 0.001, 0.034) for z in (-0.03, 0.1, 0.25, NUT_Z)], "g_manche",
         "guitare", segs=16)
    box("sillet", (0, FB_Y0 - 0.001, NUT_Z + 0.002), (0.062, 0.006, 0.006), "g_os", "guitare")
    prev = NUT_Z
    for n in range(1, 25):
        z = NUT_Z - SCALE * (1 - 2 ** (-n / 12))
        if z < -0.03:
            break
        box(f"frette{n}", (0, FB_Y0 - 0.0008, z), (neck_hw(z) * 2 - 0.002, 0.002, 0.0022), "g_argent", "guitare")
        if n in (3, 5, 7, 9, 12, 15, 17, 19, 21):
            zm = (z + prev) / 2
            for x in ((-0.012, 0.012) if n == 12 else (0.0,)):
                box(f"repere{n}{x}", (x, FB_Y0 - 0.0004, zm), (0.009, 0.001, 0.009), "g_nacre", "guitare")
        prev = z


HEAD_R = [(0.0, 0.0), (0.031, 0.0), (0.035, 0.03), (0.046, 0.1), (0.054, 0.132), (0.05, 0.148), (0.036, 0.152),
          (0.022, 0.166), (0.0, 0.152)]
POSTS = (0.099, 0.067, 0.035)


def build_head():
    before = set(col().objects.keys())
    N = Vector((0, FB_Y1, NUT_Z))
    outline = [(x, NUT_Z + z) for x, z in mirror_pts(HEAD_R)]
    inner = offset_poly(outline, 0.007)
    frame_ring("tete_cadre", outline, inner, FB_Y0 - 0.002, -0.015, "g_cadre", wall_m="g_acier")
    extrude("tete", inner, FB_Y0, -0.017, "g_plaque")
    # dos de la tête en bois, boîtiers de mécaniques
    extrude("tete_dos", offset_poly(outline, 0.004), -0.016, -0.011, "g_manche")
    for s in (1, -1):
        for k, z in enumerate(POSTS):
            box(f"boitier{s}{k}", (0.03 * s, -0.007, NUT_Z + z), (0.017, 0.008, 0.015), "g_cadre", "guitare")
    # cornes en croissant de lune
    for s in (1, -1):
        side = "D" if s > 0 else "G"
        path = [(0.038, 0.14), (0.062, 0.132), (0.08, 0.146), (0.086, 0.17), (0.077, 0.193), (0.058, 0.207),
                (0.036, 0.214)]
        rw = [0.02, 0.018, 0.015, 0.012, 0.009, 0.005, 0.001]
        rt = [0.012, 0.012, 0.011, 0.009, 0.007, 0.004, 0.001]
        loft("corne" + side, [((x * s, -0.027 + 0.07 * (k / 6) ** 2, NUT_Z + z), a, b)
                               for k, ((x, z), a, b) in enumerate(zip(path, rw, rt))],
             "g_armure", "guitare", segs=10)
        # mécaniques : axe sur la face, clé sur le côté
        for k, z in enumerate(POSTS):
            loft(f"axe{side}{k}", [((0.032 * s, FB_Y0, NUT_Z + z), 0.005, 0.005),
                                   ((0.032 * s, FB_Y0 - 0.009, NUT_Z + z), 0.0045, 0.0045)], "g_argent", "guitare",
                 segs=8)
            rod(f"cle_tige{side}{k}", (0.048 * s, -0.027, NUT_Z + z), (0.056 * s, -0.027, NUT_Z + z), 0.0035,
                "g_argent")
            loft(f"cle{side}{k}", [((0.065 * s, -0.022, NUT_Z + z), 0.0115, 0.0095),
                                   ((0.065 * s, -0.032, NUT_Z + z), 0.0115, 0.0095)], "g_cadre", "guitare", segs=12)
    # crâne d'argent et dague
    zc = NUT_Z + 0.104
    ellipsoid("crane", (0, FB_Y0 - 0.007, zc), (0.022, 0.013, 0.021), "g_argent", "guitare", 12, 8)
    ellipsoid("crane_machoire", (0, FB_Y0 - 0.006, zc - 0.022), (0.014, 0.009, 0.011), "g_argent", "guitare", 10, 6)
    for s in (1, -1):
        ellipsoid(f"crane_orbite{s}", (0.0085 * s, FB_Y0 - 0.0185, zc - 0.003), (0.006, 0.004, 0.0055), "g_noir",
                  "guitare", 8, 6)
    loft("dague", [((0, FB_Y0 - 0.003, zc - 0.032), 0.001, 0.001), ((0, FB_Y0 - 0.003, zc - 0.042), 0.009, 0.004),
                   ((0, FB_Y0 - 0.003, zc - 0.078), 0.001, 0.001)], "g_argent", "guitare", segs=4, smooth=False)
    # cordes sur la tête : du sillet vers chaque axe
    for i in range(6):
        x0 = -0.0225 + 0.009 * i
        s = -1 if i < 3 else 1
        z = POSTS[i] if i < 3 else POSTS[5 - i]
        rod(f"corde_tete{i}", (x0, FB_Y0 - 0.0045, NUT_Z + 0.003), (0.032 * s, FB_Y0 - 0.006, NUT_Z + z), 0.0007,
            "g_cordes")
    # tête légèrement renversée vers l'arrière
    R = Matrix.Rotation(math.radians(-13), 3, "X")
    for o in list(col().objects):
        if o.name not in before:
            xform(o, N, R)


def build_strings():
    for i in range(6):
        a = (-0.0225 + 0.009 * i, FB_Y0 - 0.0045, NUT_Z + 0.002)
        b = (0.004 - 0.026 + 0.0104 * i, YF - 0.0195, -0.196)
        c = (-0.012 + 0.0048 * i, YF - 0.011, -0.232)
        rod(f"corde{i}", a, b, 0.0007, "g_cordes")
        rod(f"corde_fin{i}", b, c, 0.0007, "g_cordes")


def build_guitar():
    global COL
    COL = None
    reset()
    materials_g()
    build_body()
    build_shoulders()
    build_tips()
    build_neck()
    build_head()
    build_strings()


def join_guitar():
    objs = [o for o in col().objects if o.type == "MESH"]
    with bpy.context.temp_override(active_object=objs[0], selected_editable_objects=objs, selected_objects=objs):
        bpy.ops.object.join()
    g = objs[0]
    g.name = "Guitare"
    g.data.name = "Guitare"
    return g


def export_guitar(path):
    bpy.ops.object.select_all(action="DESELECT")
    for o in col().objects:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True,
                              export_yup=True, export_animations=False)
