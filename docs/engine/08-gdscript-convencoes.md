# 08 — Convenções GDScript

## Tipagem (Godot 4.x / 4.7)

Evitar erro `Cannot infer the type of "x" variable`:

```gdscript
# Ruim
const FRAME_DURATIONS := [0.55, 0.45]
var dur := FRAME_DURATIONS[i]

# Bom
const FRAME_DURATIONS: Array[float] = [0.55, 0.45]
var dur: float = FRAME_DURATIONS[i]
```

Arrays tipados: `Array[Texture2D]`, `Array[String]`.

## Nós

```gdscript
@onready var bar: ProgressBar = %ProgressBar
```

Marcar `unique_name_in_owner` na cena.

## Sinais

Preferir sinais para combate UI (`hurt`, `died`, `coins_changed`) em vez de buscar nó por path frágil.

## Player (futuro)

- `CharacterBody2D` + `move_and_slide`  
- State machine com `enum` + `match` no começo  
- Hitbox `Area2D` só nos frames active  

## Formatação

- UTF-8  
- Tabs conforme Godot default do projeto  
- Sem secrets no repo  
