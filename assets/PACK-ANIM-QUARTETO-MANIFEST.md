# Pack anim quarteto — review

**Gerado:** 2026-09-10 · Cursor GenerateImage (`reference_image_paths` = 00 daquele id) + Pillow  
**Style bible:** `docs/STYLE-BIBLE.md`  
**Pasta review:** `assets/pack_anim_quarteto/`  
**Produção:** `assets/characters/{player,nezuko,zenitsu,inosuke}/`

Onda 1 (`pack_playtest_trio`) deixou o trio com 1 frame por anim. Esta frente sobe à paridade Tanjiro e adiciona dash no corpo.

## O que entra

| Id | Combate idle / run / attack / hurt | Dash | Hub 01 breathe |
|----|------------------------------------|------|----------------|
| tanjiro (`player/combat`) | **intacto** (já 7/5/3/1) | 00–02 novos | **não** (01 legado é pose errada) |
| nezuko | 00 lock + 01–06 / 01–03 / 01–02 | 00–02 | sim (edit do hub 00) |
| zenitsu | 00 lock + 01–06 / 01–03 / 01–02 | 00–02 | sim |
| inosuke | 00 lock + 01–06 / 01–03 / 01–02; **duas** lâminas em todo frame | 00–02 | sim |

Hurt permanece 1 frame (paridade). VFX extra em `assets/fx/**` **não** gerado — slash/impact/dash da onda feel já cobre.

## Pipeline

1. Pose = `image_edit` da **BASE daquele id** (00 da pasta; dash a partir do run/00). Nunca gen solto. Nunca edit do Tanjiro virando outro.  
2. Imagine entregou **JPEG** (`ffd8…`) com extensão `.png` e fundo magenta.  
3. `tools/chroma_character_pack.py --src --dest --kind`: PNG real (`89 50 4E 47`), chroma skill + `hot_pink`, canvas combate **512×512** / hub **640×900**.  
4. **Flip default = false.** Nenhum 00 foi reprocessado. Nezuko `combat/run/00.png` SHA idêntico a `0638999`.  
5. Frame novo que nascesse à direita seria `--flip` **só nesse arquivo**. Nesta leva todos nasceram LEFT — zero flips.

## Facing

- Combate canônico olha **esquerda**. `player.gd` `flip_h` só se `facing > 0` — **intocado**.  
- Nezuko run/00 **não** foi flipado de novo (já era esquerda em `a03e7a4` / `0638999`).

## Defeitos honestos

- Imagine ainda entrega JPEG + blobs magenta soltos; chroma come o fundo, às vezes deixa **franja rosa** (Inosuke attack/dash, alguns idle).  
- Drift de obi da onda 1 permanece (Nezuko run/attack: nó xadrez vs laranja sólido do hub). **Não** regeneramos a base.  
- Inosuke side continua “javali de verdade” vs máscara-de-pelúcia do hub frente — identidade da pasta, não bug novo.  
- Inosuke attack 01≈02 (active e follow-through próximos). O 00 (windup) + o esticar do 01 ainda leem o golpe no corpo.  
- Zenitsu dash 01 estica menos que o Tanjiro 01 (mais “corrida baixa” que horizontal). 00 lean + 02 recover fecham o avanço.  
- Idle 01–06 são micro (peso/pisca/cabelo), de propósito — **não** são golpes (hub.gd já sofreu com 06/07 de combate no idle).  
- 11 ids residuais (kanao…muzan) **intocados**. Catalog/unlock intocado.

## Como ver

1. F5 `sandbox_combat` / `stage_w1_01` com Tanjiro, Nezuko, Zenitsu, Inosuke.  
2. Idle respira (7 frames). Run cicla. Attack tem windup/active/follow. Dash troca o desenho (não só stretch).  
3. Andar à **esquerda**: ninguém olha o lado errado; Nezuko run não “moonwalk”.  
4. Hub trio: 00 + blink 03; 01 entra no tween de respiração. Tanjiro **não** usa o 01 legado.  
5. Review: `assets/pack_anim_quarteto/`.

## Como pedir ajuste

“Nezuko dash mais baixa”, “Inosuke attack 02 mais follow-through”, “menos franja no chroma”, “Zenitsu dash 01 mais esticado”.
