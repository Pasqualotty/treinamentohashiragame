extends SceneTree
## Headless: mapas de fundo w2–w5; w1 não substitui a arte da cena.
##   godot --headless --path . -s res://scripts/qa/smoke_world_backdrop.gd

var _failed: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== smoke_world_backdrop ===")
	_expect("w2_01", "res://assets/backgrounds/w2/stage.png")
	_expect("w5_boss", "res://assets/backgrounds/w5/stage.png")
	_expect("w1_03", "")
	_expect("w3_04", "res://assets/backgrounds/w3/stage.png")
	var w2: String = WorldBackdrop.texture_path_for_stage("w2_01")
	var w4: String = WorldBackdrop.texture_path_for_stage("w4_01")
	if w2 == w4:
		_fail("w2 e w4 devolveram o mesmo caminho: %s" % w2)
	if _failed > 0:
		print("=== WORLD BACKDROP FAIL === falhas=%d" % _failed)
		quit(1)
		return
	print("=== WORLD BACKDROP PASS ===")
	quit(0)


func _expect(stage_id: String, want: String) -> void:
	var got: String = WorldBackdrop.texture_path_for_stage(stage_id)
	if got != want:
		_fail("%s → %s (esperado %s)" % [stage_id, got, want])
	else:
		print("  OK %s → %s" % [stage_id, got if not got.is_empty() else "(vazio)"])


func _fail(msg: String) -> void:
	_failed += 1
	push_error("[world-backdrop] %s" % msg)
	print("  FAIL %s" % msg)
