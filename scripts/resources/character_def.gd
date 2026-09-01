class_name CharacterDef
extends Resource
## Definição de um personagem jogável: identidade, kit (stats), unlock e tint.
##
## Objeto de dados PURO — não lê o autoload `Game`. Quem tem o progresso passa
## `cleared_ids` para `is_unlocked`, o mesmo contrato de `StageDef`.

const DEFAULT_STATS_PATH := "res://resources/player/player_stats.tres"

@export var id: String = ""
@export var display_name: String = ""
## IDs de fase que precisam estar em `stages_cleared`. Vazio = starter.
@export var unlock_requires: Array[String] = []
## Texto curto em PT para o cadeado (ex.: "Vença o chefe do Mundo 1").
@export var unlock_hint: String = ""
@export var skill_1_name: String = ""
@export var skill_2_name: String = ""
@export var ultimate_name: String = ""
## Modulate no hub e no sprite de combate (placeholder no lugar de arte própria).
@export var accent: Color = Color(1, 1, 1, 1)
@export_file("*.tres") var stats_path: String = DEFAULT_STATS_PATH
## Pasta de frames de combate. Vazio = frames do Tanjiro.
@export var combat_frames_dir: String = ""
@export var lifesteal_ratio: float = 0.0


func is_starter() -> bool:
	return unlock_requires.is_empty()


## Todos os pré-requisitos estão em `cleared`? Starter (lista vazia) sempre sim.
func is_unlocked(cleared: Array[String]) -> bool:
	for req_id: String in unlock_requires:
		if not cleared.has(req_id):
			return false
	return true


func missing_requirements(cleared: Array[String]) -> Array[String]:
	var missing: Array[String] = []
	for req_id: String in unlock_requires:
		if not cleared.has(req_id):
			missing.append(req_id)
	return missing


func lock_label() -> String:
	if unlock_hint != "":
		return unlock_hint
	if unlock_requires.is_empty():
		return ""
	return "Conclua: %s" % ", ".join(unlock_requires)


## Stats do kit, duplicados (não muta o .tres). Aplica nomes de skill e lifesteal.
func build_stats() -> PlayerStats:
	var path: String = stats_path if stats_path != "" else DEFAULT_STATS_PATH
	var loaded: Resource = load(path)
	var s: PlayerStats = loaded as PlayerStats
	if s == null:
		s = PlayerStats.new()
	else:
		s = s.duplicate(true) as PlayerStats
		if s == null:
			s = PlayerStats.new()
	if skill_1_name != "":
		s.skill_1_display_name = skill_1_name
	if skill_2_name != "":
		s.skill_2_display_name = skill_2_name
	if ultimate_name != "":
		s.ultimate_display_name = ultimate_name
	if lifesteal_ratio > 0.0:
		s.lifesteal_ratio = lifesteal_ratio
	return s
