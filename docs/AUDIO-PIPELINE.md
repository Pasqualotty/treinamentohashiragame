# Pipeline de áudio — Treinamento Hashira

## Status MVP (frente audio-mvp)

Áudio **mínimo jogável** está ligado:

| Camada | Estado |
|--------|--------|
| Buses Master / BGM / SFX | `resources/default_bus_layout.tres` + `project.godot` |
| Autoload `Audio` | `scripts/autoload/audio.gd` |
| Volumes no save | `Game.audio_volume_*` → `user://save.json` |
| SFX placeholders | `assets/audio/sfx/*.wav` (procedural, original) |
| BGM hub | `assets/audio/bgm/game_theme.mp3` — loop via `_as_looping` |
| BGM stage por mundo | `w1_loop.wav` … `w5_loop.wav` via `BgmRoute` + `Game.current_world_id` |
| BGM boss | `assets/audio/bgm/boss_loop.wav` (nunca `game_theme`) |
| Hooks | splash sting, hub BGM + UI click, mapa UI click, stage/boss BGM, slash/hit, coin/breath_full/ultimate/stage_clear |

**Licença:** só original/procedural/CC0 — **nunca** OST Demon Slayer rip.

---

## API (`Audio` autoload)

```gdscript
Audio.play_sfx("ui_click")          # silent no-op se arquivo faltar
Audio.play_sfx("slash", 1.05)       # pitch opcional
Audio.play_bgm("hub")               # game_theme.mp3 (menu)
Audio.play_bgm("stage", true)       # w1..w5_loop.wav conforme Game.current_world_id
Audio.play_bgm("boss")              # boss_loop.wav (nunca game_theme)
Audio.stop_bgm()
Audio.set_volume_master(0.8)        # linear 0..1, persiste no save
Audio.set_volume_bgm(0.6)
Audio.set_volume_sfx(1.0)
```

Rota (`scripts/audio/bgm_route.gd`, `class_name BgmRoute`):

| kind | world | arquivo |
|------|-------|---------|
| `hub` | (ignorado) | `res://assets/audio/bgm/game_theme.mp3` |
| `boss` | (ignorado) | `res://assets/audio/bgm/boss_loop.wav` |
| `stage` | `w1`…`w5` | `res://assets/audio/bgm/wN_loop.wav` |
| `stage` | desconhecido | `res://assets/audio/bgm/stage_loop.wav` |

`Audio.play_bgm` só escolhe o path via `BgmRoute.resolve`. No `stage`, lê `Game.current_world_id` se o autoload existir. Hub, cada mundo e boss são caminhos distintos.

IDs SFX: `ui_click`, `slash`, `hit`, `hurt`, `coin`, `breath_full`, `ultimate`, `stage_clear`, `brand_sting`.

Graceful: se bus/arquivo faltar, não quebra cena (pool + `ResourceLoader.exists`).

---

## Arquivos no repo

```
assets/audio/
  sfx/
    ui_click.wav
    slash.wav
    hit.wav
    hurt.wav
    coin.wav
    breath_full.wav
    ultimate.wav
    stage_clear.wav
    brand_sting.wav
  bgm/
    game_theme.mp3     # hub / menu
    hub_loop.wav       # placeholder extra (não é a rota de hub)
    stage_loop.wav     # fallback se o mundo não for w1..w5
    w1_loop.wav        # Montanha
    w2_loop.wav        # Trem
    w3_loop.wav        # Distrito
    w4_loop.wav        # Castelo
    w5_loop.wav        # Céu Vermelho
    boss_loop.wav      # boss (nunca game_theme)
resources/default_bus_layout.tres   # Master → BGM, SFX
scripts/audio/bgm_route.gd
scripts/autoload/audio.gd
scripts/tools/generate_audio_placeholders.py
scripts/qa/smoke_bgm_routes.gd
```

Regenerar placeholders:

```powershell
python scripts/tools/generate_audio_placeholders.py
```

Depois abra o Godot uma vez para reimportar (gera `.import`).

---

## Onde toca no jogo

| Evento | Onde |
|--------|------|
| Brand sting | `splash_studio.gd` |
| BGM hub | `hub.gd` `_ready` |
| UI click hub/mapa | `hub.gd`, `world_map.gd` |
| BGM fase/sandbox | `stage_controller.gd` (`stage`), `sandbox_combat.gd` |
| BGM boss | `stage_controller.gd` quando `stage_id` contém `boss` |
| Slash / hit / hurt / ultimate | `player.gd` / `player_combat.gd` |
| Coin | `coin_pickup.gd` |
| Breath full | `game.gd` `add_breath_from_hit` (borda full) |
| Stage clear | `stage_controller.gd` |

---

## Posso gerar som daqui (Grok Build)?

| Tipo | Nesta sessão? | Ferramenta recomendada |
|------|---------------|------------------------|
| **SFX placeholder** | ✅ script procedural Python | `generate_audio_placeholders.py` |
| **SFX polido** | ❌ sem gerador AI embutido | **ElevenLabs Sound Effects** |
| **Música / BGM loop** | ✅ tom/ambiente procedural curto | Suno / Udio / ElevenLabs Music p/ polir |
| **Jingle marca** | ✅ `brand_sting` placeholder | Gravado ou Suno “logo sting” |
| **Import Godot** | ✅ | `.wav` ok; `.ogg` preferido no mobile |

O Imagine (imagem/vídeo) **não gera áudio**.

### Prompts ElevenLabs (upgrade futuro)

| ID | Prompt sugerido |
|----|-----------------|
| `coin` | `short cheerful coin collect chime for mobile game` |
| `slash` | `fast sword slash whoosh anime style short` |
| `hit` | `blade impact light hit on enemy short` |
| `hurt` | `player take damage thud short` |
| `ui_click` | `soft ui button click` |
| `breath_full` | `magical energy charge complete chime` |
| `ultimate` | `powerful sword special attack whoosh` |
| `brand_sting` | `short cinematic logo sting japanese drums one second` |

BGM Suno/Udio (sempre instrumental, sem vocal, sem tema comercial):

- Hub: `dark night japanese bamboo forest ambient loop, soft taiko, no vocals, 90bpm`
- Fase: `energetic anime action instrumental loop, shakuhachi hints, no vocals`

**Sempre** checar loop no Audacity e licença dos termos da ferramenta.

### Grátis sem AI

- [Kenney.nl](https://kenney.nl/assets) — UI/SFX packs  
- [Freesound](https://freesound.org) — CC0 / CC-BY (créditos)

---

## Godot

1. Buses: `resources/default_bus_layout.tres` (Master / BGM / SFX)  
2. Autoload `Audio` em `project.godot` (depois de `Game`)  
3. Formato: WAV placeholders agora; migrar para **OGG Vorbis** quando tiver assets finais  
4. Runtime: se layout faltar, `Audio._ensure_buses()` cria BGM/SFX em memória  

---

## O que a EVA / worker faz

| Feito no MVP | Ainda humano / futuro |
|--------------|------------------------|
| Pastas, buses, `Audio.play_*` | Conta ElevenLabs/Suno se quiser polish |
| Placeholders procedurais originais | Aprovar jingle final da marca |
| Hooks splash/hub/sandbox/combate | Trocar WAV por OGG polido drop-in (mesmo nome base) |

Trocar arquivo em `assets/audio/sfx|bgm/` com o **mesmo nome base** (`.ogg` preferido) — o autoload tenta `.ogg` antes de `.wav`.
