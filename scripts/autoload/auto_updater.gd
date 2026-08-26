extends Node
## OTA sideload: no hub, GET do manifesto remoto; se version_code maior, avisa.
## Nunca bloqueia boot, mapa ou combate. Desktop/editor: no-op (ou preview).

const DIALOG_SCENE := "res://scenes/ui/update_dialog.tscn"
const DOWNLOAD_PATH := "user://updates/hashira-update.apk"
const DEBUG_PROMPT_PATH := "user://debug_update_prompt.json"
const MANIFEST_TIMEOUT := 8.0
const APK_TIMEOUT := 180.0
const PROGRESS_TICK := 0.12
const HUB_SCENE := "res://scenes/main_menu/hub.tscn"
const USER_AGENT := "TreinamentoHashira-OTA"

signal check_finished(had_update: bool)

var _http: HTTPRequest
var _dialog: CanvasLayer
var _pending: UpdateManifest
var _local_code: int = 1
var _local_name: String = "0.0.1"
var _manifest_url: String = ""
var _busy: bool = false
var _mode: String = ""
var _snoozed_code: int = 0
var _waiting_permission: bool = false
var _progress_timer: Timer


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.name = "UpdateHttp"
	_http.use_threads = true
	_http.max_redirects = 8
	_http.download_chunk_size = 65536
	add_child(_http)
	_http.request_completed.connect(_on_http_completed)

	_progress_timer = Timer.new()
	_progress_timer.wait_time = PROGRESS_TICK
	_progress_timer.one_shot = false
	add_child(_progress_timer)
	_progress_timer.timeout.connect(_on_progress_tick)

	_reload_local_version()


func _reload_local_version() -> void:
	var local: Dictionary = UpdateManifest.load_local()
	_local_code = int(local.get("version_code", 1))
	_local_name = str(local.get("version_name", "0.0.1"))
	_manifest_url = str(local.get("manifest_url", ""))
	var pkg_code: int = AndroidApkInstaller.read_package_version_code()
	if pkg_code > 0:
		_local_code = pkg_code


func get_local_version_code() -> int:
	return _local_code


func get_local_version_name() -> String:
	return _local_name


## Chamado pelo hub depois do layout. Sem internet / falha = silêncio.
func check_from_hub() -> void:
	_reload_local_version()
	if _busy:
		return
	if not AndroidApkInstaller.is_android():
		_maybe_debug_preview()
		print("AutoUpdater: desktop/editor — check remoto pulado (só no celular)")
		check_finished.emit(false)
		return
	if _pending != null and _pending.is_newer_than(_local_code) and _pending.version_code != _snoozed_code:
		_show_offer(_pending)
		return
	if _manifest_url.is_empty() or not _manifest_url.begins_with("https://"):
		push_warning("AutoUpdater: manifest_url ausente ou não-https")
		check_finished.emit(false)
		return
	_fetch_manifest()


func _maybe_debug_preview() -> void:
	if not FileAccess.file_exists(DEBUG_PROMPT_PATH):
		return
	var f := FileAccess.open(DEBUG_PROMPT_PATH, FileAccess.READ)
	if f == null:
		return
	var m: UpdateManifest = UpdateManifest.parse(f.get_as_text())
	if not m.is_valid():
		push_warning("AutoUpdater: debug_update_prompt.json inválido (%s)" % m.parse_error)
		return
	_pending = m
	_show_offer(m)


func _fetch_manifest() -> void:
	_busy = true
	_mode = "manifest"
	_http.timeout = MANIFEST_TIMEOUT
	_http.set_download_file("")
	var err := _http.request(_manifest_url, _headers(), HTTPClient.METHOD_GET)
	if err != OK:
		_busy = false
		_mode = ""
		push_warning("AutoUpdater: falha ao pedir manifesto (err=%s)" % err)
		check_finished.emit(false)


func _headers() -> PackedStringArray:
	return PackedStringArray([
		"Accept: application/json",
		"User-Agent: %s/%s" % [USER_AGENT, _local_name],
	])


func _on_http_completed(result: int, response_code: int, _headers_in: PackedStringArray, body: PackedByteArray) -> void:
	var mode := _mode
	_mode = ""
	_progress_timer.stop()
	if mode == "manifest":
		_busy = false
		_handle_manifest(result, response_code, body)
		return
	if mode == "apk":
		_handle_apk(result, response_code)
		return


func _handle_manifest(result: int, response_code: int, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		print("AutoUpdater: manifesto indisponível (result=%s http=%s) — jogo segue" % [result, response_code])
		check_finished.emit(false)
		return
	var m: UpdateManifest = UpdateManifest.parse(body.get_string_from_utf8())
	if not m.is_valid():
		push_warning("AutoUpdater: manifesto inválido (%s)" % m.parse_error)
		check_finished.emit(false)
		return
	_pending = m
	if not m.is_newer_than(_local_code):
		print("AutoUpdater: já na última (%s / %s)" % [_local_name, _local_code])
		check_finished.emit(false)
		return
	if m.version_code == _snoozed_code:
		check_finished.emit(true)
		return
	if not _is_on_hub():
		print("AutoUpdater: update %s disponível, mas jogador saiu do hub" % m.version_name)
		check_finished.emit(true)
		return
	_show_offer(m)
	check_finished.emit(true)


func _handle_apk(result: int, response_code: int) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_fail_download()
		return
	if not FileAccess.file_exists(DOWNLOAD_PATH) or not UpdateManifest.looks_like_apk(DOWNLOAD_PATH):
		_fail_download()
		return
	if _pending != null and _pending.size_bytes > 0:
		var got: int = _file_size(DOWNLOAD_PATH)
		if got < int(float(_pending.size_bytes) * 0.90):
			_fail_download()
			return
	if _pending != null and not UpdateManifest.sha256_matches(DOWNLOAD_PATH, _pending.sha256):
		push_warning("AutoUpdater: sha256 do APK não bate")
		_fail_download()
		return
	_begin_install()


func _fail_download() -> void:
	_busy = false
	_delete_download()
	if _dialog != null and _dialog.has_method("show_failed"):
		_dialog.call("show_failed")


func start_update_from_ui() -> void:
	if _pending == null or not _pending.is_valid():
		return
	if not AndroidApkInstaller.is_android():
		if _dialog != null and _dialog.has_method("show_desktop_only"):
			_dialog.call("show_desktop_only")
		return
	if not AndroidApkInstaller.can_request_installs():
		_waiting_permission = true
		if _dialog != null and _dialog.has_method("show_permission"):
			_dialog.call("show_permission")
		return
	_start_download()


func open_install_permission() -> void:
	var err := AndroidApkInstaller.open_unknown_sources_settings()
	if not err.is_empty():
		push_warning("AutoUpdater: não abriu permissão (%s)" % err)
		if _dialog != null and _dialog.has_method("show_failed"):
			_dialog.call("show_failed")


func retry_update() -> void:
	start_update_from_ui()


func snooze() -> void:
	if _pending != null:
		_snoozed_code = _pending.version_code
	_waiting_permission = false
	_cancel_download()
	_hide_dialog()


func cancel_download() -> void:
	_cancel_download()
	if _dialog != null and _dialog.has_method("show_offer") and _pending != null:
		_dialog.call("show_offer", _pending, _local_name)
		return
	_hide_dialog()


func _cancel_download() -> void:
	_http.cancel_request()
	_progress_timer.stop()
	_http.set_download_file("")
	_busy = false
	_mode = ""
	_delete_download()


func _start_download() -> void:
	if _pending == null:
		return
	_busy = true
	_mode = "apk"
	_ensure_download_dir()
	_delete_download()
	_http.timeout = APK_TIMEOUT
	_http.set_download_file(DOWNLOAD_PATH)
	if _dialog != null and _dialog.has_method("show_downloading"):
		_dialog.call("show_downloading", 0.0)
	_progress_timer.start()
	var err := _http.request(_pending.apk_url, PackedStringArray([
		"User-Agent: %s/%s" % [USER_AGENT, _local_name],
	]), HTTPClient.METHOD_GET)
	if err != OK:
		_http.set_download_file("")
		_fail_download()


func _on_progress_tick() -> void:
	if _dialog == null or not _dialog.has_method("show_downloading"):
		return
	var got: int = _http.get_downloaded_bytes()
	var total: int = _http.get_body_size()
	if total <= 0 and _pending != null:
		total = _pending.size_bytes
	var ratio: float = 0.0
	if total > 0:
		ratio = clampf(float(got) / float(total), 0.0, 1.0)
	_dialog.call("show_downloading", ratio)


func _begin_install() -> void:
	_busy = false
	_http.set_download_file("")
	if _dialog != null and _dialog.has_method("show_installing"):
		_dialog.call("show_installing")
	var abs_path := ProjectSettings.globalize_path(DOWNLOAD_PATH)
	var err := AndroidApkInstaller.start_install(abs_path)
	if not err.is_empty():
		push_warning("AutoUpdater: instalador falhou (%s)" % err)
		if _dialog != null and _dialog.has_method("show_install_blocked"):
			_dialog.call("show_install_blocked")


func _notification(what: int) -> void:
	if what != NOTIFICATION_APPLICATION_FOCUS_IN:
		return
	if not _waiting_permission:
		return
	if not AndroidApkInstaller.can_request_installs():
		return
	_waiting_permission = false
	_start_download()


func _is_on_hub() -> bool:
	var scene := get_tree().current_scene
	if scene == null:
		return false
	return scene.scene_file_path == HUB_SCENE


func _show_offer(m: UpdateManifest) -> void:
	_ensure_dialog()
	if _dialog != null and _dialog.has_method("show_offer"):
		_dialog.call("show_offer", m, _local_name)


func _hide_dialog() -> void:
	if _dialog != null and _dialog.has_method("hide_dialog"):
		_dialog.call("hide_dialog")


func _ensure_dialog() -> void:
	if _dialog != null and is_instance_valid(_dialog):
		return
	if not ResourceLoader.exists(DIALOG_SCENE):
		push_error("AutoUpdater: cena do aviso ausente")
		return
	var packed: PackedScene = load(DIALOG_SCENE) as PackedScene
	if packed == null:
		return
	_dialog = packed.instantiate() as CanvasLayer
	if _dialog == null:
		return
	add_child(_dialog)
	_bind_dialog_signal("update_pressed", start_update_from_ui)
	_bind_dialog_signal("later_pressed", snooze)
	_bind_dialog_signal("retry_pressed", retry_update)
	_bind_dialog_signal("play_anyway_pressed", snooze)
	_bind_dialog_signal("permission_pressed", open_install_permission)
	_bind_dialog_signal("cancel_download_pressed", cancel_download)


func _ensure_download_dir() -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	if not dir.dir_exists("updates"):
		dir.make_dir("updates")


func _bind_dialog_signal(sig: String, cb: Callable) -> void:
	if _dialog == null or not _dialog.has_signal(sig):
		return
	if not _dialog.is_connected(sig, cb):
		_dialog.connect(sig, cb)


func _file_size(path: String) -> int:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return 0
	return int(f.get_length())


func _delete_download() -> void:
	if FileAccess.file_exists(DOWNLOAD_PATH):
		DirAccess.remove_absolute(DOWNLOAD_PATH)
