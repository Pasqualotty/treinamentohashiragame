extends CanvasLayer
## Controles touch de combate (GDD §4) — mesmas InputMap actions do teclado.
## Multi-touch: TouchScreenButton (cada dedo independente).
##
## Layout 1280×720 landscape (polegares):
##   ESQ: move_left / move_right · DASH · PULO
##   DIR: ATK · H1 · H2 · ULT
##   TOPO DIR: pause
##
## Visual: botões cortados de assets/ui/touch/buttons_row.png + labels ASCII.
## Uso:
##   var touch := preload("res://scenes/ui/combat_touch_controls.tscn").instantiate()
##   add_child(touch)

## Se true, esconde botões em desktop (só touchscreen real). Default false = playtest PC.
@export var hide_on_desktop: bool = false
## Viewport de design (layout fixo; stretch do projeto escala).
@export var design_size: Vector2 = Vector2(1280, 720)
## Margem safe area (px no design).
@export var safe_margin: float = 28.0
## Diâmetro principal (ATK, L/R) — mínimo mobile ~72–96.
@export var size_main: float = 96.0
## Diâmetro secundário (skills, jump, dash).
@export var size_sec: float = 80.0
## Pause (topo).
@export var size_pause: float = 56.0

const TEX_RED := preload("res://assets/ui/touch/btn_red.png")
const TEX_ORANGE := preload("res://assets/ui/touch/btn_orange.png")
const TEX_BLUE := preload("res://assets/ui/touch/btn_blue.png")
const TEX_PURPLE := preload("res://assets/ui/touch/btn_purple.png")

var _root: Node2D
var _labels: Control
## Cache texture_normal / texture_pressed por (source, size).
var _tex_cache: Dictionary = {}


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
	## Polegar esquerdo: L/R embaixo; DASH + PULO logo acima.
	var m: float = safe_margin
	var s_main: float = size_main
	var s_sec: float = size_sec
	var gap: float = 14.0
	var bottom_y: float = design_size.y - m - s_main

	_add_action_button(
		"move_left", "<",
		Vector2(m, bottom_y), Vector2(s_main, s_main),
		TEX_BLUE, 20
	)
	_add_action_button(
		"move_right", ">",
		Vector2(m + s_main + gap, bottom_y), Vector2(s_main, s_main),
		TEX_BLUE, 20
	)
	var upper_y: float = bottom_y - gap - s_sec
	_add_action_button(
		"advance", "DASH",
		Vector2(m, upper_y), Vector2(s_sec + 12.0, s_sec),
		TEX_ORANGE, 15
	)
	_add_action_button(
		"jump", "PULO",
		Vector2(m + s_sec + gap + 12.0, upper_y), Vector2(s_sec + 12.0, s_sec),
		TEX_BLUE, 15
	)


func _build_right_cluster() -> void:
	## Polegar direito: ATK grande; H1 / H2 em arco; ULT abaixo do ATK.
	var m: float = safe_margin
	var s_atk: float = size_main + 4.0
	var s_sec: float = size_sec
	var s_ult: float = size_sec + 8.0
	var right: float = design_size.x - m
	var bottom: float = design_size.y - m

	# ATK — âncora do cluster direito
	var atk_tl := Vector2(right - s_atk - 88.0, bottom - s_atk - 36.0)
	_add_action_button(
		"attack_basic", "ATK",
		atk_tl, Vector2(s_atk, s_atk),
		TEX_RED, 22
	)
	# H1 — acima-direita do ATK
	_add_action_button(
		"skill_1", "H1",
		Vector2(right - s_sec, atk_tl.y - s_sec + 12.0), Vector2(s_sec, s_sec),
		TEX_PURPLE, 18
	)
	# H2 — direita do ATK
	_add_action_button(
		"skill_2", "H2",
		Vector2(right - s_sec, atk_tl.y + 28.0), Vector2(s_sec, s_sec),
		TEX_BLUE, 18
	)
	# ULT — sob o ATK, sem colidir com borda
	_add_action_button(
		"ultimate", "ULT",
		Vector2(atk_tl.x + 8.0, bottom - s_ult), Vector2(s_ult + 16.0, s_ult - 8.0),
		TEX_ORANGE, 16
	)


func _build_pause() -> void:
	## Topo direita — fora do HUD de moedas (HUD reserva margem direita).
	var s: float = size_pause
	_add_action_button(
		"pause", "II",
		Vector2(design_size.x - safe_margin - s, safe_margin * 0.7),
		Vector2(s, s * 0.85),
		TEX_PURPLE, 16
	)


func _add_action_button(
	action: String,
	label_text: String,
	top_left: Vector2,
	size: Vector2,
	base_tex: Texture2D,
	font_size: int,
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

	btn.texture_normal = _scaled_button_texture(base_tex, size, false)
	btn.texture_pressed = _scaled_button_texture(base_tex, size, true)

	_root.add_child(btn)
	_add_caption(label_text, top_left, size, font_size)


func _add_caption(text: String, top_left: Vector2, size: Vector2, font_size: int) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.position = top_left
	lbl.size = size
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", Color(0.99, 0.97, 0.92, 1.0))
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	lbl.add_theme_constant_override("outline_size", 2)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	_labels.add_child(lbl)


func _scaled_button_texture(base: Texture2D, size: Vector2, pressed: bool) -> Texture2D:
	var w: int = maxi(int(round(size.x)), 8)
	var h: int = maxi(int(round(size.y)), 8)
	var key := "%s_%dx%d_%s" % [base.resource_path, w, h, "p" if pressed else "n"]
	if _tex_cache.has(key):
		return _tex_cache[key] as Texture2D

	var src: Image = base.get_image()
	if src == null:
		# Fallback se import ainda não materializou imagem (headless sem cache).
		var fallback := _make_round_rect_texture(Vector2(w, h), Color(0.3, 0.35, 0.5, 0.85), pressed)
		_tex_cache[key] = fallback
		return fallback

	var img := src.duplicate() as Image
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	img.resize(w, h, Image.INTERPOLATE_LANCZOS)

	if pressed:
		_darken_image(img, 0.72)
		# leve “sink” via borda mais escura
		_stroke_image(img, Color(0, 0, 0, 0.45), 2)
	else:
		_stroke_image(img, Color(1, 1, 1, 0.22), 1)

	var tex := ImageTexture.create_from_image(img)
	_tex_cache[key] = tex
	return tex


func _darken_image(img: Image, factor: float) -> void:
	var w := img.get_width()
	var h := img.get_height()
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			if c.a < 0.01:
				continue
			c.r *= factor
			c.g *= factor
			c.b *= factor
			img.set_pixel(x, y, c)


func _stroke_image(img: Image, color: Color, thickness: int) -> void:
	## Contorno leve só em pixels de borda com alpha (não preenche interior).
	var w := img.get_width()
	var h := img.get_height()
	var copy := img.duplicate() as Image
	for y in h:
		for x in w:
			var c := copy.get_pixel(x, y)
			if c.a < 0.2:
				continue
			var edge := false
			for dy in range(-thickness, thickness + 1):
				for dx in range(-thickness, thickness + 1):
					var nx := x + dx
					var ny := y + dy
					if nx < 0 or ny < 0 or nx >= w or ny >= h:
						edge = true
						break
					if copy.get_pixel(nx, ny).a < 0.15:
						edge = true
						break
				if edge:
					break
			if edge:
				var out := c.lerp(color, 0.35)
				out.a = maxf(c.a, color.a)
				img.set_pixel(x, y, out)


func _make_round_rect_texture(size: Vector2, fill: Color, pressed: bool) -> ImageTexture:
	var w: int = maxi(int(size.x), 8)
	var h: int = maxi(int(size.y), 8)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var col := fill.darkened(0.25) if pressed else fill
	var border := Color(1, 1, 1, 0.4)
	var rx := float(mini(w, h)) * 0.5
	var cx := w * 0.5
	var cy := h * 0.5
	for y in h:
		for x in w:
			var dx := (x + 0.5 - cx) / rx
			var dy := (y + 0.5 - cy) / (h * 0.5)
			var d := dx * dx + dy * dy
			if d > 1.05:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			elif d > 0.88:
				img.set_pixel(x, y, border)
			else:
				img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)
