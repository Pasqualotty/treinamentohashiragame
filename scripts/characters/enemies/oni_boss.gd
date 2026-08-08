extends CharacterBody2D
## Boss "Senhor da Névoa" — chefe demônio genérico de fan game (SEM nomes
## oficiais do anime/IP). Multi-fase por %HP: Fase 1 (100–60%) cautelosa,
## Fase 2 (60–25%) mais agressiva, Fase 3 "Fúria" (<25%) telegraphs mais
## rápidos + invocações mais frequentes.
##
## 3 ataques telegrafados:
##  - CHARGE (investida): dash rápido com hitbox ativa, atravessa o campo.
##  - SLAM (golpe em área): trava no lugar e dispara uma onda de choque nos
##    dois lados (hitboxes que se afastam do corpo durante a janela ativa).
##  - SUMMON (invocar): chama 1–2 `oni_weak` (cena existente, só referenciada
##    — NÃO editada) pra apoiar.
##
## Poise: hits não cancelam ataques em andamento (bosses não são
## interrompidos por pancada avulsa) — só a mudança de fase força um RECOVER
## de segurança, dando respiro justo ao jogador.
##
## Barra de vida própria no topo da tela (CanvasLayer) + banner de intro e
## banner de derrota. Group `enemy`; segue as convenções hp/_died/defeated
## usadas por oni_weak/oni_elite pra integrar com o WaveDirector sem editá-lo
## além do necessário para registrar esta cena.
## REGRA MOEDAS: só o coin_pickup credita (anti double-count).

signal defeated

enum State { INTRO, PATROL, CHASE, TELEGRAPH, CHARGE, SLAM, SUMMON, RECOVER, DEAD }
enum AttackKind { CHARGE, SLAM, SUMMON }
enum Phase { P1, P2, P3 }

const BOSS_NAME: String = "Senhor da Névoa"
const FLASH_COLOR: Color = Color(1.6, 0.4, 0.4, 1.0)
const FLASH_TIME: float = 0.1
const KNOCK_FRICTION: float = 820.0
const ONI_WEAK_SCENE: PackedScene = preload("res://scenes/characters/enemies/oni_weak.tscn")
const COIN_SCENE: PackedScene = preload("res://scenes/combat/coin_pickup.tscn")
## Duração do recoil visual procedural ao tomar hit — poise total de estado,
## mas ainda mostra um jolt discreto (o boss é pesado, então é mais sutil que
## nos onis comuns).
const HURT_RECOIL_DUR: float = 0.2

@export var max_hp: int = 300
## Valor da moeda spawnada no chão (creditada só no pickup).
@export var coin_reward: int = 80
@export var patrol_speed: float = 50.0
@export var chase_speed: float = 115.0
@export var detect_range: float = 520.0
@export var attack_range: float = 340.0
@export var patrol_half_width: float = 160.0

# Investida (CHARGE)
@export var charge_speed: float = 460.0
@export var charge_telegraph_time: float = 0.55
@export var charge_max_time: float = 0.65
@export var charge_damage: int = 14
@export var charge_knockback: Vector2 = Vector2(240.0, -70.0)

# Golpe em área / onda (SLAM)
@export var slam_telegraph_time: float = 0.6
@export var slam_active_time: float = 0.22
@export var slam_damage: int = 16
@export var slam_knockback: Vector2 = Vector2(200.0, -220.0)
@export var slam_wave_range: float = 210.0

# Invocação (SUMMON)
@export var summon_telegraph_time: float = 0.7
@export var summon_max_minions: int = 2
@export var summon_cooldown: float = 14.0

@export var attack_cooldown_base: float = 1.8
@export var recovery_time: float = 0.5

@onready var sprite: Sprite2D = %Sprite
@onready var hurtbox: Hurtbox = %Hurtbox
@onready var hitbox: Hitbox = %Hitbox
@onready var slam_hitbox_l: Hitbox = %SlamHitboxL
@onready var slam_hitbox_r: Hitbox = %SlamHitboxR
@onready var hp_label: Label = %HpLabel

var hp: int = 300
var state: State = State.INTRO
var phase: int = Phase.P1
var facing: float = -1.0
var _pending_attack: int = AttackKind.CHARGE
var _telegraph_base_color: Color = Color.WHITE
var _home_x: float = 0.0
var _patrol_dir: float = -1.0
var _flash_left: float = 0.0
var _base_modulate: Color = Color.WHITE
var _phase_timer: float = 0.0
var _cooldown_left: float = 0.0
var _summon_cd_left: float = 0.0
var _hitbox_base_x: float = 46.0
var _slam_base_offset: float = 30.0
var _gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity") as float
var _died: bool = false
var _minions: Array[Node] = []

# --- Animação procedural (transform absoluto por frame, sem frames novos) ---
var _sprite_base_pos: Vector2 = Vector2.ZERO
var _sprite_base_scale: Vector2 = Vector2.ONE
var _walk_t: float = 0.0
var _hurt_recoil_t: float = 0.0

var _hp_layer: CanvasLayer
var _hp_bar: ProgressBar
var _hp_name_label: Label
var _hp_text_label: Label

var _banner_layer: CanvasLayer
var _banner_bg: ColorRect
var _banner: Label
var _banner_tween: Tween


func _ready() -> void:
	add_to_group("enemy")
	hp = max_hp
	_home_x = global_position.x
	if sprite:
		_base_modulate = sprite.modulate
		# Arte base olha pra esquerda: flip_h da cena = "olhando pra direita".
		facing = 1.0 if sprite.flip_h else -1.0
		_patrol_dir = facing
		_sprite_base_pos = sprite.position
		_sprite_base_scale = sprite.scale
	if hurtbox:
		hurtbox.team = &"enemy"
		if not hurtbox.hurt.is_connected(_on_hurt):
			hurtbox.hurt.connect(_on_hurt)
	if hitbox:
		hitbox.team = &"enemy"
		hitbox.disable()
		_hitbox_base_x = absf(hitbox.position.x)
		if is_zero_approx(_hitbox_base_x):
			_hitbox_base_x = 46.0
	if slam_hitbox_l:
		slam_hitbox_l.team = &"enemy"
		slam_hitbox_l.disable()
		_slam_base_offset = absf(slam_hitbox_l.position.x)
		if is_zero_approx(_slam_base_offset):
			_slam_base_offset = 30.0
	if slam_hitbox_r:
		slam_hitbox_r.team = &"enemy"
		slam_hitbox_r.disable()
	_apply_facing()
	_build_boss_ui()
	_refresh_hp_bar()
	if is_instance_valid(Audio):
		Audio.play_bgm("boss")
	_play_intro()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += _gravity * delta

	if _cooldown_left > 0.0:
		_cooldown_left = maxf(0.0, _cooldown_left - delta)
	if _summon_cd_left > 0.0:
		_summon_cd_left = maxf(0.0, _summon_cd_left - delta)

	if state == State.DEAD or state == State.INTRO:
		velocity.x = move_toward(velocity.x, 0.0, KNOCK_FRICTION * delta)
		move_and_slide()
		_tick_flash(delta)
		return

	match state:
		State.PATROL:
			_ai_patrol(delta)
		State.CHASE:
			_ai_chase(delta)
		State.TELEGRAPH:
			_ai_telegraph(delta)
		State.CHARGE:
			_ai_charge(delta)
		State.SLAM:
			_ai_slam(delta)
		State.SUMMON:
			_ai_summon(delta)
		State.RECOVER:
			_ai_recover(delta)

	_update_anim(delta)
	move_and_slide()
	if state == State.CHARGE and is_on_wall():
		_end_charge()
	_tick_flash(delta)


# --- Movimento base (PATROL / CHASE) ---

func _ai_patrol(delta: float) -> void:
	var player: Node2D = _find_player()
	if player and _dist_to(player) <= detect_range:
		state = State.CHASE
		return
	var left_bound: float = _home_x - patrol_half_width
	var right_bound: float = _home_x + patrol_half_width
	if global_position.x <= left_bound:
		_patrol_dir = 1.0
	elif global_position.x >= right_bound:
		_patrol_dir = -1.0
	facing = _patrol_dir
	_apply_facing()
	if is_on_floor():
		velocity.x = _patrol_dir * patrol_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, KNOCK_FRICTION * delta)


func _ai_chase(delta: float) -> void:
	var player: Node2D = _find_player()
	if player == null:
		velocity.x = move_toward(velocity.x, 0.0, KNOCK_FRICTION * delta)
		return
	var dx: float = player.global_position.x - global_position.x
	if not is_zero_approx(dx):
		facing = signf(dx)
		_apply_facing()
	var dist: float = absf(dx)
	if dist <= attack_range and _cooldown_left <= 0.0 and is_on_floor():
		_begin_attack_cycle()
		return
	if is_on_floor():
		velocity.x = facing * chase_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, KNOCK_FRICTION * delta)


# --- Escolha de ataque ---

func _begin_attack_cycle() -> void:
	var kind: int = _choose_attack()
	_pending_attack = kind
	state = State.TELEGRAPH
	_phase_timer = 0.0
	velocity.x = 0.0
	match kind:
		AttackKind.CHARGE:
			_telegraph_base_color = Color(1.55, 0.8, 0.4, 1.0)
		AttackKind.SLAM:
			_telegraph_base_color = Color(1.6, 0.35, 0.35, 1.0)
		AttackKind.SUMMON:
			_telegraph_base_color = Color(0.9, 0.55, 1.6, 1.0)
		_:
			_telegraph_base_color = _base_modulate


func _choose_attack() -> int:
	var w_charge: float = 1.0
	var w_slam: float = 1.0
	var w_summon: float = 0.0
	match phase:
		Phase.P1:
			w_summon = 0.0
		Phase.P2:
			w_summon = 0.7
		Phase.P3:
			w_summon = 0.9
			w_charge = 1.25
	if _summon_cd_left > 0.0 or _alive_minion_count() >= summon_max_minions:
		w_summon = 0.0
	var total: float = w_charge + w_slam + w_summon
	if total <= 0.0:
		return AttackKind.CHARGE
	var roll: float = randf() * total
	if roll < w_charge:
		return AttackKind.CHARGE
	roll -= w_charge
	if roll < w_slam:
		return AttackKind.SLAM
	return AttackKind.SUMMON


func _telegraph_duration_for(kind: int) -> float:
	var base: float = charge_telegraph_time
	match kind:
		AttackKind.SLAM:
			base = slam_telegraph_time
		AttackKind.SUMMON:
			base = summon_telegraph_time
	return base * _phase_speed_mult()


func _phase_speed_mult() -> float:
	match phase:
		Phase.P2:
			return 0.88
		Phase.P3:
			return 0.72
		_:
			return 1.0


func _phase_cooldown_mult() -> float:
	match phase:
		Phase.P2:
			return 0.8
		Phase.P3:
			return 0.6
		_:
			return 1.0


func _ai_telegraph(delta: float) -> void:
	velocity.x = 0.0
	_phase_timer += delta
	if sprite:
		var pulse: float = 0.82 + 0.28 * absf(sin(_phase_timer * 26.0))
		var c: Color = _telegraph_base_color * pulse
		c.a = 1.0
		sprite.modulate = c
	if _phase_timer >= _telegraph_duration_for(_pending_attack):
		match _pending_attack:
			AttackKind.CHARGE:
				_start_charge()
			AttackKind.SLAM:
				_start_slam()
			AttackKind.SUMMON:
				_start_summon()


# --- CHARGE (investida) ---

func _start_charge() -> void:
	state = State.CHARGE
	_phase_timer = 0.0
	if sprite:
		sprite.modulate = Color(1.7, 1.5, 1.2, 1.0)
	if hitbox:
		hitbox.damage = charge_damage
		hitbox.knockback = charge_knockback
		hitbox.set_facing(facing)
		hitbox.position.x = _hitbox_base_x * facing
		hitbox.enable()


func _ai_charge(delta: float) -> void:
	var mult: float = 1.15 if phase == Phase.P3 else 1.0
	velocity.x = facing * charge_speed * mult
	_phase_timer += delta
	if _phase_timer >= charge_max_time:
		_end_charge()


func _end_charge() -> void:
	if hitbox:
		hitbox.disable()
	if sprite:
		sprite.modulate = _base_modulate
	_start_recover()


# --- SLAM (golpe em área / onda) ---

func _start_slam() -> void:
	state = State.SLAM
	_phase_timer = 0.0
	velocity.x = 0.0
	if sprite:
		sprite.modulate = Color(1.75, 0.5, 0.45, 1.0)
	if is_instance_valid(CombatFeel):
		CombatFeel.shake(6.5, 0.18)
	if is_instance_valid(Audio):
		Audio.play_sfx("hit", 0.85, 1.15)
	_fire_slam_wave()


func _fire_slam_wave() -> void:
	if slam_hitbox_l:
		slam_hitbox_l.damage = slam_damage
		slam_hitbox_l.knockback = Vector2(-absf(slam_knockback.x), slam_knockback.y)
		slam_hitbox_l.position.x = -_slam_base_offset
		slam_hitbox_l.enable()
		_tween_slam(slam_hitbox_l, -1.0)
	if slam_hitbox_r:
		slam_hitbox_r.damage = slam_damage
		slam_hitbox_r.knockback = Vector2(absf(slam_knockback.x), slam_knockback.y)
		slam_hitbox_r.position.x = _slam_base_offset
		slam_hitbox_r.enable()
		_tween_slam(slam_hitbox_r, 1.0)


func _tween_slam(hb: Hitbox, dir: float) -> void:
	var target_x: float = dir * slam_wave_range
	var tw: Tween = create_tween()
	tw.tween_property(hb, "position:x", target_x, slam_active_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _ai_slam(delta: float) -> void:
	velocity.x = 0.0
	_phase_timer += delta
	if _phase_timer >= slam_active_time:
		_end_slam()


func _end_slam() -> void:
	if slam_hitbox_l:
		slam_hitbox_l.disable()
		slam_hitbox_l.position.x = -_slam_base_offset
	if slam_hitbox_r:
		slam_hitbox_r.disable()
		slam_hitbox_r.position.x = _slam_base_offset
	if sprite:
		sprite.modulate = _base_modulate
	_start_recover()


# --- SUMMON (invocar onis fracos) ---

func _start_summon() -> void:
	state = State.SUMMON
	_phase_timer = 0.0
	velocity.x = 0.0
	if sprite:
		sprite.modulate = Color(1.1, 0.75, 1.75, 1.0)
	var count: int = 2 if phase == Phase.P3 else 1
	count = mini(count, summon_max_minions - _alive_minion_count())
	count = maxi(count, 0)
	for i in count:
		_spawn_minion(i)
	_summon_cd_left = summon_cooldown


func _spawn_minion(i: int) -> void:
	var parent_node: Node = get_parent()
	if parent_node == null:
		parent_node = get_tree().current_scene if get_tree() else null
	if parent_node == null:
		return
	var m: Node = ONI_WEAK_SCENE.instantiate()
	parent_node.add_child(m)
	if m is Node2D:
		var off_x: float = -70.0 if i == 0 else 70.0
		(m as Node2D).global_position = global_position + Vector2(off_x, 0.0)
	if m.has_signal("defeated"):
		m.connect("defeated", _on_minion_defeated.bind(m), CONNECT_ONE_SHOT)
	_minions.append(m)


func _on_minion_defeated(m: Node) -> void:
	_minions.erase(m)


func _ai_summon(delta: float) -> void:
	velocity.x = 0.0
	_phase_timer += delta
	if _phase_timer >= 0.4:
		if sprite:
			sprite.modulate = _base_modulate
		_start_recover()


func _alive_minion_count() -> int:
	var n: int = 0
	for m: Node in _minions:
		if is_instance_valid(m):
			n += 1
	return n


# --- RECOVER (comum a todos os ataques) ---

func _start_recover() -> void:
	state = State.RECOVER
	_phase_timer = 0.0


func _ai_recover(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, KNOCK_FRICTION * delta)
	_phase_timer += delta
	var dur: float = recovery_time * (0.75 if phase == Phase.P3 else 1.0)
	if _phase_timer >= dur:
		_cooldown_left = attack_cooldown_base * _phase_cooldown_mult()
		state = State.CHASE


# --- Animação procedural (transform absoluto por frame, sem frames novos) ---

func _phase_weight_mult() -> float:
	## Motion fica mais pesado/ameaçador conforme a fase avança (amplitude +
	## frequência maiores em P2/P3) — reforça a escalada sem tocar na state
	## machine de fases.
	match phase:
		Phase.P2:
			return 1.15
		Phase.P3:
			return 1.3
		_:
			return 1.0


func _update_anim(delta: float) -> void:
	## Motion procedural do boss: telegraph com silhueta distinta por
	## AttackKind (CHARGE recolhe pra trás, SLAM agacha/comprime, SUMMON
	## pulsa/levita), stomp de impacto no SLAM, stretch no CHARGE, gesto no
	## SUMMON, e settle com wobble no RECOVER. Absoluto por frame (sem
	## drift); volta pra _sprite_base_pos/_sprite_base_scale ao sair do
	## estado. INTRO/DEAD não passam por aqui (early-return no
	## _physics_process) — quem cuida deles é o banner/tween de morte.
	if sprite == null:
		return
	if _hurt_recoil_t > 0.0:
		_hurt_recoil_t = maxf(_hurt_recoil_t - delta, 0.0)

	var pos: Vector2 = _sprite_base_pos
	var scl: Vector2 = _sprite_base_scale
	var rot: float = 0.0
	var weight: float = _phase_weight_mult()

	match state:
		State.PATROL, State.CHASE:
			var chasing: bool = state == State.CHASE
			var moving: bool = is_on_floor() and not is_zero_approx(velocity.x)
			var move_dir: float = signf(velocity.x) if moving else facing
			if moving:
				_walk_t += delta * (7.0 if chasing else 4.6) * weight
			var amp: float = (5.2 if chasing else 3.4) * weight
			var bob: float = sin(_walk_t) * amp if moving else 0.0
			pos = _sprite_base_pos + Vector2(0.0, bob)
			scl = _sprite_base_scale * Vector2(1.0 - absf(bob) * 0.010, 1.0 + absf(bob) * 0.012)
			rot = deg_to_rad((5.0 if chasing else 2.5) * move_dir * weight) if moving else 0.0
		State.TELEGRAPH:
			_walk_t = 0.0
			var dur: float = maxf(_telegraph_duration_for(_pending_attack), 0.0001)
			var p: float = clampf(_phase_timer / dur, 0.0, 1.0)
			match _pending_attack:
				AttackKind.CHARGE:
					var wind: float = sin(p * PI * 0.5)
					var tremor: float = sin(_phase_timer * 44.0) * 0.8 * p * weight
					pos = _sprite_base_pos + Vector2(-9.0 * wind * facing + tremor, 3.0 * wind)
					scl = _sprite_base_scale * Vector2(1.0 - 0.12 * wind, 1.0 + 0.10 * wind)
					rot = deg_to_rad((-8.0 * wind + tremor) * facing)
				AttackKind.SLAM:
					var crouch: float = sin(p * PI * 0.5)
					var tremor2: float = sin(_phase_timer * 50.0) * 0.9 * p * weight
					pos = _sprite_base_pos + Vector2(tremor2, 5.0 * crouch)
					scl = _sprite_base_scale * Vector2(1.0 + 0.16 * crouch, 1.0 - 0.20 * crouch)
					rot = deg_to_rad(tremor2 * 1.5)
				AttackKind.SUMMON:
					var pulse: float = sin(p * TAU * 1.6) * p
					pos = _sprite_base_pos + Vector2(0.0, -4.0 * p - pulse * 1.5)
					scl = _sprite_base_scale * Vector2(1.0 + 0.05 * p + 0.03 * pulse, 1.0 + 0.08 * p + 0.03 * pulse)
					rot = deg_to_rad(pulse * 4.0)
		State.CHARGE:
			# Stretch forte na direção do dash.
			_walk_t = 0.0
			var q: float = clampf(_phase_timer / maxf(charge_max_time, 0.0001), 0.0, 1.0)
			var burst: float = sin(q * PI)
			pos = _sprite_base_pos + Vector2(5.0 * facing, 2.5 * burst)
			scl = _sprite_base_scale * Vector2(1.30 + 0.10 * burst, 0.80 - 0.06 * burst)
			rot = deg_to_rad(4.0 * facing)
		State.SLAM:
			# Stomp: compressão forte no impacto, expande e relaxa até o fim
			# da janela ativa (sincroniza com o shake de CombatFeel).
			_walk_t = 0.0
			var q2: float = clampf(_phase_timer / maxf(slam_active_time, 0.0001), 0.0, 1.0)
			var slam_e: float = 1.0 - q2
			var impact: float = exp(-q2 * 9.0)
			pos = _sprite_base_pos + Vector2(0.0, 6.0 * impact)
			scl = _sprite_base_scale * Vector2(1.0 + 0.30 * impact - 0.05 * slam_e, 1.0 - 0.32 * impact + 0.05 * slam_e)
		State.SUMMON:
			# Gesto de invocação: pulsa/levita levemente (espelha o threshold
			# de 0.4s usado em _ai_summon).
			_walk_t = 0.0
			var pulse2: float = sin(_phase_timer * 16.0)
			pos = _sprite_base_pos + Vector2(0.0, -3.0 - pulse2 * 1.2)
			scl = _sprite_base_scale * Vector2(1.05 + 0.03 * pulse2, 1.08 + 0.03 * pulse2)
			rot = deg_to_rad(pulse2 * 3.0)
		State.RECOVER:
			_walk_t = 0.0
			var dur2: float = maxf(recovery_time * (0.75 if phase == Phase.P3 else 1.0), 0.0001)
			var q3: float = clampf(_phase_timer / dur2, 0.0, 1.0)
			var wobble: float = sin(q3 * PI * 3.0) * (1.0 - q3)
			pos = _sprite_base_pos + Vector2(wobble * 3.5 * facing, absf(wobble) * 1.8)
			scl = _sprite_base_scale * Vector2(1.0 - wobble * 0.05, 1.0 + wobble * 0.05)
			rot = deg_to_rad(wobble * 5.0 * facing)
		_:
			_walk_t = 0.0

	if _hurt_recoil_t > 0.0:
		var e3: float = _hurt_recoil_t / HURT_RECOIL_DUR
		pos += Vector2(-5.0 * e3 * facing, -1.2 * e3)
		rot += deg_to_rad(-5.0 * e3 * facing)
		scl *= Vector2(1.0 + 0.03 * e3, 1.0 - 0.045 * e3)

	sprite.position = pos
	sprite.scale = scl
	sprite.rotation = rot


# --- Dano / fases ---

func _on_hurt(hit_data: HitData) -> void:
	if _died or hp <= 0:
		return
	hp = maxi(0, hp - hit_data.damage)
	# Boss tem peso — recebe uma fração do knockback normal.
	velocity.x = hit_data.knockback.x * 0.45
	velocity.y = hit_data.knockback.y * 0.45
	_start_flash()
	_hurt_recoil_t = HURT_RECOIL_DUR
	_refresh_hp_bar()
	print("[OniBoss] hurt dmg=%d hp=%d/%d phase=%s" % [hit_data.damage, hp, max_hp, Phase.keys()[phase]])
	# Poise total: hit não cancela telegraph/ataque em andamento. Só a
	# transição de fase (abaixo) força um respiro seguro.
	_check_phase_transition()
	if hp <= 0:
		_on_defeated()


func _check_phase_transition() -> void:
	var pct: float = float(hp) / float(max_hp)
	var new_phase: int = Phase.P1
	if pct <= 0.25:
		new_phase = Phase.P3
	elif pct <= 0.6:
		new_phase = Phase.P2
	if new_phase == phase or new_phase < phase:
		return
	phase = new_phase
	_enter_phase(phase)


func _enter_phase(new_phase: int) -> void:
	var title: String
	var color: Color
	if new_phase == Phase.P2:
		title = "%s ENTRA EM FÚRIA!" % BOSS_NAME.to_upper()
		color = Color(1.0, 0.55, 0.25, 1.0)
	else:
		title = "FASE FINAL — %s DESESPERADO!" % BOSS_NAME.to_upper()
		color = Color(1.0, 0.25, 0.35, 1.0)
	_show_banner_async(title, color, 1.3)
	if is_instance_valid(CombatFeel):
		CombatFeel.shake(7.5, 0.24)
	if is_instance_valid(Audio):
		Audio.play_sfx("hit", 0.7, 1.3)
	if state != State.DEAD and state != State.INTRO:
		if hitbox:
			hitbox.disable()
		if slam_hitbox_l:
			slam_hitbox_l.disable()
		if slam_hitbox_r:
			slam_hitbox_r.disable()
		if sprite:
			sprite.modulate = _base_modulate
		_start_recover()


func _on_defeated() -> void:
	if _died:
		return
	_died = true
	state = State.DEAD
	if hitbox:
		hitbox.disable()
	if slam_hitbox_l:
		slam_hitbox_l.disable()
	if slam_hitbox_r:
		slam_hitbox_r.disable()
	if hurtbox:
		hurtbox.invulnerable = true
	for m: Node in _minions:
		if is_instance_valid(m):
			m.queue_free()
	_minions.clear()
	if hp_label:
		hp_label.text = "HP 0/%d — KO" % max_hp
	_spawn_coin_drop()
	defeated.emit()
	print("[OniBoss] defeated hp=0/%d" % max_hp)
	if is_instance_valid(CombatFeel):
		CombatFeel.shake(9.0, 0.5)
	_show_banner_async("%s DERROTADO!" % BOSS_NAME.to_upper(), Color(1.0, 0.82, 0.35, 1.0), 1.3)
	_fade_hp_bar()
	var tree: SceneTree = get_tree()
	if tree:
		await tree.create_timer(0.85).timeout
	if sprite and is_instance_valid(sprite):
		var tw: Tween = create_tween()
		tw.set_parallel(true)
		tw.tween_property(sprite, "modulate:a", 0.0, 0.55)
		tw.tween_property(self, "scale", Vector2(0.85, 0.85), 0.55)
		# Tombo/squash procedural do sprite — gigante desmoronando.
		var fall_dir: float = facing if not is_zero_approx(facing) else 1.0
		tw.tween_property(sprite, "rotation", deg_to_rad(58.0 * fall_dir), 0.55) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(sprite, "scale", _sprite_base_scale * Vector2(1.18, 0.72), 0.55) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		await tw.finished
	if tree:
		await tree.create_timer(0.15).timeout
	if is_instance_valid(self):
		queue_free()


func _spawn_coin_drop() -> void:
	## Não credita moedas aqui — só spawna pickup (anti double-count).
	var parent_node: Node = get_parent()
	if parent_node == null:
		parent_node = get_tree().current_scene if get_tree() else null
	if parent_node == null:
		push_error("[OniBoss] sem parent pra drop de moeda")
		return
	var coin: Node = COIN_SCENE.instantiate()
	if coin == null:
		push_error("[OniBoss] falha ao instanciar coin_pickup")
		return
	parent_node.add_child(coin)
	if coin is Node2D:
		(coin as Node2D).global_position = global_position + Vector2(facing * 12.0, -44.0)
		(coin as Node2D).z_index = 25
	if coin.has_method("setup"):
		coin.call("setup", coin_reward)
	elif "value" in coin:
		coin.set("value", coin_reward)


# --- Intro / banner / HP bar ---

func _play_intro() -> void:
	state = State.INTRO
	velocity = Vector2.ZERO
	await _show_banner("— %s —" % BOSS_NAME.to_upper(), Color(1.0, 0.6, 0.95, 1.0), 1.6)
	if is_instance_valid(self) and state == State.INTRO:
		state = State.PATROL


func _build_boss_ui() -> void:
	_hp_layer = CanvasLayer.new()
	_hp_layer.name = "BossHpLayer"
	_hp_layer.layer = 58
	add_child(_hp_layer)

	var bg := ColorRect.new()
	bg.name = "BossHpBg"
	bg.anchor_left = 0.5
	bg.anchor_right = 0.5
	bg.offset_left = -230.0
	bg.offset_right = 230.0
	bg.offset_top = 16.0
	bg.offset_bottom = 66.0
	bg.color = Color(0.05, 0.04, 0.09, 0.78)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_layer.add_child(bg)

	_hp_name_label = Label.new()
	_hp_name_label.name = "BossNameLabel"
	_hp_name_label.anchor_left = 0.5
	_hp_name_label.anchor_right = 0.5
	_hp_name_label.offset_left = -230.0
	_hp_name_label.offset_right = 230.0
	_hp_name_label.offset_top = 18.0
	_hp_name_label.offset_bottom = 38.0
	_hp_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_name_label.text = BOSS_NAME
	_hp_name_label.add_theme_font_size_override("font_size", 16)
	_hp_name_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6, 1.0))
	_hp_name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_hp_name_label.add_theme_constant_override("shadow_offset_x", 1)
	_hp_name_label.add_theme_constant_override("shadow_offset_y", 1)
	_hp_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_layer.add_child(_hp_name_label)

	_hp_bar = ProgressBar.new()
	_hp_bar.name = "BossHpBar"
	_hp_bar.anchor_left = 0.5
	_hp_bar.anchor_right = 0.5
	_hp_bar.offset_left = -214.0
	_hp_bar.offset_right = 214.0
	_hp_bar.offset_top = 40.0
	_hp_bar.offset_bottom = 60.0
	_hp_bar.show_percentage = false
	_hp_bar.max_value = float(max_hp)
	_hp_bar.value = float(hp)
	_hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg_box := StyleBoxFlat.new()
	bg_box.bg_color = Color(0.1, 0.05, 0.07, 0.95)
	bg_box.border_color = Color(0.55, 0.45, 0.2, 0.7)
	bg_box.set_border_width_all(1)
	bg_box.set_corner_radius_all(6)
	var fill_box := StyleBoxFlat.new()
	fill_box.bg_color = Color(0.77, 0.24, 0.24, 1.0)
	fill_box.set_corner_radius_all(5)
	_hp_bar.add_theme_stylebox_override("background", bg_box)
	_hp_bar.add_theme_stylebox_override("fill", fill_box)
	_hp_layer.add_child(_hp_bar)

	_hp_text_label = Label.new()
	_hp_text_label.name = "BossHpText"
	_hp_text_label.anchor_left = 0.5
	_hp_text_label.anchor_right = 0.5
	_hp_text_label.offset_left = -214.0
	_hp_text_label.offset_right = 214.0
	_hp_text_label.offset_top = 40.0
	_hp_text_label.offset_bottom = 60.0
	_hp_text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hp_text_label.add_theme_font_size_override("font_size", 13)
	_hp_text_label.add_theme_color_override("font_color", Color(1, 0.95, 0.9, 1))
	_hp_text_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_hp_text_label.add_theme_constant_override("shadow_offset_x", 1)
	_hp_text_label.add_theme_constant_override("shadow_offset_y", 1)
	_hp_text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_layer.add_child(_hp_text_label)

	_ensure_banner_ui()


func _refresh_hp_bar() -> void:
	if _hp_bar:
		_hp_bar.max_value = float(max_hp)
		_hp_bar.value = float(hp)
	if _hp_text_label:
		_hp_text_label.text = "%d / %d" % [hp, max_hp]
	if hp_label:
		hp_label.text = "HP %d/%d" % [hp, max_hp]


func _fade_hp_bar() -> void:
	if _hp_layer == null:
		return
	var tw: Tween = create_tween()
	tw.tween_interval(0.4)
	tw.set_parallel(true)
	for child: Node in _hp_layer.get_children():
		if child is CanvasItem:
			tw.tween_property(child, "modulate:a", 0.0, 0.5)


func _ensure_banner_ui() -> void:
	_banner_layer = CanvasLayer.new()
	_banner_layer.name = "BossBannerLayer"
	_banner_layer.layer = 59
	add_child(_banner_layer)

	_banner_bg = ColorRect.new()
	_banner_bg.name = "BossBannerBg"
	_banner_bg.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_banner_bg.offset_top = 300.0
	_banner_bg.offset_bottom = 372.0
	_banner_bg.color = Color(0.02, 0.03, 0.07, 0.0)
	_banner_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_layer.add_child(_banner_bg)

	_banner = Label.new()
	_banner.name = "BossBannerLabel"
	_banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_banner.offset_top = 304.0
	_banner.offset_bottom = 368.0
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 34)
	_banner.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	_banner.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	_banner.add_theme_constant_override("shadow_offset_x", 2)
	_banner.add_theme_constant_override("shadow_offset_y", 2)
	_banner.add_theme_constant_override("outline_size", 4)
	_banner.modulate.a = 0.0
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_layer.add_child(_banner)


func _show_banner(text: String, color: Color, hold: float = 1.2) -> void:
	if _banner == null or not is_inside_tree():
		return
	if _banner_tween != null and is_instance_valid(_banner_tween):
		_banner_tween.kill()
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	_banner.modulate = Color(1, 1, 1, 0)
	_banner.scale = Vector2(0.7, 0.7)
	_banner.pivot_offset = Vector2(_banner.size.x * 0.5, _banner.size.y * 0.5)
	if _banner_bg:
		_banner_bg.color = Color(0.02, 0.03, 0.07, 0.0)

	_banner_tween = create_tween()
	_banner_tween.set_parallel(true)
	_banner_tween.tween_property(_banner, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_banner_tween.tween_property(_banner, "scale", Vector2(1.06, 1.06), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if _banner_bg:
		_banner_tween.tween_property(_banner_bg, "color:a", 0.5, 0.2)
	_banner_tween.set_parallel(false)
	_banner_tween.tween_property(_banner, "scale", Vector2.ONE, 0.12)
	_banner_tween.tween_interval(maxf(0.15, hold - 0.5))
	_banner_tween.set_parallel(true)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if _banner_bg:
		_banner_tween.tween_property(_banner_bg, "color:a", 0.0, 0.3)
	await _banner_tween.finished


func _show_banner_async(text: String, color: Color, hold: float = 1.2) -> void:
	# Não espera — usado em transições que não podem travar o state machine.
	_show_banner(text, color, hold)


# --- Utilidades comuns ---

func _find_player() -> Node2D:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	var nodes: Array[Node] = tree.get_nodes_in_group("player")
	if nodes.is_empty():
		return null
	var n: Node = nodes[0]
	if n is Node2D:
		return n as Node2D
	return null


func _dist_to(target: Node2D) -> float:
	return global_position.distance_to(target.global_position)


func _apply_facing() -> void:
	## `oni_weak_side.png` SEM flip já olha pra ESQUERDA:
	##   facing = -1 (esquerda) -> flip_h = false
	##   facing = +1 (direita)  -> flip_h = true
	## A dedução inicial em `_ready()` é o inverso exato disto.
	if sprite:
		sprite.flip_h = facing > 0.0
	if hitbox:
		hitbox.position.x = _hitbox_base_x * facing


func _start_flash() -> void:
	_flash_left = FLASH_TIME
	if sprite and state != State.TELEGRAPH:
		sprite.modulate = FLASH_COLOR


func _tick_flash(delta: float) -> void:
	if _flash_left <= 0.0:
		return
	_flash_left -= delta
	if _flash_left <= 0.0 and sprite and state != State.TELEGRAPH and state != State.DEAD:
		sprite.modulate = _base_modulate
