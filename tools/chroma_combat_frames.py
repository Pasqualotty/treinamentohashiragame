# -*- coding: utf-8 -*-
"""Chroma #FF00FF (+ near-black bg) -> alpha for combat player frames."""
from __future__ import annotations
from pathlib import Path
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
COMBAT = ROOT / "assets/characters/player/combat"

def chroma_key(im: Image.Image) -> Image.Image:
    arr = np.array(im.convert("RGBA"))
    r, g, b = arr[:,:,0].astype(np.int16), arr[:,:,1].astype(np.int16), arr[:,:,2].astype(np.int16)
    mag = (r > 180) & (b > 180) & (g < 130)
    black = (r < 18) & (g < 18) & (b < 18)
    mask2 = (r > 150) & (b > 150) & (g < 160)
    dominate = (r + b) > (g * 2 + 40)
    alpha = arr[:,:,3].copy()
    alpha[mag | black | (mask2 & dominate)] = 0
    arr[:,:,3] = alpha
    return Image.fromarray(arr)

def crop_alpha(im: Image.Image, pad: int = 6) -> Image.Image:
    arr = np.array(im)
    ys, xs = np.where(arr[:,:,3] > 10)
    if len(xs) == 0:
        return im
    x0, x1 = max(0, int(xs.min()) - pad), min(im.width - 1, int(xs.max()) + pad)
    y0, y1 = max(0, int(ys.min()) - pad), min(im.height - 1, int(ys.max()) + pad)
    return im.crop((x0, y0, x1 + 1, y1 + 1))

def normalize_canvas(im: Image.Image, size=(512, 512)) -> Image.Image:
    im = crop_alpha(im, pad=8)
    tw, th = size
    w, h = im.size
    scale = min((tw * 0.88) / w, (th * 0.92) / h)
    nw, nh = max(1, int(w * scale)), max(1, int(h * scale))
    im = im.resize((nw, nh), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    canvas.paste(im, ((tw - nw) // 2, th - nh - int(th * 0.04)), im)
    return canvas

def process_tree(folder: Path) -> int:
    n = 0
    for p in sorted(folder.rglob("*.png")):
        if p.name.endswith(".import"):
            continue
        im = normalize_canvas(chroma_key(Image.open(p)))
        im.save(p, "PNG")
        n += 1
        print("OK", p.relative_to(ROOT))
    return n

if __name__ == "__main__":
    count = process_tree(COMBAT)
    print(f"processed {count} frames under {COMBAT.relative_to(ROOT)}")
