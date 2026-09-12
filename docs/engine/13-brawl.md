# 13 — Modo batalha

Gênero **novo**, separado do side-scroller vs oni. Feel Brawl: mapa 2D em que os caçadores **andam no chão e sobem/descem**, e **se atacam**.

| | |
|---|---|
| Cena | `res://scenes/modes/brawl/brawl_arena.tscn` |
| Abrir | Sala (modo **Mapa de batalha**) ou **F6** / Play na cena. Porta **não** é o JOGAR. |
| Roster default | Inosuke (2 lâminas) vs Nezuko (sem katana) |
| GameMode | 2P (`max_clients=1`). Se `/root/GameMode` existir sem sessão, lê `brawl_ids` / `get_brawl_roster()` e `brawl_match_time`. |
| Vitória | Último de pé, ou mais HP no fim do tempo (90 s). |
| Rede | `LanSession` em sessão + peer: spawn pelo roster (igual a fase). Cada celular controla o seu via `InputFrame` / snap. **Sem dummy.** F6/smoke sem sessão: dummy local no 2º corpo. Sem Firebase. Sem 4P neste modo. |

O player canônico é **instanciado** (não editado). Times `brawl_0` / `brawl_1` no hit/hurt pra o golpe atravessar. Movimento no plano: `MOTION_MODE_FLOATING` + eixo `move_up` / `move_down` (stick do GDD). Host simula; guest manda `InputFrame` e segue snap.
