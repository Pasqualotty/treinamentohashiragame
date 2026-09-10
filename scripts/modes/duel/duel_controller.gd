extends Node2D
## Duelo 1v1 de frente: um round, dois corpos, vencedor em PT.
## Porta própria — não passa pelo JOGAR / mapa. Sem net nesta fatia:
## o 2º lutador é dummy local (puppet de input).
##
## Facing canônico (GDD): arte de combate olha ESQUERDA.
## `flip_h` só quando `_facing > 0`. Não inverter. Não flipar PNG.

const COMBAT_HUD_SCENE := preload("res://scenes/ui/combat_hud.tscn")
const TOUCH_SCENE := preload("res://scenes/ui/combat_touch_controls.tscn")

const TEAM_LEFT := &"duel_left"
const TEAM_RIGHT := &"duel_right"
const CHAR_LEFT := "inosuke"
const CHAR_RIGHT := "nezuko"

const FACE_RIGHT := 1.0
const FACE_LEFT := -1.0

const INTRO_SEC := 1.55
const DUMMY_REACH := 108.0
const DUMMY_ATK_CD := 0.9

const TEXT_ROUND := "ROUND 1"
const TEXT_WIN := "Você ganhou"
const TEXT_LOSE := "Você perdeu"

enum Phase { INTRO, FIGHT, RESULT }

@onready var _left: Node = %FighterLeft
@onready var _right: Node = %FighterRight
@onready var _round_label: Label = %RoundLabel
@onready var _result_root: Control = %ResultRoot
@onready var _result_label: Label = %ResultLabel
@onready var _voltar: Button = %VoltarButton
@onready var _camera: Camera2D = %Camera2D

var _phase: Phase = Phase.INTRO
var _dummy_frozen: bool = true
var _dummy_atk_cd: float = 0.0
var _settled: bool = false
var _intro_left: float = INTRO_SEC


func _ready() -> void:
	if _camera:
		_camera.make_current()
	_result_root.visible = false
	_round_label.text = TEXT_ROUND
	_round_label.visible = true
	_voltar.pressed.connect(_on_voltar)
	_prepare_fighter(_left, CHAR_LEFT, true, TEAM_LEFT, FACE_RIGHT)
	_prepare_fighter(_right, CHAR_RIGHT, false, TEAM_RIGHT, FACE_LEFT)
	_set_locked(true)
	_spawn_hud_and_touch()
	if is_instance_valid(Audio) and Audio.has_method("play_bgm"):
		Audio.play_bgm("stage")


func _process(delta: float) -> void:
	if _phase == Phase.INTRO:
		_intro_left -= delta
		if _intro_left <= 0.0:
			_begin_fight()
		return
	if _phase != Phase.FIGHT:
		return
	_dummy_atk_cd = maxf(0.0, _dummy_atk_cd - delta)
	_tick_dummy()


func get_phase() -> Phase:
	return _phase


func get_banner_text() -> String:
	return _round_label.text if _round_label else ""


func get_result_text() -> String:
	return _result_label.text if _result_label else ""


func get_left_fighter() -> Node:
	return _left


func get_right_fighter() -> Node:
	return _right


func _prepare_fighter(fighter: Node, char_id: String, local_pawn: bool, team: StringName, facing: float) -> void:
	if fighter == null:
		return
	fighter.set("skip_local_upgrades", true)
	fighter.set("is_local_pawn", local_pawn)
	fighter.set("accept_local_input", local_pawn)
	fighter.set("coop_slot", 0 if local_pawn else 1)
	if fighter.has_method("reload_character_kit"):
		fighter.call("reload_character_kit", char_id)
	if fighter.has_method("heal_full"):
		fighter.call("heal_full")
	_assign_team(fighter, team)
	_lock_facing(fighter, facing)
	if fighter.has_signal("died"):
		fighter.connect("died", _on_fighter_died.bind(local_pawn))


func _assign_team(fighter: Node, team: StringName) -> void:
	var hit: Node = fighter.get_node_or_null("Hitbox")
	var hurt: Node = fighter.get_node_or_null("Hurtbox")
	if hit:
		hit.set("team", team)
	if hurt:
		hurt.set("team", team)


func _lock_facing(fighter: Node, dir: float) -> void:
	if fighter == null or not fighter.has_method("apply_host_snap"):
		return
	var body := fighter as Node2D
	if body == null:
		return
	var hp_now: int = int(fighter.call("get_hp")) if fighter.has_method("get_hp") else 100
	var breath: float = float(fighter.get("pawn_breath"))
	var breath_m: float = float(fighter.get("pawn_breath_max"))
	if breath_m <= 0.0:
		breath_m = 100.0
	fighter.call("apply_host_snap", body.global_position, 0.0, dir, 0, hp_now, breath, breath_m)


func _set_locked(locked: bool) -> void:
	_dummy_frozen = locked
	if _left:
		_left.set("accept_local_input", (not locked) and _phase != Phase.RESULT)
		if locked and _left is CharacterBody2D:
			(_left as CharacterBody2D).velocity = Vector2.ZERO
	if _right:
		_right.set("accept_local_input", false)
		if locked and _right is CharacterBody2D:
			(_right as CharacterBody2D).velocity = Vector2.ZERO
		if locked and _right.has_method("apply_input_frame"):
			_right.call("apply_input_frame", 0.0, 0, 0)


func _begin_fight() -> void:
	if _phase != Phase.INTRO:
		return
	_phase = Phase.FIGHT
	_set_locked(false)
	_lock_facing(_left, FACE_RIGHT)
	_lock_facing(_right, FACE_LEFT)


func _tick_dummy() -> void:
	if _dummy_frozen or _right == null or _left == null:
		return
	if not _right.has_method("apply_input_frame"):
		return
	if _right.has_method("get_state") and int(_right.call("get_state")) == 9:
		_right.call("apply_input_frame", 0.0, 0, 0)
		return
	var dx: float = (_left as Node2D).global_position.x - (_right as Node2D).global_position.x
	var axis: float = 0.0
	if absf(dx) > DUMMY_REACH:
		axis = signf(dx)
	var just: int = 0
	if absf(dx) <= DUMMY_REACH + 16.0 and _dummy_atk_cd <= 0.0:
		just = InputFrame.BIT_ATK
		_dummy_atk_cd = DUMMY_ATK_CD
	_right.call("apply_input_frame", axis, 0, just)


func _on_fighter_died(local_pawn: bool) -> void:
	if _settled:
		return
	_settled = true
	_phase = Phase.RESULT
	_set_locked(true)
	_round_label.visible = false
	_result_label.text = TEXT_LOSE if local_pawn else TEXT_WIN
	_result_root.visible = true


func _spawn_hud_and_touch() -> void:
	var hud: CanvasLayer = COMBAT_HUD_SCENE.instantiate() as CanvasLayer
	add_child(hud)
	if hud.has_method("bind_local_pawn") and _left != null:
		hud.call("bind_local_pawn", _left)
	if hud.has_method("set_hp") and _left != null and _left.has_method("get_hp"):
		hud.call("set_hp", float(_left.call("get_hp")), float(_left.call("get_max_hp")))
	var touch: CanvasLayer = TOUCH_SCENE.instantiate() as CanvasLayer
	add_child(touch)


func _on_voltar() -> void:
	if is_instance_valid(SceneRouter) and SceneRouter.has_method("to_hub"):
		SceneRouter.to_hub()
		return
	get_tree().change_scene_to_file("res://scenes/main_menu/hub.tscn")
