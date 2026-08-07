extends Node2D
## Desintegração de morte do oni: partículas de cinza/fumaça subindo.
## Instanciada por `Fx.death_poof()`; auto-remove ao final.

@onready var particles: CPUParticles2D = %Particles


func _ready() -> void:
	if particles == null:
		return
	if is_instance_valid(Fx):
		particles.texture = Fx.get_dot_texture()
		particles.color_ramp = Fx.get_fade_gradient()


func play(color: Color = Color(0.55, 0.55, 0.6, 1.0)) -> void:
	if particles == null:
		queue_free()
		return
	particles.color = color
	particles.emitting = true
	var tree: SceneTree = get_tree()
	if tree:
		await tree.create_timer(particles.lifetime + 0.25).timeout
	queue_free()
