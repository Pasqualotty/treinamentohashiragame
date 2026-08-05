# 11 — Combat HUD

## Arquivos

| Papel | Path |
|-------|------|
| Cena reutilizável | `scenes/ui/combat_hud.tscn` |
| Script | `scripts/ui/combat_hud.gd` |
| Demo / sandbox | `scenes/ui/combat_hud_demo.tscn` + `scripts/ui/combat_hud_demo.gd` |

## O que mostra

- **HP** — API local `set_hp(current, max)` (player real ainda não existe).
- **Respiração** — `Game.breath` via `Game.breath_changed`.
- **Moedas da run** — `Game.coins_run` via `Game.run_coins_changed` (não banked).

## Moedas: run vs banked

| Contexto | Variável | Sinal |
|----------|----------|--------|
| Hub / loja | `Game.coins_banked` | `coins_changed` (hub ignora payload e relê banked) |
| Fase / HUD combate | `Game.coins_run` | **`run_coins_changed`** |

`add_run_coins` emite os dois sinais (legado + run). Preferir `run_coins_changed` no combate.

## Como a fase futura instancia

```gdscript
# Na cena de battle (ex.: stage_w1_01.gd)
const COMBAT_HUD := preload("res://scenes/ui/combat_hud.tscn")

func _ready() -> void:
    var hud := COMBAT_HUD.instantiate()
    add_child(hud)
    hud.set_hp(player.max_hp, player.max_hp)
    # depois, em damage:
    # hud.set_hp(player.hp, player.max_hp)
    # Game.add_breath_from_hit(10.0)
    # Game.add_run_coins(1)
```

Ou arraste `combat_hud.tscn` como filho no editor (CanvasLayer, layer 10).

## Demo

No Godot: abra `scenes/ui/combat_hud_demo.tscn` → **Run Current Scene** (F6).

Botões: HP ±, Breath +10, Fill/ULT, Coins +5, Reset.

## Fora de escopo (esta frente)

Player físico, hitbox, oni, fase, touch controls de combate.
