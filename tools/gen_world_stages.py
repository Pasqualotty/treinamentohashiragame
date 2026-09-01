#!/usr/bin/env python3
"""Gera StageDef + cenas W2–W5 a partir dos templates W1 (placeholder jogável)."""
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TRES_DIR = ROOT / "resources" / "stages"
SCENE_DIR = ROOT / "scenes" / "battle"

POS4 = [(160, 450), (460, 320), (780, 430), (1100, 250)]
POS5 = [(130, 470), (360, 330), (590, 450), (820, 300), (1140, 250)]

THEMES = {
    "w2": {
        "modulate": "Color(0.92, 0.82, 0.7, 1)",
        "sky": "0.14, 0.1, 0.07, 1, 0.32, 0.24, 0.14, 1, 0.45, 0.34, 0.2, 1",
        "fg": "0.12, 0.07, 0.03, 0.55, 0.12, 0.07, 0.03, 0, 0.12, 0.07, 0.03, 0, 0.12, 0.07, 0.03, 0.55",
        "bg": "Color(0.14, 0.08, 0.04, 0.4)",
        "moon": "Color(1.0, 0.82, 0.55, 1)",
        "firefly": "Color(1.0, 0.72, 0.28, 0.55)",
        "mist": "Color(0.72, 0.64, 0.5, 0.16)",
        "accent": "Color(0.95, 0.5, 0.18, 1)",
        "portal": "Color(0.95, 0.7, 0.35, 0.75)",
        "boss_bg": "Color(0.16, 0.08, 0.04, 0.45)",
        "boss_portal": "Color(0.95, 0.55, 0.2, 0.85)",
    },
    "w3": {
        "modulate": "Color(0.88, 0.72, 0.78, 1)",
        "sky": "0.08, 0.05, 0.1, 1, 0.22, 0.1, 0.16, 1, 0.38, 0.16, 0.14, 1",
        "fg": "0.08, 0.03, 0.05, 0.55, 0.08, 0.03, 0.05, 0, 0.08, 0.03, 0.05, 0, 0.08, 0.03, 0.05, 0.55",
        "bg": "Color(0.1, 0.04, 0.08, 0.4)",
        "moon": "Color(1.0, 0.55, 0.35, 1)",
        "firefly": "Color(1.0, 0.7, 0.35, 0.6)",
        "mist": "Color(0.55, 0.35, 0.4, 0.14)",
        "accent": "Color(1.0, 0.45, 0.2, 1)",
        "portal": "Color(1.0, 0.55, 0.4, 0.75)",
        "boss_bg": "Color(0.12, 0.04, 0.08, 0.48)",
        "boss_portal": "Color(1.0, 0.4, 0.28, 0.85)",
    },
    "w4": {
        "modulate": "Color(0.78, 0.8, 0.92, 1)",
        "sky": "0.05, 0.06, 0.12, 1, 0.1, 0.12, 0.22, 1, 0.18, 0.18, 0.28, 1",
        "fg": "0.04, 0.04, 0.08, 0.55, 0.04, 0.04, 0.08, 0, 0.04, 0.04, 0.08, 0, 0.04, 0.04, 0.08, 0.55",
        "bg": "Color(0.06, 0.06, 0.12, 0.42)",
        "moon": "Color(0.7, 0.78, 1.0, 1)",
        "firefly": "Color(0.7, 0.8, 1.0, 0.45)",
        "mist": "Color(0.4, 0.42, 0.55, 0.14)",
        "accent": "Color(0.55, 0.45, 0.85, 1)",
        "portal": "Color(0.55, 0.65, 1.0, 0.75)",
        "boss_bg": "Color(0.05, 0.05, 0.12, 0.5)",
        "boss_portal": "Color(0.7, 0.4, 0.9, 0.85)",
    },
    "w5": {
        "modulate": "Color(0.95, 0.7, 0.68, 1)",
        "sky": "0.16, 0.03, 0.04, 1, 0.32, 0.06, 0.06, 1, 0.5, 0.12, 0.08, 1",
        "fg": "0.12, 0.02, 0.02, 0.55, 0.12, 0.02, 0.02, 0, 0.12, 0.02, 0.02, 0, 0.12, 0.02, 0.02, 0.55",
        "bg": "Color(0.18, 0.04, 0.04, 0.42)",
        "moon": "Color(1.0, 0.35, 0.28, 1)",
        "firefly": "Color(1.0, 0.4, 0.25, 0.55)",
        "mist": "Color(0.55, 0.15, 0.12, 0.16)",
        "accent": "Color(1.0, 0.25, 0.18, 1)",
        "portal": "Color(1.0, 0.4, 0.35, 0.75)",
        "boss_bg": "Color(0.2, 0.03, 0.04, 0.5)",
        "boss_portal": "Color(1.0, 0.28, 0.22, 0.9)",
    },
}

W2_WAVES = {
    "w2_01": [["weak", "weak"], ["weak", "weak", "weak"], ["weak", "elite"]],
    "w2_02": [["weak", "weak", "weak"], ["weak", "elite", "weak"], ["elite", "weak"]],
    "w2_03": [["weak", "ranged"], ["ranged", "weak", "weak"], ["elite", "ranged"]],
    "w2_boss": [["weak", "weak", "ranged"], ["charger", "elite"], ["boss"]],
}
W3_WAVES = {
    "w3_01": [["weak", "weak"], ["weak", "weak", "weak"], ["weak", "elite"]],
    "w3_02": [["weak", "weak", "elite"], ["elite", "weak", "weak"], ["ranged", "weak"]],
    "w3_03": [["ranged", "weak"], ["weak", "ranged", "weak"], ["elite", "ranged"]],
    "w3_04": [["charger", "weak"], ["ranged", "charger"], ["elite", "charger", "weak"]],
    "w3_boss": [["weak", "ranged", "weak"], ["charger", "elite", "ranged"], ["boss"]],
}
W4_WAVES = {
    "w4_01": [["weak", "weak", "weak"], ["weak", "elite"], ["elite", "weak", "weak"]],
    "w4_02": [["ranged", "weak"], ["weak", "ranged", "weak"], ["elite", "ranged"]],
    "w4_03": [["charger", "weak"], ["ranged", "charger", "weak"], ["elite", "charger"]],
    "w4_04": [["elite", "ranged"], ["charger", "ranged", "weak"], ["elite", "charger", "ranged"]],
    "w4_boss": [["ranged", "elite", "weak"], ["charger", "ranged", "elite"], ["boss"]],
}
W5_WAVES = {
    "w5_01": [["weak", "elite"], ["ranged", "weak", "weak"], ["elite", "ranged"]],
    "w5_02": [["charger", "weak"], ["ranged", "charger", "weak"], ["elite", "charger"]],
    "w5_03": [["elite", "ranged", "weak"], ["charger", "elite", "ranged"], ["elite", "charger", "ranged"]],
    "w5_boss": [["charger", "ranged", "elite"], ["elite", "charger", "ranged", "weak"], ["boss"]],
}

WORLDS = [
    (
        "w2",
        "Mundo 2",
        ["Estação", "Vagões", "Telhados", "Boss"],
        ["w1_boss"],
        POS4,
        W2_WAVES,
    ),
    (
        "w3",
        "Mundo 3",
        ["Becos", "Lanternas", "Mercado", "Ponte", "Boss"],
        ["w2_boss"],
        POS5,
        W3_WAVES,
    ),
    (
        "w4",
        "Mundo 4",
        ["Átrio", "Salão", "Torre", "Muralha", "Boss"],
        ["w3_boss"],
        POS5,
        W4_WAVES,
    ),
    (
        "w5",
        "Mundo 5",
        ["Nuvens", "Templo", "Abismo", "Boss"],
        ["w4_boss"],
        POS4,
        W5_WAVES,
    ),
]


def waves_line(packs: list[list[str]]) -> str:
    inner = ", ".join("[" + ", ".join(f'"{k}"' for k in pack) + "]" for pack in packs)
    return f"waves = [{inner}]"


def write_tres(stage_id: str, display: str, req: list[str], label: str, pos: tuple[int, int], is_boss: bool, waves: list[list[str]]) -> None:
    req_s = ", ".join(f'"{r}"' for r in req)
    body = f"""[gd_resource type="Resource" script_class="StageDef" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/battle/stage_def.gd" id="1_script"]

[resource]
script = ExtResource("1_script")
stage_id = "{stage_id}"
display_name = "{display}"
scene_path = "res://scenes/battle/stage_{stage_id}.tscn"
requires_cleared = Array[String]([{req_s}])
map_label = "{label}"
map_position = Vector2({pos[0]}, {pos[1]})
is_boss = {"true" if is_boss else "false"}
{waves_line(waves)}
"""
    (TRES_DIR / f"stage_{stage_id}.tres").write_text(body, encoding="utf-8")


def write_normal_scene(stage_id: str, theme: dict) -> None:
    token = stage_id.replace("_", "")
    node = f"Stage{stage_id.replace('_', '').upper()[0]}{stage_id[1:].replace('_', '')}"
    # StageW201 / StageW301
    node = "Stage" + stage_id.replace("_", "").capitalize().replace("w", "W", 1)
    if stage_id.endswith("_boss"):
        node = f"Stage{stage_id[:2].upper()}Boss"
    else:
        parts = stage_id.split("_")
        node = f"Stage{parts[0].upper()}{parts[1]}"
    text = (SCENE_DIR / "stage_w1_01.tscn").read_text(encoding="utf-8")
    text = text.replace("Gradient_sky_w101", f"Gradient_sky_{token}")
    text = text.replace("GradTex_sky_w101", f"GradTex_sky_{token}")
    text = text.replace("Gradient_fg_w101", f"Gradient_fg_{token}")
    text = text.replace("GradTex_fg_w101", f"GradTex_fg_{token}")
    text = text.replace('name="StageW101"', f'name="{node}"')
    text = text.replace('stage_id = "w1_01"', f'stage_id = "{stage_id}"')
    text = text.replace(
        "colors = PackedColorArray(0.0588, 0.0706, 0.0941, 1, 0.1098, 0.1373, 0.1882, 1, 0.16, 0.2, 0.19, 1)",
        f"colors = PackedColorArray({theme['sky']})",
    )
    text = text.replace(
        "colors = PackedColorArray(0.03, 0.06, 0.04, 0.55, 0.03, 0.06, 0.04, 0, 0.03, 0.06, 0.04, 0, 0.03, 0.06, 0.04, 0.55)",
        f"colors = PackedColorArray({theme['fg']})",
    )
    text = text.replace("color = Color(0.8, 0.83, 0.96, 1)", f"color = {theme['modulate']}")
    text = text.replace("color = Color(0.85, 0.95, 0.55, 0.55)", f"color = {theme['firefly']}")
    text = text.replace("color = Color(0.55, 0.62, 0.7, 0.12)", f"color = {theme['mist']}")
    text = text.replace("color = Color(0.68, 0.76, 1.0, 1)", f"color = {theme['moon']}")
    text = text.replace("color = Color(0.91, 0.72, 0.29, 1)", f"color = {theme['accent']}")
    text = text.replace("color = Color(0.05, 0.07, 0.1, 0.35)", f"color = {theme['bg']}")
    text = text.replace("color = Color(0.35, 0.85, 0.95, 0.75)", f"color = {theme['portal']}")
    (SCENE_DIR / f"stage_{stage_id}.tscn").write_text(text, encoding="utf-8")


def write_boss_scene(stage_id: str, theme: dict) -> None:
    parts = stage_id.split("_")
    node = f"Stage{parts[0].upper()}Boss"
    text = (SCENE_DIR / "stage_w1_boss.tscn").read_text(encoding="utf-8")
    text = text.replace('name="StageW1Boss"', f'name="{node}"')
    text = text.replace('stage_id = "w1_boss"', f'stage_id = "{stage_id}"')
    text = text.replace("color = Color(0.05, 0.07, 0.1, 0.35)", f"color = {theme['boss_bg']}")
    text = text.replace("color = Color(1, 0.45, 0.25, 0.85)", f"color = {theme['boss_portal']}")
    (SCENE_DIR / f"stage_{stage_id}.tscn").write_text(text, encoding="utf-8")


def main() -> None:
    n = 0
    for wid, world_name, labels, first_req, positions, wave_map in WORLDS:
        theme = THEMES[wid]
        ids: list[str] = []
        normals = labels[:-1]
        for i, label in enumerate(normals):
            sid = f"{wid}_{i+1:02d}"
            ids.append(sid)
            req = list(first_req) if i == 0 else [ids[i - 1]]
            pos = positions[i]
            write_tres(sid, f"{world_name} — {label}", req, f"Fase {i+1}", pos, False, wave_map[sid])
            write_normal_scene(sid, theme)
            n += 1
        boss_id = f"{wid}_boss"
        write_tres(boss_id, f"{world_name} — Boss", ids, "Boss", positions[-1], True, wave_map[boss_id])
        write_boss_scene(boss_id, theme)
        n += 1
    print(f"wrote {n} stages")


if __name__ == "__main__":
    main()
