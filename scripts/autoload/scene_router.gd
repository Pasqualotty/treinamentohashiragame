extends Node
## Troca de cenas centralizada (boot → loading → hub → mapa → fase).

const SPLASH := "res://scenes/boot/splash_studio.tscn"
const LOADING := "res://scenes/boot/loading.tscn"
const HUB := "res://scenes/main_menu/hub.tscn"
const WORLD_MAP := "res://scenes/world/world_map.tscn"


func go_to(path: String) -> void:
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("SceneRouter: falha ao ir para %s (err=%s)" % [path, err])


func to_splash() -> void:
	go_to(SPLASH)


func to_loading() -> void:
	go_to(LOADING)


func to_hub() -> void:
	go_to(HUB)


func to_world_map() -> void:
	go_to(WORLD_MAP)
