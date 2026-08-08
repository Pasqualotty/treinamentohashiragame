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
const ARC_SPAN: float = 1.15


func play(facing: float, kind: StringName = &"basic") -> void:
	if line == null:
		queue_free()
		return
	var f: float = signf(facing) if not is_zero_approx(facing) else 1.0
	var color: Color = COLOR_BASIC
	var radius: float = 46.0
	var width: float = 5.0
	match kind:
		&"skill":
			color = COLOR_SKILL
			radius = 58.0
			width = 6.5
		&"ultimate":
			color = COLOR_ULTIMATE
			radius = 78.0
			width = 9.0
		_:
			color = COLOR_BASIC
			radius = 46.0
			width = 5.0

	line.default_color = color
	line.width = width
	line.points = _arc_points(f, radius)
	modulate = Color(1.0, 1.0, 1.0, 1.0)

	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "modulate:a", 0.0, DURATION).set_ease(Tween.EASE_OUT)
	tw.tween_property(line, "width", 0.5, DURATION).set_ease(Tween.EASE_IN)
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
