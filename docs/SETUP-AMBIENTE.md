# Setup do ambiente — Treinamento Hashira

**Atualizado:** 2026-08-03

## Instalado nesta máquina

| Ferramenta | Status | Notas |
|------------|--------|-------|
| **Godot 4.7.1** (Standard) | ✅ winget | `Godot_v4.7.1-stable_win64.exe` |
| **OpenJDK 17** (Microsoft) | ✅ | `C:\Program Files\Microsoft\jdk-17.0.20.8-hotspot` |
| **Git** | ✅ | |
| **Projeto Godot** | ✅ nesta pasta | splash → loading → hub → mapa |
| **Android Studio** | ✅ | `C:\Program Files\Android\Android Studio` |
| **Android SDK** | ✅ cmdline-tools | `%LOCALAPPDATA%\Android\Sdk` |
| **Licenças SDK** | ✅ aceitas | `sdkmanager --licenses` |
| **Debug keystore** | ✅ | `%APPDATA%\Godot\keystores\debug.keystore` |

### Abrir o projeto

Duplo clique em `project.godot`, ou:

```powershell
& "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.1-stable_win64.exe" --path "C:\Users\mathe\Documents\Pasqualotti Studios - Demon Slayer - Treinamento hashira" --editor
```

### Fluxo já ligado no código

```
splash_studio → loading → hub → [JOGAR] → world_map
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
| | alias `androiddebugkey` · password `android` |

### Pacotes SDK (docs Godot 4.x)

- platform-tools  
- build-tools;35.0.1  
- platforms;android-35  
- cmake;3.10.2.4988404  
- ndk;28.1.13356709  
- cmdline-tools (latest)  

Variáveis de usuário: `ANDROID_HOME`, `ANDROID_SDK_ROOT`, `JAVA_HOME`.

### No Godot (uma vez, se ainda não tiver)

**Editor → Editor Settings → Export → Android**

1. Java SDK Path = pasta do JDK 17  
2. Android SDK Path = pasta Sdk  
3. **Project → Export → Add → Android** quando for gerar APK  
4. Baixar **Export Templates** se o Godot pedir  

> O SDK **já está instalado por linha de comando** — o wizard do Android Studio é opcional para o export Godot.

### Controles PC (dev)

Project → Project Settings → Input Map:

| Action | Tecla |
|--------|--------|
| move_left / move_right | A/D ou setas |
| jump | Espaço |
| advance (dash) | F / Shift |
| attack_basic | J |
| skill_1 / skill_2 | K / L |
| ultimate | I |
| pause | Esc |
