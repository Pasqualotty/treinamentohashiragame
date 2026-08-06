# Status do projeto — Treinamento Hashira

**Atualizado:** 2026-08-06  
**Marca:** **MVP W1 COMPLETO**

---

## Onde estamos (1 frase)

**MVP do checklist fechado e jogavel:** splash → loading → hub → mapa W1 visual → fases 1–3 + boss → combate (Tanjiro, oni fraco/elite, coins, breath/ult, touch, HUD) → clear → loja 4 upgrades + save → APK debug. Prova em emulador Android (hub/mapa/fase).

---

## Definicao de “pronto” (MVP do GDD §2 / d17)

| Item | Status |
|------|--------|
| 1 mundo, 3 fases + boss | ✅ |
| So Tanjiro | ✅ |
| Loja 4 upgrades + save | ✅ |
| 2 tipos de oni (fraco + elite) | ✅ |
| Boot splash → loading → hub | ✅ |
| JOGAR → mapa → fase jogavel | ✅ |
| Touch + InputMap | ✅ |
| APK instalavel | ✅ `export/TreinamentoHashira-debug.apk` |
| Creditos fan game | ✅ engrenagem do hub |
| Pause na fase | ✅ Continuar / Mapa / Hub |

---

## FORA do MVP (depois — checklist F/G residual)

- Zenitsu, Inosuke, Hashiras, W2–W5, Muzan/Yoriichi  
- Anim sheets AAA multi-frame  
- Keystore release assinado + “noite dos amigos” em 3+ aparelhos  
- Balance fino / nomes de skill com o sobrinho  

Isso **nao** bloqueia o MVP. O doc diz: MVP ≠ jogo dos sonhos no dia 1.

---

## Decisoes GDD fechadas no codigo (defaults)

| Tema | Default MVP |
|------|-------------|
| Skills Tanjiro | Corte em Arco / Investida |
| Upgrades loja | HP, Dano, Velocidade, Dash CD |
| Morte na fase | perde moedas da run (`lose_run_coins`) |
| Upgrades | **globais** |
| Elite/boss moedas | elite 20 / boss clear bank da run |

---

## Como instalar

```
export/TreinamentoHashira-debug.apk
```

Desinstale a versao antiga → instale esta → celular deitado.

Prints de prova (emulador): `export/playtest_shots/PROOF_*.png`

---

## Historico

| Data | Evento |
|------|--------|
| 2026-08-03 | GDD + boot/hub |
| 2026-08-05 | W1 playable + arte + audio + frentes |
| 2026-08-06 | **MVP W1 COMPLETO** (pause, creditos, polimento residual, APK) |
