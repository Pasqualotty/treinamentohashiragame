extends SceneTree
## Smoke: rota de BGM por kind/mundo. Sem tocar áudio.
## Uso: godot --headless --path . -s res://scripts/qa/smoke_bgm_routes.gd

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
	var hub := BgmRoute.resolve("hub", "")
	var boss := BgmRoute.resolve("boss", "w1")
	var stage_w1 := BgmRoute.resolve("stage", "w1")
	var stage_w2 := BgmRoute.resolve("stage", "w2")
	var stage_w3 := BgmRoute.resolve("stage", "w3")
	var stage_w4 := BgmRoute.resolve("stage", "w4")
	var stage_w5 := BgmRoute.resolve("stage", "w5")
	var stage_unknown := BgmRoute.resolve("stage", "wx")

	if boss == hub:
		_fail("boss == hub")
	else:
		_pass("boss != hub")

	if stage_w2 == stage_w5:
		_fail("w2 == w5")
	else:
		_pass("w2 != w5")

	if stage_w3 != "res://assets/audio/bgm/w3_loop.wav":
		_fail("stage w3 não aponta para w3_loop (foi %s)" % stage_w3)
	else:
		_pass("stage w3 → w3_loop.wav")

	if boss.contains("game_theme"):
		_fail("boss aponta para game_theme")
	else:
		_pass("boss não é game_theme")

	if hub != "res://assets/audio/bgm/game_theme.mp3":
		_fail("hub não é game_theme.mp3 (foi %s)" % hub)
	else:
		_pass("hub → game_theme.mp3")

	if boss != "res://assets/audio/bgm/boss_loop.wav":
		_fail("boss não é boss_loop.wav (foi %s)" % boss)
	else:
		_pass("boss → boss_loop.wav")

	if stage_unknown != "res://assets/audio/bgm/stage_loop.wav":
		_fail("mundo desconhecido não caiu em stage_loop (foi %s)" % stage_unknown)
	else:
		_pass("stage desconhecido → stage_loop.wav")

	if stage_w1 == hub or stage_w1 == boss:
		_fail("stage w1 colidiu com hub ou boss")
	if stage_w1 != "res://assets/audio/bgm/w1_loop.wav":
		_fail("stage w1 não aponta para w1_loop (foi %s)" % stage_w1)
	if stage_w4 != "res://assets/audio/bgm/w4_loop.wav":
		_fail("stage w4 não aponta para w4_loop (foi %s)" % stage_w4)
	if stage_w5 != "res://assets/audio/bgm/w5_loop.wav":
		_fail("stage w5 não aponta para w5_loop (foi %s)" % stage_w5)

	var paths: Array[String] = [hub, boss, stage_w1, stage_w2, stage_w3, stage_w4, stage_w5]
	var seen: Dictionary = {}
	for p in paths:
		if seen.has(p):
			_fail("caminho repetido entre hub/boss/mundos: %s" % p)
		else:
			seen[p] = true

	_finish()


func _finish() -> void:
	print("=== smoke_bgm_routes ===")
	for m in _messages:
		print("  - ", m)
	if _ok:
		print("BGM_ROUTES PASS")
		quit(0)
	else:
		print("BGM_ROUTES FAIL")
		quit(1)
