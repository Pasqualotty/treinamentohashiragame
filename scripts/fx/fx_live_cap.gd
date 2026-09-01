class_name FxLiveCap
extends RefCounted
## Teto de FX vivos no autoload `Fx`. Puro: o smoke afirma os números sem cena.

const DEFAULT_CAP := 24


## Quantos filhos evictar ANTES de nascer mais um, para o total ficar ≤ cap.
static func evict_for_spawn(live: int, cap: int = DEFAULT_CAP) -> int:
	if cap <= 0:
		return maxi(0, live)
	return maxi(0, live - cap + 1)


static func allows_spawn(live: int, cap: int = DEFAULT_CAP) -> bool:
	return evict_for_spawn(live, cap) == 0
