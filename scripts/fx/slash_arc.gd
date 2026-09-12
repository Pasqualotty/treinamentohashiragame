extends Node2D
## Arco de corte: Line2D curvo com blend aditivo. Cor por tipo de golpe
## (Style Bible): basic = branco quente; skill/ultimate = água #5B8DEF
## (ultimate mais claro/intenso e com escala maior).
## Instanciada por `Fx.slash()`; auto-remove ao final da animação.

@onready var line: Line2D = %Line

const COLOR_BASIC: Color = Color(1.0, 0.92, 0.85, 0.95)
const COLOR_SKILL: Color = Color(0.357, 0.553, 0.937, 0.95)
const COLOR_ULTIMATE: Color = Color(0.55, 0.78, 1.0, 1.0)
const DURATION: float = 0.22
const ARC_SPAN: float = 0.95


func play(facing: float, kind: StringName = &"basic", tint: Color = Color(0, 0, 0, 0)) -> void:
	if line == null:
		queue_free()
		return
	var f: float = signf(facing) if not is_zero_approx(facing) else 1.0
	var color: Color = COLOR_BASIC
	var radius: float = 42.0
	var width: float = 8.0
	match kind:
		&"skill":
			color = COLOR_SKILL
			radius = 52.0
			width = 10.0
		&"ultimate":
			color = COLOR_ULTIMATE
			radius = 68.0
			width = 12.0
		_:
			color = COLOR_BASIC
			radius = 42.0
			width = 8.0
	if tint.a > 0.01:
		color = Color(tint.r, tint.g, tint.b, maxf(tint.a, 0.9))

	line.antialiased = false
	line.default_color = color
	line.width = width
	line.points = _arc_points(f, radius)
	modulate = Color(1.0, 1.0, 1.0, 1.0)

	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "modulate:a", 0.0, DURATION).set_ease(Tween.EASE_OUT)
	tw.tween_property(line, "width", 2.0, DURATION).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(queue_free)


func _arc_points(f: float, radius: float) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	var steps: int = 10
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var ang: float = lerp(-ARC_SPAN, ARC_SPAN, t)
		var p: Vector2 = Vector2(cos(ang), sin(ang)) * radius
		p.x *= f
		pts.append(p)
	return pts
