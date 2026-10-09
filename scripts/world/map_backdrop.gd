extends RefCounted
## Fundo do mapa por mundo: W1 usa a arte do mapa; W2–W5 usam a pintura de fase do
## mundo (`assets/backgrounds/wN/stage.png`) com dim INK + vinheta, e a troca de aba
## é um cross-fade entre duas camadas de TextureRect.

const MAP_ART_W1 := "res://assets/ui/map/world_map_w1.png"
const STAGE_ART := "res://assets/backgrounds/%s/stage.png"
const FADE_TIME := 0.35
const DIM_ALPHA := 0.5
const VIGNETTE_ALPHA := 0.7


static func art_path(world_id: String) -> String:
	if world_id == "w1":
		return MAP_ART_W1
	var path: String = STAGE_ART % world_id
	return path if ResourceLoader.exists(path) else MAP_ART_W1


static func texture_for(world_id: String) -> Texture2D:
	return load(art_path(world_id)) as Texture2D


## W1 não ganha dim (a arte já é de mapa); os outros mundos sim.
static func dim_for(world_id: String) -> float:
	return 0.0 if art_path(world_id) == MAP_ART_W1 else DIM_ALPHA


## Camada de cima do cross-fade: mesmo ajuste de esticar da camada de baixo.
static func make_back_layer(front: TextureRect) -> TextureRect:
	var back := TextureRect.new()
	back.name = "MapArtB"
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.expand_mode = front.expand_mode
	back.stretch_mode = front.stretch_mode
	back.modulate.a = 0.0
	return back


static func make_dim() -> ColorRect:
	var dim := ColorRect.new()
	dim.name = "MapDim"
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Palette.with_alpha(Palette.INK, 1.0)
	dim.modulate.a = 0.0
	return dim


## Vinheta: gradiente radial transparente no centro e INK nas bordas.
static func make_vignette() -> TextureRect:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([
		Palette.with_alpha(Palette.INK, 0.0),
		Palette.with_alpha(Palette.INK, 0.0),
		Palette.with_alpha(Palette.INK, VIGNETTE_ALPHA),
	])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.9)
	t.width = 256
	t.height = 144
	var rect := TextureRect.new()
	rect.name = "MapVignette"
	rect.texture = t
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	return rect


## Troca com cross-fade: a camada de trás recebe a nova textura e sobe; no fim a da
## frente assume (sem piscar) e a de trás some. O dim acompanha na mesma duração.
static func crossfade(owner: Node, front: TextureRect, back: TextureRect, dim: ColorRect,
		world_id: String) -> Tween:
	back.texture = texture_for(world_id)
	back.modulate.a = 0.0
	var tw: Tween = owner.create_tween().set_parallel(true)
	tw.tween_property(back, "modulate:a", 1.0, FADE_TIME).set_trans(Tween.TRANS_SINE)
	tw.tween_property(dim, "modulate:a", dim_for(world_id), FADE_TIME)
	tw.chain().tween_callback(_commit.bind(front, back))
	return tw


static func _commit(front: TextureRect, back: TextureRect) -> void:
	if not is_instance_valid(front) or not is_instance_valid(back):
		return
	front.texture = back.texture
	back.modulate.a = 0.0
