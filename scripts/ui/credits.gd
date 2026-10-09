extends Control
## Tela de creditos / aviso fan game.
## O texto mora no Label `Body` da cena; em runtime ele vira uma linha por Label
## (VBox `Lines`) para as linhas entrarem em cascata.


func _ready() -> void:
	SafeInset.apply(self)
	var back := get_node_or_null("Back") as Button
	var lines: Array = _split_body(get_node_or_null("Body") as Label)
	MetaChrome.setup_screen(self, "credits", get_node_or_null("Title") as Label,
		get_node_or_null("Subtitle") as Label, back)
	if back and not back.pressed.is_connected(_on_back):
		back.pressed.connect(_on_back)
	_blend_logo()
	UiMotion.enter_stagger([get_node_or_null("Logo")] + lines, 0.07)


## Troca o Label `Body` por um VBox com um Label por linha (mesma área na tela).
func _split_body(body: Label) -> Array:
	var made: Array = []
	if body == null:
		return made
	var box := VBoxContainer.new()
	box.name = "Lines"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 6)
	add_child(box)
	box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	box.offset_left = body.offset_left
	box.offset_right = body.offset_right
	box.offset_top = body.offset_top
	box.offset_bottom = body.offset_bottom
	var lines: PackedStringArray = body.text.split("\n")
	for i in lines.size():
		var lab := _make_line(lines[i], i == 0)
		box.add_child(lab)
		made.append(lab)
	body.queue_free()
	return made


func _make_line(text: String, headline: bool) -> Label:
	var lab := Label.new()
	lab.text = text
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.add_theme_font_size_override("font_size", 22 if headline else 18)
	lab.add_theme_color_override("font_color", Palette.GOLD if headline else Palette.CREAM)
	return lab


## O PNG do logo tem fundo preto opaco: blend aditivo apaga o preto e deixa só o desenho.
func _blend_logo() -> void:
	var logo := get_node_or_null("Logo") as CanvasItem
	if logo == null:
		return
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	logo.material = mat


func _on_back() -> void:
	SceneRouter.to_hub()
