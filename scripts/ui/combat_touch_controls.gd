extends CanvasLayer
## Controles touch de combate (GDD §4) — emitem as mesmas InputMap actions do teclado.
## Multi-touch: TouchScreenButton (cada dedo independente).
##
## Layout 1280×720 landscape (polegares):
##   ESQ: move_left / move_right · advance (dash) · jump
##   DIR: attack_basic · skill_1 · skill_2 · ultimate · pause
##
## Uso em cena de combate:
##   var touch := preload("res://scenes/ui/combat_touch_controls.tscn").instantiate()
##   add_child(touch)
##
## PC playtest: teclado (docs/engine/04-input-e-mobile.md). Mouse no editor aciona os botões.

## Se true, esconde botões em desktop (só touchscreen real). Default false = playtest PC.
@export var hide_on_desktop: bool = false

var _root: Node2D
var _labels: Control


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	if hide_on_desktop and not DisplayServer.is_touchscreen_available():
		visible = false
		return
	_root = Node2D.new()
	_root.name = "TouchRoot"
	add_child(_root)

	# Labels em Control full-screen (só desenho; mouse_filter ignore).
	_labels = Control.new()
	_labels.name = "Labels"
	_labels.set_anchors_preset(Control.PRESET_FULL_RECT)
	_labels.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_labels)

	_build_left_cluster()
	_build_right_cluster()
	_build_pause()


func _build_left_cluster() -> void:
	_add_action_button("move_left", "◄", Vector2(36, 520), Vector2(96, 96),
		Color(0.22, 0.28, 0.40, 0.72), Color(0.40, 0.55, 0.85, 0.90))
	_add_action_button("move_right", "►", Vector2(148, 520), Vector2(96, 96),
		Color(0.22, 0.28, 0.40, 0.72), Color(0.40, 0.55, 0.85, 0.90))
	_add_action_button("advance", "DASH", Vector2(36, 400), Vector2(100, 72),
		Color(0.35, 0.28, 0.18, 0.75), Color(0.85, 0.65, 0.25, 0.92))
	_add_action_button("jump", "PULO", Vector2(160, 400), Vector2(100, 72),
		Color(0.18, 0.35, 0.28, 0.75), Color(0.30, 0.80, 0.50, 0.92))


func _build_right_cluster() -> void:
	_add_action_button("attack_basic", "ATK", Vector2(980, 520), Vector2(100, 100),
		Color(0.45, 0.18, 0.18, 0.78), Color(0.90, 0.30, 0.30, 0.95))
	_add_action_button("skill_1", "H1", Vector2(1100, 480), Vector2(84, 84),
		Color(0.25, 0.22, 0.42, 0.78), Color(0.55, 0.45, 0.95, 0.95))
	_add_action_button("skill_2", "H2", Vector2(1170, 560), Vector2(84, 84),
		Color(0.22, 0.30, 0.42, 0.78), Color(0.40, 0.65, 0.95, 0.95))
	_add_action_button("ultimate", "ULT", Vector2(1040, 620), Vector2(120, 64),
		Color(0.42, 0.32, 0.12, 0.80), Color(1.0, 0.82, 0.25, 0.95))


func _build_pause() -> void:
	_add_action_button("pause", "❚❚", Vector2(1190, 24), Vector2(64, 48),
		Color(0.15, 0.15, 0.18, 0.70), Color(0.55, 0.55, 0.60, 0.90))


func _add_action_button(
	action: String,
	label_text: String,
	top_left: Vector2,
	size: Vector2,
	color_normal: Color,
	color_pressed: Color,
) -> void:
	var btn := TouchScreenButton.new()
	btn.name = "Btn_%s" % action
	btn.action = action
	btn.visibility_mode = TouchScreenButton.VISIBILITY_ALWAYS
	# Shape is centered on the node; place node at rect center.
	btn.shape_centered = true
	btn.position = top_left + size * 0.5

	var shape := RectangleShape2D.new()
	shape.size = size
	btn.shape = shape

	btn.texture_normal = _make_rect_texture(size, color_normal)
	btn.texture_pressed = _make_rect_texture(size, color_pressed)

	_root.add_child(btn)
	_add_caption(label_text, top_left, size)


func _add_caption(text: String, top_left: Vector2, size: Vector2) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.position = top_left
	lbl.size = size
	lbl.add_theme_font_size_override("font_size", 16 if text.length() > 2 else 22)
	lbl.add_theme_color_override("font_color", Color(0.98, 0.96, 0.90, 1))
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	_labels.add_child(lbl)


func _make_rect_texture(size: Vector2, fill: Color) -> ImageTexture:
	var w: int = maxi(int(size.x), 8)
	var h: int = maxi(int(size.y), 8)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var border := Color(1, 1, 1, 0.35)
	for y in h:
		for x in w:
			if x < 2 or y < 2 or x >= w - 2 or y >= h - 2:
				img.set_pixel(x, y, border)
			else:
				img.set_pixel(x, y, fill)
	return ImageTexture.create_from_image(img)
