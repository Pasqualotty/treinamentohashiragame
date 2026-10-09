"""Gera assets/characters/<dir>/combat/fit.json (bbox de alpha do 1o frame de idle).

Determinístico e sem custo em runtime: SpriteFit lê esse JSON; sem ele cai no
Image.get_used_rect(). Re-executável: python tools/gen_sprite_fit.py
"""
import json
import re
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
LIMIAR_ALPHA = 1  # mesmo critério de Image.get_used_rect (alpha > 0)


def combat_dirs():
    """Lê combat_frames_dir de cada CharacterDef (.tres)."""
    achados = []
    for tres in sorted((ROOT / "resources" / "characters").glob("*.tres")):
        m = re.search(r'combat_frames_dir = "res://([^"]+)"', tres.read_text(encoding="utf-8"))
        if m:
            achados.append(ROOT / m.group(1))
    return achados


def bbox_idle(combat: Path):
    frames = sorted((combat / "idle_side").glob("[0-9][0-9].png"))
    if not frames:
        return None
    img = Image.open(frames[0]).convert("RGBA")
    alpha = img.getchannel("A").point(lambda a: 255 if a >= LIMIAR_ALPHA else 0)
    box = alpha.getbbox()
    if box is None:
        return None
    x0, y0, x1, y1 = box
    return {"x": x0, "y": y0, "w": x1 - x0, "h": y1 - y0, "tex_w": img.width, "tex_h": img.height}


def main():
    for combat in combat_dirs():
        dados = bbox_idle(combat)
        if dados is None:
            print("sem idle:", combat)
            continue
        (combat / "fit.json").write_text(json.dumps(dados, sort_keys=True) + "\n", encoding="utf-8")
        print(combat.parent.name, dados)


if __name__ == "__main__":
    main()
