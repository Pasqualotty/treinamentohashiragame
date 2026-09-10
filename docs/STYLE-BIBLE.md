# Style bible — Treinamento Hashira (arte)

**Versão:** 0.2 · 2026-09-10  
**Uso:** fan project pessoal · não copiar assets oficiais do anime/jogo comercial

## Frase âncora

> Sprite de jogo 2D mobile, silhueta nítida, contorno escuro fino, cores chapadas com pouco sombreado, legível em tela pequena; clima noturno japonês (índigo, carmesim, ouro pálido).

## Regras engine-ready

| Tipo | Fundo | Notas |
|------|-------|--------|
| Personagens / onis | **Magenta sólido** `#FF00FF` (chroma) | Sem chão, sem sombra projetada, sem texto |
| Tiles de chão | Seamless / tileable | Sem marco único no centro |
| Ícones UI | Fundo transparente ou chroma | Sem texto baked |
| Key art loading | Cena full 16:9 | Pode ter ambiente |

## Proporção personagem

- Semi-chibi jogável (cabeça ~1/3 do corpo), **não** realista  
- Altura alvo em jogo: ~48–64 px de sprite (arte master maior, escala no Godot)  
- Side-scroller: **perfil / 3/4** para combate; **frente** para hub  

## Paleta global (orientação)

| Uso | Cor |
|-----|-----|
| Noite / UI dark | `#0F1218` / `#1C2330` |
| Destaque carmesim | `#C43C3C` |
| Ouro / CTA | `#E8B84A` |
| Água / respiração | `#5B8DEF` |
| Chroma key | `#FF00FF` |

## Pipeline

1. **Uma base nova por caçador** (`image_gen`). Tanjiro: `tanjiro_idle_front_base` só para poses **dele**.  
2. Trio (Nezuko / Zenitsu / Inosuke): **nunca** `image_edit` da base do Tanjiro.  
3. Poses = `image_edit` da base daquele id. Inosuke = duas lâminas de propósito; Nezuko = sem katana.  
4. Onis / tiles / UI podem ser gen novos, mesma frase de estilo.  
5. Import Godot: Filter **Off**, Mipmaps **Off**.  
6. JPEG do Imagine → PNG real (`89 50 4E 47`) + chroma antes de `res://`.

## Pack v0.1 (gerado)

Ver `assets/PACK-V01-MANIFEST.md`
