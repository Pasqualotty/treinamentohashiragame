class_name FriendCode
extends RefCounted
## Código de amigo persistente: 8 chars, sem 0/O/I/1. Sem SceneTree, sem rede.
## Diferente do código de sala (6) de propósito — Zap não mistura os dois.

const CHARSET := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const LENGTH := 8


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


static func normalize(raw: String) -> String:
	return raw.strip_edges().replace(" ", "").to_upper()


static func is_valid(code: String) -> bool:
	var n := normalize(code)
	if n.length() != LENGTH:
		return false
	for c in n:
		if not CHARSET.contains(c):
			return false
	return true
