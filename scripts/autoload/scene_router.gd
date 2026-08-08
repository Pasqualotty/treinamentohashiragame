extends Node
## Troca de cenas centralizada (boot → loading → hub → mapa → fase).
## Toda troca passa por uma cortina de transição (ver scripts/ui/transition.gd)
## — API pública (go_to/to_*) inalterada, a transição acontece por baixo.

const SPLASH := "res://scenes/boot/splash_studio.tscn"
const LOADING := "res://scenes/boot/loading.tscn"
const HUB := "res://scenes/main_menu/hub.tscn"
const WORLD_MAP := "res://scenes/world/world_map.tscn"
const SHOP := "res://scenes/ui/shop.tscn"
const CREDITS := "res://scenes/ui/credits.tscn"
const SETTINGS := "res://scenes/ui/settings.tscn"
const NAME_ENTRY := "res://scenes/ui/name_entry.tscn"

const TransitionScript := preload("res://scripts/ui/transition.gd")

## Intencao de navegacao lida pela tela de nome (mesmo padrao de `Game.pending_stage_id`).
## false = onboarding do primeiro boot; true = renomear a partir do hub (mostra Cancelar).
var name_entry_edit_mode: bool = false

var _transition: CanvasLayer


func _ready() -> void:
	_transition = TransitionScript.new()
	_transition.name = "SceneTransition"
	add_child(_transition)


## Troca de cena com transição suave. Fire-and-forget: chamadores continuam
## chamando `SceneRouter.go_to(path)` sem `await`, como sempre.
func go_to(path: String) -> void:
	if _transition == null or _transition.is_busy():
		# Sem cortina disponível (ou já em transição) — troca direta, nunca trava a navegação.
		var err := get_tree().change_scene_to_file(path)
		if err != OK:
			push_error("SceneRouter: falha ao ir para %s (err=%s)" % [path, err])
		return
	_go_to_with_transition(path)


func _go_to_with_transition(path: String) -> void:
	_transition.set_busy(true)
	await _transition.close()
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("SceneRouter: falha ao ir para %s (err=%s)" % [path, err])
		await _transition.open()
		_transition.set_busy(false)
		return
	await get_tree().process_frame
	await _transition.open()
	_transition.set_busy(false)


func to_splash() -> void:
	go_to(SPLASH)


func to_loading() -> void:
	go_to(LOADING)


func to_hub() -> void:
	go_to(HUB)


func to_world_map() -> void:
	go_to(WORLD_MAP)


func to_shop() -> void:
	go_to(SHOP)


func to_credits() -> void:
	go_to(CREDITS)


func to_settings() -> void:
	go_to(SETTINGS)


## `edit_mode` true quando o jogador ja tem nome e veio do hub para trocar.
func to_name_entry(edit_mode: bool = false) -> void:
	name_entry_edit_mode = edit_mode
	go_to(NAME_ENTRY)
