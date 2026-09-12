# -*- coding: utf-8 -*-
"""Kits únicos + ícones de skill por caçador + frames de skill tintados.

Não toca run/00. Sem rip oficial. PNG real (89 50 4E 47). Chroma #FF00FF limpo.
"""
from __future__ import annotations

import math
import struct
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

import gen_touch_icons as T

ROOT = Path(__file__).resolve().parents[1]
KITS_DIR = ROOT / "resources/player/kits"
ICONS_DIR = ROOT / "assets/ui/touch/icons"
CHARS = ROOT / "assets/characters"

PNG_MAGIC = b"\x89PNG\r\n\x1a\n"

# id -> (display accent RGB, combat dir relative to assets/characters)
HUNTERS: list[dict] = [
    {"id": "tanjiro", "accent": (166, 28, 40), "combat": "player/combat"},
    {"id": "nezuko", "accent": (196, 72, 118), "combat": "nezuko/combat"},
    {"id": "zenitsu", "accent": (214, 186, 36), "combat": "zenitsu/combat"},
    {"id": "inosuke", "accent": (56, 132, 78), "combat": "inosuke/combat"},
    {"id": "kanao", "accent": (214, 140, 186), "combat": "kanao/combat"},
    {"id": "shinobu", "accent": (128, 96, 196), "combat": "shinobu/combat"},
    {"id": "uzui", "accent": (214, 164, 48), "combat": "uzui/combat"},
    {"id": "rengoku", "accent": (214, 92, 32), "combat": "rengoku/combat"},
    {"id": "tomioka", "accent": (48, 110, 186), "combat": "tomioka/combat"},
    {"id": "obanai", "accent": (72, 168, 88), "combat": "obanai/combat"},
    {"id": "tokito", "accent": (140, 164, 206), "combat": "tokito/combat"},
    {"id": "sanemi", "accent": (88, 168, 72), "combat": "sanemi/combat"},
    {"id": "gyomei", "accent": (132, 120, 96), "combat": "gyomei/combat"},
    {"id": "yoriichi", "accent": (214, 168, 40), "combat": "yoriichi/combat"},
    {"id": "muzan", "accent": (168, 40, 56), "combat": "muzan/combat"},
]

# Números TODOS distintos (fingerprint smoke). Tanjiro shop: s1=14 ult=32 hp=100.
KITS: dict[str, dict] = {
    "tanjiro": {
        "path": ROOT / "resources/player/player_stats.tres",
        "body": """move_speed = 280.0
jump_velocity = -460.0
gravity = 1500.0
max_fall_speed = 980.0
coyote_time = 0.14
move_accel = 3400.0
move_friction = 4200.0
input_buffer = 0.12
attack_cancel_ratio = 0.45
dash_speed = 620.0
dash_duration = 0.15
dash_cooldown = 0.70
attack_step_speed = 110.0
attack_lunge_y = 0.0
max_hp = 100
hurt_stun = 0.16
hurt_invuln = 0.5
hurt_friction = 1600.0
attack_damage = 8
attack_knockback = Vector2(200, -80)
attack_startup = 0.04
attack_active = 0.14
attack_recovery = 0.09
attack_hitbox_size = Vector2(52, 34)
attack_hitbox_offset_x = 32.0
attack_hitbox_sizes = PackedVector2Array(36, 26, 52, 34, 62, 36)
attack_hitbox_offsets_x = PackedFloat32Array(18, 32, 40)
attack_hit2_hitbox_sizes = PackedVector2Array(32, 24, 44, 32, 54, 34)
attack_hit2_hitbox_offsets_x = PackedFloat32Array(20, 30, 38)
attack_hit3_hitbox_sizes = PackedVector2Array(42, 30, 66, 40, 80, 46)
attack_hit3_hitbox_offsets_x = PackedFloat32Array(22, 34, 44)
skill_1_display_name = "Corte em Arco"
skill_1_damage = 14
skill_1_knockback = Vector2(240, -100)
skill_1_cooldown = 3.2
skill_1_startup = 0.06
skill_1_active = 0.16
skill_1_recovery = 0.14
skill_1_hitbox_size = Vector2(68, 40)
skill_1_hitbox_offset_x = 36.0
skill_1_hitbox_sizes = PackedVector2Array(48, 32, 68, 40, 80, 44)
skill_1_hitbox_offsets_x = PackedFloat32Array(24, 36, 46)
skill_1_lunge_speed = 0.0
skill_1_lunge_y = 0.0
skill_1_hit_count = 1
skill_1_vfx_tint = Color(0.36, 0.55, 0.94, 1)
skill_2_display_name = "Investida"
skill_2_damage = 12
skill_2_knockback = Vector2(300, -50)
skill_2_cooldown = 4.0
skill_2_startup = 0.04
skill_2_active = 0.18
skill_2_recovery = 0.1
skill_2_lunge_speed = 540.0
skill_2_lunge_y = 0.0
skill_2_hit_count = 1
skill_2_hitbox_size = Vector2(52, 32)
skill_2_hitbox_offset_x = 34.0
skill_2_hitbox_sizes = PackedVector2Array(40, 26, 52, 32, 64, 34)
skill_2_hitbox_offsets_x = PackedFloat32Array(22, 34, 42)
skill_2_vfx_tint = Color(0.31, 0.75, 1.0, 1)
ultimate_damage = 32
ultimate_knockback = Vector2(340, -130)
ultimate_startup = 0.08
ultimate_active = 0.28
ultimate_recovery = 0.22
ultimate_iframes = 0.45
ultimate_hitbox_size = Vector2(84, 52)
ultimate_hitbox_offset_x = 40.0
ultimate_hitbox_sizes = PackedVector2Array(56, 40, 84, 52, 96, 56)
ultimate_hitbox_offsets_x = PackedFloat32Array(26, 40, 52)
ultimate_lunge_speed = 80.0
ultimate_vfx_tint = Color(0.91, 0.72, 0.29, 1)
breath_per_hit = 12.0
lifesteal_ratio = 0.0
""",
    },
    "nezuko": {
        "path": KITS_DIR / "stats_nezuko.tres",
        "body": """move_speed = 268.0
max_hp = 96
dash_speed = 620.0
dash_duration = 0.15
dash_cooldown = 0.70
attack_damage = 7
attack_knockback = Vector2(150, -140)
attack_startup = 0.055
attack_active = 0.12
attack_recovery = 0.11
attack_step_speed = 55.0
attack_lunge_y = -90.0
attack_hitbox_size = Vector2(40, 46)
attack_hitbox_offset_x = 26.0
attack_hitbox_sizes = PackedVector2Array(28, 34, 40, 46, 48, 52)
attack_hitbox_offsets_x = PackedFloat32Array(16, 26, 32)
skill_1_damage = 11
skill_1_knockback = Vector2(150, -160)
skill_1_cooldown = 2.7
skill_1_startup = 0.08
skill_1_active = 0.14
skill_1_recovery = 0.16
skill_1_hitbox_size = Vector2(46, 54)
skill_1_hitbox_offset_x = 28.0
skill_1_hitbox_sizes = PackedVector2Array(32, 40, 46, 54, 54, 60)
skill_1_hitbox_offsets_x = PackedFloat32Array(18, 28, 34)
skill_1_lunge_speed = 40.0
skill_1_lunge_y = -40.0
skill_1_hit_count = 1
skill_1_vfx_tint = Color(1.0, 0.42, 0.62, 1)
skill_2_damage = 9
skill_2_knockback = Vector2(120, -220)
skill_2_cooldown = 3.5
skill_2_startup = 0.07
skill_2_active = 0.2
skill_2_recovery = 0.14
skill_2_lunge_speed = 160.0
skill_2_lunge_y = -380.0
skill_2_hit_count = 1
skill_2_hitbox_size = Vector2(44, 58)
skill_2_hitbox_offset_x = 24.0
skill_2_hitbox_sizes = PackedVector2Array(30, 42, 44, 58, 50, 66)
skill_2_hitbox_offsets_x = PackedFloat32Array(16, 24, 30)
skill_2_vfx_tint = Color(0.95, 0.28, 0.55, 1)
ultimate_damage = 26
ultimate_knockback = Vector2(210, -200)
ultimate_startup = 0.11
ultimate_active = 0.22
ultimate_recovery = 0.2
ultimate_iframes = 0.38
ultimate_hitbox_size = Vector2(70, 72)
ultimate_hitbox_offset_x = 30.0
ultimate_hitbox_sizes = PackedVector2Array(48, 50, 70, 72, 82, 80)
ultimate_hitbox_offsets_x = PackedFloat32Array(20, 30, 38)
ultimate_lunge_speed = 120.0
ultimate_vfx_tint = Color(1.0, 0.55, 0.72, 1)
breath_per_hit = 11.0
lifesteal_ratio = 0.12
""",
    },
    "zenitsu": {
        "path": KITS_DIR / "stats_zenitsu.tres",
        "body": """move_speed = 330.0
max_hp = 85
dash_speed = 740.0
dash_duration = 0.15
dash_cooldown = 0.55
attack_damage = 6
attack_knockback = Vector2(320, -30)
attack_startup = 0.028
attack_active = 0.1
attack_recovery = 0.07
attack_step_speed = 320.0
attack_lunge_y = 0.0
attack_hitbox_size = Vector2(70, 26)
attack_hitbox_offset_x = 38.0
attack_hitbox_sizes = PackedVector2Array(40, 22, 70, 26, 96, 28)
attack_hitbox_offsets_x = PackedFloat32Array(20, 38, 52)
skill_1_damage = 13
skill_1_knockback = Vector2(400, -20)
skill_1_cooldown = 2.3
skill_1_startup = 0.025
skill_1_active = 0.12
skill_1_recovery = 0.1
skill_1_hitbox_size = Vector2(96, 24)
skill_1_hitbox_offset_x = 48.0
skill_1_hitbox_sizes = PackedVector2Array(56, 20, 96, 24, 118, 26)
skill_1_hitbox_offsets_x = PackedFloat32Array(28, 48, 62)
skill_1_lunge_speed = 880.0
skill_1_lunge_y = 0.0
skill_1_hit_count = 1
skill_1_vfx_tint = Color(1.0, 0.92, 0.22, 1)
skill_2_damage = 15
skill_2_knockback = Vector2(420, -10)
skill_2_cooldown = 2.5
skill_2_startup = 0.02
skill_2_active = 0.16
skill_2_recovery = 0.08
skill_2_lunge_speed = 940.0
skill_2_lunge_y = 0.0
skill_2_hit_count = 1
skill_2_hitbox_size = Vector2(88, 22)
skill_2_hitbox_offset_x = 50.0
skill_2_hitbox_sizes = PackedVector2Array(50, 18, 88, 22, 110, 24)
skill_2_hitbox_offsets_x = PackedFloat32Array(30, 50, 64)
skill_2_vfx_tint = Color(0.95, 0.82, 0.12, 1)
ultimate_damage = 34
ultimate_knockback = Vector2(460, -40)
ultimate_startup = 0.03
ultimate_active = 0.16
ultimate_recovery = 0.1
ultimate_iframes = 0.5
ultimate_hitbox_size = Vector2(100, 30)
ultimate_hitbox_offset_x = 54.0
ultimate_hitbox_sizes = PackedVector2Array(60, 24, 100, 30, 124, 32)
ultimate_hitbox_offsets_x = PackedFloat32Array(32, 54, 70)
ultimate_lunge_speed = 720.0
ultimate_vfx_tint = Color(1.0, 0.98, 0.45, 1)
breath_per_hit = 13.0
lifesteal_ratio = 0.0
""",
    },
    "inosuke": {
        "path": KITS_DIR / "stats_inosuke.tres",
        "body": """move_speed = 270.0
max_hp = 115
dash_speed = 620.0
dash_duration = 0.15
dash_cooldown = 0.70
attack_damage = 10
attack_knockback = Vector2(210, -70)
attack_startup = 0.048
attack_active = 0.16
attack_recovery = 0.06
attack_step_speed = 175.0
attack_lunge_y = 0.0
attack_hitbox_size = Vector2(72, 42)
attack_hitbox_offset_x = 34.0
attack_hitbox_sizes = PackedVector2Array(48, 30, 72, 42, 86, 46)
attack_hitbox_offsets_x = PackedFloat32Array(20, 34, 44)
skill_1_damage = 8
skill_1_knockback = Vector2(190, -80)
skill_1_cooldown = 3.6
skill_1_startup = 0.052
skill_1_active = 0.22
skill_1_recovery = 0.12
skill_1_hitbox_size = Vector2(82, 46)
skill_1_hitbox_offset_x = 36.0
skill_1_hitbox_sizes = PackedVector2Array(54, 34, 82, 46, 96, 50)
skill_1_hitbox_offsets_x = PackedFloat32Array(22, 36, 46)
skill_1_lunge_speed = 140.0
skill_1_lunge_y = 0.0
skill_1_hit_count = 2
skill_1_vfx_tint = Color(0.42, 0.82, 0.48, 1)
skill_2_damage = 16
skill_2_knockback = Vector2(280, -40)
skill_2_cooldown = 4.5
skill_2_startup = 0.06
skill_2_active = 0.2
skill_2_recovery = 0.12
skill_2_lunge_speed = 630.0
skill_2_lunge_y = 0.0
skill_2_hit_count = 1
skill_2_hitbox_size = Vector2(78, 40)
skill_2_hitbox_offset_x = 38.0
skill_2_hitbox_sizes = PackedVector2Array(50, 28, 78, 40, 92, 44)
skill_2_hitbox_offsets_x = PackedFloat32Array(24, 38, 48)
skill_2_vfx_tint = Color(0.28, 0.7, 0.4, 1)
ultimate_damage = 36
ultimate_knockback = Vector2(360, -90)
ultimate_startup = 0.09
ultimate_active = 0.26
ultimate_recovery = 0.18
ultimate_iframes = 0.42
ultimate_hitbox_size = Vector2(90, 50)
ultimate_hitbox_offset_x = 42.0
ultimate_hitbox_sizes = PackedVector2Array(60, 36, 90, 50, 108, 56)
ultimate_hitbox_offsets_x = PackedFloat32Array(26, 42, 54)
ultimate_lunge_speed = 200.0
ultimate_vfx_tint = Color(0.55, 0.95, 0.6, 1)
breath_per_hit = 10.0
hurt_stun = 0.12
lifesteal_ratio = 0.0
""",
    },
    "kanao": {
        "path": KITS_DIR / "stats_kanao.tres",
        "body": """move_speed = 305.0
max_hp = 90
dash_speed = 620.0
dash_duration = 0.15
dash_cooldown = 0.62
attack_damage = 9
attack_knockback = Vector2(170, -95)
attack_startup = 0.026
attack_active = 0.09
attack_recovery = 0.075
attack_step_speed = 88.0
attack_lunge_y = 0.0
attack_hitbox_size = Vector2(46, 30)
attack_hitbox_offset_x = 30.0
attack_hitbox_sizes = PackedVector2Array(30, 22, 46, 30, 56, 32)
attack_hitbox_offsets_x = PackedFloat32Array(16, 30, 38)
skill_1_damage = 12
skill_1_knockback = Vector2(165, -115)
skill_1_cooldown = 2.55
skill_1_startup = 0.038
skill_1_active = 0.13
skill_1_recovery = 0.12
skill_1_hitbox_size = Vector2(52, 32)
skill_1_hitbox_offset_x = 32.0
skill_1_hitbox_sizes = PackedVector2Array(34, 24, 52, 32, 62, 34)
skill_1_hitbox_offsets_x = PackedFloat32Array(18, 32, 40)
skill_1_lunge_speed = 60.0
skill_1_lunge_y = 0.0
skill_1_hit_count = 1
skill_1_vfx_tint = Color(0.95, 0.62, 0.88, 1)
skill_2_damage = 10
skill_2_knockback = Vector2(200, -70)
skill_2_cooldown = 3.75
skill_2_startup = 0.045
skill_2_active = 0.15
skill_2_recovery = 0.11
skill_2_lunge_speed = 470.0
skill_2_lunge_y = 0.0
skill_2_hit_count = 1
skill_2_hitbox_size = Vector2(50, 30)
skill_2_hitbox_offset_x = 33.0
skill_2_hitbox_sizes = PackedVector2Array(32, 22, 50, 30, 60, 32)
skill_2_hitbox_offsets_x = PackedFloat32Array(20, 33, 41)
skill_2_vfx_tint = Color(0.88, 0.5, 0.8, 1)
ultimate_damage = 29
ultimate_knockback = Vector2(280, -110)
ultimate_startup = 0.07
ultimate_active = 0.2
ultimate_recovery = 0.16
ultimate_iframes = 0.36
ultimate_hitbox_size = Vector2(62, 38)
ultimate_hitbox_offset_x = 34.0
ultimate_hitbox_sizes = PackedVector2Array(40, 28, 62, 38, 74, 42)
ultimate_hitbox_offsets_x = PackedFloat32Array(22, 34, 44)
ultimate_lunge_speed = 90.0
ultimate_vfx_tint = Color(1.0, 0.75, 0.92, 1)
breath_per_hit = 12.5
lifesteal_ratio = 0.0
""",
    },
    "shinobu": {
        "path": KITS_DIR / "stats_shinobu.tres",
        "body": """move_speed = 315.0
max_hp = 80
dash_speed = 620.0
dash_duration = 0.15
dash_cooldown = 0.70
attack_damage = 5
attack_knockback = Vector2(110, -40)
attack_startup = 0.022
attack_active = 0.08
attack_recovery = 0.08
attack_step_speed = 35.0
attack_lunge_y = 0.0
attack_hitbox_size = Vector2(24, 16)
attack_hitbox_offset_x = 58.0
attack_hitbox_sizes = PackedVector2Array(16, 12, 24, 16, 30, 16)
attack_hitbox_offsets_x = PackedFloat32Array(44, 58, 70)
skill_1_damage = 7
skill_1_knockback = Vector2(110, -25)
skill_1_cooldown = 1.9
skill_1_startup = 0.02
skill_1_active = 0.1
skill_1_recovery = 0.1
skill_1_hitbox_size = Vector2(20, 14)
skill_1_hitbox_offset_x = 66.0
skill_1_hitbox_sizes = PackedVector2Array(14, 12, 20, 14, 26, 14)
skill_1_hitbox_offsets_x = PackedFloat32Array(50, 66, 78)
skill_1_lunge_speed = 20.0
skill_1_lunge_y = 0.0
skill_1_hit_count = 1
skill_1_vfx_tint = Color(0.62, 0.42, 0.95, 1)
skill_2_damage = 9
skill_2_knockback = Vector2(140, -30)
skill_2_cooldown = 3.15
skill_2_startup = 0.03
skill_2_active = 0.14
skill_2_recovery = 0.1
skill_2_lunge_speed = 340.0
skill_2_lunge_y = 0.0
skill_2_hit_count = 1
skill_2_hitbox_size = Vector2(22, 14)
skill_2_hitbox_offset_x = 62.0
skill_2_hitbox_sizes = PackedVector2Array(16, 12, 22, 14, 28, 14)
skill_2_hitbox_offsets_x = PackedFloat32Array(48, 62, 74)
skill_2_vfx_tint = Color(0.72, 0.55, 1.0, 1)
ultimate_damage = 23
ultimate_knockback = Vector2(180, -50)
ultimate_startup = 0.05
ultimate_active = 0.18
ultimate_recovery = 0.14
ultimate_iframes = 0.32
ultimate_hitbox_size = Vector2(28, 16)
ultimate_hitbox_offset_x = 74.0
ultimate_hitbox_sizes = PackedVector2Array(18, 12, 28, 16, 36, 16)
ultimate_hitbox_offsets_x = PackedFloat32Array(56, 74, 86)
ultimate_lunge_speed = 40.0
ultimate_vfx_tint = Color(0.55, 0.28, 0.85, 1)
breath_per_hit = 14.0
lifesteal_ratio = 0.0
""",
    },
    "uzui": {
        "path": KITS_DIR / "stats_uzui.tres",
        "body": """move_speed = 335.0
max_hp = 95
dash_speed = 700.0
dash_duration = 0.15
dash_cooldown = 0.70
attack_damage = 9
attack_knockback = Vector2(230, -55)
attack_startup = 0.034
attack_active = 0.13
attack_recovery = 0.1
attack_step_speed = 210.0
attack_lunge_y = 0.0
attack_hitbox_size = Vector2(58, 36)
attack_hitbox_offset_x = 33.0
attack_hitbox_sizes = PackedVector2Array(38, 26, 58, 36, 70, 38)
attack_hitbox_offsets_x = PackedFloat32Array(18, 33, 42)
skill_1_damage = 15
skill_1_knockback = Vector2(270, -65)
skill_1_cooldown = 3.35
skill_1_startup = 0.048
skill_1_active = 0.15
skill_1_recovery = 0.13
skill_1_hitbox_size = Vector2(64, 38)
skill_1_hitbox_offset_x = 35.0
skill_1_hitbox_sizes = PackedVector2Array(42, 28, 64, 38, 76, 40)
skill_1_hitbox_offsets_x = PackedFloat32Array(20, 35, 44)
skill_1_lunge_speed = 90.0
skill_1_lunge_y = 0.0
skill_1_hit_count = 1
skill_1_vfx_tint = Color(1.0, 0.78, 0.22, 1)
skill_2_damage = 13
skill_2_knockback = Vector2(250, -45)
skill_2_cooldown = 3.65
skill_2_startup = 0.04
skill_2_active = 0.17
skill_2_recovery = 0.11
skill_2_lunge_speed = 720.0
skill_2_lunge_y = 0.0
skill_2_hit_count = 2
skill_2_hitbox_size = Vector2(60, 34)
skill_2_hitbox_offset_x = 36.0
skill_2_hitbox_sizes = PackedVector2Array(40, 24, 60, 34, 74, 36)
skill_2_hitbox_offsets_x = PackedFloat32Array(22, 36, 46)
skill_2_vfx_tint = Color(0.95, 0.65, 0.15, 1)
ultimate_damage = 35
ultimate_knockback = Vector2(330, -80)
ultimate_startup = 0.06
ultimate_active = 0.24
ultimate_recovery = 0.17
ultimate_iframes = 0.4
ultimate_hitbox_size = Vector2(76, 44)
ultimate_hitbox_offset_x = 38.0
ultimate_hitbox_sizes = PackedVector2Array(50, 32, 76, 44, 90, 48)
ultimate_hitbox_offsets_x = PackedFloat32Array(24, 38, 50)
ultimate_lunge_speed = 160.0
ultimate_vfx_tint = Color(1.0, 0.88, 0.35, 1)
breath_per_hit = 11.5
lifesteal_ratio = 0.0
""",
    },
    "rengoku": {
        "path": KITS_DIR / "stats_rengoku.tres",
        "body": """move_speed = 250.0
max_hp = 120
dash_speed = 620.0
dash_duration = 0.15
dash_cooldown = 0.70
attack_damage = 12
attack_knockback = Vector2(250, -100)
attack_startup = 0.058
attack_active = 0.15
attack_recovery = 0.12
attack_step_speed = 145.0
attack_lunge_y = 0.0
attack_hitbox_size = Vector2(60, 38)
attack_hitbox_offset_x = 34.0
attack_hitbox_sizes = PackedVector2Array(40, 28, 60, 38, 74, 42)
attack_hitbox_offsets_x = PackedFloat32Array(20, 34, 44)
skill_1_damage = 18
skill_1_knockback = Vector2(310, -125)
skill_1_cooldown = 3.85
skill_1_startup = 0.082
skill_1_active = 0.18
skill_1_recovery = 0.15
skill_1_hitbox_size = Vector2(76, 48)
skill_1_hitbox_offset_x = 38.0
skill_1_hitbox_sizes = PackedVector2Array(50, 34, 76, 48, 90, 52)
skill_1_hitbox_offsets_x = PackedFloat32Array(24, 38, 48)
skill_1_lunge_speed = 70.0
skill_1_lunge_y = 0.0
skill_1_hit_count = 1
skill_1_vfx_tint = Color(1.0, 0.42, 0.12, 1)
skill_2_damage = 14
skill_2_knockback = Vector2(290, -60)
skill_2_cooldown = 4.65
skill_2_startup = 0.055
skill_2_active = 0.19
skill_2_recovery = 0.13
skill_2_lunge_speed = 590.0
skill_2_lunge_y = 0.0
skill_2_hit_count = 1
skill_2_hitbox_size = Vector2(66, 40)
skill_2_hitbox_offset_x = 36.0
skill_2_hitbox_sizes = PackedVector2Array(44, 28, 66, 40, 80, 44)
skill_2_hitbox_offsets_x = PackedFloat32Array(22, 36, 46)
skill_2_vfx_tint = Color(1.0, 0.55, 0.18, 1)
ultimate_damage = 44
ultimate_knockback = Vector2(380, -140)
ultimate_startup = 0.1
ultimate_active = 0.3
ultimate_recovery = 0.24
ultimate_iframes = 0.48
ultimate_hitbox_size = Vector2(98, 58)
ultimate_hitbox_offset_x = 44.0
ultimate_hitbox_sizes = PackedVector2Array(64, 40, 98, 58, 114, 64)
ultimate_hitbox_offsets_x = PackedFloat32Array(28, 44, 56)
ultimate_lunge_speed = 110.0
ultimate_vfx_tint = Color(1.0, 0.72, 0.2, 1)
breath_per_hit = 12.0
lifesteal_ratio = 0.0
""",
    },
    "tomioka": {
        "path": KITS_DIR / "stats_tomioka.tres",
        "body": """move_speed = 285.0
max_hp = 108
dash_speed = 620.0
dash_duration = 0.15
dash_cooldown = 0.70
attack_damage = 10
attack_knockback = Vector2(190, -85)
attack_startup = 0.052
attack_active = 0.13
attack_recovery = 0.1
attack_step_speed = 78.0
attack_lunge_y = 0.0
attack_hitbox_size = Vector2(56, 36)
attack_hitbox_offset_x = 34.0
attack_hitbox_sizes = PackedVector2Array(36, 26, 56, 36, 68, 38)
attack_hitbox_offsets_x = PackedFloat32Array(18, 34, 42)
skill_1_damage = 16
skill_1_knockback = Vector2(225, -95)
skill_1_cooldown = 3.25
skill_1_startup = 0.068
skill_1_active = 0.17
skill_1_recovery = 0.14
skill_1_hitbox_size = Vector2(78, 42)
skill_1_hitbox_offset_x = 40.0
skill_1_hitbox_sizes = PackedVector2Array(50, 30, 78, 42, 92, 46)
skill_1_hitbox_offsets_x = PackedFloat32Array(24, 40, 50)
skill_1_lunge_speed = 30.0
skill_1_lunge_y = 0.0
skill_1_hit_count = 1
skill_1_vfx_tint = Color(0.28, 0.55, 0.95, 1)
skill_2_damage = 12
skill_2_knockback = Vector2(240, -55)
skill_2_cooldown = 4.85
skill_2_startup = 0.05
skill_2_active = 0.2
skill_2_recovery = 0.12
skill_2_lunge_speed = 390.0
skill_2_lunge_y = 0.0
skill_2_hit_count = 1
skill_2_hitbox_size = Vector2(64, 36)
skill_2_hitbox_offset_x = 36.0
skill_2_hitbox_sizes = PackedVector2Array(42, 26, 64, 36, 76, 38)
skill_2_hitbox_offsets_x = PackedFloat32Array(22, 36, 46)
skill_2_vfx_tint = Color(0.2, 0.7, 1.0, 1)
ultimate_damage = 40
ultimate_knockback = Vector2(300, -100)
ultimate_startup = 0.09
ultimate_active = 0.26
ultimate_recovery = 0.2
ultimate_iframes = 0.44
ultimate_hitbox_size = Vector2(80, 48)
ultimate_hitbox_offset_x = 42.0
ultimate_hitbox_sizes = PackedVector2Array(52, 34, 80, 48, 96, 52)
ultimate_hitbox_offsets_x = PackedFloat32Array(26, 42, 54)
ultimate_lunge_speed = 50.0
ultimate_vfx_tint = Color(0.45, 0.82, 1.0, 1)
breath_per_hit = 12.0
lifesteal_ratio = 0.0
""",
    },
    "obanai": {
        "path": KITS_DIR / "stats_obanai.tres",
        "body": """move_speed = 290.0
max_hp = 95
dash_speed = 620.0
dash_duration = 0.15
dash_cooldown = 0.70
attack_damage = 11
attack_knockback = Vector2(180, -60)
attack_startup = 0.046
attack_active = 0.11
attack_recovery = 0.1
attack_step_speed = 52.0
attack_lunge_y = 0.0
attack_hitbox_size = Vector2(74, 26)
attack_hitbox_offset_x = 44.0
attack_hitbox_sizes = PackedVector2Array(48, 20, 74, 26, 90, 26)
attack_hitbox_offsets_x = PackedFloat32Array(28, 44, 56)
skill_1_damage = 16
skill_1_knockback = Vector2(185, -50)
skill_1_cooldown = 3.05
skill_1_startup = 0.058
skill_1_active = 0.15
skill_1_recovery = 0.13
skill_1_hitbox_size = Vector2(88, 28)
skill_1_hitbox_offset_x = 50.0
skill_1_hitbox_sizes = PackedVector2Array(56, 20, 88, 28, 104, 28)
skill_1_hitbox_offsets_x = PackedFloat32Array(32, 50, 64)
skill_1_lunge_speed = 25.0
skill_1_lunge_y = 0.0
skill_1_hit_count = 1
skill_1_vfx_tint = Color(0.35, 0.85, 0.45, 1)
skill_2_damage = 13
skill_2_knockback = Vector2(220, -40)
skill_2_cooldown = 4.15
skill_2_startup = 0.05
skill_2_active = 0.18
skill_2_recovery = 0.12
skill_2_lunge_speed = 430.0
skill_2_lunge_y = 0.0
skill_2_hit_count = 1
skill_2_hitbox_size = Vector2(80, 26)
skill_2_hitbox_offset_x = 48.0
skill_2_hitbox_sizes = PackedVector2Array(52, 20, 80, 26, 96, 26)
skill_2_hitbox_offsets_x = PackedFloat32Array(30, 48, 60)
skill_2_vfx_tint = Color(0.2, 0.75, 0.4, 1)
ultimate_damage = 39
ultimate_knockback = Vector2(310, -70)
ultimate_startup = 0.085
ultimate_active = 0.24
ultimate_recovery = 0.19
ultimate_iframes = 0.4
ultimate_hitbox_size = Vector2(92, 30)
ultimate_hitbox_offset_x = 54.0
ultimate_hitbox_sizes = PackedVector2Array(60, 22, 92, 30, 110, 30)
ultimate_hitbox_offsets_x = PackedFloat32Array(34, 54, 68)
ultimate_lunge_speed = 70.0
ultimate_vfx_tint = Color(0.5, 0.95, 0.55, 1)
breath_per_hit = 12.0
lifesteal_ratio = 0.0
""",
    },
    "tokito": {
        "path": KITS_DIR / "stats_tokito.tres",
        "body": """move_speed = 345.0
max_hp = 75
dash_speed = 720.0
dash_duration = 0.15
dash_cooldown = 0.48
attack_damage = 8
attack_knockback = Vector2(160, -75)
attack_startup = 0.018
attack_active = 0.085
attack_recovery = 0.065
attack_step_speed = 250.0
attack_lunge_y = 0.0
attack_hitbox_size = Vector2(42, 30)
attack_hitbox_offset_x = 28.0
attack_hitbox_sizes = PackedVector2Array(26, 22, 42, 30, 52, 32)
attack_hitbox_offsets_x = PackedFloat32Array(14, 28, 36)
skill_1_damage = 14
skill_1_knockback = Vector2(145, -85)
skill_1_cooldown = 2.15
skill_1_startup = 0.028
skill_1_active = 0.12
skill_1_recovery = 0.1
skill_1_hitbox_size = Vector2(48, 32)
skill_1_hitbox_offset_x = 30.0
skill_1_hitbox_sizes = PackedVector2Array(30, 24, 48, 32, 58, 34)
skill_1_hitbox_offsets_x = PackedFloat32Array(16, 30, 38)
skill_1_lunge_speed = 180.0
skill_1_lunge_y = 0.0
skill_1_hit_count = 1
skill_1_vfx_tint = Color(0.72, 0.82, 1.0, 1)
skill_2_damage = 11
skill_2_knockback = Vector2(200, -40)
skill_2_cooldown = 2.85
skill_2_startup = 0.03
skill_2_active = 0.14
skill_2_recovery = 0.09
skill_2_lunge_speed = 810.0
skill_2_lunge_y = 0.0
skill_2_hit_count = 1
skill_2_hitbox_size = Vector2(46, 28)
skill_2_hitbox_offset_x = 32.0
skill_2_hitbox_sizes = PackedVector2Array(28, 20, 46, 28, 58, 30)
skill_2_hitbox_offsets_x = PackedFloat32Array(18, 32, 42)
skill_2_vfx_tint = Color(0.6, 0.72, 0.95, 1)
ultimate_damage = 38
ultimate_knockback = Vector2(270, -90)
ultimate_startup = 0.055
ultimate_active = 0.2
ultimate_recovery = 0.14
ultimate_iframes = 0.6
ultimate_hitbox_size = Vector2(68, 40)
ultimate_hitbox_offset_x = 36.0
ultimate_hitbox_sizes = PackedVector2Array(44, 28, 68, 40, 82, 44)
ultimate_hitbox_offsets_x = PackedFloat32Array(22, 36, 46)
ultimate_lunge_speed = 240.0
ultimate_vfx_tint = Color(0.85, 0.9, 1.0, 1)
breath_per_hit = 13.5
hurt_invuln = 0.6
lifesteal_ratio = 0.0
""",
    },
    "sanemi": {
        "path": KITS_DIR / "stats_sanemi.tres",
        "body": """move_speed = 295.0
max_hp = 100
dash_speed = 620.0
dash_duration = 0.15
dash_cooldown = 0.70
attack_damage = 13
attack_knockback = Vector2(260, -50)
attack_startup = 0.036
attack_active = 0.12
attack_recovery = 0.07
attack_step_speed = 195.0
attack_lunge_y = 0.0
attack_hitbox_size = Vector2(64, 36)
attack_hitbox_offset_x = 34.0
attack_hitbox_sizes = PackedVector2Array(42, 26, 64, 36, 78, 38)
attack_hitbox_offsets_x = PackedFloat32Array(20, 34, 44)
skill_1_damage = 17
skill_1_knockback = Vector2(330, -55)
skill_1_cooldown = 2.85
skill_1_startup = 0.042
skill_1_active = 0.14
skill_1_recovery = 0.11
skill_1_hitbox_size = Vector2(72, 40)
skill_1_hitbox_offset_x = 36.0
skill_1_hitbox_sizes = PackedVector2Array(46, 28, 72, 40, 86, 42)
skill_1_hitbox_offsets_x = PackedFloat32Array(22, 36, 46)
skill_1_lunge_speed = 100.0
skill_1_lunge_y = 0.0
skill_1_hit_count = 1
skill_1_vfx_tint = Color(0.55, 0.95, 0.4, 1)
skill_2_damage = 15
skill_2_knockback = Vector2(310, -35)
skill_2_cooldown = 3.85
skill_2_startup = 0.038
skill_2_active = 0.16
skill_2_recovery = 0.1
skill_2_lunge_speed = 670.0
skill_2_lunge_y = 0.0
skill_2_hit_count = 1
skill_2_hitbox_size = Vector2(68, 34)
skill_2_hitbox_offset_x = 37.0
skill_2_hitbox_sizes = PackedVector2Array(44, 24, 68, 34, 82, 36)
skill_2_hitbox_offsets_x = PackedFloat32Array(23, 37, 47)
skill_2_vfx_tint = Color(0.4, 0.85, 0.3, 1)
ultimate_damage = 42
ultimate_knockback = Vector2(370, -80)
ultimate_startup = 0.07
ultimate_active = 0.22
ultimate_recovery = 0.16
ultimate_iframes = 0.38
ultimate_hitbox_size = Vector2(86, 48)
ultimate_hitbox_offset_x = 40.0
ultimate_hitbox_sizes = PackedVector2Array(56, 34, 86, 48, 102, 52)
ultimate_hitbox_offsets_x = PackedFloat32Array(26, 40, 52)
ultimate_lunge_speed = 150.0
ultimate_vfx_tint = Color(0.7, 1.0, 0.5, 1)
breath_per_hit = 12.0
lifesteal_ratio = 0.0
""",
    },
    "gyomei": {
        "path": KITS_DIR / "stats_gyomei.tres",
        "body": """move_speed = 195.0
max_hp = 155
dash_speed = 460.0
dash_duration = 0.12
dash_cooldown = 0.70
attack_damage = 15
attack_knockback = Vector2(340, -150)
attack_startup = 0.085
attack_active = 0.2
attack_recovery = 0.18
attack_step_speed = 22.0
attack_lunge_y = 0.0
attack_hitbox_size = Vector2(96, 58)
attack_hitbox_offset_x = 40.0
attack_hitbox_sizes = PackedVector2Array(64, 42, 96, 58, 118, 66)
attack_hitbox_offsets_x = PackedFloat32Array(24, 40, 54)
skill_1_damage = 22
skill_1_knockback = Vector2(370, -170)
skill_1_cooldown = 5.4
skill_1_startup = 0.14
skill_1_active = 0.22
skill_1_recovery = 0.2
skill_1_hitbox_size = Vector2(118, 70)
skill_1_hitbox_offset_x = 46.0
skill_1_hitbox_sizes = PackedVector2Array(78, 50, 118, 70, 140, 78)
skill_1_hitbox_offsets_x = PackedFloat32Array(28, 46, 60)
skill_1_lunge_speed = 10.0
skill_1_lunge_y = 0.0
skill_1_hit_count = 1
skill_1_vfx_tint = Color(0.7, 0.62, 0.45, 1)
skill_2_damage = 18
skill_2_knockback = Vector2(350, -80)
skill_2_cooldown = 5.8
skill_2_startup = 0.1
skill_2_active = 0.24
skill_2_recovery = 0.18
skill_2_lunge_speed = 200.0
skill_2_lunge_y = 0.0
skill_2_hit_count = 1
skill_2_hitbox_size = Vector2(104, 62)
skill_2_hitbox_offset_x = 44.0
skill_2_hitbox_sizes = PackedVector2Array(70, 44, 104, 62, 124, 70)
skill_2_hitbox_offsets_x = PackedFloat32Array(26, 44, 56)
skill_2_vfx_tint = Color(0.55, 0.5, 0.38, 1)
ultimate_damage = 50
ultimate_knockback = Vector2(420, -180)
ultimate_startup = 0.16
ultimate_active = 0.32
ultimate_recovery = 0.28
ultimate_iframes = 0.55
ultimate_hitbox_size = Vector2(132, 80)
ultimate_hitbox_offset_x = 50.0
ultimate_hitbox_sizes = PackedVector2Array(88, 56, 132, 80, 154, 88)
ultimate_hitbox_offsets_x = PackedFloat32Array(30, 50, 66)
ultimate_lunge_speed = 15.0
ultimate_vfx_tint = Color(0.85, 0.78, 0.55, 1)
breath_per_hit = 9.0
lifesteal_ratio = 0.0
""",
    },
    "yoriichi": {
        "path": KITS_DIR / "stats_yoriichi.tres",
        "body": """move_speed = 315.0
max_hp = 130
dash_speed = 620.0
dash_duration = 0.15
dash_cooldown = 0.70
attack_damage = 16
attack_knockback = Vector2(240, -90)
attack_startup = 0.03
attack_active = 0.11
attack_recovery = 0.07
attack_step_speed = 155.0
attack_lunge_y = 0.0
attack_hitbox_size = Vector2(66, 38)
attack_hitbox_offset_x = 35.0
attack_hitbox_sizes = PackedVector2Array(44, 28, 66, 38, 80, 42)
attack_hitbox_offsets_x = PackedFloat32Array(20, 35, 46)
skill_1_damage = 23
skill_1_knockback = Vector2(285, -105)
skill_1_cooldown = 2.45
skill_1_startup = 0.036
skill_1_active = 0.14
skill_1_recovery = 0.11
skill_1_hitbox_size = Vector2(80, 44)
skill_1_hitbox_offset_x = 38.0
skill_1_hitbox_sizes = PackedVector2Array(52, 32, 80, 44, 96, 48)
skill_1_hitbox_offsets_x = PackedFloat32Array(22, 38, 50)
skill_1_lunge_speed = 85.0
skill_1_lunge_y = 0.0
skill_1_hit_count = 1
skill_1_vfx_tint = Color(1.0, 0.82, 0.2, 1)
skill_2_damage = 20
skill_2_knockback = Vector2(270, -70)
skill_2_cooldown = 3.45
skill_2_startup = 0.04
skill_2_active = 0.16
skill_2_recovery = 0.1
skill_2_lunge_speed = 610.0
skill_2_lunge_y = 0.0
skill_2_hit_count = 1
skill_2_hitbox_size = Vector2(74, 40)
skill_2_hitbox_offset_x = 37.0
skill_2_hitbox_sizes = PackedVector2Array(48, 28, 74, 40, 88, 44)
skill_2_hitbox_offsets_x = PackedFloat32Array(22, 37, 48)
skill_2_vfx_tint = Color(1.0, 0.7, 0.15, 1)
ultimate_damage = 58
ultimate_knockback = Vector2(400, -130)
ultimate_startup = 0.05
ultimate_active = 0.24
ultimate_recovery = 0.15
ultimate_iframes = 0.5
ultimate_hitbox_size = Vector2(102, 56)
ultimate_hitbox_offset_x = 44.0
ultimate_hitbox_sizes = PackedVector2Array(66, 38, 102, 56, 120, 62)
ultimate_hitbox_offsets_x = PackedFloat32Array(28, 44, 58)
ultimate_lunge_speed = 130.0
ultimate_vfx_tint = Color(1.0, 0.92, 0.4, 1)
breath_per_hit = 16.0
lifesteal_ratio = 0.0
""",
    },
    "muzan": {
        "path": KITS_DIR / "stats_muzan.tres",
        "body": """move_speed = 255.0
max_hp = 140
dash_speed = 620.0
dash_duration = 0.15
dash_cooldown = 0.70
attack_damage = 11
attack_knockback = Vector2(220, -95)
attack_startup = 0.062
attack_active = 0.15
attack_recovery = 0.13
attack_step_speed = 105.0
attack_lunge_y = 0.0
attack_hitbox_size = Vector2(88, 48)
attack_hitbox_offset_x = 36.0
attack_hitbox_sizes = PackedVector2Array(56, 34, 88, 48, 106, 54)
attack_hitbox_offsets_x = PackedFloat32Array(22, 36, 48)
skill_1_damage = 19
skill_1_knockback = Vector2(255, -90)
skill_1_cooldown = 4.25
skill_1_startup = 0.095
skill_1_active = 0.18
skill_1_recovery = 0.16
skill_1_hitbox_size = Vector2(92, 50)
skill_1_hitbox_offset_x = 38.0
skill_1_hitbox_sizes = PackedVector2Array(60, 36, 92, 50, 110, 56)
skill_1_hitbox_offsets_x = PackedFloat32Array(24, 38, 50)
skill_1_lunge_speed = 45.0
skill_1_lunge_y = 0.0
skill_1_hit_count = 1
skill_1_vfx_tint = Color(0.75, 0.12, 0.22, 1)
skill_2_damage = 17
skill_2_knockback = Vector2(260, -60)
skill_2_cooldown = 4.75
skill_2_startup = 0.07
skill_2_active = 0.2
skill_2_recovery = 0.14
skill_2_lunge_speed = 370.0
skill_2_lunge_y = 0.0
skill_2_hit_count = 1
skill_2_hitbox_size = Vector2(84, 44)
skill_2_hitbox_offset_x = 37.0
skill_2_hitbox_sizes = PackedVector2Array(54, 32, 84, 44, 100, 48)
skill_2_hitbox_offsets_x = PackedFloat32Array(23, 37, 49)
skill_2_vfx_tint = Color(0.45, 0.08, 0.18, 1)
ultimate_damage = 52
ultimate_knockback = Vector2(390, -150)
ultimate_startup = 0.12
ultimate_active = 0.3
ultimate_recovery = 0.26
ultimate_iframes = 0.52
ultimate_hitbox_size = Vector2(112, 64)
ultimate_hitbox_offset_x = 46.0
ultimate_hitbox_sizes = PackedVector2Array(72, 44, 112, 64, 130, 72)
ultimate_hitbox_offsets_x = PackedFloat32Array(28, 46, 60)
ultimate_lunge_speed = 95.0
ultimate_vfx_tint = Color(0.9, 0.2, 0.3, 1)
breath_per_hit = 10.0
lifesteal_ratio = 0.12
""",
    },
}


def _write_tres(path: Path, body: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    text = (
        '[gd_resource type="Resource" script_class="PlayerStats" load_steps=2 format=3]\n\n'
        '[ext_resource type="Script" path="res://scripts/characters/player_stats.gd" id="1_stats"]\n\n'
        "[resource]\n"
        'script = ExtResource("1_stats")\n'
        f"{body}"
    )
    path.write_text(text, encoding="utf-8")


def _assert_png(path: Path) -> None:
    with path.open("rb") as f:
        head = f.read(8)
    if head != PNG_MAGIC:
        raise SystemExit(f"not a real PNG: {path} {head!r}")


def _clean_chroma(im: Image.Image) -> Image.Image:
    im = im.convert("RGBA")
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if r > 180 and b > 180 and g < 130:
                px[x, y] = (0, 0, 0, 0)
    return im


# --- glyphs per hunter (silhueta nítida, sem katana na Nezuko, 2 lâminas no Inosuke) ---
def _g_wave(d: ImageDraw.ImageDraw) -> None:
    T.glyph_skill_1(d)


def _g_dash(d: ImageDraw.ImageDraw) -> None:
    T.glyph_advance(d)


def _g_sun(d: ImageDraw.ImageDraw) -> None:
    T.glyph_ultimate(d)


def _g_kick(d: ImageDraw.ImageDraw) -> None:
    d.polygon([(T.C - 40, 720), (T.C + 200, 420), (T.C + 80, 400), (T.C - 160, 620)], fill=255)
    d.ellipse(T._box(70, T.C + 160, 360), fill=255)


def _g_hop(d: ImageDraw.ImageDraw) -> None:
    T.glyph_jump(d)


def _g_burst(d: ImageDraw.ImageDraw) -> None:
    for i in range(8):
        ang = i * 45.0
        d.polygon(
            [T._polar(ang, 340), T._polar(ang - 10, 160), T._polar(ang + 10, 160)],
            fill=255,
        )
    d.ellipse(T._box(90), fill=255)


def _g_bolt(d: ImageDraw.ImageDraw) -> None:
    d.polygon(
        [(T.C + 40, 180), (T.C - 80, 480), (T.C + 20, 480), (T.C - 60, 840), (T.C + 160, 500), (T.C + 40, 500)],
        fill=255,
    )


def _g_fangs(d: ImageDraw.ImageDraw) -> None:
    d.polygon([(T.C - 180, 280), (T.C - 40, 720), (T.C - 220, 720)], fill=255)
    d.polygon([(T.C + 180, 280), (T.C + 40, 720), (T.C + 220, 720)], fill=255)
    T._rounded_bar(d, T.C - 240, 240, T.C - 40, 300, 20)
    T._rounded_bar(d, T.C + 40, 240, T.C + 240, 300, 20)


def _g_boar(d: ImageDraw.ImageDraw) -> None:
    d.ellipse(T._box(220), fill=255)
    d.polygon([(T.C - 80, 300), (T.C - 200, 120), (T.C - 20, 280)], fill=255)
    d.polygon([(T.C + 80, 300), (T.C + 200, 120), (T.C + 20, 280)], fill=255)


def _g_needle(d: ImageDraw.ImageDraw) -> None:
    d.polygon([(T.C - 20, 200), (T.C + 20, 200), (T.C + 8, 780), (T.C - 8, 780)], fill=255)
    d.ellipse(T._box(36, T.C, 170), fill=255)


def _g_drop(d: ImageDraw.ImageDraw) -> None:
    d.polygon([(T.C, 220), (T.C + 140, 560), (T.C - 140, 560)], fill=255)
    d.ellipse(T._box(140, T.C, 620), fill=255)


def _g_star(d: ImageDraw.ImageDraw) -> None:
    pts = [T._polar(i * 72.0 - 90, 320 if i % 2 == 0 else 140) for i in range(10)]
    d.polygon(pts, fill=255)


def _g_dual(d: ImageDraw.ImageDraw) -> None:
    d.line([(260, 760), (760, 260)], fill=255, width=54)
    d.line([(300, 260), (760, 720)], fill=255, width=54)


def _g_flame(d: ImageDraw.ImageDraw) -> None:
    T.glyph_ultimate_dark(d)
    d.ellipse(T._box(80, T.C, 700), fill=255)


def _g_crescent(d: ImageDraw.ImageDraw) -> None:
    d.ellipse(T._box(280), fill=255)
    d.ellipse(T._box(220, T.C + 80, T.C - 40), fill=0)


def _g_snake(d: ImageDraw.ImageDraw) -> None:
    T._wave_band(d, 200, 820, 420, 90, 280, 70)
    d.ellipse(T._box(40, 800, 380), fill=255)


def _g_mist(d: ImageDraw.ImageDraw) -> None:
    d.ellipse(T._box(160, T.C - 80, T.C), fill=255)
    d.ellipse(T._box(140, T.C + 90, T.C + 40), fill=255)
    d.ellipse(T._box(110, T.C, T.C - 80), fill=255)


def _g_wind(d: ImageDraw.ImageDraw) -> None:
    T._wave_band(d, 180, 840, 360, 40, 360, 50)
    T._wave_band(d, 220, 800, 500, 50, 360, 50)
    T._wave_band(d, 260, 760, 640, 40, 360, 40)


def _g_boulder(d: ImageDraw.ImageDraw) -> None:
    d.polygon([(T.C, 220), (T.C + 260, 520), (T.C + 160, 780), (T.C - 180, 780), (T.C - 260, 500)], fill=255)


def _g_moon(d: ImageDraw.ImageDraw) -> None:
    d.ellipse(T._box(260), fill=255)
    d.ellipse(T._box(200, T.C + 90, T.C - 30), fill=0)


GLYPHS: dict[str, dict[str, T.GlyphFn]] = {
    "tanjiro": {"skill_1": _g_wave, "skill_2": _g_dash, "ultimate": _g_sun},
    "nezuko": {"skill_1": _g_kick, "skill_2": _g_hop, "ultimate": _g_burst},
    "zenitsu": {"skill_1": _g_bolt, "skill_2": T.glyph_advance, "ultimate": _g_sun},
    "inosuke": {"skill_1": _g_fangs, "skill_2": _g_boar, "ultimate": _g_boulder},
    "kanao": {"skill_1": _g_burst, "skill_2": T.glyph_jump, "ultimate": _g_crescent},
    "shinobu": {"skill_1": _g_needle, "skill_2": _g_star, "ultimate": _g_drop},
    "uzui": {"skill_1": _g_star, "skill_2": _g_dual, "ultimate": _g_burst},
    "rengoku": {"skill_1": _g_flame, "skill_2": T.glyph_advance, "ultimate": _g_sun},
    "tomioka": {"skill_1": _g_wave, "skill_2": _g_crescent, "ultimate": T.glyph_skill_2},
    "obanai": {"skill_1": _g_snake, "skill_2": T.glyph_skill_2, "ultimate": _g_wind},
    "tokito": {"skill_1": _g_mist, "skill_2": T.glyph_advance, "ultimate": _g_crescent},
    "sanemi": {"skill_1": _g_wind, "skill_2": T.glyph_attack_basic, "ultimate": _g_burst},
    "gyomei": {"skill_1": _g_boulder, "skill_2": _g_star, "ultimate": _g_boulder},
    "yoriichi": {"skill_1": _g_sun, "skill_2": T.glyph_skill_2, "ultimate": T.glyph_ultimate},
    "muzan": {"skill_1": _g_moon, "skill_2": _g_crescent, "ultimate": _g_star},
}

SKILL_TINTS = {
    "skill_1": (0.72, 0.88, 1.35),
    "skill_2": (1.28, 0.78, 1.18),
    "ultimate": (1.35, 1.18, 0.62),
}


def render_kit_icon(char_id: str, action: str, accent: tuple[int, int, int], pressed: bool) -> Image.Image:
    halo = action == "ultimate"
    img = T._build_shell(accent, pressed, halo)
    fn = GLYPHS[char_id][action]
    light_mask = T._draw_mask(fn)
    if pressed:
        light_mask = T._transform_pressed(light_mask)
    clip = T._circle_mask(T.R_GLYPH_CLIP)
    light_mask = Image.composite(light_mask, T._blank_mask(), clip)
    shadow = light_mask.filter(ImageFilter.GaussianBlur(T.SHADOW_BLUR))
    shadow_layer = Image.new("RGBA", (T.SS, T.SS), (0, 0, 0, 0))
    shadow_layer.paste(T._tinted(shadow, (0, 0, 0), T.SHADOW_ALPHA), T.SHADOW_OFFSET)
    shadow_layer.putalpha(Image.composite(shadow_layer.getchannel("A"), T._blank_mask(), clip))
    img = Image.alpha_composite(img, shadow_layer)
    outline = T._dilate(light_mask, T.OUTLINE_BLUR)
    outline = Image.composite(outline, T._blank_mask(), clip)
    img = Image.alpha_composite(img, T._tinted(outline, T.INK_DARK, 240))
    ink = T.INK_WARM if action == "ultimate" else T.INK_LIGHT
    img = Image.alpha_composite(img, T._tinted(light_mask, ink))
    img.putalpha(Image.composite(img.getchannel("A"), T._blank_mask(), T._circle_mask(T.R_SHELL)))
    return img.resize((T.OUT, T.OUT), Image.Resampling.LANCZOS)


def _tint_frame(src: Path, dst: Path, rgb_mul: tuple[float, float, float]) -> None:
    im = Image.open(src).convert("RGBA")
    im = _clean_chroma(im)
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < 8:
                px[x, y] = (0, 0, 0, 0)
                continue
            px[x, y] = (
                min(255, int(r * rgb_mul[0])),
                min(255, int(g * rgb_mul[1])),
                min(255, int(b * rgb_mul[2])),
                a,
            )
    dst.parent.mkdir(parents=True, exist_ok=True)
    im.save(dst, "PNG")
    _assert_png(dst)


def write_kits() -> int:
    n = 0
    for kid, spec in KITS.items():
        _write_tres(spec["path"], spec["body"])
        n += 1
        print("kit", kid, spec["path"].relative_to(ROOT).as_posix())
    return n


def write_icons() -> int:
    n = 0
    for h in HUNTERS:
        out = ICONS_DIR / h["id"]
        out.mkdir(parents=True, exist_ok=True)
        for action in ("skill_1", "skill_2", "ultimate"):
            for pressed, suffix in ((False, ""), (True, "_pressed")):
                path = out / f"{action}{suffix}.png"
                render_kit_icon(h["id"], action, h["accent"], pressed).save(path, "PNG", optimize=True)
                _assert_png(path)
                n += 1
    print(f"icons {n}")
    return n


def write_skill_frames() -> int:
    n = 0
    for h in HUNTERS:
        attack_dir = CHARS / h["combat"] / "attack"
        if not attack_dir.is_dir():
            print("skip frames", h["id"], "no attack")
            continue
        srcs = sorted(attack_dir.glob("??.png"))
        if not srcs:
            continue
        for skill, mul in SKILL_TINTS.items():
            dest_dir = CHARS / h["combat"] / skill
            for src in srcs:
                dst = dest_dir / src.name
                _tint_frame(src, dst, mul)
                n += 1
    print(f"skill frames {n}")
    return n


def main() -> None:
    kits = write_kits()
    icons = write_icons()
    frames = write_skill_frames()
    print(f"DONE kits={kits} icons={icons} frames={frames}")


if __name__ == "__main__":
    main()
