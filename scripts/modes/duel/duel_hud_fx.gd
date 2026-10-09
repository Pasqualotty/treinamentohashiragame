class_name DuelHudFx
extends RefCounted
## Visual do duelo fora do controlador: nomes em Cinzel, rastro/ticks nas barras,
## animação do banner ROUND, KO e cerimônia do resultado. Só estilo/animação —
## o fluxo (fases, LAN, slots) continua em `duel_controller.gd`.

const FONT_TITLE := "res://assets/fonts/Cinzel-Bold.ttf"
const _UiFont := preload("res://scripts/ui/ui_font.gd")
const NAME_SIZE: int = 18
const RESULT_SIZE: int = 40
const BANNER_SLIDE_PX: float = 24.0
const BANNER_IN_SEC: float = 0.35
const BANNER_OUT_SEC: float = 0.3
const TICK_INSET: float = 2.0
const KO_FLASH_SEC: float = 0.18


## Nome do lutador em Cinzel 18 (espaço preservado pelo `FontVariation`).
static func style_name(lbl: Label) -> void:
	if lbl == null:
		return
	var fv := FontVariation.new()
	fv.base_font = load(FONT_TITLE) as Font
	fv.spacing_space = _UiFont.SPACE_PAD_PX
	lbl.add_theme_font_override("font", fv)
	lbl.add_theme_font_size_override("font_size", NAME_SIZE)


## Rastro de dano na barra de vida (a barra precisa ter margem interna de 3 px).
static func attach_trail(bar: ProgressBar) -> void:
	if bar != null:
		HudTrail.attach(bar, 3.0)


## Quatro marcas de segmento por cima da barra de respiração.
static func attach_ticks(bar: ProgressBar) -> void:
	if bar == null:
		return
	var ticks := BarTicks.new()
	ticks.segments = 4
	ticks.inset = TICK_INSET
	ticks.set_anchors_preset(Control.PRESET_FULL_RECT)
	ticks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(ticks)


## Banner ROUND: entra deslizando 24 px com pop (0.8 -> 1.0).
static func banner_in(lbl: Label) -> void:
	if lbl == null:
		return
	var base_y: float = lbl.position.y
	lbl.pivot_offset = lbl.size * 0.5
	lbl.modulate.a = 0.0
	lbl.scale = Vector2(0.8, 0.8)
	lbl.position.y = base_y + BANNER_SLIDE_PX
	var tw := lbl.create_tween().set_parallel(true)
	tw.tween_property(lbl, "modulate:a", 1.0, BANNER_IN_SEC)
	tw.tween_property(lbl, "position:y", base_y, BANNER_IN_SEC).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "scale", Vector2.ONE, BANNER_IN_SEC).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Banner some com fade ao começar a luta.
static func banner_out(lbl: Label) -> void:
	if lbl == null or not lbl.visible:
		return
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "modulate:a", 0.0, BANNER_OUT_SEC)
	tw.tween_callback(func() -> void: lbl.visible = false)


## Flash branco curto no KO (o hitstop vem do combate).
static func ko_flash(fx: Node) -> void:
	if fx != null and fx.has_method("flash"):
		fx.call("flash", Color(1, 1, 1, 0.55), KO_FLASH_SEC)


## Resultado: letterbox, título Cinzel 40 ouro com slide, CTA dourado (De novo, ou Voltar sozinho no solo) + ghost (Lobby) com bounce.
static func style_result(root: Control, title: Label, ctas: Array[Button], ghosts: Array[Button]) -> void:
	var bars: Array[ColorRect] = ModeResultOverlay.add_letterbox(root)
	for bar: ColorRect in bars:
		root.move_child(bar, 1) # logo acima do Dim, abaixo do título e dos botões
	ModeResultOverlay.style_title(title, RESULT_SIZE, Palette.GOLD)
	for btn: Button in ctas:
		MetaChrome.apply_cta(btn)
	for btn: Button in ghosts:
		MetaChrome.apply_ghost(btn)
	for btn: Button in ctas + ghosts:
		btn.add_theme_font_size_override("font_size", 22)
		ModeResultOverlay.bounce(btn)


## Entrada do título do resultado (chamar quando o root fica visível).
static func result_in(title: Label) -> void:
	var base_y: float = title.position.y
	title.modulate.a = 0.0
	title.position.y = base_y + ModeResultOverlay.SLIDE_PX
	var tw := title.create_tween().set_parallel(true)
	tw.tween_property(title, "modulate:a", 1.0, ModeResultOverlay.IN_SEC)
	tw.tween_property(title, "position:y", base_y, ModeResultOverlay.IN_SEC).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
