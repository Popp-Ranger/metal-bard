# Détection des notes d'un solo de guitare (début et hauteur de chaque note) pour en faire la partition d'un
# mini-jeu de solo (data/*.json, voir SoloMinigame).
#
# Usage (Blender sert de lecteur mp3 et fournit numpy) :
#   blender --background --factory-startup --python tools/audio/detect_notes.py -- <audio> <sortie.json>
#       [ecart_min_s=0.15] [image_controle.png]
#
# Un solo de guitare saturée est souvent lié (legato, glissés, vibrato) : ses notes n'ont pas toujours d'attaque
# franche, et le flux d'énergie seul en rate beaucoup. On suit donc la mélodie :
#  1. spectre (fenêtres de 4096, pas de 256) ; pour chaque instant, la fondamentale la plus saillante entre
#     196 Hz et 1,5 kHz (somme pondérée des 5 premières harmoniques, au cinquième de demi-ton) : la guitare solo,
#     au-dessus des accords de la rythmique ;
#  2. hauteur lissée (médiane sur 70 ms : le vibrato disparaît) puis arrondie au demi-ton ; une nouvelle note
#     commence quand la hauteur change et tient au moins 70 ms ;
#  3. les attaques franches (flux spectral 200 Hz - 4 kHz) au milieu d'une note tenue la coupent (200 ms après son début au plus tôt) : notes répétées ;
#  4. deux notes jamais plus proches que ecart_min_s (la partition reste jouable) ;
#  5. corde (0 à 3) selon la hauteur, par quartiles du morceau.
import aud, json, os, sys
import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
N_FFT = 4096
HOP = 256
MIDI_LO, MIDI_HI = 59, 92          # si 3 (247 Hz) -> sol# 6 (1,7 kHz)
STEP = 0.2                          # pas de la grille de hauteurs (demi-ton)
HOLD = 0.07                         # durée minimale d'une note (s)


def load(path):
    snd = aud.Sound(path)
    rate = int(snd.specs[0])
    data = np.asarray(snd.data(), dtype=np.float32)
    return (data.mean(axis=1) if data.ndim == 2 else data), rate


def spectrum(x):
    win = np.hanning(N_FFT).astype(np.float32)
    n = 1 + max(0, (len(x) - N_FFT) // HOP)
    frames = np.lib.stride_tricks.as_strided(x, shape=(n, N_FFT), strides=(x.strides[0] * HOP, x.strides[0]))
    return np.abs(np.fft.rfft(frames * win, axis=1))


def melody(spec, rate):
    """Hauteur (midi, flottant) et saillance de la mélodie à chaque instant."""
    logm = np.log1p(spec * 20.0)
    grid = np.arange(MIDI_LO, MIDI_HI, STEP)
    f0 = 440.0 * 2 ** ((grid - 69) / 12)
    bins = np.arange(spec.shape[1])
    sal = np.zeros((spec.shape[0], len(grid)), dtype=np.float32)
    for h in range(1, 5):
        k = f0 * h * N_FFT / rate
        ok = k < spec.shape[1] - 1
        lo = np.floor(k[ok]).astype(int)
        fr = (k[ok] - lo).astype(np.float32)
        val = logm[:, lo] * (1 - fr) + logm[:, lo + 1] * fr
        sal[:, ok] += val * (0.55 ** (h - 1))
    best = np.argmax(sal, axis=1)
    return grid[best], sal[np.arange(len(best)), best], bins


def flux_onsets(spec, rate, k=3.0):
    freqs = np.fft.rfftfreq(N_FFT, 1.0 / rate)
    band = (freqs >= 200) & (freqs <= 4000)
    logm = np.log1p(spec[:, band] * 10.0)
    flux = np.concatenate([[0.0], np.maximum(0.0, np.diff(logm, axis=0)).sum(axis=1)])
    flux /= max(flux.max(), 1e-9)
    w = int(0.4 * rate / HOP)
    pad = np.pad(flux, (w, w), mode="edge")
    med = np.array([np.median(pad[i:i + 2 * w + 1]) for i in range(len(flux))])
    mad = np.array([np.median(np.abs(pad[i:i + 2 * w + 1] - med[i])) for i in range(len(flux))])
    thr = med + k * mad + 0.02
    return [i for i in range(1, len(flux) - 1) if flux[i] > thr[i] and flux[i] >= flux[i - 1] and flux[i] >= flux[i + 1]]


def median_filter(a, w):
    pad = np.pad(a, (w, w), mode="edge")
    return np.array([np.median(pad[i:i + 2 * w + 1]) for i in range(len(a))])


def notes_of(x, rate, min_gap):
    spec = spectrum(x)
    fps = rate / HOP
    midi, sal, _ = melody(spec, rate)
    voiced = sal > np.percentile(sal, 25)  # silences et passages sans solo
    smooth = median_filter(midi, int(0.035 * fps))
    semi = np.round(smooth).astype(int)
    hold = int(HOLD * fps)
    starts = []  # (trame, midi)
    cur = None
    i = 0
    while i < len(semi):
        if not voiced[i]:
            cur = None
            i += 1
            continue
        if semi[i] != cur:
            j = i
            while j < len(semi) and semi[j] == semi[i] and voiced[j]:
                j += 1
            if j - i >= hold:
                cur = semi[i]
                starts.append((i, int(cur)))
                i = j
                continue
        i += 1
    # attaques franches au milieu d'une note tenue : note répétée
    ons = flux_onsets(spec, rate)
    for o in ons:
        if not voiced[o]:
            continue
        prev = [s for s in starts if s[0] <= o]
        if prev and o - prev[-1][0] >= int(0.2 * fps):
            starts.append((o, int(semi[o])))
    starts.sort()
    gap = int(min_gap * fps)
    out = []
    for f, m in starts:
        if out and f - out[-1][0] < gap:
            continue
        out.append((f, m))
    # une trame est datée par son début ; ce qu'elle entend est centré une demi-fenêtre plus loin
    half = N_FFT / 2 / rate
    return [(f / fps + half, m) for f, m in out], spec, midi, voiced


def main():
    args = sys.argv[sys.argv.index("--") + 1:]
    src, dst = args[0], args[1]
    min_gap = float(args[2]) if len(args) > 2 else 0.15
    x, rate = load(src)
    duration = len(x) / rate
    found, spec, midi, voiced = notes_of(x, rate, min_gap)
    pitches = sorted(m for _, m in found)
    qs = [pitches[int(len(pitches) * q)] for q in (0.25, 0.5, 0.75)] if pitches else [0, 0, 0]
    notes = []
    for t, m in found:
        lane = min(3, sum(1 for q in qs if m >= q))
        notes.append({"t": round(t, 3), "midi": m, "hz": int(round(440 * 2 ** ((m - 69) / 12))), "lane": lane})
    chart = {
        "source": "res://" + os.path.relpath(os.path.abspath(src), ROOT).replace("\\", "/"),
        "duration": round(duration, 3),
        "info": "Notes détectées automatiquement (tools/audio/detect_notes.py) : mélodie de la guitare solo suivie au "
                f"demi-ton, attaques franches ajoutées, écart minimal {min_gap} s ; la corde dépend de la hauteur.",
        "notes": notes,
    }
    with open(dst, "w", encoding="utf-8") as f:
        json.dump(chart, f, ensure_ascii=False, indent="\t")
    gaps = np.diff([n["t"] for n in notes]) if len(notes) > 1 else np.array([0.0])
    print(f"[notes] {len(notes)} notes sur {duration:.2f} s ; écart min {gaps.min():.3f} s, médian "
          f"{np.median(gaps):.3f} s, max {gaps.max():.2f} s ; cordes "
          f"{[sum(1 for n in notes if n['lane'] == l) for l in range(4)]}")
    if len(args) > 3:
        control_image(args[3], spec, rate, midi, voiced, notes)


def control_image(path, spec, rate, midi, voiced, notes):
    """Spectrogramme (196 Hz - 1,5 kHz, échelle en demi-tons), mélodie suivie (cyan) et notes retenues (traits de
    la couleur de leur corde)."""
    import bpy
    fps = rate / HOP
    W = spec.shape[0]
    PX = 6  # pixels par demi-ton
    H = (MIDI_HI - MIDI_LO) * PX
    img = np.zeros((H, W), dtype=np.float32)
    for r in range(H):
        m = MIDI_LO + r / PX
        k = int(round(440 * 2 ** ((m - 69) / 12) * N_FFT / rate))
        img[r] = spec[:, k]
    img = np.clip(np.log1p(img * 5) / np.percentile(np.log1p(img * 5), 99.5), 0, 1)
    rgba = np.zeros((H, W, 4), dtype=np.float32)
    rgba[..., 0] = img * 0.8
    rgba[..., 1] = img ** 1.5 * 0.7
    rgba[..., 2] = img ** 3 * 0.5
    rgba[..., 3] = 1
    for s in range(int(W / fps) + 1):
        rgba[:, min(W - 1, int(s * fps)), :3] = 0.3
    for i in range(W):
        if voiced[i]:
            r = int((midi[i] - MIDI_LO) * PX)
            rgba[max(0, r - 1):r + 1, i, :3] = (0.2, 1.0, 1.0)
    cols = [(0.3, 0.9, 0.35), (0.95, 0.25, 0.2), (1.0, 0.85, 0.2), (0.3, 0.55, 1.0)]
    for n in notes:
        c = int(n["t"] * fps)
        r = int((n["midi"] - MIDI_LO) * PX)
        rgba[max(0, r - 10):r + 10, max(0, c - 1):c + 2, :3] = cols[n["lane"]]
    # en 4 bandes empilées (la première en haut) pour rester lisible
    rows = 4
    cw = (W + rows - 1) // rows
    rgba = np.pad(rgba, ((0, 0), (0, cw * rows - W), (0, 0)))
    sheet = np.concatenate([rgba[:, k * cw:(k + 1) * cw] for k in reversed(range(rows))], axis=0)
    o = bpy.data.images.new("controle", cw, H * rows)
    o.pixels = sheet.ravel()
    o.filepath_raw = path
    o.file_format = "PNG"
    o.save()


main()
