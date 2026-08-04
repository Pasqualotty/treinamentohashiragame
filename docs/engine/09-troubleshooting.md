# 09 — Troubleshooting

| Sintoma | Causa | Fix |
|---------|-------|-----|
| `Not a PNG file` / ERR_FILE_CORRUPT | JPEG salvo como .png | Pillow → PNG real; apagar `.import` |
| Magenta no hub | Chroma não aplicado | Script chroma + recarregar textura |
| Katana “solta” / second stick | Bug de gen side view | `image_edit` “ONE sword only” |
| Thumbnail Explorer antigo | Cache Windows | Abrir no Fotos / arquivo `*_FIXED` |
| `Cannot infer type of "dur"` | Array untyped + `:=` | `Array[float]` + `var dur: float` |
| Keyart loading some | Textura corrompida ou null | ExtResource na cena + PNG válido |
| Android Studio “não abre” da EVA | Job Object / sessão | `schtasks` / atalho Desktop |
| New Project no Studio | Confusão | Cancelar — jogo é Godot |
| Video Imagine 400 ZDR | API sem upload_url | Ken Burns / frames edit |
| Aspect 3:1 422 | Ratio inválido | 16:9 + crop ou PIL |

## Comandos úteis

```powershell
# Magic bytes
# FF D8 = JPEG · 89 50 = PNG

# Abrir projeto
& "...\Godot_v4.7.1-stable_win64.exe" --path "C:\Users\mathe\Documents\Pasqualotti Studios - Demon Slayer - Treinamento hashira" --editor
```
