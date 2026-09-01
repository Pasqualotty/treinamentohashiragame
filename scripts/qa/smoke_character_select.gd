extends SceneTree
## Smoke do elenco: 14 ids, unlock, select recusa locked, persistência, player lê o kit.
## Nunca escreve em user://save.json — usa save temporário.
## Uso: godot --headless --path . -s res://scripts/qa/smoke_character_select.gd

const SELECT_SCENE := "res://scenes/ui/character_select.tscn"
const HUB := "res://scenes/main_menu/hub.tscn"
const PLAYER := "res://scenes/characters/player/player.tscn"
const TEMP_SAVE := "user://smoke_character_select_save.json"

var _ok: bool = true
var _messages: Array[String] = []
var _game: Node = null
var _temp_save_active: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _fail(msg: String) -> void:
	_ok = false
	_messages.append("FAIL: " + msg)


func _pass(msg: String) -> void:
	_messages.append("ok: " + msg)


func _run() -> void:
	_game = root.get_node_or_null("Game")
	var router: Node = root.get_node_or_null("SceneRouter")
	if _game == null:
		_fail("autoload Game ausente")
		_finish()
		return
	if router == null:
		_fail("autoload SceneRouter ausente")
		_finish()
		return

	_use_temp_save()
	_reset_progress()

	_test_catalog()
	_test_unlock_table()
	_test_select_and_persist()
	_test_legacy_save()
	_test_player_kit()
	await _test_scenes(router)
	_finish()


func _use_temp_save() -> void:
	_game.call("set_save_path", TEMP_SAVE)
	_temp_save_active = true
	_delete_temp_save()


func _restore_save() -> void:
	if not _temp_save_active:
		return
	_temp_save_active = false
	_delete_temp_save()
	if _game == null:
		return
	_game.call("set_save_path", "")
	_game.call("load_game")


func _delete_temp_save() -> void:
	if FileAccess.file_exists(TEMP_SAVE):
		DirAccess.remove_absolute(TEMP_SAVE)


func _reset_progress() -> void:
	_clear_string_array("stages_cleared")
	_clear_string_array("unlocked_characters")
	var unlocked: Array = _game.get("unlocked_characters")
	unlocked.append("tanjiro")
	_game.set("current_character_id", "tanjiro")
	_game.set("upgrades", {})
	_game.set("coins_banked", 0)
	_game.call("save_game")


func _clear_string_array(prop: String) -> void:
	var arr: Variant = _game.get(prop)
	if arr is Array:
		(arr as Array).clear()


func _test_catalog() -> void:
	var loaded: Array = CharacterCatalog.load_all()
	if loaded.size() != CharacterCatalog.EXPECTED_IDS.size():
		_fail("catálogo size=%d esperado %d" % [loaded.size(), CharacterCatalog.EXPECTED_IDS.size()])
		return
	var got: Array[String] = []
	for def: CharacterDef in loaded:
		got.append(def.id)
		if def.display_name == "":
			_fail("%s sem display_name" % def.id)
			return
		if def.skill_1_name == "" or def.skill_2_name == "" or def.ultimate_name == "":
			_fail("%s sem nomes de skill" % def.id)
			return
		var stats: PlayerStats = def.build_stats()
		if stats == null:
			_fail("%s build_stats null" % def.id)
			return
		if stats.skill_1_display_name != def.skill_1_name:
			_fail("%s skill_1 stats=%s def=%s" % [def.id, stats.skill_1_display_name, def.skill_1_name])
			return
	for expected: String in CharacterCatalog.EXPECTED_IDS:
		if expected not in got:
			_fail("id ausente no catálogo: %s" % expected)
			return
	if CharacterCatalog.find("tanjiro") == null or CharacterCatalog.find("muzan") == null:
		_fail("find tanjiro/muzan falhou")
		return
	if CharacterCatalog.find("nao_existe") != null:
		_fail("find inventou personagem")
		return
	_pass("catálogo 14 ids + kits")


func _test_unlock_table() -> void:
	var tanjiro: CharacterDef = CharacterCatalog.find("tanjiro")
	var zenitsu: CharacterDef = CharacterCatalog.find("zenitsu")
	var inosuke: CharacterDef = CharacterCatalog.find("inosuke")
	var empty: Array[String] = []
	if tanjiro == null or not tanjiro.is_unlocked(empty):
		_fail("Tanjiro deveria ser starter")
		return
	if zenitsu == null or zenitsu.is_unlocked(empty):
		_fail("Zenitsu unlocked sem w1_boss")
		return
	var w1: Array[String] = ["w1_boss"]
	if not zenitsu.is_unlocked(w1):
		_fail("Zenitsu locked com w1_boss")
		return
	if inosuke != null and inosuke.is_unlocked(w1):
		_fail("Inosuke unlocked só com w1_boss")
		return
	var w2: Array[String] = ["w1_boss", "w2_boss"]
	if inosuke == null or not inosuke.is_unlocked(w2):
		_fail("Inosuke locked com w2_boss")
		return
	if not bool(_game.call("is_character_unlocked", "tanjiro")):
		_fail("Game.is_character_unlocked(tanjiro) false no save novo")
		return
	if bool(_game.call("is_character_unlocked", "zenitsu")):
		_fail("Zenitsu unlocked no save novo")
		return
	_pass("unlock table (starter / locked / w1 / w2)")


func _test_select_and_persist() -> void:
	if bool(_game.call("select_character", "zenitsu")):
		_fail("select zenitsu aceitou locked")
		return
	if str(_game.get("current_character_id")) != "tanjiro":
		_fail("current_character_id mudou após recusa")
		return
	if not bool(_game.call("select_character", "tanjiro")):
		_fail("select tanjiro recusou starter")
		return

	_game.call("mark_stage_cleared", "w1_boss")
	if not bool(_game.call("is_character_unlocked", "zenitsu")):
		_fail("Zenitsu não liberou após w1_boss")
		return
	if not bool(_game.call("select_character", "zenitsu")):
		_fail("select zenitsu recusou após unlock")
		return
	if str(_game.get("current_character_id")) != "zenitsu":
		_fail("current_character_id != zenitsu")
		return

	var save_path: String = str(_game.call("get_save_path"))
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if typeof(parsed) != TYPE_DICTIONARY:
		_fail("save ilegível após select")
		return
	var data: Dictionary = parsed
	if str(data.get("current_character_id", "")) != "zenitsu":
		_fail("save current_character_id = %s" % str(data.get("current_character_id", "")))
		return
	var unlocked: Variant = data.get("unlocked_characters", [])
	if not (unlocked is Array) or not (unlocked as Array).has("zenitsu"):
		_fail("save unlocked_characters sem zenitsu")
		return

	_game.set("current_character_id", "tanjiro")
	_clear_string_array("unlocked_characters")
	(_game.get("unlocked_characters") as Array).append("tanjiro")
	_game.call("load_game")
	if str(_game.get("current_character_id")) != "zenitsu":
		_fail("load_game não restaurou zenitsu (veio %s)" % str(_game.get("current_character_id")))
		return
	if not bool(_game.call("is_character_unlocked", "zenitsu")):
		_fail("load_game perdeu zenitsu unlocked")
		return
	_pass("select recusa locked + round-trip save")


func _test_legacy_save() -> void:
	var save_path: String = str(_game.call("get_save_path"))
	var legacy := {
		"version": 1,
		"coins_banked": 0,
		"player_name": "Smoke",
		"current_character_id": "tanjiro",
		"stages_cleared": [],
		"upgrades": {},
	}
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(legacy))
	f = null
	_game.call("load_game")
	var unlocked: Array = _game.get("unlocked_characters")
	if "tanjiro" not in unlocked:
		_fail("legado sem lista não tem tanjiro")
		return
	if "zenitsu" in unlocked:
		_fail("legado sem clears liberou zenitsu")
		return
	_pass("save legado = só tanjiro")


func _test_player_kit() -> void:
	_game.call("mark_stage_cleared", "w1_boss")
	if not bool(_game.call("select_character", "zenitsu")):
		_fail("não conseguiu selecionar zenitsu pro player")
		return
	var packed: PackedScene = load(PLAYER) as PackedScene
	if packed == null:
		_fail("player.tscn não carregou")
		return
	var player: Node = packed.instantiate()
	root.add_child(player)
	var id_got: String = str(player.get("applied_character_id"))
	if id_got != "zenitsu":
		_fail("player.applied_character_id=%s" % id_got)
		player.queue_free()
		return
	var stats: Object = player.get("stats")
	if stats == null:
		_fail("player.stats null")
		player.queue_free()
		return
	var s1: String = str(stats.get("skill_1_display_name"))
	if s1 != "Relâmpago":
		_fail("player skill_1=%s (esperado Relâmpago)" % s1)
		player.queue_free()
		return
	var s2: String = str(stats.get("skill_2_display_name"))
	if s2 != "Passo do Trovão":
		_fail("player skill_2=%s" % s2)
		player.queue_free()
		return
	player.queue_free()
	_pass("player aplica kit do id salvo")


func _test_scenes(router: Node) -> void:
	var path: String = str(router.get("CHARACTER_SELECT"))
	if path != SELECT_SCENE:
		_fail("SceneRouter.CHARACTER_SELECT = %s" % path)
		return
	if not router.has_method("to_characters"):
		_fail("SceneRouter.to_characters ausente")
		return
	for p in [SELECT_SCENE, HUB]:
		var packed: PackedScene = load(p) as PackedScene
		if packed == null:
			_fail("cena não carregou: %s" % p)
			return
		var inst: Node = packed.instantiate()
		root.add_child(inst)
		await process_frame
		if p == SELECT_SCENE:
			var grid: Node = inst.find_child("Grid", true, false)
			if grid == null:
				_fail("character_select sem Grid")
				inst.queue_free()
				return
			if grid.get_child_count() != CharacterCatalog.EXPECTED_IDS.size():
				_fail("grid cards=%d esperado 14" % grid.get_child_count())
				inst.queue_free()
				return
		inst.queue_free()
	_pass("tela PERSONAGENS instancia 14 cards + hub")


func _finish() -> void:
	_restore_save()
	for line: String in _messages:
		print(line)
	if _ok:
		print("CHARACTER_SELECT PASS")
		quit(0)
	else:
		print("CHARACTER_SELECT FAIL")
		quit(1)
