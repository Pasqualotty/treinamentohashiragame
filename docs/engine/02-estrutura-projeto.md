# 02 — Estrutura do projeto

```
res://
  project.godot
  icon.svg
  assets/
    branding/          # logo Pasqualotti
    characters/
      player/          # bases + hub_idle/
      enemies/         # oni_weak_side.png
    tiles/w1/
    ui/
      hub/             # bg_still, bg_frame_00..
      buttons/         # btn_shop, btn_play, settings_gear
      icons/           # coin
      loading/         # keyart_w1
      touch/
    pack_v01/          # review humano (cópia)
  scenes/
    boot/              # splash_studio, loading
    main_menu/         # hub
    world/             # world_map
    battle/            # (futuro) stages
    characters/
    ui/
  scripts/
    autoload/
    boot/
    main_menu/
    world/
    combat/            # (futuro)
  resources/           # .tres stats, upgrades
  data/
  docs/                # GDD, engine, checklist
  export/
```

## Regras de organização

1. **Uma cena = um fluxo ou entidade** (player, oni, stage), não “Main.tscn monstro”.  
2. Scripts perto do domínio (`scripts/boot`, `scripts/main_menu`).  
3. Arte em `assets/`; `pack_vN/` só para review (pode reimportar no Godot — ok).  
4. `.godot/` no `.gitignore` (cache local).  
5. Preferir `unique_name_in_owner` + `%NodeName` no GDScript.

## Cenas principais hoje

| Cena | Script | Função |
|------|--------|--------|
| `scenes/boot/splash_studio.tscn` | `splash_studio.gd` | Logo marca → loading |
| `scenes/boot/loading.tscn` | `loading.gd` | Keyart + barra → hub |
| `scenes/main_menu/hub.tscn` | `hub.gd` | Estado padrão |
| `scenes/world/world_map.tscn` | `world_map.gd` | Escolha de fase (stub) |
