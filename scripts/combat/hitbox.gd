class_name Hitbox
extends Area2D
## Hitbox de ataque: só causa dano enquanto `enable()` estiver ativo.
## Previne double-hit no mesmo swing via lista de instance_ids.

signal hit(hurtbox: Hurtbox, hit_data: HitData)

@export var damage: int = 1
@export var knockback: Vector2 = Vector2(160.0, -50.0)
## Time do dono — não acerta hurtboxes com o mesmo team.
@export var team: StringName = &"player"

var _active: bool = false
var _already_hit: Array[int] = []
var _swing_id: int = 0


func _ready() -> void:
	monitoring = false
	monitorable = false
	# Camada 4 = hitbox, máscara 5 = hurtbox (bits 3 e 4).
	collision_layer = 1 << 3
	collision_mask = 1 << 4
	area_entered.connect(_on_area_entered)


func is_active() -> bool:
	return _active


func enable() -> void:
	_swing_id += 1
	_already_hit.clear()
	_active = true
	monitoring = true
	# Alvos já sobrepostos no frame em que ativa.
	for area: Area2D in get_overlapping_areas():
		_try_hit(area)


func disable() -> void:
	_active = false
	monitoring = false
	_already_hit.clear()


func set_facing(dir: float) -> void:
	if is_zero_approx(dir):
		return
	var sign_dir: float = signf(dir)
	# Knockback aponta na direção do golpe.
	knockback = Vector2(absf(knockback.x) * sign_dir, knockback.y)


func _on_area_entered(area: Area2D) -> void:
	_try_hit(area)


func _try_hit(area: Area2D) -> void:
	if not _active:
		return
	if not area is Hurtbox:
		return
	var hurtbox: Hurtbox = area as Hurtbox
	if hurtbox.team == team:
		return
	var id: int = hurtbox.get_instance_id()
	if _already_hit.has(id):
		return
	_already_hit.append(id)

	var data: HitData = HitData.new()
	data.damage = damage
	data.knockback = knockback
	data.source = owner if owner else self
	data.swing_id = _swing_id

	hurtbox.receive_hit(data)
	hit.emit(hurtbox, data)
