extends SceneTree
## Headless: catálogo W1–W5 + world_map + invariantes de progressão.
##
## PRINCÍPIO: este smoke NÃO reimplementa unlock. Aperta o Button de verdade
## (fase e aba de mundo) e observa pending_stage_id / current_world_id / status.
##
## Uso: godot --headless --path . -s res://scripts/qa/smoke_load_stages.gd

const MAP_SCENE: String = "res://scenes/world/world_map.tscn"
const WAVE_SCRIPT: String = "res://scripts/battle/wave_director.gd"
const W1_IDS: PackedStringArray = [
	"w1_01", "w1_02", "w1_03", "w1_04", "w1_05", "w1_boss",
]
const WORLD_EXPECTED := {
	"w1": ["w1_01", "w1_02", "w1_03", "w1_04", "w1_05", "w1_boss"],
	"w2": ["w2_01", "w2_02", "w2_03", "w2_boss"],
	"w3": ["w3_01", "w3_02", "w3_03", "w3_04", "w3_boss"],
	"w4": ["w4_01", "w4_02", "w4_03", "w4_04", "w4_boss"],
	"w5": ["w5_01", "w5_02", "w5_03", "w5_boss"],
}

const BLOCKED_STATES: PackedStringArray = ["locked", "boss_locked"]

var _failed: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _fail(msg: String) -> void:
	push_error("[smoke] FAIL %s" % msg)
	print("[smoke] FAIL %s" % msg)
	_failed += 1


func _run() -> void:
	var game0: Node = root.get_node_or_null("Game")
	if game0 != null and game0.has_method("set_save_path"):
		game0.call("set_save_path", "user://smoke_load_stages.json")
	_check_world_unlock_helper()
	_check_catalog_worlds()
	var all_defs: Array[StageDef] = WorldCatalog.load_all_stages()
	await _check_stage_scenes(all_defs)
	_check_waves(all_defs)
	await _check_world_map_w1()
	await _check_world_selector()
	await _check_progression_w1()
	_check_no_dead_end_all_worlds()

	print("[smoke] IDs W1 intactos: %s" % ", ".join(W1_IDS))
	if _failed > 0:
		print("[smoke] FAILED count=%d" % _failed)
		quit(1)
		return
	print("[smoke] ALL PASSED")
	quit(0)


func _empty_cleared() -> Array[String]:
	var out: Array[String] = []
	return out


func _ids(raw: Array) -> Array[String]:
	var out: Array[String] = []
	for v: Variant in raw:
		out.append(str(v))
	return out


func _check_world_unlock_helper() -> void:
	var none: Array[String] = _empty_cleared()
	if WorldUnlock.known_ids().size() != 5:
		_fail("WorldUnlock.known_ids esperava 5, veio %d" % WorldUnlock.known_ids().size())
	if WorldUnlock.is_unlocked("w1", none) != true:
		_fail("w1 deve estar aberto no save novo")
	if WorldUnlock.is_unlocked("w2", none):
		_fail("w2 não pode abrir sem w1_boss")
	if WorldUnlock.is_unlocked("nope", none):
		_fail("mundo desconhecido não pode abrir")
	if WorldUnlock.required_cleared("nope") != "*":
		_fail("mundo desconhecido deve exigir sentinela fail-closed")
	if WorldUnlock.required_cleared("w1") != "":
		_fail("w1 não exige fase")
	if WorldUnlock.required_cleared("w2") != "w1_boss":
		_fail("w2 exige w1_boss")
	if WorldUnlock.required_cleared("w3") != "w2_boss":
		_fail("w3 exige w2_boss")
	if WorldUnlock.required_cleared("w4") != "w3_boss":
		_fail("w4 exige w3_boss")
	if WorldUnlock.required_cleared("w5") != "w4_boss":
		_fail("w5 exige w4_boss")
	if WorldUnlock.boss_id("w2") != "w2_boss":
		_fail("boss_id w2")
	if WorldUnlock.boss_id("nope") != "":
		_fail("boss_id desconhecido deve ser vazio")
	if WorldUnlock.next_world_id("w1") != "w2":
		_fail("next_world w1→w2")
	if WorldUnlock.next_world_id("w5") != "":
		_fail("w5 não tem próximo mundo")
	if WorldUnlock.next_world_id("nope") != "":
		_fail("next_world desconhecido vazio")
	var with_w1: Array[String] = _ids(["w1_boss"])
	if not WorldUnlock.is_unlocked("w2", with_w1):
		_fail("w2 abre com w1_boss")
	if WorldUnlock.is_unlocked("w3", with_w1):
		_fail("w3 não abre só com w1_boss")
	if WorldUnlock.clamp_world_id("w5", none) != "w1":
		_fail("clamp save novo → w1")
	if WorldUnlock.clamp_world_id("w2", with_w1) != "w2":
		_fail("clamp w2 aberto permanece")
	if WorldUnlock.clamp_world_id("w4", with_w1) != "w2":
		_fail("clamp w4 trancado cai no último aberto (w2)")
	if not WorldUnlock.is_known("w1"):
		_fail("w1 is_known")
	if WorldUnlock.is_known("wx"):
		_fail("wx não é known")
	print("[smoke] OK WorldUnlock helper")


func _check_catalog_worlds() -> void:
	var wids: PackedStringArray = WorldCatalog.world_ids()
	if wids.size() != 5:
		_fail("catálogo com %d mundos, esperado 5" % wids.size())
		return
	for i in range(wids.size()):
		if wids[i] != WorldUnlock.known_ids()[i]:
			_fail("ordem de mundos: %s vs %s" % [wids[i], WorldUnlock.known_ids()[i]])
	for wid: String in WORLD_EXPECTED.keys():
		var want: Array = WORLD_EXPECTED[wid]
		var defs: Array[StageDef] = WorldCatalog.load_stages(wid)
		if defs.size() != want.size():
			_fail("%s com %d fases, esperado %d" % [wid, defs.size(), want.size()])
			continue
		var bosses: int = 0
		for i in range(defs.size()):
			var def: StageDef = defs[i]
			if def.stage_id != str(want[i]):
				_fail("%s ordem: índice %d = %s (esperado %s)" % [wid, i, def.stage_id, want[i]])
			if def.map_label == "":
				_fail("%s sem map_label" % def.stage_id)
			if def.map_position == Vector2.ZERO:
				_fail("%s sem map_position" % def.stage_id)
			if def.is_boss:
				bosses += 1
			print("[smoke] OK StageDef %s label=%s pos=%s boss=%s" % [
				def.stage_id, def.map_label, def.map_position, def.is_boss,
			])
		if bosses != 1:
			_fail("%s esperava 1 boss, achei %d" % [wid, bosses])
	var w1: PackedStringArray = WorldCatalog.stage_ids("w1")
	if w1 != W1_IDS:
		_fail("W1 ids reescritos: %s" % ", ".join(w1))
	print("[smoke] OK 5 mundos no catálogo")


func _check_stage_scenes(defs: Array[StageDef]) -> void:
	for def: StageDef in defs:
		if def.scene_path == "" or not ResourceLoader.exists(def.scene_path):
			_fail("cena ausente para %s: %s" % [def.stage_id, def.scene_path])
			continue
		var packed := load(def.scene_path) as PackedScene
		if packed == null:
			_fail("load: %s" % def.scene_path)
			continue
		var node: Node = packed.instantiate()
		if node == null:
			_fail("instantiate: %s" % def.scene_path)
			continue
		root.add_child(node)
		await process_frame
		var sid: String = str(node.get("stage_id"))
		if sid != def.stage_id:
			_fail("%s tem stage_id=%s na cena %s" % [def.stage_id, sid, def.scene_path])
		elif node.find_child("Goal", true, false) == null:
			_fail("%s sem nó Goal" % def.stage_id)
		else:
			print("[smoke] OK cena %s (%s)" % [def.stage_id, def.scene_path])
		node.queue_free()
		await process_frame


func _check_waves(defs: Array[StageDef]) -> void:
	var script := load(WAVE_SCRIPT) as GDScript
	if script == null:
		_fail("não carregou %s" % WAVE_SCRIPT)
		return
	var consts: Dictionary = script.get_script_constant_map()
	var kinds: PackedStringArray = consts.get("KINDS", PackedStringArray())
	if kinds.is_empty():
		_fail("wave_director sem const KINDS — não dá pra validar os tipos de oni")
		return

	var wd := Node.new()
	wd.set_script(script)

	print("[smoke] canário de ondas: o erro de 'fase sem ondas' a seguir é esperado")
	var canary: Array = wd.call("_waves_for_stage", "__fase_inexistente__")
	if not canary.is_empty():
		_fail("_waves_for_stage tem default genérico: id inexistente devolveu %d ondas" % canary.size())
	else:
		print("[smoke] OK sem default silencioso em _waves_for_stage")

	for def: StageDef in defs:
		var waves: Array = wd.call("_waves_for_stage", def.stage_id)
		if waves.is_empty():
			_fail("%s sem ondas em _waves_for_stage()" % def.stage_id)
			continue
		var total_onis: int = 0
		var bad: bool = false
		var last_kind: String = ""
		for wi in range(waves.size()):
			var pack: Array = waves[wi] as Array
			if pack.is_empty():
				_fail("%s onda %d vazia" % [def.stage_id, wi + 1])
				bad = true
				continue
			for kind_v: Variant in pack:
				var kind: String = str(kind_v)
				last_kind = kind
				if not kinds.has(kind):
					_fail("%s onda %d: tipo de oni desconhecido '%s'" % [def.stage_id, wi + 1, kind])
					bad = true
				total_onis += 1
		if def.is_boss and last_kind != "boss" and not last_kind.begins_with("boss_"):
			_fail("%s boss deve fechar com kind boss* (veio '%s')" % [def.stage_id, last_kind])
			bad = true
		if not bad:
			print("[smoke] OK ondas %s: %d ondas, %d onis last=%s" % [
				def.stage_id, waves.size(), total_onis, last_kind,
			])
	wd.free()


func _check_world_map_w1() -> void:
	var game: Node = root.get_node_or_null("Game")
	if game:
		game.set("current_world_id", "w1")
	var packed := load(MAP_SCENE) as PackedScene
	if packed == null:
		_fail("load: %s" % MAP_SCENE)
		return
	var map: Node = packed.instantiate()
	if map == null:
		_fail("instantiate: %s" % MAP_SCENE)
		return
	root.add_child(map)
	await process_frame

	var buttons: Array[Button] = _stage_buttons_of(map)
	if buttons.size() != W1_IDS.size():
		_fail("world_map criou %d nós para %d fases do W1" % [buttons.size(), W1_IDS.size()])
	else:
		print("[smoke] OK world_map W1 com %d nós de fase" % buttons.size())
	map.queue_free()
	await process_frame


func _stage_buttons_of(map: Node) -> Array[Button]:
	var out: Array[Button] = []
	var canvas: Node = map.find_child("MapCanvas", true, false)
	if canvas == null:
		return out
	for child: Node in canvas.get_children():
		if child is Button:
			out.append(child as Button)
	return out


func _check_world_selector() -> void:
	var game: Node = root.get_node_or_null("Game")
	if game == null:
		_fail("autoload Game ausente")
		return
	var previous: Array = (game.get("stages_cleared") as Array).duplicate()
	var previous_pending: String = str(game.get("pending_stage_id"))
	var previous_world: String = str(game.get("current_world_id"))

	game.set("stages_cleared", _empty_cleared())
	game.set("current_world_id", "w1")
	game.set("pending_stage_id", "")

	var map: Node = await _mount_map()
	if map == null:
		game.set("stages_cleared", previous)
		game.set("pending_stage_id", previous_pending)
		game.set("current_world_id", previous_world)
		return
	for wid: String in WorldCatalog.world_ids():
		var tab: Node = map.find_child("WorldTab_%s" % wid, true, false)
		if tab == null or not (tab is Button):
			_fail("aba de mundo ausente: WorldTab_%s" % wid)
	var tab_w2 := map.find_child("WorldTab_w2", true, false) as Button
	if tab_w2:
		tab_w2.pressed.emit()
		await process_frame
		var status := map.find_child("StatusLabel", true, false) as Label
		var st: String = status.text if status else ""
		if str(game.get("current_world_id")) != "w1":
			_fail("aba w2 trancada mudou current_world_id para %s" % game.get("current_world_id"))
		if not st.contains("conclua"):
			_fail("aba w2 trancada não explicou o bloqueio ('%s')" % st)
		if _stage_buttons_of(map).size() != W1_IDS.size():
			_fail("aba w2 trancada não deveria trocar os nós do W1")
		else:
			print("[smoke] OK aba w2 trancada recusou o toque")
	map.queue_free()
	await process_frame

	game.set("stages_cleared", _ids(["w1_boss"]))
	game.set("current_world_id", "w1")
	map = await _mount_map()
	if map == null:
		game.set("stages_cleared", previous)
		game.set("pending_stage_id", previous_pending)
		game.set("current_world_id", previous_world)
		return
	tab_w2 = map.find_child("WorldTab_w2", true, false) as Button
	if tab_w2 == null:
		_fail("WorldTab_w2 ausente após w1_boss")
	else:
		tab_w2.pressed.emit()
		await process_frame
		if str(game.get("current_world_id")) != "w2":
			_fail("aba w2 aberta não trocou o mundo (current=%s)" % game.get("current_world_id"))
		var n: int = _stage_buttons_of(map).size()
		if n != 4:
			_fail("mapa W2 deveria ter 4 nós, veio %d" % n)
		else:
			print("[smoke] OK seletor trocou para W2 com 4 nós")
	map.queue_free()
	await process_frame

	game.set("stages_cleared", previous)
	game.set("pending_stage_id", previous_pending)
	game.set("current_world_id", previous_world)


func _mount_map() -> Node:
	var packed := load(MAP_SCENE) as PackedScene
	if packed == null:
		_fail("load: %s" % MAP_SCENE)
		return null
	var map: Node = packed.instantiate()
	if map == null:
		_fail("instantiate: %s" % MAP_SCENE)
		return null
	root.add_child(map)
	await process_frame
	return map


func _check_progression_w1() -> void:
	var game: Node = root.get_node_or_null("Game")
	if game == null:
		_fail("autoload Game ausente")
		return
	var previous: Array = (game.get("stages_cleared") as Array).duplicate()
	var previous_pending: String = str(game.get("pending_stage_id"))
	var previous_world: String = str(game.get("current_world_id"))
	game.set("current_world_id", "w1")
	var defs: Array[StageDef] = WorldCatalog.load_stages("w1")

	await _expect_case(game, defs, "save novo", [], [
		"available", "locked", "locked", "locked", "locked", "boss_locked",
	])
	await _expect_case(game, defs, "save legado (01-03)", ["w1_01", "w1_02", "w1_03"], [
		"cleared", "cleared", "cleared", "available", "locked", "boss_locked",
	])
	await _expect_case(game, defs, "save legado (01-03 + boss)", ["w1_01", "w1_02", "w1_03", "w1_boss"], [
		"cleared", "cleared", "cleared", "available", "locked", "cleared",
	])
	await _expect_case(game, defs, "tudo limpo", [
		"w1_01", "w1_02", "w1_03", "w1_04", "w1_05", "w1_boss",
	], ["cleared", "cleared", "cleared", "cleared", "cleared", "cleared"])

	game.set("stages_cleared", previous)
	game.set("pending_stage_id", previous_pending)
	game.set("current_world_id", previous_world)


func _expect_case(game: Node, defs: Array[StageDef], case_name: String,
		cleared: Array, expected: Array) -> void:
	var typed: Array[String] = _ids(cleared)
	game.set("stages_cleared", typed)
	game.set("current_world_id", "w1")

	for i in range(defs.size()):
		var want: String = str(expected[i])
		var probe: Dictionary = await _probe_node(game, i)
		if not bool(probe.get("ok", false)):
			_fail("%s: não consegui sondar o nó %d" % [case_name, i])
			continue

		var got: String = str(probe.get("state", ""))
		if got != want:
			_fail("%s: %s está '%s', esperado '%s'" % [case_name, defs[i].stage_id, got, want])
		if bool(probe.get("disabled", true)):
			_fail("%s: botão de %s está disabled — 'pressed' nunca dispara e o toque fica sem resposta" % [
				case_name, defs[i].stage_id,
			])

		var pending: String = str(probe.get("pending", ""))
		var status: String = str(probe.get("status", ""))
		var refused: bool = status.contains("conclua")
		if BLOCKED_STATES.has(want):
			if pending != "":
				_fail("%s: %s é '%s' mas o toque liberou a entrada (pending=%s)" % [
					case_name, defs[i].stage_id, want, pending,
				])
			if not refused:
				_fail("%s: %s bloqueada mas o status não explicou ('%s')" % [
					case_name, defs[i].stage_id, status,
				])
		else:
			if pending != defs[i].stage_id:
				_fail("%s: %s aparece como '%s' mas o toque NÃO entrou (pending='%s', status='%s')" % [
					case_name, defs[i].stage_id, want, pending, status,
				])
			if refused:
				_fail("%s: %s aparece como '%s' e mesmo assim recusou o toque ('%s')" % [
					case_name, defs[i].stage_id, want, status,
				])

	var next: StageDef = WorldCatalog.next_playable(typed, "w1")
	var next_id: String = next.stage_id if next != null else "-"
	print("[smoke] OK progressão '%s' → próxima jogável: %s" % [case_name, next_id])


func _probe_node(game: Node, index: int) -> Dictionary:
	var out: Dictionary = {"ok": false}
	var packed := load(MAP_SCENE) as PackedScene
	if packed == null:
		return out
	var map: Node = packed.instantiate()
	if map == null:
		return out
	root.add_child(map)
	await process_frame

	var buttons: Array[Button] = _stage_buttons_of(map)
	var status := map.find_child("StatusLabel", true, false) as Label
	if status == null or index >= buttons.size():
		map.queue_free()
		await process_frame
		return out

	var btn: Button = buttons[index]
	out["disabled"] = btn.disabled
	out["state"] = str(map.call("_node_state", index))

	game.set("pending_stage_id", "")
	btn.pressed.emit()
	await process_frame
	out["status"] = status.text
	out["pending"] = str(game.get("pending_stage_id"))
	out["ok"] = true

	map.queue_free()
	await process_frame
	return out


func _check_no_dead_end_all_worlds() -> void:
	var cleared: Array[String] = _empty_cleared()
	var order := PackedStringArray()
	for wid: String in WorldCatalog.world_ids():
		if not WorldUnlock.is_unlocked(wid, cleared):
			_fail("mundo %s trancado no encadeamento global após %s" % [wid, ", ".join(order)])
			return
		var defs: Array[StageDef] = WorldCatalog.load_stages(wid)
		var local := PackedStringArray()
		for _i in range(defs.size()):
			var next: StageDef = WorldCatalog.next_playable(cleared, wid)
			if next == null:
				_fail("progressão travou em %s com %s" % [wid, ", ".join(local)])
				return
			cleared.append(next.stage_id)
			local.append(next.stage_id)
			order.append(next.stage_id)
		if local[local.size() - 1] != WorldUnlock.boss_id(wid):
			_fail("%s não termina no boss (terminou em %s)" % [wid, local[local.size() - 1]])
			return
		if WorldCatalog.next_playable(cleared, wid) != null:
			_fail("%s ainda tem fase jogável depois do boss" % wid)
			return
	print("[smoke] OK progressão sem beco sem saída: %s" % ", ".join(order))
