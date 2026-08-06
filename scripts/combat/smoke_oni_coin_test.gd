extends SceneTree
## Smoke headless: oni carrega, toma dano até morrer, spawna coin;
## pickup credita run_coins; kill NÃO credita (anti double-count).


func _initialize() -> void:
	var ok: bool = true
	var messages: PackedStringArray = PackedStringArray()

	# Autoloads ficam como filhos do root da SceneTree (não usar path /root/ absoluto aqui).
	var game: Node = root.get_node_or_null("Game")
	if game == null:
		push_error("SMOKE_ONI_COIN FAIL: autoload Game ausente")
		quit(1)
		return

	game.set("coins_run", 0)

	var oni_scene: PackedScene = load("res://scenes/characters/enemies/oni_weak.tscn") as PackedScene
	var coin_scene: PackedScene = load("res://scenes/combat/coin_pickup.tscn") as PackedScene
	if oni_scene == null or coin_scene == null:
		push_error("SMOKE_ONI_COIN FAIL: cenas não carregaram")
		quit(1)
		return

	var world: Node2D = Node2D.new()
	world.name = "SmokeWorld"
	root.add_child(world)

	# Chão mínimo para CharacterBody2D.
	var ground: StaticBody2D = StaticBody2D.new()
	ground.collision_layer = 1
	ground.collision_mask = 0
	var gshape: CollisionShape2D = CollisionShape2D.new()
	var grect: RectangleShape2D = RectangleShape2D.new()
	grect.size = Vector2(800, 40)
	gshape.shape = grect
	ground.position = Vector2(0, 40)
	ground.add_child(gshape)
	world.add_child(ground)

	# Player stub (group + layer 2) para o pickup detectar.
	var player: CharacterBody2D = CharacterBody2D.new()
	player.name = "PlayerStub"
	player.add_to_group("player")
	player.collision_layer = 2
	player.collision_mask = 1
	var pshape: CollisionShape2D = CollisionShape2D.new()
	var prect: RectangleShape2D = RectangleShape2D.new()
	prect.size = Vector2(24, 40)
	pshape.shape = prect
	player.add_child(pshape)
	player.position = Vector2(-200, 0)
	world.add_child(player)

	var oni: Node = oni_scene.instantiate()
	world.add_child(oni)
	if oni is Node2D:
		(oni as Node2D).position = Vector2(0, 0)

	# Array como ref mutável (lambda GDScript não atualiza bool local confiável).
	var defeated_flag: Array = [false]
	if oni.has_signal("defeated"):
		oni.connect("defeated", func() -> void: defeated_flag[0] = true)
	else:
		ok = false
		messages.append("oni deve declarar signal defeated")

	await process_frame
	await physics_frame
	await physics_frame

	if not oni.is_in_group("enemy"):
		ok = false
		messages.append("oni deveria estar no group enemy")

	var coins_before_kill: int = int(game.get("coins_run"))
	if coins_before_kill != 0:
		ok = false
		messages.append("coins_run deveria iniciar 0, got %d" % coins_before_kill)

	# Aplica dano via hurtbox até morrer (HP 30, hits de 10).
	var hurtbox: Node = oni.get_node_or_null("%Hurtbox")
	if hurtbox == null:
		hurtbox = oni.get_node_or_null("Hurtbox")
	if hurtbox == null or not hurtbox.has_method("receive_hit"):
		ok = false
		messages.append("hurtbox do oni não encontrada")
	else:
		var hit_script: GDScript = load("res://scripts/combat/hit_data.gd") as GDScript
		for i: int in range(4):
			var data: RefCounted = hit_script.new() as RefCounted
			data.set("damage", 10)
			data.set("knockback", Vector2(20, -10))
			hurtbox.call("receive_hit", data)
			await process_frame
			if not is_instance_valid(oni):
				break

	# Espera morte + spawn coin + queue_free do oni.
	for _i: int in range(30):
		await process_frame
		await physics_frame
		if world.get_node_or_null("OniWeak") == null and not is_instance_valid(oni):
			break
		# Nome da instância pode variar; conta coins no world.
		var any_coin: bool = false
		for c: Node in world.get_children():
			if c.is_in_group("coin_pickup"):
				any_coin = true
				break
		if any_coin:
			break

	if not bool(defeated_flag[0]):
		ok = false
		messages.append("signal defeated não emitido na morte do oni")

	var coins_after_kill: int = int(game.get("coins_run"))
	if coins_after_kill != 0:
		ok = false
		messages.append(
			"double-count: kill NÃO deve creditar; coins_run=%d (esperado 0 antes do pickup)"
			% coins_after_kill
		)

	var coin_node: Node = null
	for c: Node in world.get_children():
		if c.is_in_group("coin_pickup"):
			coin_node = c
			break

	if coin_node == null:
		# Oni pode ter spawnado e removido se lifetime curto — não; lifetime 12s.
		# Talvez ainda não removeu o oni e coin é sibling.
		ok = false
		messages.append("esperado coin_pickup no world após morte do oni")
	else:
		# Move player sobre a coin para body_entered.
		if coin_node is Node2D and player:
			player.global_position = (coin_node as Node2D).global_position
		await physics_frame
		await physics_frame
		await physics_frame
		# Fallback: chama collect se ainda existir.
		if is_instance_valid(coin_node) and coin_node.has_method("_collect"):
			coin_node.call("_collect")
		await process_frame

	var coins_after_pick: int = int(game.get("coins_run"))
	if coins_after_pick != 10:
		ok = false
		messages.append("após pickup esperado coins_run=10, got %d" % coins_after_pick)

	# Elite carrega com HP maior.
	var elite_scene: PackedScene = load("res://scenes/characters/enemies/oni_elite.tscn") as PackedScene
	if elite_scene == null:
		ok = false
		messages.append("oni_elite.tscn não carregou")
	else:
		var elite: Node = elite_scene.instantiate()
		world.add_child(elite)
		await process_frame
		var ehp: int = int(elite.get("max_hp"))
		if ehp < 50:
			ok = false
			messages.append("elite max_hp esperado >=50, got %d" % ehp)
		elite.queue_free()

	if ok:
		print("SMOKE_ONI_COIN PASS coins_run=%d" % coins_after_pick)
		quit(0)
	else:
		for m: String in messages:
			push_error("SMOKE_ONI_COIN FAIL: " + m)
		quit(1)
