extends CanvasLayer
## Controles touch premium: stick + botões com arte própria por ação.
##
## Layout radial (não é grade): cada canto inferior é um cluster polar formado por
## uma âncora grande e satélites distribuídos num arco de raio constante ao redor
## dela. Todas as posições saem de [method _arc_point] — nada de somas manuais de
## gap espalhadas pelo código.
##
## Convenção de ângulo (graus, coordenadas de tela do Godot com y para baixo):
## 0° = direita · 90° = baixo · 180° = esquerda · 270° = topo.
##
## Regras duras do layout (afirmadas em res://scripts/qa/smoke_touch_layout.gd):
## nenhum par de alvos se sobrepõe (folga real entre bordas >= 12px), nada invade
## a faixa do HUD superior e tudo cabe dentro de [member safe_margin].
##
## As âncoras saem do retângulo visível REAL do viewport, não de [member design_size]:
## o projeto usa `window/stretch/aspect="expand"`, que alarga o viewport em vez de
## adicionar barras. Num 20:9 (2400x1080) o retângulo visível é 1600x720, e ancorar
## no design deixaria o cluster 352px longe da borda — bem longe do descanso do
## polegar, e desalinhado do HUD, que ancora no viewport real.

@export var hide_on_desktop: bool = false
## Fallback quando não há viewport utilizável (headless com janela dummy).
@export var design_size: Vector2 = Vector2(1280, 720)
## Inset absoluto a partir das bordas reais do viewport (é distância de polegar,
## não proporção — não escala com a resolução).
@export var safe_margin: float = 32.0
## Faixa superior reservada ao HUD de combate: nenhum controle pode invadi-la.
@export var hud_band_height: float = 150.0
@export var stick_size: float = 156.0
@export var stick_deadzone: float = 0.12

## Hierarquia de tamanho em três níveis.
@export var size_primary: float = 132.0    ## âncora do cluster direito (ATK)
@export var size_secondary: float = 104.0  ## ultimate, jump
@export var size_tertiary: float = 88.0    ## skill_1, skill_2, advance
@export var size_pause: float = 56.0       ## chrome discreto, fora dos clusters

## Raio dos arcos. Constante por cluster — é o que dá a leitura radial.
@export var arc_radius_right: float = 158.0
@export var arc_radius_left: float = 152.0

const ICONS_DIR := "res://assets/ui/touch/icons"
const LABELED_DIR := "res://assets/ui/touch/labeled"

## Arco direito: varre do topo para a esquerda, em passos regulares de 45°.
const ANGLE_ULTIMATE := 270.0
const ANGLE_SKILL_1 := 225.0
const ANGLE_SKILL_2 := 180.0
## Arco esquerdo: espelho do direito — varre do topo para a direita.
const ANGLE_JUMP := 315.0
const ANGLE_ADVANCE := 0.0

## Respiro entre a faixa do HUD e o botão de pause.
const PAUSE_HUD_GAP := 12.0

## Abaixo disso o viewport não comporta o layout (janela dummy 64x64 do headless,
## por exemplo) e vale mais cair no design do que espremer tudo num canto.
const MIN_LAYOUT_SIZE := Vector2(640.0, 360.0)

const PRESS_SCALE := 0.9
## Press mais quente/claro e idle mais discreto — diferença de estado nítida.
const PRESS_MOD := Color(1.2, 1.14, 0.9, 1.0)
const NORMAL_MOD := Color(1.0, 1.0, 1.0, 0.86)
const RELEASE_EASE_SEC := 0.14

var _root: Control
var _tex_cache: Dictionary = {}
var _btn_nodes: Dictionary = {}
var _layout_slots: Array[Dictionary] = []
var _stick: VirtualJoystick
var _applied_size: Vector2 = Vector2.ZERO


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	if hide_on_desktop and not DisplayServer.is_touchscreen_available():
		visible = false
		return
	_root = Control.new()
	_root.name = "TouchRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var vp: Viewport = get_viewport()
	if vp != null:
		vp.size_changed.connect(_on_viewport_size_changed)
	_rebuild_layout()


func _exit_tree() -> void:
	_release_all()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_release_all()


## Geometria final dos alvos de toque, em coordenadas do viewport.
## Cada entrada: { "id": String, "center": Vector2, "radius": float }.
## Usado pelo smoke de layout (res://scripts/qa/smoke_touch_layout.gd).
func get_layout_slots() -> Array[Dictionary]:
	return _layout_slots.duplicate(true)


## Retângulo em que o layout foi ancorado da última vez (viewport real ou fallback).
func get_layout_size() -> Vector2:
	return _applied_size


# ---------------------------------------------------------------------------
# ancoragem no viewport real
# ---------------------------------------------------------------------------
## Área de desenho real. Com `stretch/aspect="expand"` o viewport cresce junto com
## o aspecto do aparelho, então é daqui que as âncoras têm de sair — igualzinho ao
## HUD, que usa um Control em PRESET_FULL_RECT.
func _resolve_layout_size() -> Vector2:
	var vp: Viewport = get_viewport()
	if vp != null:
		var visible_size: Vector2 = vp.get_visible_rect().size
		if visible_size.x >= MIN_LAYOUT_SIZE.x and visible_size.y >= MIN_LAYOUT_SIZE.y:
			return visible_size
	return design_size


func _on_viewport_size_changed() -> void:
	# Rotação de tela / resize: reancora. Sai cedo se o retângulo útil não mudou.
	if _resolve_layout_size().is_equal_approx(_applied_size):
		return
	_rebuild_layout()


func _rebuild_layout() -> void:
	_release_all()
	for child in _root.get_children():
		_root.remove_child(child)
		child.queue_free()
	_btn_nodes.clear()
	_layout_slots.clear()
	_stick = null

	var layout_size: Vector2 = _resolve_layout_size()
	_applied_size = layout_size
	_build_left_cluster(layout_size)
	_build_right_cluster(layout_size)
	_build_pause(layout_size)


# ---------------------------------------------------------------------------
# geometria polar
# ---------------------------------------------------------------------------
func _arc_point(anchor: Vector2, radius: float, angle_deg: float) -> Vector2:
	var a: float = deg_to_rad(angle_deg)
	return anchor + Vector2(cos(a), sin(a)) * radius


## Posiciona uma lista de satélites num arco de raio constante ao redor da âncora.
## Cada slot: { "action": String, "angle": float (graus), "size": float }.
func _place_on_arc(anchor: Vector2, radius: float, slots: Array[Dictionary]) -> void:
	for slot in slots:
		var center: Vector2 = _arc_point(anchor, radius, float(slot["angle"]))
		_add_action_button(String(slot["action"]), center, float(slot["size"]))


# ---------------------------------------------------------------------------
# clusters
# ---------------------------------------------------------------------------
func _build_left_cluster(layout_size: Vector2) -> void:
	## Âncora = stick virtual encostado no canto inferior esquerdo do viewport.
	var anchor := Vector2(
		safe_margin + stick_size * 0.5,
		layout_size.y - safe_margin - stick_size * 0.5
	)
	_add_virtual_stick(anchor, stick_size)
	var slots: Array[Dictionary] = [
		{"action": "jump", "angle": ANGLE_JUMP, "size": size_secondary},
		{"action": "advance", "angle": ANGLE_ADVANCE, "size": size_tertiary},
	]
	_place_on_arc(anchor, arc_radius_left, slots)


func _build_right_cluster(layout_size: Vector2) -> void:
	## Âncora = ataque básico encostado no canto inferior direito do viewport.
	## (Substitui a grade ATK/ULT + fileira H1/H2 de 4b45939: o PO pediu arranjo
	## radial explicitamente, com um círculo grande e menores orbitando em arco.)
	var anchor := Vector2(
		layout_size.x - safe_margin - size_primary * 0.5,
		layout_size.y - safe_margin - size_primary * 0.5
	)
	_add_action_button("attack_basic", anchor, size_primary)
	var slots: Array[Dictionary] = [
		{"action": "ultimate", "angle": ANGLE_ULTIMATE, "size": size_secondary},
		{"action": "skill_1", "angle": ANGLE_SKILL_1, "size": size_tertiary},
		{"action": "skill_2", "angle": ANGLE_SKILL_2, "size": size_tertiary},
	]
	_place_on_arc(anchor, arc_radius_right, slots)


func _build_pause(layout_size: Vector2) -> void:
	## Canto superior direito da área jogável, logo abaixo da faixa do HUD.
	var center := Vector2(
		layout_size.x - safe_margin - size_pause * 0.5,
		hud_band_height + PAUSE_HUD_GAP + size_pause * 0.5
	)
	_add_action_button("pause", center, size_pause)


# ---------------------------------------------------------------------------
# stick
# ---------------------------------------------------------------------------
func _add_virtual_stick(center: Vector2, size: float) -> void:
	var stick := VirtualJoystick.new()
	stick.name = "VirtualStick"
	stick.position = center - Vector2(size, size) * 0.5
	stick.custom_minimum_size = Vector2(size, size)
	stick.size = Vector2(size, size)
	stick.mouse_filter = Control.MOUSE_FILTER_STOP
	stick.focus_mode = Control.FOCUS_NONE
	stick.joystick_size = size * 0.92
	stick.tip_size = size * 0.4
	stick.deadzone_ratio = stick_deadzone
	stick.clampzone_ratio = 1.0
	stick.joystick_mode = VirtualJoystick.JOYSTICK_FIXED
	stick.visibility_mode = VirtualJoystick.VISIBILITY_ALWAYS
	stick.action_left = &"move_left"
	stick.action_right = &"move_right"
	stick.action_up = &"move_up"
	stick.action_down = &"move_down"
	_apply_stick_theme(stick, size)
	_root.add_child(stick)
	_stick = stick
	_layout_slots.append({"id": "virtual_stick", "center": center, "radius": size * 0.5})


func _apply_stick_theme(stick: VirtualJoystick, size: float) -> void:
	# Base lacada escura + ouro, mesma linguagem dos botões.
	var base_n := _make_circle_stylebox(
		int(size), Color(0.09, 0.08, 0.12, 0.72), Color(0.82, 0.66, 0.22, 0.95), 5
	)
	var base_p := _make_circle_stylebox(
		int(size), Color(0.12, 0.11, 0.16, 0.85), Color(1.0, 0.8, 0.28, 1.0), 5
	)
	var tip_px := int(size * 0.4)
	var tip_n := _make_circle_stylebox(
		tip_px, Color(0.18, 0.2, 0.28, 0.92), Color(0.9, 0.78, 0.35, 0.95), 3
	)
	var tip_p := _make_circle_stylebox(
		tip_px, Color(0.28, 0.26, 0.2, 0.95), Color(1.0, 0.88, 0.4, 1.0), 3
	)
	stick.add_theme_stylebox_override("normal_joystick", base_n)
	stick.add_theme_stylebox_override("pressed_joystick", base_p)
	stick.add_theme_stylebox_override("normal_tip", tip_n)
	stick.add_theme_stylebox_override("pressed_tip", tip_p)


func _make_circle_stylebox(px: int, fill: Color, border: Color, border_w: int) -> StyleBoxTexture:
	var s: int = maxi(px, 16)
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var cx := s * 0.5
	var cy := s * 0.5
	var r := s * 0.48
	var r_in := r - float(border_w)
	for y in s:
		for x in s:
			var dx := x + 0.5 - cx
			var dy := y + 0.5 - cy
			var d := sqrt(dx * dx + dy * dy)
			if d > r:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			elif d > r_in:
				img.set_pixel(x, y, border)
			else:
				img.set_pixel(x, y, fill)
	var tex := ImageTexture.create_from_image(img)
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	return sb


# ---------------------------------------------------------------------------
# botões
# ---------------------------------------------------------------------------
func _add_action_button(action: String, center: Vector2, size: float) -> void:
	var btn := TouchScreenButton.new()
	btn.name = "Btn_%s" % action
	btn.action = action
	btn.visibility_mode = TouchScreenButton.VISIBILITY_ALWAYS
	btn.texture_normal = _load_icon(action, false)
	btn.texture_pressed = _load_icon(action, true)
	btn.modulate = NORMAL_MOD

	# TouchScreenButton desenha a textura a partir da própria origem e, com
	# shape_centered, centra a forma na textura. Logo a origem é o canto
	# superior esquerdo do alvo, não o centro.
	var tex_size := _texture_size(btn.texture_normal, size)
	btn.scale = Vector2(size / tex_size.x, size / tex_size.y)
	btn.position = center - Vector2(size, size) * 0.5

	# Forma redonda igual à arte: o alvo de toque é exatamente o disco visível.
	var shape := CircleShape2D.new()
	shape.radius = minf(tex_size.x, tex_size.y) * 0.5
	btn.shape = shape
	btn.shape_centered = true

	btn.set_meta("base_scale", btn.scale)
	btn.pressed.connect(_on_tsb_pressed.bind(action, btn))
	btn.released.connect(_on_tsb_released.bind(action, btn))
	_root.add_child(btn)
	_btn_nodes[action] = btn
	_layout_slots.append({"id": action, "center": center, "radius": size * 0.5})


func _texture_size(tex: Texture2D, fallback: float) -> Vector2:
	if tex == null:
		return Vector2(fallback, fallback)
	var ts: Vector2 = tex.get_size()
	if ts.x <= 0.0 or ts.y <= 0.0:
		return Vector2(fallback, fallback)
	return ts


func _load_icon(action: String, pressed: bool) -> Texture2D:
	var key := "%s_%s" % [action, "p" if pressed else "n"]
	if _tex_cache.has(key):
		return _tex_cache[key] as Texture2D
	var suffix := "_pressed" if pressed else ""
	for base in [ICONS_DIR, LABELED_DIR]:
		var path := "%s/%s%s.png" % [base, action, suffix]
		if ResourceLoader.exists(path):
			var tex := load(path) as Texture2D
			if tex:
				_tex_cache[key] = tex
				return tex
	push_warning("touch: ícone ausente para '%s' (pressed=%s)" % [action, pressed])
	var fb := _fallback_circle(Color(0.2, 0.22, 0.3), pressed)
	_tex_cache[key] = fb
	return fb


func _fallback_circle(col: Color, pressed: bool) -> Texture2D:
	var s := 128
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var c := col.darkened(0.2) if pressed else col
	var cx := s * 0.5
	var cy := s * 0.5
	var r := s * 0.46
	for y in s:
		for x in s:
			var dx := x + 0.5 - cx
			var dy := y + 0.5 - cy
			var d := sqrt(dx * dx + dy * dy)
			if d > r:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			elif d > r - 5.0:
				img.set_pixel(x, y, Color(0.85, 0.68, 0.22, 1))
			else:
				img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


# ---------------------------------------------------------------------------
# feedback
# ---------------------------------------------------------------------------
func _on_tsb_pressed(action: String, btn: TouchScreenButton) -> void:
	# Press é instantâneo (sem tween) — resposta imediata importa mais que
	# suavidade num jogo de combate. O "juice" fica pro release.
	_kill_btn_tween(btn)
	var base: Vector2 = btn.get_meta("base_scale", btn.scale)
	btn.scale = base * PRESS_SCALE
	btn.modulate = PRESS_MOD
	if is_instance_valid(Audio) and action != "move_left" and action != "move_right":
		Audio.play_sfx("ui_click", randf_range(0.95, 1.05))


func _on_tsb_released(_action: String, btn: TouchScreenButton) -> void:
	# Release com ease-back suave (spring) — feedback tátil premium sem
	# atrasar a resposta do press em si.
	_kill_btn_tween(btn)
	var base: Vector2 = btn.get_meta("base_scale", Vector2.ONE)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.set_trans(Tween.TRANS_BACK)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(btn, "scale", base, RELEASE_EASE_SEC)
	tw.tween_property(btn, "modulate", NORMAL_MOD, RELEASE_EASE_SEC)
	btn.set_meta("release_tween", tw)


func _kill_btn_tween(btn: TouchScreenButton) -> void:
	# get_meta(key, null) NÃO suprime o erro "meta ausente" no Godot 4 (null é
	# o mesmo sentinel de "sem default") — precisa do has_meta() antes.
	if not btn.has_meta("release_tween"):
		return
	var tw: Variant = btn.get_meta("release_tween")
	if tw is Tween and (tw as Tween).is_valid():
		(tw as Tween).kill()


func _release_all() -> void:
	for action: String in ["move_left", "move_right", "move_up", "move_down"]:
		if InputMap.has_action(action) and Input.is_action_pressed(action):
			Input.action_release(action)
	for action: Variant in _btn_nodes.keys():
		var btn: TouchScreenButton = _btn_nodes[action] as TouchScreenButton
		if btn:
			_kill_btn_tween(btn)
			var base: Vector2 = btn.get_meta("base_scale", Vector2.ONE)
			btn.scale = base
			btn.modulate = NORMAL_MOD
