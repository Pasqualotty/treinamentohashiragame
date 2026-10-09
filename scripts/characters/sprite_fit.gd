class_name SpriteFit
extends RefCounted
## Escala e pivô de sprite pelo bbox de alpha (não pela textura inteira).
##
## Convenção: `AnimatedSprite2D` centrado. `feet_vector` (px de TEXTURA) é o vetor
## do centro da textura até os PÉS (fundo do bbox, centro horizontal do bbox);
## `center_for` posiciona o sprite para os pés caírem em y=0 / x=0 do corpo,
## com escala e rotação pivotando nos pés.
## O bbox vem de `fit.json` (tools/gen_sprite_fit.py, custo zero em runtime);
## sem JSON cai em `Image.get_used_rect()` com cache estático por dir.

const FIT_FILE: String = "fit.json"

## Cache do fallback (get_used_rect custa): dir de combate -> Rect2i.
static var _rect_cache: Dictionary = {}


## Rect usável: vazio/inválido vira a textura inteira (comportamento antigo).
static func usable_rect(used: Rect2i, tex_size: Vector2i) -> Rect2i:
	var full: Rect2i = Rect2i(Vector2i.ZERO, tex_size)
	var clipped: Rect2i = used.intersection(full)
	if clipped.size.x <= 0 or clipped.size.y <= 0:
		return full
	return clipped


## Escala que faz o bbox ter `target_h` px de altura. 0.0 = entrada inválida.
static func scale_for(used: Rect2i, tex_size: Vector2i, target_h: float) -> float:
	var rect: Rect2i = usable_rect(used, tex_size)
	if target_h <= 0.0 or rect.size.y <= 0:
		return 0.0
	return target_h / float(rect.size.y)


## Vetor centro-da-textura -> pés (px de textura, textura sem flip):
## x = centro horizontal do bbox, y = fundo do bbox.
static func feet_vector(used: Rect2i, tex_size: Vector2i) -> Vector2:
	var rect: Rect2i = usable_rect(used, tex_size)
	var cx: float = float(rect.position.x) + float(rect.size.x) * 0.5
	return Vector2(cx - float(tex_size.x) * 0.5, float(rect.end.y) - float(tex_size.y) * 0.5)


## Com flip_h o x do vetor dos pés espelha.
static func flip_vector(feet: Vector2, flipped: bool) -> Vector2:
	return Vector2(-feet.x if flipped else feet.x, feet.y)


## Posição do CENTRO do sprite para que os pés fiquem em `feet_pos`, com escala e
## rotação aplicadas a partir dos pés (squash/stretch e lean com pivô no chão).
static func center_for(feet_pos: Vector2, feet: Vector2, scl: Vector2, rot: float) -> Vector2:
	return feet_pos - (feet * scl).rotated(rot)


## Tudo de uma vez: {"scale": float, "feet": Vector2}.
static func fit(used: Rect2i, tex_size: Vector2i, target_h: float) -> Dictionary:
	return {"scale": scale_for(used, tex_size, target_h), "feet": feet_vector(used, tex_size)}


## Lê o Rect2i de um `fit.json` (texto). Inválido -> Rect2i() vazio.
static func rect_from_json(text: String) -> Rect2i:
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return Rect2i()
	var d: Dictionary = parsed
	for key: String in ["x", "y", "w", "h"]:
		if not d.has(key) or not (d[key] is float or d[key] is int):
			return Rect2i()
	return Rect2i(int(d["x"]), int(d["y"]), int(d["w"]), int(d["h"]))


## Bbox de alpha de um dir de combate: JSON primeiro, imagem como fallback.
static func used_rect_for(combat_dir: String, sample: Texture2D) -> Rect2i:
	if _rect_cache.has(combat_dir):
		return _rect_cache[combat_dir]
	var rect: Rect2i = _rect_from_file("%s/%s" % [combat_dir.rstrip("/"), FIT_FILE])
	if rect.size.y <= 0:
		rect = _rect_from_texture(sample)
	_rect_cache[combat_dir] = rect
	return rect


static func _rect_from_file(path: String) -> Rect2i:
	if not FileAccess.file_exists(path):
		return Rect2i()
	return rect_from_json(FileAccess.get_file_as_string(path))


static func _rect_from_texture(sample: Texture2D) -> Rect2i:
	if sample == null:
		return Rect2i()
	var img: Image = sample.get_image()
	if img == null or img.is_empty():
		return Rect2i()
	return img.get_used_rect()
