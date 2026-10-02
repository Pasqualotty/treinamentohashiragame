class_name HitboxArc
extends RefCounted
## Arco sintético quando sizes/offsets vêm vazios e há mais de 1 frame.
## Cedo: menor e perto do corpo. Meio: fallback cheio. Tarde: um pouco mais longo.

const EARLY_SIZE := 0.70
const EARLY_OFFSET := 0.56
const LATE_SIZE_X := 1.20
const LATE_SIZE_Y := 1.08
const LATE_OFFSET := 1.25


static func size_at(fallback: Vector2, index: int, frame_count: int) -> Vector2:
	var n: int = maxi(frame_count, 1)
	if n <= 1:
		return fallback
	var t: float = _t(index, n)
	var early: Vector2 = fallback * EARLY_SIZE
	var late := Vector2(fallback.x * LATE_SIZE_X, fallback.y * LATE_SIZE_Y)
	return _along(early, fallback, late, t)


static func offset_at(fallback: float, index: int, frame_count: int) -> float:
	var n: int = maxi(frame_count, 1)
	if n <= 1:
		return fallback
	var t: float = _t(index, n)
	return _along_f(fallback * EARLY_OFFSET, fallback, fallback * LATE_OFFSET, t)


static func _t(index: int, n: int) -> float:
	return clampf(float(clampi(index, 0, n - 1)) / float(n - 1), 0.0, 1.0)


static func _along(early: Vector2, mid: Vector2, late: Vector2, t: float) -> Vector2:
	if t <= 0.5:
		return early.lerp(mid, t * 2.0)
	return mid.lerp(late, (t - 0.5) * 2.0)


static func _along_f(early: float, mid: float, late: float, t: float) -> float:
	if t <= 0.5:
		return lerpf(early, mid, t * 2.0)
	return lerpf(mid, late, (t - 0.5) * 2.0)
