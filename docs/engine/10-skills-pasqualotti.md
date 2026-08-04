# 10 — Skills obrigatórias (design + arte)

## Instaladas

| Skill | Path user | Slash |
|-------|-----------|-------|
| Game design Pasqualotti | `~/.grok/skills/pasqualotti-game-design/` | `/pasqualotti-game-design` |
| Imagine game assets | `~/.grok/skills/grok-imagine-game-assets/` | `/grok-imagine-game-assets` |

Espelho no repo: `.grok/skills/<mesmo-nome>/` (para versionar com o projeto).

## Quando a EVA / Grok **deve** carregar

| Situação | Skill |
|----------|--------|
| Hub, menu, controles, loop, mapa, HUD, feel, MVP | `pasqualotti-game-design` |
| Sprite, key art, botão visual, fundo, chroma, pack, anim idle | `grok-imagine-game-assets` |
| Ambos (ex.: “deixa o hub bonito”) | **As duas**, nessa ordem: design → arte → implementação |

## Regra de processo

1. Ler skill correspondente **antes** de implementar.  
2. Não inventar pipeline de PNG/JPEG fora da skill de arte.  
3. Atualizar GDD/STATUS se design mudar.  
4. Atualizar `docs/engine/` se config de engine mudar de forma material.

## Deep research embutido (fontes)

- Godot Best Practices (docs oficiais 4.x/4.7)  
- Godot “Your first 2D game”  
- Godot 4.7: VirtualJoystick nativo, renderer Mobile  
- Export Android packages (platform 35, NDK, etc.)  
- Lições reais deste repositório (sessão 2026-08-03)
