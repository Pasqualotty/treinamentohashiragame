# Playtest com o sobrinho — checklist 10 minutos

**Objetivo:** alguém joga **sem você explicar** e o jogo ainda “funciona”.  
**Duração alvo:** ~10 minutos no celular deitado (ou emulador se for o caso).  
**APK:** `export/TreinamentoHashira-debug.apk` (desinstale a versão antiga antes).

> Você **não** fala “aperte aqui” nem “é side-scroller”. Só observa e anota.

---

## Antes de entregar o celular (30s)

- [ ] APK instalado e abre sem crash na splash
- [ ] Celular **deitado** (paisagem)
- [ ] Volume audível (BGM/SFX)
- [ ] Você tem papel/notas ou este arquivo aberto no PC

---

## Cronômetro (~10 min)

| Min | O que observar (sem ajudar) | OK? | Nota rápida |
|-----|-----------------------------|-----|-------------|
| 0–1 | Splash → loading → chega no **hub** sozinho | ☐ | |
| 1–2 | Entende o botão **JOGAR** e chega no **mapa** | ☐ | |
| 2–3 | Entra na **fase 1** (ou qualquer fase liberada) | ☐ | |
| 3–5 | **Anda**, **pula**, **dá dash** (se achar o botão) | ☐ | |
| 5–7 | **Ataca** onis / vê vida cair / **moeda** aparece | ☐ | |
| 7–8 | Sobrevive ou morre sem crash; entende “perdeu” | ☐ | |
| 8–9 | Volta pro mapa/hub (pause, portal ou morte) | ☐ | |
| 9–10 | Abre **loja** ou **créditos** sem travar | ☐ | |

---

## 8 perguntas no final (sim/não + 1 frase)

1. **Dá pra jogar sem tutorial?**  
   ☐ Sim  ☐ Mais ou menos  ☐ Não — _______________________

2. **Os botões na tela cabem nos polegares (deitado)?**  
   ☐ Sim  ☐ Apertado  ☐ Não alcança — _______________________

3. **Ficou claro o que matar / o que fazer na fase?**  
   ☐ Sim  ☐ Confuso — _______________________

4. **Pulo e dash parecem “gostosos” ou escorregadios?**  
   ☐ Bom  ☐ Meia-boca  ☐ Ruim — _______________________

5. **Ataque parece acertar o que deveria?**  
   ☐ Sim  ☐ Às vezes  ☐ Quase nunca — _______________________

6. **Moedas: fácil de pegar?**  
   ☐ Sim  ☐ Chatas — _______________________

7. **Travou, bugou tela preta, sumiu botão?**  
   ☐ Não  ☐ Sim: _______________________

8. **Joga de novo amanhã se eu pedir?**  
   ☐ Sim  ☐ Talvez  ☐ Não — _______________________

---

## Sinais de “gate passou” (mínimo)

Marque **PASS** só se **todos** forem verdade:

- [ ] Completou boot até hub **sem crash**
- [ ] Entrou em pelo menos **1 fase**
- [ ] Moveu o personagem e usou **ataque** pelo menos 1×
- [ ] **Nenhum** crash / soft-lock que precise fechar o app
- [ ] Ele conseguiu sozinho em ≥ **6 dos 8** minutos de gameplay (você não precisou “salvar” o play)

**Veredito humano:** ☐ PASS  ☐ FAIL  ☐ PRECISA REFAZER COM AJUSTE

Data: ________  Dispositivo: ________  Quem jogou: ________

---

## Se FAIL — anote em 3 linhas (pra mandar pro dev)

1. Onde parou:  
2. O que tentou:  
3. O que esperava:

---

## Suite automática (não substitui o sobrinho)

No PC, na pasta do projeto:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_smokes.ps1
```

Esperado: `SUITE PASS` (load stages + playable W1 + combat e2e + meta + player).  
Smoke **não** prova “é divertido” — só prova “não quebrou o básico no headless”.

---

## Links úteis

| Doc | Uso |
|------|-----|
| `docs/STATUS-PROGRESSO.md` | Onde o projeto está / premium wave |
| `docs/CHECKLIST-MESTRE.html` | Checklist longo (browser) |
| `export/playtest_shots/` | Prints de prova de fluxo |
