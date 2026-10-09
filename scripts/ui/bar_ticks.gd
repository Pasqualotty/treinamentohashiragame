class_name BarTicks
extends Control
## Marcas de segmento desenhadas por cima de uma barra (ex.: respiração em 4 partes).

@export var segments: int = 4
@export var tick_color: Color = Color(0.02, 0.02, 0.03, 0.55)
## Recuo lateral = margem interna do StyleBox da barra.
@export var inset: float = 3.0


func _draw() -> void:
	if segments < 2:
		return
	var usable: float = size.x - inset * 2.0
	for i: int in range(1, segments):
		var x: float = inset + usable * float(i) / float(segments)
		draw_line(Vector2(x, inset), Vector2(x, size.y - inset), tick_color, 2.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
