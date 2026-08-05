# Status do projeto — Treinamento Hashira

**Atualizado:** 2026-08-05  
**Fonte de produto:** `GDD-DECISOES.md` · **Roadmap:** `CHECKLIST-MESTRE.html` §7 · **Setup:** `SETUP-AMBIENTE.md`  
**Engine:** `docs/engine/README.md` · **Skills:** `/pasqualotti-game-design` · `/grok-imagine-game-assets`

---

## Onde estamos (1 frase)

**Boot e hub polido funcionam no PC** (splash → loading → hub com Tanjiro animado → mapa stub).  
**Sandboxes de combate existem** (movimento, hitbox/dummy, HUD, touch). Ainda falta fase real no mapa, oni com drop, ultimate completo e APK no celular.

---

## Roadmap (checklist §7) — progresso

| Fase | Nome | Status | Notas |
|------|------|--------|-------|
| **A** | Fundação produto + repo | ✅ | GDD, git, Godot, pastas, engine handbook, skills |
| **B** | Hello + input + pixel | 🟡 parcial | Boot/hub OK; **InputMap + touch combate** ✅; **APK** ainda não |
| **C** | Vertical slice combate | 🟡 parcial | Move/pulo/dash + atk básico + HUD + touch; falta skills/ult/oni/fase no mapa |
| **D** | Meta (mapa visual, loja, save) | 🟡 | Mapa = botões stub; **save base** no autoload `Game` |
| **E** | Arte & feel | 🟡 pack + hub | Pack v0.1 + hub Tanjiro v3 (idle/blink/flourish, BG, botões) |
| **F** | Conteúdo em escala | ⬜ | |
| **G** | Noite dos amigos (APK) | ⬜ | |

### Detalhe do que já passou no Play (PC)

| Item | Status |
|------|--------|
| Splash logo Pasqualotti | ✅ validado |
| Loading barra + key art | ✅ |
| Hub (JOGAR / loja stub / chars stub) | ✅ + polish visual |
| Tanjiro hub idle + blink + attack flourish | ✅ |
| Fundo hub animado + botões temáticos | ✅ |
| JOGAR → mapa Mundo 1 | ✅ |
| Mapa visual (nós/caminho) | ❌ stub de botões (“em breve”) |
| Sandbox move (andar/pulo/dash) | ✅ `scenes/battle/sandbox_move.tscn` |
| Sandbox combate (hitbox + dummy) | ✅ `scenes/battle/sandbox_combat.tscn` |
| HUD combate (HP/breath/coins run) | ✅ `scenes/ui/combat_hud_demo.tscn` |
| Touch controls de combate | ✅ `scenes/ui/combat_touch_test.tscn` |
| Fase 1 no mapa | ❌ |
| APK no telefone | ❌ (SDK instalado; export ainda em andamento) |

### Ambiente

| Item | Status |
|------|--------|
| Godot 4.7.1 | ✅ |
| OpenJDK 17 | ✅ |
| Android SDK (platform 35, NDK, build-tools) | ✅ |
| Licenças SDK | ✅ |
| Debug keystore | ✅ |
| Paths no Editor Settings Godot | ⏳ colar 1× se ainda não (`docs/android-paths.txt`) |
| `export_presets.cfg` | ❌ |

---

## Próximo foco canônico

**Fase B residual + Fase C (vertical slice)** — sem pular para elenco/W2.

Ordem saudável:

1. Paths Android no Editor + (quando quiser) Hello APK  
2. InputMap + HUD touch (B)  
3. Player move/pulo/dash (C)  
4. Ataque básico + hitbox (C)  
5. Breath + ultimate (C) — API já no `Game`  
6. Oni fraco + moedas no chão (C)  
7. Fase tilemap curta + goal + link no mapa (C)  
8. Em paralelo leve: SFX marca, polish mapa visual, loja dados  

---

## Decisões ainda abertas (bloqueiam pouco)

Ver `GDD-DECISOES.md` §9. Principais:

- Morreu na fase: perde moedas da run ou banka tudo? (código já tem run vs banked)  
- Nomes das 2 skills do Tanjiro  
- 4 upgrades da loja v1  
- Rewards elite/boss  

Fechado: paisagem, 1280×720, side-scroller, pulo×1, dash, controles L/R, JOGAR → mapa, MVP escopo.

---

## Histórico curto

| Data | Evento |
|------|--------|
| 2026-08-03 | GDD + checklist + plano técnico |
| 2026-08-03 | Godot/JDK/SDK/keystore; bootstrap cenas |
| 2026-08-03 | Playtest humano: splash → loading → hub → mapa ok |
| 2026-08-03 | Pack v0.1 Imagine + engine handbook + skills |
| 2026-08-03…05 | Hub polish: Tanjiro v3, frames, BG, botões, layout pés no chão |
| 2026-08-05 | Checklist mestre atualizado (snapshot + checks alinhados ao repo) |
