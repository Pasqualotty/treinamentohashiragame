extends SceneTree
## Captura F5 1280x720: hub em 0.25 s (meio da entrada) e 1.5 s (pronto); mapa W1 em
## 1.2 s; mapa W3 (progresso só em memória) em 1.2 s. Janela real — NÃO usar --headless.
## HASHIRA_CAPTURE_DIR = pasta de saída. NUNCA chama Game.save_game().

const HUB := "res://scenes/main_menu/hub.tscn"
const MAP := "res://scenes/world/world_map.tscn"
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
	var game: Node = root.get_node_or_null("Game")
	var saved_cleared: Array[String] = (game.get("stages_cleared") as Array[String]).duplicate()
	var saved_world: String = str(game.get("current_world_id"))
	var ok: bool = await _shoot_hub(out_dir)
	if ok:
		var none: Array[String] = []
		game.set("stages_cleared", none)
		game.set("current_world_id", "w1")
		ok = await _shoot_map(out_dir.path_join("f5-mapa-w1.png"))
	if ok:
		var w2: Array[String] = ["w1_boss", "w2_01", "w2_02", "w2_03", "w2_boss", "w3_01"]
		game.set("stages_cleared", w2)
		game.set("current_world_id", "w3")
		ok = await _shoot_map(out_dir.path_join("f5-mapa-w3.png"))
	game.set("stages_cleared", saved_cleared)
	game.set("current_world_id", saved_world)
	print("CAPTURE_F5 DONE ", ok)
	quit(0 if ok else 1)


func _shoot_hub(out_dir: String) -> bool:
	var inst: Node = (load(HUB) as PackedScene).instantiate()
	root.add_child(inst)
	await create_timer(0.25).timeout
	if not await _save(out_dir.path_join("f5-hub-025s.png")):
		return false
	await create_timer(1.25).timeout
	var ok: bool = await _save(out_dir.path_join("f5-hub-150s.png"))
	inst.queue_free()
	await process_frame
	return ok


func _shoot_map(path: String) -> bool:
	var inst: Node = (load(MAP) as PackedScene).instantiate()
	root.add_child(inst)
	await create_timer(1.2).timeout
	var ok: bool = await _save(path)
	inst.queue_free()
	await process_frame
	return ok


func _save(path: String) -> bool:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	if img == null:
		print("CAPTURE FAIL image null ", path)
		return false
	var err: Error = img.save_png(path)
	print("saved ", path, " ", img.get_width(), "x", img.get_height(), " err=", err)
	return err == OK
