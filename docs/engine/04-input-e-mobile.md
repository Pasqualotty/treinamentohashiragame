# 04 — Input e mobile

## InputMap (a completar no Project Settings se faltar)

| Action | Teclado dev | Touch (planejado) |
|--------|-------------|-------------------|
| `move_left` / `move_right` | A/D, setas | Joystick esquerdo |
| `jump` | Espaço | Botão pulo |
| `advance` | F / Shift | Dash |
| `attack_basic` | J | Botão atk |
| `skill_1` / `skill_2` | K / L | Skills |
| `ultimate` | I | Ultimate (só full) |
| `pause` | Esc | Ícone pause |

Sempre:

```gdscript
Input.is_action_just_pressed("jump")
# NÃO: Input.is_key_pressed(KEY_SPACE) só
```

## Layout touch (GDD)

- **Paisagem**, dois polegares.  
- Esquerda: stick + dash + pulo.  
- Direita: atk + 2 skills + ultimate.  

## Godot 4.7 VirtualJoystick

4.7 inclui nó oficial **VirtualJoystick** (3 modos). Preferir documentação atual da versão instalada ao copiar plugins antigos.

## Teste

1. PC: teclado no slice.  
2. Android: export debug APK + USB debugging ou sideload.  
3. Playtest semanal no telefone do sobrinho.
