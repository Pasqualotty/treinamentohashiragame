# GDD curto — decisões fechadas

**Projeto:** Treinamento Hashira (2D · Android · fan / uso pessoal)  
**Estúdio:** Pasqualotti Studio  
**Atualizado:** 2026-09-12 (sala no celular — progresso vivo em `STATUS-PROGRESSO.md`)

---

## 1. Tela e câmera

| Decisão | Valor | Status |
|---------|-------|--------|
| Orientação | **Paisagem** (celular deitado) | ✅ |
| Resolução de design | **1280×720** (project.godot) | ✅ em uso no Play |
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
      • Texto opcional: “Carregando…” (não “Conectando-se…” — boot sem rede)
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

- Offline-first no **boot**: texto **“Carregando…”** / “Preparando o dojo…” — **não** “Conectando-se…”. Check da sala da estrela só **depois** do hub (Criar/Entrar).
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
| Centro | Brawler em pose | **Personagem atual** (idle showcase; não é sempre Tanjiro) | ✅ |
| CTA grande amarelo | JOGAR | **JOGAR** → **mapa do mundo** (escolhe a fase) | ✅ |
| Topo moedas / recursos | Gems, coins, bling | **Moedas** (e depois outros se precisar) | ✅ moedas |
| Topo perfil | Nick + ícone | Nick local / “Caçador” + avatar | ✅ simples |
| Esquerda LOJA | Shop | **Loja de upgrades** | ✅ |
| Esquerda lista chars | Brawlers | **Personagens** (15 no catálogo; Tanjiro starter; Nezuko livre) | ✅ tela select |
| Esquerda missões / XP | Battle pass vibe | Missões / XP | ⏳ fase 2 |
| Direita **Amigos** | Social | Botão **AMIGOS** (esquerda, peso de Loja) + **gaveta** da direita. Sem coluna plantada. | ✅ |
| Direita Clube / Notícias / Eventos | Social online | Fora | ❌ omitir |
| Baixo seletor de modo | Combate solitário + mapa | **Mapa / próxima fase** + info do mundo | ✅ |
| Setas + / skin | Skins | Trocar personagem / skin | ⏳ char select simples OK |

#### Wireframe hub (Amigos = botão; lista = gaveta)

```
┌────────────────────────────────────────────────────────────────────┐
│ [👤 nick]                         🪙 1234                   [⚙]  │
├────────┬───────────────────────────────────────────────────────────┤
│ LOJA   │                                                           │
│ PERSONA│     PERSONAGEM ATUAL (centro)                             │
│  GENS  │         idle / showcase                                   │
│ AMIGOS │                                                           │
├────────┴──────────────────────┬────────────────────────────────────┤
│  Escolha o mundo e a fase…    │            [  JOGAR  ]             │
└───────────────────────────────┴────────────────────────────────────┘

Toque AMIGOS → gaveta desliza da direita (painel sólido, topo→embaixo; JOGAR não vaza):
                         │ AMIGOS              [Fechar] │
                         │ Ninguém                      │
                         │ [ Criar sala ]               │
                         │ [ Entrar     ]               │
```

**Amigos:** **Adicionar amigo** pelo **nome do perfil**. A outra pessoa **Aceita** ou **Não**. Só então fica na lista. **+** convida pra **sala já criada**. Sem aceite, sem lista. Sem código de amigo na tela.  
**Sala (host):** código de 6 caracteres (tap = copiar) + “Esperando amigo…” / “Amigo entrou” + **modo** (`2 vs oni` · `4 vs oni` · `Mapa de batalha` · `1v1`) + lista com **+** + Fechar sala.  
**Entrar (guest):** convite da sala (entra sozinho) **ou** código 6 na mão. Beacon Wi-Fi primeiro (~2,5 s); senão a **sala da estrela** (host baked no APK) — os dois só **saem** pro VPS (NAT da casa não precisa abrir porta). Sem campo de IP na gaveta.  
**JOGAR:** sempre abre o **mapa**. Só o **host** escolhe a fase no coop vs oni. Guest no hub: “O anfitrião escolhe a fase”.

**2 vs oni:** 2 jogadores. `MAX_CLIENTS = 1`.  
**4 vs oni:** 4 celulares, cada um um caçador. `MAX_CLIENTS = 3`. Câmera nos vivos. Oni no mais perto. 2P/solo não mudam.  
**Mapa de batalha:** até 4 celulares. Host toca **Começar**. Sem amigo (F6 ou sala sozinha), as vagas viram máquina. Pátio grande com pads de vida / respiração / haste. Depois do fim: **De novo** ou **Sair**. **1v1:** 2P. Com sala + amigo, cada celular controla o seu (mesmo `InputFrame` da fase). Sem sessão (F6), dummy local. Sem a cena: toast em PT e a sala continua.

Mesmo Wi-Fi **ou** cada um na sua casa (sala da estrela no APK; se o NAT bloquear, o relay carrega o ENet). ENet 17777 + beacon UDP 17778. Código filtra o beacon (não é o IP). Host simula a fase; o amigo manda input. Sem Firebase, Play Games. Save `friends` = nomes, **sem IP**. Cap 16. Handshake `proto=1` + `version_code` — APK diferente recusa em PT. PC local = reserva de dev, não o caminho do sobrinho.

**Não entra:** split-screen, clube, notícias, eventos, ranking, sync de loja. Implementar o mapa Brawl e o duelo = outras frentes.

**JOGAR (fechado):** opção **A** — abre o **mapa do mundo**; o jogador escolhe a fase (ou boss se desbloqueado).  
Não entra direto na fase a partir do hub.

**Regra de cena:** splash, loading e hub **não** são combate.  
Combate = `stage_*` com HUD de luta (stick, dash, skills).

**Assets de marca**

| Arquivo | Uso |
|---------|-----|
| `assets/branding/pasqualotti-studio-logo.png` | Splash do estúdio |
| SFX marca | `assets/audio/sfx/brand_sting.wav` ✅ |
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
- Efeito: impulso rápido no eixo X (curto) com ease-out no fim, depois volta ao controle normal
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

**Drops atuais** (pickup no chão; ao limpar a fase o bank da run vai pro save):

| Fonte | Moedas no pickup |
|-------|------------------|
| Oni fraco | **10** |
| Elite | **20** |
| Ranged | **12** |
| Charger | **16** |
| Bosses | **70–120** (fogo 70 · dual 75 · W1 80 · castelo 85 · final 120) **além** do bank da run no clear |

**Loja (4 upgrades globais, 3 níveis, custos iguais nos 4):** `50 / 200 / 420` → 720 por stat, **2880** no máximo. W1 sozinho não esgota a loja.

**Poder por compra:** HP **+15** · Dano **+3** no básico **e** ripple nas skills (s1 **+4** / s2 **+3** / ult **+6** por nível) · velocidade **+20** · dash CD **−0,12 s** (chão 0,35). Sem 5º upgrade, XP, mana ou custo de skill em moeda.

---

## 7. Escopo MVP

| Item | Valor | Status |
|------|-------|--------|
| Splash marca + hub | Sim | ✅ no fluxo |
| Mundos | **5** (W1 starter; W2–W5 abrem ao limpar o boss anterior) | ✅ catálogo + mapa |
| Fases | W1: 5 + boss · W2: 3 + boss · W3: 4 + boss · W4: 4 + boss · W5: 3 + boss | ✅ ids estáveis |
| Playable | **Elenco 15** (Tanjiro starter; Nezuko livre; resto por mundo) | ✅ |
| Loja | **4 upgrades** | ✅ |
| Onis | **2 tipos** | ✅ |
| Distribuição | APK sideload + OTA próprio (GitHub Releases) | ✅ |
| Amigos / LAN 2P+4P | Lista no hub + sala código 6 + modos na sala | ✅ |

### Desafio oni (2026-09-10)

- Telegraph obrigatório: wind-up cancela no hit; swing (ATTACK) do fraco/elite completa.
- Fraco 48 HP / 7 dano. Elite 96 HP / 11 dano (mais rápido que o fraco).
- W1 onda 1 = 2 fracos. Portal só abre depois das ondas (`waves_finished`).
- Drop (`coin_reward`) inalterado.

---

## 8. Playtest

- Sobrinho **ajuda a testar** (acordo semanal no celular, mesmo feio) — ✅ confirmado
- Builds feias cedo > polish sem feedback

---

## 9. Decisões fechadas no MVP (2026-08-06)

- [x] Print de referência do hub + loading (Brawl Stars UX)
- [x] Jingle / SFX da marca (sting procedural no splash)
- [x] Key art loading (pack v0.1 + loading)
- [x] Skills Tanjiro MVP: **Corte em Arco** / **Investida**
- [x] Upgrades loja v1: **HP · Dano · Velocidade · Dash CD**
- [x] Resolução base: **1280×720** paisagem
- [x] Morte na fase: **perde moedas da run** (bank só no clear)
- [x] Upgrades: **globais** no MVP
- [x] JOGAR → **mapa do mundo**
- [x] Elite ~20 moedas no pickup; boss = clear da run

### Economia e skills (2026-09-10)

- Custos da loja: **50 / 200 / 420** nos 4 upgrades (HP · Dano · Velocidade · Dash CD).
- Upgrade **Dano** escala básico (+3) **e** skill 1 (+4), skill 2 (+3) e ultimate (+6) no mesmo nível.
- Upgrades continuam **globais** — não por personagem e não resetam por mundo.
- Kits de caçador declaram atk / s1 / s2 / ult / CDs no `PlayerStats` (não no `CharacterDef`).

### Auto-update (família, 2026-08-26)

- Sem Play Store. Manifesto JSON remoto + APK no GitHub Releases.
- Check **no hub**, depois do boot — nunca trava splash/loading/combate.
- `version_code` remoto > local → aviso curto em PT (ATUALIZAR / Depois).
- Sem net / falhou o check → o jogo abre normal.
- Download falhou → tentar de novo + jogar assim mesmo.
- PC/editor: check não bate na rede.
- Fluxo de publicação: `docs/AUTO-UPDATE.md`

### Amigos / sala (2026-09-10, casa↔casa 2026-09-10, modos 2026-09-10)

- Direita do hub = **Amigos** (lista + sala). Clube / notícias / eventos continuam fora.
- Depois de **Criar sala**, a sala abre **lobby em tela cheia**: equipe à esquerda, caçador no centro, modos à direita, faixa de retratos embaixo. Cada celular escolhe o próprio caçador ali (não cai em Inosuke). Lista de amigos continua na gaveta.
- Depois de **Criar sala**, o anfitrião escolhe: `2 vs oni` · `4 vs oni` · `Mapa de batalha` · `1v1`. JOGAR ouro **não** é esse seletor — continua o mapa do mundo.
- 2 vs oni: 2 jogadores, `MAX_CLIENTS = 1`. 4 vs oni: 4 celulares (`MAX_CLIENTS = 3`), câmera nos vivos, oni no mais perto. 2P/solo intactos.
- Mapa de batalha: até 4, Começar na sala, pátio com pads, De novo/Sair. 1v1: 2P. Sala + peer = roster. F6 sem sessão = máquina. Sem a cena: toast PT, sala não quebra.
- Wi-Fi da casa **ou** casa↔casa pela **sala da estrela** (host baked no APK). Sem campo de IP na gaveta. Host escolhe a fase no mapa no coop vs oni.
- Beacon primeiro; senão a sala da estrela. Sala caiu: o jogo abre; Criar/Entrar avisa em PT. Boot **não** fala “Conectando-se…”.
- **Adicionar amigo** pelo nome do perfil (os dois no hub). O **x** apaga. Código de 6 da sala continua (Zap).
- Moedas da run = pote do grupo; no clear o grupo banka no save local. 2P: morte de qualquer um = wipe. 4 vs oni: wipe quando ninguém vivo resta.
- Textos de sala: “Criar sala”, “Entrar”, “Procurando na rede…”, “Procurando o amigo…”, “Amigo entrou”, “A sala da estrela está desligada”.
- Sem persistir IP. Sem Firebase / Play Games. PC local = reserva de dev.

### Ainda pos-MVP

- Arte final por mundo / por caçador, release keystore, playtest no celular

---

## 10. Histórico

| Data | O quê |
|------|--------|
| 2026-08-03 | Rodada 1: paisagem, pulo, layout L/R, MVP, side-scroller, playtest |
| 2026-08-03 | Rodada 2: splash marca + hub; dash c/ cooldown; respiração por hit; moedas no chão + contador topo; 1 pulo; sobrinho tester; logo em `assets/branding/` |
| 2026-08-03 | Rodada 3: boot = splash estúdio → loading (barra) → hub Brawl-like; refs em `docs/references/ui/`; social online fora do MVP |
| 2026-08-03 | Rodada 3b: JOGAR no hub → **mapa do mundo** (não pula fase direto) |
| 2026-08-03 | Playtest PC: splash → loading → hub → mapa stub OK; combate ainda não; ver STATUS-PROGRESSO |
| 2026-09-01 | Mapa com 5 mundos (W1 Montanha → W5 Céu Vermelho). W2 tranca até `w1_boss`. Ondas dos mundos novos no StageDef. Placeholder de BG por tema. |
| 2026-09-10 | Hub centro = personagem atual (não sempre Tanjiro). Elenco 15 com Nezuko playtest (unlock livre, kit = stats do Tanjiro). |
| 2026-09-12 | 15 kits únicos (ataque/skill/ult + ícones por id). Nezuko lifesteal 0.12; Inosuke 2 hits; Zenitsu dash; Shinobu reach fino; Gyomei hitbox grande. Stick/dash/pulo/pause iguais. |
| 2026-09-10 | Loja `[50, 200, 420]`; HP +15; Dano +3 com ripple de skill/ult; kits com números explícitos. Upgrades globais. |
| 2026-09-10 | Amigos no hub + sala LAN 2P (ENet + código 6 + beacon UDP). Sem nuvem. |
| 2026-09-10 | Casa↔casa: primeiro PC do meio (3a). Superado em 2026-09-12 pela sala da estrela no APK. |
| 2026-09-12 | Sala no celular: gaveta sem IP; sala da estrela baked; PC vira reserva de dev. |
| 2026-09-10 | Sala: 4 opções (`2 vs oni` · `4 vs oni` · `Mapa de batalha` · `1v1`). 4 vs oni joga (`MAX_CLIENTS=3`). Portas Brawl/1v1. |
| 2026-09-12 | Mapa/1v1: com sala o amigo joga (roster + InputFrame). Dummy só no F6. |
| 2026-09-12 | Mapa de batalha: até 4, pátio grande, pads, barras verde/amarelo/vermelho, skills no plano, De novo/Sair. |
| 2026-09-13 | Lobby da sala em tela cheia + escolha de caçador (não força Inosuke). |
| 2026-09-13 | Convite de amigo pelo nome do perfil (sem código de 8 na tela). |
