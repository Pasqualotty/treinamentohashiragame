# 07 — Export Android

**Objetivo:** gerar um APK de **debug** do hub (e do fluxo splash→loading→hub→mapa) para sideload no celular.  
**Fan game pessoal** — não é build da Play Store.

## Paths (esta máquina)

| Item | Valor |
|------|--------|
| Java SDK (JDK 17) | `C:\Program Files\Microsoft\jdk-17.0.20.8-hotspot` |
| Android SDK | `%LOCALAPPDATA%\Android\Sdk` |
| Packages | platform-tools, build-tools 35.0.1, platforms;android-35, ndk 28.1.13356709, cmake… |
| Debug keystore | `%APPDATA%\Godot\keystores\debug.keystore` (alias `androiddebugkey`, pass `android`) |
| Export templates | `%APPDATA%\Godot\export_templates\4.7.1.stable\` |
| Godot | winget `Godot_v4.7.1-stable_win64.exe` (ver `docs/android-paths.txt`) |

Lista copiável: `docs/android-paths.txt` · setup geral: `docs/SETUP-AMBIENTE.md`.

## O que já está no repositório

| Artefato | Função |
|----------|--------|
| `export_presets.cfg` | Preset **Android Debug** · package `studio.pasqualotti.hashira` · saída `export/TreinamentoHashira-debug.apk` |
| `scripts/export-android-debug.ps1` | Export headless via Godot CLI (se templates + paths ok) |
| `export/` | Pasta de saída (APKs no `.gitignore`) |

**Não** versionamos: `*.keystore`, senhas de release, APKs gerados.

## Checklist one-click (Editor)

1. **Editor → Editor Settings → Export → Android**  
   - Java SDK Path = pasta do JDK 17  
   - Android SDK Path = pasta `Sdk`  
   - Debug Keystore = keystore debug do Godot (se vazio, o Editor cria/usa o padrão)
2. **Editor → Manage Export Templates** → baixar templates da **mesma versão** do editor (4.7.1).  
   Sem isso o export falha com “No export template found”.
3. **Project → Export…**  
   - Deve aparecer o preset **Android Debug** (vindo do `export_presets.cfg`)  
   - Package / Unique Name: `studio.pasqualotti.hashira`  
   - Export Path: `export/TreinamentoHashira-debug.apk`  
   - Architectures: **arm64-v8a** (celulares modernos)
4. Clique **Export Project** (modo Debug) → APK em `export/`.
5. No telefone: ative “Fontes desconhecidas” / instalar via USB (`adb install -r export\TreinamentoHashira-debug.apk`).

## CLI (opcional)

```powershell
# Na pasta do projeto (worktree ou main)
.\scripts\export-android-debug.ps1
# ou com path explícito do Godot:
.\scripts\export-android-debug.ps1 -GodotExe "C:\path\to\Godot_v4.7.1-stable_win64.exe"
```

Comando manual equivalente:

```powershell
& $GodotExe --headless --path . --export-debug "Android Debug" "export/TreinamentoHashira-debug.apk"
```

## Preset (resumo)

| Campo | Valor |
|-------|--------|
| Nome | `Android Debug` |
| Platform | Android |
| Unique name | `studio.pasqualotti.hashira` |
| App name | Treinamento Hashira |
| Version name / code | `0.1.0` / `1` |
| Arch | arm64-v8a |
| Gradle build | **off** (export “clássico” com templates) |
| Assinatura | debug (Editor Settings; sem keystore de release no git) |

## Bloqueios comuns

| Sintoma | O que fazer |
|---------|-------------|
| No export template found | Manage Export Templates → Download 4.7.1 |
| SDK path invalid | Colar path de `docs/android-paths.txt` no Editor Settings |
| Keystore missing | Godot regenera debug em `%APPDATA%\Godot\keystores\` |
| APK enorme / lento | Manter só arm64-v8a no preset |
| Quer release Play | Fora de escopo agora — keystore de release **fora** do git |

## Docs oficiais

https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html  

## Nota

Android Studio **não** é o projeto do jogo — só ferramenta de SDK. Não criar “New Project” Kotlin para o Hashira.
