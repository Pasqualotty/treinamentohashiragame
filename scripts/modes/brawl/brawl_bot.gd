extends Node
## Máquina local: persegue, ataca e usa skill. Sem rede.

var pawn: CharacterBody2D
var rival: CharacterBody2D
var attack_range: float = 92.0
var start_delay: float = 1.2
var desired_vertical: float = 0.0

var _atk_cd: float = 0.0
var _skill_cd: float = 0.0
var _alive_t: float = 0.0
var _retarget_t: float = 0.0


func setup(hunter: CharacterBody2D, target: CharacterBody2D) -> void:
	pawn = hunter
	rival = target
	process_priority = -20


func _physics_process(delta: float) -> void:
	desired_vertical = 0.0
	if pawn == null or not is_instance_valid(pawn) or not pawn.has_method("apply_input_frame"):
		return
	_alive_t += delta
	_retarget_t -= delta
	if _retarget_t <= 0.0:
		_retarget()
		_retarget_t = 0.7
	if rival == null or not is_instance_valid(rival):
		pawn.call("apply_input_frame", 0.0, 0, 0)
		return
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
	_skill_cd = maxf(0.0, _skill_cd - delta)
	var just: int = 0
	var dist: float = delta_pos.length()
	if dist <= attack_range + 40.0 and _skill_cd <= 0.0:
		if _ult_ready():
			just = InputFrame.BIT_ULT
			_skill_cd = 2.4
		else:
			just = InputFrame.BIT_S1
			_skill_cd = 1.6
	elif dist <= attack_range and _atk_cd <= 0.0:
		just = InputFrame.BIT_ATK
		_atk_cd = 0.58
	pawn.call("apply_input_frame", axis_x, 0, just)


func _ult_ready() -> bool:
	if pawn == null:
		return false
	if pawn.has_method("get_pawn_breath"):
		return float(pawn.call("get_pawn_breath")) >= float(pawn.call("get_pawn_breath_max"))
	return false


func _retarget() -> void:
	var arena: Node = get_parent()
	if arena == null or not arena.has_method("get_hunters"):
		return
	var best: CharacterBody2D = null
	var best_d: float = 1.0e9
	var raw: Variant = arena.call("get_hunters")
	if raw is Array:
		for n: Variant in raw:
			if n == pawn or not (n is CharacterBody2D):
				continue
			var other: CharacterBody2D = n as CharacterBody2D
			if int(other.get("hp")) <= 0:
				continue
			var d: float = pawn.global_position.distance_to(other.global_position)
			if d < best_d:
				best_d = d
				best = other
	if best != null:
		rival = best
