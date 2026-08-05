extends Area2D
## Portal / goal no fim da fase. Emite `reached` quando o player entra.

signal reached(body: Node2D)

@export var one_shot: bool = true

var _fired: bool = false


func _ready() -> void:
	monitoring = true
	monitorable = false
	# Player sandbox = layer 2; player move = layer 1 — aceita ambos.
	if collision_mask == 0:
		collision_mask = 1 | 2
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _fired and one_shot:
		return
	if body == null or not body.is_in_group("player"):
		return
	_fired = true
	reached.emit(body)
