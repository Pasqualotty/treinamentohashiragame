extends SceneTree
## Smoke: splash → hub → mapa → fase → hub, 20 vezes, sem erro / leak óbvio.
## NUNCA escreve em user://save.json.
## Uso: godot --headless --path . -s res://scripts/qa/smoke_scene_switch.gd

const SPLASH := "res://scenes/boot/splash_studio.tscn"
const HUB := "res://scenes/main_menu/hub.tscn"
const WORLD_MAP := "res://scenes/world/world_map.tscn"
const STAGE := "res://scenes/battle/stage_w1_01.tscn"
const TEMP_SAVE := "user://smoke_scene_switch_save.json"
const CYCLES := 20
const LAND_TIMEOUT := 8.0
const POLL := 0.05
## Folga de nós entre o 1º e o 20º ciclo (queue_free atrasado + autoloads).
const MAX_NODE_GROWTH := 80

var _ok: bool = true
var _messages: Array[String] = []
var _game: Node = null
var _temp_active: bool = false
var _orig_name: String = ""


func _initialize() -> void:
	call_deferred("_run")


func _fail(msg: String) -> void:
	_ok = false
	_messages.append("FAIL: " + msg)


func _pass(msg: String) -> void:
	_messages.append("ok: " + msg)


func _run() -> void:
	_game = root.get_node_or_null("Game")
	var router: Node = root.get_node_or_null("SceneRouter")
	if _game == null or router == null:
		_fail("autoload Game/SceneRouter ausente")
		_finish()
		return

	_use_temp_save()
	if not bool(_game.call("set_player_name", "Inosuke")):
		_fail("set_player_name recusou")
		_finish()
		return

	var fx: Node = root.get_node_or_null("Fx")
	var baseline: int = -1

	for i in CYCLES:
		if fx != null and fx.has_method("clear_all"):
			fx.call("clear_all")
		if not await _step(router, SPLASH, "splash"):
			_fail("ciclo %d: splash" % (i + 1))
			_finish()
			return
		if not await _step(router, HUB, "hub"):
			_fail("ciclo %d: hub (após splash)" % (i + 1))
			_finish()
			return
		if not await _step(router, WORLD_MAP, "mapa"):
			_fail("ciclo %d: mapa" % (i + 1))
			_finish()
			return
		_game.set("pending_stage_id", "w1_01")
		if not await _step(router, STAGE, "fase"):
			_fail("ciclo %d: fase" % (i + 1))
			_finish()
			return
		if not await _step(router, HUB, "hub"):
			_fail("ciclo %d: hub (após fase)" % (i + 1))
			_finish()
			return
		for _f in 4:
			await process_frame
		var now: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
		if baseline < 0:
			baseline = now
		elif now - baseline > MAX_NODE_GROWTH:
			_fail("ciclo %d: leak OBJECT_COUNT %d → %d (teto +%d)" % [i + 1, baseline, now, MAX_NODE_GROWTH])
			_finish()
			return

	_pass("%d ciclos splash→hub→mapa→fase→hub" % CYCLES)
	_pass("OBJECT_COUNT estável (baseline=%d, teto +%d)" % [baseline, MAX_NODE_GROWTH])
	_finish()


func _step(router: Node, path: String, _label: String) -> bool:
	if not bool(router.call("go_to", path)):
		var waited_busy: float = 0.0
		while waited_busy < LAND_TIMEOUT and bool(router.call("is_navigating")):
			await create_timer(POLL).timeout
			waited_busy += POLL
		if not bool(router.call("go_to", path)):
			return false
	var waited: float = 0.0
	while waited < LAND_TIMEOUT:
		await create_timer(POLL).timeout
		waited += POLL
		if bool(router.call("is_navigating")):
			continue
		if current_scene != null and current_scene.scene_file_path == path:
			return true
	return false


func _use_temp_save() -> void:
	_orig_name = str(_game.get("player_name"))
	_game.call("set_save_path", TEMP_SAVE)
	_temp_active = true
	if FileAccess.file_exists(TEMP_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_SAVE))
	AtomicJson.remove_sidecars(TEMP_SAVE)


func _restore() -> void:
	if not _temp_active:
		return
	_temp_active = false
	if FileAccess.file_exists(TEMP_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_SAVE))
	AtomicJson.remove_sidecars(TEMP_SAVE)
	if _game == null:
		return
	_game.call("set_save_path", "")
	_game.set("player_name", _orig_name)
	_game.call("load_game")


func _finish() -> void:
	_restore()
	print("=== smoke_scene_switch ===")
	for m in _messages:
		print("  - ", m)
	if _ok:
		print("SCENE_SWITCH PASS")
		quit(0)
	else:
		print("SCENE_SWITCH FAIL")
		quit(1)
