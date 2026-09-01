# Changelog — Treinamento Hashira

## Unreleased — mundos W2–W5

- Mapa com seletor de 5 mundos; cadeado até o boss anterior
- Fases + boss: `w2_01`…`w2_boss`, `w3_*`, `w4_*`, `w5_01`…`w5_boss`
- Ondas dos mundos novos no `StageDef.waves` (kind `boss` no pack final)
- W1 ids intactos

## Unreleased — auto-update sideload

- No hub, se existe versão nova, o sobrinho vê um aviso e pode baixar/instalar sem APK na mão
- Publicação: GitHub Releases (`latest.json` + APK) — `docs/AUTO-UPDATE.md`

## 0.1.0 — MVP Mundo 1 (2026-08-06)

### Jogavel
- Boot: splash Pasqualotti → loading → hub
- Hub com Tanjiro animado, LOJA, JOGAR, creditos (engrenagem)
- Mapa Mundo 1 visual (nos Fase 1–3 + Boss)
- Fases 1–3 + boss com combate side-scroller
- Tanjiro: move, pulo, dash, atk, 2 skills, ultimate, breath
- Oni fraco + elite, moedas no chao, HUD, touch
- Pause (Continuar / Mapa / Hub)
- Loja 4 upgrades + save persistente
- APK debug: `export/TreinamentoHashira-debug.apk`

### Tecnico
- Godot 4.7 Mobile + gl_compatibility no Android
- Package: `studio.pasqualotti.hashira`

### Fora desta versao
- Personagens extras, mundos 2+, release assinado, polish AAA
