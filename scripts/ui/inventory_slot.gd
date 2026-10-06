class_name InventorySlot
extends Control
## Une case de l'inventaire (façon MMO) : cadre de fer (assets/ui/case.png), l'icône carrée de l'objet (ItemIcon) avec un
## liseré de la couleur de sa rareté, ou la silhouette grise de l'emplacement d'équipement vide. Survol : surbrillance
## (la fenêtre affiche la bulle d'info sous le curseur) ; clic gauche ou droit : `activated`.

signal activated(slot: InventorySlot)
signal hovered(slot: InventorySlot, inside: bool)

const SIZE := 54.0
const FRAME := preload("res://assets/ui/case.png")

## Objet dans la case ("" : vide), emplacement d'équipement qu'elle représente ("" : case du sac), nombre (potions).
var item_id := ""
var equip_slot := ""
var count := 0
var _hover := false


static func make(id: String, slot: String = "", amount: int = 0) -> InventorySlot:
	var s := InventorySlot.new()
	s.item_id = id
	s.equip_slot = slot
	s.count = amount
	return s


func _ready() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))


func _on_hover(inside: bool) -> void:
	_hover = inside
	queue_redraw()
	hovered.emit(self, inside)


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT] and not item_id.is_empty():
		accept_event()
		activated.emit(self)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r.grow(-3), Color(0.05, 0.04, 0.04, 0.95))
	var inner := r.grow(-8)
	if not item_id.is_empty():
		var rarity := ItemDB.color_of(item_id) if ItemDB.relics().has(item_id) else Color(1.0, 0.8, 0.35)
		draw_rect(r.grow(-4), Color(rarity.r, rarity.g, rarity.b, 0.16)) # fond teinté par la rareté
		ItemIcon.draw(self, inner, ItemIcon.kind_of(item_id), item_id)
		draw_rect(r.grow(-4), Color(rarity.r, rarity.g, rarity.b, 0.85), false, 2.0)
		if count > 1:
			draw_string(UiStyle.serif(), Vector2(size.x - 24, size.y - 7), str(count), HORIZONTAL_ALIGNMENT_RIGHT, 18, 15, UiStyle.BONE)
	elif not equip_slot.is_empty():
		ItemIcon.draw(self, inner, equip_slot, "", true) # emplacement vide : silhouette grise
	draw_texture_rect(FRAME, r, false)
	if _hover:
		draw_rect(r.grow(-4), Color(1.0, 0.9, 0.6, 0.18))
