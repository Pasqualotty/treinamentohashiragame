class_name KnockCarry
extends RefCounted
## Janela de knockback no chão: a AI de rua não pisa `velocity.x` enquanto o
## recoil ainda está vivo. Puro — smoke afirma sem cena.

static func holds(recoil_t: float) -> bool:
	return recoil_t > 0.0


static func apply_friction(velocity_x: float, friction: float, delta: float) -> float:
	return move_toward(velocity_x, 0.0, maxf(0.0, friction) * maxf(0.0, delta))
