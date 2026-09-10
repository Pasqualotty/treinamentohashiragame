extends RefCounted
## Garante avanço visível de U+0020 nas fontes do tema.
## Noto/Cinzel no disco têm o glifo; o raster do hub (Nearest + cache)
## às vezes entrega advance 0 — a palavra cola (`Criarsala`).


const SPACE_MIN_PX := 3.0
const SPACE_PAD_PX := 6


static func ensure_theme_space() -> void:
	var theme: Theme = ThemeDB.get_project_theme()
	if theme != null:
		_ensure(theme.default_font, theme.default_font_size)
		_ensure(theme.get_font("font", "Label"), theme.get_font_size("font_size", "Label"))
		_ensure(theme.get_font("font", "Button"), theme.get_font_size("font_size", "Button"))
		_ensure(theme.get_font("font", "LineEdit"), theme.get_font_size("font_size", "LineEdit"))
	for path in [
		"res://assets/fonts/NotoSans-Regular.ttf",
		"res://assets/fonts/NotoSans-SemiBold.ttf",
		"res://assets/fonts/NotoSans-Bold.ttf",
		"res://assets/fonts/Cinzel-Bold.ttf",
	]:
		_ensure(load(path) as Font, 18)


static func space_width(font: Font, size: int) -> float:
	if font == null:
		return 0.0
	var with_sp: float = font.get_string_size("a a", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var no_sp: float = font.get_string_size("aa", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	return with_sp - no_sp


static func _ensure(font: Font, size: int) -> void:
	if font == null:
		return
	if space_width(font, size) >= SPACE_MIN_PX:
		return
	font.set_spacing(TextServer.SPACING_SPACE, SPACE_PAD_PX)
