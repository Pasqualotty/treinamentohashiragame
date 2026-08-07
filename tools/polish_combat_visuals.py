"""Polish combat visuals: recolor haori, button icons, ground strip helpers."""
from __future__ import annotations

import math
import os
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]


def recolor_green_haori_to_red(im: Image.Image) -> Image.Image:
	"""Combat frames saíram com haori verde; idle canônico é carmesim xadrez."""
	im = im.convert("RGBA")
	px = im.load()
	w, h = im.size
	for y in range(h):
		for x in range(w):
			r, g, b, a = px[x, y]
			if a < 20:
				continue
			# Contorno rosa/magenta residual → marrom escuro
			if r > 160 and b > 120 and g < 120 and a > 100:
				px[x, y] = (32, 18, 22, a)
				continue
			# Haori verde / xadrez verde → carmesim (swap g→r)
			if g > r + 18 and g > b + 10 and g > 55:
				# Mantém variação de luz do xadrez
				nr = min(255, int(g * 1.05 + 20))
				ng = min(255, int(r * 0.55 + 18))
				nb = min(255, int(b * 0.45 + 22))
				px[x, y] = (nr, ng, nb, a)
	return im


def fix_combat_frames() -> None:
	combat = ROOT / "assets" / "characters" / "player" / "combat"
	paths = list(combat.rglob("*.png"))
	for p in paths:
		if "labeled" in str(p):
			continue
		im = Image.open(p)
		fixed = recolor_green_haori_to_red(im)
		fixed.save(p, "PNG")
		print("recolor", p.relative_to(ROOT))


def make_plate(size: int, face: tuple, pressed: bool = False) -> Image.Image:
	s = size
	im = Image.new("RGBA", (s, s), (0, 0, 0, 0))
	d = ImageDraw.Draw(im)
	dark = (14, 12, 22, 255)
	gold = (210, 168, 48, 255) if not pressed else (170, 130, 30, 255)
	fill = tuple(max(0, c - 30) for c in face) if pressed else face
	m = 2
	d.ellipse([m, m, s - 1 - m, s - 1 - m], fill=dark)
	d.ellipse([m + 3, m + 3, s - 4 - m, s - 4 - m], fill=gold)
	ins = m + 8
	if pressed:
		ins += 2
	d.ellipse([ins, ins, s - 1 - ins, s - 1 - ins], fill=fill + (255,))
	if not pressed:
		gloss = Image.new("RGBA", (s, s), (0, 0, 0, 0))
		gd = ImageDraw.Draw(gloss)
		gd.ellipse([ins + 6, ins + 4, s // 2 + 10, s // 2 + 2], fill=(255, 255, 255, 48))
		im = Image.alpha_composite(im, gloss)
	return im


def draw_icon(im: Image.Image, kind: str, pressed: bool) -> Image.Image:
	"""Ícones brancos/dourados legíveis no centro do botão."""
	d = ImageDraw.Draw(im)
	s = im.width
	cx, cy = s // 2, s // 2
	col = (255, 246, 220, 255) if not pressed else (255, 230, 180, 255)
	shadow = (0, 0, 0, 160)
	w = max(3, s // 28)

	def line(pts, width=w, color=col):
		# shadow
		sh = [(p[0] + 1, p[1] + 1) for p in pts]
		d.line(sh, fill=shadow, width=width + 1)
		d.line(pts, fill=color, width=width)

	if kind == "jump":
		# seta pra cima + pés
		line([(cx, cy + s // 6), (cx, cy - s // 5)], w + 1)
		line([(cx - s // 7, cy - s // 12), (cx, cy - s // 5), (cx + s // 7, cy - s // 12)], w + 1)
		d.ellipse([cx - s // 10, cy + s // 8, cx - s // 28, cy + s // 5], fill=col)
		d.ellipse([cx + s // 28, cy + s // 8, cx + s // 10, cy + s // 5], fill=col)
	elif kind == "dash":
		# chevrons >>
		for off in (-s // 14, s // 18):
			line(
				[
					(cx - s // 8 + off, cy - s // 7),
					(cx + s // 12 + off, cy),
					(cx - s // 8 + off, cy + s // 7),
				],
				w + 1,
			)
	elif kind == "attack":
		# katana diagonal
		line([(cx - s // 6, cy + s // 5), (cx + s // 5, cy - s // 5)], w + 2)
		d.ellipse([cx + s // 8, cy - s // 4, cx + s // 5, cy - s // 8], outline=col, width=w)
		# guarda
		line([(cx - s // 20, cy + s // 20), (cx + s // 14, cy - s // 16)], w)
	elif kind == "skill1":
		# arco / crescent slash
		bbox = [cx - s // 5, cy - s // 5, cx + s // 5, cy + s // 5]
		d.arc(bbox, 200, 340, fill=col, width=w + 1)
		d.arc([b + 1 for b in bbox], 200, 340, fill=shadow, width=w)
	elif kind == "skill2":
		# investida: seta horizontal + impact
		line([(cx - s // 5, cy), (cx + s // 6, cy)], w + 2)
		line([(cx + s // 20, cy - s // 8), (cx + s // 6, cy), (cx + s // 20, cy + s // 8)], w + 1)
	elif kind == "ultimate":
		# sol / respiração
		d.ellipse([cx - s // 9, cy - s // 9, cx + s // 9, cy + s // 9], outline=col, width=w + 1)
		for ang in range(0, 360, 45):
			rad = math.radians(ang)
			x0 = cx + int(math.cos(rad) * s * 0.16)
			y0 = cy + int(math.sin(rad) * s * 0.16)
			x1 = cx + int(math.cos(rad) * s * 0.26)
			y1 = cy + int(math.sin(rad) * s * 0.26)
			line([(x0, y0), (x1, y1)], w)
	elif kind == "pause":
		bw = s // 10
		gap = s // 14
		d.rectangle([cx - gap - bw, cy - s // 6, cx - gap, cy + s // 6], fill=col)
		d.rectangle([cx + gap, cy - s // 6, cx + gap + bw, cy + s // 6], fill=col)
	elif kind == "move_left":
		line([(cx + s // 10, cy - s // 7), (cx - s // 8, cy), (cx + s // 10, cy + s // 7)], w + 2)
	elif kind == "move_right":
		line([(cx - s // 10, cy - s // 7), (cx + s // 8, cy), (cx - s // 10, cy + s // 7)], w + 2)
	return im


def make_icon_button(kind: str, face: tuple, pressed: bool) -> Image.Image:
	im = make_plate(160, face, pressed)
	im = draw_icon(im, kind, pressed)
	return im


def export_buttons() -> None:
	out = ROOT / "assets" / "ui" / "touch" / "icons"
	out.mkdir(parents=True, exist_ok=True)
	# Also labeled dir for existing loader
	labeled = ROOT / "assets" / "ui" / "touch" / "labeled"
	labeled.mkdir(parents=True, exist_ok=True)

	# face colors: dark lacquer with tint (not pure candy)
	specs = {
		"jump": ("jump", (28, 48, 92)),
		"advance": ("dash", (110, 58, 18)),
		"attack_basic": ("attack", (120, 28, 32)),
		"skill_1": ("skill1", (72, 36, 110)),
		"skill_2": ("skill2", (28, 72, 110)),
		"ultimate": ("ultimate", (130, 70, 16)),
		"pause": ("pause", (48, 36, 72)),
		"move_left": ("move_left", (28, 48, 92)),
		"move_right": ("move_right", (28, 48, 92)),
	}
	for action, (kind, face) in specs.items():
		n = make_icon_button(kind, face, False)
		p = make_icon_button(kind, face, True)
		n.save(out / f"{action}.png", "PNG")
		p.save(out / f"{action}_pressed.png", "PNG")
		n.save(labeled / f"{action}.png", "PNG")
		p.save(labeled / f"{action}_pressed.png", "PNG")
		print("btn", action)


def make_hud_icons() -> None:
	icons = ROOT / "assets" / "ui" / "icons"
	icons.mkdir(parents=True, exist_ok=True)
	# Heart
	heart = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
	d = ImageDraw.Draw(heart)
	d.polygon([(32, 54), (8, 28), (14, 14), (26, 14), (32, 22), (38, 14), (50, 14), (56, 28)], fill=(200, 40, 50, 255))
	d.ellipse([10, 10, 34, 34], fill=(200, 40, 50, 255))
	d.ellipse([30, 10, 54, 34], fill=(200, 40, 50, 255))
	d.ellipse([16, 14, 28, 26], fill=(255, 160, 160, 180))
	heart.save(icons / "hp_heart.png", "PNG")
	# Breath / flame swirl
	breath = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
	d = ImageDraw.Draw(breath)
	d.ellipse([18, 18, 46, 46], outline=(90, 150, 255, 255), width=4)
	d.arc([12, 12, 52, 52], 200, 40, fill=(120, 180, 255, 255), width=3)
	d.ellipse([28, 28, 36, 36], fill=(200, 230, 255, 255))
	breath.save(icons / "breath_orb.png", "PNG")
	print("hud icons ok")


def make_ground_strip() -> None:
	"""Faixa de chão horizontal a partir do tile (sem faixona verde)."""
	src = ROOT / "assets" / "tiles" / "w1" / "ground_path.png"
	if not src.exists():
		print("no ground_path")
		return
	im = Image.open(src).convert("RGBA")
	# pega faixa de terra do meio da textura
	w, h = im.size
	crop = im.crop((0, int(h * 0.35), w, int(h * 0.62)))
	# strip longo 1600x64
	strip = Image.new("RGBA", (1600, 64), (0, 0, 0, 0))
	cw = crop.width
	x = 0
	while x < 1600:
		piece = crop.resize((cw, 64), Image.Resampling.LANCZOS)
		strip.paste(piece, (x, 0))
		x += cw
	out = ROOT / "assets" / "tiles" / "w1" / "ground_strip_side.png"
	strip.save(out, "PNG")
	# platform shorter
	plat = strip.crop((0, 0, 256, 64)).resize((200, 28), Image.Resampling.LANCZOS)
	plat.save(ROOT / "assets" / "tiles" / "w1" / "platform_strip_side.png", "PNG")
	print("ground strips ok")


def main() -> None:
	fix_combat_frames()
	export_buttons()
	make_hud_icons()
	make_ground_strip()
	print("DONE polish_combat_visuals")


if __name__ == "__main__":
	main()
