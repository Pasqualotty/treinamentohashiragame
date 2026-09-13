extends RefCounted
## Monta o pátio grande: chão, cobertura, lanternas e pads.

const MAP_SIZE := Vector2(2880, 1620)
const TEX_YARD := "res://assets/modes/brawl/yard.png"
const TEX_GROUND := "res://assets/modes/brawl/ground.png"
const TEX_BUSH := "res://assets/modes/brawl/bush.png"
const TEX_ROCK := "res://assets/modes/brawl/rock.png"
const TEX_LANTERN := "res://assets/modes/brawl/lantern.png"
const TEX_HP := "res://assets/modes/brawl/pickup_hp.png"
const TEX_BREATH := "res://assets/modes/brawl/pickup_breath.png"
const TEX_HASTE := "res://assets/modes/brawl/pickup_haste.png"
const PICKUP_SCRIPT: Script = preload("res://scripts/modes/brawl/brawl_pickup.gd")

const SPAWNS: Array[Vector2] = [
	Vector2(620, 700),
	Vector2(2260, 700),
	Vector2(620, 1120),
	Vector2(2260, 1120),
]


static func play_rect() -> Rect2:
	return Rect2(80, 180, MAP_SIZE.x - 160, MAP_SIZE.y - 280)


static func build(world: Node2D, pickups_host: Node2D) -> void:
	_clear(world)
	_clear(pickups_host)
	_paint_ground(world)
	_paint_yard(world)
	_walls(world)
	_cover(world, Vector2(1440, 820), TEX_BUSH, Vector2(110, 72), 1.15)
	_cover(world, Vector2(980, 560), TEX_ROCK, Vector2(88, 64), 0.85)
	_cover(world, Vector2(1900, 560), TEX_ROCK, Vector2(88, 64), 0.85)
	_cover(world, Vector2(980, 1100), TEX_BUSH, Vector2(100, 68), 1.0)
	_cover(world, Vector2(1900, 1100), TEX_BUSH, Vector2(100, 68), 1.0)
	_cover(world, Vector2(1440, 420), TEX_ROCK, Vector2(70, 52), 0.7)
	_cover(world, Vector2(1440, 1220), TEX_ROCK, Vector2(70, 52), 0.7)
	_deco(world, Vector2(240, 260), TEX_LANTERN, 0.42)
	_deco(world, Vector2(2640, 260), TEX_LANTERN, 0.42)
	_deco(world, Vector2(240, 1420), TEX_LANTERN, 0.42)
	_deco(world, Vector2(2640, 1420), TEX_LANTERN, 0.42)
	_deco(world, Vector2(720, 820), TEX_LANTERN, 0.34)
	_deco(world, Vector2(2160, 820), TEX_LANTERN, 0.34)
	_spawn_pickups(pickups_host)


static func _clear(host: Node) -> void:
	if host == null:
		return
	for c: Node in host.get_children():
		c.queue_free()


static func _tex(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


static func _paint_ground(world: Node2D) -> void:
	var tex: Texture2D = _tex(TEX_GROUND)
	var tile := 256.0
	var y: float = 0.0
	while y < MAP_SIZE.y:
		var x: float = 0.0
		while x < MAP_SIZE.x:
			if tex != null:
				var spr := Sprite2D.new()
				spr.texture = tex
				spr.centered = false
				spr.position = Vector2(x, y)
				spr.scale = Vector2(tile / float(tex.get_width()), tile / float(tex.get_height()))
				spr.modulate = Color(0.72, 0.78, 0.7, 1.0)
				spr.z_index = -20
				world.add_child(spr)
			else:
				var rect := ColorRect.new()
				rect.position = Vector2(x, y)
				rect.size = Vector2(tile, tile)
				rect.color = Color(0.18, 0.16, 0.1, 1.0)
				rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
				rect.z_index = -20
				world.add_child(rect)
			x += tile
		y += tile


static func _paint_yard(world: Node2D) -> void:
	var tex: Texture2D = _tex(TEX_YARD)
	if tex == null:
		var fill := ColorRect.new()
		fill.size = MAP_SIZE
		fill.color = Color(0.07, 0.1, 0.08, 0.55)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fill.z_index = -18
		world.add_child(fill)
		return
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.centered = false
	spr.position = Vector2.ZERO
	spr.scale = Vector2(MAP_SIZE.x / float(tex.get_width()), MAP_SIZE.y / float(tex.get_height()))
	spr.modulate = Color(1, 1, 1, 0.82)
	spr.z_index = -18
	world.add_child(spr)


static func _walls(world: Node2D) -> void:
	var thick := 48.0
	_wall(world, Vector2(MAP_SIZE.x * 0.5, 24), Vector2(MAP_SIZE.x, thick))
	_wall(world, Vector2(MAP_SIZE.x * 0.5, MAP_SIZE.y - 24), Vector2(MAP_SIZE.x, thick))
	_wall(world, Vector2(24, MAP_SIZE.y * 0.5), Vector2(thick, MAP_SIZE.y))
	_wall(world, Vector2(MAP_SIZE.x - 24, MAP_SIZE.y * 0.5), Vector2(thick, MAP_SIZE.y))


static func _wall(world: Node2D, pos: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	world.add_child(body)


static func _cover(world: Node2D, pos: Vector2, path: String, hit: Vector2, scale: float) -> void:
	var body := StaticBody2D.new()
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = hit
	shape.shape = rect
	body.add_child(shape)
	var tex: Texture2D = _tex(path)
	if tex != null:
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.scale = Vector2(scale, scale)
		spr.position = Vector2(0, -18)
		body.add_child(spr)
	else:
		var box := ColorRect.new()
		box.position = -hit * 0.5
		box.size = hit
		box.color = Color(0.08, 0.22, 0.12, 1.0)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		body.add_child(box)
	world.add_child(body)


static func _deco(world: Node2D, pos: Vector2, path: String, scale: float) -> void:
	var tex: Texture2D = _tex(path)
	if tex == null:
		return
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.position = pos
	spr.scale = Vector2(scale, scale)
	spr.z_index = -2
	world.add_child(spr)


static func _spawn_pickups(host: Node2D) -> void:
	var spots: Array[Dictionary] = [
		{"pos": Vector2(1440, 300), "kind": 0, "tex": TEX_HP},
		{"pos": Vector2(1440, 1400), "kind": 0, "tex": TEX_HP},
		{"pos": Vector2(620, 820), "kind": 1, "tex": TEX_BREATH},
		{"pos": Vector2(2260, 820), "kind": 1, "tex": TEX_BREATH},
		{"pos": Vector2(1440, 620), "kind": 2, "tex": TEX_HASTE},
		{"pos": Vector2(1440, 1020), "kind": 2, "tex": TEX_HASTE},
	]
	for spec: Dictionary in spots:
		var pad: Area2D = PICKUP_SCRIPT.new() as Area2D
		pad.position = spec["pos"]
		host.add_child(pad)
		pad.call("setup", int(spec["kind"]), _tex(str(spec["tex"])))
