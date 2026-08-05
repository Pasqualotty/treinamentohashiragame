extends Node2D
## Controller comum das fases W1: run coins, goal → bank+clear, morte → lose+reload.

const COMBAT_HUD_SCENE := preload("res://scenes/ui/combat_hud.tscn")

## IDs canônicos (documentados no done.json / world_map).
## w1_01 | w1_02 | w1_03 | w1_boss
@export var stage_id: String = "w1_01"
@export var reset_run_coins_on_start: bool = true
@export var reset_breath_on_start: bool = true
## true = reload da fase; false = volta ao mapa.
@export var reload_on_death: bool = true
@export var fall_death_y: float = 900.0
@export var spawn_combat_hud: bool = true
@export var player_max_hp: int = 100

var _completed: bool = false
var _dead: bool = false
var _player: Node2D
var _goal: Area2D
var _hud: CanvasLayer


func _ready() -> void:
	if reset_run_coins_on_start:
		Game.lose_run_coins()
	if reset_breath_on_start:
		Game.breath = 0.0
		Game.breath_changed.emit(Game.breath, Game.breath_max)

	_player = _find_player()
	_goal = _find_goal()
	if _goal:
		if _goal.has_signal("reached"):
			if not _goal.reached.is_connected(_on_goal_reached):
				_goal.reached.connect(_on_goal_reached)
		elif not _goal.body_entered.is_connected(_on_goal_body_entered):
			_goal.body_entered.connect(_on_goal_body_entered)

	if spawn_combat_hud:
		_hud = COMBAT_HUD_SCENE.instantiate() as CanvasLayer
		add_child(_hud)
		if _hud.has_method("set_hp"):
			_hud.call("set_hp", player_max_hp, player_max_hp)

	print("[StageController] stage_id=%s ready" % stage_id)


func _physics_process(_delta: float) -> void:
	if _completed or _dead:
		return
	if _player == null:
		_player = _find_player()
		if _player == null:
			return
	if _player.global_position.y > fall_death_y:
		report_player_death()


## API pública — inimigos / traps podem chamar depois.
func report_player_death() -> void:
	if _completed or _dead:
		return
	_dead = true
	Game.lose_run_coins()
	print("[StageController] player death → lose_run_coins stage=%s" % stage_id)
	if reload_on_death:
		get_tree().reload_current_scene()
	else:
		SceneRouter.to_world_map()


func _on_goal_reached(_body: Node2D) -> void:
	_complete_stage()


func _on_goal_body_entered(body: Node2D) -> void:
	if body != null and body.is_in_group("player"):
		_complete_stage()


func _complete_stage() -> void:
	if _completed or _dead:
		return
	_completed = true
	Game.bank_run_coins()
	Game.mark_stage_cleared(stage_id)
	print("[StageController] CLEAR %s → bank + world_map" % stage_id)
	SceneRouter.to_world_map()


func _find_player() -> Node2D:
	var from_group: Array[Node] = get_tree().get_nodes_in_group("player")
	if not from_group.is_empty():
		return from_group[0] as Node2D
	var direct := get_node_or_null("Player") as Node2D
	return direct


func _find_goal() -> Area2D:
	var direct := get_node_or_null("Goal") as Area2D
	if direct:
		return direct
	var nested := find_child("Goal", true, false)
	return nested as Area2D
