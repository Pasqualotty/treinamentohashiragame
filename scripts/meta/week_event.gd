class_name WeekEvent
extends RefCounted
## Evento da semana no aparelho. Semana nova zera o progresso.


static func week_id_from_unix(unix: int) -> int:
	# Balde de 7 dias a partir do epoch Unix. Dois instantes em semanas
	# diferentes nunca compartilham o mesmo id.
	return int(floor(float(maxi(0, unix)) / 604800.0))


static func current_week_id() -> int:
	return week_id_from_unix(int(Time.get_unix_time_from_system()))


static func event_for_week(week_id: int) -> Dictionary:
	var _week: int = week_id
	return {
		"id": "week_train",
		"title": "Treino da semana",
		"desc": "Limpar 3 fases nesta semana.",
		"goal": 3,
		"xp": 50,
	}
