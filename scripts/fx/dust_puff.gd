extends Node2D
## Poeira de pés (land/dash): burst curto e terroso. Auto-remove.
## Instanciada por `Fx.dust()`.

@onready var particles: CPUParticles2D = %Particles


func _ready() -> void:
	if particles == null:
		return
	if is_instance_valid(Fx):
		particles.texture = Fx.get_dot_texture()
		particles.color_ramp = Fx.get_fade_gradient()


func play() -> void:
	if particles == null:
		queue_free()
		return
	particles.emitting = true
	var tree: SceneTree = get_tree()
	if tree:
		await tree.create_timer(particles.lifetime + 0.2).timeout
	queue_free()
