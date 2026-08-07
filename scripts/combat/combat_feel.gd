extends Node
## Juice de combate: hitstop curto + camera shake leve.
## Autoload `CombatFeel`. Seguro se camera/time_scale falhar.

const HITSTOP_DEFAULT: float = 0.045
const HITSTOP_SCALE: float = 0.08
const SHAKE_HIT: float = 3.5
const SHAKE_ULT: float = 7.0
const SHAKE_HIT_DUR: float = 0.10
const SHAKE_ULT_DUR: float = 0.18

var _hitstop_busy: bool = false
var _shake_token: int = 0


func hit_impact(intensity: float = 1.0, is_ultimate: bool = false) -> void:
	## Combo padrão ao acertar: hitstop + shake.
	var stop_t: float = HITSTOP_DEFAULT * clampf(intensity, 0.5, 2.0)
	if is_ultimate:
		stop_t = clampf(stop_t * 1.35, 0.04, 0.06)
	hitstop(stop_t)
	if is_ultimate:
		shake(SHAKE_ULT * intensity, SHAKE_ULT_DUR)
	else:
		shake(SHAKE_HIT * intensity, SHAKE_HIT_DUR)


func hitstop(duration_sec: float = HITSTOP_DEFAULT) -> void:
	## Congela o jogo por `duration_sec` em tempo real (0.03–0.06s).
	if _hitstop_busy:
		return
	duration_sec = clampf(duration_sec, 0.02, 0.08)
	_hitstop_busy = true
	var prev: float = Engine.time_scale
	if prev <= 0.001 or prev > 1.0:
		prev = 1.0
	Engine.time_scale = HITSTOP_SCALE
	var tree: SceneTree = get_tree()
	if tree:
		# ignore_time_scale=true → duração em wall-clock.
		await tree.create_timer(duration_sec, true, true).timeout
	# Failsafe: nunca deixa time_scale preso em slow-mo.
	if not is_inside_tree() or Engine.time_scale < 0.5:
		Engine.time_scale = 1.0
	else:
		Engine.time_scale = 1.0 if prev < 0.5 else prev
	_hitstop_busy = false


func _exit_tree() -> void:
	Engine.time_scale = 1.0
	_hitstop_busy = false


func reset_time_scale() -> void:
	Engine.time_scale = 1.0
	_hitstop_busy = false


func shake(intensity: float = SHAKE_HIT, duration_sec: float = SHAKE_HIT_DUR) -> void:
	var cam: Camera2D = _find_camera()
	if cam == null:
		return
	_shake_token += 1
	var token: int = _shake_token
	var base: Vector2 = cam.offset
	var t: float = 0.0
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	while t < duration_sec and token == _shake_token and is_instance_valid(cam):
		var falloff: float = 1.0 - (t / duration_sec)
		var amp: float = intensity * falloff
		cam.offset = base + Vector2(
			randf_range(-amp, amp),
			randf_range(-amp, amp)
		)
		await tree.process_frame
		t += tree.root.get_process_delta_time() if tree.root else 0.016
	if is_instance_valid(cam) and token == _shake_token:
		cam.offset = base


func _find_camera() -> Camera2D:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	var vp: Viewport = tree.root.get_viewport()
	if vp:
		var active: Camera2D = vp.get_camera_2d()
		if active:
			return active
	return null
