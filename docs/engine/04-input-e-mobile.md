# 04 — Input e mobile

## InputMap (project.godot)

Actions canônicas do GDD (`docs/GDD-DECISOES.md` §4). Player e UI **só** leem estas actions — nunca `is_key_pressed` hardcoded no combate.

| Action | Teclado (playtest PC) | Touch |
|--------|----------------------|-------|
| `move_left` | A, ← | Botão ◄ |
| `move_right` | D, → | Botão ► |
| `move_up` | W, ↑ | (opcional; side-scroller MVP foca L/R) |
| `move_down` | S, ↓ | (opcional) |
| `jump` | Espaço | **PULO** (esquerda) |
| `advance` | Shift, F | **DASH** (esquerda) |
| `attack_basic` | Z, J | **ATK** |
| `skill_1` | X, K | **H1** |
| `skill_2` | C, L | **H2** |
| `ultimate` | V, I | **ULT** (só se barra full — lógica fora deste módulo) |
| `pause` | Esc | **❚❚** (topo direita) |

Sempre:

```gdscript
Input.is_action_just_pressed("jump")
# NÃO: Input.is_key_pressed(KEY_SPACE) no player
```

## Cena touch reutilizável

| Path | Papel |
|------|--------|
| `scenes/ui/combat_touch_controls.tscn` | CanvasLayer empilhável (layer 100) |
| `scripts/ui/combat_touch_controls.gd` | Monta `TouchScreenButton` → `action` = nome InputMap |
| `scenes/ui/combat_touch_test.tscn` | Playtest (status held/just + teclado) |

**Integração em fase de combate:**

```gdscript
var touch := preload("res://scenes/ui/combat_touch_controls.tscn").instantiate()
add_child(touch)
```

Ou arraste a cena como filho do root da `stage_*`. Não precisa reescrever o hub.

### Layout (1280×720, polegares)

- **Esquerda:** move L/R · DASH · PULO  
- **Direita:** ATK · H1 · H2 · ULT  
- **Topo direita:** pause  

Multi-touch: cada botão é `TouchScreenButton` (dedos independentes). Placeholders procedurais; asset `assets/ui/touch/buttons_row.png` fica pra polish visual.

Export `hide_on_desktop`: se true, esconde a camada em desktop (útil em builds mistos). Default **false** para playtest no editor com mouse.

## Teste

1. Editor: abra `scenes/ui/combat_touch_test.tscn` → F6.  
2. Segure teclas e clique nos botões — `Held` / `Just pressed` devem listar as actions.  
3. Android: export debug (outra frente) + multi-touch real no aparelho.

## Notas 4.7

- Não há dependência de plugin de joystick externo no MVP (L/R discretos bastam no side-scroller).  
- Stick analógico virtual pode entrar depois sem mudar nomes de action.
