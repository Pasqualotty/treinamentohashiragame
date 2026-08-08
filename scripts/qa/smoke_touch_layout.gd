extends SceneTree
## Smoke headless: geometria dos controles touch de combate.
##
## Valida que o layout radial não se sobrepõe, cabe na tela, respeita a margem
## de segurança e não invade a faixa do HUD superior. Valida também que cada
## ação tem arte própria carregada (normal + pressed, distintas entre si).
##
## Uso: godot --headless --path . -s res://scripts/qa/smoke_touch_layout.gd

const TOUCH_SCENE := "res://scenes/ui/combat_touch_controls.tscn"
const ICONS_DIR := "res://assets/ui/touch/icons"
const EXPECTED_ACTIONS: PackedStringArray = [
	"attack_basic", "ultimate", "skill_1", "skill_2", "jump", "advance", "pause",
]
const ICON_SIZE := 256
## Regra dura do layout, afirmada aqui de forma independente da implementação.
const MIN_EDGE_GAP := 12.0
## Folga para o ease-back do release terminar entre um toque e o próximo.
const RELEASE_SETTLE_SEC := 0.22

var _failures: Array[String] = []
var _notes: Array[String] = []


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

	_check_icons()
	var slots: Array = node.call("get_layout_slots")
	_check_slots(node, slots)
	_check_nodes(node)

	# Headless abre uma janela dummy 64x64: sem isso, todo toque cai fora do viewport.
	root.size = Vector2i(node.get("design_size"))
	await process_frame
	await _check_touch_alignment(slots)

	node.queue_free()
	await process_frame
	_report()


# ---------------------------------------------------------------------------
# checks
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


func _check_slots(node: CanvasLayer, slots: Array) -> void:
	var expected_count: int = EXPECTED_ACTIONS.size() + 1  # + stick virtual
	if slots.size() != expected_count:
		_fail("get_layout_slots(): %d slots, esperado %d" % [slots.size(), expected_count])
		return

	var design: Vector2 = node.get("design_size")
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

		# Dentro da margem de segurança (logo, dentro da tela).
		var left: float = center.x - radius
		var right: float = center.x + radius
		var top: float = center.y - radius
		var bottom: float = center.y + radius
		if left < margin - 0.5 or top < margin - 0.5:
			_fail("%s: fora da margem (topo-esq %.1f,%.1f < %.1f)" % [id, left, top, margin])
		if right > design.x - margin + 0.5 or bottom > design.y - margin + 0.5:
			_fail(
				"%s: fora da margem (baixo-dir %.1f,%.1f > %.1f,%.1f)"
				% [id, right, bottom, design.x - margin, design.y - margin]
			)

		# Não invade a faixa do HUD superior.
		if top < hud_band - 0.5:
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
	_notes.append("menor folga entre bordas: %.1fpx (%s)" % [worst_gap, worst_pair])


func _check_nodes(node: CanvasLayer) -> void:
	## Cada slot de ação tem um TouchScreenButton com action, arte e forma redonda
	## alinhada ao centro geométrico declarado.
	var touch_root: Node = node.get_node_or_null("TouchRoot")
	if touch_root == null:
		_fail("TouchRoot ausente")
		return
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
		var declared: float = _slot_radius(node, action)
		if absf(effective_radius - declared) > 1.0:
			_fail(
				"Btn_%s: raio de toque %.1f != raio declarado %.1f"
				% [action, effective_radius, declared]
			)


func _check_touch_alignment(slots: Array) -> void:
	## Toque no centro declarado (e em 4 pontos internos) precisa disparar a ação.
	## É o que prova que a área de toque coincide com o disco desenhado — um
	## desalinhamento de meio botão passaria em qualquer checagem só geométrica.
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
			var hit: bool = await _tap(id, probe)
			if not hit:
				_fail("%s: toque em %s não disparou a ação" % [id, probe])
				break
	_notes.append("alinhamento arte/toque verificado nas %d acoes" % EXPECTED_ACTIONS.size())


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


func _slot_radius(node: CanvasLayer, id: String) -> float:
	for slot: Dictionary in node.call("get_layout_slots"):
		if String(slot["id"]) == id:
			return float(slot["radius"])
	return -1.0


# ---------------------------------------------------------------------------
# relatório
# ---------------------------------------------------------------------------
func _fail(msg: String) -> void:
	_failures.append(msg)


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
