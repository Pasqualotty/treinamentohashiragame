extends SceneTree
## Smoke headless: carrega player canÃ´nico, stats, hitbox/hurtbox e valida estados bÃ¡sicos.
##
## Godot:
##   Godot_v4.7.1-stable_win64_console.exe --headless --path . -s res://scripts/combat/smoke_player_test.gd


func _initialize() -> void:
	var ok: bool = true
	var messages: PackedStringArray = PackedStringArray()

	# --- PlayerStats resource ---
	var stats: Resource = load("res://resources/player/player_stats.tres")
	if stats == null:
		ok = false
		messages.append("player_stats.tres nao carregou")
	else:
		if not ("max_hp" in stats) or int(stats.get("max_hp")) < 1:
			ok = false
			messages.append("PlayerStats.max_hp invalido")
		if not ("move_speed" in stats):
			ok = false
			messages.append("PlayerStats.move_speed ausente")
		if not ("skill_1_display_name" in stats):
			ok = false
			messages.append("PlayerStats.skill_1_display_name ausente")
		else:
			var s1: String = str(stats.get("skill_1_display_name"))
			if s1.is_empty():
				ok = false
				messages.append("skill_1_display_name vazio")
		if not ("skill_2_display_name" in stats):
			ok = false
			messages.append("PlayerStats.skill_2_display_name ausente")
		# Feel fields (frente feel-combat)
		if not ("input_buffer" in stats):
			ok = false
			messages.append("PlayerStats.input_buffer ausente")
		else:
			var ib: float = float(stats.get("input_buffer"))
			if ib < 0.08 or ib > 0.20:
				ok = false
				messages.append("input_buffer fora de 0.08-0.20 (got %s)" % ib)
		if not ("move_accel" in stats):
			ok = false
			messages.append("PlayerStats.move_accel ausente")
		if not ("coyote_time" in stats):
			ok = false
			messages.append("PlayerStats.coyote_time ausente")
		if not ("attack_cancel_ratio" in stats):
			ok = false
			messages.append("PlayerStats.attack_cancel_ratio ausente")

	# --- Scripts existem ---
	var player_script: GDScript = load("res://scripts/characters/player.gd") as GDScript
	var hit_script: GDScript = load("res://scripts/combat/hitbox.gd") as GDScript
	var hurt_script: GDScript = load("res://scripts/combat/hurtbox.gd") as GDScript
	if player_script == null:
		ok = false
		messages.append("player.gd nÃ£o carregou")
	if hit_script == null or hurt_script == null:
		ok = false
		messages.append("hitbox/hurtbox scripts ausentes")

	# --- Cena canÃ´nica ---
	var packed: PackedScene = load("res://scenes/characters/player/player.tscn") as PackedScene
	if packed == null:
		ok = false
		messages.append("player.tscn nÃ£o carregou")
	else:
		var player: Node = packed.instantiate()
		if player == null:
			ok = false
			messages.append("player.tscn instantiate falhou")
		else:
			root.add_child(player)
			await process_frame
			await physics_frame

			if not player.is_in_group("player"):
				ok = false
				messages.append("player nÃ£o estÃ¡ no group 'player'")

			if not player.has_method("get_state"):
				ok = false
				messages.append("player sem get_state()")
			if not player.has_method("try_dash"):
				ok = false
				messages.append("player sem try_dash()")
			if not player.has_method("try_jump"):
				ok = false
				messages.append("player sem try_jump()")
			if not player.has_method("apply_damage"):
				ok = false
				messages.append("player sem apply_damage()")
			if not player.has_signal("died"):
				ok = false
				messages.append("player sem signal died")
			if not player.has_signal("hp_changed"):
				ok = false
				messages.append("player sem signal hp_changed")

			# NÃ³s de combate + animaÃ§Ã£o
			var hb: Node = player.get_node_or_null("Hitbox")
			var hurt: Node = player.get_node_or_null("Hurtbox")
			if hb == null:
				ok = false
				messages.append("Hitbox child ausente")
			if hurt == null:
				ok = false
				messages.append("Hurtbox child ausente")

			# Visual: AnimatedSprite2D multi-frame combat (preferido) ou Sprite2D legado.
			var vis: Node = player.get_node_or_null("AnimatedSprite2D")
			if vis == null:
				vis = player.get_node_or_null("%AnimatedSprite2D")
			if vis == null:
				vis = player.find_child("AnimatedSprite2D", true, false)
			if vis == null:
				vis = player.get_node_or_null("Sprite2D")
			if vis == null:
				vis = player.find_child("Sprite2D", true, false)
			if vis == null:
				ok = false
				messages.append("Sprite visual ausente no player canônico")
			elif vis is AnimatedSprite2D:
				var aspr := vis as AnimatedSprite2D
				if aspr.sprite_frames == null:
					ok = false
					messages.append("SpriteFrames nulo no AnimatedSprite2D")
				else:
					var sf: SpriteFrames = aspr.sprite_frames
					for need_anim: String in ["idle", "run", "attack"]:
						if not sf.has_animation(need_anim):
							ok = false
							messages.append("SpriteFrames sem anim '%s'" % need_anim)
						elif sf.get_frame_count(need_anim) < 1:
							ok = false
							messages.append("anim '%s' sem frames" % need_anim)
					print(
						"OK player AnimatedSprite2D idle=%d run=%d attack=%d"
						% [
							sf.get_frame_count("idle") if sf.has_animation("idle") else 0,
							sf.get_frame_count("run") if sf.has_animation("run") else 0,
							sf.get_frame_count("attack") if sf.has_animation("attack") else 0,
						]
					)
			elif vis is Sprite2D:
				var spr := vis as Sprite2D
				if spr.texture == null:
					ok = false
					messages.append("Sprite2D sem texture")
				else:
					print("OK player Sprite2D texture=", spr.texture.resource_path)
			else:
				ok = false
				messages.append("Visual tipo inválido: %s" % vis.get_class())

			# HP inicial
			if player.has_method("get_hp") and player.has_method("get_max_hp"):
				var hp: int = int(player.call("get_hp"))
				var max_hp: int = int(player.call("get_max_hp"))
				if hp != max_hp or max_hp <= 0:
					ok = false
					messages.append("HP inicial esperado full, got %d/%d" % [hp, max_hp])

			# apply_damage + death (espera i-frames de hurt acabarem entre hits)
			if player.has_method("apply_damage") and player.has_method("get_state"):
				var died_flag: Array = [false]
				if player.has_signal("died"):
					player.died.connect(func() -> void: died_flag[0] = true)
				var max_hp0: int = int(player.call("get_max_hp"))
				player.call("apply_damage", 10, Vector2.ZERO)
				await process_frame
				var hp2: int = int(player.call("get_hp"))
				if hp2 != max_hp0 - 10:
					ok = false
					messages.append("apply_damage nÃ£o reduziu HP corretamente (got %d)" % hp2)
				# Espera hurt_invuln default (~0.45s) + margem
				await create_timer(0.55).timeout
				player.call("apply_damage", 9999, Vector2.ZERO)
				await process_frame
				var st: Variant = player.call("get_state")
				# State.DEAD = 9 no enum unificado
				if int(st) != 9:
					ok = false
					messages.append("estado apÃ³s kill deveria ser DEAD(9), got %s" % str(st))
				if not died_flag[0]:
					ok = false
					messages.append("signal died nÃ£o emitiu")

			player.queue_free()
			await process_frame

	# --- Sandbox combat aponta pro player canÃ´nico ---
	var sandbox: PackedScene = load("res://scenes/battle/sandbox_combat.tscn") as PackedScene
	if sandbox == null:
		ok = false
		messages.append("sandbox_combat.tscn nÃ£o carregou")
	else:
		var sc: Node = sandbox.instantiate()
		root.add_child(sc)
		await process_frame
		# Player canÃ´nico: node "Player" direto OU nested PlayerSandbox/Player.
		var p: Node = sc.get_node_or_null("Player")
		if p != null and not p.is_in_group("player"):
			var nested: Node = p.get_node_or_null("Player")
			if nested != null:
				p = nested
		if p == null:
			var found: Array[Node] = sc.get_tree().get_nodes_in_group("player")
			for n: Node in found:
				if sc.is_ancestor_of(n):
					p = n
					break
		if p == null:
			ok = false
			messages.append("sandbox_combat sem node Player")
		elif not p.is_in_group("player"):
			ok = false
			messages.append("sandbox Player fora do group")
		elif p.get_script() == null:
			ok = false
			messages.append("sandbox Player sem script")
		else:
			var path: String = str(p.get_script().resource_path)
			if path.find("player.gd") < 0:
				ok = false
				messages.append("sandbox Player script nÃ£o Ã© player.gd: %s" % path)
			# Confirma visual no player do sandbox
			var svis: Node = p.get_node_or_null("AnimatedSprite2D")
			if svis == null:
				svis = p.find_child("AnimatedSprite2D", true, false)
			if svis == null:
				svis = p.get_node_or_null("Sprite2D")
			if svis == null:
				svis = p.find_child("Sprite2D", true, false)
			if svis == null:
				ok = false
				messages.append("sandbox Player sem Sprite visual")
		sc.queue_free()
		await process_frame

	# --- Game breath / ultimate API ---
	if Engine.has_singleton("Game") or true:
		# Autoload Game
		var game: Node = root.get_node_or_null("/root/Game")
		if game == null:
			# Em -s script mode autoloads ainda devem existir
			ok = false
			messages.append("Autoload Game ausente")
		else:
			game.set("breath", 0.0)
			game.call("add_breath_from_hit", 50.0)
			if float(game.get("breath")) < 50.0:
				ok = false
				messages.append("add_breath_from_hit falhou")
			game.set("breath", float(game.get("breath_max")))
			if not bool(game.call("is_ultimate_ready")):
				ok = false
				messages.append("is_ultimate_ready deveria ser true com breath full")
			game.call("consume_ultimate")
			if float(game.get("breath")) > 0.01:
				ok = false
				messages.append("consume_ultimate nÃ£o zerou breath")

	if ok:
		print("SMOKE_PLAYER_TEST PASS")
		quit(0)
	else:
		for m: String in messages:
			push_error("SMOKE_PLAYER_TEST FAIL: " + m)
		quit(1)

