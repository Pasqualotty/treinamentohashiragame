extends SceneTree
## Headless: trava as duas regressões visuais reportadas no playtest.
## Uso: godot --headless --path . -s res://scripts/qa/smoke_facing_ground.gd
##
## A) Facing dos onis — "oni espawnando ao contrário".
##    A arte base `assets/characters/enemies/oni_weak_side.png` SEM flip já
##    olha pra ESQUERDA. Então o vínculo correto é `flip_h = facing > 0`, e a
##    dedução em `_ready()` é o inverso exato. Quando os dois saem de sincronia
##    o oni anda pra um lado e "olha" pro outro.
##
## B) Cobertura do chão — "piso voando".
##    A faixa de chão precisa descer além do `limit_bottom` da Camera2D e
##    cobrir a extensão horizontal visível, senão o parallax aparece por baixo
##    da linha do chão.

## A arte base olha pra esquerda quando `flip_h = false`. Se o asset for
## redesenhado olhando pra direita, inverta ESTA constante (e o vínculo nos
## scripts de oni) — não os asserts.
const ART_FACES_LEFT: bool = true

## Onis nascem olhando pra esquerda: o player sempre entra pela esquerda da
## fase, então é pra lá que eles devem encarar no spawn.
const EXPECTED_SPAWN_FACING: float = -1.0

const ENEMY_SCENES: PackedStringArray = [
	"res://scenes/characters/enemies/oni_weak.tscn",
	"res://scenes/characters/enemies/oni_elite.tscn",
	"res://scenes/characters/enemies/oni_charger.tscn",
	"res://scenes/characters/enemies/oni_ranged.tscn",
	"res://scenes/characters/enemies/oni_boss.tscn",
]

const STAGES: PackedStringArray = [
	"res://scenes/battle/stage_w1_01.tscn",
	"res://scenes/battle/stage_w1_02.tscn",
	"res://scenes/battle/stage_w1_03.tscn",
	"res://scenes/battle/stage_w1_boss.tscn",
]

## Tolerância pra comparar geometria em float.
const EPS: float = 0.5

var _failed: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== smoke_facing_ground ===")
	await _check_facing()
	await _check_ground()

	if _failed > 0:
		print("=== FACING/GROUND FAIL === falhas=%d" % _failed)
		quit(1)
		return
	print("=== FACING/GROUND PASS ===")
	quit(0)


func _fail(msg: String) -> void:
	_failed += 1
	push_error("[facing/ground] %s" % msg)
	print("  FAIL %s" % msg)


# --- A) facing ---------------------------------------------------------------

func _check_facing() -> void:
	print("-- facing dos onis (arte base olha %s) --" % ("esquerda" if ART_FACES_LEFT else "direita"))
	for path: String in ENEMY_SCENES:
		var packed: PackedScene = load(path) as PackedScene
		if packed == null:
			_fail("load falhou: %s" % path)
			continue
		var oni: Node = packed.instantiate()
		if oni == null:
			_fail("instantiate falhou: %s" % path)
			continue
		root.add_child(oni)
		await process_frame

		var sprite: Sprite2D = oni.get_node_or_null("Sprite") as Sprite2D
		if sprite == null:
			_fail("%s sem nó Sprite" % path)
			oni.queue_free()
			await process_frame
			continue

		# Spawn: precisa encarar o lado de onde o player vem.
		var spawn_facing: float = float(oni.get("facing"))
		if not is_equal_approx(spawn_facing, EXPECTED_SPAWN_FACING):
			_fail("%s nasce com facing=%.1f, esperado %.1f" % [
				path, spawn_facing, EXPECTED_SPAWN_FACING,
			])

		# Invariante: o flip aplicado tem que casar com a direção lógica.
		if sprite.flip_h != _expected_flip(spawn_facing):
			_fail("%s pós-_ready: facing=%.1f mas flip_h=%s" % [
				path, spawn_facing, str(sprite.flip_h),
			])

		# Ida e volta forçadas — sem await no meio, pra nenhum passo de física
		# reescrever facing entre o set e a leitura.
		var hitbox: Node2D = oni.get_node_or_null("Hitbox") as Node2D
		for dir: float in [1.0, -1.0]:
			oni.set("facing", dir)
			oni.call("_apply_facing")
			var want: bool = _expected_flip(dir)
			if sprite.flip_h != want:
				_fail("%s facing=%.1f -> flip_h=%s, esperado %s" % [
					path, dir, str(sprite.flip_h), str(want),
				])
			# O hitbox segue `facing` (não `flip_h`): golpe sai do lado certo.
			if hitbox != null and not is_zero_approx(hitbox.position.x):
				if signf(hitbox.position.x) != dir:
					_fail("%s facing=%.1f mas hitbox.x=%.1f (lado errado)" % [
						path, dir, hitbox.position.x,
					])

		print("  OK %s" % path)
		oni.queue_free()
		await process_frame


func _expected_flip(dir: float) -> bool:
	return (dir > 0.0) if ART_FACES_LEFT else (dir < 0.0)


# --- B) chão -----------------------------------------------------------------

func _check_ground() -> void:
	print("-- cobertura do chão vs. câmera --")
	for path: String in STAGES:
		var packed: PackedScene = load(path) as PackedScene
		if packed == null:
			_fail("load falhou: %s" % path)
			continue
		var stage: Node = packed.instantiate()
		if stage == null:
			_fail("instantiate falhou: %s" % path)
			continue
		root.add_child(stage)
		await process_frame

		_assert_ground(path, stage)

		stage.queue_free()
		await process_frame


func _assert_ground(path: String, stage: Node) -> void:
	var ground: Node2D = stage.get_node_or_null("Ground") as Node2D
	if ground == null:
		_fail("%s sem nó Ground" % path)
		return
	var band: Node2D = ground.get_node_or_null("Visual") as Node2D
	if band == null or not band.has_method("bottom_y"):
		_fail("%s: Ground/Visual não é um GroundBand" % path)
		return
	var camera: Camera2D = stage.get_node_or_null("Player/Camera2D") as Camera2D
	if camera == null:
		_fail("%s sem Player/Camera2D" % path)
		return

	# 1) A faixa começa exatamente no topo da colisão — se divergir, o visual
	#    saiu de sincronia com a altura de caminhada.
	var shape_node: CollisionShape2D = ground.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node != null and shape_node.shape is RectangleShape2D:
		var rect: RectangleShape2D = shape_node.shape as RectangleShape2D
		var collision_top: float = shape_node.position.y - rect.size.y * 0.5
		var surface_y: float = float(band.get("surface_y"))
		if absf(surface_y - collision_top) > EPS:
			_fail("%s: surface_y=%.1f mas topo da colisão=%.1f" % [
				path, surface_y, collision_top,
			])
		# 2) Largura da faixa cobre a extensão inteira da colisão.
		var band_width: float = float(band.get("band_width"))
		if band_width + EPS < rect.size.x:
			_fail("%s: band_width=%.0f menor que a colisão (%.0f)" % [
				path, band_width, rect.size.x,
			])

	# 3) Vertical: a faixa tem que passar do limite inferior da câmera.
	var bottom_world: float = band.to_global(Vector2(0.0, float(band.call("bottom_y")))).y
	var margin: float = bottom_world - float(camera.limit_bottom)
	if margin < 0.0:
		_fail("%s: chão termina em y=%.0f, ACIMA do limit_bottom=%d (buraco de %.0f px)" % [
			path, bottom_world, camera.limit_bottom, -margin,
		])

	# 4) Horizontal: a faixa cobre toda a faixa de x que a câmera alcança.
	var half: float = float(band.get("band_width")) * 0.5
	var left_world: float = band.to_global(Vector2(-half, 0.0)).x
	var right_world: float = band.to_global(Vector2(half, 0.0)).x
	if left_world > float(camera.limit_left) + EPS:
		_fail("%s: chão começa em x=%.0f, à direita do limit_left=%d" % [
			path, left_world, camera.limit_left,
		])
	if right_world + EPS < float(camera.limit_right):
		_fail("%s: chão termina em x=%.0f, à esquerda do limit_right=%d" % [
			path, right_world, camera.limit_right,
		])

	print("  OK %s — chão até y=%.0f, %.0f px abaixo do limit_bottom=%d" % [
		path, bottom_world, margin, camera.limit_bottom,
	])
