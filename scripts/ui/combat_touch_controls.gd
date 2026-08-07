extends CanvasLayer
## Controles touch premium: stick + botões com ÍCONES (não bolha colorida vazia).
## Layout polegar: espaços generosos, clusters sem sobreposição.

@export var hide_on_desktop: bool = false
@export var design_size: Vector2 = Vector2(1280, 720)
@export var safe_margin: float = 32.0
@export var size_main: float = 108.0
@export var size_sec: float = 88.0
@export var size_pause: float = 56.0
@export var stick_size: float = 156.0
@export var stick_deadzone: float = 0.14

const ICONS_DIR := "res://assets/ui/touch/icons"
const LABELED_DIR := "res://assets/ui/touch/labeled"
const PRESS_SCALE := 0.92
const PRESS_MOD := Color(1.12, 1.08, 0.95, 1.0)
const NORMAL_MOD := Color(1.0, 1.0, 1.0, 0.98)

var _root: Control
var _tex_cache: Dictionary = {}
var _btn_nodes: Dictionary = {}
var _stick: VirtualJoystick


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
	_build_left_cluster()
	_build_right_cluster()
	_build_pause()


func _exit_tree() -> void:
	_release_all()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_release_all()


func _build_left_cluster() -> void:
	## Stick canto inferior esquerdo; DASH acima do PULO, com gap confortável.
	var m: float = safe_margin
	var s_stick: float = stick_size
	var s_sec: float = size_sec
	var gap: float = 20.0
	var bottom: float = design_size.y - m

	_add_virtual_stick(Vector2(m, bottom - s_stick), s_stick)

	var side_x: float = m + s_stick + gap + 8.0
	var jump_y: float = bottom - s_sec
	var dash_y: float = jump_y - gap - s_sec
	_add_action_button("advance", Vector2(side_x, dash_y), Vector2(s_sec, s_sec))
	_add_action_button("jump", Vector2(side_x, jump_y), Vector2(s_sec, s_sec))


func _build_right_cluster() -> void:
	## ATK grande âncora; H1 acima, H2 à direita, ULT abaixo-esquerda do ATK.
	var m: float = safe_margin
	var s_atk: float = size_main + 12.0
	var s_sec: float = size_sec
	var gap: float = 18.0
	var right: float = design_size.x - m
	var bottom: float = design_size.y - m

	var atk_tl := Vector2(right - s_atk - s_sec - gap, bottom - s_atk - 24.0)
	_add_action_button("attack_basic", atk_tl, Vector2(s_atk, s_atk))

	# H1 acima do ATK
	_add_action_button(
		"skill_1",
		Vector2(atk_tl.x + s_atk - s_sec * 0.35, atk_tl.y - s_sec - gap),
		Vector2(s_sec, s_sec)
	)
	# H2 à direita do ATK
	_add_action_button(
		"skill_2",
		Vector2(right - s_sec, atk_tl.y + s_atk * 0.25),
		Vector2(s_sec, s_sec)
	)
	# ULT embaixo do ATK, levemente à esquerda
	_add_action_button(
		"ultimate",
		Vector2(atk_tl.x - 4.0, bottom - s_sec - 4.0),
		Vector2(s_sec + 10.0, s_sec)
	)


func _build_pause() -> void:
	var s: float = size_pause
	_add_action_button(
		"pause",
		Vector2(design_size.x - safe_margin - s, safe_margin * 0.55),
		Vector2(s, s)
	)


func _add_virtual_stick(top_left: Vector2, size: float) -> void:
	var stick := VirtualJoystick.new()
	stick.name = "VirtualStick"
	stick.position = top_left
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


func _apply_stick_theme(stick: VirtualJoystick, size: float) -> void:
	# Base lacada escura + ouro (sem azul docinho).
	var base_n := _make_circle_stylebox(int(size), Color(0.09, 0.08, 0.12, 0.72), Color(0.82, 0.66, 0.22, 0.95), 5)
	var base_p := _make_circle_stylebox(int(size), Color(0.12, 0.11, 0.16, 0.85), Color(1.0, 0.8, 0.28, 1.0), 5)
	var tip_px := int(size * 0.4)
	var tip_n := _make_circle_stylebox(tip_px, Color(0.18, 0.2, 0.28, 0.92), Color(0.9, 0.78, 0.35, 0.95), 3)
	var tip_p := _make_circle_stylebox(tip_px, Color(0.28, 0.26, 0.2, 0.95), Color(1.0, 0.88, 0.4, 1.0), 3)
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


func _add_action_button(action: String, top_left: Vector2, size: Vector2) -> void:
	var btn := TouchScreenButton.new()
	btn.name = "Btn_%s" % action
	btn.action = action
	btn.visibility_mode = TouchScreenButton.VISIBILITY_ALWAYS
	btn.texture_normal = _load_icon(action, false)
	btn.texture_pressed = _load_icon(action, true)
	btn.modulate = NORMAL_MOD
	btn.position = top_left + size * 0.5
	var shape := RectangleShape2D.new()
	shape.size = size * 1.05
	btn.shape = shape
	btn.shape_centered = true
	var tex: Texture2D = btn.texture_normal
	if tex != null:
		var ts: Vector2 = tex.get_size()
		if ts.x > 0.0 and ts.y > 0.0:
			btn.scale = Vector2(size.x / ts.x, size.y / ts.y)
	btn.set_meta("base_scale", btn.scale)
	btn.pressed.connect(_on_tsb_pressed.bind(action, btn))
	btn.released.connect(_on_tsb_released.bind(action, btn))
	_root.add_child(btn)
	_btn_nodes[action] = btn


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


func _on_tsb_pressed(action: String, btn: TouchScreenButton) -> void:
	var base: Vector2 = btn.get_meta("base_scale", btn.scale)
	btn.scale = base * PRESS_SCALE
	btn.modulate = PRESS_MOD
	if is_instance_valid(Audio) and action != "move_left" and action != "move_right":
		Audio.play_sfx("ui_click", randf_range(0.95, 1.05))


func _on_tsb_released(_action: String, btn: TouchScreenButton) -> void:
	var base: Vector2 = btn.get_meta("base_scale", Vector2.ONE)
	btn.scale = base
	btn.modulate = NORMAL_MOD


func _release_all() -> void:
	for action: String in ["move_left", "move_right", "move_up", "move_down"]:
		if InputMap.has_action(action) and Input.is_action_pressed(action):
			Input.action_release(action)
	for action: Variant in _btn_nodes.keys():
		var btn: TouchScreenButton = _btn_nodes[action] as TouchScreenButton
		if btn:
			var base: Vector2 = btn.get_meta("base_scale", Vector2.ONE)
			btn.scale = base
			btn.modulate = NORMAL_MOD
