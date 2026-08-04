---
name: grok-imagine-game-assets
description: >
  Prompt engineer e pipeline de assets de jogo com Grok Imagine (image_gen,
  image_edit, image_to_video). Use SEMPRE ao gerar/editar sprites, tiles, UI,
  key art, hub background, botões, ícones, animações idle, chroma key, packs
  de arte, style bible visual. Gatilhos: /grok-imagine-game-assets, "gera arte",
  "Imagine", "sprite", "key art", "botão UI", "fundo do hub", "pack de arte",
  "chroma", "magenta", "animação idle", "Tanjiro", "oni", asset de jogo.
  Complementa game-asset-core; para Pasqualotti Studio carregar também
  pasqualotti-game-design se for UI/flow.
---

# Grok Imagine — Game Assets Prompt Engineer (Pasqualotti)

Pipeline **engine-ready** para Godot 2D mobile. Lições reais do projeto Treinamento Hashira embutidas.

## Quando carregar

Qualquer geração/edição de **arte de jogo** neste ecossistema.  
Se for hub/menu/flow → também `pasqualotti-game-design`.  
Skills base: `game-asset-core` + specialist (character / tiles / ui / animation) se existirem.

## Regras de ouro (gate duro)

### 1) Nunca mentir extensão de arquivo

| Errado | Certo |
|--------|--------|
| Salvar JPEG do Imagine como `.png` | Converter com Pillow para **PNG real** (header `89 50 4E 47`) ou manter `.jpg` e path `.jpg` |
| Godot `ERR_FILE_CORRUPT` / “Not a PNG file” | = JPEG renomeado. **Converter antes** de commitar |

```python
# Obrigatório após image_gen/edit se for usar no Godot como PNG:
from PIL import Image
im = Image.open(src).convert("RGBA")
im.save(dst, "PNG")
```

### 2) Chroma key canônico

- Fundo de sprite/UI isolado: **magenta puro** `#FF00FF` no prompt.  
- Depois no disco: **remover magenta → alpha 0** + crop ao conteúdo.  
- Hub **nunca** mostra quadrado magenta.

```python
# mask: R e B altos, G baixo
mask = (r > 180) & (b > 180) & (g < 130)
arr[mask, 3] = 0
```

### 3) Consistência de personagem

- **Uma base** (ex. `tanjiro_idle_front_base`).  
- Toda pose nova = **`image_edit` a partir da base**, nunca `image_gen` solto do zero.  
- Restate traços fixos no prompt (haori xadrez, brincos, cicatriz, espada preta).

### 4) Aspect ratios válidos (API atual)

Só: `1:1`, `3:4`, `4:3`, `9:16`, `16:9`, `2:3`, `3:2`, `9:19.5`, `19.5:9`, `9:20`, `20:9`, `1:2`, `2:1`, `auto`.  
**Não use** `3:1` (falha 422). Botões largos: gerar `16:9` e **crop**, ou desenhar em PIL.

### 5) Vídeo (`image_to_video`)

Pode falhar com ZDR / `upload_url`. Fallback obrigatório:

- Frames via `image_edit` (blink, breathe), ou  
- Ken Burns no Godot (vários crops + drift em script).

Não bloquear entrega por vídeo.

## Style bible (antes do pack)

1 frase + regras:

```
Sprite 2D mobile, silhueta nítida, contorno escuro fino, cores chapadas,
legível em tela pequena; clima noturno japonês (índigo, carmesim, ouro).
```

| Tipo | Fundo no gen | Pós |
|------|--------------|-----|
| Char / oni / ícone | Magenta sólido | PNG + alpha |
| Tile ground | Seamless | PNG tileable |
| Key art / hub BG | Cena full 16:9 | PNG, sem texto |
| Botão | Magenta ou gerado em PIL | StyleBoxTexture |

## Prompt templates

### Personagem (base)

```
[Name] full body game sprite, [front|side view facing right], idle, 
[distinctive costume details], bold clean dark outlines, flat cel-shaded colors,
clear silhouette, isolated on solid pure magenta background #FF00FF,
no ground, no shadow, no text, mobile game ready.
```

### Edit de pose (consistência)

```
Exact same character (list fixed traits). Only change: [blink eyes closed | side view | attack windup].
Keep magenta #FF00FF background, no extra limbs, no second sword floating, no ground.
```

### Oni / inimigo

```
Weak demon enemy sprite, side view facing left, [palette], bold outlines,
flat colors, isolated pure magenta #FF00FF, not gory, mobile game.
```

### Key art loading / hub BG

```
16:9 cinematic mobile game background, night bamboo forest, moon, red torii mist,
indigo crimson gold, empty center for character overlay, no text no logos no UI.
```

### Botão (se Imagine)

```
Empty wide game UI button plate, dark lacquer wood gold rim crimson accents,
no text no letters, pure magenta #FF00FF background.
```

Prefer **PIL** para botões geométricos confiáveis (9-slice friendly) se Imagine falhar em aspect.

## Pipeline pack vN

```
1. Style bible no docs/
2. Gerar/editar assets (Imagine)
3. Converter JPEG→PNG real
4. Chroma + crop
5. Normalizar canvas de animação (mesmo tamanho)
6. Copiar para assets/... E pack_vN/ para review
7. MANIFEST.md (paths, defeitos honestos)
8. Ligar no .tscn/.gd (ExtResource ou load)
9. Godot reimport (apagar .import corrompido se preciso)
10. Commit
```

## Animações idle (hub)

Frames mínimos úteis:

| Frame | Conteúdo |
|-------|----------|
| 00, 02, 05 | Eyes open / base |
| 01 | Breathe / stance lower |
| 03 | Mid-blink or weight shift |
| 04 | Eyes closed |

Godot: `TextureRect` + array de `Texture2D` + `Array[float]` durations (typed!).  
Ou `AnimatedSprite2D` se em Node2D.

## Defeitos comuns a verificar (read-back)

- [ ] Espada/bainha flutuante extra  
- [ ] Texto baked  
- [ ] Fundo não-magenta “quase rosa” falhando no chroma  
- [ ] JPEG com extensão .png  
- [ ] Personagem regenerado do zero (drift de face)  
- [ ] Botão 3:1 aspect inválido  

## Integração Godot (pós-arte)

- Import: Filter Off se pixel; Linear se paint.  
- Hub: personagem **preenche** área de showcase; BG atrás com dim.  
- Loading: keyart no `TextureRect` via ExtResource (não só load runtime).  
- Nunca commitar só o `.import` sem o binário correto.

## Report ao usuário

1. O que gerou (lista de paths).  
2. Defeitos conhecidos.  
3. Como ver (pasta pack + F5).  
4. Como pedir ajuste (“mais pixel”, “sem yen na moeda”, “espada só uma”).  

## Anti-padrões (projeto Hashira)

| Anti | Correção |
|------|----------|
| `.png` que é JPEG | Pillow convert |
| Magenta no hub | Chroma + alpha |
| Katana bugada | image_edit focado “ONE sword only” |
| Thumbnail Explorer mentindo | Abrir FIXED / app Fotos |
| Pack sem manifesto | Sempre `PACK-VN-MANIFEST.md` |
