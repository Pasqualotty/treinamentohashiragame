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

### Cara dos caçadores (3 linhas)

1. PERSONAGENS → **15 cards com cara** (não retângulo de cor). Escolher **Nezuko** (livre) → hub e fase com cara/roupa dela, sem Tanjiro rosa.
2. **Zenitsu** só depois do chefe do Mundo 1; **Inosuke** depois do chefe do Mundo 2. Os outros 11 (Kanao…Muzan) continuam locked no save novo: toque recusa, mas o card já mostra portrait.
3. Voltar pro **Tanjiro**: hub e fase voltam ao pack fiel (haori xadrez, sem wash amarelo).

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

## 2 celulares (LAN, mesmo Wi-Fi)

Não entra no CI. Dois APKs (ou 2 instâncias Play no PC com `127.0.0.1`).

1. Os dois no **mesmo Wi-Fi da casa** (sem rede de convidado isolado). Sem campo de IP — Criar/Entrar basta.
2. Host: hub → Amigos → **Criar sala** → lobby tela cheia. Código de 6 no topo (tap copia). Cada um escolhe o caçador embaixo. Escolhe **2 vs oni** (já vem marcado). **+ Chamar amigo** no amigo já aceito.
3. Guest: entra pelo **+** do host, ou **Entrar** + código. Beacon acha no Wi-Fi; se não, a sala da estrela cobre.
4. Host toca **JOGAR** → mapa → `w1_01`. Guest **não** escolhe fase (“O anfitrião escolhe a fase”).
5. Os dois aparecem na fase; cada um controla o **próprio** caçador (touch no celular dele).
6. Os dois batem oni. Um sai da sala → o outro não fica preso (guest cai → hub; host sozinho segue ou volta ao hub se ainda não entrou na fase).
7. Fecha o app e abre de novo: a lista de amigos ainda tem o nick (sem IP na tela).

**APK diferente (`version_code`):** guest vê recusa em PT (“Atualize o APK”), não combate quebrado.

---

## 2 casas (só o celular)

Não entra no CI. O sobrinho **não liga PC**. Cada um na sua casa (ou 4G).

1. Os dois no hub → Amigos. Sem código de amigo. Sem colar IP.
2. Host: **Adicionar amigo** → escreve o **nome do perfil** do sobrinho → **Enviar convite**. Sobrinho **Aceita**.
3. Host: **Criar sala**. Na lista, toca **+** no sobrinho (não o x). O celular dele entra sozinho.
4. Reserva: **Entrar** + código de 6 da sala (Zap ainda vale) se o + não achar.
5. Host **JOGAR** → mapa → fase. Guest não escolhe fase.
6. Se a sala da estrela cair: o jogo **ainda abre**. Criar/Entrar avisa “A sala da estrela está desligada”. Loading **não** fala “Conectando-se…”. Wi-Fi da mesma casa continua.

**Reserva de dev (PC):** `tools/ligar_computador_da_sala.ps1` no editor. Não é o caminho do sobrinho.

---

## 4 celulares (4 vs oni)

Não entra no CI. Quatro APKs (ou 4 instâncias Play).

1. Host: Amigos → **Criar sala** → toca **4 vs oni** (antes dos amigos entrarem).
2. Até 3 amigos **Entrar** com o código. Cada celular = um caçador.
3. Host **JOGAR** → mapa → fase. Guest não escolhe fase.
4. A câmera segue quem está vivo. Oni corre no mais perto.
5. **Mapa de batalha:** host toca **Começar** (até 4). Sem amigo, as vagas são máquina. Skills e respiração funcionam. Quem vence vê **De novo** / **Lobby** (mesma sala). **1v1** na sala: fundo do pátio, nome em cima, respiração no HUD, corpos maiores. Fim: nome + caçador + **De novo** ou **Lobby**.

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
