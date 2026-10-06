# Interface de Metal Bard (HUD et menus), modelée et rendue dans Blender : fer noirci, pointes, crânes, chaînes, runes
# rougeoyantes (planche d'inspiration fournie par Ulysse, 5 oct. 2026).
#
# Usage (sans interface) :
#   blender --background --factory-startup --python art/hud/build_hud.py -- [element...]
#       -> assets/ui/<element>.png (fond transparent) ; pour les réservoirs, aussi <element>_masque.png : la zone où le
#          jeu dessine le liquide (blanc), sous l'image : la main et l'enceinte sont des récipients de verre fumé.
#   éléments : enceinte_db, barre_sorts, case, cadre, bouton (tous par défaut) ; main_vie (l'ancienne main de verre,
#   seulement si on la demande : la jauge de vie vient maintenant du dessin d'Ulysse, voir art/hud/main_cornes.py)
#
# Repère : X à droite, Z en haut, la caméra (orthographique) regarde vers +Y ; on modèle face à elle (côté -Y).
import bpy, bmesh, math, os, sys, random
from mathutils import Vector, Matrix, Euler

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(ROOT, "assets", "ui")
MATS = {}
MASK = set()  # objets qui forment le masque du réservoir


# ---------------------------------------------------------------- scène, matières
def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    global _HEAD
    _HEAD = None
    MATS.clear()
    MASK.clear()
    random.seed(7)
    materials()


def lin(c):
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


def mat(name, srgb, metal=0.0, rough=0.5, emit=0.0, emit_col=None, alpha=1.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = (*lin(srgb), 1.0)
    b.inputs["Metallic"].default_value = metal
    b.inputs["Roughness"].default_value = rough
    if emit > 0:
        b.inputs["Emission Color"].default_value = (*lin(emit_col or srgb), 1.0)
        b.inputs["Emission Strength"].default_value = emit
    if alpha < 1.0:
        b.inputs["Alpha"].default_value = alpha
    MATS[name] = m
    return m


def glass_material():
    """Verre fumé des récipients (la main, l'enceinte) : presque transparent de face, opaque et brillant sur les
    bords (Fresnel) ; le jeu dessine le liquide derrière, à travers lui."""
    m = bpy.data.materials.new("verre")
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    mix = nt.nodes.new("ShaderNodeMixShader")
    clear = nt.nodes.new("ShaderNodeBsdfTransparent")
    shell = nt.nodes.new("ShaderNodeBsdfPrincipled")
    shell.inputs["Base Color"].default_value = (*lin((0.16, 0.14, 0.17)), 1.0)
    shell.inputs["Roughness"].default_value = 0.12
    lw = nt.nodes.new("ShaderNodeLayerWeight")
    lw.inputs["Blend"].default_value = 0.45
    rng = nt.nodes.new("ShaderNodeMapRange")
    rng.inputs["From Min"].default_value = 0.0
    rng.inputs["From Max"].default_value = 1.0
    rng.inputs["To Min"].default_value = 0.18
    rng.inputs["To Max"].default_value = 1.0
    nt.links.new(lw.outputs["Facing"], rng.inputs["Value"])
    nt.links.new(rng.outputs["Result"], mix.inputs[0])
    nt.links.new(clear.outputs[0], mix.inputs[1])
    nt.links.new(shell.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs[0])
    MATS["verre"] = m


def materials():
    mat("fer", (0.20, 0.19, 0.20), 0.9, 0.42)
    mat("fer_sombre", (0.09, 0.085, 0.09), 0.85, 0.5)
    mat("fer_clair", (0.48, 0.46, 0.47), 0.95, 0.3)
    mat("pierre", (0.46, 0.42, 0.41), 0.0, 0.7)
    mat("os", (0.78, 0.72, 0.60), 0.0, 0.55)
    mat("orbite", (0.03, 0.02, 0.02), 0.0, 0.9)
    mat("rune", (1.0, 0.18, 0.08), 0.0, 0.4, emit=6.0)
    mat("braise", (1.0, 0.45, 0.1), 0.0, 0.4, emit=4.0)
    mat("vitre", (0.05, 0.03, 0.04), 0.2, 0.1)
    mat("cuir", (0.18, 0.11, 0.08), 0.0, 0.6)
    mat("membrane", (0.30, 0.18, 0.10), 0.3, 0.45)
    glass_material()
    mat("cuivre", (0.85, 0.45, 0.2), 1.0, 0.3)
    mat("fond", (0.07, 0.055, 0.055), 0.4, 0.7)
    mat("masque", (1, 1, 1), emit=1.0, emit_col=(1, 1, 1))
    cache = mat("cache", (0, 0, 0))
    nt = cache.node_tree
    nt.nodes.clear()
    nt.links.new(nt.nodes.new("ShaderNodeHoldout").outputs[0], nt.nodes.new("ShaderNodeOutputMaterial").inputs[0])


def obj_done(o, m, bevel=0.0, smooth=True, segs=3):
    if bevel > 0:
        b = o.modifiers.new("biseau", "BEVEL")
        b.width = bevel
        b.segments = segs
        b.limit_method = "ANGLE"
    o.data.materials.clear()
    o.data.materials.append(MATS[m])
    if m == "verre":
        MASK.add(o.name)  # le récipient : le liquide se voit à travers
    if smooth and o.type == "MESH":
        for p in o.data.polygons:
            p.use_smooth = True
        o.modifiers.new("lisse", "WEIGHTED_NORMAL") if bevel > 0 else None
    return o


def fuse(objs, voxel=0.025):
    """Réunit des pièces en un seul récipient : jointes puis reconstruites en voxels (remaillage), une coque lisse et
    fermée, sans parois internes (qui se verraient à travers le verre)."""
    objs = [o for o in objs if o.type == "MESH"]
    if not objs:
        return None
    base = objs[0]
    for o in objs:  # biseaux et lissages appliqués avant la jointure
        with bpy.context.temp_override(object=o, active_object=o):
            for mod in list(o.modifiers):
                bpy.ops.object.modifier_apply(modifier=mod.name)
    for o in objs[1:]:
        MASK.discard(o.name)
    if len(objs) > 1:
        with bpy.context.temp_override(active_object=base, selected_editable_objects=objs, selected_objects=objs):
            bpy.ops.object.join()
    r = base.modifiers.new("coque", "REMESH")
    r.mode = "VOXEL"
    r.voxel_size = voxel
    r.adaptivity = 0.0
    with bpy.context.temp_override(object=base, active_object=base):
        bpy.ops.object.modifier_apply(modifier=r.name)
    base.data.materials.clear()
    base.data.materials.append(MATS["verre"])
    for p in base.data.polygons:
        p.use_smooth = True
    MASK.add(base.name)
    return base


def rbox(loc, size, m, bevel=0.04, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    return obj_done(o, m, bevel, smooth=False)


def cyl(loc, r, depth, m, rot=(math.pi / 2, 0, 0), verts=32, bevel=0.02, r2=None):
    if r2 is None:
        bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=depth, location=loc, rotation=rot, vertices=verts)
    else:
        bpy.ops.mesh.primitive_cone_add(radius1=r, radius2=r2, depth=depth, location=loc, rotation=rot, vertices=verts)
    return obj_done(bpy.context.active_object, m, bevel, smooth=True)


def ball(loc, scale, m, segs=24):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=1, location=loc, segments=segs, ring_count=segs // 2)
    o = bpy.context.active_object
    o.scale = scale
    bpy.ops.object.transform_apply(scale=True)
    return obj_done(o, m)


def torus(loc, R, r, m, rot=(math.pi / 2, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r, location=loc, rotation=rot, major_segments=24,
                                     minor_segments=10)
    return obj_done(bpy.context.active_object, m)


def spike(base, direction, length, r, m="fer_clair"):
    d = Vector(direction).normalized()
    loc = Vector(base) + d * length / 2
    rot = d.to_track_quat("Z", "Y").to_euler()
    bpy.ops.mesh.primitive_cone_add(radius1=r, radius2=0.0, depth=length, location=loc, rotation=rot, vertices=12)
    return obj_done(bpy.context.active_object, m)


def tube(pts, radius, m, radii=None, caps=True):
    """Tube lisse le long de pts (courbe de Bézier automatique), rayon modulé point par point."""
    cu = bpy.data.curves.new("tube", "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = radius
    cu.bevel_resolution = 6
    cu.use_fill_caps = caps
    sp = cu.splines.new("BEZIER")
    sp.bezier_points.add(len(pts) - 1)
    for i, p in enumerate(pts):
        bp = sp.bezier_points[i]
        bp.co = p
        bp.handle_left_type = bp.handle_right_type = "AUTO"
        bp.radius = radii[i] if radii else 1.0
    o = bpy.data.objects.new("tube", cu)
    bpy.context.scene.collection.objects.link(o)
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    bpy.ops.object.convert(target="MESH")
    o = bpy.context.active_object
    return obj_done(o, m)


def chain(pts, link=0.09, wire=0.018, m="fer_clair"):
    """Chaîne : maillons alternés le long d'une polyligne."""
    out = []
    path = [Vector(p) for p in pts]
    total = sum((path[i + 1] - path[i]).length for i in range(len(path) - 1))
    n = max(2, int(total / (link * 1.5)))
    for k in range(n):
        t = k / (n - 1) * total
        acc = 0.0
        for i in range(len(path) - 1):
            seg = (path[i + 1] - path[i]).length
            if acc + seg >= t or i == len(path) - 2:
                u = (t - acc) / max(seg, 1e-6)
                p = path[i].lerp(path[i + 1], min(1.0, u))
                d = (path[i + 1] - path[i]).normalized()
                break
            acc += seg
        q = d.to_track_quat("Y", "Z")
        e = q.to_euler()
        if k % 2:
            e.rotate_axis("Y", math.pi / 2)
        bpy.ops.mesh.primitive_torus_add(major_radius=link * 0.55, minor_radius=wire, location=p, rotation=e,
                                         major_segments=16, minor_segments=8)
        o = bpy.context.active_object
        o.scale = (1.0, 1.5, 1.0)
        out.append(obj_done(o, m))
    return out


def rivet(loc, r=0.05, m="fer_clair"):
    return ball(loc, (r, r * 0.6, r), m, 12)


_HEAD = None
SKELETON_BLEND = os.path.join(ROOT, "art", "pnj", "squelette.blend")


def skeleton_head():
    """Tête des squelettes ennemis, découpée dans leur modèle (art/pnj/squelette.blend, au repos, sans armature) :
    au-dessus du cou, recentrée et ramenée à 1 unité de haut. Modèle commun, recopié à chaque crâne."""
    global _HEAD
    if _HEAD is not None:
        return _HEAD
    with bpy.data.libraries.load(SKELETON_BLEND, link=False) as (src, dst):
        dst.objects = [n for n in src.objects]
    meshes = [o for o in dst.objects if o is not None and o.type == "MESH"]
    mesh = max(meshes, key=lambda o: len(o.data.vertices))
    mw = mesh.matrix_world.copy()
    mesh.parent = None
    for m in list(mesh.modifiers):
        mesh.modifiers.remove(m)
    mesh.data = mesh.data.copy()
    mesh.data.transform(mw)
    mesh.matrix_world.identity()
    for o in dst.objects:
        if o is not None and o != mesh:
            bpy.data.objects.remove(o, do_unlink=True)
    bm = bmesh.new()
    bm.from_mesh(mesh.data)
    zs = [v.co.z for v in bm.verts]
    neck = min(zs) + (max(zs) - min(zs)) * 0.855  # le menton (tête : 15 % du haut) ; en dessous : cou, épaules
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < neck], context="VERTS")
    bm.to_mesh(mesh.data)
    bm.free()
    mesh.vertex_groups.clear()
    vs = [v.co for v in mesh.data.vertices]
    lo = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
    hi = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
    k = 1.0 / max(hi.z - lo.z, 1e-6)
    center = (lo + hi) * 0.5
    mesh.data.transform(Matrix.Scale(k, 4) @ Matrix.Translation(-center))
    if mesh.name in bpy.context.scene.collection.objects:
        bpy.context.scene.collection.objects.unlink(mesh)
    for c in list(mesh.users_collection):
        c.objects.unlink(mesh)
    _HEAD = mesh
    return mesh


def skull(loc, s=1.0, horns=False):
    """Crâne de squelette ennemi (vu de face), de `s` unités de haut ; `horns` : cornes de fer recourbées."""
    x, y, z = loc
    head = skeleton_head().copy()  # même maillage, nouvel objet
    head.location = loc
    head.scale = (s * 0.9, s * 0.9, s * 0.9)
    bpy.context.scene.collection.objects.link(head)
    parts = [head]
    if horns:
        for sx in (-1, 1):
            parts.append(tube([(x + 0.3 * sx * s, y, z + 0.2 * s), (x + 0.55 * sx * s, y, z + 0.42 * s),
                               (x + 0.6 * sx * s, y, z + 0.8 * s)], 0.08 * s, "fer_clair", [1.0, 0.6, 0.05]))
    return parts


# ---------------------------------------------------------------- rendu
def setup_render(w, h, cam_center, ortho):
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 48
    sc.cycles.use_denoising = True
    sc.render.film_transparent = True
    sc.render.resolution_x = w
    sc.render.resolution_y = h
    sc.render.resolution_percentage = 100
    sc.view_settings.view_transform = "Standard"
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = ortho
    cam.location = (cam_center[0], -20, cam_center[1])
    cam.rotation_euler = (math.radians(90), 0, 0)
    sc.camera = cam
    if sc.world is None:
        sc.world = bpy.data.worlds.new("monde")
    sc.world.use_nodes = True
    bg = next(n for n in sc.world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = (0.05, 0.045, 0.05, 1)
    bg.inputs["Strength"].default_value = 0.6
    # Éclairage de scène : clé chaude en haut à gauche, contre-jour orangé à droite, appoint froid.
    for name, loc, energy, col in (("cle", (-4, -6, 7), 900, (1.0, 0.85, 0.7)), ("contre", (5, 3, 3), 700, (1.0, 0.45, 0.2)),
                                   ("appoint", (3, -6, -2), 250, (0.6, 0.7, 1.0))):
        lamp = bpy.data.objects.new(name, bpy.data.lights.new(name, "AREA"))
        lamp.data.energy = energy
        lamp.data.size = 4
        lamp.data.color = col
        lamp.location = loc
        lamp.rotation_euler = (Vector((cam_center[0], 0, cam_center[1])) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
        sc.collection.objects.link(lamp)


def render(name, mask=False):
    os.makedirs(OUT, exist_ok=True)
    sc = bpy.context.scene
    sc.render.filepath = os.path.join(OUT, name + ".png")
    bpy.ops.render.render(write_still=True)
    print("[hud]", sc.render.filepath)
    if mask:
        # Masque : la silhouette du récipient en blanc, le reste caché (le jeu dessine le liquide sous l'image : les
        # chaînes, bagues et pointes opaques passent devant).
        saved = {}
        for o in sc.objects:
            if o.type != "MESH":
                continue
            saved[o.name] = [s.material for s in o.material_slots]
            o.hide_render = o.name not in MASK
            for s in o.material_slots:
                s.material = MATS["masque"]
        sc.cycles.samples = 8
        sc.cycles.use_denoising = False
        sc.render.filepath = os.path.join(OUT, name + "_masque.png")
        bpy.ops.render.render(write_still=True)
        print("[hud]", sc.render.filepath)
        for o in sc.objects:
            if o.name in saved:
                o.hide_render = False
                for s, m in zip(o.material_slots, saved[o.name]):
                    s.material = m
        sc.cycles.samples = 48
        sc.cycles.use_denoising = True


# ---------------------------------------------------------------- la main cornue (réservoir de vie)
def main_vie():
    """Main du signe des cornes (index et auriculaire levés), toute en verre fumé : c'est le réservoir de vie, le jeu la
    remplit de liquide rouge. Runes rougeoyantes, bagues, chaînes et bracelet à pointes de fer par-dessus."""
    reset()
    # Avant-bras et bracelet clouté
    tube([(0, 0.1, -2.0), (0, 0.05, -1.1)], 0.62, "verre", [1.0, 0.95])
    cyl((0, 0.05, -1.25), 0.72, 0.42, "fer", rot=(0, 0, 0), verts=36, bevel=0.04)
    for k in range(10):
        a = math.pi * (0.1 + 0.8 * k / 9)
        p = Vector((math.cos(a) * 0.72, -math.sin(a) * 0.72 + 0.05, -1.25))
        spike(p, (math.cos(a), -math.sin(a), 0.15), 0.32, 0.07)
    # Paume (bloc arrondi) et dos de la main
    palm = rbox((0, 0.05, -0.25), (1.45, 0.62, 1.55), "verre", bevel=0.28)
    # Doigts : index et auriculaire levés (cornes), majeur et annulaire repliés, pouce en travers
    def finger(x, z0, length, r, raised=True, lean=0.0):
        if raised:
            pts = [(x, 0.05, z0), (x + lean * 0.3, 0.02, z0 + length * 0.35), (x + lean * 0.7, 0.0, z0 + length * 0.7),
                   (x + lean, 0.02, z0 + length)]
            o = tube(pts, r, "verre", [1.0, 0.95, 0.88, 0.75])
            for k, f in enumerate((0.33, 0.66)):
                p = Vector(pts[0]).lerp(Vector(pts[3]), f)
                rbox((p.x, p.y - r * 0.85, p.z), (r * 1.2, 0.04, 0.05), "rune", 0.01)  # runes sur les phalanges
                torus((p.x, p.y, p.z - 0.05), r * 1.08, 0.025, "fer_clair", rot=(0, 0, 0))
            ball((x + lean, 0.0, z0 + length + r * 0.6), (r * 0.8, r * 0.8, r * 0.7), "verre")
            return o
        pts = [(x, 0.05, z0), (x, -0.25, z0 + 0.25), (x, -0.45, z0 + 0.0), (x, -0.42, z0 - 0.25)]
        return tube(pts, r, "verre", [1.0, 1.0, 0.95, 0.9])
    finger(-0.52, 0.45, 1.55, 0.2, True, -0.12)
    finger(0.55, 0.45, 1.25, 0.18, True, 0.12)
    finger(-0.18, 0.45, 0, 0.21, False)
    finger(0.18, 0.45, 0, 0.2, False)
    # Pouce replié devant le majeur et l'annulaire
    tube([(0.85, -0.1, 0.05), (0.62, -0.42, 0.42), (0.2, -0.62, 0.62), (-0.18, -0.62, 0.62)], 0.19, "verre",
         [1.0, 0.95, 0.9, 0.85])
    rbox((0.3, -0.8, 0.6), (0.22, 0.04, 0.05), "rune", 0.01, rot=(0, 0.3, 0))
    # Runes de la paume
    for (x, z, a) in ((-0.62, -0.85, 0.5), (0.62, -0.85, -0.5), (-0.62, 0.15, -0.3), (0.62, 0.15, 0.3)):
        rbox((x, -0.29, z), (0.05, 0.03, 0.3), "rune", 0.01, rot=(0, a, 0))
    # Chaînes enroulées autour du poignet et des doigts
    chain([(-0.75, -0.35, -0.85), (-0.2, -0.45, -0.95), (0.4, -0.42, -0.8), (0.8, -0.3, -0.6)])
    # Pointes sur le dos de la main et les phalanges
    for (x, z, dx) in ((-0.75, 0.2, -1), (0.75, 0.0, 1), (-0.75, -0.5, -1), (0.75, -0.6, 1)):
        spike((x, 0.05, z), (dx, 0.1, 0.25), 0.3, 0.07)
    fuse([o for o in bpy.context.scene.objects if o.name in MASK])  # un seul récipient, sans parois internes
    setup_render(420, 560, (0, 0.05), 4.2)
    render("main_vie", mask=True)


# ---------------------------------------------------------------- l'enceinte (réservoir de décibels)
def enceinte_db():
    """Baffle de scène tout en verre fumé : c'est le réservoir de décibels, le jeu le remplit de liquide violet.
    Coins renforcés, rivets, cerclages des haut-parleurs, boutons et pointes de fer et de cuivre par-dessus ; les
    membranes des haut-parleurs sont en verre elles aussi (le liquide se voit à travers)."""
    reset()
    W, H, D = 2.2, 3.4, 1.2
    rbox((0, 0.3, 0), (W, D, H), "verre", bevel=0.08)
    # Coins renforcés et rivets
    for sx in (-1, 1):
        for sz in (-1, 1):
            rbox((sx * (W / 2 - 0.12), -0.33, sz * (H / 2 - 0.12)), (0.36, 0.1, 0.36), "fer", 0.04)
            rivet((sx * (W / 2 - 0.12), -0.4, sz * (H / 2 - 0.12)), 0.06)
    for k in range(7):
        z = -H / 2 + 0.3 + k * (H - 0.6) / 6
        for sx in (-1, 1):
            rivet((sx * (W / 2 - 0.05), -0.32, z), 0.035)
    # Arêtes de fer (le verre est serti dans un cadre)
    for sx in (-1, 1):
        rbox((sx * (W / 2 - 0.03), -0.3, 0), (0.07, 0.08, H - 0.5), "fer", 0.02)
    for sz in (-1, 1):
        rbox((0, -0.3, sz * (H / 2 - 0.03)), (W - 0.5, 0.08, 0.07), "fer", 0.02)
    # Rangée du haut : deux tweeters (cerclage de fer et de cuivre, membrane de verre) et trois boutons
    for sx in (-1, 1):
        torus((sx * 0.5, -0.34, 1.15), 0.33, 0.045, "fer")
        torus((sx * 0.5, -0.37, 1.15), 0.28, 0.03, "cuivre")
        cyl((sx * 0.5, -0.36, 1.15), 0.27, 0.1, "verre", r2=0.1, bevel=0.0)
        ball((sx * 0.5, -0.42, 1.15), (0.08, 0.05, 0.08), "braise")
    for k in range(3):
        cyl((-0.25 + k * 0.25, -0.33, 0.78), 0.07, 0.1, "fer_clair", bevel=0.01)
    rbox((0, -0.32, 0.62), (1.9, 0.06, 0.05), "fer_clair", 0.01)
    # Gros haut-parleur : cerclages, membrane de verre, cache-noyau rougeoyant
    torus((0, -0.33, -1.05), 0.64, 0.055, "fer")
    torus((0, -0.37, -1.05), 0.56, 0.035, "cuivre")
    torus((0, -0.4, -1.05), 0.48, 0.025, "braise")
    cyl((0, -0.36, -1.05), 0.55, 0.18, "verre", r2=0.18, bevel=0.0)
    ball((0, -0.5, -1.05), (0.17, 0.08, 0.17), "braise")
    # Pointes sur le flanc droit, comme sur la planche
    for k in range(4):
        spike((W / 2, 0.0, -1.2 + k * 0.55), (1, -0.15, 0), 0.5, 0.11, "cuivre")
    for k in range(3):
        spike((-W / 2, 0.0, -0.9 + k * 0.7), (-1, -0.15, 0), 0.35, 0.09)
    # Pointes sur le dessus
    for k in range(5):
        spike((-0.8 + k * 0.4, 0.3, H / 2), (0, -0.1, 1), 0.3, 0.07)
    fuse([o for o in bpy.context.scene.objects if o.name in MASK])  # un seul récipient, sans parois internes
    setup_render(400, 560, (0.0, 0.05), 4.0)
    render("enceinte_db", mask=True)


# ---------------------------------------------------------------- cadres et boutons
def cut(o, cutter):
    """Évide `o` par `cutter` (différence booléenne), puis supprime `cutter`."""
    m = o.modifiers.new("evide", "BOOLEAN")
    m.operation = "DIFFERENCE"
    m.object = cutter
    bpy.context.view_layer.objects.active = o
    for mod in list(o.modifiers):
        bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.data.objects.remove(cutter, do_unlink=True)
    return o


def frame_plate(w, h, border, depth, m, bevel=0.03):
    """Cadre rectangulaire (plaque évidée au centre)."""
    plate = rbox((0, 0, 0), (w, depth, h), m, 0.0)
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, 0))
    hole = bpy.context.active_object
    hole.scale = (w - 2 * border, depth * 3, h - 2 * border)
    cut(plate, hole)
    b = plate.modifiers.new("biseau", "BEVEL")
    b.width = bevel
    b.segments = 3
    b.limit_method = "ANGLE"
    return plate


def barre_sorts():
    """Cadre de la barre de sorts : fer noirci à double filet, crâne cornu au centre, crânes aux deux bouts,
    pointes sur le dessus, chaînes pendantes. Le centre est vide : le jeu y pose ses cases."""
    reset()
    W, H = 9.4, 1.2
    frame_plate(W, H, 0.16, 0.2, "fer")
    frame_plate(W - 0.1, H - 0.1, 0.05, 0.24, "fer_clair", 0.01)
    for k in range(16):
        x = -W / 2 + 0.35 + k * (W - 0.7) / 15
        rivet((x, -0.13, H / 2 - 0.08), 0.035)
        rivet((x, -0.13, -H / 2 + 0.08), 0.035)
    for k in range(9):
        x = -W / 2 + 0.6 + k * (W - 1.2) / 8
        if abs(x) > 0.6:
            spike((x, 0, H / 2), (0, 0, 1), 0.3 if k % 2 else 0.45, 0.07)
    # crânes : cornu au centre (au-dessus du cadre), un à chaque bout
    skull((0, -0.15, H / 2 + 0.22), 0.55, horns=True)
    for sx in (-1, 1):
        skull((sx * (W / 2 + 0.1), -0.15, 0.1), 0.5)
        spike((sx * (W / 2 + 0.25), 0, 0.3), (sx, 0, 0.6), 0.5, 0.09)
        spike((sx * (W / 2 + 0.25), 0, -0.25), (sx, 0, -0.4), 0.45, 0.08)
        chain([(sx * 1.2, -0.12, -H / 2), (sx * 2.2, -0.15, -H / 2 - 0.25), (sx * 3.2, -0.12, -H / 2)], 0.1, 0.02)
    setup_render(1050, 210, (0, 0.12), 10.5)
    render("barre_sorts")


def case():
    """Case de sort : cadre de fer carré à rivets d'angle, centre vide."""
    reset()
    frame_plate(1.0, 1.0, 0.09, 0.15, "fer")
    frame_plate(0.86, 0.86, 0.025, 0.18, "fer_clair", 0.006)
    for sx in (-1, 1):
        for sz in (-1, 1):
            rivet((sx * 0.43, -0.1, sz * 0.43), 0.03)
    setup_render(128, 128, (0, 0), 1.04)
    render("case")


def cadre():
    """Panneau des menus (texture en 9 parties, coins de 48 px) : fond de fer sombre, bordure épaisse, coins
    renforcés à rivet et petite pointe."""
    reset()
    S = 1.92
    rbox((0, 0.05, 0), (S - 0.1, 0.05, S - 0.1), "fond", 0.0)
    frame_plate(S - 0.04, S - 0.04, 0.14, 0.16, "fer", 0.025)
    frame_plate(S - 0.2, S - 0.2, 0.025, 0.18, "fer_clair", 0.006)
    for sx in (-1, 1):
        for sz in (-1, 1):
            rbox((sx * (S / 2 - 0.2), -0.05, sz * (S / 2 - 0.2)), (0.3, 0.12, 0.3), "fer", 0.03, rot=(0, math.pi / 4, 0))
            rivet((sx * (S / 2 - 0.2), -0.13, sz * (S / 2 - 0.2)), 0.05)
    setup_render(192, 192, (0, 0), S)
    render("cadre")


def bouton():
    """Bouton des menus (texture en 9 parties, bords de 20 px) : plaque de fer biseautée, rivets aux bouts."""
    reset()
    rbox((0, 0, 0), (1.56, 0.12, 0.44), "fer_sombre", 0.05)
    frame_plate(1.56, 0.44, 0.05, 0.16, "fer", 0.015)
    setup_render(160, 48, (0, 0), 1.6)
    render("bouton")


BUILDERS = {"main_vie": main_vie, "enceinte_db": enceinte_db, "barre_sorts": barre_sorts, "case": case,
            "cadre": cadre, "bouton": bouton}


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    for n in (args or [b for b in BUILDERS if b != "main_vie"]):
        BUILDERS[n]()


if __name__ == "__main__":
    main()
