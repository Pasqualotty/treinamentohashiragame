#!/usr/bin/env python3
"""Gera as silhuetas de primeiro plano por mundo (determinístico, sem IA).

Saída: assets/backgrounds/w{1..5}/fg_band.png  (512x720 RGBA, preto 85% alpha)
  W1 bambu · W2 postes/corrimão de trem · W3 postes de lanterna ·
  W4 pilares · W5 espinhos de rocha.

Seamless horizontal: cada forma é desenhada em x-512, x e x+512 no mesmo
quadro, então a coluna 0 e a 511 se encaixam. Supersample 2x + LANCZOS.

Uso:  python tools/gen_world_fg.py
"""
from __future__ import annotations

import math
import random
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "backgrounds"
W, H = 512, 720
SS = 2  # supersample
INK = (0, 0, 0, 217)  # preto, 85% de alpha


class Canvas:
    def __init__(self):
        self.img = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.img)

    def wrapped(self, fn):
        """Executa fn(draw, dx) em três deslocamentos -> emenda perfeita."""
        for dx in (-W, 0, W):
            fn(self.d, dx * SS)

    def poly(self, pts):
        self.wrapped(lambda d, dx: d.polygon([(x * SS + dx, y * SS) for x, y in pts], fill=INK))

    def rect(self, x0, y0, x1, y1):
        self.wrapped(lambda d, dx: d.rectangle([x0 * SS + dx, y0 * SS, x1 * SS + dx, y1 * SS], fill=INK))

    def ellipse(self, x0, y0, x1, y1):
        self.wrapped(lambda d, dx: d.ellipse([x0 * SS + dx, y0 * SS, x1 * SS + dx, y1 * SS], fill=INK))

    def save(self, path: Path):
        out = self.img.resize((W, H), Image.LANCZOS)
        # LANCZOS pode estourar o alpha máximo: trava em 217 (85%).
        a = np.asarray(out).copy()
        a[..., 3] = np.minimum(a[..., 3], 217)
        a[..., :3] = 0
        Image.fromarray(a, "RGBA").save(path, optimize=False)


def w1_bamboo(c: Canvas, rnd: random.Random):
    """Três colmos de bambu com nós e folhas finas no alto."""
    for cx, width in ((70, 14), (250, 10), (410, 17)):
        sway = rnd.uniform(-5, 5)
        pts_l, pts_r = [], []
        for y in range(-10, H + 11, 20):
            off = sway * math.sin(y / H * math.pi)
            pts_l.append((cx + off - width / 2, y))
            pts_r.append((cx + off + width / 2, y))
        c.poly(pts_l + pts_r[::-1])
        # nós: anéis levemente mais largos
        for y in range(90, H, 130):
            off = sway * math.sin(y / H * math.pi)
            c.rect(cx + off - width / 2 - 2, y, cx + off + width / 2 + 2, y + 5)
        # folhas: lâminas finas saindo do alto do colmo
        for _ in range(5):
            y = rnd.randint(10, 200)
            side = rnd.choice((-1, 1))
            ln = rnd.randint(40, 80)
            x0 = cx + sway * math.sin(y / H * math.pi)
            c.poly([(x0, y), (x0 + side * ln, y - 14), (x0 + side * ln * 0.55, y + 6)])


def w2_train(c: Canvas, rnd: random.Random):
    """Postes do vagão, corrimão corrido e alças penduradas."""
    c.rect(-4, 0, W + 4, 22)  # trilho superior
    c.rect(-4, 300, W + 4, 312)  # corrimão
    for cx in (120, 380):
        c.rect(cx - 9, 0, cx + 9, H)
        c.rect(cx - 16, 296, cx + 16, 316)
    for cx in (40, 200, 290, 460):  # alças
        c.rect(cx - 1.5, 22, cx + 1.5, 70)
        c.ellipse(cx - 12, 62, cx + 12, 92)
        c.ellipse(cx - 7, 67, cx + 7, 87)
    # recorta o miolo da alça para virar anel (apaga com alpha 0)
    for cx in (40, 200, 290, 460):
        for dx in (-W, 0, W):
            c.d.ellipse(
                [(cx - 6 + dx) * SS, 68 * SS, (cx + 6 + dx) * SS, 86 * SS], fill=(0, 0, 0, 0)
            )


def w3_lanterns(c: Canvas, rnd: random.Random):
    """Postes de madeira com travessa e lanterna pendurada."""
    for cx, hang in ((100, 150), (360, 110)):
        c.rect(cx - 4, 0, cx + 4, H)
        c.rect(cx - 60, 36, cx + 60, 46)  # travessa
        for sx in (-52, 52):
            c.rect(cx + sx - 1, 46, cx + sx + 1, hang)
            c.ellipse(cx + sx - 14, hang, cx + sx + 14, hang + 44)
            c.rect(cx + sx - 8, hang - 6, cx + sx + 8, hang + 2)
    # fitas de pano soltas
    for cx in (230, 470):
        c.poly([(cx, 0), (cx + 18, 0), (cx + 14, 120), (cx + 4, 150), (cx - 2, 110)])


def w4_pillars(c: Canvas, rnd: random.Random):
    """Pilares de castelo com capitel e base; um largo, um fino."""
    for cx, hw in ((130, 24), (400, 15)):
        c.rect(cx - hw, 0, cx + hw, H)
        c.rect(cx - hw - 12, 0, cx + hw + 12, 40)  # capitel
        c.rect(cx - hw - 8, 40, cx + hw + 8, 56)
        c.rect(cx - hw - 12, H - 70, cx + hw + 12, H)  # base
    # corrente pendurada entre os pilares
    pts = [(x, 60 + 38 * math.sin((x - 130) / 270 * math.pi)) for x in range(130, 401, 10)]
    c.poly(pts + [(x, y + 5) for x, y in pts[::-1]])


def w5_spikes(c: Canvas, rnd: random.Random):
    """Estalactites do alto e espinhos de rocha subindo do chão."""
    x = 10
    while x < W:
        base_w = rnd.randint(30, 60)
        ln = rnd.randint(80, 230)
        tip = x + base_w / 2 + rnd.randint(-8, 8)
        c.poly([(x, -2), (x + base_w, -2), (tip, ln)])
        x += base_w + rnd.randint(14, 50)
    x = 40
    while x < W:
        base_w = rnd.randint(40, 80)
        ln = rnd.randint(150, 300)
        tip = x + base_w / 2 + rnd.randint(-10, 10)
        c.poly([(x, H + 2), (x + base_w, H + 2), (tip, H - ln)])
        x += base_w + rnd.randint(60, 140)


WORLDS = {1: w1_bamboo, 2: w2_train, 3: w3_lanterns, 4: w4_pillars, 5: w5_spikes}


def verify_wrap(path: Path) -> float:
    a = np.asarray(Image.open(path)).astype(float)
    diff = float(np.abs(a[:, 0] - a[:, -1]).mean())
    if diff > 12.0:  # alpha 0..217; coluna vizinha de uma haste pode variar
        raise SystemExit(f"FALHA emenda {path}: diff={diff:.2f}")
    return diff


def main() -> int:
    for world, fn in WORLDS.items():
        c = Canvas()
        fn(c, random.Random(2000 + world))
        folder = OUT / f"w{world}"
        folder.mkdir(parents=True, exist_ok=True)
        path = folder / "fg_band.png"
        c.save(path)
        print(f"w{world}: fg_band wrap={verify_wrap(path):.2f}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
