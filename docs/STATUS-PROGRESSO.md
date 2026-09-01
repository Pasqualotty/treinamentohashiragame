# Status do projeto — Treinamento Hashira

**Atualizado:** 2026-09-01 (elenco 14 jogáveis + tela PERSONAGENS)  
**Marca:** **MVP W1 + PLAYABLE + gate de playtest**  
**Fonte de verdade deste resumo:** este arquivo + `CHANGELOG.md`  
**Checklist detalhado (marcação manual no browser):** `docs/CHECKLIST-MESTRE.html`  
**Playtest humano 10 min:** `docs/PLAYTEST-SOBRINHO.md`  
**GDD / decisões:** `docs/GDD-DECISOES.md`

---

## Onde estamos (1 frase)

**W1 jogável de verdade (validado smoke headless):** input mouse+teclado+touch, movimento do player, ondas de oni, moedas com magnet, saída trancada até limpar ondas. Fluxo: splash → loading → hub → mapa → fase (ondas) → portal → loja/save. **Gate de playtest** documentado + suite `tools/run_smokes.ps1`.

### Hotfix playability 2026-08-07 (crítico)

| Problema reportado | Causa | Correção |
|--------------------|-------|----------|
| Botões não funcionam no Godot (PC) | `TouchScreenButton` **não** recebe mouse | Controles viraram `TextureButton` + `Input.action_press/release` + `emulate_touch_from_mouse` |
| Movimento “não existe” / física zoada | feel fraco + floor snap fraco; (e input touch morto) | Player snappier, floor_snap, stats mais responsivos; smoke prova `move_right` dx>8 |
| Fase sem andamento | 1 oni estático + clear imediato | `WaveDirector`: 3 ondas weak/elite, portal FECHADO até acabar |
| Moedas chatas de pegar | hitbox pequena | radius maior + magnet 90px |
| SceneRouter null | `const SHOP` duplicado | removido |

**Smoke playable:** `godot --headless --path . -s res://scripts/qa/smoke_playable_w1.gd` → player move + onis onda 1 + TouchRoot + WaveDirector.  
**Suite gate:** `powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_smokes.ps1` (load + playable + combat e2e + meta + player).

---

## Premium wave (próximo degrau de qualidade)

> “Premium” aqui **não** é loja paga — é o pacote de **feel + touch + cerimônia de fase + áudio + animação** que deixa o W1 com cara de jogo de verdade pro playtest do sobrinho.

| Faixa | O que é | Status (snapshot) | Gate / prova |
|-------|---------|-------------------|--------------|
| **Playable base** | Input, ondas, moedas, portal trancado, smokes | ✅ 2026-08-07 | `smoke_playable_w1` + e2e combat |
| **Feel de combate** | Hitstop, juice, SFX de hit, knockback legível | 🟡 frentes paralelas / residual | playtest humano + e2e |
| **Anim combate** | Sheets idle/run/atk no player canônico | 🟡 residual (MVP tem slash legível) | visual + smoke player |
| **Touch premium** | Layout polegares, hit areas, labels | 🟡 pós-hotfix mouse-safe | checklist sobrinho + `q1` |
| **Cerimônia de fase** | Intro/clear/portal/feedback de onda | 🟡 parcial (label de onda + saída) | e2e waves + humano |
| **Áudio pass** | BGM hub/stage, SFX hit/coin/ui | 🟡 loops + sfx existem; boss BGM não | ouvir no device |
| **Playtest gate** | Suite automática + checklist 10 min | ✅ este gate | `run_smokes.ps1` + `PLAYTEST-SOBRINHO.md` |

### Como “fechar” a premium wave (definição prática)

1. **Máquina:** `tools/run_smokes.ps1` → `SUITE PASS`  
2. **Humano:** `docs/PLAYTEST-SOBRINHO.md` → veredito PASS (sem você explicar)  
3. **Device:** 1 APK debug em celular real, paisagem, sem crash no fluxo hub→fase→volta  

Enquanto (2) ou (3) falharem, a wave **não** está premium de verdade — só “funciona no editor”.

### Comandos rápidos

```powershell
# Suite headless (exit != 0 se qualquer smoke falhar)
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_smokes.ps1

# Só e2e combat (jump/dash/atk/coin/waves)
# & <Godot_console.exe> --headless --path . -s res://scripts/qa/smoke_combat_e2e.gd
```

---

## Definição de “pronto” (MVP)

| Item | Status |
|------|--------|
| 1 mundo, 3 fases + boss | ✅ |
| Elenco 14 (Tanjiro starter; unlock por `stage_id`) | ✅ |
| Loja 4 upgrades + save | ✅ |
| 2 tipos de oni (fraco + elite) | ✅ |
| Boot splash → loading → hub | ✅ |
| JOGAR → mapa → fase jogável | ✅ |
| Touch + InputMap | ✅ |
| APK instalável | ✅ `export/TreinamentoHashira-debug.apk` |
| Auto-update sideload (OTA) | ✅ check no hub + aviso + download + Intent; publicar: `docs/AUTO-UPDATE.md` |
| Créditos fan game | ✅ engrenagem do hub |
| Pause na fase | ✅ Continuar / Mapa / Hub |
| SceneRouter (shop/credits/mapa) | ✅ (hotfix 2026-08-07) |

---

## O que ficou **pendente** (pós-MVP / residual)

Nada disso **bloqueia** o MVP. Ordem sugerida pro próximo foco:

### 1) QA humano & playtest (próximo útil)

| Item | Por quê | Doc / checklist |
|------|---------|-----------------|
| Playtest com o sobrinho **sem explicar** | prova se o jogo ensina sozinho | checklist `f12`, `b2` |
| Checklist touch (polegares alcançam tudo) | conforto real no celular deitado | `q1` |
| Stress: trocar cena 20× sem crash | regressão de router/autoload | `q2` |
| Kill-app mid-save (save não corrompe) | confiança no meta | `q3` |
| FPS ≥ 30 em aparelho fraco (fase cheia) | Android real, não só emulador | `q4` |
| “Noite dos amigos” em ≥3 celulares | distribuição real | Fase G `f28` |

### 2) Polish / feel (não bloqueante)

| Item | Notas |
|------|--------|
| Hitboxes ajustadas **por frame** de animação | checklist `r9` — hoje hitbox funciona, mas não é fine-tune por sheet |
| Sheets AAA multi-frame (run/atk/ult mais fluidos) | MVP usa sheets legíveis; upgrade de arte depois |
| BGM dedicado de boss | há `hub_loop` + `stage_loop`; **sem** `boss_loop` ainda |
| UI de volume no hub | volumes **persistem no save** via `Audio`; falta tela de settings amigável (⚙ hoje → créditos) |
| PERSONAGENS no hub | ✅ tela select real (14; locked recusa; save do id) |
| Missões / XP / social no hub | GDD: fase 2+ / fora offline |

### 3) Conteúdo em escala (Fase F)

- ✅ Elenco 14 (trio + Hashiras + Yoriichi + Muzan) — um player, 14 `CharacterDef`
- Mundos W2–W5 (ids de unlock já estáveis: `w2_boss` … `w5_05`; personagem fica locked até o mundo existir)
- Arte própria por caçador (hoje: modulate/placeholder em cima dos frames do Tanjiro)

### 4) Release “sério” (Fase G)

| Item | Status |
|------|--------|
| APK **debug** no círculo | ✅ existe |
| Keystore **release** + backup **fora do git** | ⬜ `q6` / `f26` |
| Versão semver + changelog na mão do amigo | 🟡 bump via `scripts/publish-update.ps1` + Release; keystore release ainda não |
| Auto-update no telefone do sobrinho | 🟡 código no APK; falta playtest no aparelho (`docs/AUTO-UPDATE.md`) |
| Play Store | ❌ **fora de escopo** (IP fan game) |

### 5) Estudos / processo (opcional)

- Tutoriais Godot oficiais (`e1`–`e3`)  
- Ler riscos em voz alta com o sobrinho (`k1`)  
- Nomes de skill / balance fino com playtest humano  

---

## Decisões GDD fechadas no código (defaults)

| Tema | Default MVP |
|------|-------------|
| Skills Tanjiro | Corte em Arco / Investida / Respiração |
| Elenco | `CharacterCatalog` 14 ids; save `unlocked_characters` + `current_character_id` |
| Upgrades loja | HP, Dano, Velocidade, Dash CD |
| Morte na fase | perde moedas da run (`lose_run_coins`) |
| Upgrades | **globais** |
| Elite / boss moedas | elite 20 / boss clear bank da run |

---

## Como instalar

```
export/TreinamentoHashira-debug.apk
```

Desinstale a versão antiga → instale esta → celular **deitado**.

Prints de prova (emulador): `export/playtest_shots/` (incl. hub/mapa/fase).

---

## Mapa de docs (o que atualizar quando)

| Arquivo | Papel |
|---------|--------|
| **`docs/STATUS-PROGRESSO.md`** | Snapshot “onde estamos / o que falta” — **atualizar sempre** |
| `docs/PLAYTEST-SOBRINHO.md` | Checklist humano 10 min (playtest sem explicar) |
| `tools/run_smokes.ps1` | Suite headless; exit ≠ 0 se falhar |
| `CHANGELOG.md` | O que entrou em cada versão |
| `docs/CHECKLIST-MESTRE.html` | Checklist longo; marcações no browser + snapshot de fase no HTML |
| `docs/GDD-DECISOES.md` | Decisões de produto (só muda com decisão nova) |
| `docs/PLANEJAMENTO-TECNICO.md` | Plano histórico de setup; **§13 “próximos passos” está superado** pelo MVP |

---

## Histórico

| Data | Evento |
|------|--------|
| 2026-08-03 | GDD + boot/hub |
| 2026-08-05 | W1 playable + arte + áudio + frentes |
| 2026-08-06 | **MVP W1 COMPLETO** (pause, créditos, polimento residual, APK) |
| 2026-08-07 | Hotfix `SceneRouter` (SHOP duplicado); docs alinhados |
| 2026-08-07 | **Playable pass:** touch mouse-safe, ondas W1, coins magnet, player feel, smoke PASS |
| 2026-08-07 | **Visual pass:** chroma moeda (sem magenta), botões lacados labeled, escala coin/player/oni |
| 2026-08-07 | **Playtest gate:** e2e combat reforçado, `run_smokes.ps1`, PLAYTEST-SOBRINHO, seção premium wave |
