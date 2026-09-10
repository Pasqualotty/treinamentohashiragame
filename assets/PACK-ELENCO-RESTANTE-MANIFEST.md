# Pack elenco restante — review

**Gerado:** 2026-09-10 · Cursor GenerateImage (bases **novas** por id) + Pillow  
**Style bible:** `docs/STYLE-BIBLE.md`  
**Pasta review:** `assets/pack_elenco_restante/`  
**Produção:** `assets/characters/{kanao,shinobu,uzui,rengoku,tomioka,obanai,tokito,sanemi,gyomei,yoriichi,muzan}/`  
**Script:** `tools/chroma_elenco_restante.py` (flip **condicional**; esta onda: nenhum)

Quarteto (`player` / `tanjiro` / `nezuko` / `zenitsu` / `inosuke`) **não** entra neste pack.

## O que entra

| Id | Hub 00/03 | Portrait | Combate idle/run/attack/hurt | Silhueta | Armas |
|----|-----------|----------|------------------------------|----------|-------|
| kanao | base + blink | bust | 1 frame cada | haori borboleta rosa/lilás, cabelo preso de lado | 1 katana |
| shinobu | base + blink | bust | 1 frame cada | haori inseto roxo, miúda, sorriso | 1 lâmina fina |
| uzui | base + blink | bust | 1 frame cada | joias, showman | **2** lâminas largas |
| rengoku | base + blink | bust | 1 frame cada | haori chama, cabelo amarelo ponta vermelha | 1 katana |
| tomioka | base + blink | bust | 1 frame cada | haori metade vermelho / metade verde-água | 1 katana |
| obanai | base + blink | bust | 1 frame cada | faixa no rosto, **cobra branca** | 1 katana fina + cobra |
| tokito | base + blink | bust | 1 frame cada | haori névoa, cabelo preto/branco | 1 katana |
| sanemi | base + blink | bust | 1 frame cada | haori vento, cicatrizes, cabelo eriçado | 1 katana |
| gyomei | base + blink | bust | 1 frame cada | monge enorme, faixa nos olhos | **machado + flail** |
| yoriichi | base + blink | bust | 1 frame cada | adulto, cabelo longo vermelho-escuro, haori chama vermelho/laranja | 1 katana |
| muzan | base + blink | bust | 1 frame cada | pálido, casaco escuro (não haori de caçador) | garras / sem katana |

Hub 01 breathe: não gerado (igual onda 1).  
Sheets 7/4/3 do Tanjiro **não** foram copiados — piso 1 frame por anim.

## Pipeline

1. `image_gen` de base **nova** por id. **Nunca** edit / reference do Tanjiro.  
2. Poses = edit da **mesma** base daquele id.  
3. Imagine entregou JPEG com extensão `.png` e fundo rosa-magenta (não `#FF00FF` puro).  
4. `tools/chroma_elenco_restante.py`: PNG real, chroma skill + `hot_pink`, canvas hub 640×900 / combate+portrait 512×512.  
5. Combate: prompt **facing left**. Leitura do PNG no disco **depois** do chroma. Flip só se ainda olhasse à direita.

## Facing por frame (combate)

Canônico: nariz / lâmina / pé da frente apontam para a **esquerda** da imagem.  
`player.gd` `flip_h` **não** mudou (`facing > 0`).

| Id | idle_side | run | attack | hurt | Flip Pillow |
|----|-----------|-----|--------|------|-------------|
| kanao | LEFT | LEFT | LEFT | LEFT | nenhum |
| shinobu | LEFT | LEFT | LEFT | LEFT | nenhum |
| uzui | LEFT | LEFT | LEFT | LEFT | nenhum |
| rengoku | LEFT | LEFT | LEFT | LEFT | nenhum |
| tomioka | LEFT | LEFT | LEFT | LEFT | nenhum |
| obanai | LEFT | LEFT | LEFT | LEFT | nenhum |
| tokito | LEFT | LEFT | LEFT | LEFT | nenhum |
| sanemi | LEFT | LEFT | LEFT | LEFT | nenhum |
| gyomei | LEFT | LEFT | LEFT | LEFT | nenhum |
| yoriichi | LEFT | LEFT | LEFT | LEFT | nenhum |
| muzan | LEFT | LEFT | LEFT | LEFT | nenhum |

Nenhum `FLIP_LEFT_RIGHT` nesta onda (o prompt left pegou). Se um frame futuro nascer à direita: `--flip id/pose` no chroma, **uma** vez.

## Identidade (read-back)

- **Yoriichi** ≠ Tanjiro de cabelo longo: haori chama vermelho/laranja, cara mais velha, cabelo longo; sem xadrez verde-preto.  
- **Obanai:** cobra branca no pescoço em hub, portrait e combate.  
- **Gyomei:** machado + flail; sem katana.  
- **Uzui:** duas lâminas.  
- **Muzan:** casaco formal, garras, sem gore, sem haori de caçador.

## Defeitos honestos

- Fundo do Imagine era rosa quente, não magenta puro. Chroma cobre; franja fina possível no recorte.  
- Gyomei hub blink: olhos já cobertos pela faixa — o 03 é o mesmo corpo com a faixa; piscada pouco visível.  
- Obanai / alguns side: a cobra muda um pouco de pose entre frames (ainda branca e no pescoço).  
- Kanao idle_side: katana na bainha às costas, não desembainhada (run/attack/hurt carregam a lâmina).  
- 1 frame por anim de combate (não paridade 7/4/3).  
- Drift leve de cabelo/tecido entre poses (edit da base, não regen do zero).

## Como ver

1. F5 → hub: Tanjiro fiel, sem magenta.  
2. PERSONAGENS: **15** cards com cara (locked inclusive).  
3. Debug: setar `current_character_id` para `kanao` / `rengoku` / `muzan` → hub e fase com aquele corpo, `modulate` WHITE.  
4. Review: `assets/pack_elenco_restante/`.

## Como pedir ajuste

“Yoriichi menos Tanjiro”, “Obanai cobra maior”, “Gyomei mais alto”, “Uzui duas lâminas no hurt”, “Muzan menos garras”.
