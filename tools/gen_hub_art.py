"""Gera a arte dos botoes do hub: placas laqueadas com rim dourado e icone gravado.

Cada botao do hub ganha identidade visual propria (icone que diz o que ele faz) e
hierarquia clara: JOGAR e a placa cerimonial dourada (CTA), LOJA/PERSONAGENS/CONFIG
sao placas escuras secundarias.

Determinista e re-executavel: nao usa aleatoriedade, entao rodar duas vezes gera
bytes identicos. Rodar da raiz do projeto:

    python tools/gen_hub_art.py

Saida: assets/ui/buttons/hub/*.png  (placas em 4 estados + icones avulsos)
Depois de rodar, importar no Godot para gerar os .import:

    godot --headless --path . --import
"""

from __future__ import annotations

import math
import os

from PIL import Image, ImageDraw, ImageFilter

# --- Paleta (espelha scripts/autoload/palette.gd) ---------------------------
INK = (10, 12, 17)
NIGHT = (15, 18, 24)
PANEL = (28, 35, 48)
PANEL_HI = (43, 54, 73)
GOLD = (232, 184, 74)
GOLD_BRIGHT = (255, 219, 140)
GOLD_DEEP = (168, 126, 40)
CREAM = (255, 246, 234)
WATER = (110, 158, 255)

OUT_DIR = os.path.join("assets", "ui", "buttons", "hub")

# Supersampling: desenha grande e reduz com LANCZOS -> bordas suaves sem shader.
SS = 4

STATES = ("normal", "hover", "pressed", "focus")


# --- Utilitarios de desenho -------------------------------------------------

def _lerp(a: tuple[int, int, int], b: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def _shade(c: tuple[int, int, int], amount: float) -> tuple[int, int, int]:
    """amount > 0 clareia, < 0 escurece."""
    if amount >= 0:
        return _lerp(c, (255, 255, 255), amount)
    return _lerp(c, (0, 0, 0), -amount)


def _vgrad(w: int, h: int, top: tuple[int, int, int], bottom: tuple[int, int, int]) -> Image.Image:
    """Gradiente vertical opaco de `top` para `bottom`."""
    grad = Image.new("RGB", (1, h))
    px = grad.load()
    for y in range(h):
        px[0, y] = _lerp(top, bottom, y / max(1, h - 1))
    return grad.resize((w, h), Image.NEAREST).convert("RGBA")


def _rounded_mask(w: int, h: int, radius: int) -> Image.Image:
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, w - 1, h - 1), radius=radius, fill=255)
    return mask


def _circle_mask(w: int, h: int) -> Image.Image:
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, w - 1, h - 1), fill=255)
    return mask


def _emboss(base: Image.Image, mask: Image.Image, color: tuple[int, int, int], depth: int) -> None:
    """Compoe a mascara `mask` em `base` como metal em relevo: sombra deslocada + cor."""
    shadow = Image.new("RGBA", base.size, INK + (0,))
    shadow.putalpha(mask.point(lambda v: int(v * 0.72)))
    base.alpha_composite(shadow.transform(
        base.size, Image.AFFINE, (1, 0, -depth, 0, 1, -depth), resample=Image.BILINEAR))
    solid = Image.new("RGBA", base.size, color + (0,))
    solid.putalpha(mask)
    base.alpha_composite(solid)


# --- Icones (desenhados em coordenadas supersampled) ------------------------
# Cada icone desenha dentro de um quadrado de lado `s` com canto superior
# esquerdo em (x, y), numa mascara "L" propria: 255 = tinta, 0 = vazado.
# Modo "L" e obrigatorio — em RGBA o Pillow leria `fill=255` como cor empacotada
# com alpha 0 (icone invisivel).

def _icon_layer(size: tuple[int, int]) -> tuple[Image.Image, ImageDraw.ImageDraw]:
    layer = Image.new("L", size, 0)
    return layer, ImageDraw.Draw(layer)


def icon_pouch(d: ImageDraw.ImageDraw, x: float, y: float, s: float) -> None:
    """LOJA: bolsa de moedas com uma moeda mon (furo quadrado) na frente."""
    cx = x + s * 0.46
    # Corpo da bolsa.
    d.ellipse((cx - s * 0.34, y + s * 0.32, cx + s * 0.34, y + s * 0.94), fill=255)
    # Gargalo amarrado.
    d.polygon(
        [
            (cx - s * 0.17, y + s * 0.42),
            (cx - s * 0.11, y + s * 0.14),
            (cx + s * 0.11, y + s * 0.14),
            (cx + s * 0.17, y + s * 0.42),
        ],
        fill=255,
    )
    # Nó da corda.
    d.rectangle((cx - s * 0.21, y + s * 0.26, cx + s * 0.21, y + s * 0.36), fill=255)
    # Moeda mon sobreposta (recorta o furo quadrado depois).
    mcx, mcy, mr = x + s * 0.80, y + s * 0.76, s * 0.24
    d.ellipse((mcx - mr, mcy - mr, mcx + mr, mcy + mr), fill=255)
    d.ellipse((mcx - mr, mcy - mr, mcx + mr, mcy + mr), outline=0, width=max(1, int(s * 0.05)))
    d.rectangle((mcx - mr * 0.30, mcy - mr * 0.30, mcx + mr * 0.30, mcy + mr * 0.30), fill=0)


def icon_oni_mask(d: ImageDraw.ImageDraw, x: float, y: float, s: float) -> None:
    """PERSONAGENS: mascara de oni — chifres curvos para fora, olhos em V, presas."""
    cx = x + s * 0.5
    # Chifres: crescem das tempora para cima e para FORA (nao confundir com orelhas).
    d.polygon([(cx - s * 0.30, y + s * 0.30), (cx - s * 0.46, y + s * 0.10),
               (cx - s * 0.44, y + s * 0.03), (cx - s * 0.34, y + s * 0.12),
               (cx - s * 0.17, y + s * 0.26)], fill=255)
    d.polygon([(cx + s * 0.30, y + s * 0.30), (cx + s * 0.46, y + s * 0.10),
               (cx + s * 0.44, y + s * 0.03), (cx + s * 0.34, y + s * 0.12),
               (cx + s * 0.17, y + s * 0.26)], fill=255)
    # Rosto: testa larga afunilando ate o queixo.
    d.polygon(
        [
            (cx - s * 0.34, y + s * 0.32),
            (cx - s * 0.30, y + s * 0.24),
            (cx + s * 0.30, y + s * 0.24),
            (cx + s * 0.34, y + s * 0.32),
            (cx + s * 0.30, y + s * 0.70),
            (cx, y + s * 0.96),
            (cx - s * 0.30, y + s * 0.70),
        ],
        fill=255,
    )
    # Olhos: cunhas em V raivosas, vazadas.
    d.polygon([(cx - s * 0.26, y + s * 0.38), (cx - s * 0.07, y + s * 0.48),
               (cx - s * 0.09, y + s * 0.56), (cx - s * 0.26, y + s * 0.49)], fill=0)
    d.polygon([(cx + s * 0.26, y + s * 0.38), (cx + s * 0.07, y + s * 0.48),
               (cx + s * 0.09, y + s * 0.56), (cx + s * 0.26, y + s * 0.49)], fill=0)
    # Boca: faixa vazada com presas descendo do labio superior.
    mouth_top, mouth_bot = y + s * 0.64, y + s * 0.78
    d.polygon(
        [
            (cx - s * 0.22, mouth_top),
            (cx - s * 0.13, mouth_top + s * 0.09),
            (cx - s * 0.05, mouth_top),
            (cx + s * 0.05, mouth_top),
            (cx + s * 0.13, mouth_top + s * 0.09),
            (cx + s * 0.22, mouth_top),
            (cx + s * 0.17, mouth_bot),
            (cx - s * 0.17, mouth_bot),
        ],
        fill=0,
    )


def icon_katana(d: ImageDraw.ImageDraw, x: float, y: float, s: float) -> None:
    """JOGAR: katana na diagonal (lamina, tsuba e cabo com trancado)."""
    w = max(1, int(s * 0.09))
    # Lamina: canto inferior-esquerdo -> superior-direito, com leve curvatura.
    blade = [
        (x + s * 0.34, y + s * 0.66),
        (x + s * 0.58, y + s * 0.40),
        (x + s * 0.80, y + s * 0.20),
        (x + s * 0.94, y + s * 0.09),
    ]
    d.line(blade, fill=255, width=w, joint="curve")
    # Kissaki (ponta).
    d.polygon([(x + s * 0.88, y + s * 0.06), (x + s * 0.98, y + s * 0.04),
               (x + s * 0.92, y + s * 0.16)], fill=255)
    # Tsuba (guarda) perpendicular a lamina.
    d.line([(x + s * 0.22, y + s * 0.62), (x + s * 0.40, y + s * 0.80)],
           fill=255, width=max(1, int(s * 0.08)))
    # Cabo (tsuka).
    d.line([(x + s * 0.06, y + s * 0.94), (x + s * 0.28, y + s * 0.72)],
           fill=255, width=max(1, int(s * 0.13)))
    # Trancado do cabo (vazado).
    for i in range(3):
        t = 0.20 + i * 0.22
        px = x + s * (0.06 + 0.22 * t)
        py = y + s * (0.94 - 0.22 * t)
        d.line([(px - s * 0.05, py - s * 0.05), (px + s * 0.05, py + s * 0.05)],
               fill=0, width=max(1, int(s * 0.035)))


def icon_gear(d: ImageDraw.ImageDraw, x: float, y: float, s: float) -> None:
    """CONFIG: engrenagem de 8 dentes com furo central."""
    cx, cy = x + s * 0.5, y + s * 0.5
    r_out, r_in, teeth = s * 0.46, s * 0.32, 8
    pts = []
    steps = teeth * 4
    for i in range(steps):
        ang = math.tau * i / steps
        # 2 passos no raio externo, 2 no interno -> dente quadrado.
        r = r_out if (i % 4) in (0, 1) else r_in
        pts.append((cx + math.cos(ang) * r, cy + math.sin(ang) * r))
    d.polygon(pts, fill=255)
    d.ellipse((cx - s * 0.16, cy - s * 0.16, cx + s * 0.16, cy + s * 0.16), fill=0)


def icon_bust(d: ImageDraw.ImageDraw, x: float, y: float, s: float) -> None:
    """Perfil do jogador: busto (cabeca + ombros)."""
    cx = x + s * 0.5
    d.ellipse((cx - s * 0.22, y + s * 0.08, cx + s * 0.22, y + s * 0.52), fill=255)
    d.pieslice((cx - s * 0.40, y + s * 0.56, cx + s * 0.40, y + s * 1.34), 180, 360, fill=255)


def icon_mon_coin(d: ImageDraw.ImageDraw, x: float, y: float, s: float) -> None:
    """Moeda mon: disco cheio com furo quadrado no centro."""
    cx, cy, r = x + s * 0.5, y + s * 0.5, s * 0.48
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=255)
    d.rectangle((cx - r * 0.30, cy - r * 0.30, cx + r * 0.30, cy + r * 0.30), fill=0)


ICONS = {
    "pouch": icon_pouch,
    "mask": icon_oni_mask,
    "katana": icon_katana,
    "gear": icon_gear,
    "bust": icon_bust,
    "coin": icon_mon_coin,
}


# --- Tema por estado --------------------------------------------------------

def _theme(state: str, cta: bool) -> dict:
    """Cores da placa por estado. CTA inverte a hierarquia: face dourada, rim escuro."""
    if cta:
        base = {
            "face_top": GOLD,
            "face_bottom": GOLD_DEEP,
            "rim": INK,
            "rim_alpha": 240,
            "inner": GOLD_BRIGHT,
            "inner_alpha": 130,
            "icon": INK,
            "medal_face": _shade(GOLD_DEEP, -0.42),
            "medal_ring": GOLD_BRIGHT,
            "sheen": 46,
            "grain": 7,
        }
        if state == "hover":
            base |= {"face_top": _shade(GOLD, 0.20), "face_bottom": _shade(GOLD_DEEP, 0.20),
                     "inner_alpha": 200, "sheen": 70}
        elif state == "pressed":
            base |= {"face_top": _shade(GOLD_DEEP, -0.10), "face_bottom": _shade(GOLD_DEEP, -0.40),
                     "inner_alpha": 60, "sheen": 0, "grain": 4}
        elif state == "focus":
            base |= {"rim": WATER, "rim_alpha": 255, "inner_alpha": 170, "sheen": 58}
        return base

    base = {
        "face_top": PANEL_HI,
        "face_bottom": NIGHT,
        "rim": GOLD,
        "rim_alpha": 150,
        "inner": CREAM,
        "inner_alpha": 24,
        "icon": GOLD,
        "medal_face": _shade(NIGHT, -0.35),
        "medal_ring": GOLD,
        "sheen": 26,
        "grain": 5,
    }
    if state == "hover":
        base |= {"face_top": _shade(PANEL_HI, 0.18), "face_bottom": _shade(PANEL, -0.06),
                 "rim_alpha": 240, "icon": GOLD_BRIGHT, "medal_ring": GOLD_BRIGHT,
                 "inner_alpha": 48, "sheen": 40}
    elif state == "pressed":
        base |= {"face_top": _shade(PANEL, -0.28), "face_bottom": _shade(NIGHT, -0.30),
                 "rim_alpha": 100, "icon": GOLD_DEEP, "medal_ring": GOLD_DEEP,
                 "inner_alpha": 10, "sheen": 0, "grain": 3}
    elif state == "focus":
        base |= {"rim": WATER, "rim_alpha": 255, "inner_alpha": 40, "sheen": 30}
    return base


# --- Composicao das placas --------------------------------------------------

def _lacquer_body(w: int, h: int, radius: int, th: dict, circular: bool) -> Image.Image:
    """Corpo laqueado: contorno escuro, face em gradiente, rim, brilho e sombra interna."""
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    outer = (0, 0, w - 1, h - 1)

    # Contorno escuro externo (destaca a placa sobre o fundo movimentado).
    if circular:
        d.ellipse(outer, fill=INK + (255,))
    else:
        d.rounded_rectangle(outer, radius=radius, fill=INK + (255,))

    # Face com gradiente vertical, recortada pelo shape.
    pad = 2 * SS
    fw, fh = w - pad * 2, h - pad * 2
    face = _vgrad(fw, fh, th["face_top"], th["face_bottom"])
    fmask = _circle_mask(fw, fh) if circular else _rounded_mask(fw, fh, max(1, radius - pad))
    im.paste(face, (pad, pad), fmask)

    # Sombra interna na base (volume).
    shade = Image.new("RGBA", (fw, fh), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shade)
    band = int(fh * 0.42)
    for i in range(band):
        a = int(70 * (i / max(1, band - 1)) ** 2)
        sd.line([(0, fh - band + i), (fw, fh - band + i)], fill=INK + (a,))
    shade.putalpha(Image.composite(shade.getchannel("A"), Image.new("L", (fw, fh), 0), fmask))
    im.alpha_composite(shade, (pad, pad))

    # Textura de laca escovada: hairlines horizontais muito sutis.
    if th["grain"] > 0:
        grain = Image.new("RGBA", (fw, fh), (0, 0, 0, 0))
        gd = ImageDraw.Draw(grain)
        for gy in range(0, fh, SS * 3):
            gd.line([(0, gy), (fw, gy)], fill=CREAM + (th["grain"],), width=1)
        grain.putalpha(Image.composite(grain.getchannel("A"), Image.new("L", (fw, fh), 0), fmask))
        im.alpha_composite(grain, (pad, pad))

    # Brilho da laca polida: faixa suave no terco superior (sem cunha diagonal dura).
    if th["sheen"] > 0:
        sheen = Image.new("RGBA", (fw, fh), (0, 0, 0, 0))
        sd2 = ImageDraw.Draw(sheen)
        band = int(fh * 0.34)
        for i in range(band):
            a = int(th["sheen"] * (1.0 - i / max(1, band - 1)) ** 1.6)
            sd2.line([(0, i), (fw, i)], fill=CREAM + (a,))
        sheen = sheen.filter(ImageFilter.GaussianBlur(radius=SS * 2))
        sheen.putalpha(Image.composite(sheen.getchannel("A"), Image.new("L", (fw, fh), 0), fmask))
        im.alpha_composite(sheen, (pad, pad))

    # Fio interno claro (bisel logo abaixo do rim).
    inner = (pad + SS, pad + SS, w - pad - SS - 1, h - pad - SS - 1)
    idraw = ImageDraw.Draw(im)
    inner_col = th["inner"] + (th["inner_alpha"],)
    if circular:
        idraw.ellipse(inner, outline=inner_col, width=SS)
    else:
        idraw.rounded_rectangle(inner, radius=max(1, radius - pad - SS), outline=inner_col, width=SS)

    # Rim (a assinatura dourada da marca).
    rim = (SS, SS, w - SS - 1, h - SS - 1)
    rim_col = th["rim"] + (th["rim_alpha"],)
    if circular:
        idraw.ellipse(rim, outline=rim_col, width=2 * SS)
    else:
        idraw.rounded_rectangle(rim, radius=max(1, radius - SS), outline=rim_col, width=2 * SS)
    return im


def _medallion(im: Image.Image, cx: float, cy: float, r: float, icon: str, th: dict) -> None:
    """Disco gravado a esquerda da placa, com o icone da acao em relevo."""
    d = ImageDraw.Draw(im)
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=th["medal_face"] + (235,))
    d.ellipse((cx - r, cy - r, cx + r, cy + r),
              outline=th["medal_ring"] + (200,), width=max(1, int(SS * 1.5)))

    side = r * 1.34
    layer, ld = _icon_layer(im.size)
    ICONS[icon](ld, cx - side * 0.5, cy - side * 0.5, side)
    _emboss(im, layer, th["icon"], max(1, int(SS * 0.9)))


def _studs(im: Image.Image, w: int, h: int, inset: int, color: tuple[int, int, int]) -> None:
    """Rebites nos 4 cantos — leitura de placa cerimonial pregada na madeira."""
    d = ImageDraw.Draw(im)
    r = SS * 3
    for px, py in ((inset, inset), (w - inset, inset), (inset, h - inset), (w - inset, h - inset)):
        d.ellipse((px - r, py - r, px + r, py + r), fill=color + (215,))
        d.ellipse((px - r * 0.45, py - r * 0.45, px + r * 0.45, py + r * 0.45), fill=INK + (170,))


def build_plate(w: int, h: int, icon: str, state: str, *, cta: bool = False,
                circular: bool = False) -> Image.Image:
    """Placa completa de um botao, num estado, ja reduzida ao tamanho final."""
    th = _theme(state, cta)
    W, H = w * SS, h * SS
    radius = int((min(w, h) * 0.20) * SS)
    im = _lacquer_body(W, H, radius, th, circular)

    if circular:
        _medallion(im, W * 0.5, H * 0.5, min(W, H) * 0.30, icon, th)
    else:
        med_r = H * 0.36
        med_cx = SS * 8 + med_r
        _medallion(im, med_cx, H * 0.5, med_r, icon, th)
        # Fio vertical separando o medalhao do rotulo.
        sep_x = med_cx + med_r + SS * 7
        ImageDraw.Draw(im).line(
            [(sep_x, H * 0.24), (sep_x, H * 0.76)],
            fill=th["rim"] + (max(40, th["rim_alpha"] // 3),), width=max(1, SS))
        if cta:
            _studs(im, W, H, SS * 11, th["inner"])

    # Pressionado afunda 1px: reforca o feedback tatil no toque.
    if state == "pressed":
        sunk = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        sunk.alpha_composite(im, (0, SS))
        im = sunk

    return im.resize((w, h), Image.LANCZOS)


def build_icon(size: int, icon: str, color: tuple[int, int, int]) -> Image.Image:
    """Icone avulso transparente (badge de perfil, moeda do topo)."""
    S = size * SS
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    layer, ld = _icon_layer((S, S))
    ICONS[icon](ld, S * 0.06, S * 0.06, S * 0.88)
    _emboss(im, layer, color, max(1, int(SS * 0.8)))
    return im.resize((size, size), Image.LANCZOS)


# --- Manifesto --------------------------------------------------------------

PLATES = (
    # nome,      largura, altura, icone,    cta,   circular
    ("shop", 320, 76, "pouch", False, False),
    ("chars", 320, 76, "mask", False, False),
    ("play", 380, 92, "katana", True, False),
    ("settings", 68, 68, "gear", False, True),
)

STANDALONE_ICONS = (
    ("icon_profile", 32, "bust", GOLD),
    ("icon_coin", 30, "coin", GOLD),
)


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    written = 0
    for name, w, h, icon, cta, circular in PLATES:
        for state in STATES:
            img = build_plate(w, h, icon, state, cta=cta, circular=circular)
            path = os.path.join(OUT_DIR, f"{name}_{state}.png")
            img.save(path, "PNG", optimize=True)
            print("plate", path, img.size)
            written += 1
    for name, size, icon, color in STANDALONE_ICONS:
        img = build_icon(size, icon, color)
        path = os.path.join(OUT_DIR, f"{name}.png")
        img.save(path, "PNG", optimize=True)
        print("icon ", path, img.size)
        written += 1
    print(f"DONE — {written} arquivos em {OUT_DIR}")


if __name__ == "__main__":
    main()
