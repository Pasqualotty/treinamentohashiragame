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
##   4. Registrar as ondas em `wave_director.gd::_waves_for_stage()`.
##
## O mapa não precisa de botão novo: os nós são instanciados a partir da lista.

const DEFAULT_WORLD_ID: String = "w1"

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
}


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
		out.append(def)
	return out


## IDs canônicos do mundo, na ordem do caminho.
static func stage_ids(world_id: String = DEFAULT_WORLD_ID) -> PackedStringArray:
	var out := PackedStringArray()
	for def: StageDef in load_stages(world_id):
		out.append(def.stage_id)
	return out


## StageDef pelo ID canônico (null se não existir no catálogo).
static func find(stage_id: String, world_id: String = DEFAULT_WORLD_ID) -> StageDef:
	for def: StageDef in load_stages(world_id):
		if def.stage_id == stage_id:
			return def
	return null


## Rótulo curto de uma fase pelo ID — usado em mensagens de "faltam X".
static func label_for(stage_id: String, world_id: String = DEFAULT_WORLD_ID) -> String:
	var def: StageDef = find(stage_id, world_id)
	return def.node_label() if def != null else stage_id


## Primeira fase liberada e ainda não concluída — o "próximo passo" do jogador.
## Retorna null quando o mundo inteiro já foi limpo.
static func next_playable(world_id: String = DEFAULT_WORLD_ID) -> StageDef:
	for def: StageDef in load_stages(world_id):
		if StageDef.is_cleared(def.stage_id):
			continue
		if def.is_unlocked():
			return def
	return null
