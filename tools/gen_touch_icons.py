# -*- coding: utf-8 -*-
"""Gera a arte dos botoes touch de combate em assets/ui/touch/icons.

Linguagem visual: bisel circular laqueado escuro + aro dourado, tinta de acento
por familia de acao e glifo central em alto contraste com contorno escuro. Cada
acao tem um glifo proprio e obvio; o estado `_pressed` clareia a face, esquenta o
aro e inverte o bisel (inset), de modo que a diferenca e visivel num print.

Deterministico e re-executavel: nao usa aleatoriedade nem le estado externo.
Desenha em 1024x1024 (supersample 4x) e reduz para 256x256 com LANCZOS.

Uso:
    python tools/gen_touch_icons.py
"""
from __future__ import annotations

import math
from pathlib import Path
from typing import Callable, Sequence

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "assets/ui/touch/icons"

SS = 1024                 # canvas de trabalho (supersample)
OUT = 256                 # tamanho final exportado
C = SS / 2.0              # centro do canvas

R_SHELL = 502.0           # borda externa da casca escura
R_RIM = 486.0             # borda externa do aro dourado
R_FACE = 452.0            # face laqueada (area util do glifo)
R_GLYPH_CLIP = 442.0      # recorte de seguranca do glifo

RIM = (201, 162, 39)
RIM_HOT = (255, 216, 104)
SHELL = (13, 11, 18)
INK_LIGHT = (250, 250, 246)
INK_WARM = (255, 246, 214)
INK_DARK = (9, 7, 13)

OUTLINE_BLUR = 14.0       # sigma da dilatacao que vira contorno do glifo
OUTLINE_LO = 28           # limiar baixo (mantem antialias na dilatacao)
OUTLINE_HI = 52           # limiar alto
SHADOW_BLUR = 18.0
SHADOW_ALPHA = 120
SHADOW_OFFSET = (0, 12)

PRESSED_GLYPH_SCALE = 0.955
PRESSED_GLYPH_DROP = 12

# Tinta de acento por familia de acao.
ACCENTS: dict[str, tuple[int, int, int]] = {
    "attack_basic": (166, 28, 40),    # carmesim
    "advance": (184, 100, 20),        # ambar
    "jump": (184, 100, 20),           # ambar
    "skill_1": (32, 74, 158),         # azul-indigo
    "skill_2": (100, 44, 152),        # roxo
    "ultimate": (198, 132, 22),       # dourado quente
    "pause": (44, 42, 56),            # neutro
    "move_left": (40, 58, 92),        # aco
    "move_right": (40, 58, 92),
}

# `ultimate` e o mais chamativo dos seis: aro quente + halo interno.
HALO_ACTIONS = frozenset({"ultimate"})


# --------------------------------------------------------------------------
# helpers de cor / geometria
# --------------------------------------------------------------------------
def _mix(a: Sequence[int], b: Sequence[int], t: float) -> tuple[int, int, int]:
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))  # type: ignore[return-value]


def _lighten(c: Sequence[int], t: float) -> tuple[int, int, int]:
    return _mix(c, (255, 255, 255), t)


def _darken(c: Sequence[int], t: float) -> tuple[int, int, int]:
    return _mix(c, (0, 0, 0), t)


def _box(r: float, cx: float = C, cy: float = C) -> list[float]:
    return [cx - r, cy - r, cx + r, cy + r]


def _polar(angle_deg: float, r: float, cx: float = C, cy: float = C) -> tuple[float, float]:
    """Ponto polar em coordenadas de tela (y para baixo, angulo horario a partir de +X)."""
    a = math.radians(angle_deg)
    return (cx + r * math.cos(a), cy + r * math.sin(a))


def _circle_mask(r: float) -> Image.Image:
    m = Image.new("L", (SS, SS), 0)
    ImageDraw.Draw(m).ellipse(_box(r), fill=255)
    return m


def _vertical_gradient(top: Sequence[int], bottom: Sequence[int]) -> Image.Image:
    strip = Image.new("RGB", (1, SS))
    px = strip.load()
    for y in range(SS):
        t = y / (SS - 1)
        px[0, y] = _mix(top, bottom, t)
    return strip.resize((SS, SS), Image.Resampling.BILINEAR)


def _soft_threshold(mask: Image.Image, lo: int, hi: int) -> Image.Image:
    span = max(1, hi - lo)
    lut = [0 if v <= lo else (255 if v >= hi else int(round((v - lo) * 255 / span))) for v in range(256)]
    return mask.point(lut)


def _dilate(mask: Image.Image, sigma: float) -> Image.Image:
    return _soft_threshold(mask.filter(ImageFilter.GaussianBlur(sigma)), OUTLINE_LO, OUTLINE_HI)


def _tinted(mask: Image.Image, rgb: Sequence[int], alpha: int = 255) -> Image.Image:
    layer = Image.new("RGBA", (SS, SS), tuple(rgb) + (0,))
    layer.putalpha(mask if alpha >= 255 else mask.point(lambda v: v * alpha // 255))
    return layer


def _blank_mask() -> Image.Image:
    return Image.new("L", (SS, SS), 0)


# --------------------------------------------------------------------------
# casca laqueada
# --------------------------------------------------------------------------
def _build_shell(accent: Sequence[int], pressed: bool, halo: bool) -> Image.Image:
    rim = RIM_HOT if pressed else RIM
    if halo:
        rim = _lighten(rim, 0.22 if not pressed else 0.0)

    base = Image.new("RGBA", (SS, SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(base)
    d.ellipse(_box(R_SHELL), fill=SHELL + (255,))
    d.ellipse(_box(R_RIM), fill=tuple(rim) + (255,))

    if pressed:
        face_top = _lighten(accent, 0.46)
        face_bottom = _lighten(accent, 0.06)
    else:
        face_top = _lighten(accent, 0.26)
        face_bottom = _darken(accent, 0.44)
    face = _vertical_gradient(face_top, face_bottom).convert("RGBA")
    face.putalpha(_circle_mask(R_FACE))
    base = Image.alpha_composite(base, face)

    # Bisel: normal = luz em cima; pressed = sombra em cima (inset).
    bevel = Image.new("RGBA", (SS, SS), (0, 0, 0, 0))
    bd = ImageDraw.Draw(bevel)
    bevel_box = _box(R_FACE - 14.0)
    if pressed:
        bd.arc(bevel_box, 188, 352, fill=(0, 0, 0, 150), width=26)
        bd.arc(bevel_box, 12, 168, fill=(255, 255, 255, 60), width=12)
    else:
        bd.arc(bevel_box, 188, 352, fill=(255, 255, 255, 80), width=14)
        bd.arc(bevel_box, 12, 168, fill=(0, 0, 0, 120), width=20)
    base = Image.alpha_composite(base, bevel)

    if halo:
        glow_mask = _blank_mask()
        ImageDraw.Draw(glow_mask).ellipse(_box(R_FACE - 6.0), fill=255)
        ImageDraw.Draw(glow_mask).ellipse(_box(R_FACE - 74.0), fill=0)
        glow_mask = glow_mask.filter(ImageFilter.GaussianBlur(22))
        glow_mask = Image.composite(glow_mask, _blank_mask(), _circle_mask(R_FACE))
        base = Image.alpha_composite(base, _tinted(glow_mask, (255, 226, 140), 150))

    if not pressed:
        gloss_mask = _blank_mask()
        ImageDraw.Draw(gloss_mask).ellipse([C - 330, C - 350, C + 190, C - 40], fill=255)
        gloss_mask = gloss_mask.filter(ImageFilter.GaussianBlur(34))
        gloss_mask = Image.composite(gloss_mask, _blank_mask(), _circle_mask(R_FACE - 10.0))
        base = Image.alpha_composite(base, _tinted(gloss_mask, (255, 255, 255), 70))

    return base


# --------------------------------------------------------------------------
# glifos (desenham em mascara "L"; 255 = tinta)
# --------------------------------------------------------------------------
def _rounded_bar(d: ImageDraw.ImageDraw, x0: float, y0: float, x1: float, y1: float, r: float) -> None:
    d.rounded_rectangle([x0, y0, x1, y1], radius=r, fill=255)


def glyph_attack_basic(d: ImageDraw.ImageDraw) -> None:
    """Lamina de katana em diagonal + rastro de corte."""
    # Rastro do corte: crescente no setor superior-esquerdo (de onde a lamina veio).
    d.arc(_box(326.0), 182, 274, fill=255, width=52)

    # Cabo (tsuka).
    d.line([(300, 716), (410, 608)], fill=255, width=48, joint="curve")
    # Guarda (tsuba) perpendicular ao eixo da lamina.
    d.line([(374, 606), (466, 698)], fill=255, width=26, joint="curve")
    # Lamina com ponta.
    perp = (0.7071, 0.7071)
    base = (446, 570)
    shoulder = (700, 316)
    tip = (748, 268)
    half_base, half_tip = 32.0, 17.0
    blade = [
        (base[0] - perp[0] * half_base, base[1] - perp[1] * half_base),
        (shoulder[0] - perp[0] * half_tip, shoulder[1] - perp[1] * half_tip),
        tip,
        (shoulder[0] + perp[0] * half_tip, shoulder[1] + perp[1] * half_tip),
        (base[0] + perp[0] * half_base, base[1] + perp[1] * half_base),
    ]
    d.polygon(blade, fill=255)


def glyph_attack_basic_dark(d: ImageDraw.ImageDraw) -> None:
    """Hamon: linha da tempera acompanhando o fio da lamina."""
    d.line([(474, 566), (700, 340)], fill=255, width=12, joint="curve")


def glyph_advance(d: ImageDraw.ImageDraw) -> None:
    """Duplo chevron de velocidade + linhas de movimento."""
    for x0 in (500.0, 640.0):
        d.line(
            [(x0, C - 148), (x0 + 116, C), (x0, C + 148)],
            fill=255,
            width=58,
            joint="curve",
        )
    _rounded_bar(d, 236, C - 18, 404, C + 18, 18)
    _rounded_bar(d, 280, C - 168, 404, C - 132, 18)
    _rounded_bar(d, 280, C + 132, 404, C + 168, 18)


def glyph_jump(d: ImageDraw.ImageDraw) -> None:
    """Seta ascendente saindo de um arco de solo."""
    _rounded_bar(d, C - 44, 336, C + 44, 544, 22)
    d.polygon([(C, 178), (C + 156, 352), (C - 156, 352)], fill=255)
    d.arc([214, 632, 810, 908], 203, 337, fill=255, width=50)


def _wave_band(
    d: ImageDraw.ImageDraw,
    x0: float,
    x1: float,
    y_base: float,
    amp: float,
    period: float,
    thickness: float,
) -> None:
    steps = 96
    top: list[tuple[float, float]] = []
    bottom: list[tuple[float, float]] = []
    for i in range(steps + 1):
        x = x0 + (x1 - x0) * i / steps
        y = y_base + amp * math.sin(2.0 * math.pi * (x - x0) / period)
        top.append((x, y))
        bottom.append((x, y + thickness))
    d.polygon(top + list(reversed(bottom)), fill=255)


def glyph_skill_1(d: ImageDraw.ImageDraw) -> None:
    """Onda de Respiracao da Agua: crista principal + duas linhas de refluxo."""
    _wave_band(d, 190, 834, 400, 55, 430, 88)
    _wave_band(d, 250, 774, 566, 45, 430, 46)
    _wave_band(d, 310, 714, 676, 35, 430, 34)
    d.ellipse(_box(24.0, 402, 302), fill=255)
    d.ellipse(_box(18.0, 618, 288), fill=255)


def glyph_skill_2(d: ImageDraw.ImageDraw) -> None:
    """Vortice de tres lâminas espiraladas (tecnica distinta da onda)."""
    steps = 40
    for blade in range(3):
        a0 = blade * 120.0
        outer: list[tuple[float, float]] = []
        inner: list[tuple[float, float]] = []
        for i in range(steps + 1):
            t = i / steps
            ang = a0 + 152.0 * t
            radius = 92.0 + 206.0 * t
            half = 58.0 * (1.0 - t) + 11.0
            outer.append(_polar(ang, radius + half))
            inner.append(_polar(ang, radius - half))
        d.polygon(outer + list(reversed(inner)), fill=255)
    d.ellipse(_box(50.0), fill=255)


def glyph_ultimate(d: ImageDraw.ImageDraw) -> None:
    """Selo solar Hinokami: disco + anel + raios alternados."""
    for i in range(16):
        ang = i * 22.5
        outer_r = 358.0 if i % 2 == 0 else 306.0
        d.polygon(
            [_polar(ang, outer_r), _polar(ang - 6.2, 250.0), _polar(ang + 6.2, 250.0)],
            fill=255,
        )
    d.ellipse(_box(226.0), fill=255)
    d.ellipse(_box(206.0), fill=0)
    d.ellipse(_box(186.0), fill=255)


def glyph_ultimate_dark(d: ImageDraw.ImageDraw) -> None:
    """Chama do Deus do Fogo recortada dentro do disco solar."""
    d.polygon(
        [
            (C, 352),
            (C + 62, 452),
            (C + 46, 512),
            (C + 78, 566),
            (C + 30, 648),
            (C - 34, 654),
            (C - 78, 578),
            (C - 46, 496),
            (C - 58, 436),
        ],
        fill=255,
    )
    d.ellipse(_box(30.0, C - 4, 588), fill=0)


def glyph_pause(d: ImageDraw.ImageDraw) -> None:
    """Duas barras verticais, neutro e discreto."""
    _rounded_bar(d, 424, 336, 486, 688, 28)
    _rounded_bar(d, 538, 336, 600, 688, 28)


def _arrow(d: ImageDraw.ImageDraw, to_right: bool) -> None:
    sign = 1.0 if to_right else -1.0
    d.polygon(
        [(C + sign * 196, C), (C - sign * 96, C - 200), (C - sign * 96, C + 200)],
        fill=255,
    )
    x_tail = C - sign * 300
    x_head = C - sign * 108
    _rounded_bar(d, min(x_tail, x_head), C - 52, max(x_tail, x_head), C + 52, 26)


def glyph_move_left(d: ImageDraw.ImageDraw) -> None:
    _arrow(d, to_right=False)


def glyph_move_right(d: ImageDraw.ImageDraw) -> None:
    _arrow(d, to_right=True)


GlyphFn = Callable[[ImageDraw.ImageDraw], None]

GLYPHS: dict[str, GlyphFn] = {
    "attack_basic": glyph_attack_basic,
    "advance": glyph_advance,
    "jump": glyph_jump,
    "skill_1": glyph_skill_1,
    "skill_2": glyph_skill_2,
    "ultimate": glyph_ultimate,
    "pause": glyph_pause,
    "move_left": glyph_move_left,
    "move_right": glyph_move_right,
}

GLYPHS_DARK: dict[str, GlyphFn] = {
    "attack_basic": glyph_attack_basic_dark,
    "ultimate": glyph_ultimate_dark,
}


# --------------------------------------------------------------------------
# composicao
# --------------------------------------------------------------------------
def _draw_mask(fn: GlyphFn) -> Image.Image:
    mask = _blank_mask()
    fn(ImageDraw.Draw(mask))
    return mask


def _transform_pressed(mask: Image.Image) -> Image.Image:
    """Encolhe e desce o glifo para reforcar a leitura de botao afundado."""
    scaled_px = max(1, int(round(SS * PRESSED_GLYPH_SCALE)))
    scaled = mask.resize((scaled_px, scaled_px), Image.Resampling.LANCZOS)
    out = _blank_mask()
    off = (SS - scaled_px) // 2
    out.paste(scaled, (off, off + PRESSED_GLYPH_DROP))
    return out


def render(action: str, pressed: bool) -> Image.Image:
    accent = ACCENTS[action]
    halo = action in HALO_ACTIONS
    img = _build_shell(accent, pressed, halo)

    light_mask = _draw_mask(GLYPHS[action])
    dark_fn = GLYPHS_DARK.get(action)
    dark_mask = _draw_mask(dark_fn) if dark_fn is not None else None
    if pressed:
        light_mask = _transform_pressed(light_mask)
        if dark_mask is not None:
            dark_mask = _transform_pressed(dark_mask)

    clip = _circle_mask(R_GLYPH_CLIP)
    light_mask = Image.composite(light_mask, _blank_mask(), clip)
    if dark_mask is not None:
        dark_mask = Image.composite(dark_mask, _blank_mask(), clip)

    # Sombra projetada por baixo do contorno: profundidade sem sujar o glifo.
    shadow = light_mask.filter(ImageFilter.GaussianBlur(SHADOW_BLUR))
    shadow_layer = Image.new("RGBA", (SS, SS), (0, 0, 0, 0))
    shadow_layer.paste(_tinted(shadow, (0, 0, 0), SHADOW_ALPHA), SHADOW_OFFSET)
    shadow_layer.putalpha(Image.composite(shadow_layer.getchannel("A"), _blank_mask(), clip))
    img = Image.alpha_composite(img, shadow_layer)

    outline = _dilate(light_mask, OUTLINE_BLUR)
    outline = Image.composite(outline, _blank_mask(), clip)
    img = Image.alpha_composite(img, _tinted(outline, INK_DARK, 240))

    ink = INK_WARM if action == "ultimate" else INK_LIGHT
    img = Image.alpha_composite(img, _tinted(light_mask, ink))
    if dark_mask is not None:
        img = Image.alpha_composite(img, _tinted(dark_mask, INK_DARK, 235))

    # Recorte final: nada escapa da casca.
    img.putalpha(Image.composite(img.getchannel("A"), _blank_mask(), _circle_mask(R_SHELL)))
    return img.resize((OUT, OUT), Image.Resampling.LANCZOS)


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    written = 0
    for action in GLYPHS:
        for pressed, suffix in ((False, ""), (True, "_pressed")):
            path = OUT_DIR / f"{action}{suffix}.png"
            render(action, pressed).save(path, "PNG", optimize=True)
            written += 1
            print("icon", path.relative_to(ROOT).as_posix())
    print(f"DONE {written} icons -> {OUT_DIR.relative_to(ROOT).as_posix()}")


if __name__ == "__main__":
    main()
