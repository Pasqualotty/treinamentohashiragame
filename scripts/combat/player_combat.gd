extends CharacterBody2D
## Player mínimo para sandbox de combate: move + pulo + attack_basic.
## Estado `attack_basic` com hitbox só nos frames active.

enum State { IDLE, RUN, JUMP, ATTACK_BASIC }

const SPEED: float = 220.0
const JUMP_VELOCITY: float = -380.0
## Janelas do golpe (segundos).
const ATK_STARTUP: float = 0.06
const ATK_ACTIVE: float = 0.12
const ATK_RECOVERY: float = 0.14

@onready var sprite: Sprite2D = %Sprite
@onready var hitbox: Hitbox = %Hitbox

var state: State = State.IDLE
var facing: float = 1.0
var _gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity") as float
var _attack_timer: float = 0.0
var _hitbox_base_x: float = 28.0


func _ready() -> void:
	add_to_group("player")
	if hitbox:
		hitbox.team = &"player"
		hitbox.damage = 5
		hitbox.knockback = Vector2(180.0, -70.0)
		hitbox.disable()
		_hitbox_base_x = absf(hitbox.position.x)
		if is_zero_approx(_hitbox_base_x):
			_hitbox_base_x = 28.0


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += _gravity * delta

	match state:
		State.ATTACK_BASIC:
			_process_attack(delta)
		_:
			_process_locomotion()

	move_and_slide()
	_update_state_after_move()


func _process_locomotion() -> void:
	var axis: float = Input.get_axis("move_left", "move_right")
	if not is_zero_approx(axis):
		facing = signf(axis)
		_apply_facing()
		velocity.x = axis * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED)

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	if Input.is_action_just_pressed("attack_basic") and is_on_floor():
		_start_attack()
		return

	if not is_on_floor():
		state = State.JUMP
	elif is_zero_approx(axis):
		state = State.IDLE
	else:
		state = State.RUN


func _start_attack() -> void:
	state = State.ATTACK_BASIC
	_attack_timer = 0.0
	velocity.x = 0.0
	if hitbox:
		hitbox.set_facing(facing)
		hitbox.disable()
	_apply_facing()


func _process_attack(delta: float) -> void:
	_attack_timer += delta
	velocity.x = 0.0

	# Active window: hitbox ligada só aqui (não “laser eterno”).
	if _attack_timer >= ATK_STARTUP and _attack_timer < ATK_STARTUP + ATK_ACTIVE:
		if hitbox and not hitbox.is_active():
			hitbox.set_facing(facing)
			hitbox.enable()
	else:
		if hitbox and hitbox.is_active():
			hitbox.disable()

	var total: float = ATK_STARTUP + ATK_ACTIVE + ATK_RECOVERY
	if _attack_timer >= total:
		if hitbox:
			hitbox.disable()
		state = State.IDLE
		return

	# Cancel leve no recovery se o player quiser se mover (opcional: sem cancel no MVP).
	# Mantém lock até recovery acabar.


func _update_state_after_move() -> void:
	if state == State.ATTACK_BASIC:
		return
	if not is_on_floor():
		state = State.JUMP
	elif absf(velocity.x) > 1.0:
		state = State.RUN
	else:
		state = State.IDLE


func _apply_facing() -> void:
	if sprite:
		sprite.flip_h = facing < 0.0
	if hitbox:
		hitbox.position.x = _hitbox_base_x * facing
