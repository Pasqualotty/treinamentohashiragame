class_name StaticPose
extends RefCounted
## Camada procedural para animações "estátua" (<= 2 frames): idle que respira,
## skill de 1 frame com antecipação/lunge/follow-through e dash sem frames.
## Funções puras: devolvem {x, y, sx, sy, rot} (px, multiplicadores, graus) no
## referencial do PERSONAGEM virado para a direita (o player multiplica x/rot por facing).
## O quarteto (idle 7 / skill 3 frames) não passa por aqui.

const MAX_STATIC_FRAMES: int = 2
const IDLE_PERIOD: float = 2.4
const IDLE_BREATH_Y: float = 0.03
const IDLE_SWAY_PX: float = 1.5
const IDLE_ROCK_DEG: float = 0.6
const ANTICIPATION_SEC: float = 0.08
const LUNGE_PX: float = 10.0
const OVERSHOOT_PX: float = 3.0


static func is_static(frame_count: int) -> bool:
	return frame_count <= MAX_STATIC_FRAMES


static func pose(x: float = 0.0, y: float = 0.0, sx: float = 1.0, sy: float = 1.0, rot: float = 0.0) -> Dictionary:
	return {"x": x, "y": y, "sx": sx, "sy": sy, "rot": rot}


## Respiração: escala y 1.0 -> 1.03 (pivô nos pés), sway x e balanço de rotação.
## `phase` (rad) dessincroniza instâncias.
static func idle(t: float, phase: float) -> Dictionary:
	var w: float = TAU * t / IDLE_PERIOD + phase
	var breath: float = 0.5 + 0.5 * sin(w)
	return pose(
		IDLE_SWAY_PX * sin(w * 0.5),
		0.0,
		1.0 - 0.01 * breath,
		1.0 + IDLE_BREATH_Y * breath,
		IDLE_ROCK_DEG * sin(w * 0.5 + 1.0)
	)


## Skill de 1 frame: antecipação (squash 0.9/1.08) dentro do startup, lunge até
## o meio do active (a hitbox só liga em `startup`), follow-through no recovery.
static func skill(t: float, startup: float, active: float, recovery: float) -> Dictionary:
	var ant: float = minf(ANTICIPATION_SEC, maxf(startup, 0.0))
	if t < ant:
		return _anticipation(t / maxf(ant, 0.0001))
	var lunge_end: float = startup + active * 0.5
	if t < lunge_end:
		return _lunge((t - ant) / maxf(lunge_end - ant, 0.0001))
	var rec_start: float = startup + active
	if t < rec_start:
		return _lunge(1.0)
	return _follow_through((t - rec_start) / maxf(recovery, 0.0001))


static func _anticipation(p: float) -> Dictionary:
	var e: float = sin(clampf(p, 0.0, 1.0) * PI * 0.5)
	return pose(-3.0 * e, 0.0, lerpf(1.0, 0.9, e), lerpf(1.0, 1.08, e), -4.0 * e)


static func _lunge(q: float) -> Dictionary:
	var e: float = sin(clampf(q, 0.0, 1.0) * PI * 0.5)
	return pose(lerpf(-3.0, LUNGE_PX, e), 0.0, lerpf(0.9, 1.1, e), lerpf(1.08, 0.93, e), lerpf(-4.0, 5.0, e))


## Volta ao neutro com overshoot (passa um pouco do lunge e relaxa).
static func _follow_through(p: float) -> Dictionary:
	var k: float = clampf(p, 0.0, 1.0)
	if k >= 1.0:
		return pose()
	var e: float = 1.0 - k
	var over: float = sin(k * PI) * OVERSHOOT_PX
	return pose(LUNGE_PX * e * e + over, 0.0, 1.0 + 0.1 * e * e, 1.0 - 0.07 * e * e, 5.0 * e * e)


## Dash: com frames próprios o stretch é o clássico; sem frames (usa `run`) fica forte.
static func dash(ratio: float, has_frames: bool) -> Dictionary:
	var r: float = clampf(ratio, 0.0, 1.0)
	if has_frames:
		return pose(0.0, 0.0, lerpf(1.0, 1.20, r), lerpf(1.0, 0.82, r), 0.0)
	return pose(0.0, 0.0, lerpf(1.0, 1.40, r), lerpf(1.0, 0.76, r), 7.0 * r)
