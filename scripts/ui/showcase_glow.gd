extends Control
## Glow ceremonial sob o personagem no hub — anéis elípticos pulsantes.
## Puramente procedural (sem asset novo): desenhado via _draw(), pulsa devagar
## como uma plataforma de luz sob os pés do Tanjiro.

@export var glow_color: Color = Color(0.909804, 0.721569, 0.290196, 1.0)
@export var ring_count: int = 5
@export var pulse_speed: float = 1.1

var _t: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if size.x <= 1.0 or size.y <= 1.0:
		return
	var center: Vector2 = size * 0.5
	var pulse: float = sin(_t * pulse_speed) * 0.5 + 0.5
	var rx: float = (size.x * 0.5) * (0.92 + pulse * 0.08)
	var ry: float = (size.y * 0.5) * (0.92 + pulse * 0.08)
	var segs := 40
	for i in range(ring_count, 0, -1):
		var frac: float = float(i) / float(ring_count)
		var a: float = (0.14 * (1.0 - frac)) * (0.7 + pulse * 0.3)
		var pts := PackedVector2Array()
		for s in range(segs + 1):
			var ang: float = TAU * float(s) / float(segs)
			pts.append(center + Vector2(cos(ang) * rx * frac, sin(ang) * ry * frac))
		draw_colored_polygon(pts, Color(glow_color.r, glow_color.g, glow_color.b, a))
