class_name StageDef
extends Resource
## Metadados opcionais de uma fase (id, cena, pré-requisitos).

@export var stage_id: String = ""
@export var display_name: String = ""
@export_file("*.tscn") var scene_path: String = ""
## IDs que precisam estar cleared para liberar esta fase (ex.: boss).
@export var requires_cleared: Array[String] = []


func is_unlocked() -> bool:
	for req_id: String in requires_cleared:
		if not Game.is_stage_cleared(req_id):
			return false
	return true
