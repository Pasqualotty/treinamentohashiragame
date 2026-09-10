#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""PNG real + chroma + canvas para packs de caçador (hub 640x900 / combate 512x512).

Imagine desta onda entregou JPEG com extensão .png e fundo rosa-magenta
(R alto, G~0, B 120–220) — não #FF00FF puro. Chroma cobre os dois.
Não reroda gen_character_resources.py.
"""
from __future__ import annotations

import shutil
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
STAGING_CURSOR = Path(
    r"C:\Users\mathe\.cursor\projects\c-Users-mathe-Documents-Pasqualotti-Studios-Demon-Slayer-Treinamento-hashira\assets"
)
PNG_MAGIC = b"\x89PNG\r\n\x1a\n"

HUB_SIZE = (640, 900)
COMBAT_SIZE = (512, 512)
PORTRAIT_SIZE = (512, 512)

# slug -> (src_name, dest relative to ROOT, kind)
PACK_MAP: list[tuple[str, str, str]] = [
    ("nezuko_front_base.png", "assets/characters/nezuko/hub_idle/00.png", "hub"),
    ("nezuko_hub_blink.png", "assets/characters/nezuko/hub_idle/03.png", "hub"),
    ("nezuko_portrait.png", "assets/characters/nezuko/portrait.png", "portrait"),
    ("nezuko_idle_side.png", "assets/characters/nezuko/combat/idle_side/00.png", "combat"),
    ("nezuko_run.png", "assets/characters/nezuko/combat/run/00.png", "combat"),
    ("nezuko_attack.png", "assets/characters/nezuko/combat/attack/00.png", "combat"),
    ("nezuko_hurt.png", "assets/characters/nezuko/combat/hurt/00.png", "combat"),
    ("zenitsu_front_base.png", "assets/characters/zenitsu/hub_idle/00.png", "hub"),
    ("zenitsu_hub_blink.png", "assets/characters/zenitsu/hub_idle/03.png", "hub"),
    ("zenitsu_portrait.png", "assets/characters/zenitsu/portrait.png", "portrait"),
    ("zenitsu_idle_side.png", "assets/characters/zenitsu/combat/idle_side/00.png", "combat"),
    ("zenitsu_run.png", "assets/characters/zenitsu/combat/run/00.png", "combat"),
    ("zenitsu_attack.png", "assets/characters/zenitsu/combat/attack/00.png", "combat"),
    ("zenitsu_hurt.png", "assets/characters/zenitsu/combat/hurt/00.png", "combat"),
    ("inosuke_front_base.png", "assets/characters/inosuke/hub_idle/00.png", "hub"),
    ("inosuke_hub_blink.png", "assets/characters/inosuke/hub_idle/03.png", "hub"),
    ("inosuke_portrait.png", "assets/characters/inosuke/portrait.png", "portrait"),
    ("inosuke_idle_side.png", "assets/characters/inosuke/combat/idle_side/00.png", "combat"),
    ("inosuke_run.png", "assets/characters/inosuke/combat/run/00.png", "combat"),
    ("inosuke_attack.png", "assets/characters/inosuke/combat/attack/00.png", "combat"),
    ("inosuke_hurt.png", "assets/characters/inosuke/combat/hurt/00.png", "combat"),
]


def assert_png(path: Path) -> None:
    head = path.read_bytes()[:8]
    if head != PNG_MAGIC:
        raise SystemExit(f"not a real PNG: {path} header={head.hex()}")


def chroma_key(im: Image.Image, key_black: bool = False) -> Image.Image:
    arr = np.array(im.convert("RGBA"))
    r = arr[:, :, 0].astype(np.int16)
    g = arr[:, :, 1].astype(np.int16)
    b = arr[:, :, 2].astype(np.int16)
    # Skill canônico #FF00FF
    mag = (r > 180) & (b > 180) & (g < 130)
    # Imagine desta onda: rosa quente (B às vezes < 180)
    hot_pink = (r > 200) & (g < 45) & (b > 90)
    mask2 = (r > 150) & (b > 150) & (g < 160)
    dominate = (r + b) > (g * 2 + 40)
    punch = mag | hot_pink | (mask2 & dominate)
    if key_black:
        black = (r < 18) & (g < 18) & (b < 18)
        punch = punch | black
    alpha = arr[:, :, 3].copy()
    alpha[punch] = 0
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


def normalize(
    im: Image.Image,
    kind: str,
    *,
    flip: bool = False,
    key_black: bool = False,
) -> Image.Image:
    keyed = chroma_key(im, key_black=key_black)
    # Default NÃO flipa. Onda 1 flipava todo combate e a 2ª passagem
    # inverte Nezuko run (já-esquerda). Flip só por arquivo, se o frame
    # NOVO nasceu olhando direita.
    if flip:
        keyed = keyed.transpose(Image.FLIP_LEFT_RIGHT)
    if kind == "hub":
        return _fit(keyed, HUB_SIZE, feet_bottom=True)
    if kind == "combat":
        return _fit(keyed, COMBAT_SIZE, feet_bottom=True)
    return _fit(keyed, PORTRAIT_SIZE, feet_bottom=False)


def make_tanjiro_portrait() -> Path:
    src = ROOT / "assets/characters/player/hub_idle/00.png"
    dst = ROOT / "assets/characters/tanjiro/portrait.png"
    im = Image.open(src).convert("RGBA")
    w, h = im.size
    crop = im.crop((int(w * 0.16), int(h * 0.02), int(w * 0.84), int(h * 0.50)))
    out = _fit(crop, PORTRAIT_SIZE, feet_bottom=False)
    dst.parent.mkdir(parents=True, exist_ok=True)
    out.save(dst, "PNG")
    assert_png(dst)
    return dst


def process_one(
    src: Path,
    dest: Path,
    kind: str,
    *,
    flip: bool = False,
    key_black: bool = False,
    review_root: str = "assets/pack_anim_quarteto",
) -> None:
    im = Image.open(src).convert("RGBA")
    out = normalize(im, kind, flip=flip, key_black=key_black)
    dest.parent.mkdir(parents=True, exist_ok=True)
    out.save(dest, "PNG")
    assert_png(dest)
    review = ROOT / review_root / dest.relative_to(ROOT / "assets/characters")
    review.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(dest, review)


def _process_v1_pack() -> None:
    """Onda 1 — NÃO rerodar nos 00 (fliparia Nezuko run de novo)."""
    missing: list[str] = []
    done = 0
    for src_name, rel, kind in PACK_MAP:
        src = STAGING_CURSOR / src_name
        if not src.exists():
            missing.append(src_name)
            continue
        dest = ROOT / rel
        # key_black+flip=True era o pipeline v1. Explicit — never the default.
        process_one(
            src,
            dest,
            kind,
            flip=(kind == "combat"),
            key_black=True,
            review_root="assets/pack_playtest_trio",
        )
        print("OK", rel, dest.stat().st_size)
        done += 1
    portrait = make_tanjiro_portrait()
    print("OK", portrait.relative_to(ROOT), portrait.stat().st_size)
    review_p = ROOT / "assets/pack_playtest_trio/tanjiro/portrait.png"
    review_p.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(portrait, review_p)
    if missing:
        print("MISSING", len(missing), missing)
        raise SystemExit(2)
    print(f"processed {done} staged + tanjiro portrait")


def main() -> None:
    import argparse

    p = argparse.ArgumentParser(
        description="PNG real + chroma + canvas. Default NÃO flipa e NÃO reprocessa 00."
    )
    p.add_argument("--src", type=Path, help="arquivo gerado (Imagine/JPEG ok)")
    p.add_argument("--dest", type=Path, help="destino relativo ao ROOT ou absoluto")
    p.add_argument("--kind", choices=("hub", "combat", "portrait"))
    p.add_argument(
        "--flip",
        action="store_true",
        default=False,
        help="FLIP_LEFT_RIGHT só neste arquivo (frame novo que nasceu à direita)",
    )
    p.add_argument(
        "--key-black",
        action="store_true",
        default=False,
        help="também chaveia RGB quase-preto (pipeline v1; perigoso em cabelo)",
    )
    p.add_argument(
        "--reprocess-v1",
        action="store_true",
        help="RERODA o PACK_MAP da onda 1 (00s). Perigoso — não usar nesta frente.",
    )
    args = p.parse_args()
    if args.reprocess_v1:
        _process_v1_pack()
        return
    if args.src is None or args.dest is None or args.kind is None:
        p.error("use --src --dest --kind (flip=false default). Sem --reprocess-v1.")
    dest = args.dest if args.dest.is_absolute() else ROOT / args.dest
    process_one(
        args.src,
        dest,
        args.kind,
        flip=args.flip,
        key_black=args.key_black,
    )
    print("OK", dest, dest.stat().st_size, "flip=", args.flip)


if __name__ == "__main__":
    main()
