extends Node
## Autoload de áudio leve: SFX one-shot + BGM loop.
## Graceful se arquivo/bus faltar — nunca quebra a cena.

const SFX_DIR := "res://assets/audio/sfx/"
const BGM_DIR := "res://assets/audio/bgm/"
const POOL_SIZE := 8

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
}

var volume_master: float = 1.0
var volume_bgm: float = 0.75
var volume_sfx: float = 1.0

var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_i: int = 0
var _bgm_player: AudioStreamPlayer
var _current_bgm: String = ""
var _sfx_cache: Dictionary = {}  # path -> AudioStream
var _buses_ok: bool = false


func _ready() -> void:
	_ensure_buses()
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.name = "BgmPlayer"
	_bgm_player.bus = "BGM" if _bus_exists("BGM") else "Master"
	add_child(_bgm_player)

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
	if _sfx_pool.is_empty():
		return
	var p: AudioStreamPlayer = _sfx_pool[_sfx_i]
	_sfx_i = (_sfx_i + 1) % _sfx_pool.size()
	p.stream = stream
	p.pitch_scale = clampf(pitch_scale, 0.5, 2.0)
	p.volume_db = linear_to_db(clampf(volume_linear, 0.0, 2.0))
	p.play()


func play_bgm(bgm_name: String, from_start: bool = false) -> void:
	var key := bgm_name
	if key in BGM_FILES:
		key = BGM_FILES[key]
	if _current_bgm == key and _bgm_player.playing and not from_start:
		return
	var stream := _load_stream(BGM_DIR, key)
	if stream == null:
		return
	stream = _as_looping(stream)
	_bgm_player.stream = stream
	_bgm_player.volume_db = 0.0
	_bgm_player.play()
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


func stop_bgm() -> void:
	if _bgm_player:
		_bgm_player.stop()
	_current_bgm = ""


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
