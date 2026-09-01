extends SceneTree
## Headless: hitbox acompanha cada frame do golpe (startup/recovery off).
## Uso: godot --headless --path . -s res://scripts/qa/smoke_hitbox_frames.gd

const PLAYER_SCENE := "res://scenes/characters/player/player.tscn"
const STATS_PATH := "res://resources/player/player_stats.tres"
const EPS := 0.01

var _failed: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== smoke_hitbox_frames ===")
	_check_helper_phases()
	_check_helper_frames()
	_check_helper_fallback()
	_check_stats_tables()
	await _check_player_swing()
	await _check_combo_tables_live()

	if _failed > 0:
		print("=== HITBOX_FRAMES FAIL === falhas=%d" % _failed)
		quit(1)
		return
	print("=== HITBOX_FRAMES PASS ===")
	quit(0)


func _fail(msg: String) -> void:
	_failed += 1
	push_error("[hitbox-frames] %s" % msg)
	print("  FAIL %s" % msg)


func _check_helper_phases() -> void:
	print("-- helper fases --")
	if HitboxTimeline.phase_at(0.0, 0.04, 0.14) != HitboxTimeline.PHASE_STARTUP:
		_fail("t=0 deveria ser startup")
	if HitboxTimeline.phase_at(0.02, 0.04, 0.14) != HitboxTimeline.PHASE_STARTUP:
		_fail("t no startup deveria ser startup")
	if HitboxTimeline.phase_at(0.04, 0.04, 0.14) != HitboxTimeline.PHASE_ACTIVE:
		_fail("t=startup deveria ser active")
	if HitboxTimeline.phase_at(0.10, 0.04, 0.14) != HitboxTimeline.PHASE_ACTIVE:
		_fail("meio do active deveria ser active")
	if HitboxTimeline.phase_at(0.181, 0.04, 0.14) != HitboxTimeline.PHASE_RECOVERY:
		_fail("após active deveria ser recovery")
	if HitboxTimeline.phase_at(-1.0, 0.04, 0.14) != HitboxTimeline.PHASE_STARTUP:
		_fail("timer negativo deveria ser startup")
	if HitboxTimeline.is_hitbox_on(0.02, 0.04, 0.14):
		_fail("startup deveria ter hitbox off")
	if not HitboxTimeline.is_hitbox_on(0.10, 0.04, 0.14):
		_fail("active deveria ter hitbox on")
	if HitboxTimeline.is_hitbox_on(0.20, 0.04, 0.14):
		_fail("recovery deveria ter hitbox off")
	if HitboxTimeline.is_hitbox_on(0.0, 0.0, 0.0):
		_fail("active=0 não liga hitbox")


func _check_helper_frames() -> void:
	print("-- helper frames --")
	var sizes := PackedVector2Array([Vector2(10, 10), Vector2(20, 12), Vector2(30, 14)])
	var offsets := PackedFloat32Array([8.0, 16.0, 24.0])
	var start: Dictionary = HitboxTimeline.resolve(0.01, 0.04, 0.12, sizes, offsets, Vector2(9, 9), 7.0, 3)
	if bool(start["active"]):
		_fail("resolve startup veio active")
	if int(start["frame_index"]) != 0:
		_fail("startup frame_index deveria ser 0")
	if not (start["size"] as Vector2).is_equal_approx(Vector2(10, 10)):
		_fail("startup sampleou size errado")

	var early: Dictionary = HitboxTimeline.resolve(0.041, 0.04, 0.12, sizes, offsets, Vector2(9, 9), 7.0, 3)
	var late: Dictionary = HitboxTimeline.resolve(0.159, 0.04, 0.12, sizes, offsets, Vector2(9, 9), 7.0, 3)
	if not bool(early["active"]) or not bool(late["active"]):
		_fail("active resolve deveria ligar hitbox")
	var early_size: Vector2 = early["size"]
	var late_size: Vector2 = late["size"]
	if early_size.is_equal_approx(late_size):
		_fail("size do 1º e último frame active deveriam diferir")
	if is_equal_approx(float(early["offset_x"]), float(late["offset_x"])):
		_fail("offset do 1º e último frame active deveriam diferir")
	if float(early["offset_x"]) <= 0.0 or float(late["offset_x"]) <= 0.0:
		_fail("offset active deveria ser > 0 na frente")

	var rec: Dictionary = HitboxTimeline.resolve(0.20, 0.04, 0.12, sizes, offsets, Vector2(9, 9), 7.0, 3)
	if bool(rec["active"]):
		_fail("resolve recovery veio active")
	if int(rec["frame_index"]) != 2:
		_fail("recovery frame_index deveria ser último")

	if HitboxTimeline.visual_frame(0.0, 0.04, 0.12, 3) != 0:
		_fail("visual startup deveria ser 0")
	if HitboxTimeline.visual_frame(0.20, 0.04, 0.12, 3) != 2:
		_fail("visual recovery deveria ser último")
	var vis_early: int = HitboxTimeline.visual_frame(0.041, 0.04, 0.12, 3)
	var vis_late: int = HitboxTimeline.visual_frame(0.159, 0.04, 0.12, 3)
	if vis_early == vis_late:
		_fail("visual frame deveria mudar no active (got %d/%d)" % [vis_early, vis_late])
	if HitboxTimeline.visual_frame(0.1, 0.04, 0.12, 0) != 0:
		_fail("anim_count 0 deveria clamp pra 1 frame")
	if HitboxTimeline.active_frame_index(0.1, 0.04, 0.0, 3) != 2:
		_fail("active=0 (sem janela) deveria index de recovery (último)")
	if HitboxTimeline.frame_count_of(PackedVector2Array(), PackedFloat32Array(), 0) != 1:
		_fail("frame_count_of vazio deveria ser 1")


func _check_helper_fallback() -> void:
	print("-- helper fallback --")
	var empty_s := PackedVector2Array()
	var empty_o := PackedFloat32Array()
	var pose: Dictionary = HitboxTimeline.resolve(
		0.1, 0.0, 0.2, empty_s, empty_o, Vector2(40, 30), 28.0, 1
	)
	if not bool(pose["active"]):
		_fail("fallback active deveria ligar")
	if not (pose["size"] as Vector2).is_equal_approx(Vector2(40, 30)):
		_fail("fallback size não usou scalar")
	if not is_equal_approx(float(pose["offset_x"]), 28.0):
		_fail("fallback offset não usou scalar")

	var short_s := PackedVector2Array([Vector2(11, 11)])
	var long_o := PackedFloat32Array([1.0, 2.0, 3.0])
	var mix: Dictionary = HitboxTimeline.resolve(0.15, 0.0, 0.2, short_s, long_o, Vector2(9, 9), 7.0, 0)
	if not (mix["size"] as Vector2).is_equal_approx(Vector2(11, 11)):
		_fail("size curto deveria clamp no único entry")
	if not is_equal_approx(float(mix["offset_x"]), 3.0):
		_fail("offset longo deveria samplear último no fim do active")

	var none: Dictionary = HitboxTimeline.tables_from_stats(null, HitboxTimeline.KIND_BASIC, 1)
	if not (none["fallback_size"] as Vector2).is_equal_approx(Vector2(40, 30)):
		_fail("stats null deveria fallback default")


func _check_stats_tables() -> void:
	print("-- tabelas PlayerStats --")
	var stats: PlayerStats = load(STATS_PATH) as PlayerStats
	if stats == null:
		_fail("player_stats.tres não carregou")
		return
	var h1: Dictionary = HitboxTimeline.tables_from_stats(stats, HitboxTimeline.KIND_BASIC, 1)
	var h2: Dictionary = HitboxTimeline.tables_from_stats(stats, HitboxTimeline.KIND_BASIC, 2)
	var h3: Dictionary = HitboxTimeline.tables_from_stats(stats, HitboxTimeline.KIND_BASIC, 3)
	var s1: Dictionary = HitboxTimeline.tables_from_stats(stats, HitboxTimeline.KIND_SKILL_1, 1)
	var s2: Dictionary = HitboxTimeline.tables_from_stats(stats, HitboxTimeline.KIND_SKILL_2, 1)
	var ult: Dictionary = HitboxTimeline.tables_from_stats(stats, HitboxTimeline.KIND_ULTIMATE, 1)
	_assert_table_changes(h1, "hit1")
	_assert_table_changes(h2, "hit2")
	_assert_table_changes(h3, "hit3")
	_assert_table_changes(s1, "skill_1")
	_assert_table_changes(s2, "skill_2")
	_assert_table_changes(ult, "ultimate")
	var h1s: PackedVector2Array = PackedVector2Array(h1["sizes"])
	var h2s: PackedVector2Array = PackedVector2Array(h2["sizes"])
	var h3s: PackedVector2Array = PackedVector2Array(h3["sizes"])
	if h1s.is_empty() or h2s.is_empty() or h3s.is_empty():
		_fail("combo deveria ter tabela por frame")
		return
	if h1s[h1s.size() - 1].is_equal_approx(h2s[h2s.size() - 1]):
		_fail("hit2 deveria ter AABB distinto do hit1")
	if h2s[h2s.size() - 1].is_equal_approx(h3s[h3s.size() - 1]):
		_fail("hit3 deveria ter AABB distinto do hit2")


func _assert_table_changes(tables: Dictionary, label: String) -> void:
	var sizes: PackedVector2Array = PackedVector2Array(tables["sizes"])
	var offsets: PackedFloat32Array = PackedFloat32Array(tables["offsets"])
	if sizes.size() < 2:
		_fail("%s: tabela size precisa de 2+ frames (got %d)" % [label, sizes.size()])
		return
	if offsets.size() < 2:
		_fail("%s: tabela offset precisa de 2+ frames (got %d)" % [label, offsets.size()])
		return
	if sizes[0].is_equal_approx(sizes[sizes.size() - 1]):
		_fail("%s: size[0] == size[last] — hitbox não muda com o frame" % label)
	if is_equal_approx(offsets[0], offsets[offsets.size() - 1]):
		_fail("%s: offset[0] == offset[last] — hitbox não muda com o frame" % label)
	if offsets[0] <= 0.0 or offsets[offsets.size() - 1] <= 0.0:
		_fail("%s: offset deveria ser > 0 na frente" % label)


func _check_player_swing() -> void:
	print("-- player swing --")
	var packed: PackedScene = load(PLAYER_SCENE) as PackedScene
	if packed == null:
		_fail("player.tscn não carregou")
		return
	var player: Node = packed.instantiate()
	if player == null:
		_fail("player instantiate falhou")
		return
	root.add_child(player)
	await process_frame
	await physics_frame

	if not player.has_method("try_attack_basic"):
		_fail("player sem try_attack_basic()")
		player.queue_free()
		await process_frame
		return

	var hb: Hitbox = player.get_node_or_null("%Hitbox") as Hitbox
	var shape: CollisionShape2D = player.get_node_or_null("%HitboxShape") as CollisionShape2D
	var spr: AnimatedSprite2D = player.get_node_or_null("%AnimatedSprite2D") as AnimatedSprite2D
	if hb == null or shape == null:
		_fail("Hitbox/HitboxShape ausente")
		player.queue_free()
		await process_frame
		return

	var started: bool = bool(player.call("try_attack_basic"))
	if not started:
		_fail("try_attack_basic falhou")
		player.queue_free()
		await process_frame
		return

	await physics_frame
	if hb.is_active():
		_fail("startup: hitbox deveria estar off")
	if spr != null and spr.frame != 0:
		_fail("startup: sprite.frame deveria ser 0 (got %d)" % spr.frame)

	var saw_on := false
	var first_size := Vector2.ZERO
	var last_size := Vector2.ZERO
	var first_off := 0.0
	var last_off := 0.0
	var first_frame := -1
	var last_frame := -1
	var saw_off_after := false
	var captured_first := false

	for i in 40:
		await physics_frame
		var on: bool = hb.is_active()
		var rect := shape.shape as RectangleShape2D
		var sz: Vector2 = rect.size if rect else Vector2.ZERO
		var ox: float = hb.position.x
		if on:
			saw_on = true
			if ox <= EPS:
				_fail("active: hitbox.x deveria ser > 0 na frente (got %s)" % ox)
				break
			if not captured_first:
				first_size = sz
				first_off = ox
				first_frame = spr.frame if spr else 0
				captured_first = true
			last_size = sz
			last_off = ox
			last_frame = spr.frame if spr else 0
		elif saw_on:
			saw_off_after = true
			break

	if not saw_on:
		_fail("nunca ligou hitbox no active")
	if captured_first and first_size.is_equal_approx(last_size) and is_equal_approx(first_off, last_off):
		_fail("active: size/offset iguais entre 1º e último frame (size %s off %s)" % [first_size, first_off])
	if captured_first and first_frame == last_frame and first_frame >= 0:
		print("  note sprite.frame estável=%d (AABB ainda mudou? size %s→%s)" % [first_frame, first_size, last_size])
	if not saw_off_after:
		_fail("recovery: hitbox não desligou após o active")
	else:
		print("  OK swing size %s→%s offset %.1f→%.1f frame %d→%d" % [
			first_size, last_size, first_off, last_off, first_frame, last_frame,
		])

	player.queue_free()
	await process_frame


func _check_combo_tables_live() -> void:
	print("-- combo hit2/hit3 live --")
	var packed: PackedScene = load(PLAYER_SCENE) as PackedScene
	if packed == null:
		return
	var player: Node = packed.instantiate()
	root.add_child(player)
	await process_frame
	await physics_frame

	var hb: Hitbox = player.get_node_or_null("%Hitbox") as Hitbox
	var shape: CollisionShape2D = player.get_node_or_null("%HitboxShape") as CollisionShape2D
	if hb == null or shape == null:
		_fail("combo: Hitbox ausente")
		player.queue_free()
		await process_frame
		return

	var size_hit1 := Vector2.ZERO
	player.call("try_attack_basic")
	size_hit1 = await _wait_active_size(hb, shape)
	if size_hit1 == Vector2.ZERO:
		_fail("combo: não capturou AABB do hit1")
		player.queue_free()
		await process_frame
		return

	var chained := false
	for i in 20:
		await physics_frame
		if not hb.is_active():
			chained = bool(player.call("try_attack_basic"))
			break
	if not chained:
		_fail("combo: não encadeou hit2 na janela de chain")
		player.queue_free()
		await process_frame
		return

	var size_hit2: Vector2 = await _wait_active_size(hb, shape)
	if size_hit2 == Vector2.ZERO:
		_fail("combo: não capturou AABB do hit2")
	elif size_hit1.is_equal_approx(size_hit2):
		_fail("combo: hit2 usou o mesmo AABB do hit1 (%s)" % size_hit1)
	else:
		print("  OK combo hit1 size=%s hit2 size=%s" % [size_hit1, size_hit2])

	player.queue_free()
	await process_frame


func _wait_active_size(hb: Hitbox, shape: CollisionShape2D) -> Vector2:
	for i in 30:
		await physics_frame
		if hb.is_active():
			var rect := shape.shape as RectangleShape2D
			if rect:
				return rect.size
	return Vector2.ZERO
