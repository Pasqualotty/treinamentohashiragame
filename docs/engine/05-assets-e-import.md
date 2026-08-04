# 05 — Assets e import

## Pipeline Imagine → Godot

Ver skill **`grok-imagine-game-assets`**. Resumo:

1. Gerar com fundo magenta `#FF00FF` (sprites).  
2. **Converter para PNG real** (não renomear JPEG).  
3. Chroma → alpha 0 + crop.  
4. Colocar em `assets/...`.  
5. Godot gera `.import` automaticamente.

## Erro clássico

```
ERR_FILE_CORRUPT / Not a PNG file
```

**Causa:** arquivo começa com `FF D8` (JPEG) mas extensão `.png`.  
**Fix:** Pillow `Image.open(...).save(..., "PNG")` e apagar `.import` antigo.

## Filtros

| Tipo de arte | Filter |
|--------------|--------|
| Pixel art | Nearest (project default 0) |
| Paint / key art | Linear por textura se precisar |

## Pastas de arte atuais

- Player hub idle: `assets/characters/player/hub_idle/00..05.png`  
- Side combat: `assets/characters/player/tanjiro_idle_side.png`  
- Oni: `assets/characters/enemies/oni_weak_side.png`  
- Hub BG: `assets/ui/hub/bg_frame_*.png`  
- Botões: `assets/ui/buttons/*.png`  
- Loading keyart: `assets/ui/loading/keyart_w1.png`  
- Review: `assets/pack_v01/`  

## Style bible

`docs/STYLE-BIBLE.md`
