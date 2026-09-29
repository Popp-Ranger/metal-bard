class_name DialogueProp
extends Node3D
## Objet du décor avec lequel on peut interagir (tableau des quêtes, etc.).

var dialogue_id := ""
var prompt := "Examiner"
var interact_radius := 2.0


func _ready() -> void:
	add_to_group("interactable")


func get_prompt() -> String:
	return prompt


func interact(_by: Node3D) -> void:
	Events.dialogue_requested.emit(dialogue_id)
