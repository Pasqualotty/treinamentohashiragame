# 13 — Modo batalha (placeholder)

Gênero **novo**, separado do side-scroller vs oni. Feel Brawl: mapa 2D em que os caçadores **andam no chão e sobem/descem**, e **se atacam**.

| | |
|---|---|
| Cena | `res://scenes/modes/brawl/brawl_arena.tscn` |
| Abrir | **F6** / Play na cena. Porta **não** é o JOGAR. |
| Roster default | Inosuke (2 lâminas) vs Nezuko (sem katana) |
| GameMode | Se `/root/GameMode` existir, lê `brawl_ids` / `get_brawl_roster()` e `brawl_match_time`. Senão o default. |
| Vitória | Último de pé, ou mais HP no fim do tempo (90 s). |
| Rede | Dummy local no 2º corpo. Sem Firebase, sem 1v1 ranqueado, sem coop 4 na fase oni. |

O player canônico é **instanciado** (não editado). Times `brawl_0` / `brawl_1` no hit/hurt pra o golpe atravessar. Movimento no plano: `MOTION_MODE_FLOATING` + eixo `move_up` / `move_down` (stick do GDD).
