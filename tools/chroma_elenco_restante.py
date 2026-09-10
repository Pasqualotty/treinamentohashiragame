#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""PNG real + chroma + canvas para o elenco restante (11 ids).

Imagine entrega JPEG com extensão .png e fundo rosa-magenta (não #FF00FF).
Combate: SEM flip default. Flip só se o id/anim estiver em --flip
(depois de ler o PNG no disco). Não reusa chroma_character_pack.py.
Não toca pastas do quarteto. Não reroda gen_character_resources.py.
"""
from __future__ import annotations

import argparse
import shutil
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
# Staging JPEG NÃO pode ficar dentro do projeto Godot (ERR_FILE_CORRUPT no --import).
STAGING_DIRS = [
    Path(
        r"C:\Users\mathe\.cursor\projects\c-Users-mathe-Documents-Pasqualotti-Studios-Demon-Slayer-Treinamento-hashira\assets"
    ),
    Path(r"C:\Users\mathe\AppData\Local\Temp\elenco-restante-staging"),
]
PNG_MAGIC = b"\x89PNG\r\n\x1a\n"

HUB_SIZE = (640, 900)
COMBAT_SIZE = (512, 512)
PORTRAIT_SIZE = (512, 512)

IDS = (
    "kanao",
    "shinobu",
    "uzui",
    "rengoku",
    "tomioka",
    "obanai",
    "tokito",
    "sanemi",
    "gyomei",
    "yoriichi",
    "muzan",
)

# src filename in staging -> (dest relative to ROOT, kind)
# kind: hub | portrait | combat
POSE_MAP: list[tuple[str, str, str, str]] = []
for _id in IDS:
    POSE_MAP.extend(
        [
            (f"{_id}_front_base.png", f"assets/characters/{_id}/hub_idle/00.png", "hub", _id),
            (f"{_id}_hub_blink.png", f"assets/characters/{_id}/hub_idle/03.png", "hub", _id),
            (f"{_id}_portrait.png", f"assets/characters/{_id}/portrait.png", "portrait", _id),
            (f"{_id}_idle_side.png", f"assets/characters/{_id}/combat/idle_side/00.png", "combat", _id),
            (f"{_id}_run.png", f"assets/characters/{_id}/combat/run/00.png", "combat", _id),
            (f"{_id}_attack.png", f"assets/characters/{_id}/combat/attack/00.png", "combat", _id),
            (f"{_id}_hurt.png", f"assets/characters/{_id}/combat/hurt/00.png", "combat", _id),
        ]
    )


def assert_png(path: Path) -> None:
    head = path.read_bytes()[:8]
    if head != PNG_MAGIC:
        raise SystemExit(f"not a real PNG: {path} header={head.hex()}")


def chroma_key(im: Image.Image) -> Image.Image:
    arr = np.array(im.convert("RGBA"))
    r = arr[:, :, 0].astype(np.int16)
    g = arr[:, :, 1].astype(np.int16)
    b = arr[:, :, 2].astype(np.int16)
    mag = (r > 180) & (b > 180) & (g < 130)
    hot_pink = (r > 200) & (g < 45) & (b > 90)
    black = (r < 18) & (g < 18) & (b < 18)
    mask2 = (r > 150) & (b > 150) & (g < 160)
    dominate = (r + b) > (g * 2 + 40)
    alpha = arr[:, :, 3].copy()
    alpha[mag | hot_pink | black | (mask2 & dominate)] = 0
    arr[:, :, 3] = alpha
    return Image.fromarray(arr)


def crop_alpha(im: Image.Image, pad: int = 6) -> Image.Image:
    arr = np.array(im)
    ys, xs = np.where(arr[:, :, 3] > 10)
    if len(xs) == 0:
        return im
    x0 = max(0, int(xs.min()) - pad)
    x1 = min(im.width - 1, int(xs.max()) + pad)
    y0 = max(0, int(ys.min()) - pad)
    y1 = min(im.height - 1, int(ys.max()) + pad)
    return im.crop((x0, y0, x1 + 1, y1 + 1))


def _fit(im: Image.Image, size: tuple[int, int], feet_bottom: bool) -> Image.Image:
    im = crop_alpha(im, pad=8)
    tw, th = size
    w, h = im.size
    margin_w, margin_h = 0.88, 0.92
    scale = min((tw * margin_w) / max(w, 1), (th * margin_h) / max(h, 1))
    nw, nh = max(1, int(w * scale)), max(1, int(h * scale))
    im = im.resize((nw, nh), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    x = (tw - nw) // 2
    y = (th - nh - int(th * 0.04)) if feet_bottom else (th - nh) // 2
    canvas.paste(im, (x, max(0, y)), im)
    return canvas


def normalize(im: Image.Image, kind: str, do_flip: bool) -> Image.Image:
    keyed = chroma_key(im)
    if kind == "hub":
        return _fit(keyed, HUB_SIZE, feet_bottom=True)
    if kind == "combat":
        if do_flip:
            keyed = keyed.transpose(Image.FLIP_LEFT_RIGHT)
        return _fit(keyed, COMBAT_SIZE, feet_bottom=True)
    return _fit(keyed, PORTRAIT_SIZE, feet_bottom=False)


def find_src(name: str) -> Path | None:
    for folder in STAGING_DIRS:
        cand = folder / name
        if cand.is_file():
            return cand
    return None


def pose_key(src_name: str, char_id: str) -> str:
    # kanao_idle_side.png -> kanao/idle_side
    stem = src_name.removesuffix(".png")
    prefix = f"{char_id}_"
    if not stem.startswith(prefix):
        return f"{char_id}/{stem}"
    pose = stem[len(prefix) :]
    if pose == "front_base":
        return f"{char_id}/hub00"
    if pose == "hub_blink":
        return f"{char_id}/hub03"
    return f"{char_id}/{pose}"


def process_one(src: Path, dest: Path, kind: str, do_flip: bool) -> None:
    im = Image.open(src).convert("RGBA")
    out = normalize(im, kind, do_flip)
    dest.parent.mkdir(parents=True, exist_ok=True)
    out.save(dest, "PNG")
    assert_png(dest)
    review = ROOT / "assets/pack_elenco_restante" / dest.relative_to(ROOT / "assets/characters")
    review.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(dest, review)


def parse_flip_set(raw: str) -> set[str]:
    out: set[str] = set()
    if not raw.strip():
        return out
    for token in raw.split(","):
        token = token.strip().replace("\\", "/")
        if token:
            out.add(token)
    return out


def main() -> None:
    parser = argparse.ArgumentParser(description="Chroma elenco restante (flip condicional).")
    parser.add_argument(
        "--flip",
        default="",
        help="Lista csv de poses de combate a espelhar, ex: kanao/idle_side,obanai/run",
    )
    args = parser.parse_args()
    flip_set = parse_flip_set(args.flip)

    missing: list[str] = []
    done = 0
    flipped: list[str] = []
    for src_name, rel, kind, char_id in POSE_MAP:
        src = find_src(src_name)
        if src is None:
            missing.append(src_name)
            continue
        key = pose_key(src_name, char_id)
        do_flip = kind == "combat" and key in flip_set
        dest = ROOT / rel
        process_one(src, dest, kind, do_flip)
        tag = " FLIP" if do_flip else ""
        print("OK", rel, dest.stat().st_size, tag)
        if do_flip:
            flipped.append(key)
        done += 1
    if missing:
        print("MISSING", len(missing), missing)
        raise SystemExit(2)
    print(f"processed {done}")
    print("flipped:", ",".join(flipped) if flipped else "(none)")


if __name__ == "__main__":
    main()
