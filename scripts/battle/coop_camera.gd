extends Camera2D
## Média dos caçadores vivos. Só existe em sessão LAN.

var _targets: Array[Node2D] = []
var _offset_y: float = -40.0


func setup(from: Camera2D, targets: Array[Node2D]) -> void:
	_targets = targets
	if from != null:
		limit_left = from.limit_left
		limit_top = from.limit_top
		limit_right = from.limit_right
		limit_bottom = from.limit_bottom
		position_smoothing_enabled = from.position_smoothing_enabled
		position_smoothing_speed = from.position_smoothing_speed
		_offset_y = from.position.y
	enabled = true
	make_current()


func _physics_process(_delta: float) -> void:
	var pts: Array[Vector2] = []
	for t in _targets:
		if t == null or not is_instance_valid(t):
			continue
		if not BossCommon.is_player_alive(t):
			continue
		pts.append(t.global_position)
	if pts.is_empty():
		return
	var mid := Vector2.ZERO
	for p in pts:
		mid += p
	mid /= float(pts.size())
	global_position = mid + Vector2(0.0, _offset_y)
