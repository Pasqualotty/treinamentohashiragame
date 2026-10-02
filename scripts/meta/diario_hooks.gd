class_name DiarioHooks
extends RefCounted
## Ganho ao limpar fase: +15 XP de caçador e +1 no evento da semana.


const STAGE_CLEAR_XP := 15


static func apply_stage_clear(hunter_xp: int, event_clears: int) -> Dictionary:
	return {
		"hunter_xp": maxi(0, hunter_xp) + STAGE_CLEAR_XP,
		"event_clears": maxi(0, event_clears) + 1,
	}
