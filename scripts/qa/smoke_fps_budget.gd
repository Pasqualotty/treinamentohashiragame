extends SceneTree
## Smoke do orçamento de fase cheia: teto de FX vivos + tempo de processo.
## Não é FPS de aparelho — é o cap de spawn. Fase densa = w1_05.
## Uso: godot --headless --path . -s res://scripts/qa/smoke_fps_budget.gd

const STAGE := "res://scenes/battle/stage_w1_05.tscn"
const FLOOD := 80
const SAMPLE_FRAMES := 45
## Headless: teto folgado de TIME_PROCESS (não medimos GPU de celular).
## Folga extra depois dos sheets de FX da referência (slash/água/impacto).
const MAX_AVG_PROCESS_SEC := 0.12

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
	_test_cap_math()
	await _test_stage_and_flood()
	_finish()


func _test_cap_math() -> void:
	if FxLiveCap.evict_for_spawn(0, 24) != 0:
		_fail("evict(0) deveria ser 0")
		return
	if FxLiveCap.evict_for_spawn(23, 24) != 0:
		_fail("evict(23) deveria ser 0 (ainda cabe 1)")
		return
	if FxLiveCap.evict_for_spawn(24, 24) != 1:
		_fail("evict(24) deveria ser 1")
		return
	if FxLiveCap.evict_for_spawn(30, 24) != 7:
		_fail("evict(30) deveria ser 7")
		return
	if FxLiveCap.allows_spawn(24, 24):
		_fail("allows_spawn no teto deveria ser false")
		return
	if not FxLiveCap.allows_spawn(0, 24):
		_fail("allows_spawn(0) deveria ser true")
		return
	_pass("FxLiveCap: evict/allows no teto 24")


func _test_stage_and_flood() -> void:
	var fx: Node = root.get_node_or_null("Fx")
	if fx == null:
		_fail("autoload Fx ausente")
		return
	if int(fx.get("MAX_LIVE")) != FxLiveCap.DEFAULT_CAP:
		_fail("Fx.MAX_LIVE=%s esperado %d" % [fx.get("MAX_LIVE"), FxLiveCap.DEFAULT_CAP])
		return

	var err := change_scene_to_file(STAGE)
	if err != OK:
		_fail("não carregou %s (err=%s)" % [STAGE, err])
		return
	for _i in 30:
		await process_frame
	if current_scene == null or current_scene.scene_file_path != STAGE:
		_fail("cena atual não é w1_05")
		return
	_pass("w1_05 carregou")

	fx.call("clear_all")
	await process_frame
	for _j in FLOOD:
		fx.call("spark", Vector2(200, 200), Color.WHITE, 8)
	await process_frame
	var live: int = int(fx.call("get_live_count"))
	var cap: int = int(fx.get("MAX_LIVE"))
	if live > cap:
		_fail("flood %d sparks: live=%d > cap=%d" % [FLOOD, live, cap])
	else:
		_pass("flood %d sparks: live=%d ≤ cap=%d" % [FLOOD, live, cap])

	var acc := 0.0
	for _k in SAMPLE_FRAMES:
		await process_frame
		acc += float(Performance.get_monitor(Performance.TIME_PROCESS))
	var avg: float = acc / float(SAMPLE_FRAMES)
	_messages.append("TIME_PROCESS médio=%.4fs (%d frames, teto=%.3fs)" % [avg, SAMPLE_FRAMES, MAX_AVG_PROCESS_SEC])
	if avg > MAX_AVG_PROCESS_SEC:
		_fail("TIME_PROCESS médio %.4fs > teto %.3fs" % [avg, MAX_AVG_PROCESS_SEC])
	else:
		_pass("budget de processo ok")

	fx.call("clear_all")


func _finish() -> void:
	print("=== smoke_fps_budget ===")
	for m in _messages:
		print("  - ", m)
	if _ok:
		print("FPS_BUDGET PASS")
		quit(0)
	else:
		print("FPS_BUDGET FAIL")
		quit(1)
