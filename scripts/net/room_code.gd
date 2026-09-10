class_name RoomCode
extends RefCounted
## Código de sala LAN: 6 chars, sem 0/O/I/1. Sem SceneTree, sem rede.

const CHARSET := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const LENGTH := 6


static func generate(rng: RandomNumberGenerator = null) -> String:
	var gen: RandomNumberGenerator = rng
	if gen == null:
		gen = RandomNumberGenerator.new()
		gen.randomize()
	var out := ""
	var n: int = CHARSET.length()
	for _i in LENGTH:
		out += CHARSET[gen.randi_range(0, n - 1)]
	return out


## Uppercase, tira espaço. Não troca letra inválida — quem chama valida.
static func normalize(raw: String) -> String:
	var compact := raw.strip_edges().replace(" ", "").to_upper()
	return compact


static func is_valid(code: String) -> bool:
	var n := normalize(code)
	if n.length() != LENGTH:
		return false
	for c in n:
		if not CHARSET.contains(c):
			return false
	return true
