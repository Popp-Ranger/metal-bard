# Transfert des animations Mixamo sur le squelette de Riffald (17 os), puis export du glb.
#
# Usage (sans interface) :
#   blender --background art/riffald/riffald.blend --python art/riffald/retarget_mixamo.py -- export
#   blender --background art/riffald/riffald.blend --python art/riffald/retarget_mixamo.py -- sheets <dossier>
#   blender --background art/riffald/riffald.blend --python art/riffald/retarget_mixamo.py -- clips
#     (clips des squelettes ennemis, squelette sans maillage : assets/animations/squelettes.glb)
# Même chose avec art/persof1/persof1.blend pour l'héroïne (personnage choisi d'après le .blend ouvert).
#
# Principe : pour chaque image, chaque os de Riffald prend la rotation monde de l'os Mixamo
# correspondant, relative à sa pose de repos :
#     R_riffald = R_mixamo · R_mixamo_repos⁻¹ · A · R_riffald_repos
# où A aligne l'os de Riffald au repos (pose en A) sur l'os Mixamo au repos (pose en T).
# Le bassin suit la hauteur de celui de Mixamo (mise à l'échelle des jambes) ; les déplacements
# horizontaux sont supprimés quand le jeu déplace lui-même le personnage.
# Les fichiers Mixamo bruts (assets/animations/mixamo, non versionnés) ne sont pas modifiés.
import bpy, math, os, sys
import numpy as np
from mathutils import Matrix, Quaternion, Vector

# MB_ROOT : racine du dépôt quand le .blend ouvert est une copie hors dépôt (mode « clips »).
ROOT = os.environ.get("MB_ROOT") or os.path.abspath(os.path.join(os.path.dirname(bpy.data.filepath), "..", ".."))
SRC = os.path.join(ROOT, "assets", "animations", "mixamo")
# Personnage choisi d'après le fichier .blend ouvert : (armature, collection exportée, glb du jeu, clips à
# exporter : None = tous ceux de ANIMS ; liste = ces clips ; dict = nom dans le jeu -> clip source, ex. le repos
# « idle » du tavernier pris dans « Orc Idle »). PNJ et ennemis (art/pnj) : seulement leurs clips.
PNJ_GLB = os.path.join(ROOT, "assets", "models", "pnj")
CHARACTERS = {
    "riffald": ("Riffald_rig", "Riffald", os.path.join(ROOT, "assets", "models", "riffald", "riffald.glb"), None),
    "persof1": ("PersoF1_rig", "PersoF1", os.path.join(ROOT, "assets", "models", "persof1", "persof1.glb"), None),
    "demon": ("Demon_rig", "Demon", os.path.join(ROOT, "assets", "models", "demon", "demon.glb"), None),
    "hella": ("Hella_rig", "Hella", os.path.join(ROOT, "assets", "models", "hella", "hella.glb"), None),
    "mage": ("Mage_rig", "Mage", os.path.join(PNJ_GLB, "mage.glb"), {"idle": "idle_pnj", "walk": "walk", "run": "run"}),
    "tavernier": ("Tavernier_rig", "Tavernier", os.path.join(PNJ_GLB, "tavernier.glb"), {"idle": "idle_orc", "walk": "walk", "run": "run"}),
    "gloubah": ("Gloubah_rig", "Gloubah", os.path.join(PNJ_GLB, "gloubah.glb"),
                {"idle": "idle_orc", "walk": "walk", "run": "run", "slash": "slash", "hit": "hit", "die": "die", "victory": "victory"}),
    "hibours": ("Hibours_rig", "Hibours", os.path.join(PNJ_GLB, "hibours.glb"),
                {"idle": "idle_pnj", "walk": "walk", "run": "run", "victory": "victory"}),
    "squelette": ("Squelette_rig", "Squelette", os.path.join(PNJ_GLB, "squelette.glb"),
                  ["zombie_idle", "zombie_run", "slash", "hit", "die"]),
}
RIG, COLLECTION, OUT_GLB, ONLY = CHARACTERS[os.path.splitext(os.path.basename(bpy.data.filepath))[0].lower()]
FPS = 30

# Os de Riffald -> os Mixamo (sans le préfixe « mixamorigN: »).
BONES = {
    "hips": "Hips", "spine": "Spine1", "chest": "Spine2", "neck": "Neck", "head": "Head",
    "upper_arm.L": "LeftArm", "forearm.L": "LeftForeArm", "hand.L": "LeftHand",
    "upper_arm.R": "RightArm", "forearm.R": "RightForeArm", "hand.R": "RightHand",
    "thigh.L": "LeftUpLeg", "shin.L": "LeftLeg", "foot.L": "LeftFoot",
    "thigh.R": "RightUpLeg", "shin.R": "RightLeg", "foot.R": "RightFoot",
}

# Nom dans le jeu : (fichier, première image, dernière image, déplacement horizontal du bassin)
#   root : "keep" = conservé, "strip" = supprimé, "loop" = dérive linéaire retirée (cycle en place)
# Passages choisis d'après les planches de contrôle (sheets).
ANIMS = {
    # Repos des héros (pose fournie par Ulysse, 2 oct. 2026 ; avant : « Happy Idle »).
    "idle": ("heroPose", None, None, "keep"),
    "walk": ("Walking", None, None, "loop"),
    "run": ("Running", None, None, "loop"),
    # Coups de guitare, alternés : levée au-dessus de la tête puis abattue (fin de « High Spin
    # Attack », sans la vrille) ; armée sur l'épaule puis abattue en diagonale (début de « Slash »).
    "smash": ("Great Sword High Spin Attack", 26, 47, "strip"),
    "slash": ("Great Sword Slash", 4, 34, "strip"),
    "headbang": ("headbang", None, None, "keep"),
    # Onde de choc : bras levés puis frappe du sol accroupi.
    "area": ("Standing 2H Magic Area Attack 01", 21, 62, "keep"),
    # Sorts de soutien (bouclier, amplis, phénix...) : ramassé puis bras au ciel.
    "cast": ("Standing 2H Cast Spell 01", 8, 60, "keep"),
    "hit": ("Reaction", 1, 20, "keep"),
    "die": ("Dying", None, None, "keep"),
    "slide": ("Running Slide", 7, 45, "strip"),
    # Stage Diving : vol bras écartés au-dessus de la foule, puis réception.
    "fall": ("Falling Idle", None, None, "keep"),
    "land": ("Falling To Landing", 8, 33, "keep"),
    # Allongé sur le dos (début de « Sleeping Idle », avant qu'il se retourne).
    "sleep": ("Sleeping Idle", 1, 110, "keep"),
    # Poings levés (victoire sur le boss).
    "victory": ("Victory", 10, 115, "keep"),
    # Repos voûté, à bout de souffle (vie basse).
    "idle_tired": ("Mutant Breathing Idle", None, None, "keep"),
}
# Clips des squelettes ennemis, sur le même squelette mais exportés à part, sans maillage (mode « clips »,
# lus par LocoAnimator) : ils ne vont pas dans le glb des héros.
CLIPS = {
    "zombie_idle": ("Zombie Idle", None, None, "keep"),
    "zombie_run": ("Zombie Running", None, None, "loop"),
    # Repos des PNJ à corps procédural (clients, Gérald...), style « pnj_corps » de HeroAnimator.
    "idle_pnj": ("pnjPose", None, None, "keep"),
}
CLIPS_GLB = os.path.join(ROOT, "assets", "animations", "squelettes.glb")
# Repos propres à un PNJ importé (voir CHARACTERS).
NPC_CLIPS = {"idle_orc": ("Orc Idle", None, None, "keep")}


def _q(m):
    return m.to_3x3().normalized().to_quaternion()


def import_source(name):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=os.path.join(SRC, name + ".fbx"))
    arm = [o for o in bpy.data.objects if o not in before and o.type == "ARMATURE"][0]
    prefix = arm.pose.bones[0].name.split(":")[0] + ":"
    return arm, prefix


def retarget(rig, src, prefix, game_name, first, last, root_mode):
    act = src.animation_data.action
    f0 = int(act.frame_range[0]) if first is None else first
    f1 = int(act.frame_range[1]) if last is None else last
    tb = rig.data.bones
    sb = src.data.bones
    # Repos (espace monde).
    t_rest = {t: rig.matrix_world @ tb[t].matrix_local for t in BONES}
    s_rest = {t: src.matrix_world @ sb[prefix + s].matrix_local for t, s in BONES.items()}
    align = {}
    for t in BONES:
        td = t_rest[t].to_3x3().normalized().col[1]
        sd = s_rest[t].to_3x3().normalized().col[1]
        align[t] = td.rotation_difference(sd)
    s_hips_rest = s_rest["hips"].translation
    t_hips_rest = t_rest["hips"].translation
    ratio = t_hips_rest.z / s_hips_rest.z
    # Trajectoire horizontale du bassin (pour la supprimer).
    scene = bpy.context.scene
    hip_track = {}
    for f in range(f0, f1 + 1):
        scene.frame_set(f)
        hip_track[f] = (src.matrix_world @ src.pose.bones[prefix + "Hips"].matrix).translation.copy()
    start, end = hip_track[f0], hip_track[f1]

    action = bpy.data.actions.new(game_name)
    rig.animation_data_create()
    rig.animation_data.action = action
    order = [b.name for b in rig.data.bones]  # parents avant enfants
    for f in range(f0, f1 + 1):
        scene.frame_set(f)
        world = {}
        for t in order:
            s = src.pose.bones[prefix + BONES[t]]
            sw = src.matrix_world @ s.matrix
            q = _q(sw) @ _q(s_rest[t]).inverted() @ align[t] @ _q(t_rest[t])
            bone = tb[t]
            if bone.parent is None:
                p = hip_track[f]
                h = Vector((p.x, p.y, p.z))
                if root_mode == "strip":
                    h.x, h.y = start.x, start.y
                elif root_mode == "loop":
                    k = (f - f0) / max(1, f1 - f0)
                    drift = start.lerp(end, k)
                    h.x -= drift.x - start.x
                    h.y -= drift.y - start.y
                pos = Vector((h.x * ratio, h.y * ratio, h.z * ratio))
                if root_mode in ("strip", "loop"):
                    pos.x -= start.x * ratio
                    pos.y -= start.y * ratio
            else:
                pw = world[bone.parent.name]
                rel = bone.parent.matrix_local.inverted() @ bone.matrix_local
                pos = (pw @ rel).translation
            world[t] = Matrix.Translation(pos) @ q.to_matrix().to_4x4()
        for t in order:
            bone = tb[t]
            if bone.parent is None:
                local = bone.matrix_local.inverted() @ world[t]
            else:
                rel = bone.parent.matrix_local.inverted() @ bone.matrix_local
                local = rel.inverted() @ world[bone.parent.name].inverted() @ world[t]
            pb = rig.pose.bones[t]
            pb.rotation_mode = "QUATERNION"
            loc, rot, _sc = local.decompose()
            pb.rotation_quaternion = rot
            pb.keyframe_insert("rotation_quaternion", frame=f - f0 + 1, group=t)
            if bone.parent is None:
                pb.location = loc
                pb.keyframe_insert("location", frame=f - f0 + 1, group=t)
    action.use_fake_user = True
    return action, f1 - f0 + 1


def build_all(rig, names=None, table=None):
    actions = []
    for game_name, (file, first, last, root_mode) in (table or ANIMS).items():
        if names and game_name not in names:
            continue
        if not os.path.exists(os.path.join(SRC, file + ".fbx")):
            print("MANQUANT", file)
            continue
        src, prefix = import_source(file)
        action, n = retarget(rig, src, prefix, game_name, first, last, root_mode)
        actions.append((action, n))
        bpy.data.objects.remove(src, do_unlink=True)
        print("ANIM", game_name, n)
    rig.animation_data.action = None
    for pb in rig.pose.bones:
        pb.location = (0, 0, 0)
        pb.rotation_quaternion = (1, 0, 0, 0)
    return actions


def fill_unweighted(rig):
    """Vertices sans poids (somme nulle, souvent laissés par une retouche à la peinture de poids) : ils
    resteraient figés à leur place pendant l'animation et étireraient de grands pans de maillage. Ils
    prennent la moyenne des poids de leurs voisins déjà pondérés, de proche en proche (la peinture voisine
    est prolongée) ; une pièce isolée sans aucun poids suit l'os le plus proche. Puis chaque vertex est
    normalisé (somme des poids = 1, comme le fait Blender à l'affichage). Le .blend n'est pas enregistré :
    seul le glb exporté en profite."""
    bones = {b.name: (b.head_local, b.tail_local) for b in rig.data.bones}

    def seg_dist(p, a, b):
        ab = b - a
        t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-9)))
        return (a + ab * t - p).length

    for o in bpy.data.objects:
        if o.type != "MESH" or o.parent != rig:
            continue
        me = o.data
        names = {g.index: g.name for g in o.vertex_groups}
        nb = [[] for _ in me.vertices]
        for e in me.edges:
            a, b = e.vertices
            nb[a].append(b)
            nb[b].append(a)
        W = [{names[g.group]: g.weight for g in v.groups if g.weight > 0.0 and g.group in names} for v in me.vertices]
        pending = {i for i, w in enumerate(W) if sum(w.values()) < 0.01}
        empty = len(pending)
        while pending:
            done = []
            for i in pending:
                acc, k = {}, 0
                for j in nb[i]:
                    if j not in pending:
                        k += 1
                        for g, w in W[j].items():
                            acc[g] = acc.get(g, 0.0) + w
                if k:
                    done.append((i, {g: w / k for g, w in acc.items()}))
            if not done:
                break
            for i, w in done:
                W[i] = w
                pending.discard(i)
        for i in pending:  # pièce isolée : l'os le plus proche
            p = me.vertices[i].co
            W[i] = {min(bones, key=lambda bn: seg_dist(p, *bones[bn])): 1.0}
        changed = 0
        for i, v in enumerate(me.vertices):
            tot = sum(W[i].values())
            if tot <= 0.0:
                continue
            target = {g: w / tot for g, w in W[i].items() if w / tot > 0.001}
            current = {names[g.group]: g.weight for g in v.groups if g.group in names}
            if all(abs(current.get(g, 0.0) - w) < 1e-4 for g, w in target.items()) and \
                    all(g in target or w < 1e-4 for g, w in current.items()):
                continue
            changed += 1
            for g in list(current):
                o.vertex_groups[g].remove([i])
            for g, w in target.items():
                if o.vertex_groups.get(g) is None:
                    o.vertex_groups.new(name=g)
                o.vertex_groups[g].add([i], w, "REPLACE")
        print("POIDS %s : %d vertices sans poids complétés (%d par une pièce isolée), %d normalisés"
              % (o.name, empty, len(pending), changed))


def export(rig, actions, out=None, rig_only=False):
    if not rig_only:
        fill_unweighted(rig)
    # Chaque animation dans une piste NLA : l'export glTF en fait une animation séparée.
    ad = rig.animation_data
    for tr in list(ad.nla_tracks):
        ad.nla_tracks.remove(tr)
    for action, n in actions:
        tr = ad.nla_tracks.new()
        tr.name = action.name
        tr.strips.new(action.name, 1, action)
        tr.mute = True
    bpy.ops.object.select_all(action="DESELECT")
    for o in ([rig] if rig_only else bpy.data.collections[COLLECTION].objects):
        o.select_set(True)
    bpy.context.scene.render.fps = FPS
    out = out or OUT_GLB
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=True, export_apply=False,
                              export_yup=True, export_animations=True, export_animation_mode="NLA_TRACKS",
                              export_force_sampling=True, export_frame_step=1, export_anim_slide_to_zero=True,
                              export_def_bones=False, export_optimize_animation_size=False,
                              export_image_format="JPEG", export_jpeg_quality=90)  # atlas peint en JPEG
    print("EXPORT", out)


def sheets(rig, actions, out_dir, per_row=int(os.environ.get("PER_ROW", 10)), w=150, h=230):
    """Planche de contrôle : pour chaque animation, `per_row` images réparties (Workbench)."""
    os.makedirs(out_dir, exist_ok=True)
    sc = bpy.context.scene
    cam = bpy.data.objects.new("RT_cam", bpy.data.cameras.new("RT_cam"))
    sc.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 2.6
    sc.camera = cam
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "STUDIO"
    sc.display.shading.color_type = "TEXTURE"
    sc.render.resolution_x = w
    sc.render.resolution_y = h
    sc.render.resolution_percentage = 100
    sc.render.film_transparent = False
    yaw = math.radians(-35)  # vue de 3/4 face, comme la caméra du jeu
    dist = 6.0
    cam.location = (math.sin(yaw) * dist, -math.cos(yaw) * dist, 2.0)
    cam.rotation_euler = (math.radians(80), 0, yaw)
    tmp = os.path.join(out_dir, "_frame.png")
    for action, n in actions:
        rig.animation_data.action = action
        frames = [1 + round(i * (n - 1) / (per_row - 1)) for i in range(per_row)]
        row = np.zeros((h, w * per_row, 4), dtype=np.float32)
        for i, f in enumerate(frames):
            sc.frame_set(f)
            sc.render.filepath = tmp
            bpy.ops.render.render(write_still=True)
            img = bpy.data.images.load(tmp)
            px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
            row[:, i * w:(i + 1) * w] = px
            bpy.data.images.remove(img)
        out = bpy.data.images.new(action.name, w * per_row, h)
        out.pixels = row.ravel()
        out.filepath_raw = os.path.join(out_dir, action.name + ".png")
        out.file_format = "PNG"
        out.save()
        print("SHEET", action.name, frames)
    rig.animation_data.action = None


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else ["export"]
    rig = bpy.data.objects[RIG]
    if args[0] == "sheets":
        table = dict(ANIMS, **CLIPS) if args[2:] else ANIMS
        acts = build_all(rig, args[2:] or None, table)
        sheets(rig, acts, args[1])
    elif args[0] == "clips":
        # Squelette seul + clips des squelettes ennemis -> assets/animations/squelettes.glb
        acts = build_all(rig, None, CLIPS)
        export(rig, acts, CLIPS_GLB, rig_only=True)
    else:
        if ONLY is None:
            acts = build_all(rig)
        elif isinstance(ONLY, dict):
            full = dict(ANIMS, **CLIPS, **NPC_CLIPS)
            acts = build_all(rig, None, {out: full[src] for out, src in ONLY.items()})
        else:
            acts = build_all(rig, ONLY, dict(ANIMS, **CLIPS))
        export(rig, acts)
