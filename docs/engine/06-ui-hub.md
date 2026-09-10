# 06 — UI Hub

## Arquivos

- Cena: `scenes/main_menu/hub.tscn`  
- Script: `scripts/main_menu/hub.gd`  

## Camadas (atrás → frente)

1. `BgArt` (TextureRect) — frames + drift  
2. `BgDim` — ColorRect semi-transparente  
3. TopBar / LeftColumn / CenterShowcase / **FriendsPanel** (direita) / BottomBar  

## Personagem  

## Personagem

- Showcase lê o `CharacterDef` atual (`hub_frames_dir` / 00 + 03).  
- `character_changed` **recarrega** a textura (não só o nome).  
- Pack próprio → `modulate = WHITE`. Sem pack → fallback Tanjiro + `accent`.  
- **Sem** fundo magenta (PNG com alpha).

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

- O caçador atual ocupa área central generosa  
- Fundo noturno visível  
- Botões não são “cinza default” puro  
- F5 sem erro de parse GDScript  

## Coluna direita (Amigos)

- Cena filha: `scenes/ui/friends_panel.tscn` (`%FriendsPanel`).  
- **Não** lotar `hub.gd` — o painel cuida da lista e da sala.  
- JOGAR continua no mapa; se o toque for de **guest** em sala, toast “O anfitrião escolhe a fase”.  
- Placas: tema / StyleBoxFlat (sem PNG Imagine novo nesta onda).  
- Safe area: `offset_right ≈ -20`, largura ~300, acima da barra do CTA.  
