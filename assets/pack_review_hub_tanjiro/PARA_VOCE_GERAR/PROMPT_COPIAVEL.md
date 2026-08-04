# Prompt + referência — Tanjiro hub

**Atualização:** Matheus **não** gera as imagens — a EVA gera no Imagine.  
**Só o vídeo (10s)** pode ser gerado por ele na conta dele, se a API da EVA continuar bloqueada.

**Pasta de refs (se precisar de vídeo na sua conta):** `PARA_VOCE_GERAR/`

---

## 1) Imagens de referência (use no Imagine)

| Arquivo | Use para |
|---------|----------|
| **`REF_01_tanjiro_master_magenta.jpg`** | **Principal** — cara, roupa, espada ok (1 katana + bainha no cinto) |
| `REF_02_tanjiro_transparent_current.png` | Ver estado atual (só se precisar) |
| `REF_00_canvas_guide_3x4.png` | Guia: caixa vermelha + linha verde dos pés |
| `REF_03_example_feet_on_ground.png` | Exemplo de enquadramento (pés na linha de baixo) |
| `REF_04_hub_background_only.png` | Só o fundo do hub (NÃO colar o personagem nisso no gen) |

No Imagine: **Image Edit** com `REF_01` (e se der, o guia `REF_00` junto).

---

## 2) Prompt PRINCIPAL (hub idle — copiar e colar)

```
Same character as the reference image exactly (checkered haori, hanafuda earrings, forehead scar).

FRAMING (critical):
- Full body, front view, standing on the ground.
- Feet firmly on the BOTTOM of the image (toes near the bottom edge). Do NOT float. No empty space under the feet.
- Character fills most of the tall frame: head near the top, feet at the bottom. Large silhouette for a mobile game menu showcase.
- Aspect ratio 3:4 portrait.

WEAPON (critical):
- ONE black katana held upright in the RIGHT hand only (blade tip UP).
- Short hilt ends just under the fist — no long black shaft under the hand (no double-ended / Darth Maul look).
- Separate empty black scabbard (saya) on the LEFT HIP / belt only, not attached under the sword.

BACKGROUND:
- Solid pure flat magenta #FF00FF only. No gradient, no ground texture, no shadow on the ground, no scenery, no text, no red guide boxes.

Style: clean anime game sprite, bold outlines, flat cel shading, mobile game ready.
```

---

## 3) Prompt PISCADA (edit do resultado do passo 2)

```
Exact same character, pose, framing and weapons as the reference.
ONLY change: both eyes fully closed for a blink.
Keep feet at the bottom edge, same large size.
Solid pure magenta #FF00FF background. No other changes.
```

---

## 4) Prompt RESPIRAÇÃO (edit do idle)

```
Exact same character, framing and weapons as the reference.
ONLY change: very subtle breathe, shoulders slightly lower, eyes open.
Feet still on the bottom edge. Solid pure magenta #FF00FF. No other changes.
```

---

## 5) Prompt GOLPE 1 e 2 (opcional, pro loop de showcase)

**Golpe A:**
```
Exact same character design as reference, full body large, feet near bottom of frame.
Pose: mid katana slash to the side, dynamic but readable.
ONE sword only in hands; scabbard stays on left hip.
Solid pure magenta #FF00FF, no ground shadow, no text.
```

**Golpe B:**
```
Exact same character design as reference, full body large, feet near bottom of frame.
Pose: overhead katana ready / finishing slash.
ONE sword only; scabbard on left hip.
Solid pure magenta #FF00FF, no ground shadow, no text.
```

---

## 6) Prompt VÍDEO ~10s (se o Imagine de vídeo abrir na sua conta)

Use a **melhor imagem idle** (pés no chão, magenta) como primeiro frame.

```
Same anime character standing on the bottom of the frame, then performs several clean single-katana swings and slashes, returns to idle, loopable combat showcase, smooth animation, keep identical design, solid magenta background stays flat, no floating, feet stay grounded when idle.
```

Duração: **10 segundos** se a UI permitir (senão 6s e repete).

> Se o vídeo falhar na sua conta também (erro de upload/ZDR), manda só os frames PNG que eu monto o loop no Godot.

---

## 7) Depois de gerar — o que me entregar

Coloque nesta pasta (ou me avisa o path):

```
PARA_VOCE_GERAR/entregas/
  tanjiro_idle_open.png      (ou .jpg com magenta)
  tanjiro_idle_blink.png
  tanjiro_idle_breathe.png
  tanjiro_attack_01.png      (opcional)
  tanjiro_attack_02.png      (opcional)
  tanjiro_showcase.mp4       (opcional, se vídeo rolar)
```

Eu faço: converter PNG real → tirar magenta → plugar no hub **preenchendo a caixa** com pés embaixo.

---

## 8) Checklist rápido antes de mandar

- [ ] Pés colados na **borda de baixo** (não flutuando)  
- [ ] Personagem **grande** na vertical  
- [ ] 1 lâmina na mão + bainha **só no cinto**  
- [ ] Fundo **magenta chapado** `#FF00FF` (sem cenário)  
- [ ] Sem caixas vermelhas desenhadas na imagem  

---

## 9) Sobre o fundo do hub

- O **personagem** se gera em **magenta** (vira PNG transparente).  
- O **cenário** (bamboo/lua) já é `REF_04_hub_background_only.png` — **não** redesenhe o Tanjiro em cima do cenário no Imagine; o Godot empilha: fundo + personagem transparente.  
- Se quiser **só** melhorar o fundo: edite `REF_04` sem personagem.
