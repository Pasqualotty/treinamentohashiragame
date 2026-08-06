extends CharacterBody2D
## Oni fraco/elite (conteúdo): patrulha ↔ chase + telegraph ~0.4s + hitbox de ataque.
## Group `enemy`. Hurtbox recebe hits do player.
## Anims: idle/walk/attack/hurt/dead — sheet único (flip + scale/modulate se faltar frames).
## REGRA MOEDAS: ao morrer spawna coin_pickup; NÃO chama add_run_coins na kill
## (só o pickup credita — ver coin_pickup.gd).

signal defeated

enum State { PATROL, CHASE, TELEGRAPH, ATTACK, HURT, DEAD }
enum Anim { IDLE, WALK, ATTACK, HURT, DEAD }

const FLASH_COLOR: Color = Color(1.45, 0.35, 0.35, 1.0)
const FLASH_TIME: float = 0.1
const KNOCK_FRICTION: float = 900.0
const HURT_STUN: float = 0.12
const COIN_SCENE: PackedScene = preload("res://scenes/combat/coin_pickup.tscn")

@export var max_hp: int = 30
## Valor da moeda spawnada no chão (creditada só no pickup).
@export var coin_reward: int = 10
@export var patrol_speed: float = 55.0
@export var chase_speed: float = 105.0
@export var detect_range: float = 240.0
@export var attack_range: float = 52.0
@export var telegraph_time: float = 0.4
@export var attack_active_time: float = 0.14
@export var attack_recovery: float = 0.32
@export var attack_cooldown: float = 0.85
@export var patrol_half_width: float = 90.0
@export var attack_damage: int = 4
@export var attack_knockback: Vector2 = Vector2(140.0, -40.0)

@onready var sprite: Sprite2D = %Sprite
@onready var hurtbox: Hurtbox = %Hurtbox
@onready var hitbox: Hitbox = %Hitbox
@onready var hp_label: Label = %HpLabel

var hp: int = 30
var state: State = State.PATROL
var facing: float = -1.0
var _home_x: float = 0.0
var _patrol_dir: float = -1.0
var _flash_left: float = 0.0
var _base_modulate: Color = Color.WHITE
var _base_scale: Vector2 = Vector2.ONE
var _phase_timer: float = 0.0
var _cooldown_left: float = 0.0
var _hurt_timer: float = 0.0
var _hitbox_base_x: float = 28.0
var _gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity") as float
var _died: bool = false
var _current_anim: Anim = Anim.IDLE


func _ready() -> void:
	add_to_group("enemy")
	hp = max_hp
	_home_x = global_position.x
	if sprite:
		_base_modulate = sprite.modulate
		_base_scale = sprite.scale
		facing = -1.0 if sprite.flip_h else 1.0
		_patrol_dir = facing
	if hurtbox:
		hurtbox.team = &"enemy"
		if not hurtbox.hurt.is_connected(_on_hurt):
			hurtbox.hurt.connect(_on_hurt)
	if hitbox:
		hitbox.team = &"enemy"
		hitbox.damage = attack_damage
		hitbox.knockback = attack_knockback
		hitbox.disable()
		_hitbox_base_x = absf(hitbox.position.x)
		if is_zero_approx(_hitbox_base_x):
			_hitbox_base_x = 28.0
	_apply_facing()
	_play_anim(Anim.IDLE)
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

	if state == State.HURT:
		_hurt_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, KNOCK_FRICTION * delta)
		move_and_slide()
		_tick_flash(delta)
		if _hurt_timer <= 0.0:
			state = State.CHASE
			_play_anim(Anim.WALK)
		return

	match state:
		State.PATROL:
			_ai_patrol(delta)
		State.CHASE:
			_ai_chase(delta)
		State.TELEGRAPH:
			_ai_telegraph(delta)
		State.ATTACK:
			_ai_attack(delta)

	move_and_slide()
	_tick_flash(delta)
	_update_idle_walk_anim()


func _ai_patrol(_delta: float) -> void:
	var player: Node2D = _find_player()
	if player and _dist_to(player) <= detect_range:
		state = State.CHASE
		_play_anim(Anim.WALK)
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
		velocity.x = move_toward(velocity.x, 0.0, KNOCK_FRICTION * _delta)


func _ai_chase(_delta: float) -> void:
	var player: Node2D = _find_player()
	if player == null or _dist_to(player) > detect_range * 1.35:
		state = State.PATROL
		return

	var dx: float = player.global_position.x - global_position.x
	if not is_zero_approx(dx):
		facing = signf(dx)
		_apply_facing()

	if _dist_to(player) <= attack_range and _cooldown_left <= 0.0 and is_on_floor():
		_start_telegraph()
		return

	if is_on_floor():
		velocity.x = facing * chase_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, KNOCK_FRICTION * _delta)


func _start_telegraph() -> void:
	state = State.TELEGRAPH
	_phase_timer = 0.0
	velocity.x = 0.0
	if hitbox:
		hitbox.disable()
	_play_anim(Anim.ATTACK)
	if sprite:
		sprite.modulate = Color(1.35, 1.05, 0.55, 1.0)


func _ai_telegraph(delta: float) -> void:
	velocity.x = 0.0
	_phase_timer += delta
	# Pulso de aviso no telegraph (~0.4s).
	if sprite:
		var pulse: float = 0.85 + 0.2 * absf(sin(_phase_timer * 22.0))
		sprite.modulate = Color(1.35 * pulse, 1.05 * pulse, 0.45, 1.0)
		# Stretch leve no telegraph (sheet único).
		sprite.scale = _base_scale * Vector2(1.0 + 0.06 * sin(_phase_timer * 18.0), 1.0 - 0.04 * sin(_phase_timer * 18.0))
	if _phase_timer >= telegraph_time:
		_start_attack()


func _start_attack() -> void:
	state = State.ATTACK
	_phase_timer = 0.0
	velocity.x = 0.0
	if sprite:
		sprite.modulate = _base_modulate
		sprite.scale = _base_scale * Vector2(1.12, 0.92)
	if hitbox:
		hitbox.damage = attack_damage
		hitbox.knockback = attack_knockback
		hitbox.set_facing(facing)
		hitbox.enable()


func _ai_attack(delta: float) -> void:
	velocity.x = 0.0
	_phase_timer += delta
	if _phase_timer < attack_active_time:
		if hitbox and not hitbox.is_active():
			hitbox.set_facing(facing)
			hitbox.enable()
		if sprite:
			sprite.scale = _base_scale * Vector2(1.12, 0.92)
	else:
		if hitbox and hitbox.is_active():
			hitbox.disable()
		if sprite:
			sprite.scale = _base_scale
	if _phase_timer >= attack_active_time + attack_recovery:
		if hitbox:
			hitbox.disable()
		if sprite:
			sprite.scale = _base_scale
			sprite.modulate = _base_modulate
		_cooldown_left = attack_cooldown
		state = State.CHASE
		_play_anim(Anim.WALK)


func _on_hurt(hit_data: HitData) -> void:
	if _died or hp <= 0:
		return
	hp = maxi(0, hp - hit_data.damage)
	velocity.x = hit_data.knockback.x
	velocity.y = hit_data.knockback.y
	_start_flash()
	_refresh_label()
	if is_instance_valid(Audio):
		Audio.play_sfx("hit")
	print("[Oni] hurt dmg=%d hp=%d/%d" % [hit_data.damage, hp, max_hp])
	# Interrompe telegraph/ataque ao tomar hit.
	if state == State.TELEGRAPH or state == State.ATTACK:
		if hitbox:
			hitbox.disable()
		if sprite:
			sprite.modulate = _base_modulate
			sprite.scale = _base_scale
	if hp <= 0:
		_on_defeated()
		return
	state = State.HURT
	_hurt_timer = HURT_STUN
	_play_anim(Anim.HURT)


func _on_defeated() -> void:
	if _died:
		return
	_died = true
	state = State.DEAD
	_play_anim(Anim.DEAD)
	if hitbox:
		hitbox.disable()
	if hurtbox:
		hurtbox.invulnerable = true
	if sprite:
		sprite.modulate = Color(0.4, 0.4, 0.45, 0.8)
		sprite.scale = _base_scale * Vector2(1.0, 0.75)
		sprite.rotation_degrees = 12.0 * facing
	if hp_label:
		hp_label.text = "HP 0/%d — KO" % max_hp
	_spawn_coin_drop()
	defeated.emit()
	# Remove após feedback curto (stage já contou via signal + hp==0).
	var tree: SceneTree = get_tree()
	if tree:
		await tree.create_timer(0.35).timeout
	if is_instance_valid(self):
		queue_free()


func _spawn_coin_drop() -> void:
	## Não credita moedas aqui — só spawna pickup (anti double-count).
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	var coin: Node = COIN_SCENE.instantiate()
	if coin == null:
		push_error("[Oni] falha ao instanciar coin_pickup")
		return
	parent_node.add_child(coin)
	if coin is Node2D:
		(coin as Node2D).global_position = global_position + Vector2(0.0, -12.0)
	if coin.has_method("setup"):
		coin.call("setup", coin_reward)
	elif "value" in coin:
		coin.set("value", coin_reward)
	print("[Oni] drop coin value=%d (crédito só no pickup)" % coin_reward)


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
	if sprite:
		# Arte base olha pra esquerda; facing>0 = direita (flip_h false).
		sprite.flip_h = facing < 0.0
	if hitbox:
		hitbox.position.x = _hitbox_base_x * facing


func _play_anim(anim: Anim) -> void:
	_current_anim = anim
	if sprite == null:
		return
	match anim:
		Anim.IDLE:
			sprite.modulate = _base_modulate
			sprite.scale = _base_scale
			sprite.rotation = 0.0
		Anim.WALK:
			sprite.modulate = _base_modulate
			sprite.rotation = 0.0
		Anim.ATTACK:
			# Telegraph/attack usam modulate/scale no loop da fase.
			pass
		Anim.HURT:
			sprite.modulate = FLASH_COLOR
			sprite.scale = _base_scale * Vector2(0.95, 1.05)
		Anim.DEAD:
			# Aplicado em _on_defeated.
			pass


func _update_idle_walk_anim() -> void:
	if state != State.PATROL and state != State.CHASE:
		return
	if sprite == null:
		return
	var moving: bool = absf(velocity.x) > 8.0 and is_on_floor()
	if moving:
		_current_anim = Anim.WALK
		# Bob de walk no frame único (sem sheet de walk).
		var t: float = Time.get_ticks_msec() * 0.012
		sprite.scale = _base_scale * Vector2(1.0, 1.0 + 0.04 * sin(t))
		sprite.modulate = _base_modulate
	else:
		_current_anim = Anim.IDLE
		sprite.scale = _base_scale
		sprite.modulate = _base_modulate


func _start_flash() -> void:
	_flash_left = FLASH_TIME
	if sprite and state != State.TELEGRAPH:
		sprite.modulate = FLASH_COLOR


func _tick_flash(delta: float) -> void:
	if _flash_left <= 0.0:
		return
	_flash_left -= delta
	if _flash_left <= 0.0 and sprite and state != State.TELEGRAPH and state != State.DEAD and state != State.HURT:
		sprite.modulate = _base_modulate


func _refresh_label() -> void:
	if hp_label:
		hp_label.text = "HP %d/%d" % [hp, max_hp]
