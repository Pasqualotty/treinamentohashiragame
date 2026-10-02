class_name HunterXp
extends RefCounted
## Curva de nível de caçador. XP não mexe em HP, dano, velocidade nem dash.
## Nível 1 em 0 XP. Para subir do nível L precisa 100 + 25*(L-1).


static func xp_to_next(level: int) -> int:
	var lv: int = maxi(1, level)
	return 100 + 25 * (lv - 1)


static func level_at(xp: int) -> int:
	var remain: int = maxi(0, xp)
	var level: int = 1
	var need: int = xp_to_next(level)
	while remain >= need:
		remain -= need
		level += 1
		need = xp_to_next(level)
	return level


static func xp_into_level(xp: int) -> int:
	var remain: int = maxi(0, xp)
	var level: int = 1
	var need: int = xp_to_next(level)
	while remain >= need:
		remain -= need
		level += 1
		need = xp_to_next(level)
	return remain


static func fill_ratio(xp: int) -> float:
	var need: int = xp_to_next(level_at(xp))
	if need <= 0:
		return 0.0
	return clampf(float(xp_into_level(xp)) / float(need), 0.0, 1.0)
