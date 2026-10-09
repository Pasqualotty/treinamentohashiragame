extends SceneTree
## Smoke F5 (hub + mapa): placas com ícone próprio, XP com chrome, entrada estável,
## mapa sem título duplicado, chip de rótulo fora do medalhão, abas e fundo por mundo.
## Headless. NUNCA chama Game.save_game(): o progresso é setado só em memória.
## Uso: godot --headless --path . -s res://scripts/qa/smoke_f5_hub_mapa.gd

const HUB := "res://scenes/main_menu/hub.tscn"
const MAP := "res://scenes/world/world_map.tscn"
const PLATE_BUTTONS := ["ShopButton", "CharactersButton", "FriendsButton", "MultiplayerButton",
	"MissionsButton", "NewsButton", "ClubButton", "EventsButton"]

var _ok: bool = true
var _messages: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _fail(msg: String) -> void:
	_ok = false
	_messages.append("FAIL: " + msg)


func _pass(msg: String) -> void:
	_messages.append("ok: " + msg)


func _run() -> void:
	var game: Node = root.get_node_or_null("Game")
	if game == null:
		_fail("autoload Game ausente")
		_finish()
		return
	var saved_cleared: Array[String] = (game.get("stages_cleared") as Array[String]).duplicate()
	var saved_world: String = str(game.get("current_world_id"))
	await _check_hub()
	await _check_map(game)
	game.set("stages_cleared", saved_cleared)
	game.set("current_world_id", saved_world)
	_finish()


func _finish() -> void:
	for m in _messages:
		print(m)
	if _ok:
		print("=== F5 HUB_MAPA PASS ===")
	else:
		print("=== F5 HUB_MAPA FAIL ===")
	quit(0 if _ok else 1)


func _mount(path: String) -> Node:
	var packed := load(path) as PackedScene
	if packed == null:
		_fail("não carregou %s" % path)
		return null
	var inst: Node = packed.instantiate()
	root.add_child(inst)
	return inst


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


# --- Hub --------------------------------------------------------------------

func _plate_path(btn: Button) -> String:
	var sb: StyleBoxTexture = btn.get_theme_stylebox("normal") as StyleBoxTexture
	if sb == null or sb.texture == null:
		return ""
	return sb.texture.resource_path


func _check_hub() -> void:
	var hub: Node = await _mount(HUB)
	if hub == null:
		return
	await process_frame
	await _wait(1.2)
	_check_plates(hub)
	_check_xp(hub)
	await _check_entry_stable(hub)
	hub.queue_free()
	await process_frame


func _check_plates(hub: Node) -> void:
	var seen: Dictionary = {}
	for node_name: String in PLATE_BUTTONS:
		var btn: Button = hub.find_child(node_name, true, false) as Button
		if btn == null:
			_fail("hub sem %s" % node_name)
			continue
		var path: String = _plate_path(btn)
		if path == "":
			_fail("%s sem textura de placa" % node_name)
		elif seen.has(path):
			_fail("%s repete a placa de %s (%s)" % [node_name, seen[path], path])
		else:
			seen[path] = node_name
	for node_name: String in ["PlayButton", "SettingsButton"]:
		var other: Button = hub.find_child(node_name, true, false) as Button
		if other == null or _plate_path(other) == "":
			_fail("%s sem placa" % node_name)
	if seen.size() == PLATE_BUTTONS.size():
		_pass("8 placas laterais com textura distinta")


func _check_xp(hub: Node) -> void:
	var badge: Control = hub.find_child("XpLevelBadge", true, false) as Control
	var track: Control = hub.find_child("XpTrack", true, false) as Control
	var value: Label = hub.find_child("XpValueLabel", true, false) as Label
	if badge == null or track == null or value == null:
		_fail("XP sem badge/trilho/texto")
		return
	if track.size.x < 140.0:
		_fail("trilho de XP estreito: %s" % track.size.x)
	if not value.text.ends_with(" XP") or not value.text.contains(" / "):
		_fail("texto de XP inesperado: '%s'" % value.text)
	var settings: Control = hub.find_child("SettingsButton", true, false) as Control
	if settings != null and settings.get_global_rect().end.x > 1280.0:
		_fail("engrenagem fora de 1280: %s" % settings.get_global_rect().end.x)
	if _ok:
		_pass("XP com badge, trilho %.0f px e texto '%s'" % [track.size.x, value.text])


func _check_entry_stable(hub: Node) -> void:
	var before: Dictionary = {}
	for node_name: String in PLATE_BUTTONS:
		var btn: Button = hub.find_child(node_name, true, false) as Button
		if btn == null:
			continue
		if not is_equal_approx(btn.modulate.a, 1.0):
			_fail("%s não terminou o fade (a=%s)" % [node_name, btn.modulate.a])
		before[node_name] = btn.position
	await _wait(0.25)
	for node_name: String in before:
		var btn2: Button = hub.find_child(node_name, true, false) as Button
		if btn2.position != before[node_name]:
			_fail("%s se moveu depois da entrada" % node_name)
	_pass("placas opacas e posição final estável")


# --- Mapa -------------------------------------------------------------------

func _check_map(game: Node) -> void:
	var none: Array[String] = []
	game.set("stages_cleared", none)
	game.set("current_world_id", "w1")
	var map: Node = await _mount(MAP)
	if map == null:
		return
	await _wait(0.8)
	var title: Label = map.find_child("Title", true, false) as Label
	if title == null or title.text.begins_with("Mapa"):
		_fail("Title duplicado/ausente: '%s'" % (title.text if title else "null"))
	else:
		_pass("Title = '%s'" % title.text)
	_check_chips(map)
	_check_tabs(map)
	map.queue_free()
	await process_frame
	await _check_world_background(game)


func _check_chips(map: Node) -> void:
	var n: int = 0
	for view in map.find_children("MapNode_*", "Control", true, false):
		n += 1
		var medal: Rect2 = view.call("medal_rect")
		var chip: Rect2 = view.call("chip_rect")
		if medal.size.x < 80.0:
			_fail("%s: medalhão pequeno (%s)" % [view.name, medal.size])
		if chip.intersects(medal):
			_fail("%s: chip %s intercepta o medalhão %s" % [view.name, chip, medal])
	if n < 6:
		_fail("esperava >= 6 nós, veio %d" % n)
	else:
		_pass("%d nós com chip fora do medalhão" % n)
	for btn in map.find_children("StageButton_*", "Button", true, false):
		if btn.size.x < 84.0 or btn.size.y < 84.0:
			_fail("%s: área de toque < 84" % btn.name)


func _check_tabs(map: Node) -> void:
	var tabs: Array = map.find_children("WorldTab_*", "Button", true, false)
	if tabs.size() != 5:
		_fail("esperava 5 abas, veio %d" % tabs.size())
		return
	var w2: Button = map.find_child("WorldTab_w2", true, false) as Button
	if w2.find_child("LockGlyph", true, false) == null:
		_fail("aba trancada sem cadeado desenhado")
	_pass("5 abas, trancada com cadeado")


func _check_world_background(game: Node) -> void:
	var cleared: Array[String] = ["w1_boss"]
	game.set("stages_cleared", cleared)
	game.set("current_world_id", "w2")
	var map: Node = await _mount(MAP)
	if map == null:
		return
	await _wait(0.5)
	var art: TextureRect = map.find_child("MapArt", true, false) as TextureRect
	var path: String = art.texture.resource_path if art != null and art.texture != null else ""
	if not path.contains("w2"):
		_fail("fundo do W2 = '%s'" % path)
	else:
		_pass("fundo do W2 = %s" % path)
	# Cross-fade (sem apertar a aba: ela chamaria Game.save_game()): ao fim da troca
	# a camada da frente assume a textura nova e a de trás volta a 0.
	map.set("_world_id", "w3")
	map.call("_fade_backdrop")
	await _wait(0.6)
	var back: TextureRect = map.find_child("MapArtB", true, false) as TextureRect
	if not art.texture.resource_path.contains("w3"):
		_fail("cross-fade não assumiu w3: %s" % art.texture.resource_path)
	elif back != null and not is_equal_approx(back.modulate.a, 0.0):
		_fail("camada B ficou visível após o cross-fade (a=%s)" % back.modulate.a)
	else:
		_pass("cross-fade W2 -> W3 concluído")
	map.queue_free()
	await process_frame
