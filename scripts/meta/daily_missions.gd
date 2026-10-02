class_name DailyMissions
extends RefCounted
## Três missões do dia, determinísticas pela data (YYYY-MM-DD). Sem rede.


static func day_key_from_unix(unix: int) -> String:
	var d: Dictionary = Time.get_date_dict_from_unix_time(maxi(0, unix))
	return "%04d-%02d-%02d" % [int(d.year), int(d.month), int(d.day)]


static func today_key() -> String:
	return day_key_from_unix(int(Time.get_unix_time_from_system()))


## Mesmo dia = mesmos ids, títulos e metas. A data só amarra o ciclo.
static func missions_for_day(day_key: String) -> Array[Dictionary]:
	var _day: String = day_key
	var out: Array[Dictionary] = []
	out.append({
		"id": "clear_1",
		"kind": "clear_stage",
		"title": "Limpar uma fase",
		"desc": "Termine qualquer fase do mapa.",
		"goal": 1,
		"xp": 25,
		"coins": 8,
	})
	out.append({
		"id": "coins_20",
		"kind": "collect_run_coins",
		"title": "Juntar 20 moedas",
		"desc": "Pegue 20 moedas numa mesma fase.",
		"goal": 20,
		"xp": 20,
		"coins": 6,
	})
	out.append({
		"id": "breath_max",
		"kind": "use_ultimate",
		"title": "Respiração no máximo",
		"desc": "Use a respiração máxima uma vez.",
		"goal": 1,
		"xp": 20,
		"coins": 6,
	})
	return out


static func find_mission(day_key: String, mission_id: String) -> Dictionary:
	for spec: Dictionary in missions_for_day(day_key):
		if str(spec.get("id", "")) == mission_id:
			return spec
	return {}
