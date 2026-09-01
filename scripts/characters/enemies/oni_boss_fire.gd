extends "res://scripts/characters/enemies/boss_body.gd"
## Arauto das Brasas — chase agressivo + poça de fogo no chão + investida.

enum AttackKind { CHARGE, FIRE_POOL }

@export var charge_speed: float = 500.0
@export var charge_max_time: float = 0.7
@export var charge_damage: int = 14
@export var charge_knockback: Vector2 = Vector2(250.0, -70.0)
@export var pool_time: float = 1.15
@export var pool_damage: int = 10
@export var pool_knockback: Vector2 = Vector2(80.0, -140.0)

@onready var fire_pool: Hitbox = %FirePoolHitbox


func _arm_extra_hitboxes() -> void:
	chase_speed = 165.0
	if fire_pool:
		fire_pool.team = &"enemy"
		fire_pool.disable()


func _all_hitboxes() -> Array:
	return [hitbox, fire_pool]


func _pick_attack() -> int:
	if phase >= BossCommon.PHASE_P2:
		return AttackKind.FIRE_POOL if randf() < 0.55 else AttackKind.CHARGE
	return AttackKind.CHARGE if randf() < 0.45 else AttackKind.FIRE_POOL


func _telegraph_color_for(kind: int) -> Color:
	if kind == AttackKind.FIRE_POOL:
		return Color(1.7, 0.45, 0.15, 1.0)
	return Color(1.55, 0.7, 0.3, 1.0)


func _telegraph_base_time(kind: int) -> float:
	return 0.62 if kind == AttackKind.FIRE_POOL else 0.48


func _on_attack_start(kind: int) -> void:
	if kind == AttackKind.CHARGE:
		_attack_duration = charge_max_time
		if sprite:
			sprite.modulate = Color(1.7, 1.3, 0.8, 1.0)
		BossCommon.arm_hitbox(hitbox, charge_damage, charge_knockback, _hitbox_base_x * facing, facing)
	else:
		_attack_duration = pool_time
		if sprite:
			sprite.modulate = Color(1.8, 0.5, 0.2, 1.0)
		if is_instance_valid(CombatFeel):
			CombatFeel.shake(5.0, 0.16)
		BossCommon.arm_hitbox(fire_pool, pool_damage, pool_knockback, 0.0, 0.0)


func _on_attack_tick(delta: float) -> void:
	if _pending_attack == AttackKind.CHARGE:
		var mult: float = 1.2 if phase == BossCommon.PHASE_P3 else 1.0
		velocity.x = facing * charge_speed * mult
		if is_on_wall():
			_finish_attack()
			return
	else:
		velocity.x = 0.0
	_phase_timer += delta
	if _phase_timer >= _attack_duration:
		_finish_attack()
