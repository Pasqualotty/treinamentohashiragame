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

## Cores tema (Style Bible) reutilizadas pelos callers.
const COLOR_WATER: Color = Color(0.357, 0.553, 0.937, 1.0)    # #5B8DEF — respiração da água
const COLOR_CRIMSON: Color = Color(0.769, 0.235, 0.235, 1.0)  # #C43C3C
const COLOR_GOLD: Color = Color(0.910, 0.722, 0.290, 1.0)     # #E8B84A
const COLOR_WHITE: Color = Color(1.0, 1.0, 1.0, 1.0)
const COLOR_ASH: Color = Color(0.55, 0.55, 0.6, 1.0)

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
	var inst: Node2D = _instantiate(SLASH_ARC_SCENE)
	if inst == null:
		return
	inst.global_position = pos
	if inst.has_method("play"):
		inst.call("play", facing, kind)


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
	add_child(inst)
	return inst as Node2D


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
