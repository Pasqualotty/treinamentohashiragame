extends SceneTree
## Smoke headless: geometria dos controles touch de combate, em várias resoluções.
##
## O projeto usa `window/stretch/aspect="expand"`, então o retângulo visível muda
## de forma conforme o aparelho (2400x1080 vira 1600x720; 2048x1536 vira 1280x960).
## Validar só em 16:9 é validar a única resolução em que ancorar no design dá o
## mesmo resultado que ancorar no viewport — por isso o smoke roda o mesmo bloco de
## asserts em 16:9, 20:9 e 4:3, e mede tudo contra `get_visible_rect()`, nunca
## contra `design_size`.
##
## Além da geometria, confirma que um toque real dispara a ação: é o que prova que
## a área de toque coincide com o disco desenhado.
##
## Uso: godot --headless --path . -s res://scripts/qa/smoke_touch_layout.gd

const TOUCH_SCENE := "res://scenes/ui/combat_touch_controls.tscn"
const ICONS_DIR := "res://assets/ui/touch/icons"
const EXPECTED_ACTIONS: PackedStringArray = [
	"attack_basic", "ultimate", "skill_1", "skill_2", "jump", "advance", "pause",
]
const ICON_SIZE := 256

## Regras duras do layout, afirmadas aqui de forma independente da implementação.
const MIN_EDGE_GAP := 12.0
## Tolerância ao comparar bordas com a margem de segurança.
const EPS := 1.0
## Folga para o ease-back do release terminar entre um toque e o próximo.
const RELEASE_SETTLE_SEC := 0.18

## Janelas de teste. O retângulo visível resultante vem do stretch do projeto.
## 18:9 e 19.5:9 são os celulares reais mais comuns além do 20:9 já coberto.
const RESOLUTIONS: Array[Dictionary] = [
	{"label": "16:9 1280x720", "window": Vector2i(1280, 720)},
	{"label": "18:9 2160x1080", "window": Vector2i(2160, 1080)},
	{"label": "19.5:9 2340x1080", "window": Vector2i(2340, 1080)},
	{"label": "20:9 2400x1080 (Android)", "window": Vector2i(2400, 1080)},
	{"label": "4:3 2048x1536 (tablet)", "window": Vector2i(2048, 1536)},
]

var _failures: Array[String] = []
var _notes: Array[String] = []
var _ctx: String = ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed: PackedScene = load(TOUCH_SCENE) as PackedScene
	if packed == null:
		_fail("load falhou: %s" % TOUCH_SCENE)
		_report()
		return
	var node: CanvasLayer = packed.instantiate() as CanvasLayer
	if node == null:
		_fail("instantiate falhou: %s" % TOUCH_SCENE)
		_report()
		return

	root.add_child(node)
	await process_frame
	await process_frame

	# Arte não depende de resolução: confere uma vez só.
	_ctx = "arte"
	_check_icons()

	for res: Dictionary in RESOLUTIONS:
		_ctx = String(res["label"])
		root.size = res["window"]
		# Duas passadas: uma para o viewport reagir, outra para o rebuild assentar.
		await process_frame
		await process_frame

		var viewport_size: Vector2 = root.get_visible_rect().size
		_notes.append("%s -> viewport visivel %dx%d" % [_ctx, int(viewport_size.x), int(viewport_size.y)])

		var applied: Vector2 = node.call("get_layout_size")
		if not applied.is_equal_approx(viewport_size):
			_fail(
				"layout ancorado em %s mas o viewport visivel e %s (nao reancorou)"
				% [applied, viewport_size]
			)

		var slots: Array = node.call("get_layout_slots")
		_check_slots(node, slots, viewport_size)
		_check_anchored_to_corners(node, slots, viewport_size)
		_check_thumb_zones(slots, viewport_size)
		_check_nodes(node)
		await _check_touch_alignment(slots, root.get_final_transform())

	_ctx = "input atravessando resize"
	await _check_keyboard_survives_resize(node)
	await _check_stick_released_on_resize(node)
	await _check_focus_out_does_not_disarm_guard(node)
	await _check_keyboard_survives_stick_release(node)

	node.queue_free()
	await process_frame
	_report()


# ---------------------------------------------------------------------------
# input atravessando o resize (rotação de tela)
# ---------------------------------------------------------------------------
func _check_keyboard_survives_resize(node: CanvasLayer) -> void:
	## Tecla segurada tem de sobreviver ao resize. As move_* têm binding de teclado
	## (A/D/W/S + setas); um `Input.action_release()` incondicional no rebuild mata a
	## tecla que o jogador está segurando e o personagem para até soltar e reapertar
	## (no Godot 4 `action_release` limpa device_states e o echo não re-pressiona).
	await _set_window(Vector2i(1280, 720))
	Input.action_press("move_right")
	await process_frame
	if not Input.is_action_pressed("move_right"):
		_fail("setup: action_press(move_right) não pegou")
		Input.action_release("move_right")
		return

	await _set_window(Vector2i(2400, 1080))
	if not node.call("get_layout_size").is_equal_approx(root.get_visible_rect().size):
		_fail("setup: rebuild não aconteceu no resize")
	if Input.is_action_pressed("move_right"):
		_notes.append("teclado sobreviveu ao resize (move_right seguiu pressionada)")
	else:
		_fail("move_right foi liberada pelo resize com a tecla ainda segurada")
	Input.action_release("move_right")
	await process_frame


func _check_stick_released_on_resize(node: CanvasLayer) -> void:
	## O simétrico: com o dedo no stick, o resize destrói o VirtualJoystick, que não
	## se libera sozinho — aí move_* PRECISA ser liberada, senão fica presa pra sempre.
	await _set_window(Vector2i(1280, 720))
	if not await _grab_stick(node):
		return

	await _set_window(Vector2i(2400, 1080))
	if Input.is_action_pressed("move_right"):
		_fail("stick ativo destruído no resize deixou move_right presa")
	else:
		_notes.append("stick ativo liberou move_right ao ser reconstruído")
	await _drop_stick()


func _check_focus_out_does_not_disarm_guard(node: CanvasLayer) -> void:
	## A cadeia que desarmava o guard:
	##   1. dedo no stick (posse do stick, move_right pressionada)
	##   2. FOCUS_OUT -> _release_all() solta a action
	##   3. o dedo CONTINUA arrastando -> o stick re-pressiona move_right
	##   4. resize -> se a posse tivesse morrido no passo 2, o rebuild pularia o
	##      release e move_right ficaria presa pra sempre
	## O nó do stick sobrevive ao focus-out, então a posse tem de sobreviver junto.
	await _set_window(Vector2i(1280, 720))
	if not await _grab_stick(node):
		return

	node.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	await process_frame

	# Passo 3: o dedo não saiu da tela — o stick volta a empurrar a action.
	_drag_stick()
	await process_frame
	if not Input.is_action_pressed("move_right"):
		_notes.append("focus-out: stick não re-pressionou move_right — cadeia não reproduzida")
		await _drop_stick()
		return

	await _set_window(Vector2i(2400, 1080))
	if Input.is_action_pressed("move_right"):
		_fail("focus-out desarmou a posse: move_right ficou presa após o resize")
	else:
		_notes.append("focus-out não desarmou o guard (move_right liberada no rebuild)")
	await _drop_stick()


func _check_keyboard_survives_stick_release(node: CanvasLayer) -> void:
	## Caso misto: stick empurrando um eixo e TECLA FÍSICA segurando outro. O release
	## do rebuild não pode levar a tecla junto — o VirtualJoystick da 4.7 não expõe o
	## próprio output, então a posse por eixo vem do teclado do SO, não do stick.
	await _set_window(Vector2i(1280, 720))
	var keycode: int = _first_physical_keycode("move_up")
	if keycode == 0:
		_notes.append("move_up sem binding de tecla física — caso misto pulado")
		return
	if not await _grab_stick(node):
		return

	_press_physical_key(keycode, true)
	await process_frame
	if not Input.is_action_pressed("move_up"):
		_notes.append("tecla física de move_up não pegou no headless — caso misto pulado")
		_press_physical_key(keycode, false)
		await _drop_stick()
		return

	await _set_window(Vector2i(2400, 1080))
	if Input.is_action_pressed("move_up"):
		_notes.append("caso misto: stick liberado sem matar a tecla de move_up")
	else:
		_fail("release do rebuild matou move_up, que estava presa por tecla física")
	if Input.is_action_pressed("move_right"):
		_fail("caso misto: move_right do stick ficou presa após o resize")
	_press_physical_key(keycode, false)
	await _drop_stick()


# --- helpers de stick / teclado -------------------------------------------
var _stick_center := Vector2.ZERO
var _stick_radius := 0.0


func _grab_stick(node: CanvasLayer) -> bool:
	var stick_slot: Dictionary = _find_slot(node.call("get_layout_slots"), "virtual_stick")
	if stick_slot.is_empty():
		return false
	_stick_center = stick_slot["center"]
	_stick_radius = float(stick_slot["radius"])

	var down := InputEventScreenTouch.new()
	down.index = 1
	down.position = root.get_final_transform() * _stick_center
	down.pressed = true
	root.push_input(down)
	_drag_stick()
	await process_frame

	if not Input.is_action_pressed("move_right"):
		_notes.append("stick não ativou move_right no headless — caso pulado")
		await _drop_stick()
		return false
	return true


func _drag_stick() -> void:
	var offset := Vector2(_stick_radius * 0.8, 0.0)
	var drag := InputEventScreenDrag.new()
	drag.index = 1
	drag.position = root.get_final_transform() * (_stick_center + offset)
	drag.relative = offset
	root.push_input(drag)


func _drop_stick() -> void:
	_release_touch(1, root.get_final_transform() * _stick_center)
	await process_frame
	for action in ["move_right", "move_left", "move_up", "move_down"]:
		if Input.is_action_pressed(action):
			Input.action_release(action)


func _first_physical_keycode(action: String) -> int:
	for event: InputEvent in InputMap.action_get_events(action):
		var key := event as InputEventKey
		if key != null and key.physical_keycode != 0:
			return key.physical_keycode
	return 0


func _press_physical_key(keycode: int, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _release_touch(index: int, at: Vector2) -> void:
	var up := InputEventScreenTouch.new()
	up.index = index
	up.position = at
	up.pressed = false
	root.push_input(up)


func _set_window(window: Vector2i) -> void:
	root.size = window
	await process_frame
	await process_frame


# ---------------------------------------------------------------------------
# arte
# ---------------------------------------------------------------------------
func _check_icons() -> void:
	## Arte própria por ação: normal + pressed existem, têm 256x256 e diferem.
	for action in EXPECTED_ACTIONS:
		var normal_path := "%s/%s.png" % [ICONS_DIR, action]
		var pressed_path := "%s/%s_pressed.png" % [ICONS_DIR, action]
		var normal_tex: Texture2D = _load_texture(normal_path)
		var pressed_tex: Texture2D = _load_texture(pressed_path)
		if normal_tex == null or pressed_tex == null:
			continue
		for pair in [[normal_path, normal_tex], [pressed_path, pressed_tex]]:
			var tex: Texture2D = pair[1] as Texture2D
			if tex.get_width() != ICON_SIZE or tex.get_height() != ICON_SIZE:
				_fail(
					"%s: esperado %dx%d, got %dx%d"
					% [pair[0], ICON_SIZE, ICON_SIZE, tex.get_width(), tex.get_height()]
				)
		var diff: float = _mean_abs_diff(normal_tex, pressed_tex)
		if diff < 6.0:
			_fail("%s: estado pressed quase idêntico ao normal (diff=%.2f)" % [action, diff])
		else:
			_notes.append("icone %s ok (pressed diff=%.1f)" % [action, diff])


func _load_texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		_fail("textura ausente: %s" % path)
		return null
	var tex: Texture2D = load(path) as Texture2D
	if tex == null:
		_fail("textura não carregou: %s" % path)
	return tex


func _mean_abs_diff(a: Texture2D, b: Texture2D) -> float:
	var ia: Image = a.get_image()
	var ib: Image = b.get_image()
	if ia == null or ib == null or ia.get_size() != ib.get_size():
		return 0.0
	var step := 8
	var total := 0.0
	var count := 0
	for y in range(0, ia.get_height(), step):
		for x in range(0, ia.get_width(), step):
			var ca: Color = ia.get_pixel(x, y)
			var cb: Color = ib.get_pixel(x, y)
			total += (absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b)) * 255.0 / 3.0
			count += 1
	if count == 0:
		return 0.0
	return total / float(count)


# ---------------------------------------------------------------------------
# geometria
# ---------------------------------------------------------------------------
func _check_slots(node: CanvasLayer, slots: Array, viewport_size: Vector2) -> void:
	var expected_count: int = EXPECTED_ACTIONS.size() + 1  # + stick virtual
	if slots.size() != expected_count:
		_fail("get_layout_slots(): %d slots, esperado %d" % [slots.size(), expected_count])
		return

	var margin: float = float(node.get("safe_margin"))
	var hud_band: float = float(node.get("hud_band_height"))

	var seen: Dictionary = {}
	for slot: Dictionary in slots:
		var id: String = String(slot["id"])
		var center: Vector2 = slot["center"]
		var radius: float = float(slot["radius"])
		if seen.has(id):
			_fail("slot duplicado: %s" % id)
		seen[id] = true

		if radius <= 0.0:
			_fail("%s: raio inválido (%.1f)" % [id, radius])
			continue

		# Dentro da margem de segurança do viewport REAL (logo, dentro da tela).
		var left: float = center.x - radius
		var right: float = center.x + radius
		var top: float = center.y - radius
		var bottom: float = center.y + radius
		if left < margin - EPS or top < margin - EPS:
			_fail("%s: fora da margem (topo-esq %.1f,%.1f < %.1f)" % [id, left, top, margin])
		if right > viewport_size.x - margin + EPS or bottom > viewport_size.y - margin + EPS:
			_fail(
				"%s: fora da margem (baixo-dir %.1f,%.1f > %.1f,%.1f)"
				% [id, right, bottom, viewport_size.x - margin, viewport_size.y - margin]
			)

		# Não invade a faixa do HUD superior.
		if top < hud_band - EPS:
			_fail("%s: invade a faixa do HUD (topo %.1f < %.1f)" % [id, top, hud_band])

	for action in EXPECTED_ACTIONS:
		if not seen.has(action):
			_fail("ação sem slot de layout: %s" % action)
	if not seen.has("virtual_stick"):
		_fail("stick virtual sem slot de layout")

	# Nenhum par pode se sobrepor: folga real entre bordas >= MIN_EDGE_GAP.
	var worst_gap := INF
	var worst_pair := ""
	for i in range(slots.size()):
		for j in range(i + 1, slots.size()):
			var a: Dictionary = slots[i]
			var b: Dictionary = slots[j]
			var ca: Vector2 = a["center"]
			var cb: Vector2 = b["center"]
			var gap: float = ca.distance_to(cb) - float(a["radius"]) - float(b["radius"])
			if gap < worst_gap:
				worst_gap = gap
				worst_pair = "%s/%s" % [a["id"], b["id"]]
			if gap < MIN_EDGE_GAP - 0.01:
				_fail(
					"sobreposição/folga curta %s ↔ %s: %.1fpx (mín %.1f)"
					% [a["id"], b["id"], gap, MIN_EDGE_GAP]
				)
	_notes.append("%s -> menor folga entre bordas: %.1fpx (%s)" % [_ctx, worst_gap, worst_pair])


func _check_anchored_to_corners(node: CanvasLayer, slots: Array, viewport_size: Vector2) -> void:
	## Âncoras ENCOSTADAS no canto do viewport, não só "dentro dele".
	##
	## É esta checagem que pega ancoragem em `design_size`: num viewport 1600x720 o
	## cluster ficaria a 352px da borda direita e ainda assim estaria "dentro da
	## margem". O ponto da frente é o descanso natural do polegar — o cluster tem de
	## morar no canto de verdade.
	var margin: float = float(node.get("safe_margin"))
	var expected: Array[Dictionary] = [
		{"id": "attack_basic", "edge": "direita", "actual_fn": "right"},
		{"id": "attack_basic", "edge": "inferior", "actual_fn": "bottom"},
		{"id": "virtual_stick", "edge": "esquerda", "actual_fn": "left"},
		{"id": "virtual_stick", "edge": "inferior", "actual_fn": "bottom"},
		{"id": "pause", "edge": "direita", "actual_fn": "right"},
	]
	for check: Dictionary in expected:
		var slot: Dictionary = _find_slot(slots, String(check["id"]))
		if slot.is_empty():
			continue
		var center: Vector2 = slot["center"]
		var radius: float = float(slot["radius"])
		var distance := 0.0
		match String(check["actual_fn"]):
			"right":
				distance = viewport_size.x - (center.x + radius)
			"bottom":
				distance = viewport_size.y - (center.y + radius)
			"left":
				distance = center.x - radius
		if absf(distance - margin) > EPS:
			_fail(
				"%s: borda %s a %.1fpx do viewport, esperado %.1f (âncora não seguiu o viewport)"
				% [check["id"], check["edge"], distance, margin]
			)


func _check_thumb_zones(slots: Array, viewport_size: Vector2) -> void:
	## Polegares: stick na metade esquerda, ataque na direita, folga mínima da borda.
	var mid_x: float = viewport_size.x * 0.5
	var stick: Dictionary = _find_slot(slots, "virtual_stick")
	var attack: Dictionary = _find_slot(slots, "attack_basic")
	if stick.is_empty() or attack.is_empty():
		return
	var stick_c: Vector2 = stick["center"]
	var atk_c: Vector2 = attack["center"]
	if stick_c.x >= mid_x:
		_fail("stick fora da zona esquerda (x=%.1f, meio=%.1f)" % [stick_c.x, mid_x])
	if atk_c.x <= mid_x:
		_fail("ataque fora da zona direita (x=%.1f, meio=%.1f)" % [atk_c.x, mid_x])
	var stick_left: float = stick_c.x - float(stick["radius"])
	var atk_right: float = atk_c.x + float(attack["radius"])
	if stick_left < MIN_EDGE_GAP - EPS:
		_fail("stick colado na borda (left=%.1f < %.1f)" % [stick_left, MIN_EDGE_GAP])
	if viewport_size.x - atk_right < MIN_EDGE_GAP - EPS:
		_fail("ataque colado na borda (gap=%.1f < %.1f)" % [viewport_size.x - atk_right, MIN_EDGE_GAP])
	_notes.append("%s -> polegares L/R ok (stick x=%.0f, atk x=%.0f)" % [_ctx, stick_c.x, atk_c.x])


func _find_slot(slots: Array, id: String) -> Dictionary:
	for slot: Dictionary in slots:
		if String(slot["id"]) == id:
			return slot
	_fail("slot ausente: %s" % id)
	return {}


func _check_nodes(node: CanvasLayer) -> void:
	## Cada slot de ação tem um TouchScreenButton com action, arte e forma redonda
	## alinhada ao centro geométrico declarado.
	var touch_root: Node = node.get_node_or_null("TouchRoot")
	if touch_root == null:
		_fail("TouchRoot ausente")
		return
	var slots: Array = node.call("get_layout_slots")
	for action in EXPECTED_ACTIONS:
		var btn: TouchScreenButton = touch_root.get_node_or_null("Btn_%s" % action) as TouchScreenButton
		if btn == null:
			_fail("Btn_%s ausente ou não é TouchScreenButton" % action)
			continue
		if String(btn.action) != action:
			_fail("Btn_%s: action='%s'" % [action, btn.action])
		if btn.texture_normal == null or btn.texture_pressed == null:
			_fail("Btn_%s: sem textura normal/pressed" % action)
		if not btn.shape_centered:
			_fail("Btn_%s: shape_centered=false desalinha toque e arte" % action)
		var circle: CircleShape2D = btn.shape as CircleShape2D
		if circle == null:
			_fail("Btn_%s: forma não é CircleShape2D" % action)
			continue
		# A forma vive no espaço local do nó: raio efetivo = raio * escala.
		var effective_radius: float = circle.radius * btn.scale.x
		var slot: Dictionary = _find_slot(slots, action)
		if slot.is_empty():
			continue
		var declared: float = float(slot["radius"])
		if absf(effective_radius - declared) > EPS:
			_fail(
				"Btn_%s: raio de toque %.1f != raio declarado %.1f"
				% [action, effective_radius, declared]
			)


# ---------------------------------------------------------------------------
# toque real
# ---------------------------------------------------------------------------
func _check_touch_alignment(slots: Array, to_window: Transform2D) -> void:
	## Toque no centro declarado (e em 4 pontos internos) precisa disparar a ação.
	## É o que prova que a área de toque coincide com o disco desenhado — um
	## desalinhamento de meio botão passaria em qualquer checagem só geométrica.
	##
	## Os slots vêm em coordenadas de viewport; o evento de toque chega em
	## coordenadas de janela. Com stretch ativo as duas escalas diferem (1.5x num
	## 20:9), daí o transform.
	for slot: Dictionary in slots:
		var id: String = String(slot["id"])
		if id == "virtual_stick" or not InputMap.has_action(id):
			continue
		var center: Vector2 = slot["center"]
		var radius: float = float(slot["radius"])
		var probes: Array[Vector2] = [
			center,
			center + Vector2(radius * 0.6, 0.0),
			center + Vector2(-radius * 0.6, 0.0),
			center + Vector2(0.0, radius * 0.6),
			center + Vector2(0.0, -radius * 0.6),
		]
		for probe in probes:
			var hit: bool = await _tap(id, to_window * probe)
			if not hit:
				_fail("%s: toque em %s (viewport) não disparou a ação" % [id, probe])
				break
	_notes.append("%s -> alinhamento arte/toque ok nas %d acoes" % [_ctx, EXPECTED_ACTIONS.size()])


func _tap(action: String, at: Vector2) -> bool:
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.position = at
	down.pressed = true
	root.push_input(down)
	var hit: bool = Input.is_action_pressed(action)
	var up := InputEventScreenTouch.new()
	up.index = 0
	up.position = at
	up.pressed = false
	root.push_input(up)
	if Input.is_action_pressed(action):
		Input.action_release(action)
	# O press encolhe o botão (feedback); espera o ease-back para que o próximo
	# toque volte a medir a geometria em repouso.
	await create_timer(RELEASE_SETTLE_SEC).timeout
	return hit


# ---------------------------------------------------------------------------
# relatório
# ---------------------------------------------------------------------------
func _fail(msg: String) -> void:
	_failures.append("[%s] %s" % [_ctx, msg])


func _report() -> void:
	print("=== smoke_touch_layout ===")
	for n in _notes:
		print("  - ", n)
	for f in _failures:
		print("  FAIL: ", f)
	if _failures.is_empty():
		print("=== TOUCH LAYOUT PASS ===")
		quit(0)
	else:
		print("=== TOUCH LAYOUT FAIL === (%d)" % _failures.size())
		quit(1)
