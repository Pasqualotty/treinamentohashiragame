extends CanvasLayer
## Controles de combate — mouse + touch + teclado.
## Botões lacados com texto baked (assets/ui/touch/labeled/*).

@export var hide_on_desktop: bool = false
@export var design_size: Vector2 = Vector2(1280, 720)
@export var safe_margin: float = 24.0
@export var size_main: float = 100.0
@export var size_sec: float = 84.0
@export var size_pause: float = 58.0

const LABELED_DIR := "res://assets/ui/touch/labeled"

var _root: Control
var _held_actions: Dictionary = {}
var _tex_cache: Dictionary = {}


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
	var s_main: float = size_main
	var s_sec: float = size_sec
	var gap: float = 12.0
	var bottom_y: float = design_size.y - m - s_main

	_add_action_button("move_left", Vector2(m, bottom_y), Vector2(s_main, s_main))
	_add_action_button(
		"move_right",
		Vector2(m + s_main + gap, bottom_y),
		Vector2(s_main, s_main)
	)
	var upper_y: float = bottom_y - gap - s_sec
	_add_action_button("advance", Vector2(m, upper_y), Vector2(s_sec + 10.0, s_sec))
	_add_action_button(
		"jump",
		Vector2(m + s_sec + gap + 10.0, upper_y),
		Vector2(s_sec + 10.0, s_sec)
	)


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


func _add_action_button(action: String, top_left: Vector2, size: Vector2) -> void:
	var btn := TextureButton.new()
	btn.name = "Btn_%s" % action
	btn.position = top_left
	btn.custom_minimum_size = size
	btn.size = size
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn.focus_mode = Control.FOCUS_NONE
	btn.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.texture_normal = _load_labeled(action, false)
	btn.texture_pressed = _load_labeled(action, true)
	btn.texture_hover = btn.texture_normal
	# Sombra sutil atrás
	btn.modulate = Color(1, 1, 1, 0.96)

	btn.button_down.connect(_on_btn_down.bind(action))
	btn.button_up.connect(_on_btn_up.bind(action))
	btn.mouse_exited.connect(func() -> void:
		if btn.button_pressed:
			_on_btn_up(action)
	)
	_root.add_child(btn)


func _load_labeled(action: String, pressed: bool) -> Texture2D:
	var key := "%s_%s" % [action, "p" if pressed else "n"]
	if _tex_cache.has(key):
		return _tex_cache[key] as Texture2D
	var path := "%s/%s%s.png" % [LABELED_DIR, action, "_pressed" if pressed else ""]
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	if tex == null:
		# Fallback geométrico se asset faltar.
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


func _on_btn_down(action: String) -> void:
	if not InputMap.has_action(action):
		return
	if _held_actions.get(action, false):
		return
	_held_actions[action] = true
	Input.action_press(action)


func _on_btn_up(action: String) -> void:
	if not _held_actions.get(action, false):
		return
	_held_actions.erase(action)
	if InputMap.has_action(action) and Input.is_action_pressed(action):
		Input.action_release(action)


func _release_all() -> void:
	for action: Variant in _held_actions.keys():
		var a: String = str(action)
		if InputMap.has_action(a) and Input.is_action_pressed(a):
			Input.action_release(a)
	_held_actions.clear()
