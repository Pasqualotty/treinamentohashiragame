extends SceneTree
## Print 1280×720 do duelo: dois corpos no ring + texto de round.
## Precisa de janela real — NÃO usar --headless (viewport dummy = PNG nulo).
## HASHIRA_CAPTURE_DIR = pasta de saída.

const DUEL := "res://scenes/modes/duel/duel.tscn"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	root.size = Vector2i(1280, 720)
	var out_dir: String = OS.get_environment("HASHIRA_CAPTURE_DIR")
	if out_dir.is_empty():
		print("CAPTURE FAIL HASHIRA_CAPTURE_DIR vazio")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(out_dir)
	var packed: PackedScene = load(DUEL) as PackedScene
	if packed == null:
		print("CAPTURE FAIL duel.tscn")
		quit(1)
		return
	var inst: Node = packed.instantiate()
	root.add_child(inst)
	await create_timer(0.7).timeout
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	if img == null:
		print("CAPTURE FAIL image null")
		quit(1)
		return
	var path := out_dir.path_join("duel-1280.png")
	var err: Error = img.save_png(path)
	print("saved ", path, " ", img.get_width(), "x", img.get_height(), " err=", err)
	if err != OK or img.get_width() < 1280 or img.get_height() < 720:
		print("CAPTURE FAIL size/err")
		quit(1)
		return
	print("CAPTURE_DUEL DONE")
	quit(0)
