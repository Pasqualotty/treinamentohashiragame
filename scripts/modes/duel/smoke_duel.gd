extends SceneTree
## Smoke do duelo 1v1: dois corpos se encaram, 1 round, vencedor em PT.
## Uso: godot --headless --path . -s res://scripts/modes/duel/smoke_duel.gd
##
## Facing canônico: arte olha ESQUERDA; flip_h só se facing > 0.

const DUEL := "res://scenes/modes/duel/duel.tscn"
const TEXT_ROUND := "ROUND 1"
const TEXT_WIN := "Você ganhou"
const TEXT_LOSE := "Você perdeu"

var _failed: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _fail(msg: String) -> void:
	_failed += 1
	push_error("[smoke] FAIL %s" % msg)
	print("[smoke] FAIL %s" % msg)


func _pass(msg: String) -> void:
	print("[smoke] ok %s" % msg)


func _run() -> void:
	print("=== smoke_duel ===")
	var err := change_scene_to_file(DUEL)
	if err != OK:
		_fail("change_scene_to_file duel.tscn err=%s" % err)
		_finish()
		return
	for _i in 24:
		await process_frame
	var scene := current_scene
	if scene == null or scene.scene_file_path != DUEL:
		_fail("cena atual não é duel.tscn")
		_finish()
		return
	_pass("duel.tscn carregou")

	if not scene.has_method("get_left_fighter"):
		_fail("DuelController sem API get_left_fighter")
		_finish()
		return

	var left: Node = scene.call("get_left_fighter")
	var right: Node = scene.call("get_right_fighter")
	if left == null or right == null:
		_fail("faltou FighterLeft/FighterRight")
		_finish()
		return
	if not (left is CharacterBody2D) or not (right is CharacterBody2D):
		_fail("lutadores não são CharacterBody2D")
		_finish()
		return
	_pass("dois CharacterBody2D")

	var lx: float = (left as Node2D).global_position.x
	var rx: float = (right as Node2D).global_position.x
	if lx >= rx:
		_fail("esquerda x=%.1f não está à esquerda de x=%.1f" % [lx, rx])
	else:
		_pass("posições frente a frente")

	if not left.has_method("get_facing") or not right.has_method("get_facing"):
		_fail("get_facing ausente (não editar player.gd)")
		_finish()
		return
	var lf: float = float(left.call("get_facing"))
	var rf: float = float(right.call("get_facing"))
	if lf <= 0.0:
		_fail("lutador esquerdo facing=%.1f (quer > 0, olhando o rival)" % lf)
	if rf >= 0.0:
		_fail("lutador direito facing=%.1f (quer < 0, olhando o rival)" % rf)

	var ls: AnimatedSprite2D = left.find_child("AnimatedSprite2D", true, false) as AnimatedSprite2D
	var rs: AnimatedSprite2D = right.find_child("AnimatedSprite2D", true, false) as AnimatedSprite2D
	if ls == null or rs == null:
		_fail("AnimatedSprite2D ausente")
	else:
		if ls.flip_h != (lf > 0.0):
			_fail("esquerda flip_h=%s facing=%.1f (canônico: flip_h = facing > 0)" % [str(ls.flip_h), lf])
		if rs.flip_h != (rf > 0.0):
			_fail("direita flip_h=%s facing=%.1f (canônico: flip_h = facing > 0)" % [str(rs.flip_h), rf])
		if rf < 0.0 and rs.flip_h:
			_fail("direita flip_h true com facing<0 — não inverter o canônico")
		else:
			_pass("flip_h canônico (arte esquerda; flip só se facing > 0)")

	var left_id: String = str(left.get("applied_character_id"))
	var right_id: String = str(right.get("applied_character_id"))
	if left_id != "inosuke":
		_fail("esquerda id=%s (Inosuke, 2 lâminas)" % left_id)
	else:
		_pass("esquerda Inosuke")
	if right_id != "nezuko":
		_fail("direita id=%s (Nezuko sem katana; PNG intocado)" % right_id)
	else:
		_pass("direita Nezuko")

	var banner: String = str(scene.call("get_banner_text"))
	if banner != TEXT_ROUND:
		_fail("banner='%s' esperado '%s'" % [banner, TEXT_ROUND])
	else:
		_pass("texto de round em PT/HUD")

	var hit_l: Node = left.get_node_or_null("Hitbox")
	var hurt_r: Node = right.get_node_or_null("Hurtbox")
	if hit_l == null or hurt_r == null:
		_fail("hit/hurtbox ausente")
	elif str(hit_l.get("team")) == str(hurt_r.get("team")):
		_fail("times iguais — golpe não atravessa")
	else:
		_pass("times distintos")

	if not right.has_method("apply_damage"):
		_fail("apply_damage ausente no dummy")
		_finish()
		return
	right.call("apply_damage", 9999, Vector2.ZERO)
	for _j in 20:
		await process_frame
	var result: String = str(scene.call("get_result_text"))
	if result != TEXT_WIN:
		_fail("após KO do dummy result='%s' esperado '%s'" % [result, TEXT_WIN])
	else:
		_pass("vencedor em PT (Você ganhou)")

	var packed: PackedScene = load(DUEL) as PackedScene
	if packed == null:
		_fail("reload packed falhou")
		_finish()
		return
	var inst2: Node = packed.instantiate()
	root.add_child(inst2)
	await process_frame
	await process_frame
	var left2: Node = inst2.call("get_left_fighter")
	if left2 != null and left2.has_method("apply_damage"):
		left2.call("apply_damage", 9999, Vector2.ZERO)
		for _k in 16:
			await process_frame
		var lose: String = str(inst2.call("get_result_text"))
		if lose != TEXT_LOSE:
			_fail("após KO do local result='%s' esperado '%s'" % [lose, TEXT_LOSE])
		else:
			_pass("derrota em PT (Você perdeu)")
	inst2.queue_free()

	_finish()


func _finish() -> void:
	if _failed > 0:
		print("[smoke] FAILED count=%d" % _failed)
		quit(1)
		return
	print("[smoke] ALL PASSED")
	quit(0)
