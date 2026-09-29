class_name Interactable
extends Node3D
## Objet générique avec lequel on interagit avec [E] ou un clic : escalier, clé, cage,
## coffre, lit... L'action est un Callable.

var prompt := "Interagir"
var interact_radius := 2.0
var on_interact: Callable


static func create(parent: Node, pos: Vector3, text: String, action: Callable, radius: float = 2.0) -> Interactable:
	var i := Interactable.new()
	i.position = pos
	i.prompt = text
	i.on_interact = action
	i.interact_radius = radius
	parent.add_child(i)
	return i


func _ready() -> void:
	add_to_group("interactable")


func get_prompt() -> String:
	return prompt


func interact(_by: Node3D) -> void:
	if on_interact.is_valid():
		on_interact.call()
