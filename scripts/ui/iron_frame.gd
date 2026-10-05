class_name IronFrame
extends StyleBox
## Cadre de fer des menus et des boutons : une texture rendue dans Blender (assets/ui, art/hud/build_hud.py),
## découpée en 9 parties (les coins gardent leur taille, les bords et le centre s'étirent). `dim` : voile sombre sur
## tout l'écran derrière le panneau (fenêtres modales).

var texture: Texture2D
## Taille des coins et des bords dans la texture (px).
var margin := 48.0
var modulate := Color.WHITE
var dim := false
var dim_color := Color(0, 0, 0, 0.7)


static func make(tex: Texture2D, texture_margin: float, content: float, tint: Color = Color.WHITE) -> IronFrame:
	var f := IronFrame.new()
	f.texture = tex
	f.margin = texture_margin
	f.modulate = tint
	f.set_content_margin_all(content)
	return f


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	if dim:
		RenderingServer.canvas_item_add_rect(to_canvas_item, rect.grow(4000.0), dim_color)
	if texture == null:
		return
	var src := Rect2(Vector2.ZERO, texture.get_size())
	var corner := Vector2(margin, margin)
	RenderingServer.canvas_item_add_nine_patch(to_canvas_item, rect, src, texture.get_rid(), corner, corner, RenderingServer.NINE_PATCH_STRETCH, RenderingServer.NINE_PATCH_STRETCH, true, modulate)
