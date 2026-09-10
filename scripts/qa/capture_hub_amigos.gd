extends SceneTree
## Captura o hub 1280×720: fechado e com a gaveta aberta.
## Precisa de janela real — NÃO usar --headless (viewport dummy = PNG nulo).
## HASHIRA_CAPTURE_DIR = pasta de saída.

const HUB := "res://scenes/main_menu/hub.tscn"
const _UiFont := preload("res://scripts/ui/ui_font.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_UiFont.ensure_theme_space()
	DisplayServer.window_set_size(Vector2i(1280, 720))
	root.size = Vector2i(1280, 720)
	var out_dir: String = OS.get_environment("HASHIRA_CAPTURE_DIR")
	if out_dir.is_empty():
		print("CAPTURE FAIL HASHIRA_CAPTURE_DIR vazio")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(out_dir)
	var packed: PackedScene = load(HUB) as PackedScene
	if packed == null:
		print("CAPTURE FAIL hub.tscn")
		quit(1)
		return
	var inst: Node = packed.instantiate()
	root.add_child(inst)
	await create_timer(0.8).timeout
	if not await _save(out_dir.path_join("hub-amigos-1280.png")):
		quit(1)
		return
	var fp: Node = inst.get_node_or_null("%FriendsPanel")
	if fp != null and fp.has_method("open_drawer"):
		fp.call("open_drawer")
	await create_timer(0.45).timeout
	if not await _save(out_dir.path_join("hub-amigos-gaveta-1280.png")):
		quit(1)
		return
	print("CAPTURE_HUB_AMIGOS DONE")
	quit(0)


func _save(path: String) -> bool:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	if img == null:
		print("CAPTURE FAIL image null ", path)
		return false
	var err: Error = img.save_png(path)
	print("saved ", path, " ", img.get_width(), "x", img.get_height(), " err=", err)
	return err == OK
