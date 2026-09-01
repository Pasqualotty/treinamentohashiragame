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

# --- Attack basic (hit 1 do combo — dano-base usado pelos upgrades da loja) ---
@export var attack_damage: int = 5
@export var attack_knockback: Vector2 = Vector2(180.0, -70.0)
@export var attack_startup: float = 0.06
@export var attack_active: float = 0.12
@export var attack_recovery: float = 0.14
@export var attack_hitbox_size: Vector2 = Vector2(40.0, 30.0)
@export var attack_hitbox_offset_x: float = 28.0
## AABB por frame do hit 1 (startup/recovery ignoram; active indexa 0..n-1).
## Vazio = usa attack_hitbox_size / offset_x em todos os frames.
@export var attack_hitbox_sizes: PackedVector2Array = PackedVector2Array([
	Vector2(36, 26), Vector2(52, 34), Vector2(62, 36),
])
@export var attack_hitbox_offsets_x: PackedFloat32Array = PackedFloat32Array([18.0, 32.0, 40.0])

# --- Combo básico (3 hits): hit 2 e hit 3 encadeiam a partir do attack_basic ---
## Fração do recovery do golpe atual (a partir do fim do active) em que um novo
## attack_basic já encadeia pro próximo hit do combo, cortando o resto do recovery.
## Mais alto = combo mais responsivo/generoso; mais baixo = mais "travado".
@export var attack_combo_chain_ratio: float = 0.8
## Janela (s) de tolerância após o golpe atual terminar (sem ter sido encadeado
## via cancel) em que um attack_basic ainda avança o combo em vez de resetar
## pro hit 1. Expira → combo volta a 0.
@export var attack_combo_grace: float = 0.28

## Hit 2: multiplicador sobre attack_damage (upgrades de loja continuam valendo
## pro combo inteiro, já que escalam attack_damage).
@export var attack_hit2_damage_mult: float = 1.2
@export var attack_hit2_knockback: Vector2 = Vector2(210.0, -90.0)
@export var attack_hit2_startup: float = 0.055
@export var attack_hit2_active: float = 0.12
@export var attack_hit2_recovery: float = 0.15
@export var attack_hit2_hitbox_size: Vector2 = Vector2(44.0, 32.0)
@export var attack_hit2_hitbox_offset_x: float = 30.0
@export var attack_hit2_hitbox_sizes: PackedVector2Array = PackedVector2Array([
	Vector2(32, 24), Vector2(44, 32), Vector2(54, 34),
])
@export var attack_hit2_hitbox_offsets_x: PackedFloat32Array = PackedFloat32Array([20.0, 30.0, 38.0])

## Hit 3: FINALIZADOR — mais dano/knockback/hitbox, juice mais forte (ver player.gd).
@export var attack_hit3_damage_mult: float = 2.0
@export var attack_hit3_knockback: Vector2 = Vector2(340.0, -160.0)
@export var attack_hit3_startup: float = 0.08
@export var attack_hit3_active: float = 0.16
@export var attack_hit3_recovery: float = 0.24
@export var attack_hit3_hitbox_size: Vector2 = Vector2(66.0, 40.0)
@export var attack_hit3_hitbox_offset_x: float = 34.0
@export var attack_hit3_hitbox_sizes: PackedVector2Array = PackedVector2Array([
	Vector2(42, 30), Vector2(66, 40), Vector2(80, 46),
])
@export var attack_hit3_hitbox_offsets_x: PackedFloat32Array = PackedFloat32Array([22.0, 34.0, 44.0])

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
@export var skill_1_hitbox_sizes: PackedVector2Array = PackedVector2Array([
	Vector2(48, 32), Vector2(68, 40), Vector2(80, 44),
])
@export var skill_1_hitbox_offsets_x: PackedFloat32Array = PackedFloat32Array([24.0, 36.0, 46.0])

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
@export var skill_2_hitbox_sizes: PackedVector2Array = PackedVector2Array([
	Vector2(40, 26), Vector2(52, 32), Vector2(64, 34),
])
@export var skill_2_hitbox_offsets_x: PackedFloat32Array = PackedFloat32Array([22.0, 34.0, 42.0])

# --- Ultimate (consome barra de respira├º├úo) ---
@export var ultimate_damage: int = 25
@export var ultimate_knockback: Vector2 = Vector2(320.0, -120.0)
@export var ultimate_startup: float = 0.10
@export var ultimate_active: float = 0.25
@export var ultimate_recovery: float = 0.30
@export var ultimate_iframes: float = 0.40
@export var ultimate_hitbox_size: Vector2 = Vector2(72.0, 48.0)
@export var ultimate_hitbox_offset_x: float = 36.0
@export var ultimate_hitbox_sizes: PackedVector2Array = PackedVector2Array([
	Vector2(56, 40), Vector2(84, 52), Vector2(96, 56),
])
@export var ultimate_hitbox_offsets_x: PackedFloat32Array = PackedFloat32Array([26.0, 40.0, 52.0])
## Breath ganho por hit que acerta (via Game.add_breath_from_hit).
@export var breath_per_hit: float = 10.0
