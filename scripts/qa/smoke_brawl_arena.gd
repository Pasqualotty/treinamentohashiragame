extends SceneTree
## Headless: arena batalha carrega, dois caçadores, PvP, eixo vertical, touch.
## Uso: godot --headless --path . -s res://scripts/qa/smoke_brawl_arena.gd

const ARENA := "res://scenes/modes/brawl/brawl_arena.tscn"

var _failed: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _fail(msg: String) -> void:
	_failed += 1
	push_error("[brawl] FAIL %s" % msg)
	print("  FAIL %s" % msg)


func _ok(msg: String) -> void:
	print("  ok %s" % msg)


func _run() -> void:
	print("=== smoke_brawl_arena ===")
	for action: String in ["move_left", "move_right", "move_up", "move_down", "attack_basic"]:
		if not InputMap.has_action(action):
			_fail("InputMap sem %s" % action)
		else:
			_ok("action %s" % action)

	var packed: PackedScene = load(ARENA) as PackedScene
	if packed == null:
		_fail("não carregou %s" % ARENA)
		_finish()
		return
	var inst: Node = packed.instantiate()
	root.add_child(inst)
	for _i in 24:
		await process_frame

	if inst == null:
		_fail("instância nula")
		_finish()
		return

	var hunters: Array[CharacterBody2D] = []
	if inst.has_method("get_hunters"):
		var raw: Variant = inst.call("get_hunters")
		if raw is Array:
			for n: Variant in raw:
				if n is CharacterBody2D:
					hunters.append(n as CharacterBody2D)
	if hunters.size() < 2:
		_fail("esperava 2 caçadores, veio %d" % hunters.size())
		_finish()
		return
	_ok("dois corpos na arena")

	var p1: CharacterBody2D = hunters[0]
	var p2: CharacterBody2D = hunters[1]
	var id1: String = str(p1.get("applied_character_id"))
	var id2: String = str(p2.get("applied_character_id"))
	if id1 != "inosuke":
		_fail("hunter0 id=%s esperado inosuke" % id1)
	else:
		_ok("Inosuke no slot 0")
	if id2 != "nezuko":
		_fail("hunter1 id=%s esperado nezuko" % id2)
	else:
		_ok("Nezuko no slot 1")

	if p1.motion_mode != CharacterBody2D.MOTION_MODE_FLOATING:
		_fail("p1 não está FLOATING (sobe/desce)")
	else:
		_ok("p1 FLOATING")
	if p2.motion_mode != CharacterBody2D.MOTION_MODE_FLOATING:
		_fail("p2 não está FLOATING")

	var t1: String = ""
	var t2: String = ""
	if inst.has_method("hunter_team"):
		t1 = str(inst.call("hunter_team", 0))
		t2 = str(inst.call("hunter_team", 1))
	if t1 == t2 or t1 == "":
		_fail("times iguais ou vazios t1=%s t2=%s" % [t1, t2])
	else:
		_ok("times PvP %s vs %s" % [t1, t2])

	var st1: PlayerStats = p1.get("stats") as PlayerStats
	if st1 == null or not is_zero_approx(st1.gravity):
		_fail("gravity p1 deveria ser 0 no plano")
	else:
		_ok("gravity 0 no plano")

	var touch: Node = inst.get_node_or_null("CombatTouchControls")
	if touch == null:
		_fail("touch GDD ausente")
	else:
		_ok("touch GDD presente")

	await _check_vertical(inst, p1)
	await _check_pvp_hit(inst, p1, p2)

	_finish()


func _check_vertical(arena: Node, p1: CharacterBody2D) -> void:
	var y0: float = p1.global_position.y
	if arena.has_method("debug_set_vertical"):
		arena.call("debug_set_vertical", 0, 1.0)
	for _i in 10:
		await physics_frame
	var y1: float = p1.global_position.y
	if arena.has_method("debug_set_vertical"):
		arena.call("debug_set_vertical", 0, 0.0)
	if y1 <= y0 + 4.0:
		_fail("eixo vertical não moveu (y %s -> %s)" % [y0, y1])
	else:
		_ok("desceu no plano y %s -> %s" % [y0, y1])


func _check_pvp_hit(arena: Node, p1: CharacterBody2D, p2: CharacterBody2D) -> void:
	if arena.has_method("debug_pause_bot"):
		arena.call("debug_pause_bot")
	p1.global_position = Vector2(560.0, 430.0)
	p2.global_position = Vector2(610.0, 430.0)
	p1.velocity = Vector2.ZERO
	p2.velocity = Vector2.ZERO
	p1.set("accept_local_input", false)
	p1.force_update_transform()
	p2.force_update_transform()
	p1.call("apply_input_frame", 1.0, 0, 0)
	for _i in 3:
		await physics_frame
		p1.global_position.y = 430.0
		p2.global_position.y = 430.0
		p1.velocity.y = 0.0
		p2.velocity.y = 0.0
	var hp_before: int = int(p2.get("hp"))
	p1.call("apply_input_frame", 1.0, 0, InputFrame.BIT_ATK)
	for _j in 24:
		await physics_frame
		p1.velocity.y = 0.0
		p2.velocity.y = 0.0
	var hp_after: int = int(p2.get("hp"))
	if hp_after >= hp_before:
		_fail("PvP não descontou HP (%d -> %d)" % [hp_before, hp_after])
	else:
		_ok("hit no outro caçador %d -> %d" % [hp_before, hp_after])


func _finish() -> void:
	if _failed > 0:
		print("=== BRAWL FAIL === falhas=%d" % _failed)
		quit(1)
		return
	print("=== BRAWL PASS ===")
	quit(0)
