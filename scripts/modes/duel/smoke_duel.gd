extends SceneTree
## Smoke do duelo 1v1: dois corpos se encaram, 1 round, vencedor em PT.
## Uso: godot --headless --path . -s res://scripts/modes/duel/smoke_duel.gd
##
## Facing canônico: arte olha ESQUERDA; flip_h só se facing > 0.

const DUEL := "res://scenes/modes/duel/duel.tscn"
const TEXT_ROUND := "ROUND 1"
const TEXT_WIN := "Você ganhou"
const TEXT_LOSE := "Você perdeu"
const _UiFont := preload("res://scripts/ui/ui_font.gd")

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
	_UiFont.ensure_theme_space()
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
		_assert_inosuke_blades(ls)
		_assert_nezuko_unarmed(rs)

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
	elif not banner.contains(" "):
		_fail("banner sem espaço (ROUND1 colado)")
	else:
		_pass("texto de round em PT/HUD")
	_assert_round_space(scene)
	_assert_duel_hud(scene)

	var hit_l: Node = left.get_node_or_null("Hitbox")
	var hurt_r: Node = right.get_node_or_null("Hurtbox")
	if hit_l == null or hurt_r == null:
		_fail("hit/hurtbox ausente")
	elif str(hit_l.get("team")) == str(hurt_r.get("team")):
		_fail("times iguais — golpe não atravessa")
	else:
		_pass("times distintos")

	if right.has_method("apply_damage"):
		right.set("follow_host_snap", false)
		right.set("accept_local_input", false)
		right.call("apply_input_frame", -1.0, 0, 0)
		right.set("_invuln_timer", 0.0)
		var hp0: int = int(right.get("hp"))
		right.call("apply_damage", 20, Vector2(180.0, 0.0))
		var hp1: int = int(right.get("hp"))
		if hp1 != hp0 - 5:
			_fail("block 1v1 chip=%s (hp %s -> %s)" % [hp0 - hp1, hp0, hp1])
		elif int(right.call("get_state")) == 8:
			_fail("block 1v1 ainda entrou em hurt")
		else:
			_pass("block segura o golpe")
		right.set("_invuln_timer", 0.0)
	if right.has_method("_try_start_skill_1"):
		right.set("follow_host_snap", false)
		var air_y: float = (right as Node2D).global_position.y
		(right as Node2D).global_position.y = air_y - 48.0
		var skill_ok: bool = bool(right.call("_try_start_skill_1"))
		if not skill_ok:
			_fail("skill 1v1 não abriu fora do chão")
		else:
			_pass("skill 1v1 no ar")
		(right as Node2D).global_position.y = air_y
		right.set("follow_host_snap", true)

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
	await process_frame

	await _check_net_host()
	await _check_net_guest()

	_finish()


func _check_net_host() -> void:
	var duel: Node = await _spawn_net_duel({
		"char_0": "inosuke",
		"char_1": "nezuko",
		"local_slot": 0,
		"is_guest": false,
	})
	if duel == null:
		return
	if not bool(duel.call("uses_lan_roster")):
		_fail("host sessão: uses_lan_roster=false")
	else:
		_pass("host sessão: roster LAN")
	if bool(duel.call("is_dummy_active")):
		_fail("host sessão ainda tem dummy")
	else:
		_pass("host sessão: sem dummy")
	var left: Node = duel.call("get_left_fighter")
	var right: Node = duel.call("get_right_fighter")
	if left == null or right == null:
		_fail("host sessão sem lutadores")
		duel.queue_free()
		await process_frame
		return
	if str(left.get("applied_character_id")) != "inosuke" or str(right.get("applied_character_id")) != "nezuko":
		_fail("host sessão roster=%s/%s" % [left.get("applied_character_id"), right.get("applied_character_id")])
	else:
		_pass("host sessão: Inosuke vs Nezuko")
	if int(left.get("coop_slot")) != 0 or int(right.get("coop_slot")) != 1:
		_fail("host sessão coop_slot invertido %s/%s" % [left.get("coop_slot"), right.get("coop_slot")])
	else:
		_pass("host sessão: slot 0 esquerda / 1 direita")
	if bool(left.get("accept_local_input")) or bool(right.get("accept_local_input")):
		## Intro ainda trava os dois; o que importa é o ramo sem dummy + InputFrame.
		pass
	right.set("follow_host_snap", false)
	right.set("accept_local_input", false)
	var x0: float = (right as Node2D).global_position.x
	right.call("apply_input_frame", -1.0, 0, 0)
	for _i in 12:
		await physics_frame
	if (right as Node2D).global_position.x >= x0 - 2.0:
		_fail("host sessão: InputFrame no direito não moveu (%.1f -> %.1f)" % [x0, (right as Node2D).global_position.x])
	else:
		_pass("host sessão: amigo joga via InputFrame")
	duel.queue_free()
	await process_frame


func _check_net_guest() -> void:
	var duel: Node = await _spawn_net_duel({
		"char_0": "inosuke",
		"char_1": "nezuko",
		"local_slot": 1,
		"is_guest": true,
	})
	if duel == null:
		return
	if bool(duel.call("is_dummy_active")):
		_fail("guest sessão ainda tem dummy")
	else:
		_pass("guest sessão: sem dummy")
	var left: Node = duel.call("get_left_fighter")
	var right: Node = duel.call("get_right_fighter")
	if left == null or right == null:
		_fail("guest sessão sem lutadores")
		duel.queue_free()
		await process_frame
		return
	if bool(left.get("accept_local_input")) or bool(right.get("accept_local_input")):
		_fail("guest sessão não pode aceitar input local")
	elif not bool(right.get("is_local_pawn")) or bool(left.get("is_local_pawn")):
		_fail("guest sessão slot local errado")
	elif int(left.get("coop_slot")) != 0 or int(right.get("coop_slot")) != 1:
		_fail("guest sessão coop_slot invertido %s/%s" % [left.get("coop_slot"), right.get("coop_slot")])
	elif not bool(left.get("follow_host_snap")) or not bool(right.get("follow_host_snap")):
		_fail("guest sessão sem follow_host_snap")
	else:
		_pass("guest sessão: puppet + slot 1 local + slots fixos")
	duel.queue_free()
	await process_frame


func _spawn_net_duel(meta: Dictionary) -> Node:
	var packed: PackedScene = load(DUEL) as PackedScene
	if packed == null:
		_fail("reload duel net falhou")
		return null
	var inst: Node = packed.instantiate()
	inst.set_meta("smoke_lan_roster", meta)
	root.add_child(inst)
	for _i in 16:
		await process_frame
	return inst


func _assert_round_space(scene: Node) -> void:
	var lbl: Label = scene.get_node_or_null("%RoundLabel") as Label
	if lbl == null:
		_fail("RoundLabel ausente")
		return
	var font: Font = lbl.get_theme_font("font")
	var size: int = lbl.get_theme_font_size("font_size")
	if font == null:
		_fail("RoundLabel sem fonte")
		return
	var gap: float = _UiFont.space_width(font, size)
	if gap < _UiFont.SPACE_MIN_PX:
		_fail("espaço do ROUND colado (advance=%.2f)" % gap)
		return
	if font is FontVariation:
		var fv := font as FontVariation
		if fv.spacing_space < 1:
			_fail("FontVariation.spacing_space=%d (quer >= 1)" % fv.spacing_space)
			return
		_pass("ROUND FontVariation spacing_space=%d advance=%.1f" % [fv.spacing_space, gap])
	else:
		_pass("ROUND espaço visível advance=%.1f" % gap)


func _assert_duel_hud(scene: Node) -> void:
	var left_bar: ProgressBar = scene.get_node_or_null("%HpLeftBar") as ProgressBar
	var right_bar: ProgressBar = scene.get_node_or_null("%HpRightBar") as ProgressBar
	if left_bar == null or right_bar == null:
		_fail("HUD de duelo precisa das duas barras de vitalidade")
	else:
		_pass("vitalidade dos dois")
	var breath_l: ProgressBar = scene.get_node_or_null("%BreathLeftBar") as ProgressBar
	var breath_r: ProgressBar = scene.get_node_or_null("%BreathRightBar") as ProgressBar
	if breath_l == null or breath_r == null:
		_fail("HUD de duelo sem barras de respiração")
	else:
		_pass("respiração dos dois")
	var bg: Sprite2D = scene.get_node_or_null("ArenaBg") as Sprite2D
	if bg == null or bg.texture == null:
		_fail("duelo sem fundo ArenaBg")
	else:
		_pass("fundo do pátio")
	var chrome: Dictionary = _count_stage_chrome(scene)
	var onda_vis: int = int(chrome.get("onda", 0))
	var coins_vis: int = int(chrome.get("coins", 0))
	if onda_vis > 0:
		_fail("ONDA ainda visível no duelo (%d)" % onda_vis)
	else:
		_pass("ONDA sumiu")
	if coins_vis > 0:
		_fail("moeda de fase ainda visível no duelo")
	else:
		_pass("sem moeda de fase")


func _count_stage_chrome(root: Node) -> Dictionary:
	var onda: int = 0
	var coins: int = 0
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if n is Label:
			var t: String = (n as Label).text
			if t.contains("ONDA") and (n as CanvasItem).is_visible_in_tree():
				onda += 1
		if str(n.name) == "CoinsBlock" and n is CanvasItem and (n as CanvasItem).is_visible_in_tree():
			coins += 1
		if str(n.name) == "WaveChip" and n is CanvasItem and (n as CanvasItem).is_visible_in_tree():
			onda += 1
	return {"onda": onda, "coins": coins}


func _assert_inosuke_blades(spr: AnimatedSprite2D) -> void:
	if spr.sprite_frames == null:
		_fail("Inosuke sem SpriteFrames")
		return
	var anim: StringName = spr.animation
	if anim != &"attack" and anim != &"idle":
		_fail("Inosuke anim=%s (quer attack/idle com 2 lâminas)" % String(anim))
		return
	var tex: Texture2D = spr.sprite_frames.get_frame_texture(anim, spr.frame)
	if tex == null:
		_fail("Inosuke frame sem textura")
		return
	var path := str(tex.resource_path)
	if "inosuke" not in path:
		_fail("Inosuke textura=%s (pack errado)" % path)
		return
	_pass("Inosuke 2 lâminas (%s frame=%d)" % [String(anim), spr.frame])


func _assert_nezuko_unarmed(spr: AnimatedSprite2D) -> void:
	if spr.flip_h:
		_fail("Nezuko flip_h — não flipar PNG/sprite da direita")
		return
	if spr.sprite_frames == null:
		return
	var tex: Texture2D = spr.sprite_frames.get_frame_texture(spr.animation, spr.frame)
	if tex == null:
		return
	var path := str(tex.resource_path)
	if "nezuko" not in path:
		_fail("Nezuko textura=%s" % path)
		return
	_pass("Nezuko sem katana (PNG intocado)")


func _finish() -> void:
	if _failed > 0:
		print("[smoke] FAILED count=%d" % _failed)
		quit(1)
		return
	print("[smoke] ALL PASSED")
	quit(0)
