extends SceneTree
## Hitstop refresh + reset de time_scale + KnockCarry puro.
## Uso: godot --headless --path . -s res://scripts/qa/smoke_combat_feel.gd

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
	_test_knock_carry()
	await _test_hitstop()
	_finish()


func _test_knock_carry() -> void:
	if not KnockCarry.holds(0.22):
		_fail("KnockCarry.holds(0.22) deveria ser true")
		return
	if KnockCarry.holds(0.0) or KnockCarry.holds(-0.05):
		_fail("KnockCarry.holds(0) deveria ser false")
		return
	var fric: float = KnockCarry.apply_friction(200.0, 900.0, 0.1)
	if fric >= 200.0 or fric <= 0.0:
		_fail("apply_friction deveria reduzir sem zerar de uma vez (got %s)" % fric)
		return
	_pass("KnockCarry holds/friction")


func _test_hitstop() -> void:
	var cf: Node = root.get_node_or_null("CombatFeel")
	if cf == null:
		for c in root.get_children():
			if c.name == "CombatFeel":
				cf = c
				break
	if cf == null:
		_fail("autoload CombatFeel ausente")
		return
	if not cf.has_method("hit_impact_typed") or not cf.has_method("reset_time_scale"):
		_fail("API hit_impact_typed/reset_time_scale ausente")
		return
	_pass("API pública viva")

	cf.call("reset_time_scale")
	if Engine.time_scale < 0.99:
		_fail("reset_time_scale não devolveu 1 (got %s)" % Engine.time_scale)
		return

	cf.call("hitstop", 0.05)
	await create_timer(0.12, true, true).timeout
	if Engine.time_scale < 0.99:
		_fail("após hitstop(0.05) time_scale preso em %s" % Engine.time_scale)
		return
	_pass("hitstop(0.05) volta a 1")

	# Refresh: segundo stop durante busy não deixa scale preso.
	cf.call("hitstop", 0.08)
	await create_timer(0.02, true, true).timeout
	cf.call("hitstop", 0.05)
	await create_timer(0.14, true, true).timeout
	if Engine.time_scale < 0.99:
		_fail("refresh deixou time_scale em %s" % Engine.time_scale)
		return
	_pass("refresh não prende time_scale")

	cf.call("hit_impact_typed", &"basic", 1.0)
	await create_timer(0.14, true, true).timeout
	cf.call("reset_time_scale")
	if Engine.time_scale < 0.99:
		_fail("reset após hit_impact_typed falhou (got %s)" % Engine.time_scale)
		return
	_pass("hit_impact_typed + reset_time_scale")


func _finish() -> void:
	print("=== smoke_combat_feel ===")
	for m in _messages:
		print("  - ", m)
	if _ok:
		print("=== COMBAT_FEEL PASS ===")
		quit(0)
	else:
		print("=== COMBAT_FEEL FAIL ===")
		quit(1)
