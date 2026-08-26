# Auto-update (sideload família)

## Agora / Depois (Matheus)

**Agora (primeira vez):**
1. O APK desta máquina já está em `export\TreinamentoHashira-debug.apk` (72 MB). Se precisar gerar de novo: `.\scripts\export-android-debug.ps1` (ou Editor → Export → Android Debug).
2. Manda **esse** APK uma vez pro sobrinho (WhatsApp / Drive / USB).
3. Ele instala e joga.

**Depois (versão nova):** sobe a versão no balcão (GitHub Release). **Não** manda APK de novo. O menino abre o jogo, vê o aviso, atualiza sozinho.

Não precisa Play Store. O balcão só entra quando existir versão 2 — não agora.

---

O sobrinho **não reinstala na mão**. Ele abre o jogo; se existe versão nova, aparece um aviso, baixa e o Android pede pra instalar.

Não é Play Store. O APK e o manifesto JSON ficam num **GitHub Release** público.

## O que o jogo faz

1. Splash → loading → hub (como sempre).
2. No hub (depois de aparecer), o app pede `latest.json` no endereço de `updates/app_version.json` → `manifest_url`.
3. Se `version_code` remoto **é maior** que o do aparelho: aviso em português.
4. **ATUALIZAR** baixa o APK pra pasta do app e abre o instalador do Android.
5. Sem internet, timeout ou manifesto ruim: **silêncio**. Dá pra jogar.
6. Download falhou: “Não deu pra baixar” + tentar de novo + jogar assim mesmo.
7. No PC / editor: o check **não** bate na rede e **não** abre popup.

Timeout: 8 s no manifesto, 180 s no APK. HTTPS only.

## Onde sobe o arquivo

| Arquivo | Onde mora | Quem lê |
|---------|-----------|---------|
| `latest.json` | GitHub Release, asset com **esse nome** | o celular, em `…/releases/latest/download/latest.json` |
| `TreinamentoHashira.apk` | o mesmo Release (tag `v0.0.2` etc.) | URL dentro do JSON |
| `updates/latest.json` neste repo | **exemplo + o que o script gera** | não é o check ao vivo |
| `updates/app_version.json` | versão **deste** build + URL do manifesto | o APK exportado |

URL ao vivo (repo atual):

`https://github.com/Pasqualotty/treinamentohashiragame/releases/latest/download/latest.json`

Repo **privado** quebra o check (o telefone não tem token). Deixe o repo público **ou** mude `manifest_url` pra outro HTTPS sem senha.

## Publicar um update (Matheus)

Toda exportação precisa de **version_code novo**. Se o número local e o remoto forem iguais, o sobrinho não vê aviso.

```powershell
# 1) Sobe o número (grava project.godot, export_presets.cfg, app_version.json, latest.json)
.\scripts\publish-update.ps1 -VersionName 0.0.2 -Changelog "Pulo mais fácil e um oni novo."

# 2) Exporta o APK (Editor → Export, ou)
.\scripts\export-android-debug.ps1

# 3) Preenche tamanho + sha256 no latest.json
.\scripts\publish-update.ps1 -FillFromApk

# 4) Sobe o Release (gh autenticado) — NÃO commita sozinho
.\scripts\publish-update.ps1 -FillFromApk -CreateGithubRelease
```

Ou o passo 4 na mão:

```powershell
gh release create "v0.0.2" "export/TreinamentoHashira-debug.apk" "updates/latest.json" --repo Pasqualotty/treinamentohashiragame --title "Treino 0.0.2" --notes "Pulo mais fácil e um oni novo."
```

Renomeie o asset do APK para `TreinamentoHashira.apk` se o `gh` mandar o nome debug. O JSON aponta para:

`https://github.com/Pasqualotty/treinamentohashiragame/releases/download/v0.0.2/TreinamentoHashira.apk`

Se o asset ficar com outro nome, edite `apk_url` em `updates/latest.json` **antes** de subir o Release (ou edite o asset no GitHub).

5. Sobrinho abre o jogo no telefone (precisa internet **nessa** hora só pro check/download).

## Schema do `latest.json`

```json
{
  "version_code": 2,
  "version_name": "0.0.2",
  "apk_url": "https://github.com/Pasqualotty/treinamentohashiragame/releases/download/v0.0.2/TreinamentoHashira.apk",
  "changelog": "Pulo mais fácil.",
  "size_bytes": 45000000,
  "sha256": ""
}
```

- `version_code` (int, obrigatório): o que o Android compara. Tem que ser **maior** que o do APK instalado.
- `version_name` (texto): o que a criança lê.
- `apk_url`: só `https://`
- `changelog`: curto; o jogo corta em 160 caracteres
- `size_bytes`: opcional; `0` = não mostra “uns X MB”
- `sha256`: opcional; 64 hex. Vazio = não verifica

## Primeira vez no telefone

O update **não instala o jogo zero**. Alguém ainda manda o primeiro APK (USB / Drive / WhatsApp). A partir daí, as próximas vêm pelo aviso.

Na **primeira** instalação a partir deste código, o Android pode pedir “permitir que este app instale desconhecidos”. O aviso do jogo tem o botão **ABRIR PERMISSÃO**. Xiaomi / Samsung / ColorOS às vezes escondem isso em Segurança.

O app e o APK novo precisam do **mesmo** `package` (`studio.pasqualotti.hashira`) e da **mesma família de assinatura** (debug keystore do Godot nesta máquina). Trocar o keystore = o Android recusa atualizar por cima.

## Testar o aviso no PC (sem instalar)

Crie `user://debug_update_prompt.json` (pasta de user data do Godot) com um manifesto válido. O hub abre o mesmo cartaz. **ATUALIZAR** no PC só diz que isso vale no celular.

## O que só dá pra validar no aparelho

- GET real do Release + download do APK
- Tela “fontes desconhecidas” / INSTALL
- Abrir a versão nova depois de instalar
- Xiaomi/Samsung bloqueando o instalador
- Dados móveis lentos / Wi-Fi caindo no meio do download

Smoke headless (parse + UI, sem rede):

```powershell
godot --headless --path . -s res://scripts/qa/smoke_auto_update.gd
```
