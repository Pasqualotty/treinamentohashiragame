extends SceneTree
## Captura 1280×720 da arena com dois caçadores visíveis.
## NÃO usar --headless (viewport dummy = PNG nulo).
## HASHIRA_CAPTURE_DIR = pasta de saída.

const ARENA := "res://scenes/modes/brawl/brawl_arena.tscn"


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
	var packed: PackedScene = load(ARENA) as PackedScene
	if packed == null:
		print("CAPTURE FAIL brawl_arena.tscn")
		quit(1)
		return
	var inst: Node = packed.instantiate()
	root.add_child(inst)
	await create_timer(0.7).timeout
	var hunters: Array = inst.call("get_hunters") if inst.has_method("get_hunters") else []
	print("hunters=", hunters.size())
	if not await _save(out_dir.path_join("brawl-arena-1280.png")):
		quit(1)
		return
	print("CAPTURE_BRAWL DONE")
	quit(0)


func _save(path: String) -> bool:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	if img == null:
		print("CAPTURE FAIL image null ", path)
		return false
	if img.get_width() < 1200:
		print("CAPTURE FAIL size ", img.get_width(), "x", img.get_height())
		return false
	var err: Error = img.save_png(path)
	print("saved ", path, " ", img.get_width(), "x", img.get_height(), " err=", err)
	return err == OK
