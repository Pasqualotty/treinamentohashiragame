extends Node
## Juice de combate: hitstop curto + camera shake leve por tipo de hit.
## Autoload `CombatFeel`. Seguro se camera/time_scale falhar.

const HITSTOP_DEFAULT: float = 0.045
const HITSTOP_SCALE: float = 0.08
const SHAKE_HIT: float = 3.5
const SHAKE_ULT: float = 7.0
const SHAKE_HIT_DUR: float = 0.10
const SHAKE_ULT_DUR: float = 0.18

## Intensidade base por tipo (feel calibrado — não redesenha dano).
const INTENSITY_BASIC: float = 1.0
const INTENSITY_SKILL: float = 1.2
const INTENSITY_ULTIMATE: float = 1.45
const INTENSITY_HURT: float = 0.7

var _hitstop_busy: bool = false
var _shake_token: int = 0
## Failsafe wall-clock: se hitstop travar, força reset em N segundos reais.
var _hitstop_watchdog_token: int = 0
const HITSTOP_WATCHDOG_SEC: float = 0.25

## Zoom-punch: fração de zoom-in por evento (câmera "viva" no kill/ultimate).
const ZOOM_PUNCH_KILL: float = 0.06
const ZOOM_PUNCH_ULT: float = 0.10
const ZOOM_PUNCH_DUR: float = 0.16
const FREEZE_FRAME_DUR: float = 0.075

var _zoom_token: int = 0


func hit_impact(intensity: float = 1.0, is_ultimate: bool = false) -> void:
	## Combo padrão ao acertar: hitstop + shake.
	var stop_t: float = HITSTOP_DEFAULT * clampf(intensity, 0.5, 2.0)
	if is_ultimate:
		stop_t = clampf(stop_t * 1.35, 0.04, 0.065)
	hitstop(stop_t)
	if is_ultimate:
		shake(SHAKE_ULT * intensity, SHAKE_ULT_DUR)
	else:
		shake(SHAKE_HIT * intensity, SHAKE_HIT_DUR)


func hit_impact_typed(kind: StringName, intensity_mul: float = 1.0) -> void:
	## Polish por tipo de hit: basic / skill / ultimate / hurt.
	var base: float = INTENSITY_BASIC
	var is_ult: bool = false
	match kind:
		&"basic":
			base = INTENSITY_BASIC
		&"skill":
			base = INTENSITY_SKILL
		&"ultimate":
			base = INTENSITY_ULTIMATE
			is_ult = true
		&"hurt":
			base = INTENSITY_HURT
			# Hurt: só shake leve, sem hitstop agressivo (controle do player).
			shake(SHAKE_HIT * base * intensity_mul * 0.55, 0.08)
			return
		_:
			base = INTENSITY_BASIC
	hit_impact(base * intensity_mul, is_ult)


func hitstop(duration_sec: float = HITSTOP_DEFAULT) -> void:
	## Congela o jogo por `duration_sec` em tempo real (0.03–0.06s).
	if _hitstop_busy:
		return
	duration_sec = clampf(duration_sec, 0.02, 0.08)
	_hitstop_busy = true
	_hitstop_watchdog_token += 1
	var my_watch: int = _hitstop_watchdog_token
	var prev: float = Engine.time_scale
	if prev <= 0.001 or prev > 1.0:
		prev = 1.0
	Engine.time_scale = HITSTOP_SCALE
	var tree: SceneTree = get_tree()
	if tree:
		# Watchdog em paralelo: se o await principal falhar, limpa time_scale.
		_hitstop_watchdog(my_watch)
		# ignore_time_scale=true → duração em wall-clock.
		await tree.create_timer(duration_sec, true, true).timeout
	# Failsafe: nunca deixa time_scale preso em slow-mo.
	if my_watch == _hitstop_watchdog_token:
		Engine.time_scale = 1.0 if prev < 0.5 else prev
		if Engine.time_scale < 0.5:
			Engine.time_scale = 1.0
		_hitstop_busy = false
		# Invalida watchdog pendente (conclusão normal).
		_hitstop_watchdog_token += 1


func _hitstop_watchdog(token: int) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	await tree.create_timer(HITSTOP_WATCHDOG_SEC, true, true).timeout
	if token != _hitstop_watchdog_token:
		return
	if _hitstop_busy or Engine.time_scale < 0.5:
		Engine.time_scale = 1.0
		_hitstop_busy = false
		_hitstop_watchdog_token += 1


func _exit_tree() -> void:
	Engine.time_scale = 1.0
	_hitstop_busy = false
	_hitstop_watchdog_token += 1


func reset_time_scale() -> void:
	Engine.time_scale = 1.0
	_hitstop_busy = false
	_hitstop_watchdog_token += 1


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


func freeze_frame(duration_sec: float = FREEZE_FRAME_DUR) -> void:
	## Freeze-frame de impacto (ultimate/kill) — mesmo mecanismo do hitstop,
	## com nome semântico próprio pra chamadas de "câmera viva".
	hitstop(duration_sec)


func zoom_punch(amount: float = ZOOM_PUNCH_KILL, duration_sec: float = ZOOM_PUNCH_DUR) -> void:
	## Punch de zoom curto (in→out) na câmera ativa. Seguro se não houver câmera.
	var cam: Camera2D = _find_camera()
	if cam == null:
		return
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	_zoom_token += 1
	var token: int = _zoom_token
	var base: Vector2 = cam.zoom
	var punch: Vector2 = base * (1.0 + clampf(amount, 0.0, 1.0))
	var half: float = maxf(duration_sec * 0.5, 0.001)
	var t: float = 0.0
	while t < duration_sec and token == _zoom_token and is_instance_valid(cam):
		var dt: float = tree.root.get_process_delta_time() if tree.root else 0.016
		t += dt
		var f: float = t / half if t < half else 1.0 - ((t - half) / half)
		f = clampf(f, 0.0, 1.0)
		cam.zoom = base.lerp(punch, f)
		await tree.process_frame
	if is_instance_valid(cam) and token == _zoom_token:
		cam.zoom = base


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
