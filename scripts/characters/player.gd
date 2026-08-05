extends CharacterBody2D
## Player de combate (movimento MVP): andar, 1 pulo + coyote, dash/advance c/ cooldown.
## Modular: room para attack_basic / skills (outra frente). Sem i-frames no dash.

enum State {
	IDLE,
	WALK,
	JUMP,
	DASH,
	ATTACK_BASIC,
	HURT,
	DEAD,
}

const DEFAULT_STATS: String = "res://resources/player/player_stats.tres"

@export var stats: PlayerStats

@onready var sprite: Sprite2D = %Sprite2D

var _state: State = State.IDLE
## 1.0 = direita, -1.0 = esquerda (lado que o personagem olha).
var _facing: float = 1.0
var _coyote_timer: float = 0.0
var _dash_cooldown_left: float = 0.0
var _dash_time_left: float = 0.0
var _air_dash_used: bool = false
var _was_on_floor: bool = false


func _ready() -> void:
	add_to_group("player")
	if stats == null:
		stats = load(DEFAULT_STATS) as PlayerStats
	if stats == null:
		push_error("Player: PlayerStats ausente em %s" % DEFAULT_STATS)
		stats = PlayerStats.new()
	# Aplica upgrades da loja (save) sem mutar o .tres base.
	if Game and Game.has_method("apply_upgrades_to_stats"):
		stats = Game.apply_upgrades_to_stats(stats)
	_apply_facing_visual()


func _physics_process(delta: float) -> void:
	if stats == null:
		return

	_tick_timers(delta)

	var on_floor: bool = is_on_floor()
	if on_floor:
		_coyote_timer = stats.coyote_time
		_air_dash_used = false
	elif _was_on_floor and not on_floor:
		# acabou de sair do chão — coyote já está cheio; só decai se continuar no ar
		pass
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)
	_was_on_floor = on_floor

	# Stub: frente golpe-basico preenche depois
	if Input.is_action_just_pressed("attack_basic"):
		_try_attack_basic_stub()

	match _state:
		State.DASH:
			_process_dash(delta)
		State.DEAD:
			velocity = Vector2.ZERO
		_:
			_process_move(delta)

	move_and_slide()
	_update_state_after_move()
	_apply_facing_visual()


func try_jump() -> bool:
	## Pulo 1× (solo ou coyote). Sem double jump no MVP.
	if _state == State.DASH or _state == State.DEAD or _state == State.HURT:
		return false
	if not _can_jump():
		return false
	velocity.y = stats.jump_velocity
	_coyote_timer = 0.0
	_state = State.JUMP
	return true


func try_dash() -> bool:
	## Dash curto na direção que olha. Cooldown; 1 dash aéreo até pousar. Sem i-frames.
	if _state == State.DASH or _state == State.DEAD or _state == State.HURT:
		return false
	if _dash_cooldown_left > 0.0:
		return false
	if not is_on_floor() and _air_dash_used:
		return false

	_state = State.DASH
	_dash_time_left = stats.dash_duration
	_dash_cooldown_left = stats.dash_cooldown
	if not is_on_floor():
		_air_dash_used = true
	velocity.x = _facing * stats.dash_speed
	velocity.y = 0.0
	return true


func get_state() -> State:
	return _state


func get_facing() -> float:
	return _facing


func _process_move(delta: float) -> void:
	# Gravidade (não aplica durante dash — tratado em _process_dash)
	if not is_on_floor():
		velocity.y = minf(velocity.y + stats.gravity * delta, stats.max_fall_speed)

	var axis: float = Input.get_axis("move_left", "move_right")
	if axis != 0.0:
		_facing = signf(axis)
		velocity.x = axis * stats.move_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, stats.move_speed)

	if Input.is_action_just_pressed("jump"):
		try_jump()
	if Input.is_action_just_pressed("advance"):
		try_dash()


func _process_dash(delta: float) -> void:
	_dash_time_left -= delta
	velocity.x = _facing * stats.dash_speed
	velocity.y = 0.0
	if _dash_time_left <= 0.0:
		_state = State.IDLE if is_on_floor() else State.JUMP
		velocity.x = 0.0


func _update_state_after_move() -> void:
	if _state == State.DASH or _state == State.DEAD or _state == State.HURT:
		return
	if _state == State.ATTACK_BASIC:
		return

	if not is_on_floor():
		_state = State.JUMP
		return

	var axis: float = Input.get_axis("move_left", "move_right")
	if absf(axis) > 0.01:
		_state = State.WALK
	else:
		_state = State.IDLE


func _can_jump() -> bool:
	return is_on_floor() or _coyote_timer > 0.0


func _tick_timers(delta: float) -> void:
	if _dash_cooldown_left > 0.0:
		_dash_cooldown_left = maxf(_dash_cooldown_left - delta, 0.0)


func _try_attack_basic_stub() -> void:
	# Placeholder para frente golpe-basico — não muda state no MVP de move.
	pass


func _apply_facing_visual() -> void:
	if sprite == null:
		return
	# Arte side olha pra direita por padrão; flip_h quando olha pra esquerda.
	sprite.flip_h = _facing < 0.0
