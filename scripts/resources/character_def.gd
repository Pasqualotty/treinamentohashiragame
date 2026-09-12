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
## Chrome de UI (borda de card / swatch). Com sheets próprios o corpo fica WHITE.
@export var accent: Color = Color(1, 1, 1, 1)
@export_file("*.tres") var stats_path: String = DEFAULT_STATS_PATH
## Pasta com subdirs idle_side / run / attack / hurt. Vazio = frames do Tanjiro.
@export var combat_frames_dir: String = ""
## Pasta com 00.png (idle) e 03.png (blink) do showcase do hub.
@export var hub_frames_dir: String = ""
## PNG da grade PERSONAGENS. Vazio = swatch `accent`.
@export_file("*.png") var portrait_path: String = ""
@export var lifesteal_ratio: float = 0.0


## `00.png`, `01.png`… até faltar. Aceita `res://` ainda sem `.import`.
static func list_png_sequence(dir: String, max_n: int = 32) -> Array[String]:
	var out: Array[String] = []
	if dir == "":
		return out
	var base: String = dir.rstrip("/")
	for i: int in range(max_n):
		var path: String = "%s/%02d.png" % [base, i]
		if not _res_or_file_exists(path):
			break
		out.append(path)
	return out


static func _res_or_file_exists(path: String) -> bool:
	return ResourceLoader.exists(path) or FileAccess.file_exists(path)


func has_hub_art() -> bool:
	if hub_frames_dir == "":
		return false
	return _res_or_file_exists("%s/00.png" % hub_frames_dir.rstrip("/"))


func has_portrait_art() -> bool:
	return portrait_path != "" and _res_or_file_exists(portrait_path)


func has_combat_art() -> bool:
	if combat_frames_dir == "":
		return false
	var root: String = combat_frames_dir.rstrip("/")
	for sub: String in ["idle_side", "run", "attack", "hurt"]:
		if not list_png_sequence("%s/%s" % [root, sub], 1).is_empty():
			return true
	return false


func combat_anim_paths(anim_sub: String, fallback: Array[String]) -> Array[String]:
	if combat_frames_dir == "":
		return fallback
	var root: String = combat_frames_dir.rstrip("/")
	var listed: Array[String] = list_png_sequence("%s/%s" % [root, anim_sub])
	if listed.is_empty() and anim_sub in ["skill_1", "skill_2", "ultimate"]:
		# Sem pasta de skill: usa o attack DESTE id, nunca o pack genérico do Tanjiro.
		listed = list_png_sequence("%s/attack" % root)
	if listed.is_empty():
		return fallback
	return listed


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
