# Jauge de vie du HUD : la main cornue du dessin d'Ulysse (art/hud/main_cornes_dessin.jpg, 6 oct. 2026), sans la couleur
# de peau, devient le réservoir de la vie (remplace la main de verre rendue par build_hud.py).
#
# Usage (sans interface) :
#   blender --background --factory-startup --python art/hud/main_cornes.py
#       -> assets/ui/main_vie.png : le dessin (contour noir, plis des doigts, bracelet à pointes), l'intérieur de la main
#          en verre sombre translucide : le jeu dessine le liquide dessous (scripts/ui/reservoir.gd) ;
#       -> assets/ui/main_vie_masque.png : la silhouette de la main (blanc), où monte le liquide.
#
# Le damier du fond est peint dans le JPG (pas de vraie transparence) : il est retiré par remplissage depuis les bords
# (pixels clairs et gris), arrêté par le contour noir. La peau (pixels orangés) est retirée ; les plis restent.
import bpy, os
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
SRC = os.path.join(HERE, "main_cornes_dessin.jpg")
OUT = os.path.join(ROOT, "assets", "ui")
SIZE = (420, 560)  # taille des images du réservoir (le HUD l'affiche en 150 × 200)
GLASS = (0.05, 0.04, 0.05, 0.42)  # verre sombre à la place de la peau (on voit le liquide à travers)


def load(path):
    img = bpy.data.images.load(path)
    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    return px[::-1].copy()  # Blender range les lignes de bas en haut


def save(rgba, name):
    h, w = rgba.shape[:2]
    img = bpy.data.images.new(name, w, h, alpha=True)
    img.pixels[:] = rgba[::-1].reshape(-1).tolist()
    img.filepath_raw = os.path.join(OUT, name + ".png")
    img.file_format = "PNG"
    img.save()


def dilate(m, n=1):
    for _ in range(n):
        d = m.copy()
        d[1:] |= m[:-1]
        d[:-1] |= m[1:]
        d[:, 1:] |= m[:, :-1]
        d[:, :-1] |= m[:, 1:]
        m = d
    return m


def erode(m, n=1):
    return ~dilate(~m, n)


px = load(SRC)
rgb = px[..., :3]
lum = rgb.mean(axis=2)
sat = rgb.max(axis=2) - rgb.min(axis=2)
# Fond : damier clair et gris, relié aux bords de l'image.
bg_like = (lum > 0.5) & (sat < 0.1)
bg = np.zeros_like(bg_like)
bg[0, :] = bg_like[0, :]
bg[-1, :] = bg_like[-1, :]
bg[:, 0] = bg_like[:, 0]
bg[:, -1] = bg_like[:, -1]
while True:
    grown = dilate(bg) & bg_like
    if grown.sum() == bg.sum():
        break
    bg = grown
# Peau : orangée (rouge > vert > bleu, assez saturée) et pas trop sombre.
r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
skin = (~bg) & (r > 0.45) & (r - b > 0.15) & (r >= g) & (g >= b)
# Silhouette de la main (masque) : la peau, plis compris (fermeture morphologique), sans déborder du contour.
inside = erode(dilate(skin, 6), 6) & ~bg
inside &= ~(lum < 0.12)  # le contour noir n'en fait pas partie
inside = erode(dilate(inside, 2), 2)
# Le dessin : contour, plis, bracelet ; la peau devient du verre sombre ; le fond est transparent.
art = px.copy()
art[..., 3] = 1.0
art[skin] = GLASS
art[bg] = (0.0, 0.0, 0.0, 0.0)
# Liseré du fond (anticrénelage du contour sur le damier) : la transparence suit la noirceur du pixel.
fringe = dilate(bg, 2) & ~bg & ~skin
alpha = np.clip((0.8 - lum) / 0.45, 0.0, 1.0)
art[fringe, 3] = alpha[fringe]
art[fringe, :3] = rgb[fringe] * 0.3
# Cadrage : la main entière, centrée dans une image de 420 × 560.
ys, xs = np.nonzero(art[..., 3] > 0.05)
y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
crop = art[y0:y1, x0:x1]
mcrop = inside[y0:y1, x0:x1].astype(np.float32)
scale = min((SIZE[0] - 16) / crop.shape[1], (SIZE[1] - 16) / crop.shape[0])
nw, nh = int(crop.shape[1] * scale), int(crop.shape[0] * scale)


def resize(a, w, h):
    # Rééchantillonnage par moyenne de zones (réduction).
    ys = np.linspace(0, a.shape[0], h + 1).astype(int)
    xs = np.linspace(0, a.shape[1], w + 1).astype(int)
    out = np.zeros((h, w) + a.shape[2:], dtype=np.float32)
    for j in range(h):
        row = a[ys[j]:max(ys[j + 1], ys[j] + 1)]
        for i in range(w):
            out[j, i] = row[:, xs[i]:max(xs[i + 1], xs[i] + 1)].reshape(-1, *a.shape[2:]).mean(axis=0)
    return out


# Couleurs prémultipliées pendant la réduction (pas de halo sombre sur les bords transparents).
pm = crop.copy()
pm[..., :3] *= pm[..., 3:4]
small = resize(pm, nw, nh)
a = small[..., 3:4]
small[..., :3] = np.where(a > 1e-4, small[..., :3] / np.maximum(a, 1e-4), 0.0)
small_mask = resize(mcrop, nw, nh)
out = np.zeros((SIZE[1], SIZE[0], 4), dtype=np.float32)
ox, oy = (SIZE[0] - nw) // 2, (SIZE[1] - nh) // 2
out[oy:oy + nh, ox:ox + nw] = small
mask = np.zeros((SIZE[1], SIZE[0], 4), dtype=np.float32)
mask[oy:oy + nh, ox:ox + nw, :3] = 1.0
mask[oy:oy + nh, ox:ox + nw, 3] = np.clip(small_mask, 0.0, 1.0)
save(out, "main_vie")
save(mask, "main_vie_masque")
print("MAIN_CORNES %dx%d -> %dx%d (peau %d px, masque %d px)" % (crop.shape[1], crop.shape[0], nw, nh, skin.sum(), inside.sum()))
