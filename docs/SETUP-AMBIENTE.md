# Setup do ambiente — Treinamento Hashira

**Atualizado:** 2026-08-03

## Instalado nesta máquina

| Ferramenta | Status | Notas |
|------------|--------|-------|
| **Godot 4.7.1** (Standard) | ✅ winget `GodotEngine.GodotEngine` | `Godot_v4.7.1-stable_win64.exe` via WinGet Packages |
| **OpenJDK 17** (Microsoft) | ✅ winget `Microsoft.OpenJDK.17` | Precisa para export Android |
| **Git** | ✅ | já estava |
| **Projeto Godot** | ✅ nesta pasta | `project.godot` + cenas boot/hub/mapa |
| **Android Studio / SDK** | ⏳ instalar em paralelo | necessário só para APK no celular |

### Abrir o projeto

No Explorer: duplo clique em `project.godot`  
Ou no terminal (path do WinGet):

```powershell
& "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.1-stable_win64.exe" --path "C:\Users\mathe\Documents\Pasqualotti Studios - Demon Slayer - Treinamento hashira" --editor
```

Atalho opcional: `C:\Users\mathe\Tools\Godot\Godot.exe` (se o link foi criado).

### Fluxo já ligado no código

```
splash_studio → loading → hub → [JOGAR] → world_map
```

Main scene: `res://scenes/boot/splash_studio.tscn`  
Autoloads: `Game`, `SceneRouter`

### Depois do Android Studio

1. Abrir Android Studio uma vez → instalar SDK padrão  
2. SDK Manager: platform-tools, build-tools, Platform API, NDK, CMake  
3. Godot → Editor Settings → Export → Android: paths do JDK + SDK  
4. Project → Export → Android → templates  

Ver checklist mestre §6 e `PLANEJAMENTO-TECNICO.md`.

### Controles PC (dev) — configurar no Editor

Project → Project Settings → Input Map (criar se faltar):

| Action | Tecla sugerida |
|--------|----------------|
| move_left / move_right | A/D ou setas |
| jump | Espaço |
| advance (dash) | F / Shift |
| attack_basic | J |
| skill_1 / skill_2 | K / L |
| ultimate | I |
| pause | Esc |
