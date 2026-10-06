# HUD et menus (v0.1.46)

Inspiré de la planche fournie par Ulysse (5 oct. 2026) : fer noirci, pointes, crânes, chaînes, runes rougeoyantes.
La main et l'enceinte sont volontairement petites : seuls leurs réservoirs comptent.

## Éléments (rendus dans Blender)

```
blender --background --factory-startup --python art/hud/build_hud.py -- [element...]
```

Écrit `assets/ui/<element>.png` (fond transparent) :

| Élément | Rôle |
|---|---|
| `main_vie` (+ `_masque`) | la main cornue du dessin d'Ulysse (`art/hud/main_cornes_dessin.jpg`), sans la couleur de peau = **réservoir de vie** (bas à gauche) : le liquide rouge remplit la main, sous le contour noir, les plis et le bracelet à pointes ; la partie vide est en verre sombre. Fabriquée par `art/hud/main_cornes.py` (fond en damier retiré, peau retirée, masque = silhouette de la main) |
| `enceinte_db` (+ `_masque`) | baffle de scène tout en verre fumé = **réservoir de décibels** (bas à droite) ; coins, cerclages, boutons et pointes de métal |
| `barre_sorts` | cadre de la barre de sorts : crânes des squelettes ennemis (tête découpée dans art/pnj/squelette.blend), cornu au centre, pointes, chaînes pendantes |
| `case` | cadre de fer d'une case de sort |
| `cadre` | panneau des menus, découpé en 9 parties (coins de 48 px) |
| `bouton` | bouton des menus, découpé en 9 parties (bords de 18 px) |

Le **masque** d'un réservoir est la silhouette du récipient (pièces de verre réunies et remaillées en une seule
coque) ; le jeu dessine le liquide dans cette silhouette, puis l'image de verre par-dessus.

## Dans le jeu

- `Reservoir` (`scripts/ui/reservoir.gd`) : l'image, puis son masque dessiné par `shaders/reservoir.gdshader`
  (liquide qui monte du bas au haut de la zone blanche, surface qui ondule, remous, bulles, écume, éclair blanc
  quand on perd des PV), et une plaque de fer avec le texte (« VIE 61 % · 23 / 38 », « dB 82 % · 61 / 74 »).
  Le niveau suit la valeur en douceur.
- `Hud` : réservoirs dans les coins bas, barre de sorts dans son cadre (11 cases de 72 px : touche en haut à
  gauche, nom au centre, coût en dB ou nombre de potions en bas à droite, voile de recharge), barre d'XP sous le nom.
- `IronFrame` (`scripts/ui/iron_frame.gd`) : style de panneau ou de bouton à partir d'une texture découpée en 9 ;
  `dim` assombrit tout l'écran derrière (fenêtres modales). `UiStyle.frame()`, `UiStyle.button_box()` et
  `UiStyle.plate()` ; le thème commun l'applique à tous les `PanelContainer`, `Panel`, `Button` et `OptionButton`.

## Reste à faire

- Icônes des sorts (aujourd'hui, leur nom écrit dans la case).
- Petit portrait du héros en haut à gauche, mini-carte.
