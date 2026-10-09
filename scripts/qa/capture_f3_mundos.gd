extends SceneTree
## Captura PNGs dos mundos (fundo, chão, atmosfera) para conferência visual da F3.
## Precisa de janela real — NÃO rodar com --headless.
##   godot --path . --resolution 1280x720 -s res://scripts/qa/capture_f3_mundos.gd
##
## Saída em `HASHIRA_CAPTURE_DIR` (ou user://f3shots). Cada shot espera alguns
## segundos para a atmosfera encher e os tweens rodarem.

const SHOTS: Array = [
	# [cena, apelido, segundos de espera, x do player (-1 = não mexe)]
	["stage_w1_01", "w1_01", 3.0, -1.0],
	["stage_w1_boss", "w1_boss", 3.0, -1.0],
	["stage_w2_01", "w2_01", 3.0, -1.0],
	["stage_w3_01", "w3_01", 3.0, -1.0],
	["stage_w4_01", "w4_01", 3.0, -1.0],
	["stage_w5_01", "w5_01", 3.0, -1.0],
	["stage_w5_boss", "w5_boss", 3.0, -1.0],
	["stage_w1_01", "w1_01_scroll_x900", 3.0, 900.0],
	["stage_w2_01", "w2_01_scroll_x900", 3.0, 900.0],
]


func _initialize() -> void:
	call_deferred("_run")


func _out_dir() -> String:
	var env: String = OS.get_environment("HASHIRA_CAPTURE_DIR")
	return env if not env.is_empty() else "user://f3shots"


func _run() -> void:
	var dir: String = _out_dir()
	DirAccess.make_dir_recursive_absolute(dir)
	for shot in SHOTS:
		await _capture(str(shot[0]), str(shot[1]), float(shot[2]), float(shot[3]), dir)
	print("CAPTURE DONE -> ", ProjectSettings.globalize_path(dir))
	quit(0)


func _capture(scene: String, label: String, wait_s: float, player_x: float, dir: String) -> void:
	var packed: PackedScene = load("res://scenes/battle/%s.tscn" % scene) as PackedScene
	if packed == null:
		push_error("capture: load falhou %s" % scene)
		return
	var inst: Node = packed.instantiate()
	root.add_child(inst)
	await process_frame
	if player_x >= 0.0:
		var player: Node2D = inst.get_node_or_null("Player") as Node2D
		if player != null:
			player.global_position.x = player_x
	await create_timer(wait_s).timeout
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	if img == null:
		push_error("capture: viewport sem imagem (rodou com --headless?)")
	else:
		var path: String = "%s/%s.png" % [dir, label]
		img.save_png(path)
		print("shot ", label, " ", img.get_size(), " -> ", path)
	inst.queue_free()
	await process_frame
