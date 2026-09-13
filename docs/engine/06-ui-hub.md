# 06 — UI Hub

## Arquivos

- Cena: `scenes/main_menu/hub.tscn`  
- Script: `scripts/main_menu/hub.gd`  

## Camadas (atrás → frente)

1. `BgArt` (TextureRect) — frames + drift  
2. `BgDim` — ColorRect semi-transparente  
3. TopBar / LeftColumn (LOJA, PERSONAGENS, **AMIGOS**) / CenterShowcase / BottomBar  
4. `%FriendsPanel` é **gaveta** full-rect: começa fechada. Toque em AMIGOS desliza da direita por cima do hub. Sem `change_scene`.  
5. Lobby da sala (`MpLobby`) é tela cheia: esconde LeftColumn / TopBar / BottomBar / showcase. `z_index` do painel **acima** da coluna esquerda. Troféus no topo da lobby.  

## Personagem  

## Personagem

- Showcase lê o `CharacterDef` atual (`hub_frames_dir` / 00 + 03).  
- `character_changed` **recarrega** a textura (não só o nome).  
- Pack próprio → `modulate = WHITE`. Os **15** ids do catálogo têm pack; o ramo sem pack (Tanjiro + `accent`) só existe se um path quebrar no disco.  
- **Sem** fundo magenta (PNG com alpha).

## Botões temáticos

`hub.gd` aplica `StyleBoxTexture` em runtime:

- LOJA / PERSONAGENS / AMIGOS → `shop_*` / `chars_*` (AMIGOS reusa a placa de PERSONAGENS)  
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

## Amigos (botão + gaveta)

- Hub **não** planta a coluna. Placa **AMIGOS** na esquerda, mesmo peso de LOJA/PERSONAGENS (320×76, toque ≥ 44).  
- Cena filha: `scenes/ui/friends_panel.tscn` (`%FriendsPanel`) — overlay. Clique abre gaveta da **direita** (painel **opaco** do topo até embaixo; JOGAR some enquanto a gaveta está aberta, sem vazar por baixo). Tanjiro / Loja ficam atrás.  
- Fecha: mesmo botão AMIGOS, toque no fundo, **Fechar** na gaveta, ou `ui_cancel` / pause.  
- **Não** lotar `hub.gd` — o painel cuida da lista e da sala. Sem `go_to` / troca de tela.  
- JOGAR continua no mapa; se o toque for de **guest** em sala, abre a gaveta + toast “O anfitrião escolhe a fase”. Host no **2 vs oni** também tem **Começar** na lobby (mesmo mapa).  
- Placas internas: tema / StyleBoxFlat (sem PNG Imagine novo nesta onda).  
- Sem campo de IP. **Adicionar amigo** pelo nome do perfil + Aceitar. Criar sala; **+** chama. Entrar + código de 6 ainda vale. A sala da estrela vem no APK (`hashira/sala_host`).  
- O **+** chama pra sala. O **x** apaga.  
- Gaveta largura **360**, mínima **320**. Textos: wrap **por palavra**. Empty = `Ninguém` numa linha.  
- **Criar sala** / guest na sala → `MpLobby` tela cheia (equipe + showcase + faixa de caçadores + modos). Fechar/Sair volta à gaveta. Sem copiar arte de outro jogo.  
- Fonte do hub: `FontVariation.spacing_space = 6` no tema + `ui_font.gd` se U+0020 ainda tiver advance 0.  
