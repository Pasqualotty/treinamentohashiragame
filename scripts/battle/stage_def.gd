class_name StageDef
extends Resource
## Definição de uma fase: identidade, cena, pré-requisitos e como ela aparece
## no mapa do mundo.
##
## Este recurso é a fonte de verdade da progressão. O mapa (`world_map.gd`) gera
## os nós a partir daqui — não existem botões fixos na cena do mapa. Para criar
## uma fase nova basta adicionar um `.tres` novo e registrá-lo em `WorldCatalog`.
##
## É um objeto de dados PURO: não conhece o autoload `Game` nem a árvore de
## cenas. Quem tem o estado de progresso passa a lista de fases concluídas como
## argumento (`WorldCatalog.cleared_ids()`), o que mantém uma rota única de
## leitura do save e deixa as regras testáveis sem montar cena.

## ID canônico usado no save (`Game.stages_cleared`) e pelo StageController.
@export var stage_id: String = ""
## Nome completo, exibido em textos longos (ex.: "Mundo 1 — Fase 4").
@export var display_name: String = ""
@export_file("*.tscn") var scene_path: String = ""
## IDs que precisam estar cleared para liberar esta fase (ex.: boss).
@export var requires_cleared: Array[String] = []

@export_group("Mapa")
## Rótulo curto mostrado no nó do mapa (ex.: "Fase 4", "Boss").
@export var map_label: String = ""
## Posição do nó no mapa, em coordenadas de design (canvas 1280×560).
## Obrigatória: o mapa não inventa posição (ver `WorldCatalog.load_stages`).
@export var map_position: Vector2 = Vector2.ZERO
## Nó de chefe: anel carmesim + selo rotativo no mapa.
@export var is_boss: bool = false

@export_group("Ondas")
## Packs de onda (cada item = array de kinds do WaveDirector). Vazio = o
## diretor cai na tabela W1 em `_waves_for_stage`. Mundos novos preenchem aqui.
@export var waves: Array = []


## Todos os pré-requisitos estão em `cleared`?
##
## ATENÇÃO: isto responde só "os pré-requisitos foram cumpridos", NÃO "o jogador
## pode entrar". Fase já concluída continua acessível mesmo que os requisitos
## mudem depois (save legado) — essa decisão é do mapa, em `_node_state`.
func is_unlocked(cleared: Array[String]) -> bool:
	for req_id: String in requires_cleared:
		if not cleared.has(req_id):
			return false
	return true


## IDs de pré-requisito que ainda faltam concluir (vazio = requisitos cumpridos).
func missing_requirements(cleared: Array[String]) -> Array[String]:
	var missing: Array[String] = []
	for req_id: String in requires_cleared:
		if not cleared.has(req_id):
			missing.append(req_id)
	return missing


## Rótulo curto para o nó do mapa, com fallbacks seguros.
func node_label() -> String:
	if map_label != "":
		return map_label
	if display_name != "":
		return display_name
	return stage_id


## Ondas normalizadas (lista de packs, cada pack = lista de kinds em String).
## Pack vazio é ignorado. Recurso sem `waves` devolve [].
func wave_packs() -> Array:
	var out: Array = []
	for pack_v: Variant in waves:
		var pack: Array = []
		if pack_v is PackedStringArray:
			for k: String in (pack_v as PackedStringArray):
				pack.append(k)
		elif pack_v is Array:
			for k_v: Variant in (pack_v as Array):
				pack.append(str(k_v))
		if not pack.is_empty():
			out.append(pack)
	return out
