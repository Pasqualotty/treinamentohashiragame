"""Gera os medalhoes dos nos do mapa do mundo (mesma linguagem laqueada das placas do hub).

Cada medalhao e um disco com anel ouro (ou cinza, se trancado), face em gradiente,
brilho de laca e bisel. O icone do estado (cadeado, check, numero da fase) NAO vai no
PNG: o Godot desenha por cima, para o numero ser texto real (Cinzel) e o icone nunca
disputar espaco com o rotulo.

Determinista e re-executavel (sem aleatoriedade, bytes identicos). Da raiz do projeto:

    python tools/gen_map_art.py

Saida: assets/ui/map/medal_<estado>.png. Depois, importar no Godot:

    godot --headless --path . --import
"""

from __future__ import annotations

import math
import os

from PIL import Image, ImageDraw, ImageFilter

# Reaproveita as ferramentas de cor/gradiente/mascara do gerador do hub.
from gen_hub_art import (CREAM, GOLD, GOLD_BRIGHT, GOLD_DEEP, INK, NIGHT, PANEL, PANEL_HI,
                         _circle_mask, _shade, _vgrad)

OUT_DIR = os.path.join("assets", "ui", "map")
SS = 4

CRIMSON = (196, 60, 60)
CRIMSON_BRIGHT = (240, 102, 97)
CRIMSON_DEEP = (92, 26, 30)
GREEN = (70, 150, 104)
GREEN_DEEP = (26, 70, 50)
STEEL = (122, 130, 142)
STEEL_DEEP = (58, 64, 76)

# nome, tamanho (px final), boss, anel (topo, base), face (topo, base), espinhos, brilho
MEDALS = (
    ("available", 168, False, (GOLD_BRIGHT, GOLD_DEEP), (PANEL_HI, PANEL), None, 46),
    ("cleared", 168, False, (GOLD_BRIGHT, GOLD_DEEP), (GREEN, GREEN_DEEP), None, 40),
    ("locked", 168, False, (STEEL, STEEL_DEEP), (_shade(NIGHT, 0.10), _shade(NIGHT, -0.30)), None, 14),
    ("boss_available", 192, True, (GOLD_BRIGHT, GOLD_DEEP), (CRIMSON, CRIMSON_DEEP), CRIMSON_BRIGHT, 46),
    ("boss_cleared", 192, True, (GOLD_BRIGHT, GOLD_DEEP), (GREEN, GREEN_DEEP), GOLD, 40),
    ("boss_locked", 192, True, (STEEL, STEEL_DEEP), (_shade(CRIMSON_DEEP, -0.45), _shade(NIGHT, -0.30)),
     STEEL_DEEP, 14),
)


def _disc(im: Image.Image, cx: float, cy: float, r: float, fill: tuple) -> None:
    ImageDraw.Draw(im).ellipse((cx - r, cy - r, cx + r, cy + r), fill=fill)


def _gradient_disc(im: Image.Image, cx: float, cy: float, r: float,
                   top: tuple, bottom: tuple) -> None:
    """Disco com gradiente vertical, colado com mascara circular."""
    d = int(round(r * 2))
    grad = _vgrad(d, d, top, bottom)
    im.paste(grad, (int(round(cx - r)), int(round(cy - r))), _circle_mask(d, d))


def _spikes(im: Image.Image, cx: float, cy: float, r: float, color: tuple, n: int = 12) -> None:
    """Coroa de espinhos triangulares em volta do anel (selo de chefe)."""
    d = ImageDraw.Draw(im)
    for i in range(n):
        ang = math.tau * i / n - math.pi / 2
        half = math.tau / n * 0.26
        tip = (cx + math.cos(ang) * (r + SS * 9), cy + math.sin(ang) * (r + SS * 9))
        a = (cx + math.cos(ang - half) * (r - SS * 2), cy + math.sin(ang - half) * (r - SS * 2))
        b = (cx + math.cos(ang + half) * (r - SS * 2), cy + math.sin(ang + half) * (r - SS * 2))
        d.polygon([a, tip, b], fill=INK + (255,))
        # Miolo colorido do espinho, um pouco menor que o contorno.
        tip2 = (cx + math.cos(ang) * (r + SS * 6), cy + math.sin(ang) * (r + SS * 6))
        a2 = (cx + math.cos(ang - half * 0.7) * (r - SS * 2), cy + math.sin(ang - half * 0.7) * (r - SS * 2))
        b2 = (cx + math.cos(ang + half * 0.7) * (r - SS * 2), cy + math.sin(ang + half * 0.7) * (r - SS * 2))
        d.polygon([a2, tip2, b2], fill=color + (255,))


def _sheen(im: Image.Image, cx: float, cy: float, r: float, alpha: int) -> None:
    """Faixa de brilho de laca no terco de cima da face, recortada pelo disco."""
    if alpha <= 0:
        return
    d = int(round(r * 2))
    layer = Image.new("RGBA", (d, d), (0, 0, 0, 0))
    ld = ImageDraw.Draw(layer)
    band = int(d * 0.42)
    for i in range(band):
        a = int(alpha * (1.0 - i / max(1, band - 1)) ** 1.6)
        ld.line([(0, i), (d, i)], fill=CREAM + (a,))
    layer = layer.filter(ImageFilter.GaussianBlur(radius=SS * 2))
    layer.putalpha(Image.composite(layer.getchannel("A"), Image.new("L", (d, d), 0), _circle_mask(d, d)))
    im.alpha_composite(layer, (int(round(cx - r)), int(round(cy - r))))


def build_medal(size: int, boss: bool, ring: tuple, face: tuple, spike: tuple | None,
                sheen: int) -> Image.Image:
    S = size * SS
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    cx = cy = S / 2
    outer = S * (0.36 if boss else 0.44)

    # Sombra de contato (deslocada para baixo e borrada).
    shadow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    _disc(shadow, cx, cy + SS * 4, outer + SS * 2, INK + (150,))
    im.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(radius=SS * 4)))

    if spike is not None:
        _spikes(im, cx, cy, outer, spike)

    _disc(im, cx, cy, outer, INK + (255,))
    ring_r = outer - SS * 2
    _gradient_disc(im, cx, cy, ring_r, ring[0], ring[1])
    # Fio escuro entre o anel e a face (gravacao).
    groove_r = ring_r - outer * 0.13
    _disc(im, cx, cy, groove_r, INK + (200,))
    face_r = groove_r - SS * 2
    _gradient_disc(im, cx, cy, face_r, face[0], face[1])
    _sheen(im, cx, cy, face_r, sheen)
    # Bisel claro logo dentro da face.
    d = ImageDraw.Draw(im)
    bz = face_r - SS * 2
    d.ellipse((cx - bz, cy - bz, cx + bz, cy + bz), outline=CREAM + (34,), width=SS)
    return im.resize((size, size), Image.LANCZOS)


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    for name, size, boss, ring, face, spike, sheen in MEDALS:
        img = build_medal(size, boss, ring, face, spike, sheen)
        path = os.path.join(OUT_DIR, f"medal_{name}.png")
        img.save(path, "PNG", optimize=True)
        print("medal", path, img.size)
    print(f"DONE — {len(MEDALS)} arquivos em {OUT_DIR}")


if __name__ == "__main__":
    main()
