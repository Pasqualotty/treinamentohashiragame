extends Node
## Paleta central — Style Bible "Treinamento Hashira".
## Noite indigo, carmesim, ouro, agua, creme. Clima noturno japones.
## Autoload singleton: acesse em qualquer script como `Palette.GOLD`, etc.

## Fundo — noite indigo profunda (#0F1218).
const NIGHT_BG := Color(0.058824, 0.070588, 0.094118, 1.0)
## Paineis / superficies elevadas (#1C2330).
const PANEL := Color(0.109804, 0.137255, 0.188235, 1.0)
## Destaque / HP / perigo (#C43C3C).
const CRIMSON := Color(0.768627, 0.235294, 0.235294, 1.0)
## CTA / moeda / dourado ceremonial (#E8B84A).
const GOLD := Color(0.909804, 0.721569, 0.290196, 1.0)
## Respiracao / agua / mana (#5B8DEF).
const WATER := Color(0.356863, 0.552941, 0.937255, 1.0)
## Texto principal — creme quente (#FFF6EA).
const CREAM := Color(1.0, 0.964706, 0.917647, 1.0)

## Variantes derivadas — usadas no HUD, no theme e em glows/pulses.
const CRIMSON_BRIGHT := Color(0.94, 0.4, 0.38, 1.0)
const CRIMSON_DIM := Color(0.36, 0.13, 0.15, 1.0)
const GOLD_BRIGHT := Color(1.0, 0.86, 0.55, 1.0)
const GOLD_DIM := Color(0.42, 0.32, 0.14, 1.0)
const WATER_BRIGHT := Color(0.6, 0.75, 1.0, 1.0)
const WATER_DIM := Color(0.14, 0.2, 0.36, 1.0)

## Quase-preto para overlay/transicao de cena (cortina de fade).
const INK := Color(0.02, 0.02, 0.03, 1.0)
## Sombra de texto padrao (usada com font_shadow_color).
const SHADOW := Color(0.0, 0.0, 0.0, 0.75)


## --- Helpers -------------------------------------------------------------

## Retorna `c` com o alpha substituido por `a` (0..1).
static func with_alpha(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, a)


## Escurece `c` por `amount` (0..1). Atalho legivel para `Color.darkened`.
static func dim(c: Color, amount: float = 0.35) -> Color:
	return c.darkened(amount)


## Clareia `c` por `amount` (0..1). Atalho legivel para `Color.lightened`.
static func bright(c: Color, amount: float = 0.25) -> Color:
	return c.lightened(amount)


## Interpola entre duas cores da paleta (`w` 0..1).
static func mix(a: Color, b: Color, w: float) -> Color:
	return a.lerp(b, clampf(w, 0.0, 1.0))
