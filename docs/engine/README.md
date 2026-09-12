# Documentação da Engine — Treinamento Hashira

**Engine:** Godot **4.7.1** Standard (GDScript)  
**Plataforma alvo:** Android (sideload APK) + Play no Windows  
**Renderer:** Mobile  
**Resolução de design:** 1280×720 paisagem  

Esta pasta é a **consulta técnica** do projeto. Decisões de produto ficam em `docs/GDD-DECISOES.md`.

| Doc | Conteúdo |
|------|----------|
| [01-visao-e-stack.md](./01-visao-e-stack.md) | Por que Godot, o que está instalado |
| [02-estrutura-projeto.md](./02-estrutura-projeto.md) | Pastas, cenas, autoloads |
| [03-fluxo-e-cenas.md](./03-fluxo-e-cenas.md) | Boot → hub → mapa → fase |
| [04-input-e-mobile.md](./04-input-e-mobile.md) | InputMap, touch, VirtualJoystick 4.7 |
| [05-assets-e-import.md](./05-assets-e-import.md) | PNG, chroma, filtros, erros comuns |
| [06-ui-hub.md](./06-ui-hub.md) | Hub, StyleBoxTexture, animação |
| [07-export-android.md](./07-export-android.md) | JDK, SDK, paths, keystore |
| [08-gdscript-convencoes.md](./08-gdscript-convencoes.md) | Tipos, sinais, state machine |
| [09-troubleshooting.md](./09-troubleshooting.md) | Erros já vistos e fixes |
| [10-skills-pasqualotti.md](./10-skills-pasqualotti.md) | Skills obrigatórias de design/arte |
| [11-combat-hud.md](./11-combat-hud.md) | HUD de combate (HP / breath / moedas run) |
| [12-lan-coop.md](./12-lan-coop.md) | Coop 2P: LAN **ou** casa↔casa (beacon + PC do meio) |
| [13-brawl.md](./13-brawl.md) | Mapa de batalha: 2P na sala, dummy só no F6 |
| [14-duel.md](./14-duel.md) | 1v1: 2P na sala, dummy só no F6 |

**Skills Grok (sempre):**

- `/pasqualotti-game-design` — design de jogo / UI / flow  
- `/grok-imagine-game-assets` — arte com Imagine  

Paths user: `~/.grok/skills/...` · espelho no repo: `.grok/skills/...`
