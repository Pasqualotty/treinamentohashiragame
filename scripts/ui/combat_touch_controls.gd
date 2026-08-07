extends CanvasLayer
## Controles de combate — mouse + multi-touch + teclado.
## Esquerda: VirtualJoystick (move_* strength) + Dash/Pulo.
## Direita: TouchScreenButton labeled (multi-touch nativo) + polish press + SFX ui_click.
## PC: project.godot pointing/emulate_touch_from_mouse=true.

@export var hide_on_desktop: bool = false
@export var design_size: Vector2 = Vector2(1280, 720)
@export var safe_margin: float = 24.0
@export var size_main: float = 100.0
@export var size_sec: float = 84.0
@export var size_pause: float = 58.0
@export var stick_size: float = 148.0
@export var stick_deadzone: float = 0.14

const LABELED_DIR := "res://assets/ui/touch/labeled"
const PRESS_SCALE := 0.9
const PRESS_MOD := Color(1.18, 1.12, 0.98, 1.0)
const NORMAL_MOD := Color(1.0, 1.0, 1.0, 0.96)
const MOVE_ACTIONS: PackedStringArray = [
	"move_left", "move_right", "move_up", "move_down",
]
const COMBAT_ACTIONS: PackedStringArray = [
	"advance", "jump", "attack_basic", "skill_1", "skill_2", "ultimate", "pause",
]

var _root: Control
var _tex_cache: Dictionary = {}
var _btn_nodes: Dictionary = {}  # action -> TouchScreenButton
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
	var m: float = safe_margin
	var s_stick: float = stick_size
	var s_sec: float = size_sec
	var gap: float = 12.0
	var bottom_y: float = design_size.y - m - s_stick

	_add_virtual_stick(Vector2(m, bottom_y), s_stick)

	# Dash / Pulo à direita do stick (polegar esquerdo alcança).
	var side_x: float = m + s_stick + gap
	var jump_y: float = design_size.y - m - s_sec
	var dash_y: float = jump_y - gap - s_sec
	_add_action_button("advance", Vector2(side_x, dash_y), Vector2(s_sec + 10.0, s_sec))
	_add_action_button("jump", Vector2(side_x, jump_y), Vector2(s_sec + 10.0, s_sec))


func _build_right_cluster() -> void:
	var m: float = safe_margin
	var s_atk: float = size_main + 8.0
	var s_sec: float = size_sec
	var s_ult: float = size_sec + 6.0
	var right: float = design_size.x - m
	var bottom: float = design_size.y - m

	var atk_tl := Vector2(right - s_atk - 92.0, bottom - s_atk - 40.0)
	_add_action_button("attack_basic", atk_tl, Vector2(s_atk, s_atk))
	_add_action_button(
		"skill_1",
		Vector2(right - s_sec, atk_tl.y - s_sec + 10.0),
		Vector2(s_sec, s_sec)
	)
	_add_action_button(
		"skill_2",
		Vector2(right - s_sec, atk_tl.y + 30.0),
		Vector2(s_sec, s_sec)
	)
	_add_action_button(
		"ultimate",
		Vector2(atk_tl.x + 6.0, bottom - s_ult),
		Vector2(s_ult + 14.0, s_ult - 6.0)
	)


func _build_pause() -> void:
	var s: float = size_pause
	_add_action_button(
		"pause",
		Vector2(design_size.x - safe_margin - s, safe_margin * 0.65),
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
	stick.tip_size = size * 0.42
	stick.deadzone_ratio = stick_deadzone
	stick.clampzone_ratio = 1.0
	stick.joystick_mode = VirtualJoystick.JOYSTICK_DYNAMIC
	stick.visibility_mode = VirtualJoystick.VISIBILITY_ALWAYS
	stick.action_left = &"move_left"
	stick.action_right = &"move_right"
	stick.action_up = &"move_up"
	stick.action_down = &"move_down"
	_apply_stick_theme(stick, size)
	stick.pressed.connect(_on_stick_pressed)
	_root.add_child(stick)
	_stick = stick


func _apply_stick_theme(stick: VirtualJoystick, size: float) -> void:
	var base_n := _make_circle_stylebox(
		int(size),
		Color(0.10, 0.12, 0.18, 0.55),
		Color(0.85, 0.68, 0.22, 0.92),
		4
	)
	var base_p := _make_circle_stylebox(
		int(size),
		Color(0.14, 0.16, 0.24, 0.72),
		Color(1.0, 0.82, 0.30, 1.0),
		5
	)
	var tip_px := int(size * 0.42)
	var tip_n := _make_circle_stylebox(
		tip_px,
		Color(0.22, 0.38, 0.72, 0.88),
		Color(0.75, 0.85, 1.0, 0.95),
		3
	)
	var tip_p := _make_circle_stylebox(
		tip_px,
		Color(0.30, 0.48, 0.88, 0.95),
		Color(1.0, 0.9, 0.45, 1.0),
		3
	)
	stick.add_theme_stylebox_override("normal_joystick", base_n)
	stick.add_theme_stylebox_override("pressed_joystick", base_p)
	stick.add_theme_stylebox_override("normal_tip", tip_n)
	stick.add_theme_stylebox_override("pressed_tip", tip_p)


func _make_circle_stylebox(
	px: int,
	fill: Color,
	border: Color,
	border_w: int
) -> StyleBoxTexture:
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
				var t := clampf(d / maxf(r_in, 1.0), 0.0, 1.0)
				var c := fill.lerp(fill.darkened(0.18), t * 0.35)
				img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	return sb


func _add_action_button(action: String, top_left: Vector2, size: Vector2) -> void:
	## TouchScreenButton = multi-touch real (stick + ATK ao mesmo tempo).
	## PC via emulate_touch_from_mouse no project.godot.
	var btn := TouchScreenButton.new()
	btn.name = "Btn_%s" % action
	btn.action = action
	btn.visibility_mode = TouchScreenButton.VISIBILITY_ALWAYS
	btn.texture_normal = _load_labeled(action, false)
	btn.texture_pressed = _load_labeled(action, true)
	btn.modulate = NORMAL_MOD

	# Centro no retângulo de layout; shape cobre a hitbox.
	btn.position = top_left + size * 0.5
	var shape := RectangleShape2D.new()
	shape.size = size
	btn.shape = shape
	btn.shape_centered = true

	# Escala visual da textura para caber no size alvo.
	var tex: Texture2D = btn.texture_normal
	if tex != null:
		var ts: Vector2 = tex.get_size()
		if ts.x > 0.0 and ts.y > 0.0:
			btn.scale = Vector2(size.x / ts.x, size.y / ts.y)
	btn.set_meta("base_scale", btn.scale)
	btn.set_meta("hit_size", size)

	btn.pressed.connect(_on_tsb_pressed.bind(action, btn))
	btn.released.connect(_on_tsb_released.bind(action, btn))

	_root.add_child(btn)
	_btn_nodes[action] = btn


func _load_labeled(action: String, pressed: bool) -> Texture2D:
	var key := "%s_%s" % [action, "p" if pressed else "n"]
	if _tex_cache.has(key):
		return _tex_cache[key] as Texture2D
	var path := "%s/%s%s.png" % [LABELED_DIR, action, "_pressed" if pressed else ""]
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	if tex == null:
		tex = _fallback_circle(
			Color(0.75, 0.2, 0.25) if action == "attack_basic" else Color(0.2, 0.4, 0.75),
			pressed
		)
	_tex_cache[key] = tex
	return tex


func _fallback_circle(col: Color, pressed: bool) -> Texture2D:
	var s := 128
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var c := col.darkened(0.25) if pressed else col
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
			elif d > r - 4.0:
				img.set_pixel(x, y, Color(0.8, 0.65, 0.2, 1))
			else:
				img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


func _on_stick_pressed() -> void:
	_play_ui_click(0.45)


func _on_tsb_pressed(action: String, btn: TouchScreenButton) -> void:
	_apply_press_visual(btn, true)
	_play_ui_click(0.7)
	# action= no TSB já faz Input.action_press; só polish/SFX aqui.
	if action.is_empty():
		return


func _on_tsb_released(_action: String, btn: TouchScreenButton) -> void:
	_apply_press_visual(btn, false)


func _apply_press_visual(btn: TouchScreenButton, pressed: bool) -> void:
	if not is_instance_valid(btn):
		return
	var base: Vector2 = btn.get_meta("base_scale", Vector2.ONE) as Vector2
	if pressed:
		btn.scale = base * PRESS_SCALE
		btn.modulate = PRESS_MOD
	else:
		btn.scale = base
		btn.modulate = NORMAL_MOD


func _play_ui_click(volume_linear: float = 0.7) -> void:
	if not is_instance_valid(Audio):
		return
	Audio.play_sfx("ui_click", randf_range(0.96, 1.05), volume_linear)


func _release_all() -> void:
	## Libera botões TSB e eixos do stick (evita run grudado ao sair do app).
	for action: String in COMBAT_ACTIONS:
		if InputMap.has_action(action) and Input.is_action_pressed(action):
			Input.action_release(action)
		if _btn_nodes.has(action):
			_apply_press_visual(_btn_nodes[action] as TouchScreenButton, false)
	for action: String in MOVE_ACTIONS:
		if InputMap.has_action(action) and Input.is_action_pressed(action):
			Input.action_release(action)
	# Esconde/recoloca stick para cancelar toque preso se o motor não soltou.
	if is_instance_valid(_stick):
		_stick.visible = false
		_stick.visible = true
