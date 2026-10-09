extends SceneTree
## Captura as 9 telas-meta (entrada já terminada, 0.9 s) + a cortina no meio do close().
## Precisa de janela real — NÃO rodar com --headless.
##   $env:HASHIRA_CAPTURE_DIR = "$env:TEMP\f4shots"
##   godot --path . --resolution 1280x720 -s res://scripts/qa/capture_f4_telas.gd

const TRANSITION := "res://scripts/ui/transition.gd"
const SHOTS: Array = [
	["res://scenes/ui/shop.tscn", "shop"],
	["res://scenes/ui/character_select.tscn", "characters"],
	["res://scenes/ui/settings.tscn", "settings"],
	["res://scenes/ui/missions.tscn", "missions"],
	["res://scenes/ui/news.tscn", "news"],
	["res://scenes/ui/club.tscn", "club"],
	["res://scenes/ui/events.tscn", "events"],
	["res://scenes/ui/credits.tscn", "credits"],
	["res://scenes/ui/name_entry.tscn", "name_entry"],
]

var _out_dir: String = ""
var _game: Node = null


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_out_dir = OS.get_environment("HASHIRA_CAPTURE_DIR")
	if _out_dir.is_empty():
		_out_dir = "user://f4shots"
	DirAccess.make_dir_recursive_absolute(_out_dir)
	_game = root.get_node_or_null("Game")
	if _game != null:
		_game.call("set_save_path", "user://capture_f4_save.json")
		_game.set("player_name", "Caçador do Sol")
	var router: Node = root.get_node_or_null("SceneRouter")
	if router != null:
		router.set("name_entry_edit_mode", true)
	for shot in SHOTS:
		await _capture(str(shot[0]), str(shot[1]), 0.9)
	await _capture_transition()
	_cleanup()
	print("CAPTURE F4 DONE -> ", ProjectSettings.globalize_path(_out_dir))
	quit(0)


func _save(label: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	if img == null:
		push_error("capture: viewport sem imagem (rodou com --headless?)")
		return
	var path := "%s/%s.png" % [_out_dir, label]
	img.save_png(path)
	print("shot ", label, " ", img.get_size(), " -> ", path)


func _capture(scene_path: String, label: String, wait_s: float) -> void:
	var packed: PackedScene = load(scene_path) as PackedScene
	var inst: Node = packed.instantiate()
	root.add_child(inst)
	await create_timer(wait_s).timeout
	await _save(label)
	inst.queue_free()
	await process_frame


func _capture_transition() -> void:
	var packed: PackedScene = load("res://scenes/ui/shop.tscn") as PackedScene
	var inst: Node = packed.instantiate()
	root.add_child(inst)
	await create_timer(0.9).timeout
	var tr: CanvasLayer = (load(TRANSITION) as GDScript).new()
	root.add_child(tr)
	tr.close(0.3)
	await create_timer(0.12).timeout
	await _save("transicao_meio")
	await create_timer(0.3).timeout
	tr.queue_free()
	inst.queue_free()


func _cleanup() -> void:
	if _game != null:
		_game.call("set_save_path", "")
		_game.call("load_game")
	if FileAccess.file_exists("user://capture_f4_save.json"):
		DirAccess.remove_absolute("user://capture_f4_save.json")
