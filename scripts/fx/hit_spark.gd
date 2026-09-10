extends Node2D
## Hit spark: burst de partículas one-shot na cor do tipo de golpe.
## Instanciada por `Fx.spark()`; auto-remove ao final do burst.

@onready var particles: CPUParticles2D = %Particles


func _ready() -> void:
	if particles == null:
		return
	if is_instance_valid(Fx):
		if Fx.has_method("get_shard_texture"):
			particles.texture = Fx.get_shard_texture()
		else:
			particles.texture = Fx.get_dot_texture()
		particles.color_ramp = Fx.get_fade_gradient()


func play(color: Color = Color.WHITE, amount: int = 10) -> void:
	if particles == null:
		queue_free()
		return
	particles.amount = clampi(amount, 4, 16)
	particles.color = color
	particles.lifetime = 0.22
	particles.scale_amount_min = 1.4
	particles.scale_amount_max = 2.6
	particles.emitting = true
	var tree: SceneTree = get_tree()
	if tree:
		await tree.create_timer(particles.lifetime + 0.2).timeout
	queue_free()
