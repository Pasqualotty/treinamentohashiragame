# Review v3 — Tanjiro hub (ainda NÃO no Godot)

**Status:** 🟡 aguardando OK  
**Feedback atendido nesta versão:**

## Problemas que você apontou

| Problema | Correção nesta v3 |
|----------|-------------------|
| Não enche a caixa vermelha | Mock com personagem **preenchendo a caixa vermelha** |
| Katana “Darth Maul” (tubo preto embaixo da mão) | **Removido** — cabo curto abaixo do punho só |
| Bainha no lugar errado | **Saya só no cinto/quadril** (esquerda), **separada** da espada |
| Espada dupla | **1 lâmina** na mão + **1 bainha** no cinto = 2 peças, não sabre duplo |

## O que abrir (ordem)

1. **`DETAIL_sword_and_hip.png`** — zoom da mão + hip (confere se ainda parece sabre duplo)  
2. **`MOCK_hub_center.png`** — caixa vermelha + personagem grande no fundo do hub  
3. **`SHEET_idle_on_checker.png`** — frames no xadrez (sem magenta)  
4. **`HERO_static_transparent.png`** — frame master  

## Frames idle propostos

| Frame | Conteúdo |
|-------|----------|
| 00 / 02 / 04 open | Master v2 |
| 01 breathe | Respiro leve |
| 03 blink | Olhos fechados |

Loop: open → breathe → open → blink → open (calmo).

## Ainda NÃO implementado no jogo

O hub do Godot **continua com o asset antigo** até você mandar:

**“Pode implementar o pack review v2”**

## Se ainda estiver errado

Manda print do `DETAIL_sword_and_hip` com o que falhou (ex.: “bainha ainda parece lâmina”, “quero tsuba em forma de chama”).
