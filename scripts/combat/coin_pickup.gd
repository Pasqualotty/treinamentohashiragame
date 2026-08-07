extends Area2D
## Moeda no chão. REGRA DE ECONOMIA (anti double-count):
## - Só o pickup chama `Game.add_run_coins`.
## - Morte do oni apenas spawna esta cena (não credita na kill).
## Assim o contador da run = o que o player de fato coletou no chão (GDD).

const COIN_TEX: Texture2D = preload("res://assets/ui/icons/coin.png")

@export var value: int = 10
## Tempo até sumir se ninguém pegar (0 = infinito).
@export var lifetime: float = 12.0

var _collected: bool = false
var _life_left: float = 0.0

@onready var sprite: Sprite2D = %Sprite
@onready var shape: CollisionShape2D = %CollisionShape2D


func _ready() -> void:
	add_to_group("coin_pickup")
	_life_left = lifetime
	monitoring = true
	monitorable = false
	# Detecta body do player (collision_layer = 2).
	collision_layer = 0
	collision_mask = 2
	# Hitbox generosa — moeda tem que ser fácil de pegar.
	if shape and shape.shape is CircleShape2D:
		(shape.shape as CircleShape2D).radius = maxf((shape.shape as CircleShape2D).radius, 22.0)
	elif shape and shape.shape is RectangleShape2D:
		(shape.shape as RectangleShape2D).size = Vector2(40, 40)
	z_index = 20
	if sprite:
		if sprite.texture == null:
			sprite.texture = COIN_TEX
		sprite.centered = true
		# ~48px na tela — óbvio de ver
		sprite.scale = Vector2(0.55, 0.55)
		sprite.z_index = 20
		sprite.modulate = Color.WHITE
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	# Sobe um pouco do chão pra não sumir atrás do ground
	position.y -= 18.0
	scale = Vector2(0.5, 0.5)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	set_physics_process(true)


func setup(amount: int) -> void:
	value = maxi(0, amount)


func _process(delta: float) -> void:
	if _collected:
		return
	if lifetime <= 0.0:
		return
	_life_left -= delta
	if _life_left <= 0.0:
		queue_free()
		return
	# Piscar no fim da vida.
	if sprite and _life_left < 2.0:
		sprite.modulate.a = 0.45 + 0.55 * absf(sin(_life_left * 12.0))


func _physics_process(delta: float) -> void:
	if _collected:
		return
	var player := _find_player()
	if player == null:
		return
	var d: float = global_position.distance_to(player.global_position)
	if d < 90.0:
		global_position = global_position.move_toward(player.global_position, 280.0 * delta)
	if d < 28.0:
		_collect()


func _find_player() -> Node2D:
	var tree := get_tree()
	if tree == null:
		return null
	var nodes := tree.get_nodes_in_group("player")
	if nodes.is_empty():
		return null
	return nodes[0] as Node2D


func _on_body_entered(body: Node2D) -> void:
	if _collected:
		return
	if body == null:
		return
	if not body.is_in_group("player"):
		return
	_collect()


func _collect() -> void:
	_collected = true
	set_deferred("monitoring", false)
	if value > 0:
		Game.add_run_coins(value)
	if is_instance_valid(Audio):
		Audio.play_sfx("coin", randf_range(0.95, 1.12))
	print("[CoinPickup] +%d run_coins → %d" % [value, Game.coins_run])
	queue_free()
