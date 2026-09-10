extends Node2D
## Controller comum das fases W1:
## touch + HUD + ondas de oni → destrava saída → clear / morte.

const COMBAT_HUD_SCENE := preload("res://scenes/ui/combat_hud.tscn")
const TOUCH_SCENE := preload("res://scenes/ui/combat_touch_controls.tscn")
const WAVE_SCRIPT := preload("res://scripts/battle/wave_director.gd")
const PLAYER_SCENE := preload("res://scenes/characters/player/player.tscn")
const COOP_CAM_SCRIPT := preload("res://scripts/battle/coop_camera.gd")

@export var stage_id: String = "w1_01"
@export var reset_run_coins_on_start: bool = true
@export var reset_breath_on_start: bool = true
@export var reload_on_death: bool = true
@export var fall_death_y: float = 900.0
@export var spawn_combat_hud: bool = true
@export var spawn_touch_controls: bool = true
@export var player_max_hp: int = 100
## Com ondas: NÃO limpa a fase só por matar o último oni da cena.
## Clear = portal após waves_finished (ou portal se use_waves=false).
@export var use_waves: bool = true
@export var clear_when_enemies_dead: bool = false
@export var lock_goal_until_waves_done: bool = true

var _completed: bool = false
var _dead: bool = false
var _player: Node2D
var _goal: Area2D
var _hud: CanvasLayer
var _returning: bool = false
var _waves_done: bool = false
var _wave_director: Node
var _player2: Node2D
var _coop: bool = false
var _local_pawn: Node2D


func _ready() -> void:
	if reset_run_coins_on_start:
		Game.lose_run_coins()
	if reset_breath_on_start:
		Game.breath = 0.0
		Game.breath_changed.emit(Game.breath, Game.breath_max)

	if is_instance_valid(Audio):
		# Boss stages use darker BGM key; others use stage loop.
		if "boss" in stage_id.to_lower():
			Audio.play_bgm("boss")
		else:
			Audio.play_bgm("stage")

	_player = _find_player()
	_goal = _find_goal()
	_setup_coop_if_needed()
	_setup_player_physics()
	_wire_player_hits()
	_wire_player_death()
	_bind_lan_stage_signals()

	if _goal and lock_goal_until_waves_done and use_waves:
		_set_goal_locked(true)

	if spawn_combat_hud:
		_hud = COMBAT_HUD_SCENE.instantiate() as CanvasLayer
		add_child(_hud)
		var cur_hp: float = float(player_max_hp)
		var max_hp: float = float(player_max_hp)
		if _player != null:
			var php: Variant = _player.get("hp")
			if php != null:
				cur_hp = float(php)
			var st: Variant = _player.get("stats")
			if st != null and st.get("max_hp") != null:
				max_hp = float(st.get("max_hp"))
		if _local_pawn != null:
			var lhp: Variant = _local_pawn.get("hp")
			if lhp != null:
				cur_hp = float(lhp)
			var lst: Variant = _local_pawn.get("stats")
			if lst != null and lst.get("max_hp") != null:
				max_hp = float(lst.get("max_hp"))
		if _hud.has_method("set_hp"):
			_hud.call("set_hp", cur_hp, max_hp)
		var hud_src: Node2D = _local_pawn if _local_pawn != null else _player
		if hud_src != null and _hud.has_method("bind_local_pawn"):
			_hud.call("bind_local_pawn", hud_src)
		elif hud_src != null and hud_src.has_signal("hp_changed"):
			if not hud_src.is_connected("hp_changed", _on_player_hp_changed):
				hud_src.connect("hp_changed", _on_player_hp_changed)

	if spawn_touch_controls:
		add_child(TOUCH_SCENE.instantiate())

	_build_back_button()
	_build_controls_hint()
	_build_stage_intro_hint()

	if use_waves:
		if _coop and is_instance_valid(LanSession) and LanSession.is_guest():
			_waves_done = false
		else:
			_start_waves()
	else:
		_waves_done = true
		_wire_enemies()
		if _goal:
			_set_goal_locked(false)
	call_deferred("_play_stage_intro")

	if _goal:
		if _goal.has_signal("reached"):
			if not _goal.reached.is_connected(_on_goal_reached):
				_goal.reached.connect(_on_goal_reached)
		elif not _goal.body_entered.is_connected(_on_goal_body_entered):
			_goal.body_entered.connect(_on_goal_body_entered)

	print("[StageController] stage_id=%s ready waves=%s" % [stage_id, use_waves])


func _setup_player_physics() -> void:
	if _player == null:
		return
	if _player is CharacterBody2D:
		var body := _player as CharacterBody2D
		body.floor_snap_length = 12.0
		body.floor_max_angle = deg_to_rad(50.0)
		body.safe_margin = 0.12
		body.collision_mask = 1 # world
		body.collision_layer = 2 # player
		# Garante câmera ativa no play.
		var cam := body.get_node_or_null("Camera2D") as Camera2D
		if cam and not _coop:
			cam.make_current()


func _coop_session() -> bool:
	return is_instance_valid(LanSession) and LanSession.in_session() and LanSession.has_peer()


func _setup_coop_if_needed() -> void:
	_coop = _coop_session()
	if not _coop:
		_local_pawn = _player
		return
	if LanSession.is_guest():
		_clear_guest_packed_enemies()
	LanSession.mark_entered_stage()
	if _player != null:
		_player.set("coop_slot", 0)
		_player.set("is_local_pawn", LanSession.is_host())
		_player.set("accept_local_input", LanSession.is_host())
		_player.set("follow_host_snap", LanSession.is_guest())
		if LanSession.is_guest() and _player.has_method("reload_character_kit"):
			_player.call("reload_character_kit", LanSession.remote_character_id)
		var cam := _player.get_node_or_null("Camera2D") as Camera2D
		if cam:
			cam.enabled = false
		_spawn_player2()
		_make_coop_camera(cam)
	_local_pawn = _player if LanSession.is_host() else _player2
	if _local_pawn != null:
		_local_pawn.set("is_local_pawn", true)


func _clear_guest_packed_enemies() -> void:
	## Guest não chama WaveDirector._clear_preplaced_enemies. Sem isto o Enemy1
	## packed nas stage_*.tscn corre AI local no mesmo frame da física.
	var tree := get_tree()
	if tree == null:
		return
	for n: Node in tree.get_nodes_in_group("enemy"):
		if not is_instance_valid(n):
			continue
		n.set("net_puppet", true)
		n.queue_free()


func _spawn_player2() -> void:
	if _player == null:
		return
	var p2: Node = PLAYER_SCENE.instantiate()
	p2.name = "Player2"
	p2.set("coop_slot", 1)
	p2.set("forced_character_id", LanSession.remote_character_id if LanSession.is_host() else Game.current_character_id)
	p2.set("skip_local_upgrades", true)
	p2.set("accept_local_input", false)
	p2.set("follow_host_snap", LanSession.is_guest())
	p2.set("is_local_pawn", LanSession.is_guest())
	add_child(p2)
	if p2 is Node2D:
		(p2 as Node2D).global_position = (_player as Node2D).global_position + Vector2(80.0, 0.0)
	_player2 = p2 as Node2D
	if p2 is CharacterBody2D:
		var body := p2 as CharacterBody2D
		body.floor_snap_length = 12.0
		body.collision_mask = 1
		body.collision_layer = 2


func _make_coop_camera(from: Camera2D) -> void:
	var cam := Camera2D.new()
	cam.set_script(COOP_CAM_SCRIPT)
	cam.name = "CoopCamera"
	add_child(cam)
	var targets: Array[Node2D] = []
	if _player != null:
		targets.append(_player)
	if _player2 != null:
		targets.append(_player2)
	if cam.has_method("setup"):
		cam.call("setup", from, targets)


func _bind_lan_stage_signals() -> void:
	if not _coop:
		return
	if not LanSession.stage_cleared_event.is_connected(_on_lan_stage_cleared):
		LanSession.stage_cleared_event.connect(_on_lan_stage_cleared)
	if not LanSession.stage_wipe.is_connected(_on_lan_wipe):
		LanSession.stage_wipe.connect(_on_lan_wipe)
	if not LanSession.waves_unlocked.is_connected(_on_lan_waves_done):
		LanSession.waves_unlocked.connect(_on_lan_waves_done)


func _on_lan_stage_cleared(sid: String, coins: int) -> void:
	if LanSession.is_host():
		return
	if _completed or _dead:
		return
	_completed = true
	Game.coins_run = coins
	Game.bank_run_coins()
	Game.mark_stage_cleared(sid)
	if is_instance_valid(Audio):
		Audio.play_sfx("stage_clear")
	await _play_clear_ceremony(coins)


func _on_lan_wipe() -> void:
	if LanSession.is_host():
		return
	_dead = true
	Game.lose_run_coins()
	get_tree().reload_current_scene()


func _on_lan_waves_done() -> void:
	_waves_done = true
	if _goal:
		_set_goal_locked(false)


func _start_waves() -> void:
	_wave_director = Node.new()
	_wave_director.set_script(WAVE_SCRIPT)
	_wave_director.name = "WaveDirector"
	_wave_director.set("stage_id", stage_id)
	_wave_director.set("spawn_y", _guess_spawn_y())
	_wave_director.set("auto_start", false)
	_wave_director.set("clear_scene_enemies_on_start", true)
	add_child(_wave_director)
	if _wave_director.has_signal("waves_finished"):
		_wave_director.connect("waves_finished", _on_waves_finished)
	if _wave_director.has_signal("wave_started"):
		_wave_director.connect("wave_started", _on_wave_started)
	if _wave_director.has_signal("wave_cleared"):
		_wave_director.connect("wave_cleared", _on_wave_cleared)


func _guess_spawn_y() -> float:
	if _player != null:
		return _player.global_position.y
	return 500.0


func _on_waves_finished() -> void:
	_waves_done = true
	if _goal:
		_set_goal_locked(false)
	if _coop and is_instance_valid(LanSession) and LanSession.is_host():
		LanSession.broadcast_waves_done()
	print("[StageController] waves done → goal unlocked")


func _on_wave_started(wave_index: int, total_waves: int, _count: int) -> void:
	if _hud != null and _hud.has_method("set_wave"):
		_hud.call("set_wave", wave_index, total_waves)


func _on_wave_cleared(_wave_index: int, _total_waves: int) -> void:
	for p: Node in [_player, _player2]:
		if p != null and p.has_method("heal"):
			p.call("heal", 12)


func _play_stage_intro() -> void:
	if CeremonyCard.is_headless():
		_kick_waves()
		return
	var def: StageDef = WorldCatalog.find(stage_id)
	var title: String = def.display_name if def else stage_id
	var kicker: String = def.map_label if def else "Fase"
	var card := CeremonyCard.new()
	add_child(card)
	await card.play(kicker, title, "Os onis surgem nas sombras", 2.0)
	_kick_waves()


func _kick_waves() -> void:
	if _wave_director != null and _wave_director.has_method("begin_waves"):
		_wave_director.call("begin_waves")


func _set_goal_locked(locked: bool) -> void:
	if _goal == null:
		return
	# Prefer API do StageGoal (pulse/glow + FECHADA legível).
	if _goal.has_method("set_locked"):
		_goal.call("set_locked", locked)
		return
	_goal.monitoring = not locked
	_goal.visible = true
	var label := _goal.get_node_or_null("Label") as Label
	if label:
		label.text = "FECHADA" if locked else "SAIDA"
	var glow := _goal.get_node_or_null("PortalGlow") as CanvasItem
	if glow:
		glow.modulate = Color(0.5, 0.5, 0.5, 0.5) if locked else Color.WHITE
	var vis := _goal.get_node_or_null("PortalVisual") as CanvasItem
	if vis:
		vis.modulate = Color(0.4, 0.4, 0.45, 0.55) if locked else Color.WHITE


func _on_player_hp_changed(current: int, max_hp: int) -> void:
	if _hud != null and _hud.has_method("set_hp"):
		_hud.call("set_hp", float(current), float(max_hp))


func _unhandled_input(event: InputEvent) -> void:
	if _completed or _dead or _returning:
		return
	if event.is_action_pressed("pause"):
		_show_pause_menu()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	## Pause via botão on-screen usa action_press (nem sempre vira InputEvent
	## em _unhandled_input). Checa também aqui.
	if _completed or _dead or _returning:
		return
	if get_tree().paused:
		return
	if Input.is_action_just_pressed("pause"):
		_show_pause_menu()


func _physics_process(_delta: float) -> void:
	if _completed or _dead:
		return
	if _player == null:
		_player = _find_player()
		if _player == null:
			return
	if _coop:
		for p: Node2D in [_player, _player2]:
			if p != null and p.global_position.y > fall_death_y:
				report_player_death()
				return
		return
	if _player.global_position.y > fall_death_y:
		report_player_death()


func report_player_death() -> void:
	if _completed or _dead:
		return
	if _coop and is_instance_valid(LanSession) and LanSession.is_guest():
		return
	_dead = true
	Game.lose_run_coins()
	print("[StageController] player death stage=%s" % stage_id)
	if _coop and is_instance_valid(LanSession) and LanSession.is_host():
		LanSession.broadcast_wipe()
	if reload_on_death:
		get_tree().reload_current_scene()
	else:
		SceneRouter.to_world_map()


func _on_goal_reached(_body: Node2D) -> void:
	if lock_goal_until_waves_done and use_waves and not _waves_done:
		return
	_complete_stage()


func _on_goal_body_entered(body: Node2D) -> void:
	if body != null and body.is_in_group("player"):
		if lock_goal_until_waves_done and use_waves and not _waves_done:
			return
		_complete_stage()


func _on_enemy_defeated() -> void:
	if not clear_when_enemies_dead or _completed or _dead:
		return
	if use_waves and not _waves_done:
		return
	await get_tree().process_frame
	if _all_enemies_defeated():
		_complete_stage()


func _complete_stage() -> void:
	if _completed or _dead:
		return
	if _coop and is_instance_valid(LanSession) and LanSession.is_guest():
		return
	_completed = true
	var banked_amount: int = int(Game.coins_run)
	Game.bank_run_coins()
	Game.mark_stage_cleared(stage_id)
	if _coop and is_instance_valid(LanSession) and LanSession.is_host():
		LanSession.broadcast_stage_cleared(stage_id, banked_amount)
	if is_instance_valid(Audio):
		Audio.play_sfx("stage_clear")
	if is_instance_valid(CombatFeel):
		CombatFeel.shake(5.0, 0.15)
	print("[StageController] CLEAR %s coins_banked=%d" % [stage_id, banked_amount])
	await _play_clear_ceremony(banked_amount)
	_go_after_clear()


func _go_after_clear() -> void:
	if CeremonyCard.is_headless():
		_navigate_coop(SceneRouter.WORLD_MAP)
		return
	var nxt: StageDef = WorldCatalog.next_playable_any(WorldCatalog.cleared_ids())
	if nxt != null and not nxt.scene_path.is_empty():
		Game.pending_stage_id = nxt.stage_id
		Game.current_world_id = WorldCatalog.world_of(nxt.stage_id)
		_navigate_coop(nxt.scene_path)
		return
	_navigate_coop(SceneRouter.WORLD_MAP)


func _navigate_coop(path: String) -> void:
	if _coop and is_instance_valid(LanSession) and LanSession.is_host():
		LanSession.announce_stage(path)
	SceneRouter.go_to(path)


## Banner CLEAR + flash de moedas bank + delay de cerimônia.
func _play_clear_ceremony(banked_amount: int) -> void:
	var layer := CanvasLayer.new()
	layer.name = "ClearCeremony"
	layer.layer = 95
	add_child(layer)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.04, 0.08, 0.0)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(dim)

	var title := Label.new()
	title.name = "ClearTitle"
	title.set_anchors_preset(Control.PRESET_CENTER)
	title.offset_left = -320.0
	title.offset_top = -80.0
	title.offset_right = 320.0
	title.offset_bottom = 0.0
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.text = "FASE CONCLUIDA"
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.45, 1.0))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	title.add_theme_color_override("font_outline_color", Color(0.2, 0.1, 0.0, 0.85))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 3)
	title.add_theme_constant_override("outline_size", 5)
	title.modulate.a = 0.0
	title.scale = Vector2(0.55, 0.55)
	title.pivot_offset = Vector2(320.0, 40.0)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(title)

	var coins_lbl := Label.new()
	coins_lbl.name = "CoinsBankFlash"
	coins_lbl.set_anchors_preset(Control.PRESET_CENTER)
	coins_lbl.offset_left = -280.0
	coins_lbl.offset_top = 12.0
	coins_lbl.offset_right = 280.0
	coins_lbl.offset_bottom = 64.0
	coins_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coins_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if banked_amount > 0:
		coins_lbl.text = "+%d moedas salvas" % banked_amount
	else:
		coins_lbl.text = "Fase concluída"
	coins_lbl.add_theme_font_size_override("font_size", 28)
	coins_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35, 1.0))
	coins_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	coins_lbl.add_theme_constant_override("shadow_offset_x", 2)
	coins_lbl.add_theme_constant_override("shadow_offset_y", 2)
	coins_lbl.modulate.a = 0.0
	coins_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(coins_lbl)

	# Pop CLEAR + dim + flash moedas.
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(dim, "color:a", 0.55, 0.22)
	tw.tween_property(title, "modulate:a", 1.0, 0.18)
	tw.tween_property(title, "scale", Vector2(1.12, 1.12), 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.set_parallel(false)
	tw.tween_property(title, "scale", Vector2.ONE, 0.12)
	tw.tween_property(coins_lbl, "modulate:a", 1.0, 0.18)
	# Pulse dourado nas moedas (bank flash).
	tw.tween_property(coins_lbl, "modulate", Color(1.25, 1.15, 0.55, 1.0), 0.12)
	tw.tween_property(coins_lbl, "modulate", Color(1.0, 0.88, 0.35, 1.0), 0.18)
	tw.tween_interval(1.15)
	tw.set_parallel(true)
	tw.tween_property(title, "modulate:a", 0.0, 0.35)
	tw.tween_property(coins_lbl, "modulate:a", 0.0, 0.35)
	tw.tween_property(dim, "color:a", 0.0, 0.35)
	await tw.finished
	if is_instance_valid(layer):
		layer.queue_free()


func _return_to_map(count_as_victory: bool) -> void:
	if _returning:
		return
	_returning = true
	if not count_as_victory and not _completed:
		Game.lose_run_coins()
	if _coop and is_instance_valid(LanSession) and LanSession.is_host():
		LanSession.host_leave_stage_to_map()
	SceneRouter.to_world_map()


func _build_back_button() -> void:
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
	back.pressed.connect(func() -> void: _show_pause_menu())
	layer.add_child(back)


func _build_controls_hint() -> void:
	var layer := CanvasLayer.new()
	layer.name = "ControlsHint"
	layer.layer = 45
	add_child(layer)
	var lbl := Label.new()
	lbl.position = Vector2(16, 64)
	lbl.size = Vector2(900, 28)
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", Color(0.92, 0.95, 0.88, 0.95))
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	lbl.text = "PC: A/D mover · Espaço pulo · Shift dash · Z atk · X/C skills · V ult · Esc pause"
	layer.add_child(lbl)
	# Some sozinho depois de 8s.
	var tw := create_tween()
	tw.tween_interval(8.0)
	tw.tween_property(lbl, "modulate:a", 0.0, 1.2)
	tw.tween_callback(func() -> void:
		if is_instance_valid(lbl):
			lbl.queue_free()
		if is_instance_valid(layer) and layer.get_child_count() == 0:
			layer.queue_free()
	)


## Hint de objetivo da fase no start (some com fade).
func _build_stage_intro_hint() -> void:
	var layer := CanvasLayer.new()
	layer.name = "StageIntroHint"
	layer.layer = 46
	add_child(layer)

	var panel := ColorRect.new()
	panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	panel.offset_top = 200.0
	panel.offset_bottom = 268.0
	panel.color = Color(0.02, 0.05, 0.1, 0.0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(panel)

	var lbl := Label.new()
	lbl.set_anchors_preset(Control.PRESET_TOP_WIDE)
	lbl.offset_top = 204.0
	lbl.offset_bottom = 264.0
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 26)
	lbl.add_theme_color_override("font_color", Color(0.95, 0.97, 0.9, 1.0))
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	lbl.add_theme_constant_override("shadow_offset_x", 2)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	lbl.add_theme_constant_override("outline_size", 3)
	if use_waves:
		lbl.text = "Elimine as ondas · Saída abre no fim"
	else:
		lbl.text = "Derrote os onis e alcance a saída"
	lbl.modulate.a = 0.0
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(lbl)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "modulate:a", 1.0, 0.35)
	tw.tween_property(panel, "color:a", 0.5, 0.35)
	tw.set_parallel(false)
	tw.tween_interval(3.2)
	tw.set_parallel(true)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.9)
	tw.tween_property(panel, "color:a", 0.0, 0.9)
	tw.set_parallel(false)
	tw.tween_callback(layer.queue_free)


func _show_pause_menu() -> void:
	if get_tree().paused:
		return
	if has_node("PauseMenu"):
		return
	get_tree().paused = true
	# Garante que hitstop não deixe o jogo em câmera lenta na pausa.
	if is_instance_valid(CombatFeel):
		Engine.time_scale = 1.0
	var layer := CanvasLayer.new()
	layer.name = "PauseMenu"
	layer.layer = 80
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(dim)
	var panel := VBoxContainer.new()
	panel.position = Vector2(440, 220)
	panel.custom_minimum_size = Vector2(400, 280)
	panel.add_theme_constant_override("separation", 16)
	layer.add_child(panel)
	var title := Label.new()
	title.text = "PAUSA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(1, 0.95, 0.85, 1))
	panel.add_child(title)
	var resume := Button.new()
	resume.text = "Continuar"
	resume.custom_minimum_size = Vector2(0, 56)
	resume.process_mode = Node.PROCESS_MODE_ALWAYS
	resume.pressed.connect(func() -> void:
		get_tree().paused = false
		Engine.time_scale = 1.0
		layer.queue_free()
	)
	panel.add_child(resume)
	if not _coop or (is_instance_valid(LanSession) and LanSession.is_host()):
		var to_map := Button.new()
		to_map.text = "Sair para o mapa"
		to_map.custom_minimum_size = Vector2(0, 56)
		to_map.process_mode = Node.PROCESS_MODE_ALWAYS
		to_map.pressed.connect(func() -> void:
			get_tree().paused = false
			Engine.time_scale = 1.0
			layer.queue_free()
			_return_to_map(false)
		)
		panel.add_child(to_map)
	if _coop:
		var leave := Button.new()
		leave.text = "Sair da sala"
		leave.custom_minimum_size = Vector2(0, 56)
		leave.process_mode = Node.PROCESS_MODE_ALWAYS
		leave.pressed.connect(func() -> void:
			get_tree().paused = false
			Engine.time_scale = 1.0
			layer.queue_free()
			if not _completed:
				Game.lose_run_coins()
			if is_instance_valid(LanSession):
				LanSession.close_session()
			SceneRouter.to_hub()
		)
		panel.add_child(leave)
	else:
		var to_hub := Button.new()
		to_hub.text = "Sair para o hub"
		to_hub.custom_minimum_size = Vector2(0, 56)
		to_hub.process_mode = Node.PROCESS_MODE_ALWAYS
		to_hub.pressed.connect(func() -> void:
			get_tree().paused = false
			Engine.time_scale = 1.0
			layer.queue_free()
			if not _completed:
				Game.lose_run_coins()
			SceneRouter.to_hub()
		)
		panel.add_child(to_hub)


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


func _wire_player_death() -> void:
	for p: Node in [_player, _player2]:
		if p == null:
			continue
		if p.has_signal("died") and not p.is_connected("died", report_player_death):
			p.connect("died", report_player_death)


func _on_player_hitbox_hit(_hurtbox: Variant, _hit_data: Variant) -> void:
	# Breath também no player; reforço se o player não conectou.
	pass


func _all_enemies_defeated() -> bool:
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemy")
	if enemies.is_empty():
		return true
	for n: Node in enemies:
		if not is_instance_valid(n):
			continue
		var n_hp: Variant = n.get("hp")
		if n_hp != null and int(n_hp) > 0:
			return false
		if n.get("_died") == true:
			continue
		if n_hp == null:
			return false
	return true


func _find_player() -> Node2D:
	var from_group: Array[Node] = get_tree().get_nodes_in_group("player")
	if not from_group.is_empty():
		return from_group[0] as Node2D
	return get_node_or_null("Player") as Node2D


func _find_goal() -> Area2D:
	var direct := get_node_or_null("Goal") as Area2D
	if direct:
		return direct
	return find_child("Goal", true, false) as Area2D
