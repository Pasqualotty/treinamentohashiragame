extends SceneTree
## Smoke E2E do boot: splash -> loading -> destino certo.
## Save sem nome tem que cair na tela de nome; save com nome vai direto pro hub.
## Uso: godot --headless --path . -s res://scripts/qa/smoke_boot_flow.gd

const SPLASH := "res://scenes/boot/splash_studio.tscn"
const NAME_ENTRY := "res://scenes/ui/name_entry.tscn"
const HUB := "res://scenes/main_menu/hub.tscn"
## Splash (2.2s) + cortinas de transição + barra de loading, com folga.
const BOOT_TIMEOUT := 20.0
const POLL := 0.25

var _ok: bool = true
var _messages: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game: Node = root.get_node_or_null("Game")
	if game == null:
		_messages.append("FAIL: autoload Game ausente")
		_ok = false
		_finish()
		return

	var save_path: String = str(game.get("SAVE_PATH"))
	var backup: String = ""
	if FileAccess.file_exists(save_path):
		backup = FileAccess.get_file_as_string(save_path)

	# 1) Primeiro boot: sem nome no save -> onboarding.
	game.set("player_name", "")
	game.call("save_game")
	await _expect_boot_lands_on(NAME_ENTRY, "sem nome -> tela de nome")

	# 2) Boot seguinte: nome salvo -> hub direto.
	if not bool(game.call("set_player_name", "Tanjiro")):
		_ok = false
		_messages.append("FAIL: set_player_name recusou nome válido")
	else:
		await _expect_boot_lands_on(HUB, "com nome -> hub")

	# Devolve o save do usuário como estava.
	if backup != "":
		var f := FileAccess.open(save_path, FileAccess.WRITE)
		f.store_string(backup)
		f = null
		game.call("load_game")
	_finish()


func _expect_boot_lands_on(expected: String, label: String) -> void:
	change_scene_to_file(SPLASH)
	var waited: float = 0.0
	var landed: String = ""
	while waited < BOOT_TIMEOUT:
		await create_timer(POLL).timeout
		waited += POLL
		if current_scene == null:
			continue
		landed = current_scene.scene_file_path
		if landed == expected:
			_messages.append("ok: %s (%.1fs)" % [label, waited])
			return
	_ok = false
	_messages.append("FAIL: %s — parou em %s após %.1fs" % [label, landed, waited])


func _finish() -> void:
	print("=== smoke_boot_flow ===")
	for m in _messages:
		print("  - ", m)
	if _ok:
		print("BOOT_FLOW PASS")
		quit(0)
	else:
		print("BOOT_FLOW FAIL")
		quit(1)
