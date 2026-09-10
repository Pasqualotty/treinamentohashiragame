extends Node
## Dummy local: anda no plano 2D e ataca o rival. Sem rede.

var pawn: CharacterBody2D
var rival: CharacterBody2D
var attack_range: float = 92.0
var start_delay: float = 1.2
var desired_vertical: float = 0.0

var _atk_cd: float = 0.0
var _alive_t: float = 0.0


func setup(hunter: CharacterBody2D, target: CharacterBody2D) -> void:
	pawn = hunter
	rival = target
	process_priority = -20


func _physics_process(delta: float) -> void:
	desired_vertical = 0.0
	if pawn == null or not is_instance_valid(pawn) or rival == null or not is_instance_valid(rival):
		return
	if not pawn.has_method("apply_input_frame"):
		return
	_alive_t += delta
	var hp_now: int = int(pawn.get("hp"))
	if hp_now <= 0:
		pawn.call("apply_input_frame", 0.0, 0, 0)
		return
	if _alive_t < start_delay:
		if _alive_t < 0.08:
			pawn.call("apply_input_frame", -1.0, 0, 0)
		else:
			pawn.call("apply_input_frame", 0.0, 0, 0)
		return

	var delta_pos: Vector2 = rival.global_position - pawn.global_position
	var axis_x: float = 0.0
	if absf(delta_pos.x) > 14.0:
		axis_x = signf(delta_pos.x)
	if absf(delta_pos.y) > 10.0:
		desired_vertical = clampf(delta_pos.y / 90.0, -1.0, 1.0)

	_atk_cd = maxf(0.0, _atk_cd - delta)
	var just: int = 0
	if delta_pos.length() <= attack_range and _atk_cd <= 0.0:
		just = InputFrame.BIT_ATK
		_atk_cd = 0.58
	pawn.call("apply_input_frame", axis_x, 0, just)
