extends SceneTree
## Captura PNGs das telas de UI para conferência visual (QA de arte).
## Precisa de janela real — NÃO rodar com --headless, senão o viewport sai preto.
##
##   godot --path . -s res://scripts/qa/capture_screens.gd
##
## Saída em user:// (Windows: %APPDATA%/Godot/app_userdata/<projeto>/screens/).
## Cada tela é capturada depois de alguns segundos para pegar tweens em curso.

const OUT_DIR := "user://screens"

## cena, apelido do arquivo, segundos de espera antes do clique do obturador,
## modo de edição da tela de nome (ignorado pelo hub).
const SHOTS: Array = [
	["res://scenes/ui/name_entry.tscn", "name_entry_onboarding", 0.6, false],
	["res://scenes/ui/name_entry.tscn", "name_entry_editar", 0.6, true],
	["res://scenes/main_menu/hub.tscn", "hub", 0.8, false],
	["res://scenes/main_menu/hub.tscn", "hub_late", 7.5, false],
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var game: Node = root.get_node_or_null("Game")
	var router: Node = root.get_node_or_null("SceneRouter")
	# Nome fictício só para o shot: mostra o hub e o modo editar já preenchidos.
	if game != null:
		game.set("player_name", "Caçador do Sol")
	for shot in SHOTS:
		if router != null:
			router.set("name_entry_edit_mode", bool(shot[3]))
		await _capture(str(shot[0]), str(shot[1]), float(shot[2]))
	print("CAPTURE DONE -> ", ProjectSettings.globalize_path(OUT_DIR))
	quit(0)


func _capture(scene_path: String, label: String, wait_s: float) -> void:
	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		push_error("capture: load falhou %s" % scene_path)
		return
	var inst: Node = packed.instantiate()
	root.add_child(inst)
	await create_timer(wait_s).timeout
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	if img == null:
		push_error("capture: viewport sem imagem (rodou com --headless?)")
	else:
		var path := "%s/%s.png" % [OUT_DIR, label]
		img.save_png(path)
		print("shot ", label, " ", img.get_size(), " -> ", path)
	inst.queue_free()
	await process_frame
