class_name StageDef
extends Resource
## Definição de uma fase: identidade, cena, pré-requisitos e como ela aparece
## no mapa do mundo.
##
## Este recurso é a fonte de verdade da progressão. O mapa (`world_map.gd`) gera
## os nós a partir daqui — não existem botões fixos na cena do mapa. Para criar
## uma fase nova basta adicionar um `.tres` novo e registrá-lo em `WorldCatalog`.

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
## Zero = o mapa distribui o nó automaticamente ao longo do caminho.
@export var map_position: Vector2 = Vector2.ZERO
## Nó de chefe: anel carmesim + selo rotativo no mapa.
@export var is_boss: bool = false


## Fase já concluída no save atual?
##
## Resolve o autoload `Game` pela árvore em vez de usar o identificador global:
## em `godot --headless -s <script>` os autoloads ainda não estão registrados
## quando este script é compilado, e o global quebraria a compilação dos smokes.
static func is_cleared(id: String) -> bool:
	var loop: MainLoop = Engine.get_main_loop()
	if not (loop is SceneTree):
		return false
	var game: Node = (loop as SceneTree).root.get_node_or_null("Game")
	if game == null:
		return false
	return bool(game.call("is_stage_cleared", id))


## Todos os pré-requisitos já foram concluídos?
func is_unlocked() -> bool:
	return missing_requirements().is_empty()


## IDs de pré-requisito que ainda faltam concluir (vazio = fase liberada).
func missing_requirements() -> Array[String]:
	var missing: Array[String] = []
	for req_id: String in requires_cleared:
		if not StageDef.is_cleared(req_id):
			missing.append(req_id)
	return missing


## Rótulo curto para o nó do mapa, com fallbacks seguros.
func node_label() -> String:
	if map_label != "":
		return map_label
	if display_name != "":
		return display_name
	return stage_id
