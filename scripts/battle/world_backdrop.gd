class_name WorldBackdrop
extends RefCounted
## Caminho de MidArt por mundo. W1 (e ids desconhecidos) devolvem vazio
## para a cena manter a arte que já tem.

const PATH_W2 := "res://assets/backgrounds/w2/stage.png"
const PATH_W3 := "res://assets/backgrounds/w3/stage.png"
const PATH_W4 := "res://assets/backgrounds/w4/stage.png"
const PATH_W5 := "res://assets/backgrounds/w5/stage.png"


static func texture_path_for_stage(stage_id: String) -> String:
	if stage_id.begins_with("w2_"):
		return PATH_W2
	if stage_id.begins_with("w3_"):
		return PATH_W3
	if stage_id.begins_with("w4_"):
		return PATH_W4
	if stage_id.begins_with("w5_"):
		return PATH_W5
	return ""


## Veste a fase inteira para o mundo (emenda do fundo, chão temático, atmosfera).
## Stub do contrato `docs/uplift-visual/contrato.md`: a frente F3 preenche.
static func dress(_stage: Node, _stage_id: String) -> void:
	pass
