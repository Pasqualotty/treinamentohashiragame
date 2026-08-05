# Status do projeto â€” Treinamento Hashira

**Atualizado:** 2026-08-05  
**Fonte de produto:** `GDD-DECISOES.md` Â· **Roadmap:** `CHECKLIST-MESTRE.html` Â§7 Â· **Setup:** `SETUP-AMBIENTE.md`  
**Engine:** `docs/engine/README.md` Â· **Skills:** `/pasqualotti-game-design` Â· `/grok-imagine-game-assets`

---

## Onde estamos (1 frase)

**Boot e hub polido funcionam no PC** (splash â†’ loading â†’ hub com Tanjiro animado â†’ mapa stub).  
**Sandboxes de combate existem** (movimento, hitbox/dummy, HUD, touch). Ainda falta fase real no mapa, oni com drop, ultimate completo e APK no celular.

---

## Roadmap (checklist Â§7) â€” progresso

| Fase | Nome | Status | Notas |
|------|------|--------|-------|
| **A** | FundaÃ§Ã£o produto + repo | âœ… | GDD, git, Godot, pastas, engine handbook, skills |
| **B** | Hello + input + pixel | ðŸŸ¡ parcial | Boot/hub OK; **InputMap + touch combate** âœ…; **APK** ainda nÃ£o |
| **C** | Vertical slice combate | ðŸŸ¡ parcial | Move/pulo/dash + atk bÃ¡sico + HUD + touch; falta skills/ult/oni/fase no mapa |
| **D** | Meta (mapa visual, loja, save) | ðŸŸ¡ | Mapa = botÃµes stub; **save base** no autoload `Game` |
| **E** | Arte & feel | ðŸŸ¡ pack + hub | Pack v0.1 + hub Tanjiro v3 (idle/blink/flourish, BG, botÃµes) |
| **F** | ConteÃºdo em escala | â¬œ | |
| **G** | Noite dos amigos (APK) | â¬œ | |

### Detalhe do que jÃ¡ passou no Play (PC)

| Item | Status |
|------|--------|
| Splash logo Pasqualotti | âœ… validado |
| Loading barra + key art | âœ… |
| Hub (JOGAR / loja stub / chars stub) | âœ… + polish visual |
| Tanjiro hub idle + blink + attack flourish | âœ… |
| Fundo hub animado + botÃµes temÃ¡ticos | âœ… |
| JOGAR â†’ mapa Mundo 1 | âœ… |
| Mapa visual (nÃ³s/caminho) | âŒ stub de botÃµes (â€œem breveâ€) |
| Sandbox move (andar/pulo/dash) | âœ… `scenes/battle/sandbox_move.tscn` |
| Sandbox combate (hitbox + dummy) | âœ… `scenes/battle/sandbox_combat.tscn` |
| HUD combate (HP/breath/coins run) | âœ… `scenes/ui/combat_hud_demo.tscn` |
| Touch controls de combate | âœ… `scenes/ui/combat_touch_test.tscn` |
| Fase 1 no mapa | âŒ |
| APK no telefone | âŒ (SDK instalado; export ainda em andamento) |

### Ambiente

| Item | Status |
|------|--------|
| Godot 4.7.1 | âœ… |
| OpenJDK 17 | âœ… |
| Android SDK (platform 35, NDK, build-tools) | âœ… |
| LicenÃ§as SDK | âœ… |
| Debug keystore | âœ… |
| Paths no Editor Settings Godot | â³ colar 1Ã— se ainda nÃ£o (`docs/android-paths.txt`) |
| `export_presets.cfg` | âŒ |

---

## PrÃ³ximo foco canÃ´nico

**Fase B residual + Fase C (vertical slice)** â€” sem pular para elenco/W2.

Ordem saudÃ¡vel:

1. Paths Android no Editor + (quando quiser) Hello APK  
2. InputMap + HUD touch (B)  
3. Player move/pulo/dash (C)  
4. Ataque bÃ¡sico + hitbox (C)  
5. Breath + ultimate (C) â€” API jÃ¡ no `Game`  
6. Oni fraco + moedas no chÃ£o (C)  
7. Fase tilemap curta + goal + link no mapa (C)  
8. Em paralelo leve: SFX marca, polish mapa visual, loja dados  

---

## DecisÃµes ainda abertas (bloqueiam pouco)

Ver `GDD-DECISOES.md` Â§9. Principais:

- Morreu na fase: perde moedas da run ou banka tudo? (cÃ³digo jÃ¡ tem run vs banked)  
- Nomes das 2 skills do Tanjiro  
- 4 upgrades da loja v1  
- Rewards elite/boss  

Fechado: paisagem, 1280Ã—720, side-scroller, puloÃ—1, dash, controles L/R, JOGAR â†’ mapa, MVP escopo.

---

## HistÃ³rico curto

| Data | Evento |
|------|--------|
| 2026-08-03 | GDD + checklist + plano tÃ©cnico |
| 2026-08-03 | Godot/JDK/SDK/keystore; bootstrap cenas |
| 2026-08-03 | Playtest humano: splash â†’ loading â†’ hub â†’ mapa ok |
| 2026-08-03 | Pack v0.1 Imagine + engine handbook + skills |
| 2026-08-03â€¦05 | Hub polish: Tanjiro v3, frames, BG, botÃµes, layout pÃ©s no chÃ£o |
| 2026-08-05 | Checklist mestre atualizado (snapshot + checks alinhados ao repo) |


