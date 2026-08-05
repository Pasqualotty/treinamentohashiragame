extends CharacterBody2D
## Player can├┤nico unificado (movimento + combate MVP).
## Cena: scenes/characters/player/player.tscn
##
## State machine: idle / run / jump / dash / attack_basic / skill_1 / skill_2 /
## ultimate / hurt / dead.
##
## InputMap (s├│ actions ÔÇö sem is_key_pressed):
##   move_left/right ┬À jump ┬À advance(dash) ┬À attack_basic ┬À skill_1 ┬À skill_2 ┬À ultimate
##
## Teclas playtest (project.godot):
##   A/D ou setas ┬À Espa├ºo pulo ┬À Shift/F dash ┬À Z/J atk ┬À X/K skill1 ┬À C/L skill2 ┬À V/I ult
##
## Regras GDD:
##   - Pulo 1├ù + coyote; dash c/ cooldown **sem** i-frames
##   - Hits ÔåÆ Game.add_breath_from_hit; ultimate ÔåÆ Game.consume_ultimate + i-frames curtos
##   - Skills placeholder: "Corte em Arco" / "Investida"

enum State {
	IDLE,
	RUN,
	JUMP,
	DASH,
	ATTACK_BASIC,
	SKILL_1,
	SKILL_2,
	ULTIMATE,
	HURT,
	DEAD,
}

const DEFAULT_STATS: String = "res://resources/player/player_stats.tres"

signal hp_changed(current: int, max_hp: int)
signal died
signal state_changed(new_state: State)

@export var stats: PlayerStats

@onready var sprite: Sprite2D = %Sprite2D
@onready var hitbox: Hitbox = %Hitbox
@onready var hurtbox: Hurtbox = %Hurtbox
@onready var hitbox_shape: CollisionShape2D = %HitboxShape

var _state: State = State.IDLE
## 1.0 = direita, -1.0 = esquerda.
var _facing: float = 1.0
var _coyote_timer: float = 0.0
var _dash_cooldown_left: float = 0.0
var _dash_time_left: float = 0.0
var _air_dash_used: bool = false
var _was_on_floor: bool = false

var hp: int = 100
var _skill_1_cd: float = 0.0
var _skill_2_cd: float = 0.0
var _action_timer: float = 0.0
var _action_startup: float = 0.0
var _action_active: float = 0.0
var _action_recovery: float = 0.0
var _hurt_timer: float = 0.0
var _invuln_timer: float = 0.0
var _hitbox_base_x: float = 28.0
var _default_hitbox_size: Vector2 = Vector2(40.0, 30.0)


func _ready() -> void:
	add_to_group("player")
	if stats == null:
		stats = load(DEFAULT_STATS) as PlayerStats
	if stats == null:
		push_error("Player: PlayerStats ausente em %s" % DEFAULT_STATS)
		stats = PlayerStats.new()
	# Loja: aplica upgrades do save sem mutar o .tres base.
	if Game != null and Game.has_method("apply_upgrades_to_stats"):
		stats = Game.apply_upgrades_to_stats(stats)

	hp = stats.max_hp
	_hitbox_base_x = stats.attack_hitbox_offset_x
	_default_hitbox_size = stats.attack_hitbox_size

	if hitbox:
		hitbox.team = &"player"
		hitbox.disable()
		if not hitbox.hit.is_connected(_on_hitbox_hit):
			hitbox.hit.connect(_on_hitbox_hit)
		if is_zero_approx(_hitbox_base_x):
			_hitbox_base_x = absf(hitbox.position.x)
		if is_zero_approx(_hitbox_base_x):
			_hitbox_base_x = 28.0

	if hurtbox:
		hurtbox.team = &"player"
		hurtbox.invulnerable = false
		if not hurtbox.hurt.is_connected(_on_hurt):
			hurtbox.hurt.connect(_on_hurt)

	_apply_facing_visual()
	hp_changed.emit(hp, stats.max_hp)


func _physics_process(delta: float) -> void:
	if stats == null:
		return

	_tick_timers(delta)
	_update_coyote(delta)

	match _state:
		State.DEAD:
			velocity = Vector2.ZERO
		State.DASH:
			_process_dash(delta)
		State.HURT:
			_process_hurt(delta)
		State.ATTACK_BASIC, State.SKILL_1, State.SKILL_2, State.ULTIMATE:
			_process_action(delta)
		_:
			_process_locomotion(delta)

	move_and_slide()
	_update_state_after_move()
	_apply_facing_visual()
	_update_hurtbox_invuln()


func get_state() -> State:
	return _state


func get_facing() -> float:
	return _facing


func get_hp() -> int:
	return hp


func get_max_hp() -> int:
	return stats.max_hp if stats else 0


func is_busy() -> bool:
	return _state in [
		State.DASH,
		State.ATTACK_BASIC,
		State.SKILL_1,
		State.SKILL_2,
		State.ULTIMATE,
		State.HURT,
		State.DEAD,
	]


func try_jump() -> bool:
	if _state == State.DASH or _state == State.DEAD or _state == State.HURT:
		return false
	if _is_attack_locked():
		return false
	if not _can_jump():
		return false
	velocity.y = stats.jump_velocity
	_coyote_timer = 0.0
	_set_state(State.JUMP)
	return true


func try_dash() -> bool:
	## Dash curto na dire├º├úo que olha. Cooldown; 1 dash a├®reo. Sem i-frames.
	if _state == State.DASH or _state == State.DEAD or _state == State.HURT:
		return false
	if _is_attack_locked():
		return false
	if _dash_cooldown_left > 0.0:
		return false
	if not is_on_floor() and _air_dash_used:
		return false

	_set_state(State.DASH)
	_dash_time_left = stats.dash_duration
	_dash_cooldown_left = stats.dash_cooldown
	if not is_on_floor():
		_air_dash_used = true
	velocity.x = _facing * stats.dash_speed
	velocity.y = 0.0
	_disable_hitbox()
	return true


func apply_damage(amount: int, knockback: Vector2 = Vector2.ZERO) -> void:
	if _state == State.DEAD:
		return
	if _invuln_timer > 0.0:
		return
	if amount <= 0:
		return

	hp = maxi(0, hp - amount)
	hp_changed.emit(hp, stats.max_hp)

	if hp <= 0:
		_enter_dead()
		return

	_set_state(State.HURT)
	_hurt_timer = stats.hurt_stun
	_invuln_timer = stats.hurt_invuln
	velocity = knockback
	_disable_hitbox()
	if hurtbox:
		hurtbox.invulnerable = true


func heal_full() -> void:
	if stats == null:
		return
	hp = stats.max_hp
	hp_changed.emit(hp, stats.max_hp)


# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

func _process_locomotion(delta: float) -> void:
	if not is_on_floor():
		velocity.y = minf(velocity.y + stats.gravity * delta, stats.max_fall_speed)

	var axis: float = Input.get_axis("move_left", "move_right")
	if not is_zero_approx(axis):
		_facing = signf(axis)
		velocity.x = axis * stats.move_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, stats.move_speed)

	if Input.is_action_just_pressed("jump"):
		try_jump()
	if Input.is_action_just_pressed("advance"):
		try_dash()

	# Combate ÔÇö prioridade: ultimate > skills > basic (s├│ no ch├úo p/ MVP skills/atk)
	if Input.is_action_just_pressed("ultimate"):
		if _try_start_ultimate():
			return
	if Input.is_action_just_pressed("skill_1"):
		if _try_start_skill_1():
			return
	if Input.is_action_just_pressed("skill_2"):
		if _try_start_skill_2():
			return
	if Input.is_action_just_pressed("attack_basic"):
		if _try_start_attack_basic():
			return


func _process_dash(delta: float) -> void:
	_dash_time_left -= delta
	velocity.x = _facing * stats.dash_speed
	velocity.y = 0.0
	if _dash_time_left <= 0.0:
		velocity.x = 0.0
		_set_state(State.IDLE if is_on_floor() else State.JUMP)


func _process_hurt(delta: float) -> void:
	if not is_on_floor():
		velocity.y = minf(velocity.y + stats.gravity * delta, stats.max_fall_speed)
	else:
		velocity.x = move_toward(velocity.x, 0.0, stats.move_speed * 2.0)

	_hurt_timer -= delta
	if _hurt_timer <= 0.0:
		_set_state(State.IDLE if is_on_floor() else State.JUMP)


func _process_action(delta: float) -> void:
	if not is_on_floor():
		velocity.y = minf(velocity.y + stats.gravity * delta, stats.max_fall_speed)

	# Skill 2 investida: avan├ºa durante active.
	if _state == State.SKILL_2 and _action_timer >= _action_startup \
			and _action_timer < _action_startup + _action_active:
		velocity.x = _facing * stats.skill_2_lunge_speed
	else:
		velocity.x = 0.0

	_action_timer += delta

	var active_start: float = _action_startup
	var active_end: float = _action_startup + _action_active
	if _action_timer >= active_start and _action_timer < active_end:
		if hitbox and not hitbox.is_active():
			_enable_hitbox_for_current_action()
	else:
		if hitbox and hitbox.is_active():
			hitbox.disable()

	var total: float = _action_startup + _action_active + _action_recovery
	if _action_timer >= total:
		_disable_hitbox()
		_set_state(State.IDLE if is_on_floor() else State.JUMP)


func _try_start_attack_basic() -> bool:
	if _is_attack_locked() or _state == State.DASH or _state == State.DEAD or _state == State.HURT:
		return false
	if not is_on_floor():
		return false
	_begin_action(
		State.ATTACK_BASIC,
		stats.attack_startup,
		stats.attack_active,
		stats.attack_recovery,
		stats.attack_damage,
		stats.attack_knockback,
		stats.attack_hitbox_size,
		stats.attack_hitbox_offset_x
	)
	return true


func _try_start_skill_1() -> bool:
	if _is_attack_locked() or _state == State.DASH or _state == State.DEAD or _state == State.HURT:
		return false
	if _skill_1_cd > 0.0:
		return false
	if not is_on_floor():
		return false
	_skill_1_cd = stats.skill_1_cooldown
	_begin_action(
		State.SKILL_1,
		stats.skill_1_startup,
		stats.skill_1_active,
		stats.skill_1_recovery,
		stats.skill_1_damage,
		stats.skill_1_knockback,
		stats.skill_1_hitbox_size,
		stats.skill_1_hitbox_offset_x
	)
	return true


func _try_start_skill_2() -> bool:
	if _is_attack_locked() or _state == State.DASH or _state == State.DEAD or _state == State.HURT:
		return false
	if _skill_2_cd > 0.0:
		return false
	if not is_on_floor():
		return false
	_skill_2_cd = stats.skill_2_cooldown
	_begin_action(
		State.SKILL_2,
		stats.skill_2_startup,
		stats.skill_2_active,
		stats.skill_2_recovery,
		stats.skill_2_damage,
		stats.skill_2_knockback,
		stats.skill_2_hitbox_size,
		stats.skill_2_hitbox_offset_x
	)
	return true


func _try_start_ultimate() -> bool:
	if _is_attack_locked() or _state == State.DASH or _state == State.DEAD or _state == State.HURT:
		return false
	if not Game.is_ultimate_ready():
		return false
	if not is_on_floor():
		return false

	Game.consume_ultimate()
	_invuln_timer = maxf(_invuln_timer, stats.ultimate_iframes)
	if hurtbox:
		hurtbox.invulnerable = true

	_begin_action(
		State.ULTIMATE,
		stats.ultimate_startup,
		stats.ultimate_active,
		stats.ultimate_recovery,
		stats.ultimate_damage,
		stats.ultimate_knockback,
		stats.ultimate_hitbox_size,
		stats.ultimate_hitbox_offset_x
	)
	return true


func _begin_action(
	new_state: State,
	startup: float,
	active: float,
	recovery: float,
	damage: int,
	knockback: Vector2,
	hit_size: Vector2,
	offset_x: float
) -> void:
	_set_state(new_state)
	_action_timer = 0.0
	_action_startup = startup
	_action_active = active
	_action_recovery = recovery
	velocity.x = 0.0
	_hitbox_base_x = offset_x
	_configure_hitbox(damage, knockback, hit_size, offset_x)
	_disable_hitbox()
	_apply_facing_visual()


func _configure_hitbox(damage: int, knockback: Vector2, size: Vector2, offset_x: float) -> void:
	if hitbox == null:
		return
	hitbox.damage = damage
	hitbox.knockback = knockback
	hitbox.set_facing(_facing)
	hitbox.position.x = offset_x * _facing
	hitbox.position.y = -28.0
	if hitbox_shape and hitbox_shape.shape is RectangleShape2D:
		var rect: RectangleShape2D = hitbox_shape.shape as RectangleShape2D
		# Duplica se for recurso compartilhado.
		if rect.resource_local_to_scene == false:
			rect = rect.duplicate() as RectangleShape2D
			rect.resource_local_to_scene = true
			hitbox_shape.shape = rect
		rect.size = size


func _enable_hitbox_for_current_action() -> void:
	if hitbox == null:
		return
	hitbox.set_facing(_facing)
	hitbox.position.x = _hitbox_base_x * _facing
	hitbox.enable()


func _disable_hitbox() -> void:
	if hitbox and hitbox.is_active():
		hitbox.disable()
	elif hitbox:
		hitbox.disable()


func _on_hitbox_hit(_hurtbox: Hurtbox, _hit_data: HitData) -> void:
	# Respira├º├úo por hit que acerta (GDD).
	if stats:
		Game.add_breath_from_hit(stats.breath_per_hit)
	else:
		Game.add_breath_from_hit()


func _on_hurt(hit_data: HitData) -> void:
	if hit_data == null:
		return
	apply_damage(hit_data.damage, hit_data.knockback)


func _enter_dead() -> void:
	_set_state(State.DEAD)
	velocity = Vector2.ZERO
	_disable_hitbox()
	if hurtbox:
		hurtbox.invulnerable = true
	if sprite:
		sprite.modulate = Color(0.5, 0.5, 0.55, 0.9)
	died.emit()


func _update_state_after_move() -> void:
	if _state in [
		State.DASH,
		State.DEAD,
		State.HURT,
		State.ATTACK_BASIC,
		State.SKILL_1,
		State.SKILL_2,
		State.ULTIMATE,
	]:
		return

	if not is_on_floor():
		_set_state(State.JUMP)
		return

	var axis: float = Input.get_axis("move_left", "move_right")
	if absf(axis) > 0.01:
		_set_state(State.RUN)
	else:
		_set_state(State.IDLE)


func _update_coyote(delta: float) -> void:
	var on_floor: bool = is_on_floor()
	if on_floor:
		_coyote_timer = stats.coyote_time
		_air_dash_used = false
	elif _was_on_floor and not on_floor:
		pass
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)
	_was_on_floor = on_floor


func _tick_timers(delta: float) -> void:
	if _dash_cooldown_left > 0.0:
		_dash_cooldown_left = maxf(_dash_cooldown_left - delta, 0.0)
	if _skill_1_cd > 0.0:
		_skill_1_cd = maxf(_skill_1_cd - delta, 0.0)
	if _skill_2_cd > 0.0:
		_skill_2_cd = maxf(_skill_2_cd - delta, 0.0)
	if _invuln_timer > 0.0:
		_invuln_timer = maxf(_invuln_timer - delta, 0.0)


func _update_hurtbox_invuln() -> void:
	if hurtbox == null or _state == State.DEAD:
		return
	# i-frames de hurt/ultimate; dash N├âO d├í i-frames.
	hurtbox.invulnerable = _invuln_timer > 0.0


func _can_jump() -> bool:
	return is_on_floor() or _coyote_timer > 0.0


func _is_attack_locked() -> bool:
	return _state in [
		State.ATTACK_BASIC,
		State.SKILL_1,
		State.SKILL_2,
		State.ULTIMATE,
	]


func _set_state(new_state: State) -> void:
	if _state == new_state:
		return
	_state = new_state
	state_changed.emit(new_state)


func _apply_facing_visual() -> void:
	if sprite:
		sprite.flip_h = _facing < 0.0
	if hitbox and not hitbox.is_active():
		hitbox.position.x = _hitbox_base_x * _facing
