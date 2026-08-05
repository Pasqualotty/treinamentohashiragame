# 03 — Fluxo e cenas

## Diagrama

```
[App start]
    main_scene = splash_studio.tscn
         │
         ▼
   SplashStudio  (hold ~2.2s, logo branding)
         │ SceneRouter.to_loading()
         ▼
     Loading     (keyart + ProgressBar 0–100%)
         │ SceneRouter.to_hub()
         ▼
       Hub       (BG animado, Tanjiro idle, botões)
         │ JOGAR → SceneRouter.to_world_map()
         ▼
    WorldMap     (Fase 1–3, Boss stubs)
         │ (futuro) go_to stage_w1_01.tscn
         ▼
     Battle      (CharacterBody2D, HUD touch)
```

## SceneRouter

```gdscript
# scripts/autoload/scene_router.gd
const SPLASH := "res://scenes/boot/splash_studio.tscn"
const LOADING := "res://scenes/boot/loading.tscn"
const HUB := "res://scenes/main_menu/hub.tscn"
const WORLD_MAP := "res://scenes/world/world_map.tscn"

func go_to(path: String) -> void:
    get_tree().change_scene_to_file(path)
```

**Regra:** não espalhar `change_scene_to_file` em 20 scripts — passar pelo router (ou expandir API com fade depois).

## Game (autoload)

Responsabilidades atuais:

- `coins_banked`, `coins_run`  
- `breath` / ultimate ready  
- `stages_cleared`, `upgrades`  
- `save_game` / `load_game` em `user://save.json`  
- Sinais: `coins_changed` (legado/hub), **`run_coins_changed`** (fase/HUD), `breath_changed`  

Não colocar lógica de hitbox/frame data no `Game`.

HUD de combate reutilizável: ver [11-combat-hud.md](./11-combat-hud.md) (`scenes/ui/combat_hud.tscn`).
