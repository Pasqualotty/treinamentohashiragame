extends Node
## Estado global leve (progressão, moedas banked, personagem atual).
## Não colocar lógica de combate aqui.

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 1

## Emite o total banked (hub) OU o valor da run dependendo do caller.
## Hub ignora o payload e relê `coins_banked`. HUD de combate usa `run_coins_changed`.
signal coins_changed(total: int)
## Moedas da run atual (fase). Preferir este sinal no combate.
signal run_coins_changed(run_total: int)
signal breath_changed(value: float, max_value: float)

var coins_banked: int = 0
var current_character_id: String = "tanjiro"
var stages_cleared: Array[String] = []
var upgrades: Dictionary = {}  # id -> level

# Áudio (persistido; aplicado pelo autoload Audio)
var audio_volume_master: float = 1.0
var audio_volume_bgm: float = 0.75
var audio_volume_sfx: float = 1.0

# Run / fase atual (não grava até bank)
var coins_run: int = 0
var breath: float = 0.0
var breath_max: float = 100.0


func _ready() -> void:
	load_game()


func add_run_coins(amount: int) -> void:
	coins_run += amount
	run_coins_changed.emit(coins_run)
	# Mantém API legada; hub relê banked no handler e não quebra.
	coins_changed.emit(coins_run)
	if amount > 0 and is_instance_valid(Audio):
		Audio.play_sfx("coin")


func bank_run_coins() -> void:
	coins_banked += coins_run
	coins_run = 0
	run_coins_changed.emit(coins_run)
	coins_changed.emit(coins_banked)
	save_game()


func lose_run_coins() -> void:
	coins_run = 0
	run_coins_changed.emit(coins_run)
	coins_changed.emit(coins_run)


func add_breath_from_hit(amount: float = 10.0) -> void:
	var was_full := breath >= breath_max
	breath = minf(breath + amount, breath_max)
	breath_changed.emit(breath, breath_max)
	if not was_full and breath >= breath_max and is_instance_valid(Audio):
		Audio.play_sfx("breath_full")


func is_ultimate_ready() -> bool:
	return breath >= breath_max


func consume_ultimate() -> void:
	breath = 0.0
	breath_changed.emit(breath, breath_max)
	if is_instance_valid(Audio):
		Audio.play_sfx("ultimate")


func is_stage_cleared(stage_id: String) -> bool:
	return stage_id in stages_cleared


func mark_stage_cleared(stage_id: String) -> void:
	if stage_id not in stages_cleared:
		stages_cleared.append(stage_id)
		save_game()
		if is_instance_valid(Audio):
			Audio.play_sfx("stage_clear")


func save_game() -> void:
	var data := {
		"version": SAVE_VERSION,
		"coins_banked": coins_banked,
		"current_character_id": current_character_id,
		"stages_cleared": stages_cleared,
		"upgrades": upgrades,
		"audio_volume_master": audio_volume_master,
		"audio_volume_bgm": audio_volume_bgm,
		"audio_volume_sfx": audio_volume_sfx,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("Save failed: %s" % FileAccess.get_open_error())
		return
	f.store_string(JSON.stringify(data))


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var data: Dictionary = parsed
	coins_banked = int(data.get("coins_banked", 0))
	current_character_id = str(data.get("current_character_id", "tanjiro"))
	upgrades = data.get("upgrades", {})
	audio_volume_master = clampf(float(data.get("audio_volume_master", 1.0)), 0.0, 1.0)
	audio_volume_bgm = clampf(float(data.get("audio_volume_bgm", 0.75)), 0.0, 1.0)
	audio_volume_sfx = clampf(float(data.get("audio_volume_sfx", 1.0)), 0.0, 1.0)
	var cleared: Array = data.get("stages_cleared", [])
	stages_cleared.clear()
	for s in cleared:
		stages_cleared.append(str(s))
