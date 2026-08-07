class_name PlayerStats
extends Resource
## Stats do player unificado (movimento + combate). Balanceável via .tres / loja depois.

# --- Movimento ---
@export var move_speed: float = 220.0
@export var jump_velocity: float = -420.0
@export var gravity: float = 1400.0
@export var max_fall_speed: float = 900.0
## Tempo após sair do chão em que ainda pode pular (s).
@export var coyote_time: float = 0.12
## Aceleração horizontal (px/s²) — feel de peso sem lag de stick.
@export var move_accel: float = 3200.0
## Freio horizontal sem input (px/s²).
@export var move_friction: float = 3800.0
## Buffer de input jump/attack/dash (s). Faixa premium ~0.10–0.15.
@export var input_buffer: float = 0.12
## Fração final do recovery em que basic pode cancelar em dash/pulo (0–1).
@export var attack_cancel_ratio: float = 0.45
@export var dash_speed: float = 560.0
@export var dash_duration: float = 0.14
@export var dash_cooldown: float = 1.0

# --- Vida ---
@export var max_hp: int = 100
@export var hurt_stun: float = 0.22
@export var hurt_invuln: float = 0.45
## Freio no chão durante hurt (px/s²) — recovery legível sem “slide eterno”.
@export var hurt_friction: float = 1400.0

# --- Attack basic ---
@export var attack_damage: int = 5
@export var attack_knockback: Vector2 = Vector2(180.0, -70.0)
@export var attack_startup: float = 0.06
@export var attack_active: float = 0.12
@export var attack_recovery: float = 0.14
@export var attack_hitbox_size: Vector2 = Vector2(40.0, 30.0)
@export var attack_hitbox_offset_x: float = 28.0

# --- Skill 1: Corte em Arco (placeholder GDD) ---
@export var skill_1_display_name: String = "Corte em Arco"
@export var skill_1_damage: int = 10
@export var skill_1_knockback: Vector2 = Vector2(220.0, -90.0)
@export var skill_1_cooldown: float = 4.0
@export var skill_1_startup: float = 0.08
@export var skill_1_active: float = 0.16
@export var skill_1_recovery: float = 0.18
@export var skill_1_hitbox_size: Vector2 = Vector2(56.0, 36.0)
@export var skill_1_hitbox_offset_x: float = 32.0

# --- Skill 2: Investida (placeholder GDD) ---
@export var skill_2_display_name: String = "Investida"
@export var skill_2_damage: int = 8
@export var skill_2_knockback: Vector2 = Vector2(280.0, -40.0)
@export var skill_2_cooldown: float = 5.0
@export var skill_2_startup: float = 0.05
@export var skill_2_active: float = 0.18
@export var skill_2_recovery: float = 0.12
@export var skill_2_lunge_speed: float = 480.0
@export var skill_2_hitbox_size: Vector2 = Vector2(44.0, 28.0)
@export var skill_2_hitbox_offset_x: float = 30.0

# --- Ultimate (consome barra de respira├º├úo) ---
@export var ultimate_damage: int = 25
@export var ultimate_knockback: Vector2 = Vector2(320.0, -120.0)
@export var ultimate_startup: float = 0.10
@export var ultimate_active: float = 0.25
@export var ultimate_recovery: float = 0.30
@export var ultimate_iframes: float = 0.40
@export var ultimate_hitbox_size: Vector2 = Vector2(72.0, 48.0)
@export var ultimate_hitbox_offset_x: float = 36.0
## Breath ganho por hit que acerta (via Game.add_breath_from_hit).
@export var breath_per_hit: float = 10.0
