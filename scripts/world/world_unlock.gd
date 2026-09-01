class_name WorldUnlock
extends RefCounted
## Regras puras de desbloqueio de mundo. Sem SceneTree, sem autoload.
## O mapa e os smokes só perguntam; não reimplementam a cadeia.

const WORLD_ORDER: PackedStringArray = ["w1", "w2", "w3", "w4", "w5"]

## world_id → stage_id que precisa estar cleared. Vazio = starter (sempre aberto).
const REQUIRED_CLEARED := {
	"w1": "",
	"w2": "w1_boss",
	"w3": "w2_boss",
	"w4": "w3_boss",
	"w5": "w4_boss",
}


static func known_ids() -> PackedStringArray:
	return WORLD_ORDER


static func is_known(world_id: String) -> bool:
	return REQUIRED_CLEARED.has(world_id)


## Pré-requisito canônico. Mundo desconhecido devolve um id que nunca está
## no save — fail-closed, sem exceção silenciosa.
static func required_cleared(world_id: String) -> String:
	if not REQUIRED_CLEARED.has(world_id):
		return "*"
	return str(REQUIRED_CLEARED[world_id])


static func is_unlocked(world_id: String, cleared: Array[String]) -> bool:
	if not is_known(world_id):
		return false
	var req: String = required_cleared(world_id)
	if req == "":
		return true
	return cleared.has(req)


static func next_world_id(world_id: String) -> String:
	var i: int = WORLD_ORDER.find(world_id)
	if i < 0 or i >= WORLD_ORDER.size() - 1:
		return ""
	return WORLD_ORDER[i + 1]


static func boss_id(world_id: String) -> String:
	if not is_known(world_id):
		return ""
	return "%s_boss" % world_id


## Se o save aponta um mundo ainda trancado, cai no último mundo aberto.
static func clamp_world_id(world_id: String, cleared: Array[String]) -> String:
	if is_unlocked(world_id, cleared):
		return world_id
	var last: String = "w1"
	for cand: String in WORLD_ORDER:
		if is_unlocked(cand, cleared):
			last = cand
	return last
