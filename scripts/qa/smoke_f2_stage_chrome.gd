extends SceneTree
## Smoke F2 (headless): chrome da fase — sem sobreposição no HUD, sem label duplicado,
## spawn fora do joystick, portal próprio, HUD com onis + rastro de dano, cerimônias.
## Uso: godot --headless --path . -s res://scripts/qa/smoke_f2_stage_chrome.gd

const STAGE := "res://scenes/battle/stage_w1_01.tscn"

## Carregados em runtime: referenciar o class_name direto compila antes dos autoloads
## (Palette) existirem no modo `-s`.
var _chrome: GDScript
var _card: GDScript
var _fails: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_chrome = load("res://scripts/ui/stage_chrome.gd")
	_card = load("res://scripts/ui/ceremony_card.gd")
	_chrome.force_touch = 1
	var stage: Node = await _load_stage()
	if stage == null:
		_fail("fase não carregou")
		_finish()
		return
	_check_player_spawn(stage)
	_check_goal(stage)
	_check_no_duplicate_wave_label(stage)
	_check_no_overlay_hint(stage)
	await _check_hud(stage)
	await _check_cards(stage)
	_check_helpers()
	stage.queue_free()
	await process_frame
	await _check_desktop_hint()
	_finish()


func _load_stage() -> Node:
	var packed := load(STAGE) as PackedScene
	if packed == null:
		return null
	var inst: Node = packed.instantiate()
	root.add_child(inst)
	for i in 6:
		await process_frame
	return inst


func _check_player_spawn(stage: Node) -> void:
	var players := get_nodes_in_group("player")
	if players.is_empty():
		_fail("sem player")
		return
	var x: float = (players[0] as Node2D).global_position.x
	if x < 380.0:
		_fail("player nasceu em x=%.0f (< 380, embaixo do joystick)" % x)


func _check_goal(stage: Node) -> void:
	var goal := stage.get_node_or_null("Goal")
	if goal == null:
		_fail("sem Goal")
		return
	for n: String in ["PortalGlow", "PortalVisual", "Label"]:
		var c := goal.get_node_or_null(n) as CanvasItem
		if c != null and c.visible:
			_fail("Goal/%s ainda visível" % n)
	for n: String in ["PortalChip", "PortalAura", "PortalSparks"]:
		if goal.get_node_or_null(n) == null:
			_fail("Goal sem visual próprio: %s" % n)
	if not goal.has_method("is_locked") or not goal.is_locked():
		_fail("Goal deveria nascer trancado")
	goal.set_locked(false)
	if goal.is_locked():
		_fail("set_locked(false) não destrancou")
	goal.set_locked(true)


func _check_no_duplicate_wave_label(stage: Node) -> void:
	for l: Label in _labels(stage):
		if l.text.begins_with("Onda "):
			_fail("label de onda duplicado: '%s'" % l.text)
	if stage.find_child("WaveHud", true, false) != null:
		_fail("WaveHud antigo ainda existe")


func _check_no_overlay_hint(stage: Node) -> void:
	for l: Label in _labels(stage):
		var hint: bool = l.text.contains("A/D mover") or l.text.contains("Elimine as ondas")
		if hint and l.global_position.y < 560.0:
			_fail("dica sobre a área do HUD (y=%.0f): '%s'" % [l.global_position.y, l.text])
	if stage.find_child("BackToMap", true, false) != null:
		_fail("botão Mapa ainda existe")


func _check_hud(stage: Node) -> void:
	var hud: CanvasLayer = null
	for c in stage.get_children():
		if c is CanvasLayer and c.has_method("set_wave"):
			hud = c
	if hud == null:
		_fail("sem CombatHud")
		return
	hud.set_wave(1, 3, 2)
	var wl := hud.find_child("WaveLabel", true, false) as Label
	if wl == null or not wl.text.contains("1/3") or not wl.text.contains("2"):
		_fail("chip de onda: '%s'" % (wl.text if wl else "null"))
	hud.set_wave(2, 3)
	if wl != null and wl.text.contains("onis"):
		_fail("set_wave de 2 args não deve mostrar onis")
	hud.set_hp(100.0, 100.0)
	hud.set_hp(40.0, 100.0)
	if hud.get_trail_value() <= 40.0:
		_fail("rastro caiu junto com a vida (%.1f)" % hud.get_trail_value())
	await create_timer(1.2).timeout
	if absf(hud.get_trail_value() - 40.0) > 1.5:
		_fail("rastro não alcançou 40 (%.1f)" % hud.get_trail_value())
	if hud.find_child("BreathTicks", true, false) == null:
		_fail("sem ticks na barra de respiração")


func _check_cards(stage: Node) -> void:
	var card: CanvasLayer = _card.new()
	stage.add_child(card)
	if not card.has_method("play_wave") or not card.has_method("play_clear"):
		_fail("CeremonyCard sem play_wave/play_clear")
		return
	card.play_wave(2, 3)
	var card2: CanvasLayer = _card.new()
	stage.add_child(card2)
	card2.play_clear(12, 15)
	await process_frame
	await process_frame
	if not _card.is_headless():
		_fail("is_headless() deveria ser true neste smoke")


func _check_helpers() -> void:
	if _chrome.spawn_x(160.0, true) != _chrome.SPAWN_MIN_X:
		_fail("spawn_x toque")
	if _chrome.spawn_x(160.0, false) != 160.0:
		_fail("spawn_x desktop")
	if _chrome.spawn_x(900.0, true) != 900.0:
		_fail("spawn_x já à direita")


func _check_desktop_hint() -> void:
	_chrome.force_touch = 0
	var host := Node.new()
	root.add_child(host)
	var layer: CanvasLayer = _chrome.build_controls_hint(host)
	if layer == null:
		_fail("desktop sem dica de teclado")
	else:
		var lbl := layer.get_child(0) as Label
		if lbl == null or lbl.offset_top < 640.0:
			_fail("dica de teclado fora da base da tela")
		if lbl != null and lbl.get_theme_font_size("font_size") != 14:
			_fail("dica deve ser fonte 14")
	_chrome.force_touch = 1
	if _chrome.build_controls_hint(host) != null:
		_fail("toque não deve ter dica de teclado")
	host.queue_free()


func _labels(n: Node) -> Array[Label]:
	var out: Array[Label] = []
	if n is Label:
		out.append(n)
	for c in n.get_children():
		out.append_array(_labels(c))
	return out


func _fail(msg: String) -> void:
	_fails.append(msg)
	print("FAIL: ", msg)


func _finish() -> void:
	_chrome.force_touch = -1
	if _fails.is_empty():
		print("=== F2 STAGE_CHROME PASS ===")
		quit(0)
	else:
		print("=== F2 STAGE_CHROME FAIL === (%d)" % _fails.size())
		quit(1)
