extends SceneTree
## Smoke headless: instancia hitbox/hurtbox, simula 1 swing e verifica double-hit.


func _initialize() -> void:
	var ok: bool = true
	var messages: PackedStringArray = PackedStringArray()

	var hit_script: GDScript = load("res://scripts/combat/hitbox.gd") as GDScript
	var hurt_script: GDScript = load("res://scripts/combat/hurtbox.gd") as GDScript
	var data_script: GDScript = load("res://scripts/combat/hit_data.gd") as GDScript
	if hit_script == null or hurt_script == null or data_script == null:
		push_error("FAIL: não carregou scripts combat")
		quit(1)
		return

	var root: Node2D = Node2D.new()
	root.name = "SmokeRoot"
	self.root.add_child(root)

	var hitbox: Area2D = Area2D.new()
	hitbox.set_script(hit_script)
	hitbox.name = "Hitbox"
	root.add_child(hitbox)

	var hit_shape: CollisionShape2D = CollisionShape2D.new()
	var hit_rect: RectangleShape2D = RectangleShape2D.new()
	hit_rect.size = Vector2(40, 30)
	hit_shape.shape = hit_rect
	hitbox.add_child(hit_shape)
	hitbox.position = Vector2(0, 0)

	var hurtbox: Area2D = Area2D.new()
	hurtbox.set_script(hurt_script)
	hurtbox.name = "Hurtbox"
	root.add_child(hurtbox)

	var hurt_shape: CollisionShape2D = CollisionShape2D.new()
	var hurt_rect: RectangleShape2D = RectangleShape2D.new()
	hurt_rect.size = Vector2(40, 40)
	hurt_shape.shape = hurt_rect
	hurtbox.add_child(hurt_shape)
	hurtbox.position = Vector2(10, 0)

	var hits: Array = []
	hurtbox.hurt.connect(func(data: Variant) -> void:
		hits.append(data)
	)

	# Espera physics process para areas registrarem.
	await process_frame
	await physics_frame
	await physics_frame

	hitbox.team = &"player"
	hitbox.damage = 5
	hurtbox.team = &"enemy"

	hitbox.disable()
	if hitbox.is_active():
		ok = false
		messages.append("hitbox deveria estar inativa após disable")

	hitbox.enable()
	if not hitbox.is_active():
		ok = false
		messages.append("hitbox deveria estar ativa após enable")

	await physics_frame
	await physics_frame

	if hits.size() < 1:
		ok = false
		messages.append("esperado >=1 hit no enable com overlap")
	else:
		var d: Variant = hits[0]
		if d.damage != 5:
			ok = false
			messages.append("damage esperado 5, got %s" % str(d.damage))

	# Double-hit no mesmo swing: enable já limpa lista; segundo area_entered simulado via enable sem clear?
	# enable() limpa e re-checa — isso é novo swing. No mesmo swing, try_hit 2x deve ignorar.
	var before: int = hits.size()
	hitbox._try_hit(hurtbox)
	if hits.size() != before:
		ok = false
		messages.append("double-hit no mesmo swing não deveria aplicar de novo")

	hitbox.disable()
	if hitbox.is_active():
		ok = false
		messages.append("hitbox deveria desligar no disable")

	if ok:
		print("SMOKE_HIT_TEST PASS hits=%d" % hits.size())
		quit(0)
	else:
		for m: String in messages:
			push_error("SMOKE_HIT_TEST FAIL: " + m)
		quit(1)
