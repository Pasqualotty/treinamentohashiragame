extends SceneTree
## Captura PERSONAGENS 1280×720. Janela real — NÃO usar --headless.
## HASHIRA_CAPTURE_DIR = pasta de saída (personagens-1280.png + fileira3).

const SELECT := "res://scenes/ui/character_select.tscn"
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
	if game != null and game.has_method("select_character"):
		game.call("select_character", "nezuko")
	var packed: PackedScene = load(SELECT) as PackedScene
	if packed == null:
		print("CAPTURE FAIL character_select.tscn")
		quit(1)
		return
	var inst: Node = packed.instantiate()
	root.add_child(inst)
	await create_timer(0.9).timeout
	if not await _save(out_dir.path_join("personagens-1280.png")):
		quit(1)
		return
	if not await _scroll_to_row(inst, 2):
		print("CAPTURE FAIL scroll fileira3")
		quit(1)
		return
	await create_timer(0.4).timeout
	if not await _save(out_dir.path_join("personagens-1280-fileira3.png")):
		quit(1)
		return
	print("CAPTURE_PERSONAGENS DONE")
	quit(0)


func _scroll_to_row(inst: Node, row_index: int) -> bool:
	var scroll: ScrollContainer = inst.find_child("Scroll", true, false) as ScrollContainer
	var grid: GridContainer = inst.find_child("Grid", true, false) as GridContainer
	if scroll == null or grid == null:
		return false
	var idx: int = row_index * grid.columns
	if idx >= grid.get_child_count():
		return false
	var card: Control = grid.get_child(idx) as Control
	if card == null:
		return false
	scroll.set_deferred("scroll_vertical", int(round(card.position.y)))
	await process_frame
	await process_frame
	scroll.scroll_vertical = int(round(card.position.y))
	print(
		"CAPTURE scroll_v=",
		scroll.scroll_vertical,
		" row=",
		row_index,
		" card_y=",
		card.position.y,
		" card_h=",
		card.size.y
	)
	return true


func _save(path: String) -> bool:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	if img == null:
		print("CAPTURE FAIL image null ", path)
		return false
	var err: Error = img.save_png(path)
	print("saved ", path, " ", img.get_width(), "x", img.get_height(), " err=", err)
	return err == OK
