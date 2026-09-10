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

- Pack por id: `assets/characters/<id>/` (hub_idle, portrait, combat/{idle_side,run,attack,hurt})  
- Tanjiro fiel (legado): `assets/characters/player/hub_idle/` + `player/combat/`  
- Trio playtest: `assets/characters/{nezuko,zenitsu,inosuke}/` + review `assets/pack_playtest_trio/`  
- Oni: `assets/characters/enemies/oni_weak_side.png`  
- Hub BG: `assets/ui/hub/bg_frame_*.png`  
- Botões: `assets/ui/buttons/*.png`  
- Loading keyart: `assets/ui/loading/keyart_w1.png`  
- Review antigo: `assets/pack_v01/`  

JPEG com extensão `.png` = `ERR_FILE_CORRUPT`. Sempre Pillow → header `89 50 4E 47`.

## Style bible

`docs/STYLE-BIBLE.md`
