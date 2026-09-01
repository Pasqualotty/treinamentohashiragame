extends "res://scripts/characters/enemies/boss_body.gd"
## Sombra Gêmea — golpe dos dois lados + hitbox-clone curto (não é enemy).

enum AttackKind { DUAL_SWING, CLONE }

@export var swing_time: float = 0.24
@export var swing_damage: int = 13
@export var swing_knockback: Vector2 = Vector2(200.0, -200.0)
@export var swing_wave_range: float = 200.0
@export var clone_time: float = 0.85
@export var clone_damage: int = 11
@export var clone_knockback: Vector2 = Vector2(210.0, -80.0)
@export var clone_offset: float = 90.0

@onready var slam_hitbox_l: Hitbox = %SlamHitboxL
@onready var slam_hitbox_r: Hitbox = %SlamHitboxR
@onready var clone_hitbox: Hitbox = %CloneHitbox

var _slam_base_offset: float = 30.0
var _clone_base_x: float = 90.0


func _arm_extra_hitboxes() -> void:
	for hb: Hitbox in [slam_hitbox_l, slam_hitbox_r, clone_hitbox]:
		if hb:
			hb.team = &"enemy"
			hb.disable()
	if slam_hitbox_l:
		_slam_base_offset = absf(slam_hitbox_l.position.x)
		if is_zero_approx(_slam_base_offset):
			_slam_base_offset = 30.0
	if clone_hitbox:
		_clone_base_x = absf(clone_hitbox.position.x)
		if is_zero_approx(_clone_base_x):
			_clone_base_x = clone_offset


func _all_hitboxes() -> Array:
	return [hitbox, slam_hitbox_l, slam_hitbox_r, clone_hitbox]


func _pick_attack() -> int:
	if phase >= BossCommon.PHASE_P2:
		return AttackKind.CLONE if randf() < 0.5 else AttackKind.DUAL_SWING
	return AttackKind.DUAL_SWING


func _telegraph_color_for(kind: int) -> Color:
	if kind == AttackKind.CLONE:
		return Color(0.7, 0.85, 1.7, 1.0)
	return Color(1.5, 0.4, 0.7, 1.0)


func _telegraph_base_time(kind: int) -> float:
	return 0.58 if kind == AttackKind.CLONE else 0.52


func _on_attack_start(kind: int) -> void:
	if kind == AttackKind.CLONE:
		_start_clone()
	else:
		_start_dual_swing()


func _start_dual_swing() -> void:
	_attack_duration = swing_time
	velocity.x = 0.0
	if sprite:
		sprite.modulate = Color(1.6, 0.55, 0.85, 1.0)
	if is_instance_valid(CombatFeel):
		CombatFeel.shake(6.0, 0.16)
	if slam_hitbox_l:
		BossCommon.arm_hitbox(
			slam_hitbox_l, swing_damage,
			Vector2(-absf(swing_knockback.x), swing_knockback.y),
			-_slam_base_offset, -1.0
		)
		BossCommon.tween_slam(self, slam_hitbox_l, -1.0, swing_wave_range, swing_time)
	if slam_hitbox_r:
		BossCommon.arm_hitbox(
			slam_hitbox_r, swing_damage,
			Vector2(absf(swing_knockback.x), swing_knockback.y),
			_slam_base_offset, 1.0
		)
		BossCommon.tween_slam(self, slam_hitbox_r, 1.0, swing_wave_range, swing_time)


func _start_clone() -> void:
	_attack_duration = clone_time
	velocity.x = 0.0
	if sprite:
		sprite.modulate = Color(0.85, 1.0, 1.6, 1.0)
	var clone_x: float = -facing * _clone_base_x
	BossCommon.arm_hitbox(hitbox, clone_damage, clone_knockback, _hitbox_base_x * facing, facing)
	BossCommon.arm_hitbox(clone_hitbox, clone_damage, clone_knockback, clone_x, -facing)


func _on_attack_tick(delta: float) -> void:
	velocity.x = 0.0
	_phase_timer += delta
	if _phase_timer >= _attack_duration:
		_finish_attack()


func _on_attack_end() -> void:
	BossCommon.disable_hitboxes(_all_hitboxes())
	if slam_hitbox_l:
		slam_hitbox_l.position.x = -_slam_base_offset
	if slam_hitbox_r:
		slam_hitbox_r.position.x = _slam_base_offset
	if clone_hitbox:
		clone_hitbox.position.x = -facing * _clone_base_x
	if sprite:
		sprite.modulate = _base_modulate
