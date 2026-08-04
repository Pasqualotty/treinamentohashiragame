# 01 — Visão e stack

## Decisão de engine

| Critério | Escolha |
|----------|---------|
| Engine | **Godot 4.7.1** Standard (não Mono no dia 1) |
| Linguagem | **GDScript** |
| 2D | TileMap, CharacterBody2D, AnimatedSprite / TextureRect |
| Mobile | Export Android APK; renderer **Mobile** |
| Custo | Grátis, sem royalty |

## Instalado neste PC (2026-08-03)

| Tool | Path / nota |
|------|-------------|
| Godot | WinGet `GodotEngine.GodotEngine` → `Godot_v4.7.1-stable_win64.exe` |
| JDK 17 | `C:\Program Files\Microsoft\jdk-17.0.20.8-hotspot` |
| Android SDK | `%LOCALAPPDATA%\Android\Sdk` |
| Android Studio | `C:\Program Files\Android\Android Studio` (opcional se SDK ok) |
| Debug keystore | `%APPDATA%\Godot\keystores\debug.keystore` |

Detalhe operacional: `docs/SETUP-AMBIENTE.md`.

## Project settings relevantes

Arquivo: `project.godot`

- `config/name` = Treinamento Hashira  
- `run/main_scene` = `res://scenes/boot/splash_studio.tscn`  
- Viewport 1280×720, stretch `canvas_items` + `expand`  
- `textures/canvas_textures/default_texture_filter=0` (Nearest — bom pra pixel; paint pode sobrescrever por textura)  
- `renderer/rendering_method=mobile`  

## Autoloads

| Nome | Script | Papel |
|------|--------|-------|
| `Game` | `scripts/autoload/game.gd` | Save, moedas, breath, progressão |
| `SceneRouter` | `scripts/autoload/scene_router.gd` | Troca de cenas centralizada |

## Godot 4.7 — destaques úteis

- **VirtualJoystick** nativo (mobile stick) — preferir ao asset comunitário se couber.  
- Melhorias TileSet editor / Android.  
- Docs oficiais best practices: https://docs.godotengine.org/en/stable/tutorials/best_practices/index.html  
