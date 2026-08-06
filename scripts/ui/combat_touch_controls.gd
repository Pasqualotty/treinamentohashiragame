extends CanvasLayer
## Controles touch de combate — multi-touch via TouchScreenButton.
## Layout 1280x720 landscape: L move/jump/dash · R ATK/H1/H2/ULT · pause.

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

	_labels = Control.new()
	_labels.name = "Labels"
	_labels.set_anchors_preset(Control.PRESET_FULL_RECT)
	_labels.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_labels)

	_build_left_cluster()
	_build_right_cluster()
	_build_pause()


func _build_left_cluster() -> void:
	# Polegar esquerdo
	_add_action_button("move_left", "<", Vector2(28, 560), Vector2(88, 88),
		Color(0.12, 0.16, 0.24, 0.82), Color(0.35, 0.55, 0.95, 0.95))
	_add_action_button("move_right", ">", Vector2(128, 560), Vector2(88, 88),
		Color(0.12, 0.16, 0.24, 0.82), Color(0.35, 0.55, 0.95, 0.95))
	_add_action_button("jump", "PULO", Vector2(88, 450), Vector2(100, 80),
		Color(0.1, 0.28, 0.2, 0.85), Color(0.25, 0.85, 0.45, 0.95))
	_add_action_button("advance", "DASH", Vector2(28, 450), Vector2(52, 80),
		Color(0.32, 0.24, 0.1, 0.85), Color(0.95, 0.75, 0.25, 0.95))


func _build_right_cluster() -> void:
	# Polegar direito — cluster estilo mobile fighter
	_add_action_button("attack_basic", "ATK", Vector2(1080, 540), Vector2(110, 110),
		Color(0.45, 0.12, 0.14, 0.88), Color(0.95, 0.25, 0.28, 0.98))
	_add_action_button("skill_1", "H1", Vector2(970, 500), Vector2(86, 86),
		Color(0.22, 0.16, 0.4, 0.88), Color(0.6, 0.45, 1.0, 0.98))
	_add_action_button("skill_2", "H2", Vector2(1160, 450), Vector2(86, 86),
		Color(0.14, 0.28, 0.42, 0.88), Color(0.35, 0.7, 1.0, 0.98))
	_add_action_button("ultimate", "ULT", Vector2(1050, 430), Vector2(100, 72),
		Color(0.4, 0.28, 0.08, 0.9), Color(1.0, 0.85, 0.2, 0.98))


func _build_pause() -> void:
	_add_action_button("pause", "II", Vector2(1200, 20), Vector2(56, 48),
		Color(0.1, 0.1, 0.12, 0.75), Color(0.5, 0.5, 0.55, 0.95))


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
	btn.shape_centered = true
	btn.position = top_left + size * 0.5

	var shape := RectangleShape2D.new()
	shape.size = size
	btn.shape = shape

	btn.texture_normal = _make_round_rect_texture(size, color_normal)
	btn.texture_pressed = _make_round_rect_texture(size, color_pressed)

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
	var fs: int = 18 if text.length() > 2 else 26
	lbl.add_theme_font_size_override("font_size", fs)
	lbl.add_theme_color_override("font_color", Color(1, 0.98, 0.94, 1))
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	_labels.add_child(lbl)


func _make_round_rect_texture(size: Vector2, fill: Color) -> ImageTexture:
	var w: int = maxi(int(size.x), 8)
	var h: int = maxi(int(size.y), 8)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var r: float = minf(w, h) * 0.22
	var border := Color(1, 1, 1, 0.45)
	var glow := Color(fill.r, fill.g, fill.b, minf(fill.a + 0.15, 1.0))
	for y in h:
		for x in w:
			if _in_round_rect(x, y, w, h, r):
				var edge := (
					x < 3 or y < 3 or x >= w - 3 or y >= h - 3
					or not _in_round_rect(x, y, w, h, r - 2.0)
				)
				if edge and _in_round_rect(x, y, w, h, r):
					img.set_pixel(x, y, border if y < h * 0.5 else glow)
				else:
					# leve gradiente vertical
					var t: float = float(y) / float(h)
					var c := fill.lerp(fill.darkened(0.25), t * 0.5)
					img.set_pixel(x, y, c)
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)


func _in_round_rect(x: int, y: int, w: int, h: int, radius: float) -> bool:
	var rx: float = clampf(float(x), radius, float(w) - 1.0 - radius)
	var ry: float = clampf(float(y), radius, float(h) - 1.0 - radius)
	# inside core rect
	if x >= radius and x < w - radius and y >= 0 and y < h:
		return true
	if y >= radius and y < h - radius and x >= 0 and x < w:
		return true
	# corners
	var corners: Array[Vector2] = [
		Vector2(radius, radius),
		Vector2(w - 1.0 - radius, radius),
		Vector2(radius, h - 1.0 - radius),
		Vector2(w - 1.0 - radius, h - 1.0 - radius),
	]
	var p := Vector2(x, y)
	for c in corners:
		if p.distance_to(c) <= radius:
			return true
	return false
