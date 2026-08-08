extends SceneTree
## Smoke E2E do boot: splash -> loading -> destino certo.
## Save sem nome tem que cair na tela de nome; save com nome vai direto pro hub.
## Uso: godot --headless --path . -s res://scripts/qa/smoke_boot_flow.gd
##
## Este smoke NUNCA escreve em user://save.json. `Game.set_save_path` desvia o
## save para um arquivo temporário, apagado em todos os caminhos de saída — antes
## o restore só rodava `if backup != ""` e, em máquina sem save prévio (CI, dev
## novo), o teste deixava player_name="Tanjiro" gravado e a rodada seguinte já
## caía direto no hub, exercitando outro caminho sem ninguém perceber.

const SPLASH := "res://scenes/boot/splash_studio.tscn"
const NAME_ENTRY := "res://scenes/ui/name_entry.tscn"
const HUB := "res://scenes/main_menu/hub.tscn"
## Save descartável do teste.
const TEMP_SAVE := "user://smoke_boot_flow_save.json"
## Splash (2.2s) + cortinas de transição + barra de loading, com folga.
const BOOT_TIMEOUT := 20.0
const POLL := 0.25

var _ok: bool = true
var _messages: Array[String] = []

var _game: Node = null
var _temp_save_active: bool = false
var _orig_name: String = ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game: Node = root.get_node_or_null("Game")
	if game == null:
		_messages.append("FAIL: autoload Game ausente")
		_ok = false
		_finish()
		return

	_use_temp_save(game)

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

	_finish()


## --- Isolamento do save ---------------------------------------------------

## Desvia o save para um arquivo temporário e parte de "máquina sem save".
func _use_temp_save(game: Node) -> void:
	_game = game
	_orig_name = str(game.get("player_name"))
	game.call("set_save_path", TEMP_SAVE)
	_temp_save_active = true
	_delete_temp_save()


## Idempotente: pode ser chamado de qualquer caminho de saída.
func _restore_save() -> void:
	if not _temp_save_active:
		return
	_temp_save_active = false
	_delete_temp_save()
	if _game == null:
		return
	_game.call("set_save_path", "")
	# Volta a memória ao estado do boot antes de reler o save real — se o save
	# real não existir, `load_game` sai cedo e não desfaria nada sozinho.
	_game.set("player_name", _orig_name)
	_game.call("load_game")


func _delete_temp_save() -> void:
	if FileAccess.file_exists(TEMP_SAVE):
		DirAccess.remove_absolute(TEMP_SAVE)


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
	# Restaura ANTES de qualquer print/quit: vale para pass e para todo fail.
	_restore_save()
	print("=== smoke_boot_flow ===")
	for m in _messages:
		print("  - ", m)
	if _ok:
		print("BOOT_FLOW PASS")
		quit(0)
	else:
		print("BOOT_FLOW FAIL")
		quit(1)
