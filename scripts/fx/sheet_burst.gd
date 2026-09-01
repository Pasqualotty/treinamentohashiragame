extends Node2D
## Burst de sprite-sheet (slash / water / impact) com blend aditivo.
## Igual ao protótipo web: frames em sequência, some no fim.

@onready var sprite: AnimatedSprite2D = %Sprite

var _vx: float = 0.0


func play_sheet(paths: PackedStringArray, life: float, draw_size: float, facing: float, vx: float = 0.0) -> void:
	if sprite == null or paths.is_empty():
		queue_free()
		return
	_vx = vx
	var frames := SpriteFrames.new()
	frames.add_animation(&"play")
	frames.set_animation_loop(&"play", false)
	var n: int = 0
	for p: String in paths:
		if not ResourceLoader.exists(p):
			continue
		var tex: Texture2D = load(p) as Texture2D
		if tex == null:
			continue
		frames.add_frame(&"play", tex)
		n += 1
	if n <= 0:
		queue_free()
		return
	var dur: float = maxf(life, 0.08)
	frames.set_animation_speed(&"play", float(n) / dur)
	sprite.sprite_frames = frames
	sprite.flip_h = facing < 0.0
	var tex0: Texture2D = frames.get_frame_texture(&"play", 0)
	var base_w: float = float(tex0.get_width()) if tex0 else 128.0
	if base_w > 1.0:
		sprite.scale = Vector2.ONE * (draw_size / base_w)
	sprite.play(&"play")
	if not sprite.animation_finished.is_connected(_on_done):
		sprite.animation_finished.connect(_on_done)
	var tree: SceneTree = get_tree()
	if tree:
		await tree.create_timer(dur + 0.05).timeout
	_on_done()


func _process(delta: float) -> void:
	if not is_zero_approx(_vx):
		global_position.x += _vx * delta


func _on_done() -> void:
	if is_instance_valid(self):
		queue_free()
