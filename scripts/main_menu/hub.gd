extends Control
## Hub: showcase animado do personagem (idle + blink), JOGAR → mapa.

@onready var coins_label: Label = %CoinsLabel
@onready var character_name: Label = %CharacterName
@onready var character_art: TextureRect = %CharacterArt

const HUB_IDLE_DIR := "res://assets/characters/player/hub_idle"
## Duração de cada frame (s). Blink fica mais rápido.
const FRAME_DURATIONS := [0.55, 0.45, 0.55, 0.12, 0.14, 0.50]

var _frames: Array[Texture2D] = []
var _frame_i: int = 0
var _timer: float = 0.0


func _ready() -> void:
	_load_idle_frames()
	if _frames.size() > 0:
		character_art.texture = _frames[0]
		character_art.visible = true
	_refresh()
	if not Game.coins_changed.is_connected(_on_coins_changed):
		Game.coins_changed.connect(_on_coins_changed)


func _process(delta: float) -> void:
	if _frames.size() < 2:
		return
	_timer += delta
	var dur := FRAME_DURATIONS[_frame_i % FRAME_DURATIONS.size()]
	if _timer >= dur:
		_timer = 0.0
		_frame_i = (_frame_i + 1) % _frames.size()
		character_art.texture = _frames[_frame_i]


func _load_idle_frames() -> void:
	_frames.clear()
	# 00..05.png
	for i in range(6):
		var path := "%s/%02d.png" % [HUB_IDLE_DIR, i]
		if ResourceLoader.exists(path):
			var tex := load(path) as Texture2D
			if tex:
				_frames.append(tex)
	if _frames.is_empty():
		# Fallback estático
		var fallback := "res://assets/characters/player/tanjiro_hub_idle_00.png"
		if ResourceLoader.exists(fallback):
			_frames.append(load(fallback) as Texture2D)


func _refresh() -> void:
	coins_label.text = "🪙 %d" % Game.coins_banked
	character_name.text = "Tanjiro"


func _on_coins_changed(_total: int) -> void:
	_refresh()


func _on_play_pressed() -> void:
	SceneRouter.to_world_map()


func _on_shop_pressed() -> void:
	pass


func _on_characters_pressed() -> void:
	pass


func _on_settings_pressed() -> void:
	pass
