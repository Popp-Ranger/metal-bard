# Modèles 3D des PNJ et ennemis (générés par IA, fournis par Ulysse) : préparation pour le jeu.
#
# Sources : C:\Users\Ody\OneDrive\Bureau\GODOT\Jeux\Metal Bards\Imagerie\Personnages\3D\PNJ\<dossier>\*.glb
#
# Usage (sans interface), <perso> = mage | tavernier | squelette | demon | hella | twin (héros jouables, dans art/demon, art/hella et art/twin) :
#   blender --background --factory-startup --python art/pnj/build_pnj.py -- prepare <perso>
#       -> art/pnj/<perso>.blend : maillage ressoudé et allégé, à la taille du jeu, textures 2K
#   blender --background art/pnj/<perso>.blend --python art/pnj/build_pnj.py -- views <perso> <dossier>
#       -> vues de face et de profil avec une grille (pour relever les articulations)
#   blender --background art/pnj/<perso>.blend --python art/pnj/build_pnj.py -- rig <perso>
#       -> squelette identique à celui de Riffald (17 os) + pondération, enregistré dans le .blend
# Les animations sont ensuite transférées par art/riffald/retarget_mixamo.py (voir docs/ANIMATIONS.md).
#
# Axes Blender : Z en haut, le personnage regarde vers -Y (devient +Z dans Godot après export glTF).
import bpy, bmesh, glob, math, os, sys
from mathutils import Vector

SRC_DIR = r"C:\Users\Ody\OneDrive\Bureau\GODOT\Jeux\Metal Bards\Imagerie\Personnages\3D\PNJ"
HERE = os.path.dirname(os.path.abspath(__file__))
TARGET_TRIS = 30000
TEX_COLOR = 2048
TEX_OTHER = 1024

# Personnages : dossier source, nom, hauteur totale du modèle (m, chapeau compris) et articulations
# relevées sur les vues de face et de profil (x, y, z ; .L = côté +X, gauche du personnage).
CHARS = {
    # Ozz : « Mage V2 » (4 oct. 2026), rockeur en perfecto et lunettes violettes ; remplace le sorcier
    # au chapeau pointu (Mage/V1).
    "mage": {"dir": os.path.join("Mage", "V2"), "name": "Mage", "height": 1.85, "joints": {
        "hips": (0.0, -0.01, 0.98), "spine": (0.0, 0.0, 1.15), "chest": (0.0, 0.02, 1.32),
        "neck": (0.0, 0.03, 1.50), "head": (0.0, 0.04, 1.57), "head_top": (0.0, 0.04, 1.85),
        "shoulder.L": (0.25, 0.08, 1.43), "elbow.L": (0.36, 0.10, 1.16), "wrist.L": (0.43, 0.05, 0.96),
        "shoulder.R": (-0.25, 0.08, 1.43), "elbow.R": (-0.36, 0.10, 1.16), "wrist.R": (-0.43, 0.05, 0.96),
        "hip.L": (0.10, -0.02, 0.92), "knee.L": (0.13, 0.0, 0.59), "ankle.L": (0.17, 0.05, 0.15),
        "hip.R": (-0.10, -0.02, 0.92), "knee.R": (-0.12, 0.0, 0.59), "ankle.R": (-0.17, 0.05, 0.15)}},
    # Hella, héroïne jouable (héros prédéfini) : modèle retravaillé par Ulysse dans Blender (Hella.glb, 4 oct. 2026).
    "hella": {"src": r"C:\Users\Ody\OneDrive\Bureau\GODOT\Jeux\Metal Bards\Imagerie\Personnages\3D\Humain\Féminin",
              "file": "Hella.glb", "out": "hella", "name": "Hella", "height": 1.75, "tris": 40000, "cape": True, "joints": {
        "hips": (0.0, -0.04, 0.95), "spine": (0.0, -0.045, 1.10), "chest": (0.0, -0.05, 1.25),
        "neck": (0.0, -0.04, 1.40), "head": (0.0, -0.03, 1.48), "head_top": (0.0, -0.02, 1.75),
        "shoulder.L": (0.21, 0.0, 1.36), "elbow.L": (0.28, 0.0, 1.13), "wrist.L": (0.31, -0.07, 0.90),
        "shoulder.R": (-0.21, 0.0, 1.36), "elbow.R": (-0.28, 0.0, 1.13), "wrist.R": (-0.32, -0.07, 0.90),
        "hip.L": (0.08, -0.04, 0.92), "knee.L": (0.12, -0.04, 0.53), "ankle.L": (0.15, 0.03, 0.12),
        "hip.R": (-0.10, -0.04, 0.92), "knee.R": (-0.19, -0.04, 0.53), "ankle.R": (-0.22, 0.03, 0.12)}},
    # Riffald's Twin, héros jouable : RiffaldV1.glb fourni par Ulysse (Humain/Masculin, 5 oct. 2026).
    "twin": {"src": r"C:\Users\Ody\OneDrive\Bureau\GODOT\Jeux\Metal Bards\Imagerie\Personnages\3D\Humain\Masculin",
             "file": "RiffaldV1.glb", "out": "twin", "name": "Twin", "height": 1.84, "tris": 40000, "cape": True, "joints": {
        "hips": (0.0, 0.0, 0.95), "spine": (0.0, 0.0, 1.06), "chest": (0.0, 0.01, 1.19),
        "neck": (0.0, 0.01, 1.41), "head": (0.0, 0.01, 1.47), "head_top": (0.0, 0.01, 1.84),
        "shoulder.L": (0.27, 0.04, 1.31), "elbow.L": (0.37, 0.04, 1.07), "wrist.L": (0.42, -0.03, 0.92),
        "shoulder.R": (-0.27, 0.04, 1.31), "elbow.R": (-0.37, 0.04, 1.07), "wrist.R": (-0.42, -0.03, 0.92),
        "hip.L": (0.11, 0.0, 0.91), "knee.L": (0.15, 0.0, 0.53), "ankle.L": (0.19, 0.04, 0.15),
        "hip.R": (-0.11, 0.0, 0.91), "knee.R": (-0.15, 0.0, 0.53), "ankle.R": (-0.19, 0.04, 0.15)}},
    # Back Jlack, le sage du rock (Temple du Dragon, cinématique de la légende) : PNJ/Sage (5 oct. 2026).
    "sage": {"dir": "Sage", "file": "Back Jlack.glb", "name": "Sage", "height": 1.65, "joints": {
        "hips": (0.0, 0.04, 0.72), "spine": (0.0, 0.04, 0.88), "chest": (0.0, 0.05, 1.07),
        "neck": (0.0, 0.04, 1.22), "head": (0.0, 0.0, 1.27), "head_top": (0.0, 0.0, 1.65),
        "shoulder.L": (0.32, 0.10, 1.12), "elbow.L": (0.44, 0.06, 0.93), "wrist.L": (0.47, 0.03, 0.75),
        "shoulder.R": (-0.32, 0.10, 1.12), "elbow.R": (-0.44, 0.06, 0.93), "wrist.R": (-0.47, 0.03, 0.75),
        "hip.L": (0.18, 0.04, 0.64), "knee.L": (0.20, 0.04, 0.42), "ankle.L": (0.22, 0.06, 0.14),
        "hip.R": (-0.18, 0.04, 0.64), "knee.R": (-0.19, 0.04, 0.42), "ankle.R": (-0.22, 0.06, 0.14)}},
    # Troll des cavernes (boss des grottes, chapitre 3) : Ennemis/Troll (6 oct. 2026). Préparé à 2,2 m ; le jeu
    # l'agrandit à 3,2 m (CharacterSkin.SCALES).
    "troll": {"dir": os.path.join("Ennemis", "Troll"), "file": "troll3D.glb", "name": "Troll", "height": 2.2, "joints": {
        "hips": (0.0, 0.05, 1.05), "spine": (0.0, 0.07, 1.29), "chest": (0.0, 0.05, 1.50),
        "neck": (0.0, -0.13, 1.65), "head": (0.0, -0.22, 1.69), "head_top": (0.0, -0.2, 2.2),
        "shoulder.L": (0.48, 0.19, 1.61), "elbow.L": (0.70, 0.13, 1.18), "wrist.L": (0.69, 0.05, 0.91),
        "shoulder.R": (-0.48, 0.19, 1.61), "elbow.R": (-0.70, 0.13, 1.18), "wrist.R": (-0.69, 0.05, 0.91),
        "hip.L": (0.24, 0.05, 0.97), "knee.L": (0.27, 0.05, 0.54), "ankle.L": (0.30, 0.13, 0.19),
        "hip.R": (-0.24, 0.05, 0.97), "knee.R": (-0.27, 0.05, 0.54), "ankle.R": (-0.30, 0.13, 0.19)}},
    # Gobelin des montagnes (chapitre 3) : Ennemis/Gobelin (5 oct. 2026).
    "gobelin": {"dir": os.path.join("Ennemis", "Gobelin"), "file": "gobelin3D.glb", "name": "Gobelin", "height": 1.15, "joints": {
        "hips": (0.0, 0.03, 0.505), "spine": (0.0, 0.04, 0.60), "chest": (0.0, 0.04, 0.70),
        "neck": (0.0, -0.01, 0.835), "head": (0.0, -0.03, 0.856), "head_top": (0.0, -0.02, 1.15),
        "shoulder.L": (0.17, 0.07, 0.78), "elbow.L": (0.27, 0.08, 0.63), "wrist.L": (0.32, 0.04, 0.52),
        "shoulder.R": (-0.17, 0.07, 0.78), "elbow.R": (-0.27, 0.08, 0.63), "wrist.R": (-0.32, 0.04, 0.52),
        "hip.L": (0.10, 0.03, 0.45), "knee.L": (0.11, -0.01, 0.28), "ankle.L": (0.13, 0.03, 0.10),
        "hip.R": (-0.10, 0.03, 0.45), "knee.R": (-0.11, -0.01, 0.28), "ankle.R": (-0.13, 0.03, 0.10)}},
    # Gloubah, le Roi Grenouille (boss des Catacombes) : crapaud debout couronné (Ennemis/Gloubah, 5 oct. 2026).
    # Préparé à la taille d'un héros ; le jeu l'agrandit de 50 % (CharacterSkin.SCALES).
    "gloubah": {"dir": os.path.join("Ennemis", "Gloubah"), "name": "Gloubah", "height": 1.84, "joints": {
        "hips": (0.0, 0.08, 0.68), "spine": (0.0, 0.08, 0.85), "chest": (0.0, 0.10, 1.05),
        "neck": (0.0, 0.08, 1.30), "head": (0.0, 0.05, 1.36), "head_top": (0.0, 0.03, 1.84),
        "shoulder.L": (0.36, 0.11, 1.19), "elbow.L": (0.50, 0.07, 0.88), "wrist.L": (0.53, 0.02, 0.67),
        "shoulder.R": (-0.36, 0.11, 1.19), "elbow.R": (-0.50, 0.07, 0.88), "wrist.R": (-0.53, 0.02, 0.67),
        "hip.L": (0.16, 0.10, 0.63), "knee.L": (0.23, 0.15, 0.40), "ankle.L": (0.18, 0.11, 0.13),
        "hip.R": (-0.16, 0.10, 0.63), "knee.R": (-0.23, 0.15, 0.40), "ankle.R": (-0.18, 0.11, 0.13)}},
    # Plumeau, le bébé hibours de Gérald (Ours Hiboux, 5 oct. 2026).
    "hibours": {"dir": "Ours Hiboux", "name": "Hibours", "height": 1.2, "joints": {
        "hips": (0.0, 0.03, 0.40), "spine": (0.0, 0.03, 0.55), "chest": (0.0, 0.04, 0.72),
        "neck": (0.0, 0.05, 0.88), "head": (0.0, 0.04, 0.92), "head_top": (0.0, 0.04, 1.20),
        "shoulder.L": (0.15, 0.08, 0.86), "elbow.L": (0.29, 0.03, 0.84), "wrist.L": (0.37, -0.02, 0.84),
        "shoulder.R": (-0.15, 0.08, 0.86), "elbow.R": (-0.29, 0.03, 0.84), "wrist.R": (-0.37, -0.02, 0.84),
        "hip.L": (0.10, 0.04, 0.34), "knee.L": (0.12, 0.03, 0.19), "ankle.L": (0.13, 0.05, 0.06),
        "hip.R": (-0.10, 0.04, 0.34), "knee.R": (-0.12, 0.03, 0.19), "ankle.R": (-0.13, 0.05, 0.06)}},
    "tavernier": {"dir": "Tavernier", "name": "Tavernier", "height": 2.05, "retouche": True, "joints": {
        "hips": (0.0, 0.05, 0.95), "spine": (0.0, 0.06, 1.15), "chest": (0.0, 0.08, 1.40),
        "neck": (0.0, 0.07, 1.72), "head": (0.0, 0.04, 1.78), "head_top": (0.0, 0.04, 2.05),
        "shoulder.L": (0.30, 0.14, 1.57), "elbow.L": (0.44, 0.15, 1.15), "wrist.L": (0.47, -0.02, 0.92),
        "shoulder.R": (-0.30, 0.14, 1.57), "elbow.R": (-0.45, 0.15, 1.15), "wrist.R": (-0.48, -0.02, 0.92),
        "hip.L": (0.13, 0.05, 0.92), "knee.L": (0.16, 0.05, 0.52), "ankle.L": (0.24, 0.07, 0.16),
        "hip.R": (-0.13, 0.05, 0.92), "knee.R": (-0.16, 0.05, 0.52), "ankle.R": (-0.25, 0.07, 0.16)}},
    # Squelette : os et peinture des poids retouchés à la main par Ulysse dans squelette.blend (2 oct. 2026) ;
    # « rig » les effacerait, il refuse donc sauf avec « force » (ces articulations sont celles d'origine).
    "squelette": {"dir": "Squelette", "name": "Squelette", "height": 1.75, "retouche": True, "joints": {
        "hips": (0.0, 0.04, 0.90), "spine": (0.0, 0.06, 1.05), "chest": (0.0, 0.07, 1.22),
        "neck": (0.0, 0.08, 1.43), "head": (0.0, 0.07, 1.50), "head_top": (0.0, 0.06, 1.75),
        "shoulder.L": (0.25, 0.12, 1.37), "elbow.L": (0.34, 0.14, 1.06), "wrist.L": (0.40, 0.03, 0.81),
        "shoulder.R": (-0.25, 0.12, 1.37), "elbow.R": (-0.35, 0.14, 1.06), "wrist.R": (-0.40, 0.03, 0.81),
        "hip.L": (0.12, 0.04, 0.90), "knee.L": (0.17, 0.06, 0.47), "ankle.L": (0.20, 0.10, 0.12),
        "hip.R": (-0.12, 0.04, 0.90), "knee.R": (-0.17, 0.06, 0.47), "ankle.R": (-0.20, 0.10, 0.12)}},
    # Démon jouable (héros prédéfini, pas un PNJ) : source et .blend ailleurs (art/demon). Ébauche des poids faite par
    # « rig » le 2 oct. 2026, Ulysse finit la peinture à la main : « retouche » protège son travail.
    "demon": {"src": r"C:\Users\Ody\OneDrive\Bureau\GODOT\Jeux\Metal Bards\Imagerie\Personnages\3D\Démon",
              "out": "demon", "name": "Demon", "height": 1.95, "tris": 40000, "retouche": True, "joints": {
        "hips": (0.0, -0.035, 1.02), "spine": (0.0, -0.04, 1.17), "chest": (0.0, -0.04, 1.33),
        "neck": (0.0, -0.06, 1.53), "head": (0.0, -0.07, 1.60), "head_top": (0.0, -0.07, 1.93),
        "shoulder.L": (0.21, 0.0, 1.43), "elbow.L": (0.27, 0.04, 1.22), "wrist.L": (0.355, -0.07, 1.0),
        "shoulder.R": (-0.21, 0.0, 1.43), "elbow.R": (-0.27, 0.04, 1.22), "wrist.R": (-0.355, -0.07, 1.0),
        "hip.L": (0.10, -0.03, 1.0), "knee.L": (0.16, -0.01, 0.60), "ankle.L": (0.22, 0.06, 0.15),
        "hip.R": (-0.10, -0.03, 1.0), "knee.R": (-0.18, -0.01, 0.60), "ankle.R": (-0.24, 0.06, 0.15)}},
}

HAND_LEN = 0.09  # poignet -> articulations des doigts
FOOT_LEN = 0.17  # cheville -> pointe du pied (vers l'avant, -Y)


def cfg():
    return CHARS[ARGS[1]]


def blend_path():
    return os.path.join(HERE, "..", cfg()["out"], ARGS[1] + ".blend") if "out" in cfg() else os.path.join(HERE, ARGS[1] + ".blend")


def col():
    name = cfg()["name"]
    c = bpy.data.collections.get(name)
    if c is None:
        c = bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(c)
    return c


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


def prepare():
    c = cfg()
    src = glob.glob(os.path.join(c.get("src") or os.path.join(SRC_DIR, c["dir"]), c.get("file", "*.glb")))[0]
    os.makedirs(os.path.dirname(blend_path()), exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=src)
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    for o in bpy.data.objects:
        o.select_set(o in meshes)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    body = bpy.context.view_layer.objects.active
    body.data.transform(body.matrix_world)
    body.parent = None
    body.matrix_world.identity()
    # Le générateur découpe le volume en tranches : on les ressoude avant d'alléger.
    bm = bmesh.new()
    bm.from_mesh(body.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bm.to_mesh(body.data)
    bm.free()
    faces = len(body.data.polygons)
    target = c.get("tris", TARGET_TRIS)
    if faces > target:
        dec = body.modifiers.new("Decimate", "DECIMATE")
        dec.ratio = target / faces
        dec.use_collapse_triangulate = True
        with bpy.context.temp_override(object=body, active_object=body):
            bpy.ops.object.modifier_apply(modifier=dec.name)
    vs = [v.co for v in body.data.vertices]
    zmin = min(v.z for v in vs)
    zmax = max(v.z for v in vs)
    cx = (min(v.x for v in vs) + max(v.x for v in vs)) * 0.5
    # Profondeur : centrée sur les pieds (vertices du bas).
    low = [v for v in vs if v.z < zmin + (zmax - zmin) * 0.08]
    cy = (min(v.y for v in low) + max(v.y for v in low)) * 0.5
    s = c["height"] / (zmax - zmin)
    for v in body.data.vertices:
        v.co = Vector(((v.co.x - cx) * s, (v.co.y - cy) * s, (v.co.z - zmin) * s))
    body.data.update()
    body.name = c["name"]
    body.data.name = c["name"]
    for cl in list(body.users_collection):
        cl.objects.unlink(body)
    col().objects.link(body)
    for o in list(bpy.data.objects):
        if o != body:
            bpy.data.objects.remove(o, do_unlink=True)
    for img in bpy.data.images:
        if img.size[0] == 0:
            continue
        target = TEX_COLOR if _is_color(img) else TEX_OTHER
        if img.size[0] > target:
            img.scale(target, target)
        img.pack()
    for i, m in enumerate(body.data.materials):
        m.name = "PNJ_%s_%d" % (ARGS[1], i)
    bpy.ops.wm.save_as_mainfile(filepath=blend_path())
    print("PREPARED faces=%d height=%.3f materials=%d" % (len(body.data.polygons), c["height"], len(body.data.materials)))


def views(out_dir):
    """Vues orthographiques de face et de profil, grille tous les 10 cm (lignes plus marquées tous les 50 cm)."""
    os.makedirs(out_dir, exist_ok=True)
    sc = bpy.context.scene
    h = cfg()["height"]
    cam = bpy.data.objects.new("V_cam", bpy.data.cameras.new("V_cam"))
    sc.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = h * 1.1
    sc.camera = cam
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "FLAT"
    sc.display.shading.color_type = "TEXTURE"
    sc.render.resolution_x = 900
    sc.render.resolution_y = 900
    sc.render.film_transparent = False
    # Grille : fines barres dans le plan du personnage, derrière lui.
    gm = bpy.data.materials.new("grid")
    gm.diffuse_color = (1.0, 0.0, 0.0, 1.0)
    gm2 = bpy.data.materials.new("grid2")
    gm2.diffuse_color = (0.0, 0.3, 1.0, 1.0)
    for view, (loc, rot) in {"face": ((0, -10, h * 0.5), (math.radians(90), 0, 0)),
                             "profil": ((10, 0, h * 0.5), (math.radians(90), 0, math.radians(90)))}.items():
        cam.location = loc
        cam.rotation_euler = rot
        grid = []
        k = 0
        z = 0.0
        while z <= h + 0.001:
            bpy.ops.mesh.primitive_cube_add(size=1)
            o = bpy.context.active_object
            o.scale = (2.0, 0.002, 0.003 if k % 5 else 0.006) if view == "face" else (0.002, 2.0, 0.003 if k % 5 else 0.006)
            o.location = (0, 0.5, z) if view == "face" else (-0.5, 0, z)
            o.data.materials.append(gm if k % 5 else gm2)
            grid.append(o)
            k += 1
            z += 0.1
        for i in range(-10, 11):
            bpy.ops.mesh.primitive_cube_add(size=1)
            o = bpy.context.active_object
            x = i * 0.1
            o.scale = (0.003 if i % 5 else 0.006, 0.002, h * 2) if view == "face" else (0.002, 0.003 if i % 5 else 0.006, h * 2)
            o.location = (x, 0.5, h * 0.5) if view == "face" else (-0.5, x, h * 0.5)
            o.data.materials.append(gm if i % 5 else gm2)
            grid.append(o)
        sc.render.filepath = os.path.join(out_dir, "%s_%s.png" % (ARGS[1], view))
        bpy.ops.render.render(write_still=True)
        for o in grid:
            bpy.data.objects.remove(o, do_unlink=True)
    print("VIEWS", out_dir)


# ---------------------------------------------------------------- squelette

def joints():
    j = {n: Vector(p) for n, p in cfg()["joints"].items()}
    for s in ("L", "R"):
        d = (j["wrist." + s] - j["elbow." + s]).normalized()
        j["knuckles." + s] = j["wrist." + s] + d * HAND_LEN
        j["toe." + s] = j["ankle." + s] + Vector((0.0, -FOOT_LEN, -0.06))
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


def _candidates(co, j):
    """Os candidats d'un vertex. Chapeau et barbe suivent la tête ; une robe longue (mage) ne suit
    les jambes qu'en dessous du genou et reste sinon sur le bassin, pour ne pas se déchirer entre
    les cuisses."""
    if ARGS[1] == "troll" and abs(co.x) > 0.24 and co.z > 1.35:
        # Tête enfoncée entre d'énormes épaules : le haut des deltoïdes dépasse l'os de la tête. Il suit le buste et
        # le bras de son côté, pas la tête.
        return ["chest", "upper_arm." + ("L" if co.x > 0 else "R")]
    if ARGS[1] == "troll" and co.z > 1.35 and co.y > -0.02:
        return ["chest", "neck"]  # la bosse du dos, derrière la tête
    if co.z > j["head"].z + 0.02:
        return ["head"]
    if ARGS[1] == "demon":
        # Ébauche (Ulysse finit la peinture) : cheveux longs dans le dos sur la tête, le cou et le buste ;
        # cape sur le bassin et le dos seulement.
        if co.z > 1.25 and co.y > 0.06 and abs(co.x) < 0.22:
            return ["head", "neck", "chest"]
        if _demon_cape(co, j):
            return ["hips", "spine", "chest"]
    if ARGS[1] == "hella":
        # Crinière dans le dos et grosse tresse (jusqu'au bas des reins) : tête, cou et buste ; cape sur le
        # bassin et le dos seulement (comme le démon).
        if co.z > 1.25 and co.y > 0.04 and abs(co.x) < 0.16:
            return ["head", "neck", "chest"]
        if co.z > 0.88 and co.y > 0.19 and abs(co.x) < 0.12:
            return ["head", "neck", "chest"]
        if _demon_cape(co, j):
            return ["hips", "spine", "chest"]
    if ARGS[1] == "twin":
        # Crinière rousse sur la nuque et les épaulières : tête, cou et buste ; cape sur le bassin et le dos.
        if co.z > 1.3 and co.y > 0.05 and abs(co.x) < 0.24:
            return ["head", "neck", "chest"]
        if _demon_cape(co, j):
            return ["hips", "spine", "chest"]
    if ARGS[1] == "sage":
        # Grande barbe sur le torse et longs cheveux sur les épaules : ils suivent la tête et le cou.
        if co.z > 1.16 and co.y < -0.06 and abs(co.x) < 0.15:
            return ["head", "neck"]
        if co.z > 1.12 and co.y > 0.1 and abs(co.x) < 0.24:
            return ["head", "neck", "chest"]
    if ARGS[1] == "mage" and co.z > 1.42 and co.y > 0.08 and abs(co.x) < 0.2:
        return ["head", "neck"]  # longs cheveux noirs sur la nuque
    return None


def _demon_cape(co, j):
    """Cape du démon (même maillage que le corps) : sous les épaulières, derrière ou sur les côtés, loin
    des jambes (bottes comprises) et des mains."""
    if co.z > 1.35 or co.z < 0.1 or (co.y < 0.0 and abs(co.x) < 0.28):
        return False
    hands = min(_seg_dist(co, j["elbow." + s], j["knuckles." + s]) for s in ("L", "R"))
    legs = min(min(_seg_dist(co, j["hip." + s], j["knee." + s]) - 0.02, _seg_dist(co, j["knee." + s], j["ankle." + s]),
                   _seg_dist(co, j["ankle." + s], j["toe." + s]) - 0.02) for s in ("L", "R"))
    arms = min(_seg_dist(co, j["shoulder." + s], j["elbow." + s]) for s in ("L", "R"))
    return hands > 0.16 and legs > (0.16 if co.z < 0.55 else 0.12) and arms > 0.13


def _cut_demon_cape(body, j, segs):
    """Le générateur a soudé la cape aux jambes par endroits : ces ponts s'étireraient à chaque pas.
    On supprime les faces qui relient la cape à une jambe."""
    bm = bmesh.new()
    bm.from_mesh(body.data)
    cape = {v.index: _demon_cape(v.co, j) for v in bm.verts}
    leg = {}
    for v in bm.verts:
        if not cape[v.index]:
            bn = min(segs, key=lambda b: _seg_dist(v.co, *segs[b]))
            leg[v.index] = bn.split(".")[0] in ("thigh", "shin", "foot")
    bridges = [f for f in bm.faces if any(cape[v.index] for v in f.verts) and any(leg.get(v.index, False) for v in f.verts)]
    bmesh.ops.delete(bm, geom=bridges, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(body.data)
    bm.free()
    body.data.update()
    return len(bridges)


def rig():
    c = cfg()
    if c.get("retouche") and "force" not in ARGS:
        print("REFUS : le squelette et les poids de %s ont été retouchés à la main dans Blender ; "
              "relancer avec « rig %s force » pour les recalculer (retouches perdues)." % (c["name"], ARGS[1]))
        return
    body = bpy.data.objects[c["name"]]
    rig_name = c["name"] + "_rig"
    for o in list(bpy.data.objects):
        if o.type == "ARMATURE":
            bpy.data.objects.remove(o, do_unlink=True)
    body.vertex_groups.clear()
    for m in list(body.modifiers):
        body.modifiers.remove(m)
    j = joints()
    layout = bone_layout(j)
    arm_data = bpy.data.armatures.new(rig_name)
    rig_obj = bpy.data.objects.new(rig_name, arm_data)
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
    if ARGS[1] == "demon" or c.get("cape"):
        print("CUT bridges=%d" % _cut_demon_cape(body, j, segs))
    for v in body.data.vertices:
        p = v.co
        cands = _candidates(p, j) or list(segs)
        ds = sorted((_seg_dist(p, *segs[bn]), bn) for bn in cands)[:2]
        wts = [1.0 / max(d, 0.01) ** 4 for d, _ in ds]
        tot = sum(wts)
        for (d, bn), wi in zip(ds, wts):
            if wi / tot > 0.02:
                body.vertex_groups[bn].add([v.index], wi / tot, "REPLACE")
    body.parent = rig_obj
    mod = body.modifiers.new("Armature", "ARMATURE")
    mod.object = rig_obj
    bpy.ops.wm.save_as_mainfile(filepath=blend_path())
    print("RIGGED", rig_name, len(body.data.vertices))


if __name__ == "__main__":
    ARGS = sys.argv[sys.argv.index("--") + 1:]
    if ARGS[0] == "prepare":
        prepare()
    elif ARGS[0] == "views":
        views(ARGS[2])
    elif ARGS[0] == "rig":
        rig()
