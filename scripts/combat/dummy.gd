extends CharacterBody2D
## Dummy estático de teste: Hurtbox + HP + flash + knockback leve.

signal defeated

const FLASH_COLOR: Color = Color(1.4, 0.4, 0.4, 1.0)
const FLASH_TIME: float = 0.12
const KNOCK_FRICTION: float = 900.0

@export var max_hp: int = 30

@onready var sprite: Sprite2D = %Sprite
@onready var hurtbox: Hurtbox = %Hurtbox
@onready var hp_label: Label = %HpLabel

var hp: int = 30
var _flash_left: float = 0.0
var _base_modulate: Color = Color.WHITE
var _gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity") as float
var _defeated: bool = false


func _ready() -> void:
	add_to_group("enemy")
	hp = max_hp
	if sprite:
		_base_modulate = sprite.modulate
	if hurtbox:
		hurtbox.team = &"enemy"
		if not hurtbox.hurt.is_connected(_on_hurt):
			hurtbox.hurt.connect(_on_hurt)
	_refresh_label()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += _gravity * delta
	else:
		velocity.x = move_toward(velocity.x, 0.0, KNOCK_FRICTION * delta)

	move_and_slide()

	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0 and sprite:
			sprite.modulate = _base_modulate


func _on_hurt(hit_data: HitData) -> void:
	if hp <= 0:
		return
	hp = maxi(0, hp - hit_data.damage)
	velocity.x = hit_data.knockback.x
	velocity.y = hit_data.knockback.y
	_start_flash()
	_refresh_label()
	if is_instance_valid(Audio):
		Audio.play_sfx("hit")
	print("[Dummy] hurt dmg=%d hp=%d/%d knock=%s" % [
		hit_data.damage, hp, max_hp, str(hit_data.knockback)
	])
	if hp <= 0:
		_on_defeated()


func _start_flash() -> void:
	_flash_left = FLASH_TIME
	if sprite:
		sprite.modulate = FLASH_COLOR


func _refresh_label() -> void:
	if hp_label:
		hp_label.text = "HP %d/%d" % [hp, max_hp]


func _on_defeated() -> void:
	if _defeated:
		return
	_defeated = true
	if hurtbox:
		hurtbox.invulnerable = true
	if sprite:
		sprite.modulate = Color(0.45, 0.45, 0.5, 0.85)
	if hp_label:
		hp_label.text = "HP 0/%d — KO" % max_hp
	defeated.emit()
