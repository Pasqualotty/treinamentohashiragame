# Pack de arte v0.1 — review Matheus

**Gerado:** 2026-08-03 · Grok Imagine  
**Style bible:** `docs/STYLE-BIBLE.md`  
**Pasta review rápida:** `assets/pack_v01/`

## Conteúdo

| # | Arquivo | Uso no jogo | Fundo |
|---|---------|-------------|-------|
| 00 | `00_tanjiro_idle_front_base.jpg` | Hub (showcase frente) | Magenta |
| 01 | `01_tanjiro_idle_side.png` | Combate / side-scroller idle | Magenta |
| 02 | `02_oni_weak_side.png` | Inimigo fraco | Magenta |
| 03 | `03_ground_path.png` | Tile chão W1 (checar seam) | — |
| 04 | `04_coin.png` | Ícone + drop de moeda | Magenta |
| 05 | `05_touch_buttons_row.png` | Cortar 4 botões touch | Magenta |
| 06 | `06_keyart_loading.png` | Fundo da tela de loading | Cena full |

## Paths “de produção” no projeto

```
assets/characters/player/tanjiro_idle_front_base.jpg
assets/characters/player/tanjiro_idle_side.png
assets/characters/enemies/oni_weak_side.png
assets/tiles/w1/ground_path.png
assets/ui/icons/coin.png
assets/ui/touch/buttons_row.png
assets/ui/loading/keyart_w1.png
```

## Notas honestas (defeitos / próximos)

- Estilo é **cel cartoon** legível, não pixel-art 32×32 rígido (dá pra pixelar depois no LibreSprite se quiser).
- Tanjiro side veio da base frente via edit (consistência razoável).
- Botões touch = **row** para cortar; sem ícones de skill ainda (propositais, sem texto).
- Chão: validar 2×2 no Godot se o tile “costura” bem.
- Ainda **faltam** no pack: run sheet, attacks, ultimate, hurt, HP bar, breath bar, mapa visual, 2º oni.
- Magenta `#FF00FF` = chroma; no Godot usar shader/chroma ou converter pra PNG transparente depois.

## Como pedir ajuste

Exemplos: “Tanjiro mais pixel”, “oni menos fofo”, “key art sem silhueta”, “moeda sem símbolo de yen”.  
Re-geramos com `image_edit` a partir da base que você gostar.
