extends "res://scripts/characters/enemies/boss_body.gd"
## Sentinela das Salas — teleporta entre âncoras e golpea em área.

enum AttackKind { TELEPORT, SLAM }

@export var slam_active_time: float = 0.22
@export var slam_damage: int = 16
@export var slam_knockback: Vector2 = Vector2(200.0, -220.0)
@export var slam_wave_range: float = 210.0
@export var room_span: float = 200.0
@export var teleport_settle: float = 0.18

@onready var slam_hitbox_l: Hitbox = %SlamHitboxL
@onready var slam_hitbox_r: Hitbox = %SlamHitboxR

var _slam_base_offset: float = 30.0
var _rooms: PackedFloat32Array = PackedFloat32Array()
var _room_i: int = 1


func _arm_extra_hitboxes() -> void:
	# Salas NÃO são assadas aqui: WaveDirector só seta global_position depois
	# do add_child/_ready, então _home_x ainda é o x da cena (~0).
	for hb: Hitbox in [slam_hitbox_l, slam_hitbox_r]:
		if hb:
			hb.team = &"enemy"
			hb.disable()
	if slam_hitbox_l:
		_slam_base_offset = absf(slam_hitbox_l.position.x)
		if is_zero_approx(_slam_base_offset):
			_slam_base_offset = 30.0


func _all_hitboxes() -> Array:
	return [hitbox, slam_hitbox_l, slam_hitbox_r]


func _pick_attack() -> int:
	if phase >= BossCommon.PHASE_P2:
		return AttackKind.TELEPORT if randf() < 0.6 else AttackKind.SLAM
	return AttackKind.SLAM if randf() < 0.55 else AttackKind.TELEPORT


func _telegraph_color_for(kind: int) -> Color:
	if kind == AttackKind.TELEPORT:
		return Color(0.95, 0.85, 0.45, 1.0)
	return Color(1.6, 0.35, 0.35, 1.0)


func _telegraph_base_time(kind: int) -> float:
	return 0.4 if kind == AttackKind.TELEPORT else 0.6


func _on_attack_start(kind: int) -> void:
	if kind == AttackKind.TELEPORT:
		_do_teleport()
	_start_slam()


func _do_teleport() -> void:
	_ensure_rooms_from_live_x()
	if _rooms.is_empty():
		return
	var next_i: int = _next_room_index()
	_room_i = next_i
	global_position.x = _rooms[next_i]
	if sprite:
		sprite.modulate = Color(1.4, 1.25, 0.7, 1.0)


func _ensure_rooms_from_live_x() -> void:
	var live_x: float = global_position.x
	if _rooms.size() == 3 and absf(live_x - _rooms[1]) <= room_span + 1.0:
		return
	_rooms = PackedFloat32Array([live_x - room_span, live_x, live_x + room_span])
	_room_i = 1
	_home_x = live_x


func _next_room_index() -> int:
	var n: int = _rooms.size()
	if n <= 1:
		return 0
	var step: int = 1 + randi() % (n - 1)
	return (_room_i + step) % n


func _start_slam() -> void:
	_attack_duration = slam_active_time + teleport_settle
	velocity.x = 0.0
	if is_instance_valid(CombatFeel):
		CombatFeel.shake(6.5, 0.18)
	if slam_hitbox_l:
		BossCommon.arm_hitbox(
			slam_hitbox_l, slam_damage,
			Vector2(-absf(slam_knockback.x), slam_knockback.y),
			-_slam_base_offset, -1.0
		)
		BossCommon.tween_slam(self, slam_hitbox_l, -1.0, slam_wave_range, slam_active_time)
	if slam_hitbox_r:
		BossCommon.arm_hitbox(
			slam_hitbox_r, slam_damage,
			Vector2(absf(slam_knockback.x), slam_knockback.y),
			_slam_base_offset, 1.0
		)
		BossCommon.tween_slam(self, slam_hitbox_r, 1.0, slam_wave_range, slam_active_time)


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
	if sprite:
		sprite.modulate = _base_modulate
