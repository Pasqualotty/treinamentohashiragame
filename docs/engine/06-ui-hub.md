# 06 — UI Hub

## Arquivos

- Cena: `scenes/main_menu/hub.tscn`  
- Script: `scripts/main_menu/hub.gd`  

## Camadas (atrás → frente)

1. `BgArt` (TextureRect) — frames + drift  
2. `BgDim` — ColorRect semi-transparente  
3. TopBar / LeftColumn / CenterShowcase / BottomBar  

## Personagem

- Texturas em `hub_idle/`  
- Loop com `Array[float]` de durations (blink mais rápido)  
- **Sem** fundo magenta (PNG com alpha)

## Botões temáticos

`hub.gd` aplica `StyleBoxTexture` em runtime:

- LOJA / PERSONAGENS → `btn_shop.png` / `btn_chars.png`  
- JOGAR → `btn_play.png` (fonte escura no ouro)  
- Settings → ícone `settings_gear.png`  

## Fundo animado

Como `image_to_video` pode falhar (ZDR), usamos:

- 5 frames Ken Burns (`bg_frame_00`…`04`)  
- Ping-pong de índice  
- `sin/cos` em `position` para drift  

## Critério visual de pronto

- Tanjiro ocupa área central generosa  
- Fundo noturno visível  
- Botões não são “cinza default” puro  
- F5 sem erro de parse GDScript  
