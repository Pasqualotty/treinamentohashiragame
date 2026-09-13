# 13 — Modo batalha

Gênero **novo**, separado do side-scroller vs oni. Feel Brawl: mapa 2D em que os caçadores **andam no chão e sobem/descem**, e **se atacam**.

| | |
|---|---|
| Cena | `res://scenes/modes/brawl/brawl_arena.tscn` |
| Abrir | Sala (modo **Mapa de batalha**) ou **F6** / Play na cena. Porta **não** é o JOGAR. |
| Roster default | Inosuke (2 lâminas) vs Nezuko (sem katana) |
| GameMode | Até 4 (`max_clients=3`). Host escolhe o modo e toca **Começar**. Se `/root/GameMode` existir sem sessão, lê `brawl_ids` / `get_brawl_roster()` e `brawl_match_time`. |
| Vitória | Último de pé, ou mais HP no fim do tempo (90 s). Tela **De novo / Sair**. |
| Mapa | Pátio 2880×1620, cobertura, lanternas, pads de vida / respiração / haste. |
| Rede | `LanSession` em sessão + peer: spawn pelo roster. Cada celular controla o seu via `InputFrame` / snap. Vagas vazias no F6 viram máquina. Sem Firebase. |

O player canônico é **instanciado** (não editado). Times `brawl_0` / `brawl_1` no hit/hurt pra o golpe atravessar. Movimento no plano: `MOTION_MODE_FLOATING` + eixo `move_up` / `move_down` (stick do GDD). Spawn **dentro do pátio** (não no canto de cima à esquerda). O pawn no plano **não** zera `velocity.y` como se fosse chão de side-scroller. Host simula; guest manda `InputFrame` (eixo Y no 4º byte) e segue snap.
