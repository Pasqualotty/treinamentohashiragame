# Setup do ambiente ÔÇö Treinamento Hashira

**Atualizado:** 2026-08-05 (preset Android + script de export debug)

## Instalado nesta m├íquina

| Ferramenta | Status | Notas |
|------------|--------|-------|
| **Godot 4.7.1** (Standard) | Ô£à winget | `Godot_v4.7.1-stable_win64.exe` |
| **OpenJDK 17** (Microsoft) | Ô£à | `C:\Program Files\Microsoft\jdk-17.0.20.8-hotspot` |
| **Git** | Ô£à | |
| **Projeto Godot** | Ô£à nesta pasta | splash ÔåÆ loading ÔåÆ hub ÔåÆ mapa |
| **Android Studio** | Ô£à | `C:\Program Files\Android\Android Studio` |
| **Android SDK** | Ô£à cmdline-tools | `%LOCALAPPDATA%\Android\Sdk` |
| **Licen├ºas SDK** | Ô£à aceitas | `sdkmanager --licenses` |
| **Debug keystore** | Ô£à | `%APPDATA%\Godot\keystores\debug.keystore` |
| **Export preset Android** | Ô£à no git | `export_presets.cfg` ┬À package `studio.pasqualotti.hashira` |
| **Export templates 4.7.1** | Ô£à esta m├íquina | `%APPDATA%\Godot\export_templates\4.7.1.stable\` |

### Abrir o projeto

Duplo clique em `project.godot`, ou:

```powershell
& "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.1-stable_win64.exe" --path "C:\Users\mathe\Documents\Pasqualotti Studios - Demon Slayer - Treinamento hashira" --editor
```

> Ajuste `--path` para a pasta real do clone/worktree (ex.: `hashira-apk-teste`).

### Fluxo j├í ligado no c├│digo

```
splash_studio ÔåÆ loading ÔåÆ hub ÔåÆ [JOGAR] ÔåÆ world_map
```

Main scene: `res://scenes/boot/splash_studio.tscn`  
Autoloads: `Game`, `SceneRouter`

---

## Paths Android (Godot Export)

| Setting | Path |
|---------|------|
| **Java SDK (JDK 17)** | `C:\Program Files\Microsoft\jdk-17.0.20.8-hotspot` |
| **Android SDK** | `C:\Users\mathe\AppData\Local\Android\Sdk` |
| **Debug keystore** | `C:\Users\mathe\AppData\Roaming\Godot\keystores\debug.keystore` |
| | alias `androiddebugkey` ┬À password `android` |

### Pacotes SDK (docs Godot 4.x)

- platform-tools  
- build-tools;35.0.1  
- platforms;android-35  
- cmake;3.10.2.4988404  
- ndk;28.1.13356709  
- cmdline-tools (latest)  

Vari├íveis de usu├írio: `ANDROID_HOME`, `ANDROID_SDK_ROOT`, `JAVA_HOME`.

### No Godot (uma vez, se ainda n├úo tiver)

**Editor ÔåÆ Editor Settings ÔåÆ Export ÔåÆ Android**

1. Java SDK Path = pasta do JDK 17  
2. Android SDK Path = pasta Sdk  
3. Debug keystore = `%APPDATA%\Godot\keystores\debug.keystore`  
4. **Editor ÔåÆ Manage Export Templates** ÔåÆ Download **4.7.1** (obrigat├│rio)  
5. **Project ÔåÆ ExportÔÇª** ÔåÆ preset **Android Debug** (j├í vem de `export_presets.cfg`)  
6. Export Project ÔåÆ APK em `export/TreinamentoHashira-debug.apk`

Guia completo: `docs/engine/07-export-android.md`.

### Export headless (opcional)

```powershell
.\scripts\export-android-debug.ps1
```

Requer templates 4.7.1 instalados e os paths acima no Editor Settings (o Godot CLI l├¬ as mesmas settings do usu├írio).

> O SDK **j├í est├í instalado por linha de comando** ÔÇö o wizard do Android Studio ├® opcional para o export Godot.  
> **N├úo** commitar keystore de release nem senhas.

### Controles PC (dev)

Project ÔåÆ Project Settings ÔåÆ Input Map:

| Action | Tecla |
|--------|--------|
| move_left / move_right | A/D ou setas |
| jump | Espa├ºo |
| advance (dash) | F / Shift |
| attack_basic | J |
| skill_1 / skill_2 | K / L |
| ultimate | I |
| pause | Esc |
