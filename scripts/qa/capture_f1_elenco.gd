extends SceneTree
## F1 — captura 1280×720 do elenco e dos onis. Janela real (NÃO usar --headless).
## HASHIRA_CAPTURE_DIR = pasta de saída. Gera:
##   f1_<id>_idle.png / _attack.png / _4s.png  (4 caçadores em stage_w1_01)
##   f1_boss_w1.png, f1_boss_w3.png            (chefes novos nas fases de chefe)
##   f1_lineup_onis.png                        (os 9 onis lado a lado no chão)
##   f1_lineup_hunters.png                     (15 caçadores lado a lado, pés numa linha)
##   f1_debug_collisions.png                   (stage com debug_collisions_hint)

const STAGE_W1 := "res://scenes/battle/stage_w1_01.tscn"
const STAGE_BOSS_W1 := "res://scenes/battle/stage_w1_boss.tscn"
const STAGE_BOSS_W3 := "res://scenes/battle/stage_w3_boss.tscn"
const PLAYER := "res://scenes/characters/player/player.tscn"
const SHOWCASE: PackedStringArray = ["tanjiro", "rengoku", "muzan", "nezuko"]
const ONIS: PackedStringArray = [
	"oni_weak", "oni_elite", "oni_charger", "oni_ranged", "oni_boss",
	"oni_boss_fire", "oni_boss_dual", "oni_boss_castle", "oni_boss_final",
]
const HUNTERS: PackedStringArray = [
	"tanjiro", "nezuko", "zenitsu", "inosuke", "tomioka", "rengoku", "shinobu", "kanao",
	"uzui", "tokito", "sanemi", "obanai", "gyomei", "yoriichi", "muzan",
]
const FLOOR_Y: float = 600.0

var _out: String = ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	root.size = Vector2i(1280, 720)
	_out = OS.get_environment("HASHIRA_CAPTURE_DIR")
	if _out.is_empty():
		print("CAPTURE FAIL HASHIRA_CAPTURE_DIR vazio")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	# HASHIRA_F1_ONLY=lineup pula as fases (só os dois lineups, rápido).
	if OS.get_environment("HASHIRA_F1_ONLY") == "lineup":
		await _lineup_onis()
		await _lineup_hunters()
		print("CAPTURE_F1 DONE")
		quit(0)
		return
	for id: String in SHOWCASE:
		await _stage_shots(id)
	await _stage_single(STAGE_BOSS_W1, "tanjiro", "f1_boss_w1.png", 3.0)
	await _stage_single(STAGE_BOSS_W3, "rengoku", "f1_boss_w3.png", 3.0)
	await _lineup_onis()
	await _lineup_hunters()
	debug_collisions_hint = true
	await _stage_single(STAGE_W1, "tanjiro", "f1_debug_collisions.png", 4.0)
	print("CAPTURE_F1 DONE")
	quit(0)


func _set_char(id: String) -> void:
	var game: Node = root.get_node_or_null("Game")
	if game != null:
		game.set("current_character_id", id)


func _load_stage(path: String, id: String) -> Node:
	_set_char(id)
	var err: Error = change_scene_to_file(path)
	if err != OK:
		print("CAPTURE FAIL stage ", path)
		return null
	for i in 12:
		await process_frame
	return current_scene


func _stage_shots(id: String) -> void:
	var stage: Node = await _load_stage(STAGE_W1, id)
	if stage == null:
		return
	await create_timer(1.0).timeout
	await _save("f1_%s_idle.png" % id)
	var p: Node = _player()
	if p != null and p.has_method("try_attack_basic"):
		p.call("try_attack_basic")
	await create_timer(0.12).timeout
	await _save("f1_%s_attack.png" % id)
	await create_timer(3.8).timeout
	await _save("f1_%s_4s.png" % id)


func _stage_single(path: String, id: String, file: String, wait: float) -> void:
	var stage: Node = await _load_stage(path, id)
	if stage == null:
		return
	await create_timer(wait).timeout
	await _save(file)


func _player() -> Node:
	var list: Array[Node] = get_nodes_in_group("player")
	return list[0] if not list.is_empty() else null


func _arena() -> Node2D:
	paused = false
	if current_scene != null:
		current_scene.queue_free()
		await process_frame
	var arena: Node2D = Node2D.new()
	root.add_child(arena)
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.32, 0.34, 0.4, 1.0)
	bg.size = Vector2(1280, 720)
	bg.z_index = -10
	arena.add_child(bg)
	var line: ColorRect = ColorRect.new()
	line.color = Color(1, 1, 1, 0.9)
	line.position = Vector2(0, FLOOR_Y)
	line.size = Vector2(1280, 2)
	line.z_index = 50
	arena.add_child(line)
	var floor_body: StaticBody2D = StaticBody2D.new()
	floor_body.collision_layer = 1
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(1400, 40)
	shape.shape = rect
	floor_body.position = Vector2(640, FLOOR_Y + 20.0)
	floor_body.add_child(shape)
	arena.add_child(floor_body)
	return arena


func _lineup_onis() -> void:
	var arena: Node2D = await _arena()
	var step: float = 1280.0 / float(ONIS.size())
	for i in ONIS.size():
		var packed: PackedScene = load("res://scenes/characters/enemies/%s.tscn" % ONIS[i]) as PackedScene
		var oni: Node2D = packed.instantiate() as Node2D
		oni.position = Vector2(step * (float(i) + 0.5), FLOOR_Y)
		arena.add_child(oni)
	await create_timer(0.6).timeout
	await _save("f1_lineup_onis.png")
	arena.queue_free()
	await process_frame


func _lineup_hunters() -> void:
	var arena: Node2D = await _arena()
	var packed: PackedScene = load(PLAYER) as PackedScene
	var step: float = 1280.0 / float(HUNTERS.size())
	for i in HUNTERS.size():
		var p: Node2D = packed.instantiate() as Node2D
		p.set("forced_character_id", HUNTERS[i])
		p.set("skip_local_upgrades", true)
		p.position = Vector2(step * (float(i) + 0.5), FLOOR_Y)
		arena.add_child(p)
	await create_timer(0.6).timeout
	await _save("f1_lineup_hunters.png")
	arena.queue_free()
	await process_frame


func _save(file: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	var path: String = _out.path_join(file)
	var err: Error = img.save_png(path)
	print("saved ", path, " err=", err)
