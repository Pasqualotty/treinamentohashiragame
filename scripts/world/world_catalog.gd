class_name WorldCatalog
extends RefCounted
## Catálogo de fases por mundo — fonte única de verdade para o mapa, para os
## smokes e para a progressão.
##
## COMO ADICIONAR UMA FASE NOVA
##   1. Criar a cena em `scenes/battle/stage_<id>.tscn`.
##   2. Criar o StageDef em `resources/stages/stage_<id>.tres` (id, cena,
##      `requires_cleared`, rótulo e posição no mapa).
##   3. Acrescentar o caminho do `.tres` na lista do mundo aqui embaixo, na
##      ordem em que a fase aparece no caminho do mapa.
##   4. Preencher `waves` no `.tres` (kinds do WaveDirector). W1 ainda pode
##      cair na tabela de `_waves_for_stage()` se `waves` estiver vazio.
##
## O mapa não precisa de botão novo: os nós são instanciados a partir da lista.
##
## Este é também o ÚNICO ponto que lê o progresso do save (`cleared_ids`). Tudo
## abaixo dele — `StageDef`, o mapa, os smokes — trabalha com a lista de IDs já
## resolvida, para não existirem duas rotas de leitura do mesmo estado.

const DEFAULT_WORLD_ID: String = "w1"

const TITLES := {
	"w1": "Mundo 1 — Montanha",
	"w2": "Mundo 2 — Trem",
	"w3": "Mundo 3 — Distrito",
	"w4": "Mundo 4 — Castelo",
	"w5": "Mundo 5 — Céu Vermelho",
}

## world_id → caminhos dos StageDef, na ordem do caminho no mapa.
const WORLDS: Dictionary = {
	"w1": [
		"res://resources/stages/stage_w1_01.tres",
		"res://resources/stages/stage_w1_02.tres",
		"res://resources/stages/stage_w1_03.tres",
		"res://resources/stages/stage_w1_04.tres",
		"res://resources/stages/stage_w1_05.tres",
		"res://resources/stages/stage_w1_boss.tres",
	],
	"w2": [
		"res://resources/stages/stage_w2_01.tres",
		"res://resources/stages/stage_w2_02.tres",
		"res://resources/stages/stage_w2_03.tres",
		"res://resources/stages/stage_w2_boss.tres",
	],
	"w3": [
		"res://resources/stages/stage_w3_01.tres",
		"res://resources/stages/stage_w3_02.tres",
		"res://resources/stages/stage_w3_03.tres",
		"res://resources/stages/stage_w3_04.tres",
		"res://resources/stages/stage_w3_boss.tres",
	],
	"w4": [
		"res://resources/stages/stage_w4_01.tres",
		"res://resources/stages/stage_w4_02.tres",
		"res://resources/stages/stage_w4_03.tres",
		"res://resources/stages/stage_w4_04.tres",
		"res://resources/stages/stage_w4_boss.tres",
	],
	"w5": [
		"res://resources/stages/stage_w5_01.tres",
		"res://resources/stages/stage_w5_02.tres",
		"res://resources/stages/stage_w5_03.tres",
		"res://resources/stages/stage_w5_boss.tres",
	],
}


static func world_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for wid: String in WorldUnlock.known_ids():
		if WORLDS.has(wid):
			out.append(wid)
	return out


static func title_for(world_id: String) -> String:
	return str(TITLES.get(world_id, world_id))


## Caminhos dos StageDef do mundo, na ordem do caminho no mapa.
static func stage_paths(world_id: String = DEFAULT_WORLD_ID) -> PackedStringArray:
	var out := PackedStringArray()
	var raw: Variant = WORLDS.get(world_id, [])
	if raw is Array:
		for p: Variant in (raw as Array):
			out.append(str(p))
	return out


## StageDefs do mundo, na ordem do caminho. Entradas inválidas são reportadas e
## puladas — um `.tres` quebrado não pode derrubar o mapa inteiro.
static func load_stages(world_id: String = DEFAULT_WORLD_ID) -> Array[StageDef]:
	var out: Array[StageDef] = []
	for path: String in stage_paths(world_id):
		var res: Resource = load(path)
		var def := res as StageDef
		if def == null:
			push_error("WorldCatalog: StageDef inválido em %s" % path)
			continue
		if def.stage_id == "":
			push_error("WorldCatalog: StageDef sem stage_id em %s" % path)
			continue
		if def.map_position == Vector2.ZERO:
			# `map_position` é obrigatória: sem ela o nó cairia na origem do
			# canvas, empilhado com qualquer outro que também esqueceu.
			push_error("WorldCatalog: %s sem map_position em %s" % [def.stage_id, path])
		out.append(def)
	return out


## IDs canônicos do mundo, na ordem do caminho.
static func stage_ids(world_id: String = DEFAULT_WORLD_ID) -> PackedStringArray:
	var out := PackedStringArray()
	for def: StageDef in load_stages(world_id):
		out.append(def.stage_id)
	return out


static func load_all_stages() -> Array[StageDef]:
	var out: Array[StageDef] = []
	for wid: String in world_ids():
		for def: StageDef in load_stages(wid):
			out.append(def)
	return out


## StageDef pelo ID canônico. Procura no mundo pedido e, se faltar, nos outros.
static func find(stage_id: String, world_id: String = DEFAULT_WORLD_ID) -> StageDef:
	var def: StageDef = _find_in_world(stage_id, world_id)
	if def != null:
		return def
	for wid: String in world_ids():
		if wid == world_id:
			continue
		def = _find_in_world(stage_id, wid)
		if def != null:
			return def
	return null


static func _find_in_world(stage_id: String, world_id: String) -> StageDef:
	for def: StageDef in load_stages(world_id):
		if def.stage_id == stage_id:
			return def
	return null


## Rótulo curto de uma fase pelo ID — usado em mensagens de "faltam X".
static func label_for(stage_id: String, world_id: String = DEFAULT_WORLD_ID) -> String:
	var def: StageDef = find(stage_id, world_id)
	return def.node_label() if def != null else stage_id


## Fases concluídas no save atual.
##
## Único ponto do jogo que lê `Game.stages_cleared` para fins de progressão. O
## autoload é resolvido pela árvore em vez do identificador global porque em
## `godot --headless -s <script>` os autoloads ainda não estão registrados
## quando este script é compilado — o global quebraria a compilação dos smokes.
## Falta de `Game` é erro alto, nunca uma lista vazia silenciosa.
static func cleared_ids() -> Array[String]:
	var out: Array[String] = []
	var loop: MainLoop = Engine.get_main_loop()
	if not (loop is SceneTree):
		push_error("WorldCatalog: sem SceneTree — progresso indisponível")
		return out
	var game: Node = (loop as SceneTree).root.get_node_or_null("Game")
	if game == null:
		push_error("WorldCatalog: autoload Game ausente — progresso indisponível")
		return out
	var raw: Variant = game.get("stages_cleared")
	if not (raw is Array):
		push_error("WorldCatalog: Game.stages_cleared não é Array")
		return out
	for id_v: Variant in (raw as Array):
		out.append(str(id_v))
	return out


## Primeira fase liberada e ainda não concluída — o "próximo passo" do jogador.
## Retorna null quando o mundo inteiro já foi limpo.
static func next_playable(cleared: Array[String], world_id: String = DEFAULT_WORLD_ID) -> StageDef:
	for def: StageDef in load_stages(world_id):
		if cleared.has(def.stage_id):
			continue
		if def.is_unlocked(cleared):
			return def
	return null
