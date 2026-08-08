extends CharacterBody2D
## Oni à distância (conteúdo NOVO): mantém distância preferida do player e
## atira `oni_projectile` com telegraph claro. Copiado/adaptado do padrão de
## `oni_weak.gd` (state machine + convenções hp/_died/defeated) — NÃO edita
## oni_weak.gd/.tscn.
## Group `enemy`. Hurtbox recebe hits do player.
## REGRA MOEDAS: ao morrer spawna coin_pickup; NÃO chama add_run_coins na kill
## (só o pickup credita — ver coin_pickup.gd).

signal defeated

enum State { PATROL, CHASE, TELEGRAPH, RECOVER, DEAD }

const FLASH_COLOR: Color = Color(1.45, 0.55, 0.75, 1.0)
const FLASH_TIME: float = 0.1
const KNOCK_FRICTION: float = 860.0
const COIN_SCENE: PackedScene = preload("res://scenes/combat/coin_pickup.tscn")
const PROJECTILE_SCENE: PackedScene = preload("res://scenes/characters/enemies/oni_projectile.tscn")
## Duração do recoil visual procedural ao tomar hit (overlay).
const HURT_RECOIL_DUR: float = 0.2
## Duração do "coice" visual no instante do disparo (overlay em RECOVER).
const FIRE_KICK_DUR: float = 0.22

@export var max_hp: int = 22
## Valor da moeda spawnada no chão (creditada só no pickup).
@export var coin_reward: int = 12
@export var patrol_speed: float = 48.0
@export var chase_speed: float = 92.0
@export var detect_range: float = 320.0
## Distância que o oni tenta manter do player pra atirar.
@export var preferred_range: float = 250.0
## Abaixo disso, o oni recua em vez de atirar.
@export var min_range: float = 150.0
@export var telegraph_time: float = 0.5
@export var attack_recovery: float = 0.5
@export var attack_cooldown: float = 1.5
@export var patrol_half_width: float = 90.0
@export var projectile_damage: int = 6
@export var projectile_speed: float = 360.0
@export var projectile_knockback: Vector2 = Vector2(115.0, -30.0)

@onready var sprite: Sprite2D = %Sprite
@onready var hurtbox: Hurtbox = %Hurtbox
@onready var hp_label: Label = %HpLabel

var hp: int = 22
var state: State = State.PATROL
var facing: float = -1.0
var _home_x: float = 0.0
var _patrol_dir: float = -1.0
var _flash_left: float = 0.0
var _base_modulate: Color = Color.WHITE
var _phase_timer: float = 0.0
var _cooldown_left: float = 0.0
var _gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity") as float
var _died: bool = false

# --- Animação procedural (transform absoluto por frame, sem frames novos) ---
var _sprite_base_pos: Vector2 = Vector2.ZERO
var _sprite_base_scale: Vector2 = Vector2.ONE
var _walk_t: float = 0.0
var _hurt_recoil_t: float = 0.0
var _fire_kick_t: float = 0.0


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
	_apply_facing()
	_refresh_label()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += _gravity * delta

	if _cooldown_left > 0.0:
		_cooldown_left = maxf(0.0, _cooldown_left - delta)

	if state == State.DEAD:
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
		State.RECOVER:
			_ai_recover(delta)

	_update_anim(delta)
	move_and_slide()
	_tick_flash(delta)


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
	if player == null or _dist_to(player) > detect_range * 1.5:
		state = State.PATROL
		return

	var dx: float = player.global_position.x - global_position.x
	var dist: float = absf(dx)
	if not is_zero_approx(dx):
		facing = signf(dx)
		_apply_facing()

	if dist < min_range:
		# Fica perto demais — recua pra manter distância de tiro.
		if is_on_floor():
			velocity.x = -facing * chase_speed
		else:
			velocity.x = move_toward(velocity.x, 0.0, KNOCK_FRICTION * delta)
		return

	if dist > preferred_range + 40.0:
		if is_on_floor():
			velocity.x = facing * chase_speed
		else:
			velocity.x = move_toward(velocity.x, 0.0, KNOCK_FRICTION * delta)
		return

	# Na banda de disparo: para e atira quando o cooldown permitir.
	velocity.x = move_toward(velocity.x, 0.0, KNOCK_FRICTION * delta)
	if _cooldown_left <= 0.0 and is_on_floor():
		_start_telegraph()


func _start_telegraph() -> void:
	state = State.TELEGRAPH
	_phase_timer = 0.0
	velocity.x = 0.0
	if sprite:
		sprite.modulate = Color(0.55, 0.85, 1.55, 1.0)


func _ai_telegraph(delta: float) -> void:
	velocity.x = 0.0
	_phase_timer += delta
	if sprite:
		var pulse: float = 0.85 + 0.2 * absf(sin(_phase_timer * 22.0))
		sprite.modulate = Color(0.55 * pulse, 0.85 * pulse, 1.55 * pulse, 1.0)
	if _phase_timer >= telegraph_time:
		_fire_and_recover()


func _fire_and_recover() -> void:
	if sprite:
		sprite.modulate = _base_modulate
	_fire_projectile()
	_fire_kick_t = FIRE_KICK_DUR
	state = State.RECOVER
	_phase_timer = 0.0


func _ai_recover(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, KNOCK_FRICTION * delta)
	_phase_timer += delta
	if _phase_timer >= attack_recovery:
		_cooldown_left = attack_cooldown
		state = State.CHASE


func _update_anim(delta: float) -> void:
	## Motion procedural: pose de mira (recua/estica levemente ao carregar o
	## tiro) no telegraph + "coice" de disparo no início do RECOVER. Absoluto
	## por frame (sem drift); volta pra _sprite_base_pos/_sprite_base_scale
	## fora desses estados.
	if sprite == null:
		return
	if _hurt_recoil_t > 0.0:
		_hurt_recoil_t = maxf(_hurt_recoil_t - delta, 0.0)
	if _fire_kick_t > 0.0:
		_fire_kick_t = maxf(_fire_kick_t - delta, 0.0)

	var pos: Vector2 = _sprite_base_pos
	var scl: Vector2 = _sprite_base_scale
	var rot: float = 0.0

	match state:
		State.PATROL, State.CHASE:
			var chasing: bool = state == State.CHASE
			var moving: bool = is_on_floor() and not is_zero_approx(velocity.x)
			var move_dir: float = signf(velocity.x) if moving else facing
			if moving:
				_walk_t += delta * (12.5 if chasing else 8.0)
			var amp: float = 2.6 if chasing else 1.8
			var bob: float = sin(_walk_t) * amp if moving else 0.0
			pos = _sprite_base_pos + Vector2(0.0, bob)
			scl = _sprite_base_scale * Vector2(1.0 - absf(bob) * 0.010, 1.0 + absf(bob) * 0.012)
			rot = deg_to_rad((4.0 if chasing else 2.0) * move_dir) if moving else 0.0
		State.TELEGRAPH:
			# Pose de mira: recua/estica contra o facing enquanto "carrega" o
			# tiro, com tremor leve (tensão crescendo até o disparo).
			_walk_t = 0.0
			var p: float = clampf(_phase_timer / maxf(telegraph_time, 0.0001), 0.0, 1.0)
			var draw: float = sin(p * PI * 0.5)
			var tremor: float = sin(_phase_timer * 50.0) * 0.5 * p
			pos = _sprite_base_pos + Vector2(-5.0 * draw * facing + tremor, -1.5 * draw)
			scl = _sprite_base_scale * Vector2(1.0 - 0.09 * draw, 1.0 + 0.09 * draw)
			rot = deg_to_rad((-5.0 * draw + tremor) * facing)
		_:
			_walk_t = 0.0

	if _fire_kick_t > 0.0:
		# Coice do disparo — recua rápido contra o facing e relaxa.
		var k: float = _fire_kick_t / FIRE_KICK_DUR
		var ke: float = k * k
		pos += Vector2(-7.0 * ke * facing, 0.0)
		rot += deg_to_rad(-6.0 * ke * facing)
		scl *= Vector2(1.0 - 0.05 * ke, 1.0 + 0.06 * ke)

	if _hurt_recoil_t > 0.0:
		var e3: float = _hurt_recoil_t / HURT_RECOIL_DUR
		pos += Vector2(-8.0 * e3 * facing, -2.0 * e3)
		rot += deg_to_rad(-9.0 * e3 * facing)
		scl *= Vector2(1.0 + 0.05 * e3, 1.0 - 0.07 * e3)

	sprite.position = pos
	sprite.scale = scl
	sprite.rotation = rot


func _fire_projectile() -> void:
	var parent_node: Node = get_parent()
	if parent_node == null:
		parent_node = get_tree().current_scene if get_tree() else null
	if parent_node == null:
		return
	var proj: Node = PROJECTILE_SCENE.instantiate()
	parent_node.add_child(proj)
	if proj is Node2D:
		(proj as Node2D).global_position = global_position + Vector2(facing * 26.0, -34.0)
	if proj.has_method("setup"):
		proj.call("setup", facing, projectile_damage, projectile_knockback, projectile_speed)
	if is_instance_valid(Audio):
		Audio.play_sfx("hit", 1.25, 0.7)


func _on_hurt(hit_data: HitData) -> void:
	if _died or hp <= 0:
		return
	hp = maxi(0, hp - hit_data.damage)
	velocity.x = hit_data.knockback.x
	velocity.y = hit_data.knockback.y
	_start_flash()
	_hurt_recoil_t = HURT_RECOIL_DUR
	_refresh_label()
	print("[OniRanged] hurt dmg=%d hp=%d/%d" % [hit_data.damage, hp, max_hp])
	# Interrompe telegraph ao tomar hit (ainda não comprometeu o disparo).
	if state == State.TELEGRAPH:
		if sprite:
			sprite.modulate = _base_modulate
		state = State.CHASE
	if hp <= 0:
		_on_defeated()


func _on_defeated() -> void:
	if _died:
		return
	_died = true
	state = State.DEAD
	if hurtbox:
		hurtbox.invulnerable = true
	if sprite:
		sprite.modulate = Color(0.4, 0.4, 0.45, 0.8)
	if hp_label:
		hp_label.text = "HP 0/%d — KO" % max_hp
	_spawn_coin_drop()
	defeated.emit()
	# Tombo/squash procedural junto com o fade.
	var tree: SceneTree = get_tree()
	if sprite and tree:
		var tw: Tween = create_tween()
		tw.set_parallel(true)
		tw.tween_property(sprite, "modulate:a", 0.0, 0.3)
		var fall_dir: float = facing if not is_zero_approx(facing) else 1.0
		tw.tween_property(sprite, "rotation", deg_to_rad(74.0 * fall_dir), 0.3) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(sprite, "scale", _sprite_base_scale * Vector2(1.2, 0.66), 0.3) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if tree:
		await tree.create_timer(0.35).timeout
	if is_instance_valid(self):
		queue_free()


func _spawn_coin_drop() -> void:
	## Não credita moedas aqui — só spawna pickup (anti double-count).
	var parent_node: Node = get_parent()
	if parent_node == null:
		parent_node = get_tree().current_scene if get_tree() else null
	if parent_node == null:
		push_error("[OniRanged] sem parent pra drop de moeda")
		return
	var coin: Node = COIN_SCENE.instantiate()
	if coin == null:
		push_error("[OniRanged] falha ao instanciar coin_pickup")
		return
	parent_node.add_child(coin)
	if coin is Node2D:
		(coin as Node2D).global_position = global_position + Vector2(facing * 12.0, -36.0)
		(coin as Node2D).z_index = 25
	if coin.has_method("setup"):
		coin.call("setup", coin_reward)
	elif "value" in coin:
		coin.set("value", coin_reward)


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


func _refresh_label() -> void:
	if hp_label:
		hp_label.text = "HP %d/%d" % [hp, max_hp]
