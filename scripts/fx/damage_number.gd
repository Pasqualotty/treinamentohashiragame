extends Node2D
## Número de dano que sobe e desvanece. Dourado/maior em crit/ultimate.
## Instanciada por `Fx.damage_number()`; auto-remove ao final.

@onready var label: Label = %Label

const RISE_Y: float = 46.0
const DURATION: float = 0.55
const COLOR_NORMAL: Color = Color(1.0, 0.94, 0.9, 1.0)
const COLOR_CRIT: Color = Color(0.910, 0.722, 0.290, 1.0)  # ouro #E8B84A


func play(value: int, crit: bool = false) -> void:
	if label == null:
		queue_free()
		return
	label.text = str(maxi(0, value))
	if crit:
		label.modulate = COLOR_CRIT
		label.scale = Vector2(1.3, 1.3)
	else:
		label.modulate = COLOR_NORMAL
		label.scale = Vector2(1.0, 1.0)

	position.x += randf_range(-8.0, 8.0)
	modulate = Color(1.0, 1.0, 1.0, 1.0)

	var start_y: float = position.y
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "position:y", start_y - RISE_Y, DURATION) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(self, "modulate:a", 0.0, DURATION * 0.6).set_delay(DURATION * 0.4)
	tw.chain().tween_callback(queue_free)
