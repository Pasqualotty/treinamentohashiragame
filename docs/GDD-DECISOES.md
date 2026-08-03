# GDD curto — decisões fechadas

**Projeto:** Treinamento Hashira (2D · Android · fan / uso pessoal)  
**Estúdio:** Pasqualotti Studio  
**Atualizado:** 2026-08-03 (workshop Matheus — rodada 3 · refs Brawl Stars)

---

## 1. Tela e câmera

| Decisão | Valor | Status |
|---------|-------|--------|
| Orientação | **Paisagem** (celular deitado) | ✅ |
| Resolução de design | Proposta: **1280×720** (ou 640×360 pixel + scale) | ⏳ na 1ª cena Godot |
| Gênero / câmera nas fases | **Side-scroller** (perfil, avança a fase) | ✅ |
| Mapa do mundo | Existe (escolher fase / loja / progresso) | ✅ |
| Hub / estado padrão | Estilo *Brawl Stars home* (ver §2) | ✅ |
| Referência de UX | Prints em `docs/references/ui/` | ✅ |

**Aviso de IP:** Brawl Stars = **referência de layout/UX** apenas.  
Não copiar arte, logo, tipografia ou assets da Supercell. Splash nosso = **Pasqualotti Studio**.

---

## 2. Fluxo ao abrir o jogo (boot → hub)

Ordem **obrigatória** (confirmada com prints):

```
[1] SPLASH DO ESTÚDIO
      • Logo Pasqualotti Studio
      • Som característico da marca
      • Segundos curtos + fade

[2] TELA DE CARREGAMENTO DO JOGO  (refs: loading)
      • Arte de fundo / key art do jogo (Demon Slayer estilo nosso)
      • Barra de progresso 0% → 100%
      • Texto opcional: “Carregando…” (não “Conectando-se…” — somos offline)
      • Enquanto isso: carregar resources, save, cenas leves

[3] ESTADO PADRÃO (HUB)  (ref: hub Brawl-like)
      • Personagem no centro (idle showcase)
      • Botões laterais verticais + barra inferior + moedas no topo
      • CTA principal: JOGAR

[4] Do hub → mapa / fase side-scroller / loja / etc.
```

### Cenas Godot (nomes alvo)

| Ordem | Cena | Pasta |
|------:|------|--------|
| 1 | `splash_studio.tscn` | `scenes/boot/` |
| 2 | `loading.tscn` | `scenes/boot/` |
| 3 | `hub.tscn` | `scenes/main_menu/` (estado padrão) |
| 4 | `world_map.tscn` | `scenes/` |
| 5 | `stage_*.tscn` | `scenes/battle/` |

`project.godot` → main scene = **splash_studio**.

---

### 2.1 Loading (refs oficiais)

| Arquivo | O que copiar da ideia |
|---------|------------------------|
| `docs/references/ui/ref-loading-progress.png` | Key art full-screen + **barra** + % |
| `docs/references/ui/ref-loading-connecting.png` | Mesmo layout; texto de status embaixo |

**Nossas regras de loading:**

- Offline-first: texto **“Carregando…”** / “Preparando o dojo…” — **não** “Conectando-se…” (não há servidor no MVP).
- Barra reflete progresso real (load de cenas/assets) + mínimo de tempo pra não piscar (ex. 0.8s floor).
- Arte: key art própria (pixel / paint) — placeholder no começo.
- **Não** reutilizar assets de Brawl Stars.

---

### 2.2 Hub / estado padrão (ref oficial)

| Arquivo | Uso |
|---------|-----|
| `docs/references/ui/ref-hub-estado-padrao.png` | Layout canônico do hub |

#### Mapa visual (Brawl → Hashira)

```
┌────────────────────────────────────────────────────────────────────┐
│ [perfil/nome]  [rank/troféus?]     [moedas] [gemas?]     [menu ☰] │  TOPO
├──────────┬─────────────────────────────────────────┬───────────────┤
│ LOJA     │                                         │ NOTÍCIAS*     │
│ PERSONA- │         PERSONAGEM NO CENTRO            │ AMIGOS*       │
│ GENS     │         (idle / showcase)               │ CLUBE*        │
│ MISSÕES* │         setas trocar skin/char          │ EVENTOS*      │
│ XP bar   │                                         │               │
├──────────┴─────────────────────────────────────────┴───────────────┤
│  [modo / mapa da fase]              │  [  JOGAR  ]  CTA amarelo    │  BAIXO
└────────────────────────────────────────────────────────────────────┘
* = fase 2+ (só placeholder ou escondido no MVP)
```

#### Slot a slot — o que entra no **MVP** vs depois

| Zona na ref | Em Brawl Stars | No Treinamento Hashira | MVP? |
|-------------|----------------|------------------------|------|
| Centro | Brawler em pose | **Tanjiro** (idle showcase) | ✅ |
| CTA grande amarelo | JOGAR | **JOGAR** → **mapa do mundo** (escolhe a fase) | ✅ |
| Topo moedas / recursos | Gems, coins, bling | **Moedas** (e depois outros se precisar) | ✅ moedas |
| Topo perfil | Nick + ícone | Nick local / “Caçador” + avatar | ✅ simples |
| Esquerda LOJA | Shop | **Loja de upgrades** | ✅ |
| Esquerda lista chars | Brawlers | **Personagens** (só Tanjiro unlocked) | ✅ tela stub |
| Esquerda missões / XP | Battle pass vibe | Missões / XP | ⏳ fase 2 |
| Direita Notícias / Amigos / Clube | Social online | **Fora do MVP** (offline) | ❌ omitir |
| Baixo seletor de modo | Combate solitário + mapa | **Mapa / próxima fase** + info do mundo | ✅ |
| Setas + / skin | Skins | Trocar personagem / skin | ⏳ char select simples OK |

#### Wireframe hub MVP (sem social)

```
┌──────────────────────────────────────────────────────────────┐
│  [👤 Matheus]                    🪙 1234              [⚙]   │
├────────┬───────────────────────────────────┬─────────────────┤
│        │                                   │                 │
│  LOJA  │         TANJIRO (centro)          │  (vazio MVP     │
│ PERSONA│         idle loop                 │   ou Dicas)     │
│  GENS  │                                   │                 │
│        │                                   │                 │
├────────┴───────────────┬───────────────────┴─────────────────┤
│  W1 · próxima fase     │            [  JOGAR  ]              │
└────────────────────────┴─────────────────────────────────────┘
```

**JOGAR (fechado):** opção **A** — abre o **mapa do mundo**; o jogador escolhe a fase (ou boss se desbloqueado).  
Não entra direto na fase a partir do hub.

**Regra de cena:** splash, loading e hub **não** são combate.  
Combate = `stage_*` com HUD de luta (stick, dash, skills).

**Assets de marca**

| Arquivo | Uso |
|---------|-----|
| `assets/branding/pasqualotti-studio-logo.png` | Splash do estúdio |
| SFX marca (pendente) | `assets/audio/sfx/brand_sting.*` |
| `docs/references/ui/ref-*.png` | UX only — nunca importar como asset de jogo “oficial” |

---

## 3. Movimento

| Decisão | Valor | Status |
|---------|-------|--------|
| Pulo | **Sim** | ✅ |
| Pulos no ar | **Só 1** (sem double jump no MVP) | ✅ |
| Avançar | **Dash curto pra frente**, com **cooldown** | ✅ (B) |
| Direção do dash | Frente = lado que o personagem está olhando | ✅ |

**Dash (v0 técnico):**

- Input: `advance` / botão Avançar (esquerda do touch)
- Efeito: impulso rápido no eixo X (curto), depois volta ao controle normal
- Cooldown: valor em Resource de stats (ex. 0.8–1.2s — balance depois)
- I-frames no dash: **não** no MVP (pode virar upgrade)
- No ar: pode dash 1× até pousar? → default **sim, 1 dash aéreo**, reavalia no playtest

---

## 4. Controles touch (layout canônico)

Celular **deitado**. Esquerda = movimento; direita = combate.

```
┌────────────────────────────────────────────────────────────┐
│  HUD: HP · Barra de respiração · Moedas acumuladas         │
│                                                            │
│                     [ cena de combate ]                    │
│                                                            │
│  ESQUERDA                         DIREITA                  │
│  ┌─────────┐                      ┌──┐ ┌──┐ ┌──┐          │
│  │ Joystick│                      │Atk│ │H1│ │H2│          │
│  │ virtual │                      └──┘ └──┘ └──┘          │
│  │         │                      ┌──────────┐            │
│  │ [Dash]  [Pulo]                 │ Ultimate │            │
│  └─────────┘                      └──────────┘            │
│  (+ Pause)                                                 │
└────────────────────────────────────────────────────────────┘
```

### InputMap

| Ação | Touch | PC (dev) |
|------|-------|----------|
| `move_*` | Joystick | WASD / setas |
| `advance` | **Dash** (esquerda) | Shift / F |
| `jump` | Pulo | Espaço |
| `attack_basic` | Ataque básico | J / Z |
| `skill_1` | Habilidade 1 | K / X |
| `skill_2` | Habilidade 2 | L / C |
| `ultimate` | Ultimate (só se barra full) | I / V |
| `pause` | Pause | Esc |

### Combate (MVP Tanjiro)

| Botão | Função |
|-------|--------|
| Ataque básico | Corte rápido / combo curto |
| Habilidade 1 | Skill única do personagem |
| Habilidade 2 | 2ª skill única |
| Ultimate | Golpe forte de respiração; **só com barra no máximo** |

---

## 5. Respiração → Ultimate

| Regra | Valor | Status |
|-------|-------|--------|
| Como enche | **Acertar hits** nos onis (cada hit soma ao medidor) | ✅ |
| No máximo | Libera o botão / uso da **Ultimate** | ✅ |
| Ao usar | Consome a barra (zera ou gasta full — default **zera**) | ✅ default |
| Receber dano esvazia? | Não definido — default MVP: **não esvazia** | ⏳ opcional depois |
| Tempo sozinho enche? | **Não** no MVP (só hit) | ✅ |

HUD: barra de respiração visível; estado “cheia” com glow / botão ultimate habilitado.

---

## 6. Moedas (economia in-run + persistência)

| Regra | Valor | Status |
|-------|-------|--------|
| Drop | Oni morre → **moedas caem no chão** | ✅ |
| Coleta | Player (ou magnet curto) pega → somam no contador | ✅ default: andar por cima |
| HUD | Área **no topo** mostra quantas moedas **já estão acumuladas** nesta run/sessão de fase | ✅ |
| Persistência entre sessões | Total de moedas no save (pra loja) — creditadas ao coletar ou ao fim da fase | ⏳ default: **ao coletar** entra no total da run; ao **completar fase** bank no save (anti-perda se morrer no meio — ver nota) |

**Nota de design (recomendação técnica, playtest pode mudar):**

- Contador do topo = moedas da **fase atual** (coletadas no chão).
- Ao **completar** a fase → soma no total do save (loja).
- Se **morrer** na fase → perde só as da fase não banked (mantém save anterior).

Se preferirem “tudo que coletou no chão já é eterno mesmo morrendo”, avisar — vira farm fácil.

Valor oni fraco: **10** (checklist) — confirmar no balance.

---

## 7. Escopo MVP

| Item | Valor | Status |
|------|-------|--------|
| Splash marca + hub | Sim | ✅ no fluxo |
| Mundos | **1** (W1) | ✅ |
| Fases | **3** + **1 boss** | ✅ |
| Playable | **Só Tanjiro** | ✅ |
| Loja | **4 upgrades** | ✅ |
| Onis | **2 tipos** | ✅ |
| Distribuição | APK sideload | ✅ |

---

## 8. Playtest

- Sobrinho **ajuda a testar** (acordo semanal no celular, mesmo feio) — ✅ confirmado
- Builds feias cedo > polish sem feedback

---

## 9. Ainda aberto (próximo)

- [x] Print de referência do hub + loading (Brawl Stars UX)
- [ ] Jingle / SFX da marca Pasqualotti
- [ ] Key art própria pra loading (placeholder até ter arte)
- [ ] Nomes das 2 skills do Tanjiro
- [ ] Upgrades da loja v1 (quais 4)
- [ ] Resolução base final
- [ ] Morreu na fase: perde moedas da fase ou mantém o que coletou?
- [ ] Upgrades globais vs por personagem (sugestão: **globais** no MVP)
- [x] JOGAR → **mapa do mundo** (escolhe a fase) — opção A

---

## 10. Histórico

| Data | O quê |
|------|--------|
| 2026-08-03 | Rodada 1: paisagem, pulo, layout L/R, MVP, side-scroller, playtest |
| 2026-08-03 | Rodada 2: splash marca + hub; dash c/ cooldown; respiração por hit; moedas no chão + contador topo; 1 pulo; sobrinho tester; logo em `assets/branding/` |
| 2026-08-03 | Rodada 3: boot = splash estúdio → loading (barra) → hub Brawl-like; refs em `docs/references/ui/`; social online fora do MVP |
| 2026-08-03 | Rodada 3b: JOGAR no hub → **mapa do mundo** (não pula fase direto) |
