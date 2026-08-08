extends SceneTree
## Headless: catálogo de fases do Mundo 1 + world_map + invariantes de progressão.
##
## Cobre as 6 fases (w1_01..w1_05 + boss), valida que o mapa gera um nó por fase
## do catálogo e que nenhum estado de save deixa o jogador sem fase jogável —
## inclusive o save legado que só conhece as 4 fases antigas.
##
## Uso: godot --headless --path . -s res://scripts/qa/smoke_load_stages.gd

const MAP_SCENE: String = "res://scenes/world/world_map.tscn"
const EXPECTED_IDS: PackedStringArray = [
	"w1_01", "w1_02", "w1_03", "w1_04", "w1_05", "w1_boss",
]

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
	await _check_world_map(defs)
	_check_progression(defs)

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
			_fail("%s sem map_position" % def.stage_id)
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
		_check_ground_band(node, def.stage_id)
		node.queue_free()
		await process_frame


## Convenção de chão: onde a fase declara um `Ground/GroundFill`, a faixa visual
## precisa ir da superfície de colisão até abaixo do `limit_bottom` da câmera —
## senão o parallax aparece por baixo do piso ("piso voando").
## Fases sem `GroundFill` são puladas (ainda usam só a tira fina).
func _check_ground_band(stage: Node, stage_id: String) -> void:
	var ground := stage.get_node_or_null("Ground") as Node2D
	if ground == null:
		return
	var fill := ground.get_node_or_null("GroundFill") as Sprite2D
	if fill == null or fill.texture == null:
		return
	var shape_node := ground.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		_fail("%s: Ground sem CollisionShape2D" % stage_id)
		return
	var rect := shape_node.shape as RectangleShape2D
	if rect == null:
		_fail("%s: Ground sem RectangleShape2D" % stage_id)
		return
	var camera := stage.get_node_or_null("Player/Camera2D") as Camera2D
	if camera == null:
		_fail("%s: sem Player/Camera2D para validar a faixa de chão" % stage_id)
		return

	var surface_y: float = ground.position.y - rect.size.y * 0.5
	var fill_center: Vector2 = ground.position + fill.position
	var fill_size: Vector2 = Vector2(fill.texture.get_width(), fill.texture.get_height()) * fill.scale
	var fill_top: float = fill_center.y - fill_size.y * 0.5
	var fill_bottom: float = fill_center.y + fill_size.y * 0.5
	var ground_left: float = ground.position.x - rect.size.x * 0.5
	var ground_right: float = ground.position.x + rect.size.x * 0.5
	var fill_left: float = fill_center.x - fill_size.x * 0.5
	var fill_right: float = fill_center.x + fill_size.x * 0.5

	if fill_top > surface_y + 1.0:
		_fail("%s: faixa de chão começa em y=%.0f, abaixo da superfície y=%.0f" % [
			stage_id, fill_top, surface_y,
		])
	elif fill_bottom < float(camera.limit_bottom):
		_fail("%s: faixa de chão termina em y=%.0f, acima do limit_bottom=%d" % [
			stage_id, fill_bottom, camera.limit_bottom,
		])
	elif fill_left > ground_left + 1.0 or fill_right < ground_right - 1.0:
		_fail("%s: faixa de chão (%.0f..%.0f) não cobre a colisão (%.0f..%.0f)" % [
			stage_id, fill_left, fill_right, ground_left, ground_right,
		])
	else:
		print("[smoke] OK faixa de chão %s: y %.0f..%.0f (limit_bottom=%d)" % [
			stage_id, fill_top, fill_bottom, camera.limit_bottom,
		])


# --- Mapa -------------------------------------------------------------------

func _check_world_map(defs: Array[StageDef]) -> void:
	var packed := load(MAP_SCENE) as PackedScene
	if packed == null:
		_fail("load: %s" % MAP_SCENE)
		return

	# Estado determinístico (save novo) para o mapa nascer sempre igual.
	var game: Node = root.get_node_or_null("Game")
	var previous: Array = []
	if game != null:
		previous = (game.get("stages_cleared") as Array).duplicate()
		var empty: Array[String] = []
		game.set("stages_cleared", empty)

	var map: Node = packed.instantiate()
	if map == null:
		_fail("instantiate: %s" % MAP_SCENE)
		if game != null:
			game.set("stages_cleared", previous)
		return
	root.add_child(map)
	await process_frame

	var canvas: Node = map.find_child("MapCanvas", true, false)
	if canvas == null:
		_fail("world_map sem MapCanvas")
	else:
		var buttons: int = 0
		for child: Node in canvas.get_children():
			if child is Button:
				buttons += 1
		if buttons != defs.size():
			_fail("world_map criou %d nós para %d fases do catálogo" % [buttons, defs.size()])
		else:
			print("[smoke] OK world_map com %d nós de fase" % buttons)

	# Tocar num nó bloqueado precisa dar resposta: o status diz o que falta.
	var boss_index: int = -1
	for i in range(defs.size()):
		if defs[i].is_boss:
			boss_index = i
			break
	var status := map.find_child("StatusLabel", true, false) as Label
	if boss_index < 0 or status == null:
		_fail("world_map sem nó de boss ou sem StatusLabel")
	else:
		map.call("_select_stage", boss_index)
		await process_frame
		var text: String = status.text
		if not text.contains("conclua"):
			_fail("toque no boss bloqueado não explicou o motivo (status='%s')" % text)
		else:
			print("[smoke] OK feedback de nó bloqueado: '%s'" % text)

	map.queue_free()
	await process_frame
	if game != null:
		game.set("stages_cleared", previous)


# --- Progressão -------------------------------------------------------------

func _check_progression(defs: Array[StageDef]) -> void:
	var game: Node = root.get_node_or_null("Game")
	if game == null:
		_fail("autoload Game ausente")
		return
	var previous: Array = (game.get("stages_cleared") as Array).duplicate()

	_expect_states(game, defs, "save novo", [], [
		"available", "locked", "locked", "locked", "locked", "locked",
	])
	# Save legado: só conhece as 4 fases antigas. Precisa cair na Fase 4 (nova)
	# como próximo passo, e nunca ficar sem fase jogável.
	_expect_states(game, defs, "save legado (01-03)", ["w1_01", "w1_02", "w1_03"], [
		"cleared", "cleared", "cleared", "available", "locked", "locked",
	])
	# Save legado de quem já venceu o boss antigo: o boss continua acessível
	# (concluído) e as fases novas entram na ordem certa.
	_expect_states(game, defs, "save legado (01-03 + boss)", ["w1_01", "w1_02", "w1_03", "w1_boss"], [
		"cleared", "cleared", "cleared", "available", "locked", "cleared",
	])
	_expect_states(game, defs, "tudo limpo", [
		"w1_01", "w1_02", "w1_03", "w1_04", "w1_05", "w1_boss",
	], ["cleared", "cleared", "cleared", "cleared", "cleared", "cleared"])

	_check_no_dead_end(game, defs)

	game.set("stages_cleared", previous)


## Aplica um estado de save e confere o estado de cada nó do mapa.
func _expect_states(game: Node, defs: Array[StageDef], case_name: String,
		cleared: Array, expected: Array) -> void:
	var typed: Array[String] = []
	for id_v: Variant in cleared:
		typed.append(str(id_v))
	game.set("stages_cleared", typed)
	for i in range(defs.size()):
		var def: StageDef = defs[i]
		var got: String = _state_of(game, def)
		var want: String = str(expected[i])
		if got != want:
			_fail("%s: %s está '%s', esperado '%s'" % [case_name, def.stage_id, got, want])
	var next: StageDef = WorldCatalog.next_playable()
	var next_id: String = next.stage_id if next != null else "-"
	print("[smoke] OK progressão '%s' → próxima jogável: %s" % [case_name, next_id])


func _state_of(game: Node, def: StageDef) -> String:
	if bool(game.call("is_stage_cleared", def.stage_id)):
		return "cleared"
	return "available" if def.is_unlocked() else "locked"


## Partindo do zero, seguir sempre a próxima fase jogável tem que limpar o mundo
## inteiro — se algum `requires_cleared` estiver mal encadeado, isso trava aqui.
func _check_no_dead_end(game: Node, defs: Array[StageDef]) -> void:
	var cleared: Array[String] = []
	game.set("stages_cleared", cleared)
	var order: PackedStringArray = PackedStringArray()
	for _i in range(defs.size()):
		var next: StageDef = WorldCatalog.next_playable()
		if next == null:
			_fail("progressão travou com %d/%d fases limpas: %s" % [
				cleared.size(), defs.size(), ", ".join(order),
			])
			return
		cleared.append(next.stage_id)
		order.append(next.stage_id)
		game.set("stages_cleared", cleared)
	if WorldCatalog.next_playable() != null:
		_fail("sobrou fase jogável depois de limpar todas")
		return
	if order[order.size() - 1] != "w1_boss":
		_fail("progressão natural não termina no boss (terminou em %s)" % order[order.size() - 1])
		return
	print("[smoke] OK progressão sem beco sem saída: %s" % ", ".join(order))
