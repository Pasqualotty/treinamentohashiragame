extends SceneTree
## Smoke headless do hub e da tela de nome de caçador.
## Cobre: sanitização/persistência do nome, gate do onboarding contra nomes
## invisíveis, guarda de reentrância do confirmar, roteamento do boot,
## instanciação das duas cenas e presença da arte dos botões.
## Uso: godot --headless --path . -s res://scripts/qa/smoke_hub_name_entry.gd
##
## Este smoke NUNCA escreve em user://save.json: `Game.set_save_path` aponta o
## save para um arquivo temporário que é apagado em todos os caminhos de saída.

const HUB := "res://scenes/main_menu/hub.tscn"
const NAME_ENTRY := "res://scenes/ui/name_entry.tscn"
const PLATE_DIR := "res://assets/ui/buttons/hub"
## Save descartável do teste. Some no `_finish`, aconteça o que acontecer.
const TEMP_SAVE := "user://smoke_hub_name_entry_save.json"

var _ok: bool = true
var _messages: Array[String] = []

var _game: Node = null
var _temp_save_active: bool = false
var _orig_name: String = ""


func _initialize() -> void:
	call_deferred("_run")


func _fail(msg: String) -> void:
	_ok = false
	_messages.append("FAIL: " + msg)


func _pass(msg: String) -> void:
	_messages.append("ok: " + msg)


## Renderiza invisíveis como \uXXXX. Sem isto uma falha de ZWSP sai no relatório
## como `sanitize("") = "" (esperado "")` e não dá para depurar nada.
func _dbg(s: String) -> String:
	var shown := ""
	for c in s:
		var code: int = c.unicode_at(0)
		var hide: bool = code < 32 \
			or (code >= 0x7F and code <= 0xA0) \
			or code == 0x00AD or code == 0x1680 \
			or (code >= 0x2000 and code <= 0x206F) \
			or code == 0x3000 or code == 0xFEFF
		shown += ("\\u%04X" % code) if hide else c
	return "\"%s\"" % shown


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

	_use_temp_save(game)

	_test_sanitize(game)
	_test_invisible_name_gate(game)
	_test_persistence(game)
	_test_router(router)
	_test_plates()
	await _test_scenes()
	await _test_no_double_submit(router)
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


## --- Testes ---------------------------------------------------------------

## Sanitização: apara pontas, colapsa espaços internos, corta no limite, rejeita
## vazio e derruba controle/invisíveis (DEL, C1, NBSP, ZWSP, BOM, override bidi).
func _test_sanitize(game: Node) -> void:
	var max_len: int = int(game.get("MAX_PLAYER_NAME_LEN"))
	if max_len <= 0:
		_fail("MAX_PLAYER_NAME_LEN inválido: %d" % max_len)
		return
	var nbsp := char(0x00A0)
	var zwsp := char(0x200B)
	var bom := char(0xFEFF)
	var del := char(0x7F)
	var nel := char(0x0085)  # C1
	var rlo := char(0x202E)  # override bidi
	var cases: Array = [
		["  Tanjiro  ", "Tanjiro"],
		["Caçador   do   Sol", "Caçador do Sol"],
		["   ", ""],
		["", ""],
		["\tNezuko\t", "Nezuko"],
		# DEL (U+007F): passava pelo filtro `>= 32` e virava nome invisível.
		[del + del, ""],
		["Tan" + del + "jiro", "Tanjiro"],
		# Bloco C1 (U+0080-U+009F).
		[nel + "Nezuko" + nel, "Nezuko"],
		[nel + nel, ""],
		# NBSP: escapava do split(" ") e do strip_edges().
		[nbsp + nbsp, ""],
		[nbsp + "Nezuko" + nbsp, "Nezuko"],
		["Caçador" + nbsp + "do" + nbsp + "Sol", "Caçador do Sol"],
		# ZWSP e BOM: largura zero, o gate do onboarding caía com dois deles.
		[zwsp + zwsp, ""],
		[bom, ""],
		["Zen" + zwsp + "itsu", "Zenitsu"],
		# Override bidi (Cf).
		[rlo + "Inosuke", "Inosuke"],
		[rlo + char(0x200E), ""],
	]
	for c in cases:
		var got: String = str(game.call("sanitize_player_name", c[0]))
		if got != c[1]:
			_fail("sanitize(%s) = %s (esperado %s)" % [_dbg(c[0]), _dbg(got), _dbg(c[1])])
			return
	var long_name := "".lpad(max_len + 10, "A")
	var trimmed: String = str(game.call("sanitize_player_name", long_name))
	if trimmed.length() != max_len:
		_fail("sanitize não cortou no limite: %d (esperado %d)" % [trimmed.length(), max_len])
		return
	_pass("sanitize_player_name (%d casos + corte em %d)" % [cases.size(), max_len])


## Gate do onboarding: nome só de invisíveis não pode virar "jogador tem nome",
## nem ser gravado no save. Sem isto, dois ZWSP pulavam a tela de nome.
func _test_invisible_name_gate(game: Node) -> void:
	game.set("player_name", "")
	game.call("save_game")

	var attempts: Array[String] = [
		char(0x200B) + char(0x200B),
		char(0x00A0) + char(0x00A0),
		char(0xFEFF),
		char(0x7F) + char(0x0085),
		char(0x202E) + char(0x200E),
	]
	for a in attempts:
		if bool(game.call("set_player_name", a)):
			_fail("set_player_name aceitou nome invisível: %s" % _dbg(a))
			return
	if bool(game.call("has_player_name")):
		_fail("has_player_name true após nome só de invisíveis")
		return

	var raw: String = FileAccess.get_file_as_string(str(game.call("get_save_path")))
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		_fail("save ilegível no gate de invisíveis")
		return
	if str((parsed as Dictionary).get("player_name", "")) != "":
		_fail("save gravou nome invisível: %s" % _dbg(str((parsed as Dictionary).get("player_name", ""))))
		return

	# E um save adulterado com invisível tem que voltar como "" (manda pro onboarding).
	var data: Dictionary = parsed
	data["player_name"] = char(0x200B) + char(0x200B)
	var f := FileAccess.open(str(game.call("get_save_path")), FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f = null
	game.call("load_game")
	if bool(game.call("has_player_name")):
		_fail("save com nome invisível passou pelo load_game")
		return
	_pass("gate do onboarding resiste a nome invisível (5 formas + save adulterado)")


## set_player_name persiste no save e load_game traz de volta; save antigo vira "".
func _test_persistence(game: Node) -> void:
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

	var save_path: String = str(game.call("get_save_path"))
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
	# Escreve no save temporário — o save real do dev nunca entra nesta conta.
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


## Enter duplo (ou duplo-toque no "Done" do teclado virtual) só pode disparar UMA
## navegação: sem guarda, a segunda entrada caía no ramo `is_busy()` do go_to e
## instanciava o hub duas vezes.
## Exercita `_claim_submit()`, o pedaço puro de `_confirm()`: mede exatamente a
## guarda sem trocar de cena de verdade — uma navegação real deixaria um
## `to_hub()` assíncrono no ar, capaz de gravar save depois do restore do smoke.
func _test_no_double_submit(router: Node) -> void:
	router.set("name_entry_edit_mode", false)
	var packed: PackedScene = load(NAME_ENTRY) as PackedScene
	if packed == null:
		_fail("load falhou para o teste de submit duplo: %s" % NAME_ENTRY)
		return
	var inst: Node = packed.instantiate()
	root.add_child(inst)
	await process_frame
	var field: LineEdit = inst.get("name_input") as LineEdit
	if field == null:
		_fail("name_input não resolvido na tela de nome")
		inst.queue_free()
		return

	# Nome inválido não pode armar a guarda (senão a tela trava para sempre).
	for bad in ["   ", char(0x200B) + char(0x200B)]:
		field.text = bad
		if bool(inst.call("_claim_submit")):
			_fail("confirmar aceitou nome inválido: %s" % _dbg(bad))
			inst.queue_free()
			return
	if bool(inst.get("_navigating")):
		_fail("guarda armada por nome inválido — tela travaria sem navegar")
		inst.queue_free()
		return

	# Agora o caminho válido: 3 Enters, exatamente 1 navegação.
	field.text = "Tanjiro"
	var dispatched: int = 0
	for i in range(3):
		if bool(inst.call("_claim_submit")):
			dispatched += 1
	if dispatched != 1:
		_fail("Enter x3 disparou %d navegações (esperado 1) — hub instanciaria em dobro" % dispatched)
		inst.queue_free()
		return

	inst.queue_free()
	await process_frame
	_pass("Enter x3 = 1 navegação (guarda de reentrância do confirmar)")


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
	# Restaura ANTES de qualquer print/quit: vale para pass e para todo fail.
	_restore_save()
	print("=== smoke_hub_name_entry ===")
	for m in _messages:
		print("  - ", m)
	if _ok:
		print("HUB_NAME_ENTRY PASS")
		quit(0)
	else:
		print("HUB_NAME_ENTRY FAIL")
		quit(1)
