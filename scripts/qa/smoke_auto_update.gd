extends SceneTree
## Smoke do auto-updater: parse do manifesto, comparação de versão, UI no editor.
## Não bate na rede. Instalação Android fica de fora (só no aparelho).
## Uso: godot --headless --path . -s res://scripts/qa/smoke_auto_update.gd

const DIALOG_SCENE := "res://scenes/ui/update_dialog.tscn"
const LOCAL_VERSION := "res://updates/app_version.json"
const EXAMPLE_LATEST := "res://updates/latest.json"

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
	_test_autoload()
	_test_local_version()
	_test_parse_valid()
	_test_parse_rejects()
	_test_compare()
	_test_apk_magic()
	_test_sha256_skip()
	_test_example_latest()
	await _test_dialog()
	await _test_desktop_check_noop()
	_finish()


func _test_autoload() -> void:
	var u: Node = root.get_node_or_null("AutoUpdater")
	if u == null:
		_fail("autoload AutoUpdater ausente")
		return
	if not u.has_method("check_from_hub"):
		_fail("AutoUpdater sem check_from_hub")
		return
	if not u.has_method("get_local_version_code"):
		_fail("AutoUpdater sem get_local_version_code")
		return
	_pass("autoload AutoUpdater")


func _test_local_version() -> void:
	var local: Dictionary = UpdateManifest.load_local()
	var code: int = int(local.get("version_code", 0))
	var name_s: String = str(local.get("version_name", ""))
	var url: String = str(local.get("manifest_url", ""))
	if code <= 0:
		_fail("app_version.json sem version_code")
		return
	if name_s.is_empty():
		_fail("app_version.json sem version_name")
		return
	if not url.begins_with("https://"):
		_fail("manifest_url precisa ser https")
		return
	if not FileAccess.file_exists(LOCAL_VERSION):
		_fail("falta %s" % LOCAL_VERSION)
		return
	_pass("versão local %s / code %s" % [name_s, code])


func _test_parse_valid() -> void:
	var raw := """
	{"version_code": 3, "version_name": "0.0.3",
	 "apk_url": "https://example.com/treino.apk",
	 "changelog": "Pulo mais fácil.", "size_bytes": 12000000,
	 "sha256": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}
	"""
	var m: UpdateManifest = UpdateManifest.parse(raw)
	if not m.is_valid():
		_fail("parse válido falhou (%s)" % m.parse_error)
		return
	if m.version_code != 3 or m.version_name != "0.0.3":
		_fail("campos do manifesto lidos errado")
		return
	if UpdateManifest.format_size(12000000) == "":
		_fail("format_size vazio para 12MB")
		return
	_pass("parse manifesto válido")


func _test_parse_rejects() -> void:
	var cases: Array[Dictionary] = [
		{"text": "", "why": "vazio"},
		{"text": "[]", "why": "json nao-objeto"},
		{"text": "{\"version_code\":0,\"version_name\":\"x\",\"apk_url\":\"https://a\"}", "why": "code 0"},
		{"text": "{\"version_code\":2,\"version_name\":\"\",\"apk_url\":\"https://a\"}", "why": "nome vazio"},
		{"text": "{\"version_code\":2,\"version_name\":\"x\",\"apk_url\":\"http://inseguro\"}", "why": "http"},
		{"text": "{\"version_code\":2,\"version_name\":\"x\",\"apk_url\":\"ftp://x\"}", "why": "ftp"},
		{"text": "{\"version_code\":2,\"version_name\":\"x\",\"apk_url\":\"https://a\",\"size_bytes\":-1}", "why": "size negativo"},
		{"text": "{\"version_code\":2,\"version_name\":\"x\",\"apk_url\":\"https://a\",\"sha256\":\"abc\"}", "why": "sha curto"},
	]
	for c in cases:
		var m: UpdateManifest = UpdateManifest.parse(str(c["text"]))
		if m.is_valid():
			_fail("devia rejeitar: %s" % str(c["why"]))
			return
	_pass("rejeita manifesto ruim")


func _test_compare() -> void:
	var m: UpdateManifest = UpdateManifest.parse(
		"{\"version_code\":5,\"version_name\":\"0.0.5\",\"apk_url\":\"https://x/a.apk\"}"
	)
	if not m.is_newer_than(1):
		_fail("5 deveria ser mais novo que 1")
		return
	if m.is_newer_than(5):
		_fail("5 não é mais novo que 5")
		return
	if m.is_newer_than(9):
		_fail("5 não é mais novo que 9")
		return
	_pass("comparação version_code")


func _test_apk_magic() -> void:
	var tmp := "user://smoke_auto_update_magic.bin"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		_fail("não abriu temp pra magic")
		return
	f.store_buffer(PackedByteArray([0x50, 0x4B, 0x03, 0x04]))
	f.close()
	if not UpdateManifest.looks_like_apk(tmp):
		_fail("PK.. deveria parecer APK")
		DirAccess.remove_absolute(tmp)
		return
	var f2 := FileAccess.open(tmp, FileAccess.WRITE)
	f2.store_string("<html>nope</html>")
	f2.close()
	if UpdateManifest.looks_like_apk(tmp):
		_fail("HTML não pode parecer APK")
		DirAccess.remove_absolute(tmp)
		return
	DirAccess.remove_absolute(tmp)
	_pass("magic ZIP/APK")


func _test_sha256_skip() -> void:
	if not UpdateManifest.sha256_matches("user://nao_existe.apk", ""):
		_fail("sha vazio deveria pular")
		return
	if UpdateManifest.sha256_matches("user://nao_existe.apk", "aa".repeat(32)):
		_fail("arquivo ausente com sha não pode passar")
		return
	_pass("sha256 opcional")


func _test_example_latest() -> void:
	if not FileAccess.file_exists(EXAMPLE_LATEST):
		_fail("falta updates/latest.json de exemplo")
		return
	var f := FileAccess.open(EXAMPLE_LATEST, FileAccess.READ)
	var m: UpdateManifest = UpdateManifest.parse(f.get_as_text())
	if not m.is_valid():
		_fail("latest.json de exemplo inválido (%s)" % m.parse_error)
		return
	_pass("exemplo latest.json")


func _test_dialog() -> void:
	if not ResourceLoader.exists(DIALOG_SCENE):
		_fail("cena do aviso ausente")
		return
	var packed: PackedScene = load(DIALOG_SCENE) as PackedScene
	if packed == null:
		_fail("não carregou update_dialog.tscn")
		return
	var dlg: CanvasLayer = packed.instantiate() as CanvasLayer
	if dlg == null:
		_fail("update_dialog não é CanvasLayer")
		return
	root.add_child(dlg)
	await process_frame
	var m: UpdateManifest = UpdateManifest.parse(
		"{\"version_code\":9,\"version_name\":\"9.9.9\",\"apk_url\":\"https://x/a.apk\",\"changelog\":\"Teste.\"}"
	)
	if not dlg.has_method("show_offer"):
		_fail("dialog sem show_offer")
		dlg.queue_free()
		return
	dlg.call("show_offer", m, "0.0.1")
	await process_frame
	if not dlg.visible:
		_fail("aviso não ficou visível no offer")
		dlg.queue_free()
		return
	var title: Label = dlg.get_node_or_null("%TitleLabel") as Label
	var primary: Button = dlg.get_node_or_null("%PrimaryButton") as Button
	if title == null or not title.text.contains("versão nova"):
		_fail("título do aviso errado")
		dlg.queue_free()
		return
	if primary == null or primary.text != "ATUALIZAR":
		_fail("botão ATUALIZAR ausente")
		dlg.queue_free()
		return
	dlg.call("show_failed")
	await process_frame
	if primary.text != "TENTAR DE NOVO":
		_fail("estado de falha sem tentar de novo")
		dlg.queue_free()
		return
	dlg.call("hide_dialog")
	await process_frame
	if dlg.visible:
		_fail("hide_dialog não escondeu")
		dlg.queue_free()
		return
	dlg.queue_free()
	_pass("UI do aviso (offer / falha / hide)")


func _test_desktop_check_noop() -> void:
	var u: Node = root.get_node_or_null("AutoUpdater")
	if u == null:
		return
	u.call("check_from_hub")
	await process_frame
	await process_frame
	var dlg: Node = u.get_node_or_null("UpdateDialog")
	if dlg != null and bool(dlg.get("visible")):
		_fail("check no desktop abriu popup sem debug prompt")
		return
	_pass("desktop check não abre popup")


func _finish() -> void:
	print("=== smoke_auto_update ===")
	for msg in _messages:
		print("  - ", msg)
	if _ok:
		print("AUTO_UPDATE PASS")
		quit(0)
	else:
		print("AUTO_UPDATE FAIL")
		quit(1)
