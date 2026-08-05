class_name HitData
extends RefCounted
## Payload de um acerto de combate (hitbox → hurtbox).

var damage: int = 1
var knockback: Vector2 = Vector2.ZERO
var source: Node = null
## Identificador opcional do swing (debug / multi-hit futuro).
var swing_id: int = 0
