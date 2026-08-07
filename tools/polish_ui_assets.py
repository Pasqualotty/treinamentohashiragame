"""Polish UI assets: chroma magenta coin, lacquer touch buttons."""
from __future__ import annotations

import os
from PIL import Image, ImageDraw, ImageFont


def chroma_magenta(im: Image.Image, thr_rb: int = 180, thr_g: int = 130, soft: int = 40) -> Image.Image:
	im = im.convert("RGBA")
	px = im.load()
	w, h = im.size
	for y in range(h):
		for x in range(w):
			r, g, b, a = px[x, y]
			if r >= thr_rb and b >= thr_rb and g <= thr_g:
				mag = min(r, b) - g
				if mag > soft:
					px[x, y] = (r, g, b, 0)
				else:
					alpha = int(a * (1.0 - mag / soft))
					px[x, y] = (r, g, b, max(0, alpha))
	return im


def crop_alpha(im: Image.Image, pad: int = 4) -> Image.Image:
	bbox = im.getbbox()
	if not bbox:
		return im
	l, t, r, b = bbox
	l = max(0, l - pad)
	t = max(0, t - pad)
	r = min(im.width, r + pad)
	b = min(im.height, b + pad)
	return im.crop((l, t, r, b))


def make_button(size: int, face_rgb: tuple, rim_rgb=(201, 162, 39), dark_rgb=(18, 14, 28), pressed=False) -> Image.Image:
	s = size
	im = Image.new("RGBA", (s, s), (0, 0, 0, 0))
	d = ImageDraw.Draw(im)
	m = 3
	d.ellipse([m, m, s - 1 - m, s - 1 - m], fill=dark_rgb + (255,))
	d.ellipse([m + 3, m + 3, s - 4 - m, s - 4 - m], fill=rim_rgb + (255,))
	inset = m + 7
	if pressed:
		face = tuple(max(0, c - 35) for c in face_rgb)
		inset2 = inset + 2
	else:
		face = face_rgb
		inset2 = inset
	d.ellipse([inset2, inset2, s - 1 - inset2, s - 1 - inset2], fill=face + (255,))
	if not pressed:
		gloss = Image.new("RGBA", (s, s), (0, 0, 0, 0))
		gd = ImageDraw.Draw(gloss)
		gd.ellipse([inset2 + 4, inset2 + 3, s // 2 + 8, s // 2], fill=(255, 255, 255, 55))
		im = Image.alpha_composite(im, gloss)
	return im


def bake_label(btn: Image.Image, text: str, font_size: int) -> Image.Image:
	im = btn.copy()
	d = ImageDraw.Draw(im)
	font = None
	for fp in [
		r"C:\Windows\Fonts\arialbd.ttf",
		r"C:\Windows\Fonts\arial.ttf",
		r"C:\Windows\Fonts\seguiui.ttf",
		r"C:\Windows\Fonts\segoeui.ttf",
	]:
		if os.path.exists(fp):
			try:
				font = ImageFont.truetype(fp, font_size)
				break
			except Exception:
				pass
	if font is None:
		font = ImageFont.load_default()
	bbox = d.textbbox((0, 0), text, font=font)
	tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
	x = (im.width - tw) // 2
	y = (im.height - th) // 2 - 2
	for ox, oy in [(-1, 0), (1, 0), (0, -1), (0, 1), (1, 1)]:
		d.text((x + ox, y + oy), text, font=font, fill=(0, 0, 0, 180))
	d.text((x, y), text, font=font, fill=(255, 248, 230, 255))
	return im


def main() -> None:
	# 1) Coin
	for p in ["assets/ui/icons/coin.png", "assets/pack_v01/04_coin.png"]:
		if not os.path.exists(p):
			continue
		im = chroma_magenta(Image.open(p))
		im = crop_alpha(im, 8)
		canvas = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
		im.thumbnail((120, 120), Image.Resampling.LANCZOS)
		ox = (128 - im.width) // 2
		oy = (128 - im.height) // 2
		canvas.paste(im, (ox, oy), im)
		canvas.save(p, "PNG")
		print("coin fixed", p)

	# 2) Base plates
	colors = {
		"blue": (42, 92, 180),
		"red": (180, 36, 48),
		"orange": (196, 110, 28),
		"purple": (112, 56, 168),
	}
	os.makedirs("assets/ui/touch", exist_ok=True)
	for name, col in colors.items():
		for pressed, suf in [(False, ""), (True, "_pressed")]:
			b = make_button(128, col, pressed=pressed)
			path = f"assets/ui/touch/btn_{name}{suf}.png"
			b.save(path, "PNG")
			print("btn", path)

	# 3) Labeled combat set
	labels = {
		"move_left": ("<", "blue", 48),
		"move_right": (">", "blue", 48),
		"jump": ("PULO", "blue", 22),
		"advance": ("DASH", "orange", 20),
		"attack_basic": ("ATK", "red", 28),
		"skill_1": ("H1", "purple", 28),
		"skill_2": ("H2", "blue", 28),
		"ultimate": ("ULT", "orange", 26),
		"pause": ("II", "purple", 28),
	}
	os.makedirs("assets/ui/touch/labeled", exist_ok=True)
	for action, (txt, color, fs) in labels.items():
		col = colors[color]
		n = bake_label(make_button(128, col, pressed=False), txt, fs)
		p = bake_label(make_button(128, col, pressed=True), txt, fs)
		n.save(f"assets/ui/touch/labeled/{action}.png", "PNG")
		p.save(f"assets/ui/touch/labeled/{action}_pressed.png", "PNG")
		print("labeled", action)

	for p in ["assets/ui/touch/buttons_row.png", "assets/pack_v01/05_touch_buttons_row.png"]:
		if os.path.exists(p):
			im = chroma_magenta(Image.open(p))
			im.save(p, "PNG")
			print("chroma row", p)

	print("DONE")


if __name__ == "__main__":
	main()
