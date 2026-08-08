extends SceneTree
## Smoke headless do hub e da tela de nome de caçador.
## Cobre: sanitização/persistência do nome, roteamento do boot, instanciação das
## duas cenas e presença da arte dos botões.
## Uso: godot --headless --path . -s res://scripts/qa/smoke_hub_name_entry.gd

const HUB := "res://scenes/main_menu/hub.tscn"
const NAME_ENTRY := "res://scenes/ui/name_entry.tscn"
const PLATE_DIR := "res://assets/ui/buttons/hub"

var _ok: bool = true
var _messages: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _fail(msg: String) -> void:
	_ok = false
	_messages.append("FAIL: " + msg)


func _pass(msg: String) -> void:
	_messages.append("ok: " + msg)


func _run() -> void:
	var game: Node = root.get_node_or_null("Game")
	if game == null:
		_fail("autoload Game ausente")
		_finish()
		return
	var router: Node = root.get_node_or_null("SceneRouter")
	if router == null:
		_fail("autoload SceneRouter ausente")
		_finish()
		return

	_test_sanitize(game)
	_test_persistence(game)
	_test_router(router)
	_test_plates()
	await _test_scenes()
	_finish()


## Sanitização: apara pontas, colapsa espaços internos, corta no limite, rejeita vazio.
func _test_sanitize(game: Node) -> void:
	var max_len: int = int(game.get("MAX_PLAYER_NAME_LEN"))
	if max_len <= 0:
		_fail("MAX_PLAYER_NAME_LEN inválido: %d" % max_len)
		return
	var cases: Array = [
		["  Tanjiro  ", "Tanjiro"],
		["Caçador   do   Sol", "Caçador do Sol"],
		["   ", ""],
		["", ""],
		["\tNezuko\t", "Nezuko"],
	]
	for c in cases:
		var got: String = str(game.call("sanitize_player_name", c[0]))
		if got != c[1]:
			_fail("sanitize(%s) = %s (esperado %s)" % [JSON.stringify(c[0]), JSON.stringify(got), JSON.stringify(c[1])])
			return
	var long_name := "".lpad(max_len + 10, "A")
	var trimmed: String = str(game.call("sanitize_player_name", long_name))
	if trimmed.length() != max_len:
		_fail("sanitize não cortou no limite: %d (esperado %d)" % [trimmed.length(), max_len])
		return
	_pass("sanitize_player_name (5 casos + corte em %d)" % max_len)


## set_player_name persiste no save e load_game traz de volta; save antigo vira "".
func _test_persistence(game: Node) -> void:
	var prev_name: String = str(game.get("player_name"))

	if bool(game.call("set_player_name", "   ")):
		_fail("set_player_name aceitou nome só com espaços")
		return
	if not bool(game.call("set_player_name", "  Nezuko  ")):
		_fail("set_player_name rejeitou nome válido")
		return
	if str(game.get("player_name")) != "Nezuko":
		_fail("player_name = %s (esperado Nezuko)" % str(game.get("player_name")))
		return
	if not bool(game.call("has_player_name")):
		_fail("has_player_name false com nome definido")
		return

	var save_path: String = str(game.get("SAVE_PATH"))
	var raw: String = FileAccess.get_file_as_string(save_path)
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		_fail("save.json ilegível após set_player_name")
		return
	var data: Dictionary = parsed
	if str(data.get("player_name", "")) != "Nezuko":
		_fail("save.json player_name = %s" % str(data.get("player_name", "")))
		return

	# Save legado (sem a chave) tem que cair em "" e mandar pro onboarding.
	data.erase("player_name")
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f = null
	game.call("load_game")
	if str(game.get("player_name")) != "":
		_fail("save sem player_name devia virar \"\", veio %s" % str(game.get("player_name")))
		return
	if bool(game.call("has_player_name")):
		_fail("has_player_name true com save legado")
		return
	_pass("persistência + retrocompatibilidade de save")

	game.set("player_name", prev_name)
	game.call("save_game")


## O roteador conhece a tela de nome e guarda o modo (onboarding x edição).
func _test_router(router: Node) -> void:
	var path: String = str(router.get("NAME_ENTRY"))
	if path != NAME_ENTRY:
		_fail("SceneRouter.NAME_ENTRY = %s" % path)
		return
	if not router.has_method("to_name_entry"):
		_fail("SceneRouter.to_name_entry ausente")
		return
	router.set("name_entry_edit_mode", false)
	if bool(router.get("name_entry_edit_mode")):
		_fail("name_entry_edit_mode não reseta")
		return
	_pass("SceneRouter.to_name_entry + name_entry_edit_mode")


## A arte dos botões do hub tem que existir nos 4 estados (gen_hub_art.py rodado).
func _test_plates() -> void:
	var missing: Array[String] = []
	for plate in ["shop", "chars", "play", "settings"]:
		for state in ["normal", "hover", "pressed", "focus"]:
			var p := "%s/%s_%s.png" % [PLATE_DIR, plate, state]
			if not ResourceLoader.exists(p):
				missing.append(p)
	for icon in ["icon_profile", "icon_coin"]:
		var p := "%s/%s.png" % [PLATE_DIR, icon]
		if not ResourceLoader.exists(p):
			missing.append(p)
	if not missing.is_empty():
		_fail("arte de botão ausente (rodar tools/gen_hub_art.py): %s" % ", ".join(missing))
		return
	_pass("18 assets de botão presentes")


## Hub e tela de nome instanciam e sobrevivem a alguns frames em ambos os modos.
func _test_scenes() -> void:
	var router: Node = root.get_node_or_null("SceneRouter")
	for edit_mode in [false, true]:
		router.set("name_entry_edit_mode", edit_mode)
		if not await _instantiate(NAME_ENTRY, "name_entry(edit=%s)" % edit_mode):
			return
	if not await _instantiate(HUB, "hub"):
		return
	_pass("hub + name_entry instanciam e rodam")


func _instantiate(path: String, label: String) -> bool:
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		_fail("load falhou: %s" % path)
		return false
	var inst: Node = packed.instantiate()
	if inst == null:
		_fail("instantiate falhou: %s" % label)
		return false
	root.add_child(inst)
	# Vários frames: o _ready do hub tem await e só então mede layout/tweens.
	for i in range(6):
		await process_frame
	inst.queue_free()
	await process_frame
	return true


func _finish() -> void:
	print("=== smoke_hub_name_entry ===")
	for m in _messages:
		print("  - ", m)
	if _ok:
		print("HUB_NAME_ENTRY PASS")
		quit(0)
	else:
		print("HUB_NAME_ENTRY FAIL")
		quit(1)
