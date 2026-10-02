class_name BgmRoute
extends RefCounted
## Escolha pura do arquivo de BGM. Sem I/O, sem Autoload.

const BGM_DIR := "res://assets/audio/bgm/"
const HUB_PATH := BGM_DIR + "game_theme.mp3"
const BOSS_PATH := BGM_DIR + "boss_loop.wav"
const STAGE_FALLBACK_PATH := BGM_DIR + "stage_loop.wav"

const WORLD_STAGE := {
	"w1": BGM_DIR + "w1_loop.wav",
	"w2": BGM_DIR + "w2_loop.wav",
	"w3": BGM_DIR + "w3_loop.wav",
	"w4": BGM_DIR + "w4_loop.wav",
	"w5": BGM_DIR + "w5_loop.wav",
}


static func resolve(kind: String, world_id: String) -> String:
	var k := kind.strip_edges().to_lower()
	if k == "hub":
		return HUB_PATH
	if k == "boss":
		return BOSS_PATH
	if k == "stage":
		var wid := world_id.strip_edges().to_lower()
		if WORLD_STAGE.has(wid):
			return str(WORLD_STAGE[wid])
		return STAGE_FALLBACK_PATH
	return HUB_PATH
