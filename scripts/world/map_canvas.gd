extends Control
## Canvas do caminho — WorldMap injeta `paint_cb` e desenha path/nós.

var paint_cb: Callable = Callable()


func _draw() -> void:
	if paint_cb.is_valid():
		paint_cb.call(self)
