# Uplift visual — contrato entre frentes (2026-10-09)

Objetivo: melhorar **animações e layout do jogo inteiro** sem arte nova gerada por IA
(sem créditos de gerador nesta rodada). Tudo é código, PIL determinístico ou composição
dos assets que já existem.

Diagnóstico (capturas em 1280×720, `godot -s` com janela real):

| Tela | Problema visto |
|------|----------------|
| Fase (combate) | Dica "PC: A/D mover…" desenhada **em cima** da barra de vida; "Onda 1 / 3 · onis: 3" duplica o chip "ONDA 1/3"; botão "Mapa" solto; player nasce **embaixo do joystick** (x=160, stick em x=150); label "FECHADA" flutuando sobre o botão de ult; portal é um `ColorRect`; cartão de cerimônia cinza genérico com texto de dica vazando por trás |
| Fase (fundo) | **Emenda vertical visível** no meio da tela (MidArt 1280 px com `motion_mirroring=1280` sem ser seamless) em todos os mundos; chão é a mesma faixa de tijolo em W1–W5; sem atmosfera própria em W2–W5 |
| Onis | Um único sprite (`oni_weak_side.png`) para fraco/elite/charger/ranged/5 chefes, só muda tint e escala |
| Elenco | 11 caçadores (tomioka…muzan) têm **idle de 1 frame** e skill_1/skill_2 de 1 frame; sem dash |
| Hub | 7 placas com o **mesmo ícone** (máscara de oni) — só LOJA e JOGAR têm ícone próprio; barra de XP minúscula |
| Mapa | Cadeado **sobrepõe** o texto "Fase 4"; título duplicado ("Mapa — Mundo 1 — Montanha" + "Mundo 1 — Montanha — próxima"); nós são círculos chapados apesar de existir `assets/ui/map/node_*.png`; W2–W5 sem arte de mapa |
| Loja / Personagens / Ajustes / Missões / Notícias / Clube / Eventos / Créditos | Fundo **chapado** `#0F1218` sem arte, sem vinheta; sem animação de entrada; botão Voltar em posição diferente em cada tela |
| Brawl (mapa 4P) | Barras verdes cruas, nomes sem chrome, dica de texto por cima dos nametags |

## Frentes → arquivos que PODE tocar (ninguém toca arquivo de outra frente)

| Frente | Pode tocar | Não pode |
|--------|-----------|----------|
| **F1 personagens** | `scripts/characters/**`, `scenes/characters/**`, `scripts/combat/hitbox_timeline.gd` (só se a escala exigir), `tools/gen_oni_variants.py` (novo), `assets/characters/enemies/**` (novos PNG), `scripts/qa/smoke_f1_*.gd`, `scripts/qa/capture_f1_*.gd`, `docs/uplift-visual/qualidade-f1.md` | `stage_controller.gd`, `combat_hud.*`, `stage_*.tscn`, `wave_director.gd` |
| **F2 hud-cerimonia** | `scripts/battle/stage_controller.gd`, `scripts/battle/stage_goal.gd`, `scripts/battle/wave_director.gd`, `scripts/ui/combat_hud.gd/.tscn`, `scripts/ui/ceremony_card.gd`, `scripts/ui/combat_touch_controls.gd/.tscn`, `scripts/fx/enemy_hp_pip.gd`, `scripts/qa/smoke_f2_*.gd`, `scripts/qa/capture_f2_*.gd`, `docs/uplift-visual/qualidade-f2.md` | `player.gd`, `stage_*.tscn`, `world_backdrop.gd`, `ground_band.*` |
| **F3 fundos** | `scenes/battle/stage_*.tscn` (25), `scripts/battle/world_backdrop.gd`, `scripts/world/ground_band.gd/.tscn`, `assets/backgrounds/**`, `assets/tiles/**`, `tools/gen_world_ground.py` (novo), `scripts/qa/smoke_f3_*.gd`, `scripts/qa/capture_f3_*.gd`, `scripts/qa/smoke_world_backdrop.gd`, `docs/uplift-visual/qualidade-f3.md` | `stage_controller.gd` (a chamada `WorldBackdrop.dress(self, stage_id)` já existe — F3 só preenche a função) |
| **F4 telas-meta** | `scenes/ui/{shop,character_select,settings,missions,news,club,events,credits,name_entry}.tscn` + scripts correspondentes em `scripts/ui/`, `scripts/ui/meta_chrome.gd`, `scripts/ui/transition.gd`, `scripts/ui/meta_backdrop.gd` (novo), `scripts/ui/ui_motion.gd` (novo), `scripts/qa/smoke_f4_*.gd`, `scripts/qa/capture_f4_*.gd`, `docs/uplift-visual/qualidade-f4.md` | `hub.*`, `world_map.*`, `combat_hud.*`, `friends_panel.*`, `mp_lobby.gd`, `default_theme.tres`, `palette.gd` |
| **F5 hub-mapa** | `scenes/main_menu/hub.tscn`, `scripts/main_menu/hub.gd`, `scripts/ui/showcase_glow.gd`, `tools/gen_hub_art.py`, `assets/ui/buttons/hub/**`, `scenes/world/world_map.tscn`, `scripts/world/world_map.gd`, `scripts/world/map_canvas.gd`, `assets/ui/map/**`, `tools/gen_map_art.py` (novo), `scripts/qa/smoke_f5_*.gd`, `scripts/qa/capture_f5_*.gd`, `docs/uplift-visual/qualidade-f5.md` | `friends_panel.*`, `mp_lobby.gd`, telas da F4 |
| **F6 modos** | `scripts/modes/**`, `scenes/modes/**`, `assets/modes/**`, `scripts/qa/smoke_f6_*.gd`, `docs/uplift-visual/qualidade-f6.md` | `player.gd`, `combat_hud.*` |

Arquivos **de ninguém** (só o orquestrador): `tools/run_smokes.ps1`, `project.godot`, `scripts/autoload/*`,
`resources/theme/default_theme.tres`, `CHANGELOG.md`, `docs/STATUS-PROGRESSO.md`, este contrato.

## Convenções compartilhadas

- **Frames de inimigo** (F1 define, F3/F2 não dependem): `assets/characters/enemies/<kind>/<anim>/NN.png`
  com `kind ∈ {weak, elite, charger, ranged, boss_mist, boss_fire, boss_dual, boss_castle, boss_final}`
  e `anim ∈ {idle, walk, telegraph, attack, hurt, death}`. Pasta ausente → cai no sprite único + animação procedural atual.
- **`WorldBackdrop.dress(stage: Node, stage_id: String) -> void`** (stub já na main, chamado no início de
  `StageController._apply_world_backdrop`). F3 implementa; F2 mantém a chamada.
- **Smokes:** cada frente cria `scripts/qa/smoke_f<N>_<tema>.gd` (`extends SceneTree`, imprime
  `=== F<N> <TEMA> PASS ===` / `=== F<N> <TEMA> FAIL ===`, `quit(0/1)`), roda headless. **Não edita
  `tools/run_smokes.ps1`** — o orquestrador registra na integração. A suíte inteira atual tem que continuar PASS.
- **Captura visual:** `scripts/qa/capture_f<N>_*.gd` (janela real, `godot --path . --resolution 1280x720 -s …`,
  `HASHIRA_CAPTURE_DIR` = pasta de saída). A frente **olha o PNG** antes de dizer pronto.
- **Paleta/fonte:** só `Palette.*` e as fontes do tema (Cinzel título / Noto corpo). Nenhuma cor mágica nova
  fora de `Palette` sem comentário dizendo por quê.
- **Mobile:** tudo tem que caber em 1280×720 com `SafeInset`; botão de toque ≥ 64 px; texto ≥ 14 px.
- **Sem asset gerado por IA externa** nesta rodada (sem créditos). PIL determinístico (`tools/gen_*.py`,
  re-executável, bytes idênticos) ou composição dos PNG existentes.
- Godot CLI: `$env:LOCALAPPDATA\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.1-stable_win64_console.exe`.
  Worktree novo: `godot --headless --path . --import` (2× se criou `class_name`) antes dos smokes.
- `user://` é compartilhado entre worktrees — smoke que mexe em save limpa o que sujou.
