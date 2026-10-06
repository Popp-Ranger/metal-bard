class_name ItemIcon
extends RefCounted
## Icônes carrées des objets (inventaire façon MMO) : dessinées en vectoriel selon le type d'objet (emplacement
## d'équipement, objets de quête, potion), dans un repère de 64 × 64 ramené à la case. La couleur principale vient du
## matériau du type d'objet, les détails (gemmes, clous...) de la couleur de sa rareté ; une petite variation de teinte
## propre à chaque objet distingue deux objets du même emplacement.

## Couleurs des matériaux par type d'icône.
const MATERIALS := {
	"guitare": Color(0.55, 0.12, 0.1), "tete": Color(0.62, 0.63, 0.68), "cou": Color(0.9, 0.72, 0.3),
	"torse": Color(0.42, 0.26, 0.14), "poignets": Color(0.3, 0.28, 0.3), "ceinture": Color(0.4, 0.25, 0.13),
	"pieds": Color(0.25, 0.18, 0.12), "anneau": Color(0.92, 0.75, 0.3), "talisman": Color(0.88, 0.84, 0.72),
	"mediator": Color(0.75, 0.55, 0.3), "cordes": Color(0.8, 0.82, 0.86), "grimoire": Color(0.42, 0.1, 0.12),
	"cle": Color(0.6, 0.45, 0.3), "parchemin": Color(0.88, 0.8, 0.6), "pick": Color(0.2, 0.15, 0.2),
	"portrait": Color(0.7, 0.5, 0.25), "potion": Color(0.85, 0.12, 0.12), "objet": Color(0.6, 0.6, 0.6),
}
## Couleurs propres à certains objets (les guitares d'Ulysse : Batguitare violette et noire, Xplode de bois calciné).
const ITEM_COLORS := {"batguitare": Color(0.32, 0.12, 0.42), "xplode": Color(0.36, 0.26, 0.18)}


## Type d'icône d'un objet : son emplacement d'équipement, ou un type d'objet de quête.
static func kind_of(id: String) -> String:
	if id == "potion":
		return "potion"
	if ItemDB.relics().has(id):
		return ItemDB.slot_of(id)
	if id.begins_with("cle"):
		return "cle"
	if id.begins_with("pick"):
		return "pick"
	if id.begins_with("partition") or id.begins_with("parchemin"):
		return "parchemin"
	if id.begins_with("portrait"):
		return "portrait"
	return "objet"


## Dessine l'icône de l'objet `id` (ou d'un emplacement vide, `kind`, en silhouette grise) dans `rect`.
static func draw(ci: CanvasItem, rect: Rect2, kind: String, id: String = "", ghost: bool = false) -> void:
	var base: Color = ITEM_COLORS.get(id, MATERIALS.get(kind, MATERIALS["objet"]))
	var accent := ItemDB.color_of(id) if ItemDB.relics().has(id) else Color(1.0, 0.85, 0.4)
	if not id.is_empty() and not ITEM_COLORS.has(id):
		# Petite variation de teinte propre à l'objet.
		base = Color.from_hsv(fposmod(base.h + (hash(id) % 100) / 1200.0, 1.0), base.s, base.v)
	if ghost:
		base = Color(0.5, 0.5, 0.5, 0.18)
		accent = Color(0.6, 0.6, 0.6, 0.2)
	var dark := base.darkened(0.45)
	var light := base.lightened(0.3)
	var s := rect.size.x / 64.0
	var o := rect.position
	var p := func(x: float, y: float) -> Vector2: return o + Vector2(x, y) * s
	var poly := func(pts: Array, c: Color) -> void:
		var arr := PackedVector2Array()
		for q: Vector2 in pts:
			arr.append(p.call(q.x, q.y))
		ci.draw_colored_polygon(arr, c)
	var outline := func(pts: Array, c: Color, w: float) -> void:
		var arr := PackedVector2Array()
		for q: Vector2 in pts:
			arr.append(p.call(q.x, q.y))
		arr.append(arr[0])
		ci.draw_polyline(arr, c, w * s, true)
	match kind:
		"guitare":
			var body := [Vector2(14, 58), Vector2(29, 32), Vector2(35, 32), Vector2(50, 58), Vector2(41, 58), Vector2(32, 44), Vector2(23, 58)]
			poly.call(body, base)
			outline.call(body, dark, 1.5)
			poly.call([Vector2(30, 10), Vector2(34, 10), Vector2(34, 40), Vector2(30, 40)], Color(0.3, 0.2, 0.12) if not ghost else base)
			poly.call([Vector2(27, 3), Vector2(37, 3), Vector2(35, 11), Vector2(29, 11)], dark)
			for k in 3:
				ci.draw_line(p.call(31 + k, 10), p.call(31 + k, 46), accent if id == "xplode" else light, maxf(1.0, 0.6 * s))
		"tete":
			var dome := [Vector2(14, 40)]
			for k in 13:
				var a := PI + PI * k / 12.0
				dome.append(Vector2(32 + cos(a) * 18, 40 + sin(a) * 20))
			dome.append(Vector2(50, 40))
			poly.call(dome, base)
			poly.call([Vector2(10, 40), Vector2(54, 40), Vector2(52, 47), Vector2(12, 47)], dark)
			poly.call([Vector2(16, 28), Vector2(4, 8), Vector2(12, 30)], light)
			poly.call([Vector2(48, 28), Vector2(60, 8), Vector2(52, 30)], light)
			ci.draw_circle(p.call(32, 30), 3.5 * s, accent)
		"cou":
			var chain := PackedVector2Array()
			for k in 13:
				var a := PI * k / 12.0
				chain.append(p.call(32 - cos(a) * 18, 10 + sin(a) * 22))
			ci.draw_polyline(chain, base, 2.0 * s, true)
			ci.draw_circle(p.call(32, 42), 10 * s, base)
			ci.draw_circle(p.call(32, 42), 6 * s, accent)
			ci.draw_circle(p.call(30, 40), 2 * s, Color(1, 1, 1, 0.6 if not ghost else 0.1))
		"torse":
			var vest := [Vector2(18, 10), Vector2(26, 8), Vector2(32, 18), Vector2(38, 8), Vector2(46, 10), Vector2(56, 22),
				Vector2(49, 29), Vector2(46, 58), Vector2(18, 58), Vector2(15, 29), Vector2(8, 22)]
			poly.call(vest, base)
			outline.call(vest, dark, 1.5)
			ci.draw_line(p.call(32, 18), p.call(32, 58), dark, 1.5 * s)
			for k in 3:
				ci.draw_circle(p.call(36, 26 + k * 10), 2 * s, accent)
		"poignets":
			poly.call([Vector2(12, 26), Vector2(52, 26), Vector2(52, 44), Vector2(12, 44)], base)
			outline.call([Vector2(12, 26), Vector2(52, 26), Vector2(52, 44), Vector2(12, 44)], dark, 1.5)
			for k in 4:
				var x := 17.0 + k * 10.0
				poly.call([Vector2(x - 4, 26), Vector2(x + 4, 26), Vector2(x, 14)], light)
				ci.draw_circle(p.call(x, 35), 2 * s, accent)
		"ceinture":
			poly.call([Vector2(4, 26), Vector2(60, 26), Vector2(60, 38), Vector2(4, 38)], base)
			for k in 5:
				ci.draw_circle(p.call(9 + k * 4.5, 32), 1.3 * s, light)
			poly.call([Vector2(26, 20), Vector2(40, 20), Vector2(40, 44), Vector2(26, 44)], accent)
			poly.call([Vector2(29, 24), Vector2(37, 24), Vector2(37, 40), Vector2(29, 40)], dark)
		"pieds":
			var boot := [Vector2(22, 6), Vector2(38, 6), Vector2(38, 38), Vector2(54, 44), Vector2(57, 56), Vector2(18, 56), Vector2(20, 38)]
			poly.call(boot, base)
			outline.call(boot, dark, 1.5)
			poly.call([Vector2(18, 52), Vector2(57, 52), Vector2(57, 58), Vector2(18, 58)], dark)
			for k in 3:
				ci.draw_line(p.call(23, 14 + k * 8), p.call(37, 14 + k * 8), accent, 1.5 * s)
		"anneau":
			ci.draw_arc(p.call(32, 40), 14 * s, 0, TAU, 32, base, 5 * s, true)
			poly.call([Vector2(32, 14), Vector2(40, 22), Vector2(32, 30), Vector2(24, 22)], accent)
			ci.draw_circle(p.call(30, 20), 1.6 * s, Color(1, 1, 1, 0.6 if not ghost else 0.1))
		"talisman":
			ci.draw_circle(p.call(32, 32), 22 * s, dark)
			ci.draw_arc(p.call(32, 32), 22 * s, 0, TAU, 40, base, 2.5 * s, true)
			var star := PackedVector2Array()
			for k in 6:
				var a := -PI / 2.0 + TAU * (k * 2 % 5) / 5.0
				star.append(p.call(32 + cos(a) * 17, 33 + sin(a) * 17))
			ci.draw_polyline(star, accent, 2 * s, true)
		"mediator", "pick":
			var pick := PackedVector2Array()
			for k in 24:
				var a := TAU * k / 24.0
				var r := 20.0 + 5.0 * cos(3.0 * a)
				pick.append(p.call(32 + cos(a - PI / 2.0) * r * 0.95, 30 - sin(a - PI / 2.0) * r))
			ci.draw_colored_polygon(pick, base)
			ci.draw_polyline(pick + PackedVector2Array([pick[0]]), accent if kind == "pick" else dark, 2 * s, true)
			ci.draw_circle(p.call(32, 26), 4 * s, accent)
		"cordes":
			for k in 3:
				ci.draw_arc(p.call(32, 32), (8 + k * 7) * s, 0, TAU, 32, base.darkened(k * 0.15), 2 * s, true)
			ci.draw_line(p.call(32, 32), p.call(58, 10), base, 1.5 * s)
			ci.draw_circle(p.call(32, 32), 4 * s, accent)
		"grimoire":
			poly.call([Vector2(14, 8), Vector2(52, 8), Vector2(52, 58), Vector2(14, 58)], base)
			poly.call([Vector2(14, 8), Vector2(20, 8), Vector2(20, 58), Vector2(14, 58)], dark)
			poly.call([Vector2(52, 12), Vector2(56, 12), Vector2(56, 56), Vector2(52, 56)], Color(0.9, 0.85, 0.7, 0.9 if not ghost else 0.1))
			var star := PackedVector2Array()
			for k in 6:
				var a := -PI / 2.0 + TAU * (k * 2 % 5) / 5.0
				star.append(p.call(36 + cos(a) * 10, 33 + sin(a) * 10))
			ci.draw_polyline(star, accent, 1.5 * s, true)
		"cle":
			ci.draw_arc(p.call(20, 20), 9 * s, 0, TAU, 24, base, 4 * s, true)
			ci.draw_line(p.call(26, 26), p.call(52, 52), base, 5 * s)
			poly.call([Vector2(42, 46), Vector2(48, 40), Vector2(52, 44), Vector2(46, 50)], base)
			poly.call([Vector2(48, 52), Vector2(54, 46), Vector2(58, 50), Vector2(52, 56)], base)
		"parchemin":
			poly.call([Vector2(14, 12), Vector2(50, 12), Vector2(50, 54), Vector2(14, 54)], base)
			ci.draw_circle(p.call(14, 12), 5 * s, base.darkened(0.2))
			ci.draw_circle(p.call(50, 54), 5 * s, base.darkened(0.2))
			for k in 4:
				ci.draw_line(p.call(20, 22 + k * 8), p.call(44, 22 + k * 8), Color(0.25, 0.15, 0.1, 0.8), 1.5 * s)
			ci.draw_circle(p.call(40, 44), 4 * s, Color(0.7, 0.05, 0.05))
		"portrait":
			poly.call([Vector2(12, 8), Vector2(52, 8), Vector2(52, 58), Vector2(12, 58)], base)
			poly.call([Vector2(17, 13), Vector2(47, 13), Vector2(47, 53), Vector2(17, 53)], Color(0.22, 0.2, 0.25))
			ci.draw_circle(p.call(32, 30), 9 * s, Color(0.85, 0.7, 0.6))
			ci.draw_line(p.call(26, 35), p.call(38, 35), Color(0.2, 0.12, 0.08), 2 * s) # la moustache
			poly.call([Vector2(20, 53), Vector2(44, 53), Vector2(38, 42), Vector2(26, 42)], Color(0.3, 0.15, 0.3))
		"potion":
			poly.call([Vector2(27, 8), Vector2(37, 8), Vector2(37, 22), Vector2(27, 22)], Color(0.75, 0.8, 0.85, 0.8))
			ci.draw_circle(p.call(32, 40), 17 * s, Color(0.75, 0.8, 0.85, 0.5))
			ci.draw_circle(p.call(32, 42), 14 * s, base)
			ci.draw_circle(p.call(26, 36), 3 * s, Color(1, 1, 1, 0.5))
			poly.call([Vector2(26, 4), Vector2(38, 4), Vector2(38, 9), Vector2(26, 9)], Color(0.45, 0.3, 0.15))
		_:
			ci.draw_circle(p.call(32, 32), 18 * s, base)
			ci.draw_circle(p.call(32, 32), 8 * s, accent)
