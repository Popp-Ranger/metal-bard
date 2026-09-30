# Textures peintes de Riffald, dans le style de la planche 3D : chaque matière reçoit un shader procédural
# (cuir froissé et rayé, sangles grainées, acier brossé et rayé, tissu plissé, peau, mèches striées) éclairé
# « à la main » : occlusion ambiante, lumière douce venant du haut à gauche du personnage, ombres colorées,
# arêtes usées plus claires, reflets peints sur l'acier et les cheveux. Le tout est cuit (Cycles, passe EMIT)
# dans un atlas unique, puis chaque matériau MB_* garde son nom et lit l'atlas en couleur de base.
#
# Usage, après build_riffald.py (build_all() puis build_rig()) :
#   exec(open(".../texture_riffald.py").read()) ; texture_all(4096)
#   export_textured(chemin_glb)
import bpy, math, os
from mathutils import Vector

TEX_DIR = os.path.join(os.path.dirname(os.path.abspath(bpy.data.filepath or __file__)), "textures")
ATLAS = "riffald_v3_couleur"
KEY = Vector((-0.45, -0.55, 0.70)).normalized()  # lumière principale : haut, avant, côté droit du personnage
VIEW = Vector((0.0, -1.0, 0.1)).normalized()
HALF = (KEY + VIEW).normalized()


def lin(c):
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c) + (1.0,)


# matière : ombre, base, lumière (sRGB), motif, arêtes usées (couleur, force), reflet (couleur, force),
# occlusion minimale, rugosité / métal finaux
SPEC = {
    "cuir": dict(ramp=((0.03, 0.025, 0.04), (0.12, 0.115, 0.135), (0.30, 0.30, 0.36)), pat="cuir",
                 edge=((0.30, 0.31, 0.37), 0.4), spec=((0.55, 0.58, 0.68), 0.3), ao=0.3, rough=0.5),
    "cuir_use": dict(ramp=((0.06, 0.055, 0.07), (0.23, 0.21, 0.23), (0.44, 0.43, 0.48)), pat="cuir",
                     edge=((0.35, 0.34, 0.38), 0.4), ao=0.3, rough=0.55),
    "sangle": dict(ramp=((0.12, 0.06, 0.04), (0.35, 0.21, 0.15), (0.54, 0.37, 0.27)), pat="sangle",
                   edge=((0.45, 0.31, 0.22), 0.35), ao=0.35, rough=0.6),
    "sangle_botte": dict(ramp=((0.08, 0.04, 0.03), (0.25, 0.155, 0.115), (0.43, 0.30, 0.22)), pat="sangle",
                         edge=((0.36, 0.25, 0.18), 0.35), ao=0.35, rough=0.6),
    "semelle": dict(ramp=((0.03, 0.025, 0.025), (0.12, 0.10, 0.10), (0.27, 0.24, 0.23)), pat="sangle",
                    edge=((0.25, 0.22, 0.21), 0.3), ao=0.35, rough=0.7),
    "trou": dict(ramp=((0.04, 0.02, 0.015), (0.10, 0.06, 0.05), (0.15, 0.10, 0.08)), ao=0.6, rough=0.8),
    "levre": dict(ramp=((0.58, 0.30, 0.26), (0.86, 0.56, 0.46), (0.95, 0.72, 0.62)), ao=0.5, rough=0.5),
    "metal": dict(ramp=((0.04, 0.045, 0.07), (0.17, 0.18, 0.25), (0.38, 0.43, 0.56)), pat="metal",
                  edge=((0.50, 0.55, 0.66), 0.35), spec=((0.70, 0.80, 0.95), 0.4), ao=0.3, rough=0.4,
                  metal=0.1),  # reflets déjà peints : sous 0,2, le jeu coupe le reflet toon (qui blanchit l'acier)
    "metal_bord": dict(ramp=((0.22, 0.24, 0.30), (0.56, 0.60, 0.68), (0.88, 0.91, 0.96)), pat="metal",
                       edge=((0.9, 0.92, 0.96), 0.35), spec=((1.0, 1.0, 1.0), 0.4), ao=0.35, rough=0.35,
                       metal=0.35),
    "argent": dict(ramp=((0.16, 0.16, 0.19), (0.52, 0.53, 0.57), (0.86, 0.87, 0.90)), pat="metal",
                   spec=((1.0, 1.0, 1.0), 0.45), ao=0.4, rough=0.3, metal=0.5),
    "peau": dict(ramp=((0.52, 0.24, 0.19), (0.87, 0.56, 0.42), (0.99, 0.76, 0.60)), pat="peau", ao=0.3,
                 rough=0.55),
    "cheveux": dict(ramp=((0.50, 0.11, 0.03), (0.93, 0.42, 0.12), (1.0, 0.63, 0.28)), pat="cheveux",
                    spec=((1.0, 0.82, 0.55), 0.35), ao=0.1, ao_dist=0.12, rough=0.45),
    "cheveux_ombre": dict(ramp=((0.40, 0.08, 0.02), (0.78, 0.27, 0.07), (0.95, 0.50, 0.20)), pat="cheveux",
                          ao=0.1, ao_dist=0.12, rough=0.6),
    "sourcils": dict(ramp=((0.28, 0.08, 0.02), (0.55, 0.21, 0.06), (0.75, 0.36, 0.14)), ao=0.6, rough=0.7),
    "paupiere": dict(ramp=((0.08, 0.04, 0.03), (0.16, 0.08, 0.06), (0.26, 0.15, 0.11)), ao=0.6, rough=0.7),
    "cape": dict(ramp=((0.13, 0.02, 0.055), (0.40, 0.10, 0.17), (0.62, 0.22, 0.30)), pat="tissu", ao=0.3,
                 rough=0.8),
    "maillot": dict(ramp=((0.20, 0.03, 0.05), (0.50, 0.12, 0.16), (0.72, 0.26, 0.28)), pat="tissu", ao=0.35,
                    rough=0.6),
    "gemme": dict(ramp=((0.50, 0.02, 0.06), (0.95, 0.10, 0.18), (1.0, 0.62, 0.62)), spec=((1, 1, 1), 0.5),
                  ao=0.7, rough=0.15, emit=3.0),
    "oeil": dict(ramp=((0.62, 0.60, 0.58), (0.90, 0.88, 0.85), (1.0, 1.0, 1.0)), ao=0.65, rough=0.4),
    "iris": dict(ramp=((0.06, 0.04, 0.03), (0.14, 0.09, 0.07), (0.32, 0.24, 0.20)), ao=0.7, rough=0.3),
    "bouche": dict(ramp=((0.25, 0.10, 0.08), (0.45, 0.20, 0.16), (0.60, 0.32, 0.28)), ao=0.5, rough=0.6),
}


class Graph:
    """Petit assistant de construction de nœuds : les entrées acceptent une prise ou une constante."""

    def __init__(self, m):
        self.nt = m.node_tree
        self.nt.nodes.clear()

    def node(self, kind, inputs=None, **props):
        n = self.nt.nodes.new(kind)
        for k, v in props.items():
            setattr(n, k, v)
        for k, v in (inputs or {}).items():
            self.set(n.inputs[k], v)
        return n

    def set(self, sock, v):
        if isinstance(v, bpy.types.NodeSocket):
            self.nt.links.new(v, sock)
        else:
            sock.default_value = v

    def math(self, op, a, b=0.0, clamp=False):
        n = self.node("ShaderNodeMath", operation=op, use_clamp=clamp)
        self.set(n.inputs[0], a)
        self.set(n.inputs[1], b)
        return n.outputs[0]

    def remap(self, v, a, b, c, d, smooth=False):
        n = self.node("ShaderNodeMapRange", clamp=True, interpolation_type="SMOOTHSTEP" if smooth else "LINEAR")
        self.set(n.inputs["Value"], v)
        for k, x in (("From Min", a), ("From Max", b), ("To Min", c), ("To Max", d)):
            self.set(n.inputs[k], x)
        return n.outputs["Result"]

    def vec(self, v):
        return self.node("ShaderNodeCombineXYZ", {"X": v[0], "Y": v[1], "Z": v[2]}).outputs[0]

    def vmath(self, op, a, b=None):
        n = self.node("ShaderNodeVectorMath", operation=op)
        self.set(n.inputs[0], a)
        if b is not None:
            self.set(n.inputs[1], b)
        return n.outputs["Value"] if op == "DOT_PRODUCT" else n.outputs["Vector"]

    def noise(self, co, scale, detail=2.0, stretch=None):
        if stretch is not None:
            co = self.vmath("MULTIPLY", co, self.vec(stretch))
        return self.node("ShaderNodeTexNoise", {"Vector": co, "Scale": scale, "Detail": detail}).outputs["Fac"]

    def mix(self, blend, fac, a, b):
        n = self.node("ShaderNodeMix", data_type="RGBA", blend_type=blend, clamp_result=True)
        ins = {s.identifier: s for s in n.inputs}
        self.set(ins["Factor_Float"], fac)
        self.set(ins["A_Color"], a)
        self.set(ins["B_Color"], b)
        return next(s for s in n.outputs if s.identifier == "Result_Color")


def pattern(g, kind, co):
    """Motif propre à la matière : multiplicateur de l'éclairage (autour de 1) et éclats clairs (rayures)."""
    one = 1.0
    if kind == "cuir":
        # grands plis souples, froissures horizontales (trait sombre bordé d'un trait clair), rayures claires
        folds = g.node("ShaderNodeTexWave", {"Vector": co, "Scale": 3.0, "Distortion": 2.0, "Detail": 1.0},
                       wave_type="BANDS", bands_direction="Z").outputs["Fac"]
        n = g.noise(co, 7.0, 2.0, stretch=(1, 1, 3.5))
        crease = g.remap(g.math("ABSOLUTE", g.math("SUBTRACT", n, 0.5)), 0.0, 0.018, 1.0, 0.0, True)
        lip = g.remap(g.math("ABSOLUTE", g.math("SUBTRACT", n, 0.53)), 0.0, 0.014, 1.0, 0.0, True)
        sparse = g.remap(g.noise(co, 3.0), 0.5, 0.62, 0.0, 1.0)
        mult = g.math("MULTIPLY", g.remap(folds, 0, 1, 0.95, 1.05),
                      g.math("SUBTRACT", 1.0, g.math("MULTIPLY", g.math("MULTIPLY", crease, sparse), 0.3)))
        mult = g.math("MULTIPLY", mult, g.remap(g.noise(co, 3.5), 0.3, 0.7, 0.95, 1.04))
        glint = g.math("ADD", g.math("MULTIPLY", g.math("MULTIPLY", lip, sparse), 0.35), scratches(g, co, 38.0, 0.25))
        return mult, glint
    if kind == "sangle":
        grain = g.remap(g.noise(co, 90.0, 1.0), 0.35, 0.65, 0.96, 1.03)
        mult = g.math("MULTIPLY", grain, g.remap(g.noise(co, 5.0), 0.3, 0.7, 0.92, 1.06))
        return mult, scratches(g, co, 30.0, 0.12)
    if kind == "metal":
        brushed = g.remap(g.noise(co, 22.0, 3.0, stretch=(1, 1, 8)), 0.3, 0.7, 0.9, 1.08)
        mult = g.math("MULTIPLY", brushed, g.remap(g.noise(co, 6.0), 0.3, 0.7, 0.86, 1.06))
        return mult, scratches(g, co, 26.0, 0.2)
    if kind == "cheveux":
        # stries le long des mèches (qui descendent) : bruit étiré verticalement
        streak = g.remap(g.noise(co, 55.0, 2.0, stretch=(1, 1, 0.12)), 0.3, 0.7, 0.82, 1.12)
        return streak, None
    if kind == "peau":
        return g.remap(g.noise(co, 18.0), 0.3, 0.7, 0.96, 1.03), None
    if kind == "tissu":
        folds = g.node("ShaderNodeTexWave", {"Vector": co, "Scale": 3.2, "Distortion": 6.0, "Detail": 2.0},
                       wave_type="BANDS", bands_direction="X").outputs["Fac"]
        weave = g.remap(g.noise(co, 140.0, 1.0), 0.35, 0.65, 0.95, 1.04)
        return g.math("MULTIPLY", g.remap(folds, 0, 1, 0.85, 1.1), weave), None
    return one, None


def scratches(g, co, scale, strength):
    """Rayures claires : lignes de niveau fines d'un bruit, clairsemées par un second bruit."""
    n = g.noise(co, scale, 1.0, stretch=(1, 1, 2.5))
    line = g.remap(g.math("ABSOLUTE", g.math("SUBTRACT", n, 0.5)), 0.0, 0.01, 1.0, 0.0)
    sparse = g.remap(g.noise(co, 4.0), 0.52, 0.62, 0.0, 1.0)
    return g.math("MULTIPLY", g.math("MULTIPLY", line, sparse), strength)


def paint_material(m, spec):
    """Shader de cuisson : couleur peinte (dégradé ombre → base → lumière) en émission."""
    g = Graph(m)
    co = g.node("ShaderNodeTexCoord").outputs["Object"]
    nrm = g.node("ShaderNodeNewGeometry").outputs["Normal"]
    ao = g.node("ShaderNodeAmbientOcclusion", {"Distance": spec.get("ao_dist", 0.07)}, samples=12,
                only_local=False).outputs["AO"]
    lamb = g.vmath("DOT_PRODUCT", nrm, g.vec(KEY))
    shade = g.math("MULTIPLY", g.remap(lamb, -1.0, 1.0, 0.22, 0.95), g.remap(ao, 0.0, 1.0, spec["ao"], 1.0))
    mult, glints = pattern(g, spec.get("pat"), co)
    shade = g.math("MULTIPLY", shade, mult)
    ramp = g.node("ShaderNodeValToRGB")
    cr = ramp.color_ramp
    cr.interpolation = "EASE"
    # une face tournée vers l'avant tombe vers 0,75 : couleur de base ; la lumière est réservée au dessus
    cr.elements[0].position, cr.elements[0].color = 0.15, lin(spec["ramp"][0])
    cr.elements[1].position, cr.elements[1].color = 1.0, lin(spec["ramp"][2])
    mid = cr.elements.new(0.76)
    mid.color = lin(spec["ramp"][1])
    g.set(ramp.inputs["Fac"], shade)
    col = ramp.outputs["Color"]
    if "edge" in spec:  # arêtes usées plus claires
        ecol, k = spec["edge"]
        bev = g.node("ShaderNodeBevel", {"Radius": 0.005}, samples=6).outputs["Normal"]
        edge = g.remap(g.vmath("DOT_PRODUCT", bev, nrm), 0.8, 0.99, 1.0, 0.0)
        col = g.mix("MIX", g.math("MULTIPLY", edge, k), col, lin(ecol))
    if glints is not None:
        light = lin(spec["ramp"][2])
        col = g.mix("MIX", glints, col, light)
    if "spec" in spec:  # reflet peint (demi-vecteur lumière / vue de face)
        scol, k = spec["spec"]
        hl = g.remap(g.vmath("DOT_PRODUCT", nrm, g.vec(HALF)), 0.88, 0.985, 0.0, 1.0, True)
        col = g.mix("MIX", g.math("MULTIPLY", hl, k), col, lin(scol))
    em = g.node("ShaderNodeEmission", {"Strength": 1.0})
    g.set(em.inputs["Color"], col)
    out = g.node("ShaderNodeOutputMaterial")
    g.set(out.inputs["Surface"], em.outputs[0])


def unwrap(obj):
    vl = bpy.context.view_layer
    bpy.ops.object.mode_set(mode="OBJECT") if bpy.context.object and bpy.context.object.mode != "OBJECT" else None
    for o in vl.objects:
        o.select_set(False)
    obj.select_set(True)
    vl.objects.active = obj
    while obj.data.uv_layers:
        obj.data.uv_layers.remove(obj.data.uv_layers[0])
    obj.data.uv_layers.new(name="UVMap")
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.0015, area_weight=0.0,
                             correct_aspect=True, scale_to_bounds=False)
    bpy.ops.object.mode_set(mode="OBJECT")


def bake_atlas(obj, size, samples=4):
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = samples
    img = bpy.data.images.get(ATLAS)
    if img is not None and tuple(img.size) != (size, size):
        bpy.data.images.remove(img)
        img = None
    if img is None:
        img = bpy.data.images.new(ATLAS, size, size, alpha=False)
    for m in obj.data.materials:
        t = m.node_tree.nodes.new("ShaderNodeTexImage")
        t.image = img
        m.node_tree.nodes.active = t
    vl = bpy.context.view_layer
    for o in vl.objects:
        o.select_set(False)
    obj.select_set(True)
    vl.objects.active = obj
    bpy.ops.object.bake(type="EMIT", margin=max(4, size // 256), use_clear=True)
    os.makedirs(TEX_DIR, exist_ok=True)
    img.filepath_raw = os.path.join(TEX_DIR, ATLAS + ".png")
    img.file_format = "PNG"
    img.save()
    return img


def final_materials(obj, img):
    """Matériaux de jeu : l'atlas en couleur de base (ombres comprises), rugosité et métal par matière."""
    for m in obj.data.materials:
        spec = SPEC.get(m.name[3:], dict(rough=0.6))
        nt = m.node_tree
        nt.nodes.clear()
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = img
        b = nt.nodes.new("ShaderNodeBsdfPrincipled")
        nt.links.new(tex.outputs["Color"], b.inputs["Base Color"])
        b.inputs["Roughness"].default_value = spec.get("rough", 0.6)
        b.inputs["Metallic"].default_value = spec.get("metal", 0.0)
        if spec.get("emit"):
            nt.links.new(tex.outputs["Color"], b.inputs["Emission Color"])
            b.inputs["Emission Strength"].default_value = spec["emit"]
        nt.links.new(b.outputs[0], nt.nodes.new("ShaderNodeOutputMaterial").inputs[0])
        nt.nodes.active = tex


def texture_all(size=4096, samples=4, obj_name="Riffald"):
    obj = bpy.data.objects[obj_name]
    unwrap(obj)
    for m in obj.data.materials:
        paint_material(m, SPEC.get(m.name[3:], dict(ramp=((0.1, 0.1, 0.1), (0.5, 0.5, 0.5), (0.8, 0.8, 0.8)),
                                                     ao=0.4)))
    img = bake_atlas(obj, size, samples)
    final_materials(obj, img)
    return img


def export_textured(path, jpeg_quality=90):
    vl = bpy.context.view_layer
    for o in vl.objects:
        o.select_set(o.name in bpy.data.collections["Riffald"].objects)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=False,
                              export_yup=True, export_animations=False, export_image_format="JPEG",
                              export_jpeg_quality=jpeg_quality)
