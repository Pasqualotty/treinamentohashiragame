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

Dois **clusters radiais**, um por canto inferior: uma âncora grande com satélites
distribuídos num arco de raio constante ao redor dela. Ângulos em graus na
convenção de tela (0° = direita, 90° = baixo, 180° = esquerda, 270° = topo).

| Cluster | Âncora | Satélites (ângulo @ raio) |
|---|---|---|
| Esquerdo | stick virtual 156px | `jump` 315° · `advance` 0° @ 152px |
| Direito | `attack_basic` 132px | `ultimate` 270° · `skill_1` 225° · `skill_2` 180° @ 158px |

Hierarquia de tamanho em três níveis: primário 132 (`attack_basic`), secundário
104 (`ultimate`, `jump`), terciário 88 (`skill_1`, `skill_2`, `advance`). O
`pause` (56px, neutro) fica no topo-direita **abaixo** da faixa reservada ao HUD.

Regras duras do layout: nenhum par de alvos se sobrepõe (folga real ≥ 12px entre
bordas), nada invade a faixa do HUD superior (0..150px de design) e tudo cabe
dentro de `safe_margin`. Ângulos, raios e tamanhos são constantes/exports —
posições saem do helper de arco, não de somas manuais de gap.

Multi-touch: cada botão é `TouchScreenButton` com `CircleShape2D` (dedos
independentes; a área de toque é exatamente o disco desenhado). A arte vem de
`assets/ui/touch/icons/<action>.png` + `_pressed`, gerada por
`tools/gen_touch_icons.py` (Pillow, determinístico) — um glifo próprio por ação,
não label ASCII.

Export `hide_on_desktop`: se true, esconde a camada em desktop (útil em builds mistos). Default **false** para playtest no editor com mouse.

Chrome da fase (`StageController`): botão **Mapa** no topo-esquerda (não cobre ATK nem o cluster inferior).

## Teste

1. Editor: abra `scenes/ui/combat_touch_test.tscn` → F6.  
2. Segure teclas e clique nos botões — `Held` / `Just pressed` devem listar as actions.  
3. Android: export debug (outra frente) + multi-touch real no aparelho.
4. Headless: `tools/run_smokes.ps1` roda `scripts/qa/smoke_touch_layout.gd`, que
   valida a geometria (sobreposição, faixa do HUD, margem) e confirma que um
   toque no centro declarado dispara a action — ou seja, arte e hitbox alinhadas.

## Notas 4.7

- Stick analógico virtual usa o `VirtualJoystick` nativo do 4.7 — sem plugin externo.  
- Regenerar os ícones: `python tools/gen_touch_icons.py` (saída idêntica a cada rodada).
