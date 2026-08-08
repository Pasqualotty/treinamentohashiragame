extends SceneTree
## Smoke headless: catálogo, compra/save, apply stats, carrega shop + world_map.
## Uso: godot --headless --path . -s res://scripts/ui/smoke_meta_loja_mapa.gd

const SHOP := "res://scenes/ui/shop.tscn"
const MAP := "res://scenes/world/world_map.tscn"
const CATALOG := "res://resources/upgrades/catalog.json"
## Save descartável: este smoke escreve save várias vezes e não pode encostar no
## save real do jogador (nem criá-lo em máquina/CI que ainda não tem um).
const TEMP_SAVE := "user://smoke_meta_loja_mapa_save.json"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var ok: bool = true
	var messages: Array[String] = []

	# 1) Catálogo JSON
	if not FileAccess.file_exists(CATALOG):
		ok = false
		messages.append("catalog.json ausente")
	else:
		var raw: String = FileAccess.get_file_as_string(CATALOG)
		var parsed: Variant = JSON.parse_string(raw)
		if typeof(parsed) != TYPE_DICTIONARY:
			ok = false
			messages.append("catalog.json inválido")
		else:
			var ups: Array = parsed.get("upgrades", [])
			if ups.size() != 4:
				ok = false
				messages.append("esperava 4 upgrades, got %d" % ups.size())
			else:
				messages.append("catalog OK (%d upgrades)" % ups.size())

	# Autoload Game (não usar identificador global em -s)
	var game: Node = root.get_node_or_null("Game")
	if game == null:
		ok = false
		messages.append("autoload Game ausente em /root/Game")
	else:
		game.call("set_save_path", TEMP_SAVE)
		if FileAccess.file_exists(TEMP_SAVE):
			DirAccess.remove_absolute(TEMP_SAVE)
		var prev_coins: int = int(game.get("coins_banked"))
		var prev_up: Dictionary = (game.get("upgrades") as Dictionary).duplicate(true)
		game.set("coins_banked", 500)
		game.set("upgrades", {})

		var catalog: Array = game.call("get_upgrade_catalog")
		if catalog.size() < 4:
			ok = false
			messages.append("get_upgrade_catalog size=%d" % catalog.size())
		else:
			var bought: bool = bool(game.call("buy_upgrade", "max_hp"))
			if not bought:
				ok = false
				messages.append("buy_upgrade max_hp falhou com 500 coins")
			elif int(game.call("get_upgrade_level", "max_hp")) != 1:
				ok = false
				messages.append("nível max_hp esperado 1")
			elif int(game.get("coins_banked")) != 470:
				ok = false
				messages.append("coins após compra: %s (esp 470)" % str(game.get("coins_banked")))
			else:
				messages.append("buy_upgrade + custo OK")

			var stats: Resource = game.call("build_player_stats") as Resource
			if stats == null:
				ok = false
				messages.append("build_player_stats null")
			else:
				var max_hp: float = float(stats.get("max_hp"))
				if max_hp < 109.9:
					ok = false
					messages.append("max_hp após upgrade: %s" % str(max_hp))
				else:
					messages.append("apply stats OK (max_hp=%.1f)" % max_hp)

			game.call("save_game")
			var save_path: String = str(game.call("get_save_path"))
			if not FileAccess.file_exists(save_path):
				ok = false
				messages.append("save.json não escrito em %s" % save_path)
			else:
				var save_txt: String = FileAccess.get_file_as_string(save_path)
				var save_data: Variant = JSON.parse_string(save_txt)
				if typeof(save_data) != TYPE_DICTIONARY:
					ok = false
					messages.append("save.json parse fail")
				else:
					var d: Dictionary = save_data
					for key in ["version", "coins_banked", "upgrades", "stages_cleared", "current_character_id"]:
						if not d.has(key):
							ok = false
							messages.append("save falta chave %s" % key)
					if d.has("upgrades") and typeof(d["upgrades"]) == TYPE_DICTIONARY:
						var u: Dictionary = d["upgrades"]
						if int(u.get("max_hp", 0)) != 1:
							ok = false
							messages.append("save upgrades.max_hp != 1")
						else:
							messages.append("save schema OK")

		game.set("coins_banked", prev_coins)
		game.set("upgrades", prev_up)
		# Devolve o save real e apaga o temporário: o estado em disco fica
		# idêntico ao de antes do smoke, mesmo em máquina sem save nenhum.
		game.call("set_save_path", "")
		if FileAccess.file_exists(TEMP_SAVE):
			DirAccess.remove_absolute(TEMP_SAVE)

	# 3) Cenas carregam
	for path in [SHOP, MAP]:
		var packed: PackedScene = load(path) as PackedScene
		if packed == null:
			ok = false
			messages.append("load fail: %s" % path)
			continue
		var inst: Node = packed.instantiate()
		if inst == null:
			ok = false
			messages.append("instantiate fail: %s" % path)
			continue
		root.add_child(inst)
		await process_frame
		await process_frame
		messages.append("scene smoke OK: %s" % path)
		inst.queue_free()
		await process_frame

	print("=== smoke_meta_loja_mapa ===")
	for m in messages:
		print("  - ", m)
	if ok:
		print("RESULT: PASS")
		quit(0)
	else:
		print("RESULT: FAIL")
		quit(1)
