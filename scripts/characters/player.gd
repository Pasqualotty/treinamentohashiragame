extends CharacterBody2D
## Player canonico unificado (movimento + combate MVP).
## Cena: scenes/characters/player/player.tscn
##
## State machine: idle / run / jump / dash / attack_basic / skill_1 / skill_2 /
## ultimate / hurt / dead.
##
## InputMap (so actions — sem is_key_pressed):
##   move_left/right · jump · advance(dash) · attack_basic · skill_1 · skill_2 · ultimate
##
## Teclas playtest (project.godot):
##   A/D ou setas · Espaco pulo · Shift/F dash · Z/J atk · X/K skill1 · C/L skill2 · V/I ult
##
## Regras GDD:
##   - Pulo 1x + coyote + input buffer; dash c/ cooldown **sem** i-frames
##   - Hits → Game.add_breath_from_hit; ultimate → Game.consume_ultimate + i-frames curtos
##   - Skills placeholder: "Corte em Arco" / "Investida"
##   - Juice: hit flash / knockback / hitstop / camera shake via CombatFeel
##   - Feel: accel/friction, attack cancel leve no recovery, hurt recovery firme
##
## Combo básico (3 hits): attack_basic dentro da janela de chain (mid-recovery,
## `attack_combo_chain_ratio`) ou da janela de graça pós-golpe (`attack_combo_grace`)
## encadeia hit1→hit2→hit3. Hit3 é o finalizador (mais dano/knockback + juice extra).
## Qualquer outra ação (dash/jump/skill/ultimate/hurt) ou o fim da janela reseta o
## combo pra 0. HUD escuta `combo_changed(count)` — não usar `state_changed` pra isso,
## já que os 3 hits ficam todos no mesmo State.ATTACK_BASIC.
##
## Animação: sem frames novos (3 frames por anim) — expressividade vem de squash/
## stretch/lean procedural em `_update_run_bob` (idle breathing, dash stretch,
## windup/active/recovery do golpe, recoil no hurt, squash no pouso). Isso é
## puramente cosmético (position/scale/rotation do sprite) e não interfere no
## alinhamento de frame por fase de hitbox feito em `_sync_attack_frame_to_action`.

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
## 0 = combo resetado; 1/2/3 = hit atual do combo básico (attack_basic). HUD (Frente J) escuta.
signal combo_changed(count: int)

@export var stats: PlayerStats

@onready var sprite: AnimatedSprite2D = %AnimatedSprite2D
@onready var hitbox: Hitbox = %Hitbox
@onready var hurtbox: Hurtbox = %Hurtbox
@onready var hitbox_shape: CollisionShape2D = %HitboxShape

## Altura visual alvo em px (side-scroller legível em 1280×720 / mobile).
## ~140px: personagem legível sem “formiga” no meio da tela.
const TARGET_VISUAL_HEIGHT: float = 140.0
const ANIM_IDLE: StringName = &"idle"
const ANIM_RUN: StringName = &"run"
const ANIM_ATTACK: StringName = &"attack"
const ANIM_HURT: StringName = &"hurt"

## Multi-frame combat (chroma limpo) — paths sob assets/characters/player/combat/
const IDLE_FRAME_PATHS: Array[String] = [
	"res://assets/characters/player/combat/idle_side/00.png",
	"res://assets/characters/player/combat/idle_side/01.png",
	"res://assets/characters/player/combat/idle_side/02.png",
	"res://assets/characters/player/combat/idle_side/03.png",
	"res://assets/characters/player/combat/idle_side/04.png",
	"res://assets/characters/player/combat/idle_side/05.png",
	"res://assets/characters/player/combat/idle_side/06.png",
]
const RUN_FRAME_PATHS: Array[String] = [
	"res://assets/characters/player/combat/run/00.png",
	"res://assets/characters/player/combat/run/01.png",
	"res://assets/characters/player/combat/run/02.png",
	"res://assets/characters/player/combat/run/03.png",
]
const ATTACK_FRAME_PATHS: Array[String] = [
	"res://assets/characters/player/combat/attack/00.png",
	"res://assets/characters/player/combat/attack/01.png",
	"res://assets/characters/player/combat/attack/02.png",
]
const HURT_FRAME_PATHS: Array[String] = [
	"res://assets/characters/player/combat/hurt/00.png",
]

var _state: State = State.IDLE
## 1.0 = direita, -1.0 = esquerda.
var _facing: float = 1.0
var _coyote_timer: float = 0.0
var _dash_cooldown_left: float = 0.0
var _dash_time_left: float = 0.0
var _air_dash_used: bool = false
var _was_on_floor: bool = false
## Tempo contínuo no ar — evita dust falso no spawn (landing só conta se caiu de fato).
var _air_time: float = 0.0

## Input buffers (s) — jump / attack_basic / dash (advance).
var _buf_jump: float = 0.0
var _buf_attack: float = 0.0
var _buf_dash: float = 0.0

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
var _flash_left: float = 0.0
var _base_modulate: Color = Color.WHITE
var _run_bob_t: float = 0.0
var _base_sprite_scale: float = 0.18
var _sprite_base_y: float = -48.0
const FLASH_HURT: Color = Color(1.5, 0.45, 0.45, 1.0)
const FLASH_TIME: float = 0.1

## Combo básico: 0 = sem combo; 1/2/3 = hit atual (ver signal combo_changed).
var _combo_index: int = 0
## Janela de graça (s) pós-golpe pra encadear o próximo hit sem ter cancelado
## no mid-recovery. Conta em _tick_timers; ao chegar a 0, reseta o combo.
var _combo_reset_timer: float = 0.0

## Squash de pouso (procedural, sem frame novo) — timer decai em _update_run_bob.
var _landing_squash_t: float = 0.0
const LANDING_SQUASH_DUR: float = 0.16


func _ready() -> void:
	add_to_group("player")
	# Física estável no chão (evita "patinar" / não grudar no tile).
	floor_snap_length = 12.0
	floor_max_angle = deg_to_rad(50.0)
	safe_margin = 0.12
	collision_layer = 2
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_GROUNDED
	up_direction = Vector2.UP

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

	if sprite:
		_base_modulate = Color.WHITE
		sprite.centered = true
		sprite.z_index = 2
		_setup_sprite_frames()
	_apply_facing_visual()
	_sync_sprite_to_state()
	hp_changed.emit(hp, stats.max_hp)


func _physics_process(delta: float) -> void:
	if stats == null:
		return

	_tick_timers(delta)
	_update_coyote(delta)
	_capture_input_buffers()
	_try_consume_buffers()

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

	_update_run_bob(delta)

	move_and_slide()
	_update_state_after_move()
	_apply_facing_visual()
	_update_hurtbox_invuln()
	_tick_flash(delta)


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
	if _is_attack_locked() and not _can_cancel_attack_to_mobility():
		return false
	if not _can_jump():
		return false
	if _can_cancel_attack_to_mobility():
		_disable_hitbox()
	_reset_combo()
	velocity.y = stats.jump_velocity
	_coyote_timer = 0.0
	_buf_jump = 0.0
	_set_state(State.JUMP)
	return true


func try_dash() -> bool:
	## Dash curto na direcao que olha. Cooldown; 1 dash aereo. Sem i-frames.
	if _state == State.DASH or _state == State.DEAD or _state == State.HURT:
		return false
	if _is_attack_locked() and not _can_cancel_attack_to_mobility():
		return false
	if _dash_cooldown_left > 0.0:
		return false
	if not is_on_floor() and _air_dash_used:
		return false

	if _can_cancel_attack_to_mobility():
		_disable_hitbox()

	_reset_combo()
	_set_state(State.DASH)
	_dash_time_left = stats.dash_duration
	_dash_cooldown_left = stats.dash_cooldown
	_buf_dash = 0.0
	if not is_on_floor():
		_air_dash_used = true
	velocity.x = _facing * stats.dash_speed
	velocity.y = 0.0
	_disable_hitbox()
	if is_instance_valid(Fx):
		Fx.dust(global_position)
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
	_start_flash()
	if is_instance_valid(Audio):
		Audio.play_sfx("hurt")

	if hp <= 0:
		_enter_dead()
		return

	_reset_combo()
	_set_state(State.HURT)
	_hurt_timer = stats.hurt_stun
	_invuln_timer = stats.hurt_invuln
	# Limpa buffers ofensivos no hit (evita atk "fantasma" no recovery).
	_buf_attack = 0.0
	velocity = knockback
	_disable_hitbox()
	if hurtbox:
		hurtbox.invulnerable = true
	if is_instance_valid(CombatFeel):
		CombatFeel.hit_impact_typed(&"hurt", 1.0)


func heal_full() -> void:
	if stats == null:
		return
	hp = stats.max_hp
	hp_changed.emit(hp, stats.max_hp)


# ---------------------------------------------------------------------------
# Input buffer
# ---------------------------------------------------------------------------

func _capture_input_buffers() -> void:
	if _state == State.DEAD:
		return
	var buf: float = stats.input_buffer if stats else 0.12
	if Input.is_action_just_pressed("jump"):
		_buf_jump = buf
	if Input.is_action_just_pressed("attack_basic"):
		_buf_attack = buf
	if Input.is_action_just_pressed("advance"):
		_buf_dash = buf
	# Skills/ult sem buffer longo (CD + ultimate gate); still just_pressed imediato.
	if Input.is_action_just_pressed("ultimate"):
		_try_start_ultimate()
	if Input.is_action_just_pressed("skill_1"):
		_try_start_skill_1()
	if Input.is_action_just_pressed("skill_2"):
		_try_start_skill_2()


func _try_consume_buffers() -> void:
	if _state == State.DEAD or _state == State.HURT or _state == State.DASH:
		return
	# Ordem: dash > jump > attack (mobilidade primeiro — feel responsivo).
	if _buf_dash > 0.0:
		if try_dash():
			return
	if _buf_jump > 0.0:
		if try_jump():
			return
	if _buf_attack > 0.0:
		if _try_start_attack_basic():
			_buf_attack = 0.0
			return


# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

func _process_locomotion(delta: float) -> void:
	if not is_on_floor():
		velocity.y = minf(velocity.y + stats.gravity * delta, stats.max_fall_speed)
	else:
		# Snap sutil: se está no chão e sem input vertical, zera residual.
		if velocity.y > 0.0:
			velocity.y = 0.0

	var axis: float = Input.get_axis("move_left", "move_right")
	_apply_horizontal_feel(axis, delta)

	# Buffers já capturados em _capture; fallback just_pressed se buffer zeroed.
	# (capture + consume cobrem jump/dash/attack)


func _apply_horizontal_feel(axis: float, delta: float) -> void:
	var target: float = axis * stats.move_speed
	if not is_zero_approx(axis):
		_facing = signf(axis)
		var accel: float = stats.move_accel if stats.move_accel > 0.0 else stats.move_speed * 12.0
		# Se mudou de direção, freia um pouco mais rápido (snap de virada).
		if signf(velocity.x) != 0.0 and signf(velocity.x) != signf(axis):
			accel *= 1.35
		velocity.x = move_toward(velocity.x, target, accel * delta)
	else:
		var friction: float = stats.move_friction if stats.move_friction > 0.0 else stats.move_speed * 14.0
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)


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
		var fric: float = stats.hurt_friction if stats.hurt_friction > 0.0 else stats.move_speed * 5.0
		velocity.x = move_toward(velocity.x, 0.0, fric * delta)

	_hurt_timer -= delta
	if _hurt_timer <= 0.0:
		_set_state(State.IDLE if is_on_floor() else State.JUMP)
		# Após recovery, tenta buffers de mobilidade (jump/dash) se ainda vivos.
		_try_consume_buffers()


func _process_action(delta: float) -> void:
	if not is_on_floor():
		velocity.y = minf(velocity.y + stats.gravity * delta, stats.max_fall_speed)

	# Skill 2 investida: avanca durante active.
	if _state == State.SKILL_2 and _action_timer >= _action_startup \
			and _action_timer < _action_startup + _action_active:
		velocity.x = _facing * stats.skill_2_lunge_speed
	else:
		velocity.x = 0.0

	_action_timer += delta

	# Frame + AABB da hitbox via timeline (startup/recovery off; active por frame).
	_sync_attack_frame_to_action()
	# Cancel leve: jump/dash no fim do recovery (basic e skills, não ultimate).
	if _can_cancel_attack_to_mobility():
		if _buf_dash > 0.0 and try_dash():
			return
		if _buf_jump > 0.0 and try_jump():
			return

	var total: float = _action_startup + _action_active + _action_recovery
	if _action_timer >= total:
		_disable_hitbox()
		if _state == State.ATTACK_BASIC and _combo_index > 0:
			if _combo_index >= 3:
				# Finalizador sempre fecha o combo — próximo attack_basic é hit1 novo.
				_reset_combo()
			else:
				# Não foi encadeado no mid-recovery: abre a janela de graça.
				_combo_reset_timer = stats.attack_combo_grace if stats else 0.28
		_set_state(State.IDLE if is_on_floor() else State.JUMP)
		_try_consume_buffers()


func _try_start_attack_basic() -> bool:
	if _state == State.DASH or _state == State.DEAD or _state == State.HURT:
		return false
	if _is_attack_locked():
		# Só encadeia combo se já estamos no meio de um attack_basic e a janela
		# de chain (mid-recovery) está aberta. Skills/ultimate seguem sem cancel.
		if _state != State.ATTACK_BASIC or not _can_chain_combo():
			return false
		_advance_combo()
		return true
	# Basic pode no ar — skills/ult ainda preferem chão.
	var next_hit: int = 1
	if _combo_index > 0 and _combo_index < 3 and _combo_reset_timer > 0.0:
		# Dentro da janela de graça pós-golpe: continua o combo em vez de resetar.
		next_hit = _combo_index + 1
	_start_combo_hit(next_hit)
	return true


func _can_chain_combo() -> bool:
	## Janela de cancel do golpe atual pro próximo hit do combo: abre assim que
	## o active termina (hit já conectou) e fecha em `attack_combo_chain_ratio`
	## do recovery. Hit 3 (finalizador) nunca encadeia — fecha o combo.
	if _state != State.ATTACK_BASIC or _combo_index <= 0 or _combo_index >= 3:
		return false
	if stats == null:
		return false
	var active_end: float = _action_startup + _action_active
	if _action_timer < active_end:
		return false
	var recovery_elapsed: float = _action_timer - active_end
	var ratio: float = clampf(stats.attack_combo_chain_ratio, 0.0, 1.0)
	var chain_window: float = _action_recovery * ratio
	return recovery_elapsed <= chain_window


func _advance_combo() -> void:
	_start_combo_hit(mini(_combo_index + 1, 3))


func _start_combo_hit(hit: int) -> void:
	var idx: int = clampi(hit, 1, 3)
	_combo_index = idx
	_combo_reset_timer = 0.0
	combo_changed.emit(idx)
	match idx:
		2:
			_begin_action(
				State.ATTACK_BASIC,
				stats.attack_hit2_startup,
				stats.attack_hit2_active,
				stats.attack_hit2_recovery,
				int(round(float(stats.attack_damage) * stats.attack_hit2_damage_mult)),
				stats.attack_hit2_knockback,
				stats.attack_hit2_hitbox_size,
				stats.attack_hit2_hitbox_offset_x
			)
		3:
			_begin_action(
				State.ATTACK_BASIC,
				stats.attack_hit3_startup,
				stats.attack_hit3_active,
				stats.attack_hit3_recovery,
				int(round(float(stats.attack_damage) * stats.attack_hit3_damage_mult)),
				stats.attack_hit3_knockback,
				stats.attack_hit3_hitbox_size,
				stats.attack_hit3_hitbox_offset_x
			)
		_:
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


func _reset_combo() -> void:
	if _combo_index == 0:
		return
	_combo_index = 0
	_combo_reset_timer = 0.0
	combo_changed.emit(0)


func get_combo_count() -> int:
	return _combo_index


func try_attack_basic() -> bool:
	return _try_start_attack_basic()


func _try_start_skill_1() -> bool:
	if _is_attack_locked() or _state == State.DASH or _state == State.DEAD or _state == State.HURT:
		return false
	if _skill_1_cd > 0.0:
		return false
	if not is_on_floor():
		return false
	_reset_combo()
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
	_reset_combo()
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

	_reset_combo()
	Game.consume_ultimate()
	_invuln_timer = maxf(_invuln_timer, stats.ultimate_iframes)
	if hurtbox:
		hurtbox.invulnerable = true
	if is_instance_valid(Audio):
		Audio.play_sfx("ultimate")
	if is_instance_valid(CombatFeel):
		CombatFeel.shake(CombatFeel.SHAKE_ULT, CombatFeel.SHAKE_ULT_DUR)
		if CombatFeel.has_method("freeze_frame"):
			CombatFeel.freeze_frame()
		if CombatFeel.has_method("zoom_punch"):
			CombatFeel.zoom_punch(CombatFeel.ZOOM_PUNCH_ULT, CombatFeel.ZOOM_PUNCH_DUR)

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
	# Timer/fases ANTES de _set_state: _sync_attack_frame_to_action usa esses valores
	# no frame 0 do golpe (evita pose residual do ataque anterior).
	_action_timer = 0.0
	_action_startup = startup
	_action_active = active
	_action_recovery = recovery
	_set_state(new_state)
	velocity.x = 0.0
	_hitbox_base_x = offset_x
	_configure_hitbox(damage, knockback, hit_size, offset_x)
	_disable_hitbox()
	_apply_facing_visual()
	# SFX de swing (slash) no inicio do golpe; ultimate ja tocou "ultimate".
	if new_state != State.ULTIMATE and is_instance_valid(Audio):
		Audio.play_sfx("slash", randf_range(0.95, 1.08))
	if is_instance_valid(Fx):
		var slash_kind: StringName = &"basic"
		match new_state:
			State.SKILL_1, State.SKILL_2:
				slash_kind = &"skill"
			State.ULTIMATE:
				slash_kind = &"ultimate"
			State.ATTACK_BASIC:
				slash_kind = &"skill" if _combo_index == 3 else &"basic"
			_:
				slash_kind = &"basic"
		var slash_pos: Vector2 = global_position + Vector2(offset_x * 0.55 * _facing, -28.0)
		Fx.slash(slash_pos, _facing, slash_kind)
	_sync_attack_frame_to_action()


func _configure_hitbox(damage: int, knockback: Vector2, size: Vector2, offset_x: float) -> void:
	if hitbox == null:
		return
	hitbox.damage = damage
	hitbox.knockback = knockback
	hitbox.set_facing(_facing)
	hitbox.position.x = offset_x * _facing
	hitbox.position.y = -28.0
	_set_hitbox_size(size)


func _set_hitbox_size(size: Vector2) -> void:
	if hitbox_shape == null or not (hitbox_shape.shape is RectangleShape2D):
		return
	var rect: RectangleShape2D = hitbox_shape.shape as RectangleShape2D
	if rect.resource_local_to_scene == false:
		rect = rect.duplicate() as RectangleShape2D
		rect.resource_local_to_scene = true
		hitbox_shape.shape = rect
	rect.size = size


func _disable_hitbox() -> void:
	if hitbox and hitbox.is_active():
		hitbox.disable()
	elif hitbox:
		hitbox.disable()


func _on_hitbox_hit(_hurtbox: Hurtbox, hit_data: HitData) -> void:
	# Respiracao por hit que acerta (GDD) + juice por tipo.
	if stats:
		Game.add_breath_from_hit(stats.breath_per_hit)
	else:
		Game.add_breath_from_hit()
	if is_instance_valid(Audio):
		Audio.play_sfx("hit", randf_range(0.92, 1.1))
	# Finalizador do combo (hit 3 do attack_basic): trata como golpe "skill"-tier
	# pra juice — basic sozinho é fraco demais pro impacto que um finalizador merece.
	var is_finisher: bool = _state == State.ATTACK_BASIC and _combo_index == 3
	var kind: StringName = &"basic"
	match _state:
		State.SKILL_1, State.SKILL_2:
			kind = &"skill"
		State.ULTIMATE:
			kind = &"ultimate"
		_:
			kind = &"basic"
	if is_finisher:
		kind = &"skill"
	if is_instance_valid(CombatFeel):
		CombatFeel.hit_impact_typed(kind, 1.0)
		if is_finisher and CombatFeel.has_method("zoom_punch"):
			CombatFeel.zoom_punch(CombatFeel.ZOOM_PUNCH_KILL, CombatFeel.ZOOM_PUNCH_DUR)
	if is_instance_valid(Fx):
		var spark_color: Color = Fx.COLOR_WHITE
		var spark_amount: int = 12
		var is_crit: bool = false
		match kind:
			&"skill":
				spark_color = Fx.COLOR_WATER
			&"ultimate":
				spark_color = Fx.COLOR_GOLD
				spark_amount = 18
				is_crit = true
			_:
				spark_color = Fx.COLOR_WHITE
		if is_finisher:
			spark_color = Fx.COLOR_GOLD
			spark_amount = 16
			is_crit = true
		var hit_pos: Vector2 = hitbox.global_position if hitbox else global_position
		Fx.spark(hit_pos, spark_color, spark_amount)
		Fx.damage_number(hit_pos + Vector2(0.0, -18.0), hit_data.damage if hit_data else 0, is_crit)


func _on_hurt(hit_data: HitData) -> void:
	if hit_data == null:
		return
	apply_damage(hit_data.damage, hit_data.knockback)


func _enter_dead() -> void:
	_reset_combo()
	_set_state(State.DEAD)
	velocity = Vector2.ZERO
	_buf_jump = 0.0
	_buf_attack = 0.0
	_buf_dash = 0.0
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
		if not _was_on_floor and _air_time > 0.08:
			if is_instance_valid(Fx):
				Fx.dust(global_position)
			# Squash procedural de pouso (sem frame novo) — ver _update_run_bob.
			_landing_squash_t = LANDING_SQUASH_DUR
		_air_time = 0.0
		_coyote_timer = stats.coyote_time
		_air_dash_used = false
	else:
		_air_time += delta
		if _was_on_floor:
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
	if _buf_jump > 0.0:
		_buf_jump = maxf(_buf_jump - delta, 0.0)
	if _buf_attack > 0.0:
		_buf_attack = maxf(_buf_attack - delta, 0.0)
	if _buf_dash > 0.0:
		_buf_dash = maxf(_buf_dash - delta, 0.0)
	if _combo_reset_timer > 0.0:
		_combo_reset_timer = maxf(_combo_reset_timer - delta, 0.0)
		if _combo_reset_timer <= 0.0:
			_reset_combo()


func _update_hurtbox_invuln() -> void:
	if hurtbox == null or _state == State.DEAD:
		return
	# i-frames de hurt/ultimate; dash NAO da i-frames.
	hurtbox.invulnerable = _invuln_timer > 0.0


func _start_flash() -> void:
	_flash_left = FLASH_TIME
	if sprite and _state != State.DEAD:
		sprite.modulate = FLASH_HURT


func _tick_flash(delta: float) -> void:
	if _flash_left <= 0.0:
		return
	_flash_left -= delta
	if _flash_left <= 0.0 and sprite and _state != State.DEAD:
		sprite.modulate = _base_modulate


func _can_jump() -> bool:
	return is_on_floor() or _coyote_timer > 0.0


func _is_attack_locked() -> bool:
	return _state in [
		State.ATTACK_BASIC,
		State.SKILL_1,
		State.SKILL_2,
		State.ULTIMATE,
	]


func _can_cancel_attack_to_mobility() -> bool:
	## Janela leve no recovery de basic/skills (não ultimate).
	if _state not in [State.ATTACK_BASIC, State.SKILL_1, State.SKILL_2]:
		return false
	var total: float = _action_startup + _action_active + _action_recovery
	if total <= 0.0 or _action_recovery <= 0.0:
		return false
	var recovery_start: float = _action_startup + _action_active
	if _action_timer < recovery_start:
		return false
	var into_recovery: float = _action_timer - recovery_start
	var ratio: float = stats.attack_cancel_ratio if stats else 0.45
	ratio = clampf(ratio, 0.0, 1.0)
	# Cancel só na fração final do recovery (ex.: últimos 45%).
	var cancel_from: float = _action_recovery * (1.0 - ratio)
	return into_recovery >= cancel_from


func _set_state(new_state: State) -> void:
	if _state == new_state:
		return
	_state = new_state
	state_changed.emit(new_state)
	_sync_sprite_to_state()


func _setup_sprite_frames() -> void:
	if sprite == null:
		return
	var frames: SpriteFrames = SpriteFrames.new()
	_add_anim_from_paths(frames, ANIM_IDLE, IDLE_FRAME_PATHS, 11.0, true)
	_add_anim_from_paths(frames, ANIM_RUN, RUN_FRAME_PATHS, 14.0, true)
	_add_anim_from_paths(frames, ANIM_ATTACK, ATTACK_FRAME_PATHS, 12.0, false)
	_add_anim_from_paths(frames, ANIM_HURT, HURT_FRAME_PATHS, 1.0, false)
	sprite.sprite_frames = frames
	sprite.centered = true
	# Escala por altura da primeira textura disponível (pés no chão via position.y).
	var sample: Texture2D = _first_texture(frames)
	if sample != null and sample.get_height() > 0:
		_base_sprite_scale = TARGET_VISUAL_HEIGHT / float(sample.get_height())
	else:
		_base_sprite_scale = 0.18
	_sprite_base_y = -TARGET_VISUAL_HEIGHT * 0.5
	sprite.scale = Vector2(_base_sprite_scale, _base_sprite_scale)
	sprite.position = Vector2(0.0, _sprite_base_y)
	sprite.play(ANIM_IDLE)


func _add_anim_from_paths(
	frames: SpriteFrames,
	anim_name: StringName,
	paths: Array[String],
	fps: float,
	loop: bool
) -> void:
	if frames.has_animation(anim_name):
		frames.remove_animation(anim_name)
	frames.add_animation(anim_name)
	frames.set_animation_speed(anim_name, fps)
	frames.set_animation_loop(anim_name, loop)
	for path: String in paths:
		if not ResourceLoader.exists(path):
			push_warning("Player: frame ausente %s" % path)
			continue
		var tex: Texture2D = load(path) as Texture2D
		if tex == null:
			push_warning("Player: falha ao load %s" % path)
			continue
		frames.add_frame(anim_name, tex)


func _first_texture(frames: SpriteFrames) -> Texture2D:
	for anim: StringName in [ANIM_IDLE, ANIM_RUN, ANIM_ATTACK, ANIM_HURT]:
		if frames.has_animation(anim) and frames.get_frame_count(anim) > 0:
			return frames.get_frame_texture(anim, 0)
	return null


func _sync_sprite_to_state() -> void:
	if sprite == null or sprite.sprite_frames == null:
		return
	# Nunca deixa o sprite “lavado” / sem cor fora do flash de dano.
	if _flash_left <= 0.0 and _state != State.DEAD:
		sprite.modulate = _base_modulate
	match _state:
		State.RUN, State.DASH:
			_play_anim(ANIM_RUN)
		State.ATTACK_BASIC, State.SKILL_1, State.SKILL_2, State.ULTIMATE:
			# Ataque: controlamos frame por fase de hitbox (não auto-play solto).
			_play_anim(ANIM_ATTACK, false)
			sprite.pause()
			_sync_attack_frame_to_action()
		State.HURT:
			_play_anim(ANIM_HURT, false)
		State.DEAD:
			_play_anim(ANIM_HURT, false)
			sprite.modulate = Color(0.55, 0.55, 0.6, 0.95)
		State.JUMP:
			# Pose de corrida congelada no ar (sem piscar idle/run).
			if sprite.animation != ANIM_RUN:
				_play_anim(ANIM_RUN, false)
			sprite.pause()
			if sprite.sprite_frames.get_frame_count(sprite.animation) > 0:
				sprite.frame = mini(1, sprite.sprite_frames.get_frame_count(sprite.animation) - 1)
		_:
			_play_anim(ANIM_IDLE)
	_apply_facing_visual()


func _play_anim(anim: StringName, restart: bool = true) -> void:
	if sprite == null or sprite.sprite_frames == null:
		return
	if not sprite.sprite_frames.has_animation(anim):
		return
	# Evita restart a cada frame (causa “pisca” / flash branco).
	if sprite.animation == anim and sprite.is_playing() and not restart:
		return
	if sprite.animation == anim and not restart:
		if not sprite.is_playing() and anim != ANIM_ATTACK:
			sprite.play(anim)
		return
	sprite.play(anim)


func _sync_attack_frame_to_action() -> void:
	## Alinha frame de arte + AABB da hitbox ao timeline (por frame do golpe).
	if sprite == null or sprite.sprite_frames == null:
		return
	if _state not in [State.ATTACK_BASIC, State.SKILL_1, State.SKILL_2, State.ULTIMATE]:
		return
	if not sprite.sprite_frames.has_animation(ANIM_ATTACK):
		return
	var count: int = sprite.sprite_frames.get_frame_count(ANIM_ATTACK)
	if count <= 0:
		return
	if sprite.animation != ANIM_ATTACK:
		sprite.play(ANIM_ATTACK)
	sprite.pause()
	sprite.frame = HitboxTimeline.visual_frame(
		_action_timer, _action_startup, _action_active, count
	)
	_apply_hitbox_timeline(count)


func _hitbox_action_kind() -> StringName:
	match _state:
		State.SKILL_1:
			return HitboxTimeline.KIND_SKILL_1
		State.SKILL_2:
			return HitboxTimeline.KIND_SKILL_2
		State.ULTIMATE:
			return HitboxTimeline.KIND_ULTIMATE
		_:
			return HitboxTimeline.KIND_BASIC


func _apply_hitbox_timeline(anim_frames: int) -> void:
	if hitbox == null:
		return
	var tables: Dictionary = HitboxTimeline.tables_from_stats(
		stats, _hitbox_action_kind(), _combo_index
	)
	var sizes: PackedVector2Array = PackedVector2Array(tables["sizes"])
	var offsets: PackedFloat32Array = PackedFloat32Array(tables["offsets"])
	var pose: Dictionary = HitboxTimeline.resolve(
		_action_timer,
		_action_startup,
		_action_active,
		sizes,
		offsets,
		tables["fallback_size"],
		float(tables["fallback_offset"]),
		anim_frames
	)
	var offset_x: float = float(pose["offset_x"])
	_hitbox_base_x = offset_x
	hitbox.set_facing(_facing)
	hitbox.position.x = offset_x * _facing
	hitbox.position.y = -28.0
	_set_hitbox_size(pose["size"])
	if bool(pose["active"]):
		if not hitbox.is_active():
			hitbox.enable()
	elif hitbox.is_active():
		hitbox.disable()


func _update_run_bob(delta: float) -> void:
	## Juice procedural (posição/escala/rotação do sprite) — sem frame novo.
	## Cada estado tem sua assinatura: idle respira, run balança, jump se estica
	## levinho, dash estica na direção do movimento, ataque tem windup/active/
	## follow-through (mais forte no finalizador do combo), hurt recua, e um
	## squash de pouso se sobrepõe brevemente ao sair do ar.
	if sprite == null:
		return
	if _landing_squash_t > 0.0:
		_landing_squash_t = maxf(_landing_squash_t - delta, 0.0)
	var base_y: float = _sprite_base_y
	var s: float = _base_sprite_scale

	match _state:
		State.RUN:
			if is_on_floor():
				_run_bob_t += delta * 14.0
				# Bob sutil — frames multi já carregam o motion de corrida.
				sprite.position = Vector2(0.0, base_y + sin(_run_bob_t) * 2.0)
				sprite.scale = Vector2(s, s) * _landing_squash_mult()
				sprite.rotation = 0.0
			else:
				sprite.position = Vector2(0.0, base_y)
				sprite.scale = Vector2(s, s)
				sprite.rotation = 0.0
		State.JUMP:
			_run_bob_t = 0.0
			sprite.position = Vector2(0.0, base_y - 6.0)
			sprite.scale = Vector2(s * 0.96, s * 1.04)
			sprite.rotation = 0.0
		State.DASH:
			_run_bob_t = 0.0
			# Estica mais forte no arranque do dash, relaxa perto do fim (ease-out).
			var dash_ratio: float = 0.0
			if stats and stats.dash_duration > 0.0:
				dash_ratio = clampf(_dash_time_left / stats.dash_duration, 0.0, 1.0)
			sprite.position = Vector2(0.0, base_y)
			sprite.scale = Vector2(s * lerpf(1.0, 1.16, dash_ratio), s * lerpf(1.0, 0.86, dash_ratio))
			sprite.rotation = 0.0
		State.ATTACK_BASIC, State.SKILL_1, State.SKILL_2, State.ULTIMATE:
			_run_bob_t = 0.0
			_update_attack_juice(base_y, s)
		State.HURT:
			_run_bob_t = 0.0
			_update_hurt_juice(base_y, s)
		State.DEAD:
			_run_bob_t = 0.0
			sprite.position = Vector2(0.0, base_y)
			sprite.scale = Vector2(s, s)
			sprite.rotation = 0.0
		_:
			# IDLE: micro-motion de respiração — lenta e sutil, nunca no HURT/DEAD.
			_run_bob_t += delta * 1.6
			var breathe: float = sin(_run_bob_t)
			sprite.position = Vector2(0.0, base_y + breathe * 1.1)
			sprite.scale = Vector2(s * (1.0 - breathe * 0.006), s * (1.0 + breathe * 0.012)) \
				* _landing_squash_mult()
			sprite.rotation = 0.0


## Multiplicador do squash de pouso (procedural) — forte no touchdown, relaxa
## em LANDING_SQUASH_DUR. Só aplicado em estados de locomoção "quietos"
## (idle/run); ataque/dash/hurt/jump já têm sua própria assinatura de escala.
func _landing_squash_mult() -> Vector2:
	if _landing_squash_t <= 0.0 or LANDING_SQUASH_DUR <= 0.0:
		return Vector2.ONE
	var p: float = _landing_squash_t / LANDING_SQUASH_DUR
	var e: float = p * p
	return Vector2(lerpf(1.0, 1.16, e), lerpf(1.0, 0.82, e))


func _update_attack_juice(base_y: float, s: float) -> void:
	## Antecipação no windup, extensão no active (impacto), follow-through no
	## recovery. Finalizador (hit 3 do combo) usa um multiplicador maior (`punch`)
	## pra ler como o golpe mais forte da sequência.
	var startup: float = maxf(_action_startup, 0.0001)
	var active: float = maxf(_action_active, 0.0001)
	var recovery: float = maxf(_action_recovery, 0.0001)
	var t: float = _action_timer
	var is_finisher: bool = _state == State.ATTACK_BASIC and _combo_index == 3
	var punch: float = 1.4 if is_finisher else 1.0

	var stretch_x: float = 1.0
	var stretch_y: float = 1.0
	var offset_x: float = 0.0
	var rot_deg: float = 0.0

	if t < _action_startup:
		# Antecipação: recolhe contra a direção do golpe antes do swing.
		var p: float = clampf(t / startup, 0.0, 1.0)
		var e: float = sin(p * PI * 0.5)
		stretch_x = lerpf(1.0, 0.92, e)
		stretch_y = lerpf(1.0, 1.06, e)
		offset_x = -3.0 * e
		rot_deg = -4.0 * e * punch
	elif t < _action_startup + _action_active:
		# Active: estocada/extensão no momento em que a hitbox está ligada.
		var p2: float = clampf((t - _action_startup) / active, 0.0, 1.0)
		var e2: float = sin(p2 * PI * 0.5)
		stretch_x = lerpf(0.92, 1.0 + 0.14 * punch, e2)
		stretch_y = lerpf(1.06, 1.0 - 0.10 * punch, e2)
		offset_x = lerpf(-3.0, 5.0 * punch, e2)
		rot_deg = lerpf(-4.0, 6.0 * punch, e2)
	else:
		# Recovery: follow-through relaxando de volta ao neutro.
		var p3: float = clampf((t - _action_startup - _action_active) / recovery, 0.0, 1.0)
		var e3: float = 1.0 - p3
		stretch_x = lerpf(1.0, 1.0 + 0.14 * punch, e3)
		stretch_y = lerpf(1.0, 1.0 - 0.10 * punch, e3)
		offset_x = lerpf(0.0, 5.0 * punch, e3)
		rot_deg = lerpf(0.0, 6.0 * punch, e3)

	sprite.position = Vector2(offset_x * _facing, base_y)
	sprite.scale = Vector2(s * stretch_x, s * stretch_y)
	sprite.rotation = deg_to_rad(rot_deg * _facing)


func _update_hurt_juice(base_y: float, s: float) -> void:
	## Recoil/lean ao tomar hit: forte no impacto, relaxa ao longo do hurt_stun.
	var stun: float = stats.hurt_stun if stats else 0.22
	var p: float = clampf(1.0 - (_hurt_timer / maxf(stun, 0.0001)), 0.0, 1.0)
	var e: float = pow(1.0 - p, 2.0)
	var recoil_x: float = -10.0 * e
	var rot_deg: float = -8.0 * e
	sprite.position = Vector2(recoil_x * _facing, base_y + 2.0 * e)
	sprite.scale = Vector2(s * (1.0 + 0.05 * e), s * (1.0 - 0.08 * e))
	sprite.rotation = deg_to_rad(rot_deg * _facing)


func _apply_facing_visual() -> void:
	if sprite:
		# Assets de combate olham para a ESQUERDA; flip quando facing > 0 (direita).
		sprite.flip_h = _facing > 0.0
	if hitbox and not hitbox.is_active():
		hitbox.position.x = _hitbox_base_x * _facing
