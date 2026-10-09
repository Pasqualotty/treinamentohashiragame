# -*- coding: utf-8 -*-
"""Remove a franja magenta (#FF00FF mal removido) das bordas dos PNG de assets/modes.

Determinístico: só mexe numa faixa de BAND px junto da transparência.
- magenta forte (r>150, b>150, g<120) em qualquer ponto -> alpha 0
- magenta fraco (r e b acima do verde) na faixa -> despill: r,b limitados ao verde
Uso: python tools/despill_modes.py  (rodar UMA vez sobre o original; rodar de novo corrói mais o halo do pad de vida)
"""
from __future__ import annotations
from pathlib import Path
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
FOLDERS = [ROOT / "assets/modes/brawl", ROOT / "assets/modes/duel"]
BAND = 6


def edge_band(alpha: np.ndarray, band: int) -> np.ndarray:
    """True nos pixels a até `band` px (4-vizinhos) de um pixel quase transparente."""
    out = alpha < 64
    for _ in range(band):
        grown = out.copy()
        grown[1:, :] |= out[:-1, :]
        grown[:-1, :] |= out[1:, :]
        grown[:, 1:] |= out[:, :-1]
        grown[:, :-1] |= out[:, 1:]
        out = grown
    return out


def despill(im: Image.Image) -> tuple[Image.Image, int]:
    arr = np.array(im.convert("RGBA"))
    r = arr[:, :, 0].astype(np.int16)
    g = arr[:, :, 1].astype(np.int16)
    b = arr[:, :, 2].astype(np.int16)
    a = arr[:, :, 3]
    band = edge_band(a, BAND) & (a > 0)
    strong = (a > 0) & (r > 150) & (b > 150) & (g < 120)
    strong |= band & (r > 170) & (b > 90) & (g < 110) & (b > g + 30)
    weak = band & ~strong & (r > g + 25) & (b > g + 25)
    arr[:, :, 3][strong] = 0
    arr[:, :, 0][weak] = np.minimum(r, g + 10)[weak].astype(np.uint8)
    arr[:, :, 2][weak] = np.minimum(b, g + 10)[weak].astype(np.uint8)
    return Image.fromarray(arr), int(strong.sum() + weak.sum())


def main() -> None:
    for folder in FOLDERS:
        for p in sorted(folder.glob("*.png")):
            out, n = despill(Image.open(p))
            if n:
                out.save(p, "PNG")
            print("OK" if n else "--", p.relative_to(ROOT), n)


if __name__ == "__main__":
    main()
