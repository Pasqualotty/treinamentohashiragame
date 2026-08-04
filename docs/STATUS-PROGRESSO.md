# Status do projeto — Treinamento Hashira

**Atualizado:** 2026-08-03 (skills design/arte + handbook engine)  
**Fonte de produto:** `GDD-DECISOES.md` · **Roadmap:** `CHECKLIST-MESTRE.html` §7 · **Setup:** `SETUP-AMBIENTE.md`  
**Engine:** `docs/engine/README.md` · **Skills:** `/pasqualotti-game-design` · `/grok-imagine-game-assets`

---

## Onde estamos (1 frase)

**Boot e navegação meta funcionam no PC** (splash → loading → hub → mapa stub).  
**Ainda não existe fase de combate jogável.** Ambiente Godot + SDK Android prontos.

---

## Roadmap (checklist §7) — progresso

| Fase | Nome | Status | Notas |
|------|------|--------|-------|
| **A** | Fundação produto + repo | ✅ quase | Workshop GDD feito; git + Godot + pastas; checklist HTML em uso |
| **B** | Hello + input + pixel | 🟡 parcial | Boot/hub ok; stretch + filter off no project; **InputMap + touch UI** faltam; **APK no celular** falta (SDK ok) |
| **C** | Vertical slice combate | ⬜ próximo | Player, ataques, breath, oni, HUD, fase curta |
| **D** | Meta (mapa visual, loja, save) | ⬜ | Mapa hoje = botões stub; save base no autoload Game |
| **E** | Arte & feel | 🟡 pack v0.1 | Imagine: Tanjiro L/R, oni, chão, moeda, touch row, keyart — ver `assets/pack_v01/` |
| **F** | Conteúdo em escala | ⬜ | |
| **G** | Noite dos amigos (APK) | ⬜ | |

### Detalhe do que já passou no Play (PC)

| Item | Status |
|------|--------|
| Splash logo Pasqualotti | ✅ validado |
| Loading barra + textos | ✅ validado |
| Hub (JOGAR / loja stub / chars stub) | ✅ validado |
| JOGAR → mapa Mundo 1 | ✅ validado |
| Mapa visual (nós/caminho) | ❌ stub de botões (“em breve”) |
| Fase 1 combate | ❌ |
| Touch controls | ❌ |
| APK no telefone | ❌ (SDK instalado; export Godot ainda não) |

### Ambiente

| Item | Status |
|------|--------|
| Godot 4.7.1 | ✅ |
| OpenJDK 17 | ✅ |
| Android SDK (platform 35, NDK, build-tools) | ✅ |
| Licenças SDK | ✅ |
| Debug keystore | ✅ |
| Paths no Editor Settings Godot | ⏳ colar 1x se ainda não |

---

## Próximo foco canônico (doc)

**Fase B residual + Fase C (vertical slice)** — sem pular para elenco/W2.

Ordem saudável:

1. InputMap + HUD touch (B)  
2. Player move/pulo/dash (C)  
3. Ataque básico + hitbox (C)  
4. Breath + ultimate (C)  
5. Oni fraco + moedas no chão (C)  
6. Fase tilemap curta + goal + link no mapa (C)  
7. Em paralelo “leve”: polish mapa visual, loja stub dados, SFX marca  

---

## Decisões ainda abertas (bloqueiam pouco)

Ver `GDD-DECISOES.md` §9. Principais:

- Morreu na fase: perde moedas da run ou banka tudo?  
- Nomes das 2 skills do Tanjiro  
- 4 upgrades da loja v1  
- JOGAR já fecha em → mapa ✅  

---

## Histórico curto

| Data | Evento |
|------|--------|
| 2026-08-03 | GDD + checklist + plano técnico |
| 2026-08-03 | Godot/JDK/SDK/keystore; bootstrap cenas |
| 2026-08-03 | Playtest humano: splash → loading → hub → mapa ok |
