extends SceneTree
## Smoke do diário local: curva de XP, missões estáveis, claim sem dobra,
## save legado e evento que zera na semana nova.
## Uso: godot --headless --path . -s res://scripts/qa/smoke_diario.gd

const TEMP_SAVE := "user://smoke_diario_save.json"
const FIXED_DAY := "2026-10-02"
const WEEK_A := 1000 * 604800
const WEEK_B := 1008 * 604800

var _ok: bool = true
var _messages: Array[String] = []
var _game: Node = null
var _temp_active: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _fail(msg: String) -> void:
	_ok = false
	_messages.append("FAIL: " + msg)


func _pass(msg: String) -> void:
	_messages.append("ok: " + msg)


func _run() -> void:
	_game = root.get_node_or_null("Game")
	if _game == null:
		_fail("autoload Game ausente")
		_finish()
		return
	_use_temp_save()
	_test_level_curve()
	_test_missions_stable()
	_test_claim_twice()
	_test_legacy_defaults()
	_test_week_reset()
	_test_hub_instancia()
	_test_telas_instanciam()
	_finish()


func _use_temp_save() -> void:
	_game.call("set_save_path", TEMP_SAVE)
	_temp_active = true
	_wipe(TEMP_SAVE)
	AtomicJson.remove_sidecars(TEMP_SAVE)


func _restore() -> void:
	if not _temp_active:
		return
	_temp_active = false
	_wipe(TEMP_SAVE)
	AtomicJson.remove_sidecars(TEMP_SAVE)
	if _game == null:
		return
	_game.call("set_save_path", "")
	_game.call("load_game")


func _wipe(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _test_level_curve() -> void:
	if HunterXp.level_at(0) != 1:
		_fail("nível em 0 XP != 1")
		return
	if HunterXp.xp_to_next(1) != 100:
		_fail("subir do 1 precisa 100")
		return
	if HunterXp.xp_to_next(2) != 125:
		_fail("subir do 2 precisa 125")
		return
	if HunterXp.level_at(99) != 1:
		_fail("99 XP ainda é Nv. 1")
		return
	if HunterXp.level_at(100) != 2:
		_fail("100 XP deveria ser Nv. 2")
		return
	if HunterXp.level_at(224) != 2:
		_fail("224 XP ainda é Nv. 2")
		return
	if HunterXp.level_at(225) != 3:
		_fail("225 XP deveria ser Nv. 3")
		return
	_pass("curva de nível")


func _test_missions_stable() -> void:
	var a: Array[Dictionary] = DailyMissions.missions_for_day(FIXED_DAY)
	var b: Array[Dictionary] = DailyMissions.missions_for_day(FIXED_DAY)
	if a.size() != 3 or b.size() != 3:
		_fail("dia fixo não devolveu 3 missões")
		return
	for i in range(3):
		if str(a[i].get("id", "")) != str(b[i].get("id", "")):
			_fail("missão %d mudou de id" % i)
			return
		if str(a[i].get("title", "")) != str(b[i].get("title", "")):
			_fail("missão %d mudou de título" % i)
			return
		if int(a[i].get("goal", 0)) != int(b[i].get("goal", -1)):
			_fail("missão %d mudou de meta" % i)
			return
	if str(a[0].get("id", "")) != "clear_1":
		_fail("primeira missão não é limpar fase")
		return
	_pass("missões estáveis em %s" % FIXED_DAY)


func _reset_diario_mem() -> void:
	_game.set("hunter_xp", 0)
	_game.set("coins_banked", 0)
	_game.set("mission_day", FIXED_DAY)
	_game.set("mission_progress", {})
	_game.set("mission_claimed", {})
	_game.set("event_week", WeekEvent.week_id_from_unix(WEEK_A))
	_game.set("event_clears", 0)
	_game.set("event_claimed", false)
	_game.call("save_game")


func _test_claim_twice() -> void:
	_reset_diario_mem()
	var spec: Dictionary = DailyMissions.find_mission(FIXED_DAY, "clear_1")
	var progress: Dictionary = {"clear_1": int(spec.get("goal", 1))}
	_game.set("mission_progress", progress)
	var first: Dictionary = _game.call("claim_daily_mission", "clear_1")
	if not bool(first.get("ok", false)):
		_fail("primeiro Receber falhou: %s" % str(first))
		return
	var xp_after: int = int(_game.get("hunter_xp"))
	var coins_after: int = int(_game.get("coins_banked"))
	if xp_after != int(spec.get("xp", 0)):
		_fail("XP após claim=%s" % xp_after)
		return
	if coins_after != int(spec.get("coins", 0)):
		_fail("moedas após claim=%s" % coins_after)
		return
	var second: Dictionary = _game.call("claim_daily_mission", "clear_1")
	if bool(second.get("ok", false)):
		_fail("segundo Receber deveria recusar")
		return
	if int(_game.get("hunter_xp")) != xp_after:
		_fail("segundo Receber dobrou XP")
		return
	if int(_game.get("coins_banked")) != coins_after:
		_fail("segundo Receber dobrou moedas")
		return
	_pass("Receber duas vezes não dobra")


func _test_legacy_defaults() -> void:
	_wipe(TEMP_SAVE)
	AtomicJson.remove_sidecars(TEMP_SAVE)
	var legacy := {
		"version": 1,
		"coins_banked": 12,
		"player_name": "Giyu",
		"current_character_id": "tanjiro",
		"stages_cleared": [],
		"upgrades": {},
	}
	if not AtomicJson.write_dict(TEMP_SAVE, legacy):
		_fail("não gravou save legado")
		return
	_game.call("load_game")
	if int(_game.get("hunter_xp")) != 0:
		_fail("legado hunter_xp=%s" % str(_game.get("hunter_xp")))
		return
	if str(_game.get("mission_day")) != "":
		_fail("legado mission_day deveria vir vazio")
		return
	if not (_game.get("mission_progress") is Dictionary) or not (_game.get("mission_progress") as Dictionary).is_empty():
		_fail("legado mission_progress não veio vazio")
		return
	if not (_game.get("mission_claimed") is Dictionary) or not (_game.get("mission_claimed") as Dictionary).is_empty():
		_fail("legado mission_claimed não veio vazio")
		return
	if int(_game.get("event_week")) != 0:
		_fail("legado event_week=%s" % str(_game.get("event_week")))
		return
	if int(_game.get("event_clears")) != 0:
		_fail("legado event_clears=%s" % str(_game.get("event_clears")))
		return
	if bool(_game.get("event_claimed")):
		_fail("legado event_claimed deveria ser false")
		return
	if str(_game.get("club_name")) != "Corpo de Caçadores":
		_fail("legado club_name=%s" % str(_game.get("club_name")))
		return
	_pass("save sem chaves novas carrega default")


func _test_week_reset() -> void:
	_game.set("event_week", WeekEvent.week_id_from_unix(WEEK_A))
	_game.set("event_clears", 3)
	_game.set("event_claimed", true)
	_game.set("hunter_xp", 40)
	_game.call("sync_diario_calendar", WEEK_B)
	if int(_game.get("event_clears")) != 0:
		_fail("semana nova não zerou clears")
		return
	if bool(_game.get("event_claimed")):
		_fail("semana nova não zerou claimed")
		return
	if int(_game.get("event_week")) != WeekEvent.week_id_from_unix(WEEK_B):
		_fail("semana nova não trocou o id")
		return
	_pass("semana diferente zera o evento")


func _test_hub_instancia() -> void:
	var packed: PackedScene = load("res://scenes/main_menu/hub.tscn") as PackedScene
	if packed == null:
		_fail("hub.tscn não carregou")
		return
	var inst: Node = packed.instantiate()
	if inst == null:
		_fail("hub.tscn não instanciou")
		return
	if inst.get_script() == null:
		inst.queue_free()
		_fail("hub sem script")
		return
	if inst.get_node_or_null("%MissionsButton") == null:
		inst.queue_free()
		_fail("hub sem MISSÕES")
		return
	if inst.get_node_or_null("%NewsButton") == null or inst.get_node_or_null("%ClubButton") == null:
		inst.queue_free()
		_fail("hub sem coluna direita")
		return
	inst.queue_free()
	var src: GDScript = load("res://scripts/main_menu/hub.gd") as GDScript
	if src == null:
		_fail("hub.gd não parseou")
		return
	_pass("hub instancia e script parseia")


func _test_telas_instanciam() -> void:
	for path: String in [
		"res://scenes/ui/missions.tscn",
		"res://scenes/ui/news.tscn",
		"res://scenes/ui/events.tscn",
		"res://scenes/ui/club.tscn",
	]:
		var packed: PackedScene = load(path) as PackedScene
		if packed == null:
			_fail("%s não carregou" % path)
			return
		var inst: Node = packed.instantiate()
		if inst == null or inst.get_script() == null:
			if inst != null:
				inst.queue_free()
			_fail("%s não instanciou" % path)
			return
		inst.queue_free()
	_pass("telas de diário instanciam")


func _finish() -> void:
	_restore()
	print("=== smoke_diario ===")
	for m in _messages:
		print("  - ", m)
	if _ok:
		print("DIARIO PASS")
		quit(0)
	else:
		print("DIARIO FAIL")
		quit(1)
