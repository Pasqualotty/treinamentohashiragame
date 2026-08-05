class_name PlayerStats
extends Resource
## Stats de movimento do player (balanceável via .tres / loja depois).

@export var move_speed: float = 220.0
@export var jump_velocity: float = -420.0
@export var gravity: float = 1400.0
@export var max_fall_speed: float = 900.0
## Tempo após sair do chão em que ainda pode pular (s).
@export var coyote_time: float = 0.12
@export var dash_speed: float = 560.0
@export var dash_duration: float = 0.14
@export var dash_cooldown: float = 1.0
