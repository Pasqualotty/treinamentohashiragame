extends Node2D
## Placeholder de inimigo (ColorRect) até o oni real mergear.
## Interface: group `enemy` — StageController / sistemas de combate podem enumerar.

@export var label_text: String = "ONI?"


func _ready() -> void:
	add_to_group("enemy")
	var label := get_node_or_null("Label") as Label
	if label:
		label.text = label_text
