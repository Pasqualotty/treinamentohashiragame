# 07 — Export Android

## Paths

| Item | Valor |
|------|--------|
| Java SDK | `C:\Program Files\Microsoft\jdk-17.0.20.8-hotspot` |
| Android SDK | `%LOCALAPPDATA%\Android\Sdk` |
| Packages | platform-tools, build-tools 35.0.1, platforms;android-35, ndk 28.1.13356709, cmake 3.10.2… |
| Debug keystore | `%APPDATA%\Godot\keystores\debug.keystore` (alias `androiddebugkey`, pass `android`) |

## No Godot

1. **Editor → Editor Settings → Export → Android**  
   - Java SDK Path  
   - Android SDK Path  
2. **Project → Export → Add → Android**  
3. Baixar **Export Templates** se pedido  
4. Package name sugerido: `studio.pasqualotti.hashira`  
5. Export **Debug** APK → `export/`  

## Docs oficiais

https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html  

## Nota

Android Studio **não** é o projeto do jogo — só ferramenta de SDK. Não criar “New Project” Kotlin para o Hashira.
