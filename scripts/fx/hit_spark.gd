extends Node2D
## Hit spark: burst de partículas one-shot na cor do tipo de golpe.
## Instanciada por `Fx.spark()`; auto-remove ao final do burst.

@onready var particles: CPUParticles2D = %Particles


func _ready() -> void:
	if particles == null:
		return
	if is_instance_valid(Fx):
		particles.texture = Fx.get_dot_texture()
		particles.color_ramp = Fx.get_fade_gradient()


func play(color: Color = Color.WHITE, amount: int = 10) -> void:
	if particles == null:
		queue_free()
		return
	particles.amount = clampi(amount, 4, 24)
	particles.color = color
	particles.emitting = true
	var tree: SceneTree = get_tree()
	if tree:
		await tree.create_timer(particles.lifetime + 0.2).timeout
	queue_free()
