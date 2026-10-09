class_name EnemyAnim
extends RefCounted
## Pipeline de frames de inimigo com fallback.
##
## Convenção (contrato do uplift visual):
##   assets/characters/enemies/<kind>/<anim>/NN.png   (NN = 00, 01, ...)
##   kind: weak, elite, charger, ranged, boss_mist, boss_fire, boss_dual, boss_castle, boss_final
##   anim: idle, walk, telegraph, attack, hurt, death
## Pasta ausente -> `update` não faz nada e o sprite único + animação procedural
## continuam valendo. A resolução de caminho é pura (recebe um Callable de existência).

const BASE_DIR: String = "res://assets/characters/enemies"
const MAX_FRAMES: int = 24
const ANIMS: PackedStringArray = ["idle", "walk", "telegraph", "attack", "hurt", "death"]
const LOOPING: PackedStringArray = ["idle", "walk"]
const FPS: Dictionary = {
	"idle": 6.0, "walk": 10.0, "telegraph": 8.0, "attack": 14.0, "hurt": 10.0, "death": 10.0,
}

var kind: String = ""
var _clips: Dictionary = {}
var _current: String = ""
var _time: float = 0.0


## Caminhos NN.png consecutivos a partir de 00; para no primeiro buraco.
static func frame_paths(kind_name: String, anim: String, exists: Callable) -> Array[String]:
	var found: Array[String] = []
	for i in MAX_FRAMES:
		var path: String = "%s/%s/%s/%02d.png" % [BASE_DIR, kind_name, anim, i]
		if not bool(exists.call(path)):
			break
		found.append(path)
	return found


static func fps_of(anim: String) -> float:
	return float(FPS.get(anim, 8.0))


static func is_looping(anim: String) -> bool:
	return LOOPING.has(anim)


## Índice do frame no instante `t` (loop ou trava no último).
static func frame_index(count: int, t: float, fps: float, loop: bool) -> int:
	if count <= 0:
		return 0
	var raw: int = int(floorf(maxf(t, 0.0) * maxf(fps, 0.0)))
	return posmod(raw, count) if loop else mini(raw, count - 1)


## Estado do script do oni (nome do enum) -> anim do contrato.
static func anim_for(state_name: String, moving: bool, hurt: bool) -> String:
	if state_name == "dead":
		return "death"
	if hurt:
		return "hurt"
	match state_name:
		"telegraph":
			return "telegraph"
		"attack", "charge", "slam", "summon":
			return "attack"
		"patrol", "chase":
			return "walk" if moving else "idle"
		_:
			return "idle"


## Altura (y local) da barrinha de HP: logo acima da cabeça, que a cena marca no
## HpLabel (offset_bottom). Sem label, o padrão antigo.
static func pip_offset_y(label: Label) -> float:
	return label.offset_bottom if label != null else -78.0


## Carrega os clipes que existem para o kind; sem nenhum, `has_any()` é falso.
static func create(kind_name: String) -> EnemyAnim:
	var ea: EnemyAnim = EnemyAnim.new()
	ea.kind = kind_name
	var exists: Callable = func(p: String) -> bool: return ResourceLoader.exists(p)
	for anim: String in ANIMS:
		var textures: Array[Texture2D] = []
		for path: String in frame_paths(kind_name, anim, exists):
			var tex: Texture2D = load(path) as Texture2D
			if tex != null:
				textures.append(tex)
		if not textures.is_empty():
			ea._clips[anim] = textures
	return ea


func has_any() -> bool:
	return not _clips.is_empty()


func has_clip(anim: String) -> bool:
	return _clips.has(anim)


## Avança o clipe da `anim` e troca `sprite.texture`. Sem clipe: não toca em nada.
func update(sprite: Sprite2D, anim: String, delta: float) -> void:
	if sprite == null or not _clips.has(anim):
		return
	if anim != _current:
		_current = anim
		_time = 0.0
	_time += delta
	var frames: Array = _clips[anim]
	var idx: int = frame_index(frames.size(), _time, fps_of(anim), is_looping(anim))
	sprite.texture = frames[idx]


## Posição manual no clipe (0..1): usada na morte, que dura exatamente a cerimônia.
func scrub(sprite: Sprite2D, anim: String, progress: float) -> void:
	if sprite == null or not _clips.has(anim):
		return
	var frames: Array = _clips[anim]
	var idx: int = clampi(int(floorf(clampf(progress, 0.0, 1.0) * frames.size())), 0, frames.size() - 1)
	sprite.texture = frames[idx]
