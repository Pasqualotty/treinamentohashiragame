class_name WorldBackdrop
extends RefCounted
## Veste cada fase com a identidade do seu mundo (W1..W5): emenda do fundo,
## chão temático, atmosfera, clima/luz e silhuetas de primeiro plano.
## Tudo em código, pelo `dress()` que o StageController chama no `_ready()`;
## as 25 cenas não precisam repetir nada. Cada passo tem guarda
## `get_node_or_null`: fase sem o nó (ex.: chefe não tem ParallaxBG) só pula.

const PATH_W2 := "res://assets/backgrounds/w2/stage.png"
const PATH_W3 := "res://assets/backgrounds/w3/stage.png"
const PATH_W4 := "res://assets/backgrounds/w4/stage.png"
const PATH_W5 := "res://assets/backgrounds/w5/stage.png"

## Alias da paleta central (mesmo script do autoload Palette): preload evita
## depender do autoload estar registrado quando um smoke compila esta classe.
const P := preload("res://scripts/autoload/palette.gd")

const DOT_PATH := "res://assets/backgrounds/w1/layers/soft_dot.tres"
const TILE_DIR := "res://assets/tiles/w%d/"
const FG_PATH := "res://assets/backgrounds/w%d/fg_band.png"
const FG_WIDTH := 512.0
## Faixa (px) do degradê escuro que esconde a linha de espelhamento do fundo.
const SEAM_FADE_W := 160
## Chefe fica 12 % mais escuro que a fase comum do mesmo mundo.
const BOSS_DARKEN := 0.88
## Teto de partículas por emissor (mobile fraco) e de emissores por mundo.
const MAX_PARTICLES := 24
const MAX_EMITTERS := 2

static var _petal_tex: Texture2D = null
static var _streak_tex: Texture2D = null


static func texture_path_for_stage(stage_id: String) -> String:
	if stage_id.begins_with("w2_"):
		return PATH_W2
	if stage_id.begins_with("w3_"):
		return PATH_W3
	if stage_id.begins_with("w4_"):
		return PATH_W4
	if stage_id.begins_with("w5_"):
		return PATH_W5
	return ""


## Número do mundo (1..5) a partir do id da fase ("w3_02" -> 3). Desconhecido -> 1.
static func world_of(stage_id: String) -> int:
	if stage_id.length() >= 2 and stage_id.begins_with("w"):
		var n: int = stage_id.substr(1, 1).to_int()
		if n >= 1 and n <= 5:
			return n
	return 1


static func is_boss(stage_id: String) -> bool:
	return stage_id.contains("boss")


## Veste a fase inteira para o mundo (emenda do fundo, chão temático,
## atmosfera, clima/luz, silhuetas). Só orquestra; cada passo é independente.
static func dress(stage: Node, stage_id: String) -> void:
	if stage == null:
		return
	var world: int = world_of(stage_id)
	var boss: bool = is_boss(stage_id)
	_fix_seam(stage, stage_id, world)
	_dress_ground(stage, world)
	_dress_atmo(stage, world)
	_dress_light(stage, world, boss)
	_dress_fg(stage, world)


# --- 1) emenda do fundo ------------------------------------------------------

## Espelha o fundo: `MidArtMirror` (flip_h) ao lado do original e mirroring de
## 2x a largura -> a borda de um lado encontra a MESMA borda espelhada, então a
## emenda some por construção. Sem MidArt (chefe), faz o mesmo no `BgArt`.
static func _fix_seam(stage: Node, stage_id: String, world: int) -> void:
	var mid: Sprite2D = stage.get_node_or_null("ParallaxBG/MidLayer/MidArt") as Sprite2D
	var current: Sprite2D = mid
	if current == null:
		current = stage.get_node_or_null("BgArt") as Sprite2D
	var tex: Texture2D = _resolve_texture(stage_id, current)
	if mid == null:
		_mirror_static_bg(stage, tex)
		return
	if tex == null:
		return
	mid.texture = tex
	mid.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var layer: ParallaxLayer = mid.get_parent() as ParallaxLayer
	var width: float = float(tex.get_width())
	if layer != null:
		layer.motion_mirroring = Vector2(2.0 * width, layer.motion_mirroring.y)
	_ensure_mirror(mid, "MidArtMirror", tex, width)
	_ensure_seam_fades(mid, width)
	_tint_mid_layer(layer, world)


## Textura do mundo: a do stage_id quando há (W2–W5) ou a que a cena já tem.
static func _resolve_texture(stage_id: String, current: Sprite2D) -> Texture2D:
	var path: String = texture_path_for_stage(stage_id)
	if not path.is_empty():
		var loaded: Texture2D = load(path) as Texture2D
		if loaded != null:
			return loaded
	if current != null:
		return current.texture
	return null


## Cria (ou reaproveita) o irmão espelhado de `original`, deslocado `width` px.
static func _ensure_mirror(original: Sprite2D, mirror_name: String, tex: Texture2D, width: float) -> Sprite2D:
	var parent: Node = original.get_parent()
	var mirror: Sprite2D = parent.get_node_or_null(mirror_name) as Sprite2D
	if mirror == null:
		mirror = Sprite2D.new()
		mirror.name = mirror_name
		parent.add_child(mirror)
		parent.move_child(mirror, original.get_index() + 1)
	mirror.texture = tex
	mirror.flip_h = true
	mirror.z_index = original.z_index
	mirror.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	mirror.position = original.position + Vector2(width, 0.0)
	return mirror


## Chefe: `BgArt` é fixo (sem parallax). Troca pela arte do mundo e espelha
## ao lado, cobrindo também o que a câmera vê além dos 1280 px.
static func _mirror_static_bg(stage: Node, tex: Texture2D) -> void:
	var bg: Sprite2D = stage.get_node_or_null("BgArt") as Sprite2D
	if bg == null or tex == null:
		return
	bg.texture = tex
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_ensure_mirror(bg, "BgArtMirror", tex, float(tex.get_width()))


## Degradê escuro sobre as duas linhas de espelhamento (centro da imagem e a
## junção entre repetições) para o eixo de simetria não "denunciar" o truque.
static func _ensure_seam_fades(mid: Sprite2D, width: float) -> void:
	var parent: Node = mid.get_parent()
	var tex: Texture2D = _seam_fade_texture()
	var xs: Array[float] = [mid.position.x - width * 0.5 + width, mid.position.x - width * 0.5]
	for i in xs.size():
		var fade_name: String = "MidSeamFade%d" % i
		var fade: Sprite2D = parent.get_node_or_null(fade_name) as Sprite2D
		if fade == null:
			fade = Sprite2D.new()
			fade.name = fade_name
			parent.add_child(fade)
		fade.texture = tex
		fade.position = Vector2(xs[i], mid.position.y)


static func _seam_fade_texture() -> Texture2D:
	var grad: Gradient = Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	# Tinta de noite (P.INK) com 38 % no eixo: some nas bordas.
	grad.colors = PackedColorArray([
		P.with_alpha(P.INK, 0.0),
		P.with_alpha(P.INK, 0.38),
		P.with_alpha(P.INK, 0.0),
	])
	var tex: GradientTexture2D = GradientTexture2D.new()
	tex.gradient = grad
	tex.width = SEAM_FADE_W
	tex.height = 720
	tex.fill_from = Vector2(0.0, 0.0)
	tex.fill_to = Vector2(1.0, 0.0)
	return tex


## O CanvasModulate da fase não alcança o ParallaxBackground (outro canvas):
## uma tinta suave direto na camada do meio mantém o fundo no clima do mundo.
static func _tint_mid_layer(layer: ParallaxLayer, world: int) -> void:
	if layer == null:
		return
	layer.modulate = Color.WHITE.lerp(_look(world)["modulate"] as Color, 0.55)


# --- 2) chão por mundo -------------------------------------------------------

static func _dress_ground(stage: Node, world: int) -> void:
	var band: Node = stage.get_node_or_null("Ground/Visual")
	if band == null or not ("fill_texture" in band):
		return
	var dir: String = TILE_DIR % world
	var top: Texture2D = load(dir + "ground_top.png") as Texture2D
	var fill: Texture2D = load(dir + "ground_fill.png") as Texture2D
	if top == null or fill == null:
		return
	band.set("top_texture", top)
	band.set("fill_texture", fill)
	band.set("fill_color", _look(world)["ground_base"] as Color)


# --- 3) atmosfera por mundo --------------------------------------------------

## W1 mantém a atmosfera que a própria cena já tem (vaga-lumes, brasas, neve...)
## só com o teto de partículas; W2–W5 trocam tudo por emissores do mundo.
## Orçamento: <= 2 emissores por mundo, <= 24 partículas cada.
static func _dress_atmo(stage: Node, world: int) -> void:
	var holder: Node = _atmo_holder(stage)
	if holder == null:
		return
	if world != 1:
		_clear_emitters(holder)
	_cap_emitters(holder)
	if _count_emitters(holder) > 0:
		return
	var specs: Array = _atmo_specs(world)
	for i in mini(specs.size(), MAX_EMITTERS):
		var spec: Dictionary = specs[i]
		holder.add_child(_make_emitter(str(spec["name"]), spec))


## `ParallaxBG/AtmoLayer` quando existe; no chefe (sem parallax) cria um
## `Atmo` simples atrás do cenário.
static func _atmo_holder(stage: Node) -> Node:
	var layer: Node = stage.get_node_or_null("ParallaxBG/AtmoLayer")
	if layer != null:
		return layer
	var holder: Node = stage.get_node_or_null("Atmo")
	if holder == null:
		var made: Node2D = Node2D.new()
		made.name = "Atmo"
		made.z_index = -10
		stage.add_child(made)
		holder = made
	return holder


static func _count_emitters(holder: Node) -> int:
	return holder.find_children("*", "CPUParticles2D", false, false).size()


static func _clear_emitters(holder: Node) -> void:
	for old: Node in holder.find_children("*", "CPUParticles2D", false, false):
		holder.remove_child(old)
		old.queue_free()


static func _cap_emitters(holder: Node) -> void:
	for node: Node in holder.find_children("*", "CPUParticles2D", false, false):
		var p: CPUParticles2D = node as CPUParticles2D
		p.amount = mini(p.amount, MAX_PARTICLES)


static func _make_emitter(node_name: String, spec: Dictionary) -> CPUParticles2D:
	var p: CPUParticles2D = CPUParticles2D.new()
	p.name = node_name
	p.amount = mini(int(spec["amount"]), MAX_PARTICLES)
	p.lifetime = float(spec["lifetime"])
	p.preprocess = float(spec["lifetime"])
	p.randomness = 0.6
	p.texture = spec["tex"] as Texture2D
	p.position = Vector2(640.0, float(spec["y"]))
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(640.0, float(spec["band"]))
	p.direction = spec["dir"] as Vector2
	p.spread = float(spec["spread"])
	p.gravity = spec["gravity"] as Vector2
	p.initial_velocity_min = float(spec["vmin"])
	p.initial_velocity_max = float(spec["vmax"])
	p.scale_amount_min = float(spec["smin"])
	p.scale_amount_max = float(spec["smax"])
	p.angular_velocity_min = float(spec.get("spin", 0.0)) * -1.0
	p.angular_velocity_max = float(spec.get("spin", 0.0))
	p.color = spec["color"] as Color
	return p


static func _atmo_specs(world: int) -> Array:
	match world:
		1:
			return _atmo_w1()
		2:
			return _atmo_w2()
		3:
			return _atmo_w3()
		4:
			return _atmo_w4()
	return _atmo_w5()


static func _atmo_w1() -> Array:
	# Vaga-lumes + névoa baixa (mesmos valores das cenas W1 da floresta).
	return [
		{"name": "Fireflies", "amount": 14, "lifetime": 5.5, "y": 380.0, "band": 240.0,
			"dir": Vector2(0, -1), "spread": 180.0, "gravity": Vector2.ZERO,
			"vmin": 6.0, "vmax": 18.0, "smin": 0.12, "smax": 0.3,
			"color": Color(0.85, 0.95, 0.55, 0.55), "tex": _dot()},
		{"name": "Mist", "amount": 5, "lifetime": 9.0, "y": 480.0, "band": 80.0,
			"dir": Vector2(1, 0), "spread": 20.0, "gravity": Vector2.ZERO,
			"vmin": 4.0, "vmax": 10.0, "smin": 1.6, "smax": 2.6,
			"color": Color(0.55, 0.62, 0.7, 0.12), "tex": _dot()},
	]


static func _atmo_w2() -> Array:
	# Trem andando: fagulhas do trilho cruzando para a esquerda + fumaça rápida.
	return [
		{"name": "Sparks", "amount": 20, "lifetime": 1.3, "y": 400.0, "band": 220.0,
			"dir": Vector2(-1, 0.04), "spread": 6.0, "gravity": Vector2.ZERO,
			"vmin": 420.0, "vmax": 680.0, "smin": 0.5, "smax": 1.0,
			"color": P.GOLD.lerp(P.CRIMSON_BRIGHT, 0.45), "tex": _streak()},
		{"name": "Smoke", "amount": 6, "lifetime": 3.6, "y": 430.0, "band": 150.0,
			"dir": Vector2(-1, 0), "spread": 8.0, "gravity": Vector2.ZERO,
			"vmin": 150.0, "vmax": 250.0, "smin": 2.4, "smax": 3.8,
			"color": P.with_alpha(P.WATER_BRIGHT.lerp(P.CREAM, 0.4), 0.1), "tex": _dot()},
	]


static func _atmo_w3() -> Array:
	# Distrito: pétalas caindo de lado + brilho quente de lanterna subindo.
	return [
		{"name": "Petals", "amount": 18, "lifetime": 7.0, "y": 340.0, "band": 300.0,
			"dir": Vector2(-0.5, 1), "spread": 22.0, "gravity": Vector2(-4, 6),
			"vmin": 14.0, "vmax": 34.0, "smin": 0.6, "smax": 1.1, "spin": 140.0,
			# Rosa de sakura: CRIMSON_BRIGHT clareado em direção ao creme.
			"color": P.with_alpha(P.CRIMSON_BRIGHT.lerp(P.CREAM, 0.45), 0.75), "tex": _petal()},
		{"name": "Glow", "amount": 5, "lifetime": 9.0, "y": 420.0, "band": 140.0,
			"dir": Vector2(0, -1), "spread": 25.0, "gravity": Vector2.ZERO,
			"vmin": 8.0, "vmax": 16.0, "smin": 2.6, "smax": 4.2,
			"color": P.with_alpha(P.GOLD, 0.16), "tex": _dot()},
	]


static func _atmo_w4() -> Array:
	# Castelo: só poeira suspensa, lenta (o tremor de vela vem da luz).
	return [
		{"name": "Dust", "amount": 22, "lifetime": 8.0, "y": 360.0, "band": 260.0,
			"dir": Vector2(0.3, -1), "spread": 180.0, "gravity": Vector2.ZERO,
			"vmin": 3.0, "vmax": 9.0, "smin": 0.1, "smax": 0.22,
			"color": P.with_alpha(P.WATER_BRIGHT.lerp(P.CREAM, 0.3), 0.4), "tex": _dot()},
	]


static func _atmo_w5() -> Array:
	# Céu Vermelho: brasas subindo + cinza caindo.
	return [
		{"name": "Embers", "amount": 20, "lifetime": 4.5, "y": 440.0, "band": 260.0,
			"dir": Vector2(0.2, -1), "spread": 20.0, "gravity": Vector2(0, -10),
			"vmin": 36.0, "vmax": 90.0, "smin": 0.12, "smax": 0.26,
			"color": P.GOLD.lerp(P.CRIMSON_BRIGHT, 0.5), "tex": _dot()},
		{"name": "Ash", "amount": 14, "lifetime": 6.5, "y": 300.0, "band": 300.0,
			"dir": Vector2(-0.3, 1), "spread": 16.0, "gravity": Vector2(-2, 4),
			"vmin": 18.0, "vmax": 42.0, "smin": 0.14, "smax": 0.28,
			"color": P.with_alpha(P.CREAM.darkened(0.45), 0.5), "tex": _dot()},
	]


static func _dot() -> Texture2D:
	return load(DOT_PATH) as Texture2D


## Riscos de fagulha: 48x3, branco -> transparente (cabeça à esquerda, rabo à direita).
static func _streak() -> Texture2D:
	if _streak_tex == null:
		var grad: Gradient = Gradient.new()
		grad.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
		var tex: GradientTexture2D = GradientTexture2D.new()
		tex.gradient = grad
		tex.width = 48
		tex.height = 3
		tex.fill_from = Vector2(0, 0)
		tex.fill_to = Vector2(1, 0)
		_streak_tex = tex
	return _streak_tex


## Pétala: elipse 12x7 com borda suave, gerada por código (determinística).
static func _petal() -> Texture2D:
	if _petal_tex == null:
		var img: Image = Image.create(12, 7, false, Image.FORMAT_RGBA8)
		for y in 7:
			for x in 12:
				var dx: float = (float(x) - 5.5) / 5.5
				var dy: float = (float(y) - 3.0) / 3.0
				var a: float = clampf(1.6 - (dx * dx + dy * dy) * 1.6, 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, a))
		_petal_tex = ImageTexture.create_from_image(img)
	return _petal_tex


# --- 4) clima e luz ----------------------------------------------------------

## Cor do clima, luzes, base do chão e vinheta de cada mundo. Todas derivadas
## de `Palette` (índigo / carmesim / ouro / água), com o lerp como "tempero".
static func _look(world: int) -> Dictionary:
	match world:
		2:  # trem: aço azul-cinza frio, lanterna de papel ao fundo
			return {"modulate": P.WATER_BRIGHT.lerp(Color.WHITE, 0.25),
				"ambient": P.WATER_BRIGHT, "ambient_e": 0.5,
				"accent": P.GOLD.lerp(P.CRIMSON, 0.35), "accent_e": 0.85,
				"ground_base": P.PANEL.darkened(0.2), "flicker": false}
		3:  # distrito: âmbar de lanterna
			return {"modulate": P.GOLD_BRIGHT.lerp(P.CREAM, 0.15),
				"ambient": P.GOLD_BRIGHT, "ambient_e": 0.5,
				"accent": P.GOLD.lerp(P.CRIMSON_BRIGHT, 0.5), "accent_e": 1.0,
				"ground_base": P.CRIMSON_DIM.darkened(0.5), "flicker": false}
		4:  # castelo: índigo frio e escuro, luz de vela tremendo
			return {"modulate": P.WATER_BRIGHT.lerp(P.PANEL, 0.05),
				"ambient": P.WATER.lerp(P.PANEL, 0.3), "ambient_e": 0.35,
				"accent": P.WATER.lerp(P.CRIMSON, 0.35), "accent_e": 0.65,
				"ground_base": P.PANEL.darkened(0.3), "flicker": true}
		5:  # céu vermelho: carmesim
			return {"modulate": P.CRIMSON_BRIGHT.lerp(P.CREAM, 0.35),
				"ambient": P.CRIMSON_BRIGHT, "ambient_e": 0.5,
				"accent": P.CRIMSON, "accent_e": 0.95,
				"ground_base": P.CRIMSON_DIM.darkened(0.7), "flicker": false}
	# 1: floresta (valores originais das cenas)
	return {"modulate": Color(0.8, 0.83, 0.96, 1.0),
		"ambient": Color(0.68, 0.76, 1.0, 1.0), "ambient_e": 0.45,
		"accent": P.GOLD, "accent_e": 0.7,
		"ground_base": P.PANEL.darkened(0.45), "flicker": false}


static func _dress_light(stage: Node, world: int, boss: bool) -> void:
	var look: Dictionary = _look(world)
	var tint: Color = look["modulate"] as Color
	if boss:
		tint = Color(tint.r * BOSS_DARKEN, tint.g * BOSS_DARKEN, tint.b * BOSS_DARKEN, 1.0)
	var mod: CanvasModulate = _ensure_canvas_modulate(stage)
	mod.color = tint
	var ambient: DirectionalLight2D = stage.get_node_or_null("AmbientMoon") as DirectionalLight2D
	if ambient != null:
		ambient.color = look["ambient"] as Color
		ambient.energy = float(look["ambient_e"])
	var accent: PointLight2D = stage.get_node_or_null("AccentGlow") as PointLight2D
	if accent != null:
		accent.color = look["accent"] as Color
		accent.energy = float(look["accent_e"])
		if bool(look["flicker"]):
			_flicker(stage, accent, float(look["accent_e"]))
	_ensure_vignette(stage, 0.36 if boss else 0.14)


static func _ensure_canvas_modulate(stage: Node) -> CanvasModulate:
	var mod: CanvasModulate = stage.get_node_or_null("CanvasModulate") as CanvasModulate
	if mod == null:
		mod = CanvasModulate.new()
		mod.name = "CanvasModulate"
		stage.add_child(mod)
	return mod


## Tremor de vela: a energia da luz oscila em loop irregular (tween preso à fase).
static func _flicker(stage: Node, light: PointLight2D, base: float) -> void:
	var tw: Tween = stage.create_tween().set_loops()
	tw.tween_property(light, "energy", base * 0.72, 0.17)
	tw.tween_property(light, "energy", base * 1.08, 0.29)
	tw.tween_property(light, "energy", base * 0.88, 0.12)
	tw.tween_property(light, "energy", base, 0.38)


## Vinheta radial numa CanvasLayer baixa (abaixo do HUD, layer 10): bordas
## escurecem, o centro (jogador) fica limpo. `strength` = alpha máximo da borda.
static func _ensure_vignette(stage: Node, strength: float) -> void:
	var layer: CanvasLayer = stage.get_node_or_null("WorldVignette") as CanvasLayer
	if layer == null:
		layer = CanvasLayer.new()
		layer.name = "WorldVignette"
		layer.layer = 5
		stage.add_child(layer)
		layer.add_child(_vignette_rect(strength))


static func _vignette_rect(strength: float) -> TextureRect:
	var grad: Gradient = Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	grad.colors = PackedColorArray([
		P.with_alpha(P.INK, 0.0),
		P.with_alpha(P.INK, 0.0),
		P.with_alpha(P.INK, strength),
	])
	var tex: GradientTexture2D = GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 128
	tex.height = 72
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	var rect: TextureRect = TextureRect.new()
	rect.name = "Vignette"
	rect.texture = tex
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	return rect


# --- 5) primeiro plano -------------------------------------------------------

## Troca o `FgBand` (gradiente) pela silhueta do mundo, com mirroring = 512.
static func _dress_fg(stage: Node, world: int) -> void:
	var band: Sprite2D = stage.get_node_or_null("ParallaxBG/FgLayer/FgBand") as Sprite2D
	if band == null:
		return
	var tex: Texture2D = load(FG_PATH % world) as Texture2D
	if tex == null:
		return
	band.texture = tex
	band.position = Vector2(FG_WIDTH * 0.5, 360.0)
	var layer: ParallaxLayer = band.get_parent() as ParallaxLayer
	if layer != null:
		layer.motion_mirroring = Vector2(FG_WIDTH, 0.0)
