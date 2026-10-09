"""Gera as variantes de oni (elite/charger/ranged + 5 bases de chefe) a partir de
`assets/characters/enemies/oni_weak_side.png`, sem IA e sem aleatoriedade solta:
re-executável, bytes idênticos. Foco na SILHUETA (chifres, capuz, ombros, inclinação),
não só na cor.

Uso: python tools/gen_oni_variants.py

Âncora comum: o corpo base tem pés em y=909 e centro x=512 (canvas 1024). Todas as
variantes preservam isso, então o .tscn posiciona qualquer uma com a mesma conta
(position.y = -(909-512)*scale). Imprime o bbox sólido de cada uma.
"""
import math
import random
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
DIR = ROOT / "assets" / "characters" / "enemies"
BASE = DIR / "oni_weak_side.png"
W = 1024
SS = 2  # supersample das camadas desenhadas
OUTLINE = (24, 14, 28, 255)
BONE = (236, 226, 200, 255)


# ---------------------------------------------------------------- cor
def _hsv(img):
    rgb = img.convert("RGB")
    return np.array(rgb.convert("HSV")).astype(np.float32), img.getchannel("A")


def _from_hsv(arr, alpha):
    rgb = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "HSV").convert("RGB")
    out = rgb.convert("RGBA")
    out.putalpha(alpha)
    return out


def _band(h, lo, hi):
    return (h >= lo / 360.0 * 255.0) & (h <= hi / 360.0 * 255.0)


def recolor(img, skin=None, cloth=None, band=None):
    """Troca o matiz por região (pele verde / pano roxo / faixa azul), preservando o
    sombreado. Cada alvo = (matiz°, mult_sat, soma_sat, mult_val)."""
    arr, alpha = _hsv(img)
    h, s, v = arr[..., 0], arr[..., 1], arr[..., 2]
    colorido = (s > 28) & (v > 40)
    regioes = [
        (skin, _band(h, 65, 160)),
        (band, _band(h, 205, 250)),
        (cloth, _band(h, 251, 330)),
    ]
    out = arr.copy()
    for alvo, faixa in regioes:
        if alvo is None:
            continue
        hue, sm, sa, vm = alvo
        m = colorido & faixa
        out[..., 0][m] = hue / 360.0 * 255.0
        out[..., 1][m] = np.clip(s[m] * sm + sa, 0, 255)
        out[..., 2][m] = np.clip(v[m] * vm, 0, 255)
    return _from_hsv(out, alpha)


# ---------------------------------------------------------------- desenho
class Layer:
    """Camada RGBA supersampled; coordenadas em px do canvas 1024."""

    def __init__(self):
        self.img = Image.new("RGBA", (W * SS, W * SS), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.img)

    def _p(self, pts):
        return [(x * SS, y * SS) for x, y in pts]

    def circle(self, c, r, fill):
        x, y = c
        self.d.ellipse([(x - r) * SS, (y - r) * SS, (x + r) * SS, (y + r) * SS], fill=fill)

    def poly(self, pts, fill, ow=5, outline=OUTLINE):
        p = self._p(pts)
        self.d.polygon(p, fill=fill)
        if ow > 0:
            self.d.line(p + [p[0]], fill=outline, width=ow * SS, joint="curve")

    def line(self, pts, fill, w):
        self.d.line(self._p(pts), fill=fill, width=int(w * SS), joint="curve")

    def taper(self, p0, p1, p2, r0, r1, fill, hi=None, ol=5, n=48):
        """Curva de Bézier quadrática com raio decrescente (chifre, espinho, chama)."""
        pts = [_bez(p0, p1, p2, i / (n - 1)) for i in range(n)]
        raios = [r0 + (r1 - r0) * (i / (n - 1)) for i in range(n)]
        for (x, y), r in zip(pts, raios):
            self.circle((x, y), r + ol, OUTLINE)
        for (x, y), r in zip(pts, raios):
            self.circle((x, y), r, fill)
        if hi is not None:
            for (x, y), r in zip(pts, raios):
                self.circle((x - r * 0.28, y - r * 0.18), max(r * 0.32, 0.8), hi)

    def out(self):
        return self.img.resize((W, W), Image.LANCZOS)


def _bez(a, b, c, t):
    u = 1 - t
    return (u * u * a[0] + 2 * u * t * b[0] + t * t * c[0], u * u * a[1] + 2 * u * t * b[1] + t * t * c[1])


def smooth(pts, per=14):
    """Spline Catmull-Rom fechada pelos pontos de controle (contorno orgânico)."""
    n = len(pts)
    out = []
    for i in range(n):
        p0, p1, p2, p3 = pts[(i - 1) % n], pts[i], pts[(i + 1) % n], pts[(i + 2) % n]
        for k in range(per):
            t = k / per
            t2, t3 = t * t, t * t * t
            out.append(tuple(
                0.5 * ((2 * p1[j]) + (-p0[j] + p2[j]) * t + (2 * p0[j] - 5 * p1[j] + 4 * p2[j] - p3[j]) * t2
                       + (-p0[j] + 3 * p1[j] - 3 * p2[j] + p3[j]) * t3)
                for j in (0, 1)))
    return out


def glow(center, radius, color, strength, power=2.0):
    """Brilho radial suave (aura / olho) como camada RGBA 1024."""
    yy, xx = np.mgrid[0:W, 0:W].astype(np.float32)
    d = np.sqrt((xx - center[0]) ** 2 + (yy - center[1]) ** 2) / radius
    a = np.clip(1.0 - d, 0, 1) ** power * strength
    arr = np.zeros((W, W, 4), np.uint8)
    arr[..., 0], arr[..., 1], arr[..., 2] = color
    arr[..., 3] = np.clip(a * 255, 0, 255).astype(np.uint8)
    return Image.fromarray(arr, "RGBA")


def blur(layer_img, r):
    return layer_img.filter(ImageFilter.GaussianBlur(r))


def stack(*imgs):
    base = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    for im in imgs:
        if im is not None:
            base = Image.alpha_composite(base, im)
    return base


def thick_outline(img, px):
    """Contorno externo mais grosso (dilata o alfa e pinta atrás)."""
    alpha = img.getchannel("A").point(lambda a: 255 if a > 8 else 0)
    grown = alpha.filter(ImageFilter.MaxFilter(px * 2 + 1))
    fundo = Image.new("RGBA", (W, W), OUTLINE)
    fundo.putalpha(grown)
    return Image.alpha_composite(fundo, img)


def shear_forward(img, k):
    """Inclina o corpo para a esquerda (frente do oni) mantendo os pés fixos."""
    return img.transform(img.size, Image.AFFINE, (1, -k, 909 * k, 0, 1, 0), resample=Image.BICUBIC)


# ---------------------------------------------------------------- variantes
def elite(base):
    corpo = recolor(
        base,
        skin=(352, 1.0, 70, 0.78),
        cloth=(345, 1.1, 40, 0.62),
        band=(40, 1.2, 60, 1.0),
    )
    corpo = thick_outline(corpo, 6)
    f = Layer()
    f.taper((505, 225), (440, 40), (640, 18), 28, 3, BONE, hi=(255, 250, 235, 255))
    f.taper((392, 215), (300, 120), (250, 22), 26, 3, BONE, hi=(255, 250, 235, 255))
    for i, (bx, by, tx, ty) in enumerate([(690, 450, 740, 360), (715, 500, 790, 430), (722, 560, 800, 520)]):
        f.taper((bx, by), (bx + 20, by - 40), (tx, ty), 17, 2, (150, 30, 45, 255), hi=(230, 90, 100, 255))
    f.line([(388, 312), (430, 360), (470, 412)], (214, 50, 60, 255), 9)
    f.line([(402, 340), (424, 322)], (214, 50, 60, 255), 6)
    f.line([(440, 380), (464, 362)], (214, 50, 60, 255), 6)
    return stack(corpo, f.out())


def charger(base):
    corpo = recolor(
        base,
        skin=(24, 1.0, 95, 0.95),
        cloth=(18, 1.0, 20, 0.5),
        band=(2, 1.3, 90, 1.25),
    )
    # braços mais grossos: recorta, amplia a partir do ombro e cola por cima
    caixa = (240, 480, 500, 730)
    braco = corpo.crop(caixa)
    gx, gy = int(braco.width * 1.28), int(braco.height * 1.28)
    braco = braco.resize((gx, gy), Image.LANCZOS)
    mask = Image.new("L", (gx, gy), 255)
    ombro = (500, 560)
    ox, oy = int(ombro[0] - (ombro[0] - caixa[0]) * 1.28), int(ombro[1] - (ombro[1] - caixa[1]) * 1.28)
    tela = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    tela.paste(braco, (ox, oy), mask)
    # ombro grosso só na parte esquerda (fora do torso) para não duplicar o tronco
    corte = Image.new("L", (W, W), 0)
    ImageDraw.Draw(corte).rectangle([0, 0, 470, W], fill=255)
    tela.putalpha(Image.composite(tela.getchannel("A"), Image.new("L", (W, W), 0), corte))
    corpo = Image.alpha_composite(corpo, tela)
    f = Layer()
    # chifres de touro (para a frente = esquerda) e faixa vermelha, ANTES da inclinação
    f.taper((405, 240), (285, 240), (248, 118), 31, 4, BONE, hi=(255, 250, 235, 255))
    f.taper((470, 222), (390, 120), (318, 62), 22, 3, (205, 190, 165, 255), hi=(250, 240, 220, 255))
    f.poly(smooth([(338, 262), (470, 238), (612, 236), (618, 288), (470, 290), (348, 322)], 8),
           (205, 40, 32, 255), ow=5)
    corpo = Image.alpha_composite(corpo, f.out())
    return shear_forward(corpo, 0.17)


def ranged(base):
    corpo = recolor(
        base,
        skin=(228, 0.9, 55, 0.78),
        cloth=(236, 1.0, 40, 0.5),
        band=(200, 1.0, 40, 0.6),
    )
    capa = Layer()
    capa.poly(
        [(540, 420), (770, 470), (850, 700), (820, 780), (790, 850), (745, 800), (705, 880),
         (655, 815), (610, 890), (560, 810), (500, 860), (470, 740), (470, 480)],
        (42, 46, 112, 255), ow=6,
    )
    for ax, ay, bx, by in [(620, 520, 600, 800), (700, 520, 720, 810), (560, 500, 520, 790)]:
        capa.line([(ax, ay), ((ax + bx) / 2 + 10, (ay + by) / 2), (bx, by)], (24, 26, 74, 255), 7)
    capuz = Layer()
    contorno = smooth([(345, 345), (326, 250), (366, 168), (448, 118), (548, 84), (650, 62), (742, 70),
                       (712, 150), (722, 250), (716, 345), (650, 332), (580, 282), (480, 258), (405, 290)])
    capuz.poly(contorno, (50, 54, 128, 255), ow=7)
    sombra = smooth([(365, 330), (350, 245), (385, 175), (445, 125), (474, 150), (470, 250), (410, 290)])
    capuz.poly(sombra, (28, 30, 82, 255), ow=0)
    capuz.taper((470, 124), (450, 80), (486, 42), 12, 2, BONE, hi=(255, 250, 235, 255), ol=4)
    olho = glow((440, 358), 70, (150, 235, 255), 0.95, 1.6)
    olho2 = Layer()
    olho2.circle((440, 358), 17, (225, 252, 255, 255))
    return stack(capa.out(), corpo, capuz.out(), olho, olho2.out())


def boss_mist(base):
    corpo = recolor(
        base,
        skin=(272, 0.8, 35, 1.0),
        cloth=(268, 0.9, 45, 0.78),
        band=(300, 1.0, 40, 0.6),
    )
    aura = glow((512, 540), 560, (150, 110, 230), 0.62, 1.7)
    nevoa = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    nd = ImageDraw.Draw(nevoa)
    for cx, cy, rx, ry in [(300, 880, 190, 40), (520, 905, 230, 48), (760, 870, 170, 38), (420, 820, 150, 30)]:
        nd.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=(214, 190, 255, 105))
    nevoa = blur(nevoa, 22)
    frente = nevoa.point(lambda v: v)
    frente.putalpha(nevoa.getchannel("A").point(lambda a: a // 3))
    f = Layer()
    f.taper((405, 220), (260, 150), (240, 22), 34, 3, (222, 210, 245, 255), hi=(255, 250, 255, 255))
    f.taper((520, 212), (690, 120), (720, 18), 34, 3, (222, 210, 245, 255), hi=(255, 250, 255, 255))
    olho = glow((440, 358), 60, (190, 150, 255), 0.8, 1.6)
    return stack(aura, nevoa, corpo, olho, f.out(), frente)


def boss_fire(base):
    corpo = recolor(
        base,
        skin=(6, 1.0, 120, 0.98),
        cloth=(14, 0.8, 10, 0.38),
        band=(32, 1.0, 100, 1.1),
    )
    aura = glow((512, 560), 520, (255, 120, 30), 0.5, 1.8)
    brilho = Layer()
    rng = random.Random(7)
    rachaduras = [
        [(560, 470), (590, 520), (575, 570), (620, 610), (610, 680)],
        [(640, 450), (668, 500), (700, 540), (690, 600)],
        [(380, 300), (410, 340), (396, 388), (430, 420)],
        [(330, 560), (370, 590), (400, 640)],
        [(520, 700), (560, 740), (545, 800), (590, 850)],
    ]
    for r in rachaduras:
        pts = [(x + rng.randint(-5, 5), y + rng.randint(-5, 5)) for x, y in r]
        brilho.line(pts, (255, 120, 20, 255), 12)
    halo = blur(brilho.out(), 9)
    nucleo = Layer()
    for r in rachaduras:
        nucleo.line(r, (255, 226, 120, 255), 5)
    chamas = Layer()
    for bx, topo, dx, cor in [(385, 92, -26, (255, 140, 30, 255)), (440, 28, 22, (255, 100, 20, 255)),
                              (505, 6, -14, (255, 160, 40, 255)), (572, 40, 30, (255, 110, 25, 255)),
                              (632, 96, -10, (255, 140, 30, 255))]:
        chamas.taper((bx, 235), (bx + dx, (235 + topo) / 2), (bx + dx * 0.4, topo), 30, 2, cor, hi=(255, 232, 130, 255), ol=4)
    return stack(aura, corpo, halo, nucleo.out(), chamas.out())


def boss_dual(base):
    claro = recolor(base, skin=(190, 0.9, 70, 1.05), cloth=(205, 0.7, 20, 0.85), band=(185, 1.0, 60, 1.0))
    escuro = recolor(base, skin=(285, 0.7, 20, 0.34), cloth=(280, 0.6, 5, 0.2), band=(330, 1.0, 40, 0.5))
    mask = Image.new("L", (W, W), 0)
    ImageDraw.Draw(mask).rectangle([0, 0, 508, W], fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(3))
    corpo = Image.composite(claro, escuro, mask)
    corpo.putalpha(base.getchannel("A"))
    aura_c = glow((330, 540), 440, (110, 200, 255), 0.4, 1.8)
    aura_e = glow((700, 540), 440, (160, 60, 220), 0.45, 1.8)
    f = Layer()
    f.taper((395, 220), (320, 120), (305, 40), 22, 3, (232, 244, 255, 255), hi=(255, 255, 255, 255))
    f.taper((540, 205), (700, 100), (790, 10), 40, 3, (46, 22, 64, 255), hi=(150, 80, 200, 255))
    f.taper((690, 440), (740, 390), (800, 330), 22, 3, (46, 22, 64, 255), hi=(150, 80, 200, 255))
    f.line([(512, 120), (524, 300), (500, 480), (522, 700), (508, 905)], (250, 200, 255, 255), 6)
    seam = blur(f.out(), 0.1)
    brilho_seam = Layer()
    brilho_seam.line([(512, 120), (524, 300), (500, 480), (522, 700), (508, 905)], (220, 120, 255, 200), 18)
    return stack(aura_c, aura_e, corpo, blur(brilho_seam.out(), 8), seam)


def boss_castle(base):
    corpo = recolor(
        base,
        skin=(42, 0.5, 8, 0.78),
        cloth=(220, 0.6, 10, 0.45),
        band=(30, 0.5, 15, 0.6),
    )
    aço = (146, 152, 164, 255)
    aço_escuro = (88, 94, 108, 255)
    f = Layer()
    # ombreira traseira + dianteira, peitoral, punhos de maça, coroa de ameias
    f.poly([(640, 420), (780, 430), (815, 520), (760, 585), (650, 560)], aço, ow=6)
    f.poly([(660, 440), (770, 448), (790, 510), (750, 560), (672, 545)], aço_escuro, ow=0)
    f.poly([(486, 450), (620, 430), (640, 560), (560, 600), (480, 560)], aço, ow=6)
    f.line([(505, 500), (610, 485)], aço_escuro, 6)
    f.poly([(520, 640), (740, 620), (750, 690), (530, 715)], aço_escuro, ow=6)
    for rx, ry in [(655, 455), (760, 468), (520, 470), (595, 465), (700, 650), (590, 668)]:
        f.circle((rx, ry), 7, (200, 205, 215, 255))
    f.circle((300, 600), 62, aço)
    f.circle((298, 600), 38, aço_escuro)
    for ang in range(0, 360, 60):
        f.taper((298, 600), (298 + 70 * math.cos(math.radians(ang)) * 0.7, 600 + 70 * math.sin(math.radians(ang)) * 0.7),
                (298 + 86 * math.cos(math.radians(ang)), 600 + 86 * math.sin(math.radians(ang))), 11, 4, aço, ol=3)
    for i, mx in enumerate([380, 456, 532, 608]):
        f.poly([(mx, 190), (mx, 100), (mx + 52, 100), (mx + 52, 190)], aço, ow=6)
    f.poly([(372, 200), (372, 168), (668, 168), (668, 218)], aço_escuro, ow=6)
    olho = glow((440, 358), 50, (255, 210, 120), 0.7, 1.6)
    return stack(corpo, olho, f.out())


def boss_final(base):
    corpo = recolor(
        base,
        skin=(352, 0.9, 100, 0.34),
        cloth=(340, 0.6, 30, 0.16),
        band=(0, 1.0, 100, 0.55),
    )
    aura = glow((512, 520), 640, (150, 0, 30), 0.78, 1.5)
    fumaca = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    fd = ImageDraw.Draw(fumaca)
    for cx, cy, r in [(330, 880, 90), (520, 900, 110), (740, 880, 90), (610, 190, 70), (300, 300, 60)]:
        fd.ellipse([cx - r, cy - r * 0.5, cx + r, cy + r * 0.5], fill=(20, 4, 14, 150))
    fumaca = blur(fumaca, 20)
    f = Layer()
    negro, rubro = (22, 10, 26, 255), (190, 20, 40, 255)
    f.taper((400, 220), (250, 140), (210, 10), 36, 3, negro, hi=rubro)
    f.taper((520, 208), (700, 110), (800, 8), 36, 3, negro, hi=rubro)
    f.taper((380, 250), (300, 230), (240, 210), 20, 3, negro, hi=rubro)
    f.taper((560, 232), (650, 215), (720, 190), 18, 3, negro, hi=rubro)
    for i, (bx, by) in enumerate([(700, 440), (725, 510), (730, 580), (715, 650)]):
        f.taper((bx, by), (bx + 55, by - 30), (bx + 115, by - 62), 20, 2, negro, hi=rubro)
    olho = glow((440, 358), 80, (255, 30, 30), 1.0, 1.4)
    olho2 = Layer()
    olho2.circle((440, 358), 20, (255, 70, 60, 255))
    olho2.circle((440, 358), 9, (255, 230, 220, 255))
    return stack(aura, fumaca, corpo, olho, f.out(), olho2.out())


VARIANTES = {
    "elite_side.png": elite,
    "charger_side.png": charger,
    "ranged_side.png": ranged,
    "boss_mist_side.png": boss_mist,
    "boss_fire_side.png": boss_fire,
    "boss_dual_side.png": boss_dual,
    "boss_castle_side.png": boss_castle,
    "boss_final_side.png": boss_final,
}


def main():
    base = Image.open(BASE).convert("RGBA")
    for nome, fn in VARIANTES.items():
        img = fn(base)
        img.save(DIR / nome, optimize=False)
        solido = img.getchannel("A").point(lambda a: 255 if a > 200 else 0).getbbox()
        print(nome, "bbox solido", solido)


if __name__ == "__main__":
    main()
