"""Process Imagine outputs into engine-ready PNGs for arte-mvp pack."""
from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image

RAW = Path(
    r"C:\Users\mathe\.grok\sessions\C%3A%5CUsers%5Cmathe%5CDocuments%5Chashira-arte-mvp"
    r"\019fd441-f54a-7522-87a6-f8a275f08774\images"
)
ROOT = Path(r"C:\Users\mathe\Documents\hashira-arte-mvp")


def assert_png(path: Path) -> None:
    with open(path, "rb") as f:
        assert f.read(8) == b"\x89PNG\r\n\x1a\n", f"not real PNG: {path}"


def ensure_png_bg(src: Path, dst: Path, size: tuple[int, int] = (1280, 720)) -> None:
    im = Image.open(src).convert("RGB")
    if im.size != size:
        im = im.resize(size, Image.Resampling.LANCZOS)
    dst.parent.mkdir(parents=True, exist_ok=True)
    im.save(dst, "PNG")
    assert_png(dst)
    print(f"BG   {dst.relative_to(ROOT)} {im.size}")


def chroma_key(im: Image.Image, thr_rb: int = 180, thr_g: int = 130) -> Image.Image:
    arr = np.array(im.convert("RGBA"))
    r, g, b = arr[:, :, 0], arr[:, :, 1], arr[:, :, 2]
    mask = (r > thr_rb) & (b > thr_rb) & (g < thr_g)
    arr[mask, 3] = 0
    # near-magenta fringe
    mask2 = (r > 150) & (b > 150) & (g < 160) & (arr[:, :, 3] > 0)
    # only kill if r and b clearly dominate green
    dominate = (r.astype(int) + b.astype(int)) > (g.astype(int) * 2 + 40)
    arr[mask2 & dominate, 3] = 0
    return Image.fromarray(arr)


def crop_alpha(im: Image.Image, pad: int = 4) -> Image.Image:
    arr = np.array(im)
    alpha = arr[:, :, 3]
    ys, xs = np.where(alpha > 10)
    if len(xs) == 0:
        return im
    x0, x1 = int(xs.min()), int(xs.max())
    y0, y1 = int(ys.min()), int(ys.max())
    x0 = max(0, x0 - pad)
    y0 = max(0, y0 - pad)
    x1 = min(im.width - 1, x1 + pad)
    y1 = min(im.height - 1, y1 + pad)
    return im.crop((x0, y0, x1 + 1, y1 + 1))


def save_icon(src: Path, dst: Path, size: int = 128) -> None:
    im = chroma_key(Image.open(src))
    im = crop_alpha(im, pad=8)
    w, h = im.size
    side = max(w, h)
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.paste(im, ((side - w) // 2, (side - h) // 2), im)
    canvas = canvas.resize((size, size), Image.Resampling.LANCZOS)
    dst.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(dst, "PNG")
    assert_png(dst)
    print(f"ICON {dst.relative_to(ROOT)} {canvas.size}")


def save_char(src: Path, dst: Path, max_side: int = 512) -> None:
    im = chroma_key(Image.open(src))
    im = crop_alpha(im, pad=6)
    w, h = im.size
    scale = max_side / max(w, h)
    if scale < 1:
        im = im.resize((int(w * scale), int(h * scale)), Image.Resampling.LANCZOS)
    dst.parent.mkdir(parents=True, exist_ok=True)
    im.save(dst, "PNG")
    assert_png(dst)
    print(f"CHAR {dst.relative_to(ROOT)} {im.size}")


def save_tile_strip(src: Path, dst: Path) -> None:
    im = Image.open(src).convert("RGBA")
    arr = np.array(im)
    r = arr[:, :, 0].astype(int)
    g = arr[:, :, 1].astype(int)
    b = arr[:, :, 2].astype(int)
    is_sky = (b > r + 20) & (b > g + 20) & (r < 90) & (g < 80)
    row_content = (~is_sky).mean(axis=1) > 0.15
    ys = np.where(row_content)[0]
    if len(ys) == 0:
        crop = im
    else:
        y0 = max(0, int(ys.min()) - 2)
        y1 = min(im.height, int(ys.max()) + 3)
        crop = im.crop((0, y0, im.width, y1))

    h = 128
    w = int(crop.width * (h / crop.height))
    w = max(256, (w // 64) * 64)
    crop = crop.resize((w, h), Image.Resampling.LANCZOS)
    a = np.array(crop)
    rr, gg, bb = a[:, :, 0].astype(int), a[:, :, 1].astype(int), a[:, :, 2].astype(int)
    sky2 = (bb > rr + 25) & (bb > gg + 25) & (rr < 100) & (gg < 90)
    a[sky2, 3] = 0
    out = Image.fromarray(a)
    dst.parent.mkdir(parents=True, exist_ok=True)
    out.save(dst, "PNG")
    assert_png(dst)
    print(f"TILE {dst.relative_to(ROOT)} {out.size}")


def main() -> None:
    ensure_png_bg(RAW / "4.jpg", ROOT / "assets/ui/map/world_map_w1.png")
    ensure_png_bg(RAW / "2.jpg", ROOT / "assets/backgrounds/w1/stage_forest.png")
    ensure_png_bg(RAW / "1.jpg", ROOT / "assets/backgrounds/w1/stage_village.png")
    ensure_png_bg(RAW / "3.jpg", ROOT / "assets/backgrounds/w1/stage_mountain.png")

    save_icon(RAW / "5.jpg", ROOT / "assets/ui/map/node_stage.png", 128)
    save_icon(RAW / "6.jpg", ROOT / "assets/ui/map/node_boss_lock.png", 128)
    save_icon(RAW / "9.jpg", ROOT / "assets/ui/map/node_cleared.png", 128)

    save_tile_strip(RAW / "7.jpg", ROOT / "assets/tiles/w1/ground_platform_strip.png")

    # prefer fixed run (11) if present
    run_src = RAW / "11.jpg" if (RAW / "11.jpg").exists() else RAW / "10.jpg"
    save_char(run_src, ROOT / "assets/characters/player/combat/tanjiro_run.png", 512)
    save_char(RAW / "8.jpg", ROOT / "assets/characters/player/combat/tanjiro_attack_slash.png", 512)
    print("OK")


if __name__ == "__main__":
    main()
