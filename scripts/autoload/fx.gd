extends Node
## Autoload `Fx`: camada de efeitos visuais reutilizável (spark, slash, dust,
## número de dano, poof de morte). Cada helper instancia uma cena de
## scenes/fx/, posiciona no mundo e a própria cena se auto-remove (queue_free)
## ao terminar. Falha de load/instantiate nunca trava gameplay (silenciosa).
##
## Nota de posicionamento: `Fx` é filho direto do root (autoload), sem
## ancestral CanvasItem — por isso `global_position` de cada instância
## equivale à posição no "mundo" (mesmo espaço 2D usado pelas cenas de jogo).

const HIT_SPARK_SCENE: PackedScene = preload("res://scenes/fx/hit_spark.tscn")
const SLASH_ARC_SCENE: PackedScene = preload("res://scenes/fx/slash_arc.tscn")
const DUST_PUFF_SCENE: PackedScene = preload("res://scenes/fx/dust_puff.tscn")
const DAMAGE_NUMBER_SCENE: PackedScene = preload("res://scenes/fx/damage_number.tscn")
const DEATH_POOF_SCENE: PackedScene = preload("res://scenes/fx/death_poof.tscn")
const SHEET_BURST_SCENE: PackedScene = preload("res://scenes/fx/sheet_burst.tscn")

const SLASH_PATHS: PackedStringArray = [
	"res://assets/fx/slash/00.png",
	"res://assets/fx/slash/01.png",
	"res://assets/fx/slash/02.png",
	"res://assets/fx/slash/03.png",
]
const WATER_PATHS: PackedStringArray = [
	"res://assets/fx/water/00.png",
	"res://assets/fx/water/01.png",
	"res://assets/fx/water/02.png",
	"res://assets/fx/water/03.png",
]
const IMPACT_PATHS: PackedStringArray = [
	"res://assets/fx/impact/00.png",
	"res://assets/fx/impact/01.png",
	"res://assets/fx/impact/02.png",
	"res://assets/fx/impact/03.png",
	"res://assets/fx/impact/04.png",
	"res://assets/fx/impact/05.png",
]

## Cores tema (Style Bible) reutilizadas pelos callers.
const COLOR_WATER: Color = Color(0.357, 0.553, 0.937, 1.0)    # #5B8DEF — respiração da água
const COLOR_CRIMSON: Color = Color(0.769, 0.235, 0.235, 1.0)  # #C43C3C
const COLOR_GOLD: Color = Color(0.910, 0.722, 0.290, 1.0)     # #E8B84A
const COLOR_WHITE: Color = Color(1.0, 1.0, 1.0, 1.0)
const COLOR_ASH: Color = Color(0.55, 0.55, 0.6, 1.0)

## Teto de instâncias vivas (spark/slash/dust/número/poof). Fase cheia no celular
## não empilha partículas até virar slideshow — o mais antigo sai pra nascer o novo.
const MAX_LIVE: int = 24

var _dot_texture: ImageTexture = null
var _fade_gradient: Gradient = null


func spark(pos: Vector2, color: Color = COLOR_WHITE, amount: int = 10) -> void:
	var inst: Node2D = _instantiate(HIT_SPARK_SCENE)
	if inst == null:
		return
	inst.global_position = pos
	if inst.has_method("play"):
		inst.call("play", color, amount)


func slash(pos: Vector2, facing: float, kind: StringName = &"basic") -> void:
	var size: float = 128.0
	var life: float = 0.22
	match kind:
		&"skill":
			size = 150.0
			life = 0.28
		&"ultimate":
			size = 170.0
			life = 0.32
		_:
			size = 128.0
	_play_sheet(SLASH_PATHS, pos, facing, life, size)
	var inst: Node2D = _instantiate(SLASH_ARC_SCENE)
	if inst == null:
		return
	inst.global_position = pos
	if inst.has_method("play"):
		inst.call("play", facing, kind)


func impact(pos: Vector2) -> void:
	_play_sheet(IMPACT_PATHS, pos, 1.0, 0.22, 78.0)


func water(pos: Vector2, facing: float) -> void:
	var f: float = signf(facing) if not is_zero_approx(facing) else 1.0
	_play_sheet(WATER_PATHS, pos, f, 0.48, 170.0, f * 280.0)
	flash(Color(0.31, 0.75, 1.0, 0.16), 0.22)


func flash(color: Color, duration: float = 0.18) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 80
	add_child(layer)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)
	var tw := create_tween()
	tw.tween_property(rect, "modulate:a", 0.0, maxf(0.08, duration))
	tw.tween_callback(layer.queue_free)


func afterimage(src: AnimatedSprite2D) -> void:
	if src == null or src.sprite_frames == null:
		return
	if not src.sprite_frames.has_animation(src.animation):
		return
	var tex: Texture2D = src.sprite_frames.get_frame_texture(src.animation, src.frame)
	if tex == null:
		return
	var host: Node = src.get_parent()
	if host:
		host = host.get_parent()
	if host == null:
		return
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.global_position = src.global_position
	spr.flip_h = src.flip_h
	spr.scale = src.scale
	spr.rotation = src.rotation
	spr.z_index = src.z_index - 1
	spr.modulate = Color(0.48, 0.84, 1.0, 0.5)
	host.add_child(spr)
	spr.global_position = src.global_position
	var tw := create_tween()
	tw.tween_property(spr, "modulate:a", 0.0, 0.16)
	tw.tween_callback(spr.queue_free)


func _play_sheet(paths: PackedStringArray, pos: Vector2, facing: float, life: float, draw_size: float, vx: float = 0.0) -> void:
	var inst: Node2D = _instantiate(SHEET_BURST_SCENE)
	if inst == null:
		return
	inst.global_position = pos
	if inst.has_method("play_sheet"):
		inst.call("play_sheet", paths, life, draw_size, facing, vx)


func dust(pos: Vector2) -> void:
	var inst: Node2D = _instantiate(DUST_PUFF_SCENE)
	if inst == null:
		return
	inst.global_position = pos
	if inst.has_method("play"):
		inst.call("play")


func damage_number(pos: Vector2, value: int, crit: bool = false) -> void:
	var inst: Node2D = _instantiate(DAMAGE_NUMBER_SCENE)
	if inst == null:
		return
	inst.global_position = pos
	if inst.has_method("play"):
		inst.call("play", value, crit)


func death_poof(pos: Vector2, color: Color = COLOR_ASH) -> void:
	var inst: Node2D = _instantiate(DEATH_POOF_SCENE)
	if inst == null:
		return
	inst.global_position = pos
	if inst.has_method("play"):
		inst.call("play", color)


## Textura procedural (dot suave) compartilhada por todas as cenas de
## partícula — evita depender de assets externos ou sub-resources frágeis
## no .tscn. Gerada uma vez e cacheada (lazy).
func get_dot_texture() -> ImageTexture:
	if _dot_texture == null:
		_dot_texture = _build_dot_texture()
	return _dot_texture


## Gradiente branco-opaco → branco-transparente, usado como `color_ramp`
## (fade out ao longo do lifetime) nas cenas de partícula.
func get_fade_gradient() -> Gradient:
	if _fade_gradient == null:
		_fade_gradient = Gradient.new()
		_fade_gradient.offsets = PackedFloat32Array([0.0, 1.0])
		_fade_gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	return _fade_gradient


func get_live_count() -> int:
	return get_child_count()


func clear_all() -> void:
	var kids: Array[Node] = get_children()
	for c: Node in kids:
		remove_child(c)
		c.queue_free()


func _instantiate(scene: PackedScene) -> Node2D:
	if scene == null:
		return null
	var inst: Node = scene.instantiate()
	if inst == null:
		return null
	if not (inst is Node2D):
		push_warning("Fx: cena raiz não é Node2D (%s)" % scene.resource_path)
		inst.queue_free()
		return null
	_evict_over_cap()
	add_child(inst)
	return inst as Node2D


func _evict_over_cap() -> void:
	var n: int = FxLiveCap.evict_for_spawn(get_child_count(), MAX_LIVE)
	for _i in n:
		if get_child_count() <= 0:
			return
		var oldest: Node = get_child(0)
		remove_child(oldest)
		oldest.queue_free()


func _build_dot_texture() -> ImageTexture:
	var size: int = 16
	var img: Image = Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var center: float = float(size - 1) / 2.0
	var radius: float = float(size) / 2.0
	for y in range(size):
		for x in range(size):
			var d: float = Vector2(float(x) - center, float(y) - center).length() / radius
			var a: float = clampf(1.0 - d, 0.0, 1.0)
			a = a * a
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	return ImageTexture.create_from_image(img)
