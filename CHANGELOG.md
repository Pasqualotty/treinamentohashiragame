# Changelog — Treinamento Hashira

## 0.0.10 — lobby + convite pelo nome (2026-09-13)

- Depois de Criar sala: lobby em tela cheia (equipe, caçador, modos, faixa de retratos)
- Cada celular escolhe o caçador na sala — não cai mais em Inosuke no multiplayer
- Lista de amigos continua na gaveta; **+ Chamar amigo** fica na lobby
- Convite de amigo pelo **nome do perfil**, sem código de 8 na tela

## 0.0.8 — mapa de batalha (2026-09-12)

- Depois que alguém vence: **De novo** ou **Sair**
- Pátio grande, até 4 caçadores, pads de vida / respiração / haste
- Barras de luta verde → amarelo → vermelho
- Skills e respiração funcionam no mapa (F6 contra a máquina)

## 0.0.7 — sala no celular + kits (2026-09-12)

- Sobrinho joga com o amigo **só no celular** — sem ligar PC
- Mesma Wi-Fi ou outra casa: a sala da estrela já vem no APK
- Quatro modos na sala: 2 vs oni, 4 vs oni, mapa, 1v1
- Cada caçador: ataque, skills e botões próprios (andar/pulo/dash iguais)

## 0.0.9 — casa↔casa + convite de amigo (2026-09-13)

- Entre casas o celular **só sai** pro VPS (ponte UDP). Não depende mais da porta 17777 da casa.
- Código de amigo (8): manda convite → a pessoa aceita → fica na lista
- **+** chama pra sala já criada; Entrar + código de 6 continua
- Sem Firebase, Play Games, Hostinger; JOGAR ainda abre o mapa

## 0.0.3 — efeitos + próxima fase (2026-09-01)

- Cortes, dash e hits com os efeitos do treino (slash, água, impacto)
- Onis com barra de vida na cabeça
- HUD: Vitalidade / Respiracao + onda
- Limpa a fase e o jogo te leva sozinho pra próxima
- Elenco 14, 5 mundos, chefes de verdade (já na main)

## Unreleased — mundos W2–W5 + elenco 14

- Mapa com seletor de 5 mundos; cadeado até o boss anterior
- Fases + boss: `w2_01`…`w2_boss`, `w3_*`, `w4_*`, `w5_01`…`w5_boss`
- Ondas dos mundos novos no `StageDef.waves`
- Hub PERSONAGENS abre a tela de verdade (não só o label)
- 14 caçadores no catálogo; Tanjiro starter; locked mostra a condição em PT
- Kit distinto por resource (stats + nomes de skill); um player só
- Save: `unlocked_characters` + `current_character_id` + `current_world_id`

## Unreleased — auto-update sideload

- No hub, se existe versão nova, o sobrinho vê um aviso e pode baixar/instalar sem APK na mão
- Publicação: GitHub Releases (`latest.json` + APK) — `docs/AUTO-UPDATE.md`

## 0.1.0 — MVP Mundo 1 (2026-08-06)

### Jogavel
- Boot: splash Pasqualotti → loading → hub
- Hub com Tanjiro animado, LOJA, JOGAR, creditos (engrenagem)
- Mapa Mundo 1 visual (nos Fase 1–3 + Boss)
- Fases 1–3 + boss com combate side-scroller
- Tanjiro: move, pulo, dash, atk, 2 skills, ultimate, breath
- Oni fraco + elite, moedas no chao, HUD, touch
- Pause (Continuar / Mapa / Hub)
- Loja 4 upgrades + save persistente
- APK debug: `export/TreinamentoHashira-debug.apk`

### Tecnico
- Godot 4.7 Mobile + gl_compatibility no Android
- Package: `studio.pasqualotti.hashira`

### Fora desta versao
- Personagens extras, mundos 2+, release assinado, polish AAA
