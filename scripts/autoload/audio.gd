extends Node
## Autoload de áudio: SFX pool com variação + BGM com crossfade + ducking.
## Graceful se arquivo/bus faltar — nunca quebra a cena.

const SFX_DIR := "res://assets/audio/sfx/"
const BGM_DIR := "res://assets/audio/bgm/"
const POOL_SIZE := 8

## Teto de vozes concorrentes por nome de SFX (evita 1 som saturar o pool inteiro).
const MAX_CONCURRENT_PER_SFX := 4

## Micro-variação por disparo pra evitar repetição robótica.
const PITCH_JITTER := 0.035
const VOLUME_JITTER_DB := 1.2

## BGM: tempo de crossfade padrão (fade-out do atual + fade-in do novo, em paralelo).
const BGM_FADE_TIME := 1.0
const BGM_MIN_FADE_TIME := 0.05

## Camadas leves: nome do SFX -> layer sintética tocada junto (mesmo asset, pitch/volume
## diferentes) pra dar sensação de "impacto + sub" sem precisar de asset novo.
const LAYER_DEFS := {
	"hit": {"pitch": 0.55, "volume_db": -9.0},
	"ultimate": {"pitch": 0.5, "volume_db": -6.0},
}

## Ducking automático: SFX forte que abaixa a BGM brevemente e volta.
const DUCK_ON_SFX := {
	"ultimate": {"amount": 7.0, "attack": 0.05, "hold": 0.05, "release": 0.6},
	"stage_clear": {"amount": 8.0, "attack": 0.08, "hold": 0.15, "release": 0.9},
}

## Nome lógico → arquivo (sem extensão; tenta .ogg depois .wav).
const SFX_FILES := {
	"ui_click": "ui_click",
	"slash": "slash",
	"hit": "hit",
	"hurt": "hurt",
	"coin": "coin",
	"breath_full": "breath_full",
	"ultimate": "ultimate",
	"stage_clear": "stage_clear",
	"brand_sting": "brand_sting",
}

const BGM_FILES := {
	"hub": "hub_loop",
	"stage": "stage_loop",
	"boss": "boss_loop",
}

var volume_master: float = 1.0
var volume_bgm: float = 0.75
var volume_sfx: float = 1.0

var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_i: int = 0
var _sfx_cache: Dictionary = {}  # path -> AudioStream
var _buses_ok: bool = false

## Dois players de BGM alternados pra permitir crossfade real (fade-out do antigo
## sobrepondo o fade-in do novo, sem corte seco).
var _bgm_players: Array[AudioStreamPlayer] = []
var _bgm_tweens: Array = [null, null]
var _bgm_active: int = 0
var _current_bgm: String = ""

var _duck_tween: Tween
var _duck_base_db: Variant = null


func _ready() -> void:
	_ensure_buses()

	for i in 2:
		var b := AudioStreamPlayer.new()
		b.name = "BgmPlayer_%d" % i
		b.bus = "BGM" if _bus_exists("BGM") else "Master"
		b.volume_db = -80.0
		add_child(b)
		_bgm_players.append(b)

	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.name = "SfxPlayer_%d" % i
		p.bus = "SFX" if _bus_exists("SFX") else "Master"
		add_child(p)
		_sfx_pool.append(p)

	# Volumes do save (Game carrega antes se autoload order ok).
	if is_instance_valid(Game):
		apply_volumes(
			float(Game.audio_volume_master),
			float(Game.audio_volume_bgm),
			float(Game.audio_volume_sfx),
			false
		)


func _ensure_buses() -> void:
	## Layout do project.godot costuma criar BGM/SFX; se faltar, cria em runtime.
	_buses_ok = true
	if not _bus_exists("BGM"):
		var idx := AudioServer.bus_count
		AudioServer.add_bus()
		AudioServer.set_bus_name(idx, "BGM")
		AudioServer.set_bus_send(idx, "Master")
	if not _bus_exists("SFX"):
		var idx2 := AudioServer.bus_count
		AudioServer.add_bus()
		AudioServer.set_bus_name(idx2, "SFX")
		AudioServer.set_bus_send(idx2, "Master")


func _bus_exists(bus_name: String) -> bool:
	return AudioServer.get_bus_index(bus_name) >= 0


func play_sfx(sfx_name: String, pitch_scale: float = 1.0, volume_linear: float = 1.0) -> void:
	var stream := _load_sfx(sfx_name)
	if stream == null:
		return
	if _concurrent_voices(sfx_name) >= MAX_CONCURRENT_PER_SFX:
		return

	var jitter_pitch: float = pitch_scale * randf_range(1.0 - PITCH_JITTER, 1.0 + PITCH_JITTER)
	var jitter_db: float = randf_range(-VOLUME_JITTER_DB, VOLUME_JITTER_DB)
	var base_db: float = -80.0 if volume_linear <= 0.0001 else linear_to_db(clampf(volume_linear, 0.0001, 2.0))
	_play_pooled(stream, sfx_name, jitter_pitch, base_db + jitter_db)

	if sfx_name in LAYER_DEFS:
		var layer: Dictionary = LAYER_DEFS[sfx_name]
		var layer_pitch: float = float(layer.get("pitch", 0.6)) * randf_range(0.97, 1.03)
		_play_pooled(stream, sfx_name + "_layer", layer_pitch, float(layer.get("volume_db", -8.0)))

	if sfx_name in DUCK_ON_SFX:
		var d: Dictionary = DUCK_ON_SFX[sfx_name]
		duck(
			float(d.get("amount", 6.0)),
			float(d.get("attack", 0.06)),
			float(d.get("hold", 0.05)),
			float(d.get("release", 0.5))
		)


func _concurrent_voices(tag: String) -> int:
	var count := 0
	for p in _sfx_pool:
		if p.playing and str(p.get_meta("sfx_tag", "")) == tag:
			count += 1
	return count


func _play_pooled(stream: AudioStream, tag: String, pitch_scale: float, volume_db: float) -> void:
	if _sfx_pool.is_empty():
		return
	var p: AudioStreamPlayer = _sfx_pool[_sfx_i]
	_sfx_i = (_sfx_i + 1) % _sfx_pool.size()
	p.stream = stream
	p.pitch_scale = clampf(pitch_scale, 0.4, 2.5)
	p.volume_db = clampf(volume_db, -80.0, 6.0)
	p.set_meta("sfx_tag", tag)
	p.play()


func play_bgm(bgm_name: String, from_start: bool = false, fade_time: float = BGM_FADE_TIME) -> void:
	var key := bgm_name
	if key in BGM_FILES:
		key = BGM_FILES[key]

	var current: AudioStreamPlayer = _bgm_players[_bgm_active]
	if _current_bgm == key and current.playing and not from_start:
		return

	var stream := _load_stream(BGM_DIR, key)
	if stream == null:
		return
	stream = _as_looping(stream)

	var was_playing: bool = current.playing and _current_bgm != ""
	var incoming_idx: int = (_bgm_active + 1) % _bgm_players.size() if was_playing else _bgm_active
	var outgoing_idx: int = _bgm_active if incoming_idx != _bgm_active else -1

	var fade: float = maxf(BGM_MIN_FADE_TIME, fade_time)

	var incoming: AudioStreamPlayer = _bgm_players[incoming_idx]
	_kill_bgm_tween(incoming_idx)
	incoming.stream = stream
	incoming.volume_db = -80.0
	incoming.play()
	var t_in := create_tween()
	t_in.tween_property(incoming, "volume_db", 0.0, fade)
	_bgm_tweens[incoming_idx] = t_in

	if outgoing_idx >= 0:
		var outgoing: AudioStreamPlayer = _bgm_players[outgoing_idx]
		_kill_bgm_tween(outgoing_idx)
		var t_out := create_tween()
		t_out.tween_property(outgoing, "volume_db", -80.0, fade)
		t_out.tween_callback(outgoing.stop)
		_bgm_tweens[outgoing_idx] = t_out

	_bgm_active = incoming_idx
	_current_bgm = key


func _as_looping(stream: AudioStream) -> AudioStream:
	## Duplica e marca loop (nao muta o .import cache).
	if stream is AudioStreamWAV:
		var wav := (stream as AudioStreamWAV).duplicate() as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		# Godot 4.x: AudioStreamWAV nao tem get_channel_count(); stereo=bool.
		var channels: int = 2 if wav.stereo else 1
		var bytes_per_sample: int = 2  # 16-bit PCM tipico do import
		if wav.format == AudioStreamWAV.FORMAT_8_BITS:
			bytes_per_sample = 1
		elif wav.format == AudioStreamWAV.FORMAT_IMA_ADPCM:
			bytes_per_sample = 1
		var frames: int = 0
		if wav.data.size() > 0 and channels > 0:
			frames = int(wav.data.size() / float(bytes_per_sample * channels))
		wav.loop_end = maxi(1, frames)
		return wav
	if stream is AudioStreamOggVorbis:
		var ogg := (stream as AudioStreamOggVorbis).duplicate() as AudioStreamOggVorbis
		ogg.loop = true
		return ogg
	return stream


func stop_bgm(fade_time: float = 0.5) -> void:
	var fade: float = maxf(BGM_MIN_FADE_TIME, fade_time)
	for i in _bgm_players.size():
		var p: AudioStreamPlayer = _bgm_players[i]
		if p.playing:
			_kill_bgm_tween(i)
			var t := create_tween()
			t.tween_property(p, "volume_db", -80.0, fade)
			t.tween_callback(p.stop)
			_bgm_tweens[i] = t
	_current_bgm = ""


func _kill_bgm_tween(idx: int) -> void:
	var t = _bgm_tweens[idx]
	if t and (t as Tween).is_valid():
		(t as Tween).kill()
	_bgm_tweens[idx] = null


## Abaixa a BGM temporariamente e volta ao volume base (tween no bus BGM).
## Uso automático em SFX fortes (ver DUCK_ON_SFX) e disponível pra chamada manual
## em momentos de impacto (ex.: hit de boss, camera shake).
func duck(amount_db: float = 6.0, attack: float = 0.06, hold: float = 0.05, release: float = 0.4) -> void:
	var idx := AudioServer.get_bus_index("BGM")
	if idx < 0:
		return
	if _duck_tween and _duck_tween.is_valid():
		_duck_tween.kill()

	var base_db: float = AudioServer.get_bus_volume_db(idx)
	if _duck_base_db != null:
		base_db = float(_duck_base_db)
	_duck_base_db = base_db

	_duck_tween = create_tween()
	_duck_tween.tween_method(_set_bgm_bus_db, base_db, base_db - amount_db, maxf(0.01, attack))
	_duck_tween.tween_interval(maxf(0.0, hold))
	_duck_tween.tween_method(_set_bgm_bus_db, base_db - amount_db, base_db, maxf(0.01, release))
	_duck_tween.tween_callback(_on_duck_finished)


func _on_duck_finished() -> void:
	_duck_base_db = null


func _set_bgm_bus_db(db: float) -> void:
	var idx := AudioServer.get_bus_index("BGM")
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, db)


func set_volume_master(linear: float, persist: bool = true) -> void:
	volume_master = clampf(linear, 0.0, 1.0)
	_apply_bus_volume("Master", volume_master)
	if persist:
		_persist_volumes()


func set_volume_bgm(linear: float, persist: bool = true) -> void:
	volume_bgm = clampf(linear, 0.0, 1.0)
	_apply_bus_volume("BGM", volume_bgm)
	if persist:
		_persist_volumes()


func set_volume_sfx(linear: float, persist: bool = true) -> void:
	volume_sfx = clampf(linear, 0.0, 1.0)
	_apply_bus_volume("SFX", volume_sfx)
	if persist:
		_persist_volumes()


func apply_volumes(master: float, bgm: float, sfx: float, persist: bool = false) -> void:
	volume_master = clampf(master, 0.0, 1.0)
	volume_bgm = clampf(bgm, 0.0, 1.0)
	volume_sfx = clampf(sfx, 0.0, 1.0)
	_apply_bus_volume("Master", volume_master)
	_apply_bus_volume("BGM", volume_bgm)
	_apply_bus_volume("SFX", volume_sfx)
	if persist:
		_persist_volumes()


func _apply_bus_volume(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	# 0 linear = -80 dB (quase mudo), 1 = 0 dB
	var db: float = -80.0 if linear <= 0.0001 else linear_to_db(linear)
	AudioServer.set_bus_volume_db(idx, db)


func _persist_volumes() -> void:
	if not is_instance_valid(Game):
		return
	Game.audio_volume_master = volume_master
	Game.audio_volume_bgm = volume_bgm
	Game.audio_volume_sfx = volume_sfx
	Game.save_game()


func _load_sfx(sfx_name: String) -> AudioStream:
	var file_id: String = str(SFX_FILES.get(sfx_name, sfx_name))
	return _load_stream(SFX_DIR, file_id)


func _load_stream(dir: String, file_id: String) -> AudioStream:
	var exts: Array[String] = [".ogg", ".wav", ".mp3"]
	for ext: String in exts:
		var path: String = dir + file_id + ext
		if _sfx_cache.has(path):
			return _sfx_cache[path] as AudioStream
		if ResourceLoader.exists(path):
			var stream: AudioStream = load(path) as AudioStream
			if stream:
				_sfx_cache[path] = stream
				return stream
	return null
