extends SceneTree
## Headless: catálogo de fases do Mundo 1 + world_map + invariantes de progressão.
##
## Cobre as 6 fases (w1_01..w1_05 + boss), valida que o mapa gera um nó por fase
## do catálogo e que nenhum estado de save deixa o jogador sem fase jogável —
## inclusive o save legado que só conhece as 4 fases antigas.
##
## PRINCÍPIO DOS TESTES DE PROGRESSÃO: este smoke NÃO reimplementa a regra de
## desbloqueio. Ele aperta o `Button` de verdade e observa o efeito colateral
## (`Game.pending_stage_id` + texto do status). Um teste que recalculasse o
## estado por conta própria concordaria com o mapa por construção e seria cego
## justamente pro bug que ele deveria pegar.
##
## A cobertura da faixa de chão fica em `smoke_facing_ground.gd`, que descobre
## as fases por varredura e cobre todas — não duplicar aqui.
##
## Uso: godot --headless --path . -s res://scripts/qa/smoke_load_stages.gd

const MAP_SCENE: String = "res://scenes/world/world_map.tscn"
const WAVE_SCRIPT: String = "res://scripts/battle/wave_director.gd"
const EXPECTED_IDS: PackedStringArray = [
	"w1_01", "w1_02", "w1_03", "w1_04", "w1_05", "w1_boss",
]

## Estados em que o nó recusa a entrada (espelham `world_map.gd`).
const BLOCKED_STATES: PackedStringArray = ["locked", "boss_locked"]

var _failed: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _fail(msg: String) -> void:
	push_error("[smoke] FAIL %s" % msg)
	print("[smoke] FAIL %s" % msg)
	_failed += 1


func _run() -> void:
	var defs: Array[StageDef] = WorldCatalog.load_stages()
	_check_catalog(defs)
	await _check_stage_scenes(defs)
	_check_waves(defs)
	await _check_world_map(defs)
	await _check_progression(defs)
	_check_no_dead_end(defs)

	print("[smoke] IDs canônicos: %s" % ", ".join(EXPECTED_IDS))
	if _failed > 0:
		print("[smoke] FAILED count=%d" % _failed)
		quit(1)
		return
	print("[smoke] ALL PASSED")
	quit(0)


# --- Catálogo ---------------------------------------------------------------

func _check_catalog(defs: Array[StageDef]) -> void:
	if defs.size() != EXPECTED_IDS.size():
		_fail("catálogo com %d fases, esperado %d" % [defs.size(), EXPECTED_IDS.size()])
		return
	for i in range(defs.size()):
		var def: StageDef = defs[i]
		if def.stage_id != EXPECTED_IDS[i]:
			_fail("ordem do catálogo: índice %d = %s (esperado %s)" % [i, def.stage_id, EXPECTED_IDS[i]])
			continue
		if def.map_label == "":
			_fail("%s sem map_label" % def.stage_id)
		if def.map_position == Vector2.ZERO:
			_fail("%s sem map_position (obrigatória — o mapa não inventa posição)" % def.stage_id)
		print("[smoke] OK StageDef %s label=%s pos=%s boss=%s" % [
			def.stage_id, def.map_label, def.map_position, def.is_boss,
		])
	var bosses: int = 0
	for def: StageDef in defs:
		if def.is_boss:
			bosses += 1
	if bosses != 1:
		_fail("esperava exatamente 1 fase de boss, achei %d" % bosses)


# --- Cenas ------------------------------------------------------------------

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
		# Um frame pra _ready rodar (StageController).
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


# --- Ondas ------------------------------------------------------------------

## Toda fase do catálogo precisa de ondas próprias. Sem isto, uma fase nova (ou
## um `stage_id` renomeado) rodaria com o default genérico do WaveDirector — que
## agora nem existe mais, mas o teste garante que ninguém o traga de volta.
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

	# Canário: id inexistente TEM que voltar vazio. Sem isto, bastaria alguém
	# recolocar um `_:` genérico em `_waves_for_stage` para que toda checagem
	# abaixo passasse a validar as ondas do default em vez das da fase — o teste
	# viraria enfeite sem ninguém notar. (O push_error abaixo é esperado.)
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
		for wi in range(waves.size()):
			var pack: Array = waves[wi] as Array
			if pack.is_empty():
				_fail("%s onda %d vazia" % [def.stage_id, wi + 1])
				bad = true
				continue
			for kind_v: Variant in pack:
				var kind: String = str(kind_v)
				if not kinds.has(kind):
					_fail("%s onda %d: tipo de oni desconhecido '%s'" % [def.stage_id, wi + 1, kind])
					bad = true
				total_onis += 1
		if not bad:
			print("[smoke] OK ondas %s: %d ondas, %d onis" % [def.stage_id, waves.size(), total_onis])
	wd.free()


# --- Mapa -------------------------------------------------------------------

func _check_world_map(defs: Array[StageDef]) -> void:
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
	if buttons.size() != defs.size():
		_fail("world_map criou %d nós para %d fases do catálogo" % [buttons.size(), defs.size()])
	else:
		print("[smoke] OK world_map com %d nós de fase" % buttons.size())
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


# --- Progressão -------------------------------------------------------------

func _check_progression(defs: Array[StageDef]) -> void:
	var game: Node = root.get_node_or_null("Game")
	if game == null:
		_fail("autoload Game ausente")
		return
	var previous: Array = (game.get("stages_cleared") as Array).duplicate()
	var previous_pending: String = str(game.get("pending_stage_id"))

	await _expect_case(game, defs, "save novo", [], [
		"available", "locked", "locked", "locked", "locked", "boss_locked",
	])
	# Save legado: só conhece as 4 fases antigas. Precisa cair na Fase 4 (nova)
	# como próximo passo, e nunca ficar sem fase jogável.
	await _expect_case(game, defs, "save legado (01-03)", ["w1_01", "w1_02", "w1_03"], [
		"cleared", "cleared", "cleared", "available", "locked", "boss_locked",
	])
	# Save legado de quem venceu o boss sob a regra antiga (3 fases). O boss
	# aparece concluído — e tem que ACEITAR o toque. Foi aqui que o mapa se
	# contradizia: desenhava "✓ Boss" e recusava a entrada.
	await _expect_case(game, defs, "save legado (01-03 + boss)", ["w1_01", "w1_02", "w1_03", "w1_boss"], [
		"cleared", "cleared", "cleared", "available", "locked", "cleared",
	])
	await _expect_case(game, defs, "tudo limpo", [
		"w1_01", "w1_02", "w1_03", "w1_04", "w1_05", "w1_boss",
	], ["cleared", "cleared", "cleared", "cleared", "cleared", "cleared"])

	game.set("stages_cleared", previous)
	game.set("pending_stage_id", previous_pending)


## Aplica um estado de save e, para cada nó, aperta o botão de verdade.
func _expect_case(game: Node, defs: Array[StageDef], case_name: String,
		cleared: Array, expected: Array) -> void:
	var typed: Array[String] = []
	for id_v: Variant in cleared:
		typed.append(str(id_v))
	game.set("stages_cleared", typed)

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

		# O que importa não é o estado calculado, e sim o que o toque FAZ.
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

	var next: StageDef = WorldCatalog.next_playable(typed)
	var next_id: String = next.stage_id if next != null else "-"
	print("[smoke] OK progressão '%s' → próxima jogável: %s" % [case_name, next_id])


## Monta o mapa, aperta o botão do nó `index` e devolve o que aconteceu.
##
## Um mapa novo por nó de propósito: depois de entrar numa fase o mapa entra em
## `_traveling` e recusa cliques seguintes, o que mascararia o nó seguinte.
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

	# Liberar antes da animação de viagem terminar: `_select_stage` confere
	# `is_inside_tree()` e não troca de cena com o mapa fora da árvore.
	map.queue_free()
	await process_frame
	return out


## Partindo do zero, seguir sempre a próxima fase jogável tem que limpar o mundo
## inteiro — se algum `requires_cleared` estiver mal encadeado, isso trava aqui.
## Puro: não depende do save nem do autoload.
func _check_no_dead_end(defs: Array[StageDef]) -> void:
	var cleared: Array[String] = []
	var order := PackedStringArray()
	for _i in range(defs.size()):
		var next: StageDef = WorldCatalog.next_playable(cleared)
		if next == null:
			_fail("progressão travou com %d/%d fases limpas: %s" % [
				cleared.size(), defs.size(), ", ".join(order),
			])
			return
		cleared.append(next.stage_id)
		order.append(next.stage_id)
	if WorldCatalog.next_playable(cleared) != null:
		_fail("sobrou fase jogável depois de limpar todas")
		return
	if order[order.size() - 1] != "w1_boss":
		_fail("progressão natural não termina no boss (terminou em %s)" % order[order.size() - 1])
		return
	print("[smoke] OK progressão sem beco sem saída: %s" % ", ".join(order))
