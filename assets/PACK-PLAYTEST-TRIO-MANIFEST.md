# Pack playtest trio — review

**Gerado:** 2026-09-10 · Cursor GenerateImage (bases novas por id) + Pillow  
**Style bible:** `docs/STYLE-BIBLE.md`  
**Pasta review:** `assets/pack_playtest_trio/`  
**Produção:** `assets/characters/{nezuko,zenitsu,inosuke,tanjiro}/`

## O que entra

| Id | Hub 00/03 | Portrait | Combate idle/run/attack/hurt | Silhueta |
|----|-----------|----------|------------------------------|----------|
| tanjiro | pack fiel em `player/hub_idle` | crop do hub 00 | `player/combat` (já existia) | haori xadrez, 1 katana |
| nezuko | base + blink | bust | 1 frame cada (mínimo da onda) | kimono rosa, bambu, **sem katana** |
| zenitsu | base + blink | bust | 1 frame cada | haori amarelo, 1 katana |
| inosuke | base + blink | bust | 1 frame cada | máscara javali, **duas** lâminas |

Hub 01 breathe: não gerado nesta onda (opcional).  
Sheets 7/4/3 do Tanjiro **não** foram copiados pro trio — piso jogável primeiro.

## Pipeline

1. `image_gen` de base **nova** por id (nunca edit do Tanjiro).  
2. Poses = edit da base daquele id.  
3. Imagine entregou **JPEG** com extensão `.png` e fundo rosa-magenta (não `#FF00FF` puro).  
4. `tools/chroma_character_pack.py`: converte PNG real, chroma expandido (`hot_pink` + skill), canvas hub 640×900 / combate 512×512.  
5. Combate canônico olha **esquerda** (Pillow `FLIP_LEFT_RIGHT` nos frames que nasciam à direita: Zenitsu idle/run/hurt, Nezuko run). `player.gd` `flip_h` só se `facing > 0`.

## Defeitos honestos

- Fundo do Imagine era rosa quente (R~245, G~6, B 125–215), não magenta puro. Chroma cobre; se sobrar franja, reprocessar.  
- Nezuko portrait veio em recorte circular — após chroma fica bust redondo, ok na grade.  
- Nezuko run/attack: obi às vezes vermelho/branco em vez de laranja sólido (drift leve de pose). Cara/kimono/bambu batem.  
- Zenitsu attack: lâmina na mão + saya no cinto (uma katana desembainhada, não segunda arma).  
- Inosuke side/run: cabeça mais “javali de verdade” que a máscara-de-pelúcia da base frente — ainda é silhueta de javali + duas lâminas, não Tanjiro.  
- Trio: 1 frame por anim de combate (não paridade 7/4/3 do Tanjiro).  
- Os outros 10 ids do catálogo continuam Tanjiro + `accent`.

## Como ver

1. F5 → hub: Tanjiro sem wash.  
2. PERSONAGENS: quatro caras distintas.  
3. Escolher Nezuko → hub e fase mudam de verdade.  
4. Review rápido: `assets/pack_playtest_trio/`.

## Como pedir ajuste

“Nezuko mais ponta rosa”, “Zenitsu menos assustado”, “Inosuke máscara igual à base frente”, “mais frames de run”.
