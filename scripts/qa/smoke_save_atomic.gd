extends SceneTree
## Smoke: save atômico (tmp + rename) e save legado ainda carrega.
## NUNCA escreve em user://save.json — `Game.set_save_path` desvia pra um temp.
## Uso: godot --headless --path . -s res://scripts/qa/smoke_save_atomic.gd

const TEMP_SAVE := "user://smoke_save_atomic.json"

var _ok: bool = true
var _messages: Array[String] = []
var _game: Node = null
var _temp_active: bool = false
var _orig_name: String = ""
var _orig_coins: int = 0


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
	_test_helper_roundtrip()
	_test_legacy_plain_json_still_loads()
	_test_kill_during_tmp_keeps_dest()
	_test_game_save_leaves_valid_json()
	_test_truncated_dest_recovers_from_bak()
	_test_no_tmp_after_commit()
	_finish()


func _use_temp_save() -> void:
	_orig_name = str(_game.get("player_name"))
	_orig_coins = int(_game.get("coins_banked"))
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
	_game.set("player_name", _orig_name)
	_game.set("coins_banked", _orig_coins)
	_game.call("load_game")


func _wipe(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _test_helper_roundtrip() -> void:
	var payload := {"version": 1, "coins_banked": 77, "player_name": "Giyu"}
	if not AtomicJson.write_dict(TEMP_SAVE, payload):
		_fail("AtomicJson.write_dict recusou")
		return
	var parsed: Variant = AtomicJson.read_dict(TEMP_SAVE)
	if typeof(parsed) != TYPE_DICTIONARY:
		_fail("roundtrip não devolveu Dictionary")
		return
	var data: Dictionary = parsed
	if int(data.get("coins_banked", 0)) != 77:
		_fail("roundtrip coins=%s" % data.get("coins_banked"))
		return
	if str(data.get("player_name", "")) != "Giyu":
		_fail("roundtrip name=%s" % data.get("player_name"))
		return
	_pass("AtomicJson roundtrip")


func _test_legacy_plain_json_still_loads() -> void:
	_wipe(TEMP_SAVE)
	AtomicJson.remove_sidecars(TEMP_SAVE)
	var f := FileAccess.open(TEMP_SAVE, FileAccess.WRITE)
	if f == null:
		_fail("não abriu dest legado")
		return
	f.store_string('{"version":1,"coins_banked":12,"player_name":"Muichiro","current_character_id":"tanjiro","stages_cleared":["w1_01"],"upgrades":{}}')
	f.close()
	_game.call("load_game")
	if int(_game.get("coins_banked")) != 12:
		_fail("legado: coins=%s" % _game.get("coins_banked"))
		return
	if str(_game.get("player_name")) != "Muichiro":
		_fail("legado: name=%s" % _game.get("player_name"))
		return
	_pass("save legado (JSON direto no dest) ainda carrega")


func _test_kill_during_tmp_keeps_dest() -> void:
	var good := {"version": 1, "coins_banked": 40, "player_name": "Shinobu"}
	if not AtomicJson.write_dict(TEMP_SAVE, good):
		_fail("setup dest válido falhou")
		return
	var tmp := AtomicJson.tmp_path(TEMP_SAVE)
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		_fail("não abriu tmp truncado")
		return
	f.store_string('{"coins_banked":999,"player_na')
	f.close()
	var parsed: Variant = AtomicJson.read_dict(TEMP_SAVE)
	if typeof(parsed) != TYPE_DICTIONARY:
		_fail("kill no tmp: dest ficou ilegível")
		return
	var data: Dictionary = parsed
	if int(data.get("coins_banked", 0)) != 40:
		_fail("kill no tmp corrompeu dest (coins=%s)" % data.get("coins_banked"))
		return
	if str(data.get("player_name", "")) != "Shinobu":
		_fail("kill no tmp perdeu o nome")
		return
	_wipe(tmp)
	_pass("kill no meio do tmp não corrompe o dest")


func _test_game_save_leaves_valid_json() -> void:
	_game.set("coins_banked", 333)
	_game.set("player_name", "Rengoku")
	_game.call("save_game")
	if not FileAccess.file_exists(TEMP_SAVE):
		_fail("Game.save_game não criou dest")
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TEMP_SAVE))
	if typeof(parsed) != TYPE_DICTIONARY:
		_fail("Game.save_game deixou JSON inválido")
		return
	_game.set("coins_banked", 0)
	_game.set("player_name", "")
	_game.call("load_game")
	if int(_game.get("coins_banked")) != 333:
		_fail("Game.load após save: coins=%s" % _game.get("coins_banked"))
		return
	if str(_game.get("player_name")) != "Rengoku":
		_fail("Game.load após save: name=%s" % _game.get("player_name"))
		return
	_pass("Game.save_game / load_game roundtrip")


func _test_truncated_dest_recovers_from_bak() -> void:
	var bak := AtomicJson.bak_path(TEMP_SAVE)
	var bak_abs := ProjectSettings.globalize_path(bak)
	var good := '{"version":1,"coins_banked":5,"player_name":"Mitsuri"}'
	var bf := FileAccess.open(bak, FileAccess.WRITE)
	if bf == null:
		_fail("não abriu bak")
		return
	bf.store_string(good)
	bf.close()
	var dest := FileAccess.open(TEMP_SAVE, FileAccess.WRITE)
	if dest == null:
		_fail("não abriu dest truncado")
		return
	dest.store_string("{cortado")
	dest.close()
	var parsed: Variant = AtomicJson.read_dict(TEMP_SAVE)
	if typeof(parsed) != TYPE_DICTIONARY:
		_fail("dest cortado + bak válido: read_dict null")
		DirAccess.remove_absolute(bak_abs)
		return
	var data: Dictionary = parsed
	if int(data.get("coins_banked", 0)) != 5:
		_fail("não recuperou bak (coins=%s)" % data.get("coins_banked"))
	else:
		_pass("dest cortado recupera JSON do .bak")
	DirAccess.remove_absolute(bak_abs)


func _test_no_tmp_after_commit() -> void:
	if not AtomicJson.write_dict(TEMP_SAVE, {"version": 1, "coins_banked": 1}):
		_fail("commit final falhou")
		return
	if FileAccess.file_exists(AtomicJson.tmp_path(TEMP_SAVE)):
		_fail("tmp ficou pra trás depois do commit")
		return
	if FileAccess.file_exists(AtomicJson.bak_path(TEMP_SAVE)):
		_fail("bak ficou pra trás depois do commit")
		return
	_pass("commit limpa tmp e bak")


func _finish() -> void:
	_restore()
	print("=== smoke_save_atomic ===")
	for m in _messages:
		print("  - ", m)
	if _ok:
		print("SAVE_ATOMIC PASS")
		quit(0)
	else:
		print("SAVE_ATOMIC FAIL")
		quit(1)
