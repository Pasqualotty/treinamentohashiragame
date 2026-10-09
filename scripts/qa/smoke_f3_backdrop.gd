extends SceneTree
## Headless: frente F3 (fundos). Para as 24 fases instanciadas confere
## emenda espelhada, chão por mundo, orçamento de partículas, clima e
## silhuetas de primeiro plano; e a tileabilidade dos PNG de chão.
##   godot --headless --path . -s res://scripts/qa/smoke_f3_backdrop.gd

const STAGES_DIR := "res://scenes/battle"
## Orçamento de partículas de ATMOSFERA por fase (<= 2 emissores x 24, sob ParallaxBG).
const MAX_PARTICLES_STAGE := 48
const MAX_PARTICLES_EMITTER := 24
## Teto da fase inteira (atmosfera + gameplay, ex.: aura do portal da F2).
const MAX_PARTICLES_TOTAL := 64
## Diferença média máxima (0..255) entre a 1a e a última coluna do tile.
const WRAP_MAX := 8.0

var _failed: int = 0
var _modulate_by_stage: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== smoke_f3_backdrop ===")
	_check_tiles()
	var stages: PackedStringArray = _discover()
	if stages.size() != 24:
		_fail("esperava 24 fases, achei %d" % stages.size())
	for path: String in stages:
		await _check_stage(path)
	_check_climate()
	if _failed > 0:
		print("=== F3 BACKDROP FAIL === falhas=%d" % _failed)
		quit(1)
		return
	print("=== F3 BACKDROP PASS ===")
	quit(0)


func _fail(msg: String) -> void:
	_failed += 1
	push_error("[f3] %s" % msg)
	print("  FAIL %s" % msg)


func _discover() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var dir: DirAccess = DirAccess.open(STAGES_DIR)
	if dir == null:
		return found
	for f: String in dir.get_files():
		if f.begins_with("stage_") and f.ends_with(".tscn"):
			found.append(STAGES_DIR.path_join(f))
	found.sort()
	return found


# --- tiles -------------------------------------------------------------------

func _check_tiles() -> void:
	print("-- tileabilidade dos chãos --")
	for w in range(1, 6):
		for kind: String in ["ground_top", "ground_fill"]:
			var path: String = "res://assets/tiles/w%d/%s.png" % [w, kind]
			var img: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
			if img == null:
				_fail("não abriu %s" % path)
				continue
			var diff: float = _column_diff(img, 0, img.get_width() - 1)
			if diff >= WRAP_MAX:
				_fail("%s emenda ruim: diff=%.2f/255" % [path, diff])
			else:
				print("  OK %s wrap=%.2f" % [path, diff])
	var top: Image = Image.load_from_file(ProjectSettings.globalize_path("res://assets/tiles/w1/ground_top.png"))
	var fill: Image = Image.load_from_file(ProjectSettings.globalize_path("res://assets/tiles/w1/ground_fill.png"))
	if top != null and (top.get_width() != 256 or top.get_height() != 64):
		_fail("ground_top deveria ser 256x64")
	if fill != null and (fill.get_width() != 256 or fill.get_height() != 256):
		_fail("ground_fill deveria ser 256x256")


func _column_diff(img: Image, xa: int, xb: int) -> float:
	var total: float = 0.0
	for y in img.get_height():
		var a: Color = img.get_pixel(xa, y)
		var b: Color = img.get_pixel(xb, y)
		total += (absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)) / 3.0
	return total / float(img.get_height()) * 255.0


# --- fases -------------------------------------------------------------------

func _check_stage(path: String) -> void:
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		_fail("load falhou: %s" % path)
		return
	var stage: Node = packed.instantiate()
	root.add_child(stage)
	await process_frame
	await process_frame
	var id: String = String(stage.get("stage_id"))
	var world: int = WorldBackdrop.world_of(id)
	var before: int = _failed
	_check_seam(stage, id)
	_check_ground(stage, id, world)
	_check_particles(stage, id)
	_check_fg(stage, id, world)
	var mod: CanvasModulate = stage.get_node_or_null("CanvasModulate") as CanvasModulate
	if mod == null:
		_fail("%s sem CanvasModulate" % id)
	else:
		_modulate_by_stage[id] = mod.color
	if _failed == before:
		print("  OK %s" % id)
	stage.queue_free()
	await process_frame


func _check_seam(stage: Node, id: String) -> void:
	var boss: bool = WorldBackdrop.is_boss(id)
	var art: Sprite2D = stage.get_node_or_null("BgArt" if boss else "ParallaxBG/MidLayer/MidArt") as Sprite2D
	var mirror: Sprite2D = stage.get_node_or_null(
		"BgArtMirror" if boss else "ParallaxBG/MidLayer/MidArtMirror") as Sprite2D
	if art == null or art.texture == null:
		_fail("%s sem arte de fundo" % id)
		return
	if mirror == null:
		_fail("%s sem espelho do fundo" % id)
		return
	if not mirror.flip_h or mirror.texture != art.texture:
		_fail("%s espelho sem flip_h ou textura diferente" % id)
	var width: float = float(art.texture.get_width())
	if not is_equal_approx(mirror.position.x - art.position.x, width):
		_fail("%s espelho fora de lugar (dx=%.0f)" % [id, mirror.position.x - art.position.x])
	var want: String = WorldBackdrop.texture_path_for_stage(id)
	if not want.is_empty() and art.texture.resource_path != want:
		_fail("%s fundo=%s esperado %s" % [id, art.texture.resource_path, want])
	if not boss:
		var layer: ParallaxLayer = stage.get_node("ParallaxBG/MidLayer") as ParallaxLayer
		if not is_equal_approx(layer.motion_mirroring.x, 2.0 * width):
			_fail("%s motion_mirroring.x=%.0f esperado %.0f" % [id, layer.motion_mirroring.x, 2.0 * width])


func _check_ground(stage: Node, id: String, world: int) -> void:
	var band: Node = stage.get_node_or_null("Ground/Visual")
	if band == null:
		_fail("%s sem Ground/Visual" % id)
		return
	var top: Texture2D = band.get("top_texture") as Texture2D
	var fill: Texture2D = band.get("fill_texture") as Texture2D
	var dir: String = "assets/tiles/w%d/" % world
	if top == null or not top.resource_path.contains(dir):
		_fail("%s top_texture não é de %s" % [id, dir])
	if fill == null or not fill.resource_path.contains(dir):
		_fail("%s fill_texture não é de %s" % [id, dir])


func _check_particles(stage: Node, id: String) -> void:
	var total: int = 0
	var all_emitters: Array[Node] = stage.find_children("*", "CPUParticles2D", true, false)
	var atmo: Array[Node] = []
	var grand_total: int = 0
	for node: Node in all_emitters:
		grand_total += (node as CPUParticles2D).amount
		if _is_under_parallax(node, stage):
			atmo.append(node)
	# Atmosfera (F3) tem o próprio teto; emissores de gameplay (portal da F2,
	# FX) entram só no teto da fase inteira.
	if atmo.size() > 2:
		_fail("%s tem %d emissores de atmosfera (máx. 2)" % [id, atmo.size()])
	for node: Node in atmo:
		var amount: int = (node as CPUParticles2D).amount
		if amount > MAX_PARTICLES_EMITTER:
			_fail("%s emissor %s com %d partículas (máx. %d)" % [id, node.name, amount, MAX_PARTICLES_EMITTER])
		total += amount
	if total > MAX_PARTICLES_STAGE:
		_fail("%s soma de partículas de atmosfera %d > %d" % [id, total, MAX_PARTICLES_STAGE])
	if grand_total > MAX_PARTICLES_TOTAL:
		_fail("%s soma de partículas da fase %d > %d" % [id, grand_total, MAX_PARTICLES_TOTAL])
	if WorldBackdrop.world_of(id) > 1:
		for old: String in ["Fireflies", "Mist"]:
			if stage.find_child(old, true, false) != null:
				_fail("%s ainda tem %s do bosque" % [id, old])


func _is_under_parallax(node: Node, stage: Node) -> bool:
	var p: Node = node.get_parent()
	while p != null and p != stage:
		if p is ParallaxBackground:
			return true
		p = p.get_parent()
	return false


func _check_fg(stage: Node, id: String, world: int) -> void:
	var band: Sprite2D = stage.get_node_or_null("ParallaxBG/FgLayer/FgBand") as Sprite2D
	if band == null:
		return # chefe não tem ParallaxBG
	var want: String = "assets/backgrounds/w%d/fg_band.png" % world
	if band.texture == null or not band.texture.resource_path.contains(want):
		_fail("%s FgBand sem a silhueta %s" % [id, want])
	var layer: ParallaxLayer = band.get_parent() as ParallaxLayer
	if layer != null and not is_equal_approx(layer.motion_mirroring.x, 512.0):
		_fail("%s FgLayer mirroring=%.0f esperado 512" % [id, layer.motion_mirroring.x])


func _check_climate() -> void:
	print("-- clima --")
	var c1: Color = _modulate_by_stage.get("w1_01", Color.WHITE) as Color
	var c5: Color = _modulate_by_stage.get("w5_01", Color.WHITE) as Color
	if c1.is_equal_approx(c5):
		_fail("CanvasModulate igual em w1_01 e w5_01")
	var normal: Color = _modulate_by_stage.get("w3_04", Color.WHITE) as Color
	var boss: Color = _modulate_by_stage.get("w3_boss", Color.WHITE) as Color
	if boss.r >= normal.r or boss.b >= normal.b:
		_fail("chefe w3 não ficou mais escuro que a fase comum")
	else:
		print("  OK chefe mais escuro (%.2f vs %.2f)" % [boss.r, normal.r])
