# Pipeline de áudio — Treinamento Hashira

## Posso gerar som daqui (Grok Build)?

| Tipo | Nesta sessão EVA? | Ferramenta recomendada |
|------|-------------------|------------------------|
| **SFX** (moeda, slash, hit, UI click) | ❌ sem gerador de áudio embutido | **ElevenLabs Sound Effects** (texto → SFX) |
| **Música / BGM loop** | ❌ | **Suno** / **Udio** / **ElevenLabs Music** / **Stable Audio** |
| **Jingle da marca Pasqualotti** | ❌ | Gravado por vocês **ou** Suno/Eleven com prompt “logo sting” |
| **Import no Godot** | ✅ | `.ogg` preferido; pasta `assets/audio/` |

O Imagine (imagem/vídeo) **não gera áudio**.

---

## Stack recomendada (fan project, sideload)

### 1) Efeitos curtos (prioridade)

**[ElevenLabs → Sound Effects](https://elevenlabs.io/sound-effects)**  
- Prompt em inglês/português curto: `soft gold coin pickup chime game ui`  
- Export WAV/MP3 → converter OGG se quiser  
- Bom para: coin, slash, hurt, breath full, button click  

Lista mínima MVP:

| ID | Prompt sugerido |
|----|-----------------|
| `sfx_coin` | `short cheerful coin collect chime for mobile game` |
| `sfx_slash_light` | `fast sword slash whoosh anime style short` |
| `sfx_hit` | `blade impact light hit on enemy short` |
| `sfx_hurt` | `player take damage thud short` |
| `sfx_ui_click` | `soft ui button click` |
| `sfx_breath_full` | `magical energy charge complete chime` |
| `sfx_special` | `powerful sword special attack whoosh` |
| `sfx_brand_sting` | `short cinematic logo sting japanese drums one second` |

### 2) Música de fundo

| Uso | Ferramenta |
|-----|------------|
| BGM fase / menu | **Suno** ou **Udio** (loops instrumentais) |
| Alternativa local | **Stable Audio** (se tiver GPU/conta) |
| Licença “mais segura” p/ produto | **ElevenLabs Music** (avaliar termos) |

Prompts exemplo:

- Menu: `dark night japanese bamboo forest ambient loop, soft taiko, no vocals, 90bpm`  
- Fase: `energetic anime action instrumental loop, shakuhachi hints, no vocals`  
- Boss: `intense demonic battle drums loop, dark, no vocals`  

**Sempre** baixar instrumental e checar se o loop fecha (Audacity: cortar no beat).

### 3) Grátis sem AI (placeholders)

- [Kenney.nl](https://kenney.nl/assets) — UI/SFX packs  
- [Freesound](https://freesound.org) — CC0 / CC-BY (créditos)  

---

## Estrutura no projeto

```
assets/audio/
  sfx/
    coin.ogg
    slash_light.ogg
    ...
  bgm/
    menu_loop.ogg
    stage_w1_loop.ogg
  bus: Master / BGM / SFX  (Godot Audio bus layout)
```

### Godot

1. **Project → Audio → Buses:** Master, BGM, SFX  
2. Autoload `Audio` (futuro): `play_sfx(id)`, volume no save  
3. Formato: **OGG Vorbis** preferido no mobile  

---

## O que a EVA faz / não faz

| EVA faz | Você (ou ferramenta externa) |
|---------|------------------------------|
| Pastas, buses, código `Audio.play` | Conta ElevenLabs/Suno se precisar |
| Integrar arquivos que você dropar em `assets/audio/` | Gerar/baixar WAV/MP3/OGG |
| Checklist de quais SFX faltam | Aprovar jingle da marca |

Quando tiver os arquivos na pasta, pede: **“liga os áudios no hub/combate”**.

---

## Ordem prática

1. SFX coin + slash + ui_click (ElevenLabs free tier)  
2. 1 BGM menu loop  
3. Jingle Pasqualotti (splash)  
4. Resto do checklist de combate  
