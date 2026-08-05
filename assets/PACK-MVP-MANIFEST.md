# Pack de arte MVP — mapa / fases / combate

**Gerado:** 2026-08-05 · Grok Imagine + pós Pillow  
**Branch:** `feat/hashira-arte-mvp`  
**Style bible:** `docs/STYLE-BIBLE.md` (cel cartoon mobile, outline, chroma `#FF00FF`)

## Critérios (frente arte-mvp)

| Critério | Status |
|----------|--------|
| 1 map BG 1280×720 | ✅ `assets/ui/map/world_map_w1.png` |
| ≥2 stage BGs 1280×720 | ✅ 3: floresta, vila, montanha |
| 1 tileset / strip chão | ✅ `assets/tiles/w1/ground_platform_strip.png` |
| 1 player combat pose | ✅ run + attack slash |
| Paths documentados | ✅ este arquivo |

## Paths de produção

### Mapa W1 (`assets/ui/map/`)

| Arquivo | Uso | Tamanho | Notas |
|---------|-----|---------|-------|
| `world_map_w1.png` | Fundo do mapa mundo | 1280×720 | Trilha bamboo + lanternas + torii |
| `node_stage.png` | Ícone nó de fase | 128×128 RGBA | Chroma removido |
| `node_boss_lock.png` | Boss bloqueado | 128×128 RGBA | |
| `node_cleared.png` | Fase limpa | 128×128 RGBA | |

### Backgrounds de fase (`assets/backgrounds/w1/`)

| Arquivo | Tema | Tamanho |
|---------|------|---------|
| `stage_forest.png` | Floresta de bambu noturna | 1280×720 |
| `stage_village.png` | Vila de montanha ao entardecer | 1280×720 |
| `stage_mountain.png` | Trilha rochosa / penhasco | 1280×720 |

### Tiles (`assets/tiles/w1/`)

| Arquivo | Uso | Tamanho |
|---------|-----|---------|
| `ground_path.png` | Tile legado pack v0.1 | 1024×1024 |
| `ground_platform_strip.png` | Strip horizontal de chão/plataforma | 384×128 RGBA |

### Combate player (`assets/characters/player/combat/`)

| Arquivo | Pose | Tamanho |
|---------|------|---------|
| `tanjiro_run.png` | Side run mid-stride | ~480×512 RGBA |
| `tanjiro_attack_slash.png` | Side attack slash | ~512×480 RGBA |

## Wire no Godot (leve)

| Cena | O que mudou |
|------|-------------|
| `scenes/world/world_map.tscn` | `TextureRect` com map BG + ícones nos botões Stage/Boss |
| `scenes/battle/sandbox_combat.tscn` | `Sprite2D` BG floresta + strip de chão |

Player default continua em `tanjiro_idle_side.png` (idle). Poses de combate em pasta pronta para trocar em animação depois.

## Pipeline aplicado

1. `image_gen` 16:9 BGs + ícones + tile strip  
2. `image_edit` a partir de `tanjiro_idle_side.png` (run, attack)  
3. Pillow: JPEG→**PNG real** (header `89 50 4E 47`), chroma magenta→alpha, crop, resize  
4. Script: `assets/_gen_raw/process_mvp_pack.py`

## Defeitos / honestidade

- Estilo **cel cartoon** legível em mobile — **não** pixel-art rígido.
- Stage BGs são still full-frame (não layers parallax separados).
- Tile strip: seam horizontal **razoável** (não validado 2×2 no editor); fundo índigo virou alpha.
- Run: 1ª versão tinha bainha extra; fix `image_edit` → só uma katana na mão.
- Attack slash: pose forte; escala no Godot ainda não plugada na anim state machine.
- Ícones de nó: estilo UI flat; boss lock com caveiras/fogo (legível).
- Fan art original *inspirada* em Demon Slayer vibe — não copiar assets oficiais.

## Como pedir ajuste

Exemplos: “map com menos lanternas”, “vila mais noturna”, “tile mais seamless”, “run com espada na bainha”, “attack mais semi-chibi”.
