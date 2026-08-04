# Style bible — Treinamento Hashira (arte)

**Versão:** 0.1 · 2026-08-03  
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

1. Base âncora (Tanjiro) → sempre `image_edit` a partir dela  
2. Onis / tiles / UI podem ser gen novos, mesma frase de estilo  
3. Import Godot: Filter **Off**, Mipmaps **Off**  

## Pack v0.1 (gerado)

Ver `assets/PACK-V01-MANIFEST.md`
