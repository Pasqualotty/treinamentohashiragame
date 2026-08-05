class_name Hurtbox
extends Area2D
## Área que recebe hits. Emite `hurt` com HitData; o dono aplica HP/feedback.

signal hurt(hit_data: HitData)

@export var team: StringName = &"enemy"
@export var invulnerable: bool = false


func _ready() -> void:
	monitoring = false
	monitorable = true
	# Camada 5 = hurtbox; não precisa mascarar nada.
	collision_layer = 1 << 4
	collision_mask = 0


func receive_hit(hit_data: HitData) -> void:
	if invulnerable:
		return
	if hit_data == null:
		return
	hurt.emit(hit_data)
