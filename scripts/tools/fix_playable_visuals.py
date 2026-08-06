# -*- coding: utf-8 -*-
"""Fix stage labels (UTF-8) and inject stage background art."""
from __future__ import annotations

import re
from pathlib import Path

MAIN = Path(__file__).resolve().parents[2]


def fix_labels() -> None:
    fixes = {
        "scenes/battle/stage_w1_01.tscn": {
            "saida": 'text = "SAIDA"',
            "hint": 'text = "Fase 1 - chegue ao portal azul"',
        },
        "scenes/battle/stage_w1_02.tscn": {
            "saida": 'text = "SAIDA"',
            "hint": 'text = "Fase 2 - plataformas e inimigos"',
        },
        "scenes/battle/stage_w1_03.tscn": {
            "saida": 'text = "SAIDA"',
            "hint": 'text = "Fase 3 - trilha alta"',
        },
        "scenes/battle/stage_w1_boss.tscn": {
            "hint": 'text = "BOSS - derrote o inimigo e saia pelo portal"',
        },
    }
    for rel, parts in fixes.items():
        p = MAIN / rel
        t = p.read_text(encoding="utf-8", errors="replace")
        if "saida" in parts:
            t, n1 = re.subn(r'text = "SA[^"\n]*"', parts["saida"], t, count=2)
        else:
            n1 = 0
        if "hint" in parts:
            t, n2 = re.subn(
                r'text = "W1[^"\n]*"|text = "BOSS[^"\n]*"|text = "Fase [^"\n]*"',
                parts["hint"],
                t,
                count=1,
            )
            # also replace already-garbled long hint lines
            if n2 == 0:
                t, n2 = re.subn(
                    r'(\[node name="Hint"[^\]]*\][\s\S]*?)text = "[^"]*"',
                    r'\1' + parts["hint"],
                    t,
                    count=1,
                )
        else:
            n2 = 0
        p.write_text(t, encoding="utf-8", newline="\n")
        print(f"labels {rel}: saida={n1} hint={n2}")


def inject_bgs() -> None:
    bgs = {
        "stage_w1_01.tscn": "res://assets/backgrounds/w1/stage_forest.png",
        "stage_w1_02.tscn": "res://assets/backgrounds/w1/stage_village.png",
        "stage_w1_03.tscn": "res://assets/backgrounds/w1/stage_mountain.png",
        "stage_w1_boss.tscn": "res://assets/backgrounds/w1/stage_forest.png",
    }
    for name, tex in bgs.items():
        p = MAIN / "scenes" / "battle" / name
        t = p.read_text(encoding="utf-8", errors="replace")
        if "BgArt" in t or "stage_forest.png" in t or "stage_village.png" in t:
            print(f"bg skip {name}")
            continue
        m = re.search(r"load_steps=(\d+)", t)
        if m:
            t = re.sub(
                r"load_steps=\d+",
                f"load_steps={int(m.group(1)) + 1}",
                t,
                count=1,
            )
        insert = f'[ext_resource type="Texture2D" path="{tex}" id="9_bg"]\n\n'
        t = t.replace("[sub_resource", insert + "[sub_resource", 1)
        bg_node = (
            '[node name="BgArt" type="Sprite2D" parent="."]\n'
            "z_index = -20\n"
            "position = Vector2(640, 360)\n"
            'texture = ExtResource("9_bg")\n\n'
        )
        t = t.replace('[node name="Background"', bg_node + '[node name="Background"', 1)
        t = re.sub(
            r"(\[node name=\"Background\"[^\]]*\][\s\S]*?color = )Color\([^\)]+\)",
            r"\1Color(0.05, 0.07, 0.1, 0.35)",
            t,
            count=1,
        )
        p.write_text(t, encoding="utf-8", newline="\n")
        print(f"bg injected {name}")


def main() -> None:
    fix_labels()
    inject_bgs()
    print("OK fix_playable_visuals")


if __name__ == "__main__":
    main()
