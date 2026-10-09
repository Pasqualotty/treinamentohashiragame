#!/usr/bin/env python3
"""Gera os tiles de chão por mundo (W1..W5), 100% determinístico (sem IA).

Saída: assets/tiles/w{1..5}/ground_top.png (256x64, superfície com "lábio")
       assets/tiles/w{1..5}/ground_fill.png (256x256, miolo, continua o top).

Todo campo é periódico (ruído e voronoi com wrap) -> o tile emenda consigo
mesmo na horizontal (e o miolo também na vertical). `verify_wrap()` roda no
fim e aborta se a diferença média entre a coluna 0 e a última passar do
limite. Re-executar gera bytes idênticos (RNG com seed fixa por mundo).

Uso:  python tools/gen_world_ground.py
"""
from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "tiles"
W = 256
TOP_H = 64
FILL_H = 256
# Limite do teste de emenda (média por canal, 0..255). O smoke do Godot usa 8.
WRAP_LIMIT = 8.0


def _rng(world: int) -> np.random.Generator:
    return np.random.default_rng(1000 + world)


def pnoise(rng, w, h, cx, cy):
    """Ruído de valor periódico em [0,1], grade cx*cy, interpolação suave."""
    grid = rng.random((cy, cx))
    ys = np.arange(h) * cy / h
    xs = np.arange(w) * cx / w
    y0 = np.floor(ys).astype(int)
    x0 = np.floor(xs).astype(int)
    fy = ys - y0
    fx = xs - x0
    fy = fy * fy * (3 - 2 * fy)
    fx = fx * fx * (3 - 2 * fx)
    y1 = (y0 + 1) % cy
    x1 = (x0 + 1) % cx
    y0 %= cy
    x0 %= cx
    a = grid[np.ix_(y0, x0)]
    b = grid[np.ix_(y0, x1)]
    c = grid[np.ix_(y1, x0)]
    d = grid[np.ix_(y1, x1)]
    top = a * (1 - fx)[None, :] + b * fx[None, :]
    bot = c * (1 - fx)[None, :] + d * fx[None, :]
    return top * (1 - fy)[:, None] + bot * fy[:, None]


def fbm(rng, w, h, cx, cy, octaves=3):
    total = np.zeros((h, w))
    amp = 1.0
    norm = 0.0
    for o in range(octaves):
        total += amp * pnoise(rng, w, h, cx * (2**o), cy * (2**o))
        norm += amp
        amp *= 0.5
    return total / norm


def voronoi(rng, w, h, nx, ny, ystretch=1.0):
    """Voronoi periódico. Devolve (id da célula, d2-d1 em px)."""
    n = nx * ny
    # Pontos jitterados numa grade -> células regulares (lajes), não aleatórias.
    gx, gy = np.meshgrid(np.arange(nx), np.arange(ny))
    px = ((gx.ravel() + 0.2 + 0.6 * rng.random(n)) * (w / nx))
    py = ((gy.ravel() + 0.2 + 0.6 * rng.random(n)) * (h / ny))
    yy, xx = np.mgrid[0:h, 0:w]
    dists = np.empty((n, h, w))
    for i in range(n):
        dx = np.abs(xx - px[i])
        dx = np.minimum(dx, w - dx)
        dy = np.abs(yy - py[i])
        dy = np.minimum(dy, h - dy) * ystretch
        dists[i] = np.sqrt(dx * dx + dy * dy)
    order = np.sort(dists, axis=0)
    cell = np.argmin(dists, axis=0)
    return cell, order[1] - order[0]


def ramp(t, stops):
    """t em [0,1] -> RGB interpolando `stops` [(pos, (r,g,b))...]."""
    t = np.clip(t, 0, 1)
    pos = [s[0] for s in stops]
    out = np.zeros(t.shape + (3,))
    for c in range(3):
        out[..., c] = np.interp(t, pos, [s[1][c] for s in stops])
    return out


def wrap_dx(xx, cx, w):
    d = np.abs(xx - cx)
    return np.minimum(d, w - d)


# ---------------------------------------------------------------- mundos ----
# Cada função devolve o "corpo" 256x256 (periódico nos dois eixos) em float 0..255.
# O top = linhas 0..63 + lábio; o fill = corpo rolado 64 linhas (continua o top).

def body_w1(rng):
    """Pedra de trilha com musgo e folhas (combina com o bambuzal)."""
    cell, edge = voronoi(rng, W, FILL_H, 5, 3, ystretch=1.35)
    n = fbm(rng, W, FILL_H, 6, 6)
    tone = rng.random(15)[cell]
    t = 0.30 + 0.35 * tone + 0.25 * (n - 0.5)
    img = ramp(t, [(0.0, (34, 42, 52)), (0.5, (66, 78, 84)), (1.0, (98, 108, 108))])
    # juntas escuras (com leve esverdeado de musgo)
    joint = np.clip(1 - edge / 3.2, 0, 1)[..., None]
    img = img * (1 - joint * 0.78) + np.array([14, 22, 20]) * joint * 0.78
    # musgo em manchas, sobretudo perto das juntas
    moss = np.clip((fbm(rng, W, FILL_H, 5, 5) - 0.52) * 4 + joint[..., 0] * 0.6, 0, 1)[..., None]
    img = img * (1 - moss * 0.55) + np.array([52, 92, 58]) * moss * 0.55
    return img


def body_w2(rng):
    """Chapa de aço com rebites (piso do vagão)."""
    n = fbm(rng, W, FILL_H, 8, 8)
    yy, xx = np.mgrid[0:FILL_H, 0:W]
    panel = 128
    ph = 64
    px = (xx + 1) % panel  # +1: a fresta cobre as colunas 255 e 0 (emenda no meio dela)
    py = yy % ph
    base = 0.45 + 0.25 * (n - 0.5) + 0.04 * (((xx // panel) + (yy // ph)) % 2)
    img = ramp(base, [(0.0, (34, 40, 52)), (0.5, (70, 80, 96)), (1.0, (112, 122, 138))])
    # frestas entre chapas
    seam = ((px < 2) | (py < 2)).astype(float)[..., None]
    img = img * (1 - seam * 0.7)
    # realce de borda (chanfro) logo após a fresta
    bevel = (((px >= 2) & (px < 4)) | ((py >= 2) & (py < 4))).astype(float)[..., None]
    img = img + bevel * 16
    # rebites nos cantos de cada chapa
    for cx, cy in ((10, 10), (panel - 11, 10), (10, ph - 11), (panel - 11, ph - 11)):
        d = np.sqrt((px - cx) ** 2 + (py - cy) ** 2)
        rivet = np.clip(1 - d / 3.4, 0, 1)[..., None]
        hi = np.clip(1 - np.sqrt((px - cx + 1) ** 2 + (py - cy + 1) ** 2) / 1.6, 0, 1)[..., None]
        img = img * (1 - rivet * 0.5) + rivet * 0.5 * np.array([58, 64, 78]) + hi * 40
    # riscos horizontais de desgaste
    scratch = (pnoise(rng, W, FILL_H, 2, 60) > 0.78).astype(float)[..., None]
    return img + scratch * 10


def body_w3(rng):
    """Paralelepípedo do distrito, com reflexo quente de lanterna."""
    cell, edge = voronoi(rng, W, FILL_H, 8, 6, ystretch=1.25)
    n = fbm(rng, W, FILL_H, 8, 8)
    tone = rng.random(48)[cell]
    t = 0.28 + 0.4 * tone + 0.2 * (n - 0.5)
    img = ramp(t, [(0.0, (40, 30, 44)), (0.5, (86, 66, 72)), (1.0, (132, 102, 96))])
    joint = np.clip(1 - edge / 2.6, 0, 1)[..., None]
    img = img * (1 - joint * 0.8) + np.array([16, 10, 18]) * joint * 0.8
    # pedras arredondadas: brilho no centro da pedra
    round_hi = np.clip(edge / 9.0, 0, 1)[..., None]
    img = img * (0.82 + 0.26 * round_hi)
    # poças de luz âmbar (lanternas), periódicas
    yy, xx = np.mgrid[0:FILL_H, 0:W]
    glow = np.zeros((FILL_H, W))
    for gx, gy, r in ((40, 30, 46), (170, 14, 54), (220, 120, 40), (96, 180, 50)):
        dx = wrap_dx(xx, gx, W)
        dy = wrap_dx(yy, gy, FILL_H)
        glow += np.exp(-(dx * dx + dy * dy) / (2 * (r * 0.5) ** 2))
    glow = np.clip(glow, 0, 1)[..., None]
    return img + glow * np.array([70, 42, 10]) * (0.4 + 0.6 * round_hi)


def body_w4(rng):
    """Blocos de pedra escura com juntas (castelo), aparelho em amarração."""
    yy, xx = np.mgrid[0:FILL_H, 0:W]
    bh = 32
    bw = 64
    row = yy // bh
    off = (row % 2) * (bw // 2)
    px = (xx + 1 + off) % bw  # +1: junta vertical atravessa a emenda do tile
    py = yy % bh
    bid = ((xx + 1 + off) // bw + row * 7) % 32
    tone = rng.random(32)[bid]
    n = fbm(rng, W, FILL_H, 10, 10)
    t = 0.25 + 0.3 * tone + 0.3 * (n - 0.5)
    img = ramp(t, [(0.0, (22, 24, 40)), (0.5, (48, 52, 74)), (1.0, (82, 86, 110))])
    joint = ((px < 2) | (py < 2)).astype(float)[..., None]
    img = img * (1 - joint * 0.8) + np.array([8, 8, 16]) * joint * 0.8
    lit = (((px >= 2) & (px < 4)) | ((py >= 2) & (py < 4))).astype(float)[..., None]
    img = img + lit * 12
    # lascas e rachaduras finas
    chips = (pnoise(rng, W, FILL_H, 40, 40) > 0.86).astype(float)[..., None]
    return img - chips * 14


def body_w5(rng):
    """Obsidiana rachada com brasa nas fissuras (Céu Vermelho)."""
    cell, edge = voronoi(rng, W, FILL_H, 5, 4, ystretch=1.2)
    n = fbm(rng, W, FILL_H, 8, 8)
    tone = rng.random(20)[cell]
    t = 0.18 + 0.25 * tone + 0.25 * (n - 0.5)
    img = ramp(t, [(0.0, (12, 8, 14)), (0.5, (32, 20, 30)), (1.0, (62, 38, 48))])
    # fissura: núcleo bem quente, halo laranja-avermelhado ao redor
    core = np.clip(1 - edge / 1.8, 0, 1)[..., None]
    halo = np.clip(1 - edge / 7.0, 0, 1)[..., None] ** 2
    ember = ramp(np.clip(n * 1.4, 0, 1), [(0.0, (150, 30, 20)), (1.0, (255, 150, 50))])
    img = img + halo * np.array([90, 20, 8]) * 0.55
    img = img * (1 - core) + ember * core
    return img


BODIES = {1: body_w1, 2: body_w2, 3: body_w3, 4: body_w4, 5: body_w5}


# ---------------------------------------------------------------- lábios ----
def lip_w1(img, rng):
    """Musgo + folhas caídas na borda da trilha."""
    n1 = pnoise(rng, W, 1, 12, 1)[0]
    depth = (5 + n1 * 7).astype(int)  # espessura do musgo por coluna
    yy = np.arange(TOP_H)[:, None]
    moss = (yy < depth[None, :]).astype(float)[..., None]
    shade = ramp(1 - yy / 12.0, [(0, (38, 70, 46)), (1, (84, 128, 70))])
    img = img * (1 - moss) + shade * moss
    # franja de capim: pontinhas claras acima da borda
    tuft = (pnoise(rng, W, 1, 40, 1)[0] > 0.62)
    for x in np.nonzero(tuft)[0]:
        for k in range(2):
            img[k, x] = (96, 148, 78)
    # folhas (carmesim/ouro queimado) espalhadas, com wrap
    yy2, xx2 = np.mgrid[0:TOP_H, 0:W]
    colors = [(150, 52, 44), (178, 110, 40), (120, 44, 40)]
    for i in range(7):
        cx = rng.integers(0, W)
        cy = rng.integers(3, 12)
        ang = rng.random() * np.pi
        dx = ((xx2 - cx + W / 2) % W) - W / 2
        dy = yy2 - cy
        u = dx * np.cos(ang) + dy * np.sin(ang)
        v = -dx * np.sin(ang) + dy * np.cos(ang)
        m = ((u / 5.0) ** 2 + (v / 2.2) ** 2 < 1)[..., None]
        img = np.where(m, np.array(colors[i % 3]), img)
    return img


def lip_w2(img, rng):
    """Trilho de aço corrido no topo (linha de luz azulada)."""
    yy = np.arange(TOP_H)[:, None] * np.ones((1, W))
    rail = ((yy >= 0) & (yy < 7))[..., None]
    shade = ramp(1 - yy / 7.0, [(0, (70, 82, 100)), (1, (150, 166, 188))])
    img = np.where(rail, shade, img)
    seam = ((yy >= 7) & (yy < 9))[..., None]
    img = np.where(seam, img * 0.35, img)
    # parafusos do trilho a cada 64 px
    xx = np.arange(W)[None, :] * np.ones((TOP_H, 1))
    for cx in range(16, W, 64):
        d = np.sqrt((xx - cx) ** 2 + (yy - 3.5) ** 2)
        img = np.where((d < 2.2)[..., None], np.array([44, 52, 66]), img)
    return img


def lip_w3(img, rng):
    """Meio-fio quente: faixa de pedra mais clara iluminada pela lanterna."""
    yy = np.arange(TOP_H)[:, None] * np.ones((1, W))
    n1 = pnoise(rng, W, 1, 8, 1)[0]
    curb = (yy < (6 + n1 * 3)[None, :])[..., None]
    shade = ramp(1 - yy / 9.0, [(0, (116, 82, 70)), (1, (190, 140, 96))])
    img = np.where(curb, shade, img)
    seam = ((yy >= 7) & (yy < 10))[..., None]
    return np.where(seam & ~curb, img * 0.55, img)


def lip_w4(img, rng):
    """Borda de laje: faixa lisa de pedra com aresta clara."""
    yy = np.arange(TOP_H)[:, None] * np.ones((1, W))
    slab = (yy < 6)[..., None]
    shade = ramp(1 - yy / 6.0, [(0, (58, 62, 86)), (1, (112, 118, 148))])
    img = np.where(slab, shade, img)
    seam = ((yy >= 6) & (yy < 8))[..., None]
    img = np.where(seam, img * 0.4, img)
    # juntas verticais da laje a cada 128 px
    xx = np.arange(W)[None, :] * np.ones((TOP_H, 1))
    vj = (((xx + 1) % 128) < 2) & (yy < 6)
    return np.where(vj[..., None], img * 0.45, img)


def lip_w5(img, rng):
    """Crosta de obsidiana polida com veio de brasa logo abaixo."""
    yy = np.arange(TOP_H)[:, None] * np.ones((1, W))
    crust = (yy < 5)[..., None]
    shade = ramp(1 - yy / 5.0, [(0, (40, 26, 38)), (1, (96, 60, 70))])
    img = np.where(crust, shade, img)
    n = pnoise(rng, W, 1, 10, 1)[0]
    vein = np.exp(-((yy - 6.5) ** 2) / 2.2) * (0.45 + 0.55 * n[None, :])
    return img + vein[..., None] * np.array([230, 90, 30]) * 0.55


LIPS = {1: lip_w1, 2: lip_w2, 3: lip_w3, 4: lip_w4, 5: lip_w5}


def to_image(arr):
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB")


def build_world(world: int):
    rng = _rng(world)
    body = BODIES[world](rng)
    # Suaviza 1px na horizontal e vertical COM wrap, tirando o serrilhado cru.
    body = (body * 2 + np.roll(body, 1, 1) + np.roll(body, -1, 1)) / 4
    top = LIPS[world](body[:TOP_H].copy(), _rng(world + 50))
    fill = np.roll(body, -TOP_H, axis=0)
    return to_image(top), to_image(fill)


def verify_wrap(path: Path) -> float:
    a = np.asarray(Image.open(path).convert("RGB")).astype(float)
    diff = float(np.abs(a[:, 0] - a[:, -1]).mean())
    if diff >= WRAP_LIMIT:
        raise SystemExit(f"FALHA emenda {path}: diff={diff:.2f} >= {WRAP_LIMIT}")
    return diff


def main() -> int:
    for world in range(1, 6):
        folder = OUT / f"w{world}"
        folder.mkdir(parents=True, exist_ok=True)
        top, fill = build_world(world)
        top.save(folder / "ground_top.png", optimize=False)
        fill.save(folder / "ground_fill.png", optimize=False)
        d1 = verify_wrap(folder / "ground_top.png")
        d2 = verify_wrap(folder / "ground_fill.png")
        print(f"w{world}: top wrap={d1:.2f} fill wrap={d2:.2f}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
