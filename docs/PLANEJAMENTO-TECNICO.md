# Plano técnico — Treinamento Hashira (2D · Android)

**Projeto:** Pasqualotti Studios · Demon Slayer fan game (uso pessoal / família e amigos)  
**Tipo:** 2D mobile Android  
**Status:** Fase A ✅ · Fase B parcial · boot validado no PC · combate ainda não  
**Data:** 2026-08-03  

**Decisões de produto:** [`docs/GDD-DECISOES.md`](./GDD-DECISOES.md)  
**Progresso vivo:** [`docs/STATUS-PROGRESSO.md`](./STATUS-PROGRESSO.md)

---

## 1. Visão em uma frase

Jogo **2D** de treino/combate inspirado em Demon Slayer, jogável no Android (seu telefone, do sobrinho e amigos), com foco em **aprender** desenvolvimento mobile de jogos do zero — sem intenção comercial.

---

## 2. Aviso de IP (importante, mas sem drama)

Demon Slayer / Kimetsu no Yaiba é **propriedade da Shueisha / ufotable / etc.**

| Pode (uso pessoal) | Evitar |
|--------------------|--------|
| Jogar no seu celular e dos amigos por sideload (APK) | Publicar na Play Store com nome/marca/personagens oficiais |
| Fan project de aprendizado | Monetizar, ads, IAP, crowdfunding com IP oficial |
| Arte **inspirada** / estilizada gerada por vocês | Copiar assets oficiais do anime/jogo comercial |

**Regra do projeto:** distribuir só por APK entre o círculo; não usar como “produto” nem na loja oficial com a marca.

---

## 3. Grok Imagine — dá pra gerar telas e design?

**Sim.** O Grok Build tem pipeline de assets de jogo:

| Tipo de arte | O que dá pra gerar | Skill / abordagem |
|--------------|--------------------|-------------------|
| Personagens (sprites estáticos) | Base, poses, turnaround | `game-asset-core` + `game-character-consistency` |
| Animações (walk, attack, idle) | Sequência de frames / sheets | `game-animation-frames` (vídeo → frames) |
| Cenários / chão / tiles | Texturas tileable | `game-tilesets` |
| UI (botões, painéis, barras, ícones, logo) | Estados hover/pressed etc. | `game-ui-icons` |
| Telas conceituais (mood / mock) | Menu, HUD, battle mockup | Imagine livre + depois virar assets “engine-ready” |

**O que o Imagine NÃO substitui sozinho:**
- Lógica do jogo (código, colisão, combate, save)
- Ajuste fino no editor (crop de sprite sheet, hitbox, 9-slice de UI)
- Balanceamento e playtest no telefone

**Fluxo saudável de arte:**
1. Definir **style bible** (1 frase + 1 imagem âncora) — ex.: “pixel art 32×48, silhueta nítida, paleta noturna japonesa”
2. Gerar **personagem base** e sempre reusar com *image edit* (consistência)
3. Gerar animações a partir da base (não regenerar do zero a cada pose)
4. Exportar PNG com fundo keyable / transparente
5. Importar no Godot (SpriteFrames / AnimatedSprite2D / TileSet)

---

## 4. Stack recomendada (decisão técnica)

### Recomendação principal: **Godot 4 + GDScript → Android (APK)**

| Critério | Por quê Godot 4 |
|----------|-----------------|
| Custo | 100% grátis, open source, **sem royalty** |
| 2D | Excelente (TileMap, AnimatedSprite, AnimationPlayer, Canvas) |
| Android | Export nativo para APK/AAB (sideload perfeito pro nosso caso) |
| Curva de aprendizado | GDScript parece Python — ótimo pra aprender |
| Tamanho do time | 2 pessoas (você + sobrinho): leve, rápido de abrir e brincar |
| Aprendizado transferível | Cenas, nós, signals, state machine, input touch — conceitos reais de game dev |

### Alternativas (e por que não agora)

| Stack | Prós | Contras no nosso caso |
|-------|------|------------------------|
| **Unity + C#** | Emprego, mercado, assets store | Instalação pesada, UI confusa no início, overkill 2D fan project |
| **Flutter + Flame** | Se já ama Flutter | Menos “jogo de verdade” no ecossistema; menos tutoriais de game design |
| **Defold** | Ótimo mobile 2D | Comunidade menor que Godot |
| **Native Android (Kotlin + Canvas/libGDX)** | Aprende Android puro | 10× mais esforço pra 1º jogo; frustra o sobrinho |
| **Construct / GDevelop** | Visual, rápido | Menos aprendizado de engenharia (você pediu melhores práticas) |

**Decisão de aprendizado:** Godot ensina o *jeito de pensar* de um game engine (árvore de cenas, process loop, resources) sem trancar em stack proprietária.

### Linguagem

- **GDScript** no início (100% do protótipo e MVP)
- C# no Godot só se no futuro quiser; **não** misturar no dia 1

---

## 5. Ferramentas — lista completa

### Obrigatórias (mínimo pra jogar no celular)

| Ferramenta | Uso | Onde baixar |
|------------|-----|-------------|
| **Godot 4.x (Standard)** | Editor + engine | https://godotengine.org/download/windows/ |
| **OpenJDK 17** (Temurin) | Build Android | https://adoptium.net/ |
| **Android Studio** (só SDK) | SDK Platform-Tools, Build-Tools, Platform 35, NDK, CMake | https://developer.android.com/studio |
| **Git** | Versionamento | https://git-scm.com/ |
| **GitHub Desktop** ou CLI | Sync entre PCs (opcional mas ótimo) | — |

> No PC deste planejamento (2026-08-03): **Godot, Java e Android SDK ainda NÃO instalados.**

### Altamente recomendadas (arte + produtividade)

| Ferramenta | Uso |
|------------|-----|
| **Grok Imagine** (nesta conversa / Grok) | Sprites, UI, tiles, mockups |
| **Aseprite** (pago, barato) ou **LibreSprite** (grátis) | Pixel art, frames, export sheet |
| **Krita** ou **Photopea** (web) | Ajuste de PNG, máscaras |
| **Audacity** | Efeitos sonoros simples / recorte |
| **Freesound / Kenney.nl** | SFX e placeholders free (respeitar licença) |
| **Obsidian / Notion / MDS** | Design doc e backlog (opcional) |

### No telefone (teste)

| Item | Uso |
|------|-----|
| Ativar **Opções do desenvolvedor** + **Depuração USB** | Instalar APK direto do PC |
| Ou só copiar APK e abrir com instalador (sideload) | Distribuição pros amigos |
| App tipo **Files** + “instalar apps desconhecidos” permitido | Instalação sem cabo |

### O que NÃO precisamos no dia 1

- Conta Google Play Console (só se um dia for publicar)
- Blender / Unreal (é 2D)
- Servidor / multiplayer online
- Ads SDK, analytics pesado, IAP

---

## 6. Instalação no Windows (ordem canônica)

### Fase A — Editor de jogo (1º dia, ~30 min)

1. Baixar **Godot 4.x Standard** (não precisa da versão .NET no começo).
2. Extrair pra pasta estável, ex.:  
   `C:\Users\mathe\Tools\Godot\`
3. Criar atalho no desktop.
4. Abrir Godot → **New Project** → path deste repositório → renderer **Forward+** ou **Mobile** (para Android, **Mobile** ou **Compatibility** costuma ser mais seguro em aparelhos fracos).
5. Fazer o tutorial oficial 2D “Dodge the Creeps” (1–2h) **antes** de metralhar feature do Hashira.

### Fase B — Android export (2º dia, ~1–2h)

1. Instalar **Temurin OpenJDK 17**.
2. Instalar **Android Studio** → na primeira abertura, instalar SDK padrão.
3. SDK Manager — garantir (versões alinhadas à doc Godot atual; checar docs oficiais na hora):
   - Android SDK Platform-Tools
   - Android SDK Build-Tools
   - Android SDK Platform (API 35 típico)
   - Command-line Tools
   - NDK + CMake (Godot lista versões na doc de export)
4. Godot → **Editor → Editor Settings → Export → Android**:
   - `Java SDK Path` → pasta do JDK 17
   - `Android SDK Path` → tipicamente `%LOCALAPPDATA%\Android\Sdk`
5. **Project → Export → Add → Android**  
   - Baixar Android export templates quando o Godot pedir  
   - Package name estilo: `studio.pasqualotti.hashira`  
   - Gerar **debug APK** e instalar no celular

### Fase C — Git (mesmo dia da Fase A se possível)

```text
git init
.gitignore padrão Godot (.godot/, export/, *.import às vezes versionado — seguir template oficial)
```

Template `.gitignore` Godot: https://github.com/github/gitignore/blob/main/Godot.gitignore

### Checklist “Hello Android”

- [ ] Cena com Label “Olá Hashira”
- [ ] Export debug APK
- [ ] APK abre no celular e mostra a label
- [ ] Touch registra um print no console (via USB debugging) ou muda a label

**Só depois** começar personagem e combate.

---

## 7. Arquitetura do jogo (2D Godot — boas práticas)

### 7.1 Pensar em cenas (scenes), não em “um arquivo gigante”

```
res://
  project.godot
  assets/
    characters/
    ui/
    tiles/
    audio/
  scenes/
    boot/                 # splash / load
    main_menu/
    dojo/                 # hub de treino
    battle/
    characters/
      player/
      enemy/
    ui/
      hud.tscn
      pause_menu.tscn
  scripts/
    autoload/             # Game, Save, AudioBus, SceneRouter
    combat/
    characters/
  resources/              # Stats, moves, balance (.tres)
  data/                   # JSON opcional (diálogos, waves)
```

### 7.2 Autoloads (singletons) mínimos

| Nome | Responsabilidade |
|------|------------------|
| `Game` | Estado global, progressão (ranks, desbloqueios) |
| `Save` | Salvar/carregar em `user://` (JSON ou ConfigFile) |
| `Audio` | Música / SFX com volume |
| `SceneRouter` | Troca de cena com fade (evita `get_tree().change_scene` espalhado) |

**Regra:** autoload **não** vira lixeira de tudo. Combate específico fica em nós da cena de battle.

### 7.3 Input touch-first (layout fechado 2026-08-03)

- **Paisagem.** Esquerda: joystick + **Avançar** + **Pulo**. Direita: **Ataque básico** + **Skill 1** + **Skill 2** + **Ultimate**.
- Input Map: `move_*`, `advance`, `jump`, `attack_basic`, `skill_1`, `skill_2`, `ultimate`, `pause`
- No mobile: `TouchScreenButton` / Control na HUD espelhando as actions
- Nunca hardcodar só `Input.is_key_pressed` — sempre actions
- Testar com mouse/teclado no PC **e** no telefone cedo (semana 1)
- Detalhe canônico: `docs/GDD-DECISOES.md` §4

### 7.4 Personagem e combate

- **CharacterBody2D** + `move_and_slide` (side-scroller com **pulo**)
- **AnimatedSprite2D** ou **AnimationPlayer** + Sprite2D
- **State machine** simples no player: `idle | walk | jump | attack_basic | skill_1 | skill_2 | ultimate | hurt | dead`
  - Começar com `enum` + `match` (simples)
  - Evoluir pra nós State se ficar complexo
- Hitboxes: `Area2D` com CollisionShape2D (attack box vs hurt box)
- Dano via **signal** (`hit_landed`, `died`) — desacopla UI da lógica
- Combate MVP: **1 básico + 2 skills + 1 ultimate** (não mais “3 ataques soltos + 1 especial” do rascunho antigo)

### 7.5 UI

- CanvasLayer para HUD (não se move com a câmera do mundo)
- Control + anchors (layout que sobrevive a telas diferentes)
- Evitar texto dentro da imagem do botão (localização / legibilidade)
- Safe area: respeitar notches (Godot tem helpers; testar em 2 aparelhos se possível)

### 7.6 Performance mobile (checklist)

| Prática | Por quê |
|---------|---------|
| Texturas em potência de 2 quando possível; comprimir | Memória GPU |
| Poucos draw calls: atlas / sprite sheet | FPS |
| `VisibleOnScreenNotifier2D` em inimigos off-screen | CPU |
| Evitar `_process` pesado; preferir signals e timers | Bateria |
| Physics em 60, mas lógica de AI pode throttlar | Estabilidade |
| Renderer **Mobile** / **Compatibility** se o aparelho for fraco | Compatibilidade |
| Áudio em OGG; não WAV gigante | Tamanho do APK |
| Target API e min SDK realistas (ex.: min 24/26) | Celulares dos amigos |

### 7.7 Save e progresso

- Path: `user://save.json` (no Android vira pasta do app)
- Salvar: rank, treinos feitos, volume, última cena
- Nunca confiar só em memória RAM

### 7.8 Resolução e escala

- **Orientação fechada: landscape** (celular deitado)
- Design resolution proposta: **1280×720** (ou base pixel 640×360 + integer scale) — fechar na 1ª cena
- Project Settings → Display → Stretch: `canvas_items` + aspect `expand` ou `keep`
- Layout de botões pensado para **dois polegares** em paisagem (ver GDD-DECISOES)

---

## 8. Pipeline de arte com Imagine + Godot

```
Style bible (texto + 1 âncora)
        ↓
Personagem base (Imagine) → image_edit para variantes
        ↓
Animações (image_to_video / frames) → sprite sheet
        ↓
Aseprite/LibreSprite (opcional limpeza)
        ↓
Godot: import → SpriteFrames → AnimatedSprite2D
        ↓
Hitbox ajustada frame a frame se necessário
```

**Defaults engine-ready (não negociar):**
- Fundo plano removível / transparente
- Mesma pose “pivot” entre frames
- Sem texto baked na UI
- Personagens recorrentes: **sempre** editar a partir da base (consistência)

**Ordem de produção de assets (MVP):**
1. Placeholder colorido (retângulos) — **jogável primeiro**
2. Player 1 pose idle + 1 attack
3. 1 inimigo simples
4. HUD (HP bar, botões)
5. Fundo do dojo (tile ou imagem estática)
6. Polish de animação e VFX

---

## 9. O que o jogo *pode ser* (design técnico enxuto)

Nome de pasta: **Treinamento Hashira** → encaixa bem em **loop de treino**:

### Loop de core (fechado no GDD 2026-08-03)

1. **Splash estúdio** Pasqualotti (logo + som)  
2. **Loading do jogo** — key art + barra 0–100% (ref Brawl; texto offline “Carregando…”)  
3. **Hub / estado padrão** — layout tipo home Brawl Stars: char centro, laterais, **JOGAR** (refs em `docs/references/ui/`)  
4. **JOGAR → mapa do mundo** → escolhe fase (ou loja pelo hub)  
5. **Fase side-scroller** → move, dash, pulo, combate, moedas no chão  
6. **Fim de fase** → volta mapa/hub / bank de moedas  
7. **Loja** (do hub) → upgrades  
8. **Boss do mundo** → unlock / próximo conteúdo  

Detalhe + tabela MVP dos botões do hub: `docs/GDD-DECISOES.md` §2.

### Mecânicas MVP (o mínimo divertido)

- Mover (joystick) + **dash com cooldown** + **1 pulo**
- Ataque básico + 2 skills + ultimate (respiração enche com **hits**)
- Moedas **dropam no chão**; contador no **topo**
- 2 tipos de oni + 3 fases + 1 boss (W1)
- Hub com showcase do personagem (não só lista de botões)

### Explicitamente FORA do MVP (fase 2+)

- Multijogador online  
- História completa estilo anime  
- 10+ personagens jogáveis  
- Physics complexa / plataformas longas  
- Microtransações  

**Regra de ouro de game design indie:** um loop bom > 20 features pela metade.

---

## 10. Roadmap de aprendizado e entrega

### Fase 0 — Fundação (semana 1)

- Instalar Godot + Git  
- Tutorial 2D oficial + 1 vídeo Brackeys/GDQuest Godot 4  
- Hello APK no celular  
- Decidir portrait vs landscape + design resolution  

### Fase 1 — Vertical slice (semanas 2–3)

- Player move + attack com **placeholders**  
- 1 inimigo que toma dano e morre  
- HUD de HP  
- Cena de vitória/derrota  
- **Jogar no celular** todo final de sprint  

### Fase 2 — Conteúdo mínimo (semanas 4–6)

- Dojo + 2–3 treinos  
- Save/load  
- 1 personagem “estilo” Hashira (arte Imagine)  
- SFX básico + 1 trilha  
- Polish de toque (botões grandes, feedback visual)  

### Fase 3 — “Noite dos amigos” (semana 7+)

- 2º personagem ou skins  
- Balanceamento  
- Tutorial in-game de 30s  
- APK release assinado (keystore de vocês)  
- Lista de telefone dos amigos + versão  

### Papéis sugeridos (você + sobrinho)

| Papel | Foco |
|-------|------|
| **Matheus** | Arquitetura, Godot, export Android, Git, Grok/Imagine pipeline |
| **Sobrinho** | Ideias de moves, playtest, nomes, feedback de “diversão”, opcionalmente pixel art / prompts de arte |

Trocar de papel às vezes = os dois aprendem.

---

## 11. Boas práticas de projeto (além do engine)

1. **Jogar cedo no device real** — emulador mente sobre toque e performance.  
2. **Git commits pequenos** — “player attack state”, não “tudo do jogo”.  
3. **Placeholder first** — arte linda no fim; mecânica no começo.  
4. **Um sistema por vez** — movimento OK → ataque → dano → UI → save.  
5. **Design resolution e input map no dia 1** — rework tarde dói.  
6. **Balance em Resource (.tres)** — números de dano/HP editáveis sem caçar magic numbers no código.  
7. **Playtest com o sobrinho sem explicar** — se ele não entende sozinho, o jogo não ensinou.  
8. **APK versionado** (`1.0.0-debug.3`) — saber o que cada amigo instalou.  
9. **Backup do keystore** se um dia assinar release — perder keystore = não atualiza o mesmo app.  
10. **Escopo congelado do MVP** — lista do que NÃO entra.

---

## 12. Recursos de estudo (ordem)

1. [Godot 4 docs — Your first 2D game](https://docs.godotengine.org/en/stable/getting_started/first_2d_game/index.html)  
2. [Exporting for Android](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html)  
3. GDQuest — state machine / best practices  
4. Brackeys / Chris’ Tutorials — Godot 4 2D  
5. Documentação de **signals**, **groups**, **resources**  
6. (Depois) AnimationTree se combate ficar expressivo  

---

## 13. Próximos passos concretos (quando você autorizar)

> **⚠️ Superado (2026-08-07):** a lista abaixo era o *primeiro* bootstrap do repo.  
> Estado atual e pendências = **`docs/STATUS-PROGRESSO.md`** (+ checklist HTML).  
> MVP W1 (boot → combate → loja → APK) já está entregue.

### Histórico (bootstrap inicial — feito)

1. ~~Confirmar: Godot 4 + GDScript~~ → **paisagem** 1280×720 (não portrait)  
2. ~~Instalar Fase A (Godot + Git)~~  
3. ~~Criar `project.godot` + `.gitignore`~~  
4. ~~GDD curto~~ → `docs/GDD-DECISOES.md`  
5. ~~Style bible + placeholders~~  
6. ~~Hello APK~~ → `export/TreinamentoHashira-debug.apk`  
7. ~~Vertical slice~~ → W1 fases 1–3 + boss  

### Próximos de verdade (pós-MVP)

1. Playtest humano (sobrinho) sem explicar  
2. QA Android real (touch / FPS / save)  
3. Polish (hitbox por frame, BGM boss, settings de volume na UI)  
4. Conteúdo em escala (Zenitsu/Inosuke, W2+) quando divertir  
5. Keystore release + “noite dos amigos” em 3+ aparelhos  


---

## 14. Glossário rápido (pra estudar junto com o sobrinho)

| Termo | Significado |
|-------|-------------|
| **Scene** | “Arquivo de objeto” do Godot (player, level, menu) |
| **Node** | Peça da árvore (Sprite, Collision, Timer…) |
| **Signal** | Evento (“tomei dano”) que outros escutam |
| **Resource** | Dado reutilizável (stats, item) |
| **Autoload** | Singleton global |
| **APK** | Instalador Android |
| **Sideload** | Instalar sem Play Store |
| **Hitbox / Hurtbox** | Área que causa / recebe dano |
| **State machine** | Organização do “o que o personagem está fazendo agora” |
| **Delta** | Tempo do frame — movimento * delta = frame-rate independent |

---

*Documento vivo: atualizar quando o escopo do “Treinamento Hashira” for fechado (GDD) e a stack confirmada.*
