# Plano AAA — Treinamento Hashira

**Objetivo:** tirar o jogo do "MVP que funciona" e levar pra sensação de **jogo de verdade,
premium** — jogabilidade com juice e direção de arte coesa. Documento de plano; implementação
só após aprovação (gate humano do pipeline).

**Autor:** EVA · **Data:** 2026-08-07 · **Status:** proposta aguardando OK

---

## 0. Realidade sobre "AAA" (leitura honesta)

AAA literal (Hollow Knight / Ori / Dead Cells) exige **equipe de arte dedicada** — fora do
orçamento de um fan game solo. **Mas** a boa notícia: ~70% da *sensação* AAA vem de **game feel,
VFX e UX** — que são **código**, não arte cara. O que dá pra atingir aqui é **"indie premium /
cara de jogo comercial mobile de verdade"**, e isso é 100% factível.

**Diagnóstico:** a engenharia do projeto **já é sólida** (state machine, coyote time, input buffer,
hitstop, camera shake, wave director com cerimônia, loja+save, HUD com chrome). O que grita "pobre"
é **animação (3 frames), ausência de VFX, fundos chapados, UI placeholder e áudio fino**. Ou seja:
o alicerce é bom; falta o acabamento.

**Princípio de priorização:** maior *percepção de qualidade* por *esforço*. VFX/juice e UX vêm
primeiro (código, sem custo de arte); animação e arte coesa em paralelo.

---

## Fase 0 — Fundação (pré-requisito, rápido)

| # | Item | Por quê | Esforço |
|---|------|---------|---------|
| 0.1 | **`scripts/preflight.sh`** (Godot headless import + `run_smokes` + sentinela) | Regra suprema; hoje **não existe** | P |
| 0.2 | **Design tokens central** — `resources/theme/palette.gd` (autoload) + `default_theme.tres` com a paleta da Style Bible (índigo/carmesim/ouro) | Hoje toda cor é hardcoded inline. 1 tema = coesão = "premium" instantâneo | P/M |
| 0.3 | **Camada VFX reutilizável** — `scenes/fx/` (hit_spark, slash_arc, dust, death_poof, damage_number) + autoload `Fx` pra spawnar | Base pra toda a Fase 1 | M |
| 0.4 | **Fonte real** (display + corpo) importada e no tema | Fonte padrão do Godot é o maior "tell" de amador | P |

---

## Fase 1 — Game feel & VFX  ⭐ MAIOR ROI (quase tudo código)

É aqui que "pobre → AAA feel" acontece mais rápido, **sem custo de arte**.

| # | Item | Detalhe |
|---|------|---------|
| 1.1 | **Slash VFX** | Arco de corte procedural (Line2D trail ou sprite additivo) no attack; azul "respiração da água" nas skills/ultimate — muito Demon Slayer |
| 1.2 | **Faíscas de impacto** | `GPUParticles2D` no ponto de hit, cor por tipo (basic/skill/ult); escala com dano |
| 1.3 | **Damage numbers flutuantes** | Número sobe+fade no hit; crítico maior/dourado — leitura + juice enormes |
| 1.4 | **Poeira** | Puff no land/dash/run; rastro no dash |
| 1.5 | **Morte de oni = dissolve** | Shader de desintegração (demônio vira cinzas — on-theme) em vez de fade+queue_free |
| 1.6 | **Câmera viva** | Follow com lerp + look-ahead na direção; punch de zoom + freeze-frame no ultimate/kill |
| 1.7 | **Hitstop/knockback tuning** | Já existe — calibrar por tipo + screen-space feedback |
| 1.8 | **Efeitos de tela** | Vinheta sutil, flash radial e leve aberração cromática no ultimate |
| 1.9 | **Coin juice** | Sparkle no drop + arco animado até o HUD ao coletar |
| 1.10 | **Combo feedback** | Contador de combo na tela + escalonamento de shake/pitch |

---

## Fase 2 — Direção de arte coesa & animação (paralelo à Fase 1)

| # | Item | Detalhe |
|---|------|---------|
| 2.1 | **Player animado de verdade** | Expandir de 3 → sets reais: idle 4-6, run 6-8, attack 4-6 (antecipação+follow-through), jump/fall, dash, hurt, skill1/2, ultimate. **Abordagem híbrida:** rig cutout/Skeleton2D da arte existente pra motion secundário barato + gerar keyframes (pipeline AI da Style Bible, chroma magenta) |
| 2.2 | **Onis animados** | Sprite2D → AnimatedSprite2D: walk/telegraph/attack/death; distinção visual do elite; +1-2 arquétipos novos |
| 2.3 | **Parallax nos fundos** | Cortar cada fase em 3-4 camadas (céu/longe/meio/perto/fg) + gerar camadas de profundidade; `ParallaxBackground` |
| 2.4 | **Atmosfera** | Partículas ambiente por fase (brasas na vila, névoa/vaga-lumes na floresta, neve na montanha) |
| 2.5 | **Iluminação de clima** | `CanvasModulate` noturno (índigo/carmesim) + `Light2D` rim no herói + glow na respiração |
| 2.6 | **Tileset/chão** | Variação de tiles, bordas, props (lanternas, bambu, torii) |

---

## Fase 3 — UI/UX premium

| # | Item | Detalhe |
|---|------|---------|
| 3.1 | **Theme central aplicado** | Botões/painéis/labels via `default_theme.tres` (substitui styleboxes inline) |
| 3.2 | **Transições de cena** | Wipe/fade/iris no `SceneRouter` — hoje são cortes secos (grande tell de premium) |
| 3.3 | **HUD redesign** | HP com tween de dano + pulse em HP baixo; barra de respiração segmentada com glow no full; ícones reais (hoje 1KB placeholder) |
| 3.4 | **Hub premium** | Parallax, showcase do personagem com plataforma+glow, CTA JOGAR com brilho/pulse |
| 3.5 | **Mapa do mundo vivo** | Caminho animado, nós com estados (locked/cleared/atual), animação de viagem entre nós |
| 3.6 | **Loja em cards** | Upgrades como cards com preview, before/after, animação de compra |
| 3.7 | **Loading real** | Barra de progresso real + dicas + key art |
| 3.8 | **Settings de verdade** | Sliders de volume (hoje ⚙ → créditos); pause polido |
| 3.9 | **Touch premium** | Opacidade/haptics, layout de polegares, deadzone; feedback de press |

---

## Fase 4 — Conteúdo & profundidade de combate

| # | Item | Detalhe |
|---|------|---------|
| 4.1 | **Combo de 3 hits** | Ataque básico vira combo com finalizador diferente (hoje é golpe único) |
| 4.2 | **Boss real** | Multi-fase com padrões de ataque, telegraphs, arena, barra de boss, banner de intro (hoje boss = ondas difíceis) |
| 4.3 | **Variedade de inimigos** | Oni à distância, oni investida, oni com escudo — IA distinta |
| 4.4 | **Profundidade** | Ataque aéreo, dodge/parry (i-frames upgrade), formas de respiração |
| 4.5 | **Progressão** | Árvore de upgrades expandida, desbloqueáveis, mais fases/hazards |

---

## Fase 5 — Áudio

| # | Item | Detalhe |
|---|------|---------|
| 5.1 | **Música real** | Hub/stage/boss (royalty-free estilo DS ou loops compostos melhores) |
| 5.2 | **SFX pass** | Slash/hit/impact em camadas, vocalização de oni, stinger de ultimate, ambiência por fase |
| 5.3 | **Mix dinâmico** | Ducking, música de combate vs calmaria |

---

## Fase 6 — Polish & release

| # | Item |
|---|------|
| 6.1 | Performance em device (60fps alvo, orçamento de partículas) |
| 6.2 | Robustez de save + persistência de settings |
| 6.3 | Keystore release + APK assinado |
| 6.4 | Prints/trailer pra distribuição |

---

## Ordem recomendada (ondas paralelizáveis via Maestro)

O trabalho é **naturalmente multi-frente** (arquivos independentes) — encaixa no protocolo maestro.

**Onda 1 (impacto imediato, sem custo de arte):**
- 🟢 Frente A — **VFX & juice** (Fase 0.3 + Fase 1) — código puro, transforma a percepção
- 🟢 Frente B — **Theme + transições + HUD** (Fase 0.2/0.4 + 3.1/3.2/3.3) — coesão visual
- 🟢 Frente C — **Preflight + fundação** (Fase 0.1) — rápido, destrava deploy seguro

**Onda 2 (arte & profundidade):**
- 🟡 Frente D — **Parallax + iluminação + atmosfera** (Fase 2.3-2.6)
- 🟡 Frente E — **Animação player + onis** (Fase 2.1/2.2) — mais pesada (pipeline de arte)
- 🟡 Frente F — **Combo + boss real** (Fase 4.1/4.2)

**Onda 3 (acabamento):**
- Hub/mapa/loja premium (3.4-3.9) · áudio (Fase 5) · release (Fase 6)

Onda 1 sozinha já muda a cara do jogo de "pobre" pra "isso é um jogo de verdade".

---

## O que é só humano (não é frente de código)

- Decisão sobre **fonte de arte** para animação (gerar via AI vs contratar vs rig da arte atual)
- Escolha/licença de **música** (se royalty-free pago)
- **Keystore release** + billing de qualquer serviço pago
- Aprovação de direção de arte final (o "gosto")

---

## Próximo passo

Aprovar o plano e escolher **quais frentes da Onda 1 abrir**. Recomendo abrir A + B + C juntas
(independentes entre si). A partir do OK, o maestro planeja cada frente e spawna os workers.
