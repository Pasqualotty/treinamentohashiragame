#!/usr/bin/env python3
"""Gera resources/characters/*.tres e kits de PlayerStats. Rode na raiz do repo."""
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CHARS = ROOT / "resources" / "characters"
KITS = ROOT / "resources" / "player" / "kits"

STATS_HEADER = """[gd_resource type="Resource" script_class="PlayerStats" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/characters/player_stats.gd" id="1_stats"]

[resource]
script = ExtResource("1_stats")
"""

CHAR_TMPL = """[gd_resource type="Resource" script_class="CharacterDef" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/resources/character_def.gd" id="1_def"]

[resource]
script = ExtResource("1_def")
id = "{id}"
display_name = "{display_name}"
unlock_requires = Array[String]([{requires}])
unlock_hint = "{unlock_hint}"
skill_1_name = "{skill_1}"
skill_2_name = "{skill_2}"
ultimate_name = "{ult}"
accent = Color({accent})
stats_path = "{stats_path}"
combat_frames_dir = ""
lifesteal_ratio = {lifesteal}
"""

# Kit numbers: only fields that differ from tanjiro player_stats.tres
KITS_DATA: dict[str, dict] = {
    "zenitsu": {
        "move_speed": 330.0,
        "max_hp": 85,
        "dash_speed": 740.0,
        "dash_cooldown": 0.55,
        "attack_damage": 7,
        "attack_recovery": 0.07,
        "skill_2_lunge_speed": 760.0,
        "skill_2_cooldown": 3.2,
        "ultimate_startup": 0.04,
        "ultimate_active": 0.18,
        "ultimate_recovery": 0.12,
        "ultimate_damage": 28,
    },
    "inosuke": {
        "move_speed": 270.0,
        "max_hp": 115,
        "attack_damage": 10,
        "attack_recovery": 0.06,
        "attack_hitbox_size": "Vector2(72, 42)",
        "attack_hitbox_offset_x": 36.0,
        "skill_1_hitbox_size": "Vector2(80, 46)",
        "hurt_stun": 0.12,
    },
    "kanao": {
        "move_speed": 305.0,
        "max_hp": 90,
        "attack_damage": 9,
        "attack_startup": 0.03,
        "attack_recovery": 0.07,
        "dash_cooldown": 0.62,
    },
    "shinobu": {
        "move_speed": 315.0,
        "max_hp": 80,
        "attack_damage": 6,
        "attack_startup": 0.03,
        "attack_active": 0.10,
        "skill_1_cooldown": 2.4,
        "skill_1_damage": 10,
        "breath_per_hit": 14.0,
    },
    "uzui": {
        "move_speed": 335.0,
        "dash_speed": 700.0,
        "attack_damage": 9,
        "max_hp": 95,
        "skill_2_lunge_speed": 640.0,
    },
    "rengoku": {
        "move_speed": 250.0,
        "max_hp": 120,
        "attack_damage": 12,
        "ultimate_damage": 44,
        "attack_hitbox_size": "Vector2(60, 38)",
        "ultimate_hitbox_size": "Vector2(96, 58)",
    },
    "tomioka": {
        "move_speed": 285.0,
        "max_hp": 108,
        "attack_damage": 10,
        "skill_1_damage": 16,
        "skill_1_hitbox_size": "Vector2(76, 42)",
    },
    "obanai": {
        "attack_hitbox_offset_x": 44.0,
        "attack_hitbox_size": "Vector2(74, 26)",
        "skill_1_hitbox_offset_x": 48.0,
        "skill_1_hitbox_size": "Vector2(86, 28)",
        "move_speed": 290.0,
        "max_hp": 95,
    },
    "tokito": {
        "move_speed": 345.0,
        "max_hp": 75,
        "dash_cooldown": 0.48,
        "dash_speed": 720.0,
        "attack_damage": 8,
        "hurt_invuln": 0.6,
    },
    "sanemi": {
        "move_speed": 295.0,
        "max_hp": 100,
        "attack_damage": 13,
        "attack_recovery": 0.07,
        "skill_1_damage": 18,
    },
    "gyomei": {
        "move_speed": 195.0,
        "max_hp": 155,
        "attack_damage": 15,
        "attack_recovery": 0.16,
        "attack_hitbox_size": "Vector2(92, 52)",
        "dash_speed": 460.0,
        "dash_duration": 0.12,
        "skill_1_damage": 20,
        "ultimate_damage": 48,
    },
    "yoriichi": {
        "move_speed": 315.0,
        "max_hp": 130,
        "attack_damage": 16,
        "skill_1_damage": 22,
        "ultimate_damage": 55,
        "attack_recovery": 0.07,
        "breath_per_hit": 16.0,
    },
    "muzan": {
        "move_speed": 255.0,
        "max_hp": 140,
        "attack_damage": 11,
        "attack_hitbox_size": "Vector2(88, 48)",
        "skill_1_hitbox_size": "Vector2(90, 50)",
        "ultimate_hitbox_size": "Vector2(110, 64)",
        "lifesteal_ratio": 0.12,
    },
}

CHARS_DATA = [
    {
        "id": "tanjiro",
        "display_name": "Tanjiro",
        "requires": [],
        "unlock_hint": "Disponível desde o início",
        "skill_1": "Corte em Arco",
        "skill_2": "Investida",
        "ult": "Respiração",
        "accent": "1, 0.95, 0.88, 1",
        "lifesteal": 0.0,
        "stats": "res://resources/player/player_stats.tres",
    },
    {
        "id": "zenitsu",
        "display_name": "Zenitsu",
        "requires": ["w1_boss"],
        "unlock_hint": "Vença o chefe do Mundo 1",
        "skill_1": "Relâmpago",
        "skill_2": "Passo do Trovão",
        "ult": "Seis Dobras",
        "accent": "1.12, 1.08, 0.55, 1",
        "lifesteal": 0.0,
    },
    {
        "id": "inosuke",
        "display_name": "Inosuke",
        "requires": ["w2_boss"],
        "unlock_hint": "Vença o chefe do Mundo 2",
        "skill_1": "Presas",
        "skill_2": "Investida Selvagem",
        "ult": "Rei da Serra",
        "accent": "0.72, 1.05, 0.78, 1",
        "lifesteal": 0.0,
    },
    {
        "id": "kanao",
        "display_name": "Kanao",
        "requires": ["w3_01"],
        "unlock_hint": "Conclua a fase 1 do Mundo 3",
        "skill_1": "Pétala",
        "skill_2": "Passo de Flor",
        "ult": "Olho Firme",
        "accent": "1.05, 0.82, 0.95, 1",
        "lifesteal": 0.0,
    },
    {
        "id": "shinobu",
        "display_name": "Shinobu",
        "requires": ["w3_boss"],
        "unlock_hint": "Vença o chefe do Mundo 3",
        "skill_1": "Agulha",
        "skill_2": "Dança da Vespa",
        "ult": "Toxina",
        "accent": "0.82, 0.78, 1.15, 1",
        "lifesteal": 0.0,
    },
    {
        "id": "uzui",
        "display_name": "Uzui",
        "requires": ["w3_boss"],
        "unlock_hint": "Vença o chefe do Mundo 3",
        "skill_1": "Estouro",
        "skill_2": "Corte Duplo",
        "ult": "Desfile",
        "accent": "1.1, 0.88, 0.5, 1",
        "lifesteal": 0.0,
    },
    {
        "id": "rengoku",
        "display_name": "Rengoku",
        "requires": ["w2_boss"],
        "unlock_hint": "Vença o chefe do Mundo 2",
        "skill_1": "Chama",
        "skill_2": "Investida Flamejante",
        "ult": "Pilar",
        "accent": "1.2, 0.68, 0.42, 1",
        "lifesteal": 0.0,
    },
    {
        "id": "tomioka",
        "display_name": "Tomioka",
        "requires": ["w4_01"],
        "unlock_hint": "Conclua a fase 1 do Mundo 4",
        "skill_1": "Corte de Água",
        "skill_2": "Fluxo",
        "ult": "Forma Calma",
        "accent": "0.68, 0.84, 1.15, 1",
        "lifesteal": 0.0,
    },
    {
        "id": "obanai",
        "display_name": "Obanai",
        "requires": ["w4_05"],
        "unlock_hint": "Conclua o Mundo 4",
        "skill_1": "Serpente",
        "skill_2": "Espiral",
        "ult": "Trilha",
        "accent": "0.68, 1.0, 0.72, 1",
        "lifesteal": 0.0,
    },
    {
        "id": "tokito",
        "display_name": "Tokito",
        "requires": ["w4_05"],
        "unlock_hint": "Conclua o Mundo 4",
        "skill_1": "Névoa",
        "skill_2": "Desvanecer",
        "ult": "Névoa Infinita",
        "accent": "0.84, 0.9, 1.12, 1",
        "lifesteal": 0.0,
    },
    {
        "id": "sanemi",
        "display_name": "Sanemi",
        "requires": ["w4_boss"],
        "unlock_hint": "Vença o chefe do Mundo 4",
        "skill_1": "Rajada",
        "skill_2": "Corte de Vento",
        "ult": "Tempestade",
        "accent": "0.78, 1.12, 0.72, 1",
        "lifesteal": 0.0,
    },
    {
        "id": "gyomei",
        "display_name": "Gyomei",
        "requires": ["w4_boss"],
        "unlock_hint": "Vença o chefe do Mundo 4",
        "skill_1": "Rocha",
        "skill_2": "Impacto",
        "ult": "Pilar de Pedra",
        "accent": "0.86, 0.84, 0.78, 1",
        "lifesteal": 0.0,
    },
    {
        "id": "yoriichi",
        "display_name": "Yoriichi",
        "requires": ["w5_05"],
        "unlock_hint": "Conclua o Mundo 5",
        "skill_1": "Sol Nascente",
        "skill_2": "Dança",
        "ult": "Treze Formas",
        "accent": "1.2, 0.95, 0.52, 1",
        "lifesteal": 0.0,
    },
    {
        "id": "muzan",
        "display_name": "Muzan",
        "requires": ["w5_05"],
        "unlock_hint": "Conclua o Mundo 5 (secreto)",
        "skill_1": "Sombra",
        "skill_2": "Lua",
        "ult": "Rei Oni",
        "accent": "0.95, 0.52, 0.58, 1",
        "lifesteal": 0.12,
    },
]


def fmt_requires(reqs: list[str]) -> str:
    if not reqs:
        return ""
    return ", ".join(f'"{r}"' for r in reqs)


def write_kit(cid: str, fields: dict) -> str:
    KITS.mkdir(parents=True, exist_ok=True)
    lines = [STATS_HEADER.rstrip(), ""]
    for k, v in fields.items():
        if isinstance(v, str) and v.startswith("Vector2"):
            lines.append(f"{k} = {v}")
        elif isinstance(v, float):
            lines.append(f"{k} = {v}")
        elif isinstance(v, int):
            lines.append(f"{k} = {v}")
        else:
            lines.append(f"{k} = {v}")
    path = KITS / f"stats_{cid}.tres"
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return f"res://resources/player/kits/stats_{cid}.tres"


def main() -> None:
    CHARS.mkdir(parents=True, exist_ok=True)
    for row in CHARS_DATA:
        cid = row["id"]
        stats_path = row.get("stats")
        if not stats_path:
            stats_path = write_kit(cid, KITS_DATA[cid])
        text = CHAR_TMPL.format(
            id=cid,
            display_name=row["display_name"],
            requires=fmt_requires(row["requires"]),
            unlock_hint=row["unlock_hint"],
            skill_1=row["skill_1"],
            skill_2=row["skill_2"],
            ult=row["ult"],
            accent=row["accent"],
            stats_path=stats_path,
            lifesteal=row["lifesteal"],
        )
        (CHARS / f"{cid}.tres").write_text(text, encoding="utf-8")
        print("wrote", cid, "->", stats_path)
    print("ok", len(CHARS_DATA), "characters")


if __name__ == "__main__":
    main()
