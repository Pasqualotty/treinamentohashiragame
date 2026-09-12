# 14 — Duelo 1v1

Um round, dois corpos de frente, vencedor em PT. HUD próprio (2 HP + ROUND). Sem ONDA / moeda de fase.

| | |
|---|---|
| Cena | `res://scenes/modes/duel/duel.tscn` |
| Abrir | Sala (modo **1v1**) ou Play na cena. Porta **não** é o JOGAR. |
| Roster default | Inosuke (esquerda, 2 lâminas) vs Nezuko (direita, sem katana) |
| GameMode | 2P (`max_clients=1`). |
| Facing | Arte de combate olha ESQUERDA. `flip_h` só se facing > 0. |
| Rede | `LanSession` em sessão + peer: spawn pelo roster (igual a fase). Cada celular controla o seu via `InputFrame` / snap. **Sem dummy.** F6/smoke sem sessão: dummy local no 2º corpo. Sem Firebase. Sem 4P neste modo. |

O player canônico é **instanciado** (não editado). Times `duel_left` / `duel_right`. Host simula; guest manda `InputFrame` e segue snap.
