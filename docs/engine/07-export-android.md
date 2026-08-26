# 07 ÔÇö Export Android

**Objetivo:** gerar um APK de **debug** do hub (e do fluxo splashÔåÆloadingÔåÆhubÔåÆmapa) para sideload no celular.  
**Fan game pessoal** ÔÇö n├úo ├® build da Play Store.

## Paths (esta m├íquina)

| Item | Valor |
|------|--------|
| Java SDK (JDK 17) | `C:\Program Files\Microsoft\jdk-17.0.20.8-hotspot` |
| Android SDK | `%LOCALAPPDATA%\Android\Sdk` |
| Packages | platform-tools, build-tools 35.0.1, platforms;android-35, ndk 28.1.13356709, cmakeÔÇª |
| Debug keystore | `%APPDATA%\Godot\keystores\debug.keystore` (alias `androiddebugkey`, pass `android`) |
| Export templates | `%APPDATA%\Godot\export_templates\4.7.1.stable\` |
| Godot | winget `Godot_v4.7.1-stable_win64.exe` (ver `docs/android-paths.txt`) |

Lista copi├ível: `docs/android-paths.txt` ┬À setup geral: `docs/SETUP-AMBIENTE.md`.

## O que j├í est├í no reposit├│rio

| Artefato | Fun├º├úo |
|----------|--------|
| `export_presets.cfg` | Preset **Android Debug** ┬À package `studio.pasqualotti.hashira` ┬À sa├¡da `export/TreinamentoHashira-debug.apk` |
| `scripts/export-android-debug.ps1` | Export headless via Godot CLI (se templates + paths ok) |
| `export/` | Pasta de sa├¡da (APKs no `.gitignore`) |

**N├úo** versionamos: `*.keystore`, senhas de release, APKs gerados.

## Checklist one-click (Editor)

1. **Editor ÔåÆ Editor Settings ÔåÆ Export ÔåÆ Android**  
   - Java SDK Path = pasta do JDK 17  
   - Android SDK Path = pasta `Sdk`  
   - Debug Keystore = keystore debug do Godot (se vazio, o Editor cria/usa o padr├úo)
2. **Editor ÔåÆ Manage Export Templates** ÔåÆ baixar templates da **mesma vers├úo** do editor (4.7.1).  
   Sem isso o export falha com ÔÇ£No export template foundÔÇØ.
3. **Project ÔåÆ ExportÔÇª**  
   - Deve aparecer o preset **Android Debug** (vindo do `export_presets.cfg`)  
   - Package / Unique Name: `studio.pasqualotti.hashira`  
   - Export Path: `export/TreinamentoHashira-debug.apk`  
   - Architectures: **arm64-v8a** (celulares modernos)
4. Clique **Export Project** (modo Debug) ÔåÆ APK em `export/`.
5. No telefone: ative ÔÇ£Fontes desconhecidasÔÇØ / instalar via USB (`adb install -r export\TreinamentoHashira-debug.apk`).
6. Update pro sobrinho (depois do primeiro APK): bump `version_code` + export + GitHub Release. Ver `docs/AUTO-UPDATE.md`. Sem bump do `version_code` o celular acha que ja esta na ultima.

## CLI (opcional)

```powershell
# Na pasta do projeto (worktree ou main)
.\scripts\export-android-debug.ps1
# ou com path expl├¡cito do Godot:
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
| Version name / code | ver `export_presets.cfg` + `updates/app_version.json` (os dois têm que subir juntos) |
| Internet | **on** (check de update) |
| Custom permission | `REQUEST_INSTALL_PACKAGES` (instalador OTA) |
| Arch | arm64-v8a |
| Gradle build | **off** (export ÔÇ£cl├íssicoÔÇØ com templates) |
| Assinatura | debug (Editor Settings; sem keystore de release no git) |

## Bloqueios comuns

| Sintoma | O que fazer |
|---------|-------------|
| No export template found | Manage Export Templates ÔåÆ Download 4.7.1 |
| SDK path invalid | Colar path de `docs/android-paths.txt` no Editor Settings |
| Keystore missing | Godot regenera debug em `%APPDATA%\Godot\keystores\` |
| ETC2/ASTC required | `project.godot` ÔåÆ `textures/vram_compression/import_etc2_astc=true` (j├í ligado neste repo) |
| APK enorme / lento | Manter s├│ arm64-v8a no preset |
| Quer release Play | Fora de escopo agora ÔÇö keystore de release **fora** do git |

## Docs oficiais

https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html  

## Nota

Android Studio **n├úo** ├® o projeto do jogo ÔÇö s├│ ferramenta de SDK. N├úo criar ÔÇ£New ProjectÔÇØ Kotlin para o Hashira.
