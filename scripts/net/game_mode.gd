class_name GameMode
extends RefCounted
## Contrato de modo da sala (gaveta Amigos, depois de Criar). Esta frente é dona.
## JOGAR ouro continua no mapa. Brawl/1v1 só abrem se a cena existir.

enum Id { VS_ONI_2, VS_ONI_4, BRAWL, DUEL }

const BRAWL_SCENE := "res://scenes/modes/brawl/brawl_arena.tscn"
const DUEL_SCENE := "res://scenes/modes/duel/duel.tscn"

const LABEL_VS_ONI_2 := "2 vs oni"
const LABEL_VS_ONI_4 := "4 vs oni"
const LABEL_BRAWL := "Mapa de batalha"
const LABEL_DUEL := "1v1"

const TOAST_BRAWL_MISSING := "Mapa de batalha ainda não chegou"
const TOAST_DUEL_MISSING := "1v1 ainda não chegou"


static func max_clients_for(mode_id: int) -> int:
	if mode_id == Id.VS_ONI_4 or mode_id == Id.BRAWL:
		return 3
	return 1


static func hunter_cap(mode_id: int) -> int:
	return max_clients_for(mode_id) + 1


static func is_vs_oni(mode_id: int) -> bool:
	return mode_id == Id.VS_ONI_2 or mode_id == Id.VS_ONI_4


static func scene_path(mode_id: int) -> String:
	match mode_id:
		Id.BRAWL:
			return BRAWL_SCENE
		Id.DUEL:
			return DUEL_SCENE
		_:
			return ""


static func missing_toast(mode_id: int) -> String:
	match mode_id:
		Id.BRAWL:
			return TOAST_BRAWL_MISSING
		Id.DUEL:
			return TOAST_DUEL_MISSING
		_:
			return ""


static func label_of(mode_id: int) -> String:
	match mode_id:
		Id.VS_ONI_4:
			return LABEL_VS_ONI_4
		Id.BRAWL:
			return LABEL_BRAWL
		Id.DUEL:
			return LABEL_DUEL
		_:
			return LABEL_VS_ONI_2


static func all_ids() -> Array[int]:
	return [Id.VS_ONI_2, Id.VS_ONI_4, Id.BRAWL, Id.DUEL]
