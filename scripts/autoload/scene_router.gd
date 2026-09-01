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
const CHARACTER_SELECT := "res://scenes/ui/character_select.tscn"

const TransitionScript := preload("res://scripts/ui/transition.gd")

## Emitido quando um pedido de navegacao NAO se concretizou (cena inexistente,
## erro de carregamento). Quem armou guarda de "ja estou navegando" escuta isto
## para destravar: sem o aviso a tela continua viva na arvore com a guarda presa
## e o jogador fica sem saida — nem confirmar, nem cancelar.
signal navigation_failed(path: String)

## Intencao de navegacao lida pela tela de nome (mesmo padrao de `Game.pending_stage_id`).
## false = onboarding do primeiro boot; true = renomear a partir do hub (mostra Cancelar).
var name_entry_edit_mode: bool = false

var _transition: CanvasLayer
## Trava de reentrancia no proprio roteador — e aqui que o bug original morava:
## um segundo pedido durante o fade caia no ramo `is_busy()` e trocava de cena na
## marra por cima da transicao. Agora o segundo pedido e recusado na porta.
var _navigating: bool = false


func _ready() -> void:
	_transition = TransitionScript.new()
	_transition.name = "SceneTransition"
	add_child(_transition)


## true enquanto um pedido de `go_to` ainda não pousou numa cena nova.
func is_navigating() -> bool:
	return _navigating


## Troca de cena com transição suave. Fire-and-forget: chamadores continuam
## chamando `SceneRouter.go_to(path)` sem `await`, como sempre.
## Retorna false quando o pedido é RECUSADO na hora (já há navegação no ar).
## Falha assíncrona (cena inválida) chega depois por `navigation_failed`.
func go_to(path: String) -> bool:
	if _navigating:
		return false
	_navigating = true
	if _transition == null or _transition.is_busy():
		# Sem cortina disponível — troca direta, nunca trava a navegação.
		_go_direct(path)
	else:
		_go_to_with_transition(path)
	return true


func _go_direct(path: String) -> void:
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		_fail_navigation(path, err)
		return
	# A troca só acontece no fim do frame: segurar a trava até lá faz o segundo
	# Enter do mesmo frame ser recusado (é o caso do headless, sem cortina).
	await get_tree().process_frame
	_navigating = false


func _go_to_with_transition(path: String) -> void:
	_transition.set_busy(true)
	await _transition.close()
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		await _transition.open()
		_transition.set_busy(false)
		_fail_navigation(path, err)
		return
	# Solta a trava aqui, e não depois do `open()`, porque a janela de perigo
	# fecha na troca — não no fim do fade. O que a trava protege é o intervalo em
	# que a cena ANTIGA ainda está viva e ainda gera input (dois Enter, duplo
	# toque): commitada a troca, ela já foi para deleção e não pede mais nada.
	# Segurar durante os ~0.26s do `open()` não somaria segurança e bloquearia
	# navegação legítima da cena nova — quem toca um botão do hub enquanto a
	# cortina ainda abre está fazendo algo suportado.
	#
	# CUIDADO: isto NÃO habilita navegar de dentro do `_ready`/`ENTER_TREE` da
	# cena que está entrando. `change_scene_to_file` reentrante nesse ponto
	# CRASHA a engine (signal 11) no Godot 4.7.1 — limite do próprio Godot,
	# reproduzível sem o SceneRouter no meio. Nenhuma cena de produção faz isso.
	# Se precisar navegar logo ao subir, adie: `call_deferred` ou
	# `await get_tree().process_frame` antes de chamar `go_to`.
	_navigating = false
	await get_tree().process_frame
	await _transition.open()
	_transition.set_busy(false)


## Destrava e avisa quem pediu, nesta ordem: o handler do sinal pode querer
## disparar outra navegação imediatamente.
func _fail_navigation(path: String, err: int) -> void:
	_navigating = false
	push_error("SceneRouter: falha ao ir para %s (err=%s)" % [path, err])
	navigation_failed.emit(path)


## Os helpers `to_*` repassam o retorno de `go_to`: false = pedido recusado.
## Chamador que não se importa continua ignorando o valor, como sempre.

func to_splash() -> bool:
	return go_to(SPLASH)


func to_loading() -> bool:
	return go_to(LOADING)


func to_hub() -> bool:
	return go_to(HUB)


func to_world_map() -> bool:
	return go_to(WORLD_MAP)


func to_shop() -> bool:
	return go_to(SHOP)


func to_credits() -> bool:
	return go_to(CREDITS)


func to_settings() -> bool:
	return go_to(SETTINGS)


## `edit_mode` true quando o jogador ja tem nome e veio do hub para trocar.
func to_name_entry(edit_mode: bool = false) -> bool:
	name_entry_edit_mode = edit_mode
	return go_to(NAME_ENTRY)


func to_characters() -> bool:
	return go_to(CHARACTER_SELECT)
