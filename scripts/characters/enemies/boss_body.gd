extends CharacterBody2D
## Corpo compartilhado de chefe: intro, patrol/chase, telegraph, recover,
## fases por HP, HUD, poise, coin_pickup. Ataques ficam nos filhos.
## REGRA MOEDAS: só o coin_pickup credita.

signal defeated

enum State { INTRO, PATROL, CHASE, TELEGRAPH, ATTACK, RECOVER, DEAD }

const FLASH_COLOR: Color = Color(1.6, 0.4, 0.4, 1.0)
const FLASH_TIME: float = 0.1
const KNOCK_FRICTION: float = 820.0
const COIN_SCENE: PackedScene = preload("res://scenes/combat/coin_pickup.tscn")
const HURT_RECOIL_DUR: float = 0.2

@export var boss_display_name: String = "Chefe"
@export var skip_intro: bool = false
@export var max_hp: int = 280
@export var coin_reward: int = 70
@export var patrol_speed: float = 50.0
@export var chase_speed: float = 120.0
@export var detect_range: float = 520.0
@export var attack_range: float = 340.0
@export var patrol_half_width: float = 160.0
@export var attack_cooldown_base: float = 1.8
@export var recovery_time: float = 0.5
@export var hp_fill: Color = Color(0.77, 0.24, 0.24, 1.0)

@onready var sprite: Sprite2D = %Sprite
@onready var hurtbox: Hurtbox = %Hurtbox
@onready var hitbox: Hitbox = %Hitbox
@onready var hp_label: Label = get_node_or_null("%HpLabel") as Label

var hp: int = 280
var state: int = State.INTRO
var phase: int = BossCommon.PHASE_P1
var facing: float = -1.0
var _pending_attack: int = 0
var _telegraph_base_color: Color = Color.WHITE
var _home_x: float = 0.0
var _patrol_dir: float = -1.0
var _flash_left: float = 0.0
var _base_modulate: Color = Color.WHITE
var _phase_timer: float = 0.0
var _cooldown_left: float = 0.0
var _hitbox_base_x: float = 46.0
var _gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity") as float
var _died: bool = false
var _attack_duration: float = 0.4
var _hurt_recoil_t: float = 0.0
var _sprite_base_pos: Vector2 = Vector2.ZERO
var _sprite_base_scale: Vector2 = Vector2.ONE
var _walk_t: float = 0.0
var _hp_ui: Dictionary = {}
var _banner_ui: Dictionary = {}
var _hp_layer: CanvasLayer
var _banner_tween: Tween


func _ready() -> void:
	add_to_group("enemy")
	hp = max_hp
	_home_x = global_position.x
	if sprite:
		_base_modulate = sprite.modulate
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
	_arm_extra_hitboxes()
	_apply_facing()
	_hp_ui = BossCommon.attach_hp_bar(self, boss_display_name, max_hp, hp, hp_fill)
	_hp_layer = _hp_ui.get("layer", null) as CanvasLayer
	_banner_ui = BossCommon.attach_banner(self)
	BossCommon.refresh_hp(_hp_ui, hp, max_hp, hp_label)
	if is_instance_valid(Audio):
		Audio.play_bgm("boss")
	_play_intro()


func _arm_extra_hitboxes() -> void:
	pass


func _all_hitboxes() -> Array:
	return [hitbox]


func _pick_attack() -> int:
	return 0


func _telegraph_color_for(_kind: int) -> Color:
	return Color(1.55, 0.8, 0.4, 1.0)


func _telegraph_base_time(_kind: int) -> float:
	return 0.55


func _on_attack_start(_kind: int) -> void:
	_attack_duration = 0.4
	if hitbox:
		BossCommon.arm_hitbox(hitbox, 12, Vector2(220, -70), _hitbox_base_x * facing, facing)


func _on_attack_tick(delta: float) -> void:
	velocity.x = 0.0
	_phase_timer += delta
	if _phase_timer >= _attack_duration:
		_finish_attack()


func _on_attack_end() -> void:
	BossCommon.disable_hitboxes(_all_hitboxes())
	if sprite:
		sprite.modulate = _base_modulate


func _phase_banner_for(new_phase: int) -> Dictionary:
	if new_phase == BossCommon.PHASE_P2:
		return {
			"title": "%s ENTRA EM FÚRIA!" % boss_display_name.to_upper(),
			"color": Color(1.0, 0.55, 0.25, 1.0),
		}
	return {
		"title": "FASE FINAL — %s DESESPERADO!" % boss_display_name.to_upper(),
		"color": Color(1.0, 0.25, 0.35, 1.0),
	}


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += _gravity * delta
	if _cooldown_left > 0.0:
		_cooldown_left = maxf(0.0, _cooldown_left - delta)
	if state == State.DEAD or state == State.INTRO:
		velocity.x = move_toward(velocity.x, 0.0, KNOCK_FRICTION * delta)
		move_and_slide()
		_tick_flash(delta)
		return
	_run_state(delta)
	_update_walk_anim(delta)
	move_and_slide()
	_tick_flash(delta)


func _run_state(delta: float) -> void:
	match state:
		State.PATROL:
			_ai_patrol(delta)
		State.CHASE:
			_ai_chase(delta)
		State.TELEGRAPH:
			_ai_telegraph(delta)
		State.ATTACK:
			_on_attack_tick(delta)
		State.RECOVER:
			_ai_recover(delta)


func _ai_patrol(delta: float) -> void:
	var player: Node2D = BossCommon.find_player(get_tree())
	if player and global_position.distance_to(player.global_position) <= detect_range:
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
	var player: Node2D = BossCommon.find_player(get_tree())
	if player == null:
		velocity.x = move_toward(velocity.x, 0.0, KNOCK_FRICTION * delta)
		return
	var dx: float = player.global_position.x - global_position.x
	if not is_zero_approx(dx):
		facing = signf(dx)
		_apply_facing()
	if absf(dx) <= attack_range and _cooldown_left <= 0.0 and is_on_floor():
		_begin_attack_cycle()
		return
	if is_on_floor():
		velocity.x = facing * chase_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, KNOCK_FRICTION * delta)


func _begin_attack_cycle() -> void:
	_pending_attack = _pick_attack()
	state = State.TELEGRAPH
	_phase_timer = 0.0
	velocity.x = 0.0
	_telegraph_base_color = _telegraph_color_for(_pending_attack)


func _ai_telegraph(delta: float) -> void:
	velocity.x = 0.0
	_phase_timer += delta
	if sprite:
		var pulse: float = 0.82 + 0.28 * absf(sin(_phase_timer * 26.0))
		var c: Color = _telegraph_base_color * pulse
		c.a = 1.0
		sprite.modulate = c
	var dur: float = BossCommon.telegraph_duration(_telegraph_base_time(_pending_attack), phase)
	if _phase_timer >= dur:
		_start_attack()


func _start_attack() -> void:
	state = State.ATTACK
	_phase_timer = 0.0
	_on_attack_start(_pending_attack)


func _finish_attack() -> void:
	_on_attack_end()
	_start_recover()


func _start_recover() -> void:
	state = State.RECOVER
	_phase_timer = 0.0


func _ai_recover(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, KNOCK_FRICTION * delta)
	_phase_timer += delta
	var dur: float = BossCommon.recovery_duration(recovery_time, phase)
	if _phase_timer >= dur:
		_cooldown_left = attack_cooldown_base * BossCommon.phase_cooldown_mult(phase)
		state = State.CHASE


func _update_walk_anim(delta: float) -> void:
	if sprite == null:
		return
	if state != State.PATROL and state != State.CHASE:
		sprite.position = _sprite_base_pos
		sprite.scale = _sprite_base_scale
		return
	var moving: bool = is_on_floor() and not is_zero_approx(velocity.x)
	if moving:
		_walk_t += delta * 6.0 * BossCommon.phase_weight_mult(phase)
	var bob: float = sin(_walk_t) * 4.0 if moving else 0.0
	sprite.position = _sprite_base_pos + Vector2(0.0, bob)


func _on_hurt(hit_data: HitData) -> void:
	if _died or hp <= 0:
		return
	hp = maxi(0, hp - hit_data.damage)
	velocity.x = hit_data.knockback.x * 0.45
	velocity.y = hit_data.knockback.y * 0.45
	_start_flash()
	_hurt_recoil_t = HURT_RECOIL_DUR
	BossCommon.refresh_hp(_hp_ui, hp, max_hp, hp_label)
	_check_phase_transition()
	if hp <= 0:
		_on_defeated()


func _check_phase_transition() -> void:
	var new_phase: int = BossCommon.next_phase(phase, hp, max_hp)
	if not BossCommon.did_advance(phase, new_phase):
		return
	phase = new_phase
	_enter_phase(phase)


func _enter_phase(new_phase: int) -> void:
	var info: Dictionary = _phase_banner_for(new_phase)
	_show_banner_async(str(info.get("title", "")), info.get("color", Color.WHITE) as Color, 1.3)
	if is_instance_valid(CombatFeel):
		CombatFeel.shake(7.5, 0.24)
	if is_instance_valid(Audio):
		Audio.play_sfx("hit", 0.7, 1.3)
	if state != State.DEAD and state != State.INTRO:
		BossCommon.disable_hitboxes(_all_hitboxes())
		if sprite:
			sprite.modulate = _base_modulate
		_start_recover()


func _on_defeated() -> void:
	if _died:
		return
	_died = true
	state = State.DEAD
	BossCommon.disable_hitboxes(_all_hitboxes())
	if hurtbox:
		hurtbox.invulnerable = true
	if hp_label:
		hp_label.text = "HP 0/%d — KO" % max_hp
	BossCommon.spawn_coin_drop(self, COIN_SCENE, coin_reward, facing)
	defeated.emit()
	_show_banner_async("%s DERROTADO!" % boss_display_name.to_upper(), Color(1.0, 0.82, 0.35, 1.0), 1.3)
	BossCommon.fade_hp_layer(self, _hp_layer)
	if is_instance_valid(CombatFeel):
		CombatFeel.shake(9.0, 0.5)
	var tree: SceneTree = get_tree()
	if tree:
		await tree.create_timer(0.85).timeout
	if is_instance_valid(self):
		queue_free()


func _play_intro() -> void:
	state = State.INTRO
	velocity = Vector2.ZERO
	if skip_intro:
		state = State.PATROL
		return
	await _show_banner("— %s —" % boss_display_name.to_upper(), Color(1.0, 0.6, 0.95, 1.0), 1.6)
	if is_instance_valid(self) and state == State.INTRO:
		state = State.PATROL


func _show_banner(text: String, color: Color, hold: float = 1.2) -> void:
	_banner_tween = BossCommon.play_banner(self, _banner_ui, text, color, hold)
	if _banner_tween:
		await _banner_tween.finished


func _show_banner_async(text: String, color: Color, hold: float = 1.2) -> void:
	_show_banner(text, color, hold)


func _apply_facing() -> void:
	BossCommon.apply_facing(sprite, hitbox, facing, _hitbox_base_x)


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
