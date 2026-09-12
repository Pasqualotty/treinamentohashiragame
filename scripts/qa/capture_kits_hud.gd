extends SceneTree
## Print 1280×720 do HUD touch com dois caçadores (botões de skill diferentes).
## Precisa de janela real — NÃO usar --headless.
## HASHIRA_CAPTURE_DIR = pasta de saída.

const TOUCH := "res://scenes/ui/combat_touch_controls.tscn"
const HUD := "res://scenes/ui/combat_hud.tscn"
const PLAYER := "res://scenes/characters/player/player.tscn"


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
	var game: Node = root.get_node_or_null("Game")
	if game == null:
		print("CAPTURE FAIL Game")
		quit(1)
		return
	if not await _shot(game, out_dir, "tanjiro", "hud-tanjiro-1280.png"):
		quit(1)
		return
	if not await _shot(game, out_dir, "zenitsu", "hud-zenitsu-1280.png"):
		quit(1)
		return
	print("CAPTURE_KITS_HUD DONE")
	quit(0)


func _shot(game: Node, out_dir: String, character_id: String, filename: String) -> bool:
	game.set("current_character_id", character_id)
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.08, 0.11, 1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.size = Vector2(1280, 720)
	root.add_child(bg)
	var packed_p: PackedScene = load(PLAYER) as PackedScene
	var packed_t: PackedScene = load(TOUCH) as PackedScene
	var packed_h: PackedScene = load(HUD) as PackedScene
	if packed_p == null or packed_t == null or packed_h == null:
		print("CAPTURE FAIL load ", character_id)
		return false
	var player: Node = packed_p.instantiate()
	player.position = Vector2(420, 520)
	root.add_child(player)
	var hud: Node = packed_h.instantiate()
	root.add_child(hud)
	var touch: Node = packed_t.instantiate()
	root.add_child(touch)
	await process_frame
	await process_frame
	if touch.has_method("refresh_character_icons"):
		touch.call("refresh_character_icons")
	await create_timer(0.45).timeout
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	if img == null:
		print("CAPTURE FAIL image null ", character_id)
		return false
	var path := out_dir.path_join(filename)
	var err: Error = img.save_png(path)
	print("saved ", path, " ", img.get_width(), "x", img.get_height(), " err=", err)
	if err != OK or img.get_width() < 1280 or img.get_height() < 720:
		print("CAPTURE FAIL size/err ", character_id)
		return false
	if touch.has_method("get_icon_resource_path"):
		print("icon skill_1 ", character_id, " ", touch.call("get_icon_resource_path", "skill_1"))
	touch.queue_free()
	hud.queue_free()
	player.queue_free()
	bg.queue_free()
	await process_frame
	return true
