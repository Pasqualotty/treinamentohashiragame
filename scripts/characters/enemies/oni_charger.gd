extends CharacterBody2D
## Oni investida (conteúdo NOVO): avança, telegrafa e dispara uma investida
## rápida (dash com hitbox ativa) que atravessa o campo até bater em parede ou
## expirar. Copiado/adaptado do padrão de `oni_weak.gd` (state machine +
## convenções hp/_died/defeated) — NÃO edita oni_weak.gd/.tscn.
## Group `enemy`. Hurtbox recebe hits do player.
## REGRA MOEDAS: ao morrer spawna coin_pickup; NÃO chama add_run_coins na kill
## (só o pickup credita — ver coin_pickup.gd).

signal defeated

enum State { PATROL, CHASE, TELEGRAPH, CHARGE, RECOVER, DEAD }

const FLASH_COLOR: Color = Color(1.45, 0.35, 0.35, 1.0)
const FLASH_TIME: float = 0.1
const KNOCK_FRICTION: float = 1100.0
const COIN_SCENE: PackedScene = preload("res://scenes/combat/coin_pickup.tscn")

@export var max_hp: int = 38
## Valor da moeda spawnada no chão (creditada só no pickup).
@export var coin_reward: int = 16
@export var patrol_speed: float = 58.0
@export var chase_speed: float = 100.0
@export var charge_speed: float = 430.0
@export var detect_range: float = 260.0
@export var charge_trigger_range: float = 220.0
@export var telegraph_time: float = 0.5
@export var charge_max_time: float = 0.55
@export var recovery_time: float = 0.6
@export var attack_cooldown: float = 1.5
@export var attack_damage: int = 9
@export var attack_knockback: Vector2 = Vector2(220.0, -60.0)
@export var patrol_half_width: float = 100.0

@onready var sprite: Sprite2D = %Sprite
@onready var hurtbox: Hurtbox = %Hurtbox
@onready var hitbox: Hitbox = %Hitbox
@onready var hp_label: Label = %HpLabel

var hp: int = 38
var state: State = State.PATROL
var facing: float = -1.0
var _home_x: float = 0.0
var _patrol_dir: float = -1.0
var _flash_left: float = 0.0
var _base_modulate: Color = Color.WHITE
var _phase_timer: float = 0.0
var _cooldown_left: float = 0.0
var _hitbox_base_x: float = 30.0
var _gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity") as float
var _died: bool = false


func _ready() -> void:
	add_to_group("enemy")
	hp = max_hp
	_home_x = global_position.x
	if sprite:
		_base_modulate = sprite.modulate
		facing = -1.0 if sprite.flip_h else 1.0
		_patrol_dir = facing
	if hurtbox:
		hurtbox.team = &"enemy"
		if not hurtbox.hurt.is_connected(_on_hurt):
			hurtbox.hurt.connect(_on_hurt)
	if hitbox:
		hitbox.team = &"enemy"
		hitbox.disable()
		_hitbox_base_x = absf(hitbox.position.x)
		if is_zero_approx(_hitbox_base_x):
			_hitbox_base_x = 30.0
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
		State.CHARGE:
			_ai_charge(delta)
		State.RECOVER:
			_ai_recover(delta)

	move_and_slide()
	if state == State.CHARGE and is_on_wall():
		_end_charge()
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
	if player == null or _dist_to(player) > detect_range * 1.4:
		state = State.PATROL
		return

	var dx: float = player.global_position.x - global_position.x
	if not is_zero_approx(dx):
		facing = signf(dx)
		_apply_facing()

	if absf(dx) <= charge_trigger_range and _cooldown_left <= 0.0 and is_on_floor():
		_start_telegraph()
		return

	if is_on_floor():
		velocity.x = facing * chase_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, KNOCK_FRICTION * delta)


func _start_telegraph() -> void:
	state = State.TELEGRAPH
	_phase_timer = 0.0
	velocity.x = 0.0
	if hitbox:
		hitbox.disable()
	if sprite:
		sprite.modulate = Color(1.55, 0.85, 0.4, 1.0)


func _ai_telegraph(delta: float) -> void:
	velocity.x = 0.0
	_phase_timer += delta
	if sprite:
		var pulse: float = 0.8 + 0.3 * absf(sin(_phase_timer * 30.0))
		sprite.modulate = Color(1.55 * pulse, 0.85 * pulse, 0.4 * pulse, 1.0)
	if _phase_timer >= telegraph_time:
		_start_charge()


func _start_charge() -> void:
	state = State.CHARGE
	_phase_timer = 0.0
	if sprite:
		sprite.modulate = Color(1.7, 1.5, 1.2, 1.0)
	if hitbox:
		hitbox.damage = attack_damage
		hitbox.knockback = attack_knockback
		hitbox.set_facing(facing)
		hitbox.position.x = _hitbox_base_x * facing
		hitbox.enable()


func _ai_charge(delta: float) -> void:
	# Comprometido — hit não interrompe a investida (poise durante o dash).
	velocity.x = facing * charge_speed
	_phase_timer += delta
	if _phase_timer >= charge_max_time:
		_end_charge()


func _end_charge() -> void:
	if hitbox:
		hitbox.disable()
	state = State.RECOVER
	_phase_timer = 0.0
	if sprite:
		sprite.modulate = _base_modulate


func _ai_recover(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, KNOCK_FRICTION * 1.6 * delta)
	_phase_timer += delta
	if _phase_timer >= recovery_time:
		_cooldown_left = attack_cooldown
		state = State.CHASE


func _on_hurt(hit_data: HitData) -> void:
	if _died or hp <= 0:
		return
	hp = maxi(0, hp - hit_data.damage)
	velocity.x = hit_data.knockback.x
	velocity.y = hit_data.knockback.y
	_start_flash()
	_refresh_label()
	print("[OniCharger] hurt dmg=%d hp=%d/%d" % [hit_data.damage, hp, max_hp])
	# Só o telegraph é cancelável (antes do compromisso); CHARGE tem poise.
	if state == State.TELEGRAPH:
		if hitbox:
			hitbox.disable()
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
	if hitbox:
		hitbox.disable()
	if hurtbox:
		hurtbox.invulnerable = true
	if sprite:
		sprite.modulate = Color(0.4, 0.4, 0.45, 0.8)
	if hp_label:
		hp_label.text = "HP 0/%d — KO" % max_hp
	_spawn_coin_drop()
	defeated.emit()
	var tree: SceneTree = get_tree()
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
		push_error("[OniCharger] sem parent pra drop de moeda")
		return
	var coin: Node = COIN_SCENE.instantiate()
	if coin == null:
		push_error("[OniCharger] falha ao instanciar coin_pickup")
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
	if sprite:
		sprite.flip_h = facing < 0.0
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


func _refresh_label() -> void:
	if hp_label:
		hp_label.text = "HP %d/%d" % [hp, max_hp]
