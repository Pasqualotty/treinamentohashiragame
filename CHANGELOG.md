# Changelog — Treinamento Hashira

## 0.0.17 — animações e layout do jogo inteiro (2026-10-09)

- Caçadores com altura certa e pés no chão em todas as poses (escala pelo desenho, não pela textura). Os 11 caçadores que ficavam parados como estátua agora respiram, dão antecipação no golpe e têm dash.
- Onis com cara própria: elite, charger, atirador e os 5 chefes têm silhueta e cor diferentes do oni fraco. Morte com queda, esmaecimento e poof; chefe mais lento e com flash.
- Fase: dica de teclado não cobre mais a barra de vida (e some no celular), chip de onda mostra quantos onis faltam, botão "Mapa" solto saiu (o pause já tem). Barra de vida com rastro de dano, respiração em 4 segmentos, acentos corrigidos.
- Cerimônia de fase: cartão com letterbox, título em Cinzel e objetivo; faixa "ONDA 2 / 3"; "FASE CONCLUÍDA" com moedas contando e XP. Portal de saída virou um torii com corrente (fechado) e brilho + fagulhas (aberto).
- O caçador nasce à direita do joystick (não mais embaixo dele).
- Fundos sem emenda no meio da tela em todos os mundos; chão próprio por mundo (trilha de pedra, chapa de trem, paralelepípedo, pedra de castelo, obsidiana); atmosfera e luz por mundo (fagulhas no trem, pétalas no distrito, poeira no castelo, brasas no céu vermelho); silhuetas de primeiro plano; chefes mais sombrios.
- Hub: cada placa com o próprio ícone (bolsa, máscara, bustos, katanas cruzadas, pergaminho, sino, brasão, lanterna), barra de XP com badge de nível, entrada animada, botões que respondem ao toque, fagulhas em volta do caçador.
- Mapa: medalhões por estado com o rótulo embaixo (o cadeado não cobre mais o texto), um título só, abas com nome do mundo, fundo próprio em W2–W5 com cross-fade, tinta dourada fluindo no caminho aberto.
- Loja, Personagens, Ajustes, Missões, Notícias, Clube, Eventos, Créditos e Nome: fundo com arte + vinheta, cards entrando em cascata, botões com bounce, "← Voltar" sempre no mesmo canto. Troca de tela com cortina diagonal e filete dourado.
- Espaço entre palavras voltou ao normal (texto não parece mais justificado).
- Correção: abrir o hub com um caçador trancado selecionado não reseta mais para o Tanjiro.

## 0.0.16 — diário, música e mundos (2026-10-02)

- Hub: Missões, Notícias, Clube, Eventos e nível de caçador. Tudo no aparelho. O XP não muda o dano da loja.
- Fase toca a música do mundo. O boss não usa mais o tema do menu.
- Trem, Distrito, Castelo e Céu Vermelho têm fundo próprio.
- O golpe acompanha o frame da animação.
- Corrida, ataque e ultimate com mais frames (6 no quarteto, 4 no resto do elenco).

## 0.0.15 — sem faixa na lateral do menu (2026-09-13)

- O fundo do menu volta a ir até a borda. Só os botões se afastam do recorte do telefone.

## 0.0.14 — multiplayer, bordas, dash e stick (2026-09-13)

- Hub: placa **MULTIPLAYER** cria a sala e abre a lobby
- Gaveta AMIGOS só lista / convites / Adicionar amigo; **ENTRAR** se o amigo já tem sala
- Lobby: caçadores grandes lado a lado quando entra gente
- Nome até 24 caracteres; o espaço no meio não some ao digitar
- Telas respeitam a área segura do telefone (não come notch/canto)
- Dash sai no primeiro frame ao levar hit (1v1 e mapa)
- Stick de movimento maior

## 0.0.13 — versão no hub (2026-09-13)

- No painel principal, a versão aparece no canto inferior esquerdo

## 0.0.12 — sala, 1v1, combate e mapa (2026-09-13)

- Dá para trocar o modo com o amigo já na sala (a sala não fecha)
- **2 vs oni:** o anfitrião vê **Começar** e vai ao mapa escolher a fase
- Skills e ultimate no **1v1** (não pedem mais “pés no chão”)
- Combate: segura para trás para defender; apanhando ainda consegue correr e recuar
- Mapa de batalha: quem nasce em cima à esquerda desce para o pátio; o amigo manda o eixo de cima/baixo
- Créditos: **Incendeie seu coração** depois de feito com carinho

## 0.0.11 — troféus, nametag, 1v1 e revanche (2026-09-13)

- Troféus no multiplayer: vitória soma no save; a lobby mostra o número
- Nome da pessoa em cima do corpo na sala
- 1v1: fundo do pátio, pés no chão, corpos maiores, barra de respiração
- Fim: “Fulano · Caçador ganhou”; **De novo** ou **Lobby** (mesma sala, sem convidar de novo)
- Ataques do amigo no slot certo; lobby sem LOJA/PERSONAGENS por cima

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
