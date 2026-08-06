extends Node2D
## Controller comum das fases W1: touch + HUD + goal/inimigos → clear, morte → reload.

const COMBAT_HUD_SCENE := preload("res://scenes/ui/combat_hud.tscn")
const TOUCH_SCENE := preload("res://scenes/ui/combat_touch_controls.tscn")

## IDs canônicos: w1_01 | w1_02 | w1_03 | w1_boss
@export var stage_id: String = "w1_01"
@export var reset_run_coins_on_start: bool = true
@export var reset_breath_on_start: bool = true
## true = reload da fase; false = volta ao mapa.
@export var reload_on_death: bool = true
@export var fall_death_y: float = 900.0
@export var spawn_combat_hud: bool = true
@export var spawn_touch_controls: bool = true
@export var player_max_hp: int = 100
## Se true, matar todos do group enemy também completa (além do portal).
@export var clear_when_enemies_dead: bool = true

var _completed: bool = false
var _dead: bool = false
var _player: Node2D
var _goal: Area2D
var _hud: CanvasLayer
var _returning: bool = false


func _ready() -> void:
	if reset_run_coins_on_start:
		Game.lose_run_coins()
	if reset_breath_on_start:
		Game.breath = 0.0
		Game.breath_changed.emit(Game.breath, Game.breath_max)

	if is_instance_valid(Audio):
		Audio.play_bgm("stage")

	_player = _find_player()
	_goal = _find_goal()
	if _goal:
		if _goal.has_signal("reached"):
			if not _goal.reached.is_connected(_on_goal_reached):
				_goal.reached.connect(_on_goal_reached)
		elif not _goal.body_entered.is_connected(_on_goal_body_entered):
			_goal.body_entered.connect(_on_goal_body_entered)

	_wire_enemies()
	_wire_player_hits()

	if spawn_combat_hud:
		_hud = COMBAT_HUD_SCENE.instantiate() as CanvasLayer
		add_child(_hud)
		if _hud.has_method("set_hp"):
			_hud.call("set_hp", player_max_hp, player_max_hp)

	if spawn_touch_controls:
		add_child(TOUCH_SCENE.instantiate())

	_build_back_button()
	print("[StageController] stage_id=%s ready (touch+hud)" % stage_id)


func _unhandled_input(event: InputEvent) -> void:
	if _completed or _dead or _returning:
		return
	if event.is_action_pressed("pause"):
		_return_to_map(false)
		get_viewport().set_input_as_handled()


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


func _on_enemy_defeated() -> void:
	if not clear_when_enemies_dead or _completed or _dead:
		return
	# Aguarda um frame para o inimigo sair do group se o script remover.
	await get_tree().process_frame
	if _all_enemies_defeated():
		_complete_stage()


func _complete_stage() -> void:
	if _completed or _dead:
		return
	_completed = true
	Game.bank_run_coins()
	Game.mark_stage_cleared(stage_id)
	if is_instance_valid(Audio):
		Audio.play_sfx("stage_clear")
	if is_instance_valid(CombatFeel):
		CombatFeel.shake(5.0, 0.15)
	print("[StageController] CLEAR %s → bank + world_map" % stage_id)
	await get_tree().create_timer(0.9).timeout
	SceneRouter.to_world_map()


func _return_to_map(count_as_victory: bool) -> void:
	if _returning:
		return
	_returning = true
	if not count_as_victory and not _completed:
		Game.lose_run_coins()
	SceneRouter.to_world_map()


func _build_back_button() -> void:
	## Topo-esquerda: fora do cluster touch (polegares embaixo) e longe do ATK.
	var layer := CanvasLayer.new()
	layer.name = "StageChrome"
	layer.layer = 50
	add_child(layer)
	var back := Button.new()
	back.name = "BackToMap"
	back.text = "Mapa"
	back.position = Vector2(16, 100)
	back.size = Vector2(120, 48)
	back.focus_mode = Control.FOCUS_NONE
	back.add_theme_font_size_override("font_size", 18)
	back.pressed.connect(func() -> void: _return_to_map(false))
	layer.add_child(back)


func _wire_enemies() -> void:
	for n: Node in get_tree().get_nodes_in_group("enemy"):
		if n.has_signal("defeated") and not n.is_connected("defeated", _on_enemy_defeated):
			n.connect("defeated", _on_enemy_defeated)


func _wire_player_hits() -> void:
	if _player == null:
		return
	var hitbox: Node = _player.get_node_or_null("%Hitbox")
	if hitbox == null:
		hitbox = _player.find_child("Hitbox", true, false)
	if hitbox != null and hitbox.has_signal("hit"):
		if not hitbox.is_connected("hit", _on_player_hitbox_hit):
			hitbox.connect("hit", _on_player_hitbox_hit)


func _on_player_hitbox_hit(_hurtbox: Variant, _hit_data: Variant) -> void:
	Game.add_breath_from_hit(10.0)


func _all_enemies_defeated() -> bool:
	## Após um `defeated`, se não restar ninguém vivo no group (ou group vazio
	## porque o último oni deu queue_free), a fase pode clear.
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemy")
	# Grupo vazio apos queue_free = todos mortos (clear por wipe).
	if enemies.is_empty():
		return true
	for n: Node in enemies:
		if not is_instance_valid(n):
			continue
		var n_hp: Variant = n.get("hp")
		if n_hp != null and int(n_hp) > 0:
			return false
		# Dummy/oni sem prop hp: conta como vivo se ainda no group.
		if n_hp == null:
			return false
		if n.get("_died") == true or n.get("_defeated") == true:
			continue
		# Inimigo vivo sem hp exposto: nao assume morto.
		if n.get("hp") == null:
			return false
	return true


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
