extends Area2D
## Pad no mapa: vida, respiração ou haste. Some e volta.

enum Kind { HP, BREATH, HASTE }

const HEAL := 28
const BREATH := 40.0
const HASTE_MUL := 1.45
const HASTE_SEC := 7.0
const RESPAWN_SEC := 14.0

var kind: int = Kind.HP
var _ready_t: float = 0.0
var _sprite: Sprite2D
var _glow: Sprite2D


func setup(kind_id: int, tex: Texture2D) -> void:
	kind = kind_id
	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = 2
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 28.0
	shape.shape = circle
	add_child(shape)
	_glow = Sprite2D.new()
	_glow.texture = tex
	_glow.modulate = Color(1.2, 1.2, 1.1, 0.35)
	_glow.scale = Vector2(1.35, 1.35)
	_glow.z_index = -1
	add_child(_glow)
	_sprite = Sprite2D.new()
	_sprite.texture = tex
	_sprite.scale = Vector2(0.72, 0.72)
	add_child(_sprite)
	body_entered.connect(_on_body)


func _process(delta: float) -> void:
	if _sprite == null:
		return
	if _ready_t > 0.0:
		_ready_t = maxf(0.0, _ready_t - delta)
		_sprite.visible = false
		_glow.visible = false
		monitoring = false
		return
	_sprite.visible = true
	_glow.visible = true
	monitoring = true
	_sprite.position.y = sin(Time.get_ticks_msec() * 0.004) * 4.0


func _on_body(body: Node) -> void:
	if _ready_t > 0.0:
		return
	if body == null or not body.has_method("heal"):
		return
	if int(body.get("hp")) <= 0:
		return
	match kind:
		Kind.HP:
			body.call("heal", HEAL)
		Kind.BREATH:
			if body.has_method("add_breath_pickup"):
				body.call("add_breath_pickup", BREATH)
		Kind.HASTE:
			if body.has_method("apply_speed_boost"):
				body.call("apply_speed_boost", HASTE_MUL, HASTE_SEC)
	_ready_t = RESPAWN_SEC
	if is_instance_valid(Audio) and Audio.has_method("play_sfx"):
		Audio.play_sfx("coin")
