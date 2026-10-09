extends SceneTree
## Smoke F4: chrome das 9 telas-meta (fundo vivo, Voltar padrão, título limpo),
## UiMotion (count_up exato, stagger termina opaco) e cortina de transição.
## NUNCA escreve em user://save.json (save temporário, apagado na saída).
## Uso: godot --headless --path . -s res://scripts/qa/smoke_f4_meta_screens.gd

const TEMP_SAVE := "user://smoke_f4_meta_screens_save.json"
## Scripts do chrome carregados por caminho (não por class_name): referenciar essas
## classes estaticamente aqui compilaria Palette antes dos autoloads existirem.
const TRANSITION := "res://scripts/ui/transition.gd"
const MOTION := "res://scripts/ui/ui_motion.gd"
const BACKDROP := "res://scripts/ui/meta_backdrop.gd"

## cena, variante de fundo esperada.
const SCREENS: Array = [
	["res://scenes/ui/shop.tscn", "shop"],
	["res://scenes/ui/character_select.tscn", "characters"],
	["res://scenes/ui/settings.tscn", "settings"],
	["res://scenes/ui/missions.tscn", "diario"],
	["res://scenes/ui/news.tscn", "diario"],
	["res://scenes/ui/club.tscn", "diario"],
	["res://scenes/ui/events.tscn", "diario"],
	["res://scenes/ui/credits.tscn", "credits"],
	["res://scenes/ui/name_entry.tscn", "name"],
]

var _ok: bool = true
var _messages: Array[String] = []
var _game: Node = null
var _orig_name: String = ""
var _save_swapped: bool = false


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
	if _game == null or router == null:
		_fail("autoloads Game/SceneRouter ausentes")
		_finish()
		return
	root.size = Vector2i(1280, 720)
	_orig_name = str(_game.get("player_name"))
	_game.call("set_save_path", TEMP_SAVE)
	_save_swapped = true
	router.set("name_entry_edit_mode", true)
	for entry in SCREENS:
		await _check_screen(str(entry[0]), str(entry[1]))
	router.set("name_entry_edit_mode", false)
	await _check_count_up()
	await _check_stagger()
	await _check_transition()
	_finish()


## --- Telas ---------------------------------------------------------------

func _check_screen(path: String, variant: String) -> void:
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		_fail("%s não carrega" % path)
		return
	var inst: Control = packed.instantiate() as Control
	root.add_child(inst)
	await process_frame
	await process_frame
	_check_backdrop(inst, path, variant)
	_check_back_button(inst, path)
	_check_title_clear(inst, path)
	inst.queue_free()
	await process_frame


func _check_backdrop(inst: Control, path: String, variant: String) -> void:
	var first: Node = inst.get_child(0) if inst.get_child_count() > 0 else null
	if first == null or first.get_script() != load(BACKDROP):
		_fail("%s: primeiro filho não é MetaBackdrop" % path)
		return
	if str(first.get("variant")) != variant:
		_fail("%s: variante %s, esperado %s" % [path, str(first.get("variant")), variant])
		return
	_pass("%s: MetaBackdrop(%s) é o primeiro filho" % [path, variant])


func _is_back_text(t: String) -> bool:
	return t.begins_with("←") or t.begins_with("Voltar")


func _collect_buttons(node: Node, out: Array) -> void:
	if node is Button and (node as Button).is_visible_in_tree():
		out.append(node)
	for child in node.get_children():
		_collect_buttons(child, out)


func _check_back_button(inst: Control, path: String) -> void:
	var buttons: Array = []
	_collect_buttons(inst, buttons)
	var backs: Array = []
	for b in buttons:
		if _is_back_text((b as Button).text):
			backs.append(b)
	if backs.size() != 1:
		_fail("%s: %d botões de voltar (esperado 1)" % [path, backs.size()])
		return
	var pos: Vector2 = (backs[0] as Button).global_position
	if pos.y <= 600.0 or pos.x >= 320.0:
		_fail("%s: Voltar em (%.0f, %.0f), fora do canto inferior-esquerdo" % [path, pos.x, pos.y])
		return
	_pass("%s: Voltar em (%.0f, %.0f)" % [path, pos.x, pos.y])


func _find_title(inst: Control) -> Label:
	var title: Node = inst.find_child("Title", true, false)
	if title == null:
		title = inst.find_child("TitleLabel", true, false)
	return title as Label


func _collect_labels(node: Node, out: Array) -> void:
	if node is Label and (node as Label).is_visible_in_tree():
		out.append(node)
	for child in node.get_children():
		_collect_labels(child, out)


func _check_title_clear(inst: Control, path: String) -> void:
	var title: Label = _find_title(inst)
	if title == null:
		_fail("%s: sem título" % path)
		return
	var rect: Rect2 = title.get_global_rect()
	var labels: Array = []
	_collect_labels(inst, labels)
	for lab in labels:
		if lab == title or (lab as Label).text.is_empty():
			continue
		if rect.intersects((lab as Label).get_global_rect()):
			_fail("%s: label '%s' intercepta o título" % [path, (lab as Label).text.left(24)])
			return
	_pass("%s: título livre" % path)


## --- UiMotion ------------------------------------------------------------

func _check_count_up() -> void:
	var lab := Label.new()
	root.add_child(lab)
	var motion: GDScript = load(MOTION)
	motion.count_up(lab, 10, 137, 0.3, "🪙 %d")
	await create_timer(0.6).timeout
	if lab.text != "🪙 137":
		_fail("count_up terminou em '%s'" % lab.text)
	else:
		_pass("count_up termina exatamente em 137")
	motion.count_up(lab, 137, 5, 0.0, "%d")
	if lab.text != "5":
		_fail("count_up dur=0 deu '%s'" % lab.text)
	lab.queue_free()


func _check_stagger() -> void:
	var box := VBoxContainer.new()
	root.add_child(box)
	var items: Array = []
	for i in 6:
		var c := ColorRect.new()
		c.custom_minimum_size = Vector2(40, 20)
		box.add_child(c)
		items.append(c)
	var motion: GDScript = load(MOTION)
	motion.enter_stagger(items, 0.05, 16.0)
	await create_timer(1.0).timeout
	var all_opaque := true
	for c in items:
		if not is_equal_approx((c as Control).modulate.a, 1.0):
			all_opaque = false
	if not all_opaque:
		_fail("enter_stagger deixou item translúcido")
	else:
		_pass("enter_stagger termina com modulate.a == 1.0")
	box.queue_free()


## --- Transição -----------------------------------------------------------

func _check_transition() -> void:
	var tr: CanvasLayer = (load(TRANSITION) as GDScript).new()
	root.add_child(tr)
	await process_frame
	var t0: int = Time.get_ticks_msec()
	await tr.close()
	var close_ms: int = Time.get_ticks_msec() - t0
	t0 = Time.get_ticks_msec()
	await tr.open()
	var open_ms: int = Time.get_ticks_msec() - t0
	if close_ms >= 1000 or open_ms >= 1000:
		_fail("transição lenta: close=%dms open=%dms" % [close_ms, open_ms])
	else:
		_pass("transição: close=%dms open=%dms" % [close_ms, open_ms])
	if tr.is_busy():
		_fail("is_busy() true sem set_busy")
	tr.set_busy(true)
	if not tr.is_busy():
		_fail("set_busy(true) não pegou")
	tr.queue_free()


## --- Saída ---------------------------------------------------------------

func _finish() -> void:
	if _save_swapped and _game != null:
		_game.call("set_save_path", "")
		_game.set("player_name", _orig_name)
		_game.call("load_game")
	if FileAccess.file_exists(TEMP_SAVE):
		DirAccess.remove_absolute(TEMP_SAVE)
	for m in _messages:
		print(m)
	if _ok:
		print("=== F4 META_SCREENS PASS ===")
		quit(0)
	else:
		print("=== F4 META_SCREENS FAIL ===")
		quit(1)
