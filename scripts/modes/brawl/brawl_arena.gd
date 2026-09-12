extends Node2D
## Mapa de batalha: pátio grande, até 4 caçadores, pads, saída após o fim.
## Sala + amigos: cada celular o seu. Sem sessão (F6): você + máquinas.

const PLAYER_SCENE: PackedScene = preload("res://scenes/characters/player/player.tscn")
const TOUCH_SCENE: PackedScene = preload("res://scenes/ui/combat_touch_controls.tscn")
const HUD_SCRIPT: Script = preload("res://scripts/modes/brawl/brawl_hud.gd")
const BOT_SCRIPT: Script = preload("res://scripts/modes/brawl/brawl_bot.gd")
const MAP := preload("res://scripts/modes/brawl/brawl_map.gd")

const MATCH_TIME: float = 90.0
const DEFAULT_IDS: PackedStringArray = ["inosuke", "nezuko", "zenitsu", "tanjiro"]
const FILL_IDS: PackedStringArray = ["zenitsu", "tanjiro", "rengoku", "shinobu"]

var _hunters: Array[CharacterBody2D] = []
var _bots: Array[Node] = []
var _hud: CanvasLayer
var _cam: Camera2D
var _time_left: float = MATCH_TIME
var _over: bool = false
var _roster: PackedStringArray = DEFAULT_IDS
var _debug_vertical_on: Array[bool] = [false, false, false, false]
var _debug_vertical: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
var _pause_layer: CanvasLayer


func _ready() -> void:
	process_priority = -10
	_cam = get_node_or_null("Camera2D") as Camera2D
	_roster = _resolve_roster()
	_time_left = _resolve_match_time()
	_build_map()
	if _lan_peers():
		LanSession.mark_entered_stage()
	_spawn_hunters()
	var i: int = 0
	while i < _hunters.size():
		_patch_pvp(_hunters[i], i)
		_wire_death(_hunters[i])
		i += 1
	_attach_bots()
	_spawn_hud()
	_spawn_touch()
	_face_inward()
	_setup_camera()
	if is_instance_valid(Audio) and Audio.has_method("play_bgm"):
		Audio.play_bgm("stage")
	if uses_lan_roster():
		print("[BrawlArena] sessão n=%d dummy=%s" % [_hunters.size(), has_dummy()])
	else:
		print("[BrawlArena] F6 standalone n=%d" % _hunters.size())


func _physics_process(delta: float) -> void:
	if _over:
		_zero_all_vertical()
		return
	_time_left = maxf(0.0, _time_left - delta)
	if _hud != null and _hud.has_method("set_time_left"):
		_hud.call("set_time_left", _time_left)
	var slot: int = 0
	while slot < _hunters.size():
		var axis: float = 0.0
		if slot == _local_slot():
			axis = _local_vertical_axis()
		else:
			axis = _bot_vertical(slot)
		_apply_plane_vertical(_hunters[slot], _axis_for(slot, axis))
		slot += 1
	_follow_camera()
	_check_end()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_toggle_pause()
		get_viewport().set_input_as_handled()


func get_hunter(slot: int) -> CharacterBody2D:
	if slot < 0 or slot >= _hunters.size():
		return null
	return _hunters[slot]


func get_hunters() -> Array[CharacterBody2D]:
	return _hunters.duplicate()


func hunter_count() -> int:
	return _hunters.size()


func get_map_size() -> Vector2:
	return MAP.MAP_SIZE


func is_match_over() -> bool:
	return _over


func get_time_left() -> float:
	return _time_left


func uses_lan_roster() -> bool:
	return _live_session()


func has_dummy() -> bool:
	return not _bots.is_empty()


func pickup_count() -> int:
	var host: Node = get_node_or_null("Pickups")
	return host.get_child_count() if host else 0


func hunter_team(slot: int) -> StringName:
	var pawn: CharacterBody2D = get_hunter(slot)
	if pawn == null:
		return &""
	var hit: Hitbox = pawn.get_node_or_null("%Hitbox") as Hitbox
	if hit == null:
		return &""
	return hit.team


func restart_match() -> void:
	_close_pause()
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()


func leave_match() -> void:
	_close_pause()
	get_tree().paused = false
	Engine.time_scale = 1.0
	if is_instance_valid(LanSession) and LanSession.in_session():
		LanSession.close_session()
	SceneRouter.to_hub()


func debug_pause_bot() -> void:
	for bot: Node in _bots:
		if is_instance_valid(bot):
			bot.set_physics_process(false)
			bot.set("desired_vertical", 0.0)
	var i: int = 0
	while i < _debug_vertical_on.size():
		_debug_vertical_on[i] = true
		_debug_vertical[i] = 0.0
		i += 1
	for p: CharacterBody2D in _hunters:
		if p:
			p.velocity = Vector2.ZERO


func debug_set_vertical(slot: int, axis: float) -> void:
	if slot < 0 or slot >= _debug_vertical_on.size():
		return
	_debug_vertical_on[slot] = true
	_debug_vertical[slot] = axis
	_apply_plane_vertical(get_hunter(slot), axis)


func _build_map() -> void:
	var world: Node2D = get_node_or_null("World") as Node2D
	if world == null:
		world = Node2D.new()
		world.name = "World"
		add_child(world)
	var pads: Node2D = get_node_or_null("Pickups") as Node2D
	if pads == null:
		pads = Node2D.new()
		pads.name = "Pickups"
		add_child(pads)
	MAP.build(world, pads)


func _axis_for(slot: int, fallback: float) -> float:
	if slot >= 0 and slot < _debug_vertical_on.size() and _debug_vertical_on[slot]:
		return _debug_vertical[slot]
	return fallback


func _bot_vertical(slot: int) -> float:
	for bot: Node in _bots:
		if not is_instance_valid(bot):
			continue
		var pawn: Variant = bot.get("pawn")
		if pawn == get_hunter(slot):
			return float(bot.get("desired_vertical"))
	return 0.0


func _live_session() -> bool:
	if has_meta("smoke_lan_roster"):
		return true
	return _lan_peers()


func _lan_peers() -> bool:
	return is_instance_valid(LanSession) and LanSession.in_session() and LanSession.has_peer()


func _session_is_guest() -> bool:
	if has_meta("smoke_lan_roster"):
		var raw: Variant = get_meta("smoke_lan_roster")
		if raw is Dictionary:
			return bool((raw as Dictionary).get("is_guest", false))
	return is_instance_valid(LanSession) and LanSession.is_guest()


func _local_slot() -> int:
	if has_meta("smoke_lan_roster"):
		var raw: Variant = get_meta("smoke_lan_roster")
		if raw is Dictionary:
			return int((raw as Dictionary).get("local_slot", 0))
	if not _lan_peers():
		return 0
	if LanSession.is_host():
		return 0
	var slot: int = int(LanSession.local_coop_slot)
	return slot if slot > 0 else 1


func _controls_locally(slot: int) -> bool:
	if not _live_session():
		return slot == 0
	if _session_is_guest():
		return false
	return slot == _local_slot()


func _slot_is_human(slot: int) -> bool:
	if not _live_session():
		return slot == 0
	if has_meta("smoke_lan_roster"):
		return slot <= 1
	if not is_instance_valid(LanSession):
		return slot == 0
	for item: Variant in LanSession.get_roster():
		if typeof(item) != TYPE_DICTIONARY:
			continue
		if int((item as Dictionary).get("slot", -1)) == slot:
			return true
	return slot == 0


func _ids_from_session() -> PackedStringArray:
	var ids := PackedStringArray()
	if has_meta("smoke_lan_roster"):
		var raw: Variant = get_meta("smoke_lan_roster")
		if raw is Dictionary:
			var meta := raw as Dictionary
			ids.append(str(meta.get("char_0", "inosuke")))
			ids.append(str(meta.get("char_1", "nezuko")))
			return ids
	if not is_instance_valid(LanSession):
		return ids
	var found: Dictionary = {}
	for item: Variant in LanSession.get_roster():
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var rec := item as Dictionary
		found[int(rec.get("slot", -1))] = str(rec.get("char_id", "tanjiro"))
	var slot: int = 0
	while slot < 4:
		if found.has(slot):
			ids.append(str(found[slot]))
		slot += 1
	return ids


func _resolve_roster() -> PackedStringArray:
	if _live_session():
		var from_lan: PackedStringArray = _ids_from_session()
		if from_lan.size() >= 2:
			return _fill_roster(from_lan, from_lan.size())
		return _fill_roster(from_lan, 4)
	var gm: Node = get_node_or_null("/root/GameMode")
	if gm != null:
		var from_prop: Variant = gm.get("brawl_ids")
		var parsed: PackedStringArray = _as_ids(from_prop)
		if parsed.size() >= 2:
			return _fill_roster(parsed, 4)
		if gm.has_method("get_brawl_roster"):
			parsed = _as_ids(gm.call("get_brawl_roster"))
			if parsed.size() >= 2:
				return _fill_roster(parsed, 4)
	return _fill_roster(DEFAULT_IDS, 4)


func _fill_roster(base: PackedStringArray, want: int) -> PackedStringArray:
	var out := PackedStringArray()
	for id: String in base:
		if out.size() >= want:
			break
		out.append(id)
	var i: int = 0
	while out.size() < want:
		var extra: String = FILL_IDS[i % FILL_IDS.size()]
		if extra not in out:
			out.append(extra)
		elif DEFAULT_IDS[i % DEFAULT_IDS.size()] not in out:
			out.append(DEFAULT_IDS[i % DEFAULT_IDS.size()])
		else:
			out.append("tanjiro")
		i += 1
	return out


func _resolve_match_time() -> float:
	var gm: Node = get_node_or_null("/root/GameMode")
	if gm != null:
		var t: Variant = gm.get("brawl_match_time")
		if t != null and float(t) > 5.0:
			return float(t)
	return MATCH_TIME


func _as_ids(raw: Variant) -> PackedStringArray:
	var out: PackedStringArray = []
	if raw is PackedStringArray:
		out = raw
	elif raw is Array:
		for item: Variant in raw:
			out.append(str(item))
	return out


func _spawn_hunters() -> void:
	var host: Node = get_node_or_null("Hunters")
	if host == null:
		host = Node2D.new()
		host.name = "Hunters"
		add_child(host)
	if host is Node2D:
		(host as Node2D).y_sort_enabled = true
	_hunters.clear()
	var slot: int = 0
	while slot < _roster.size() and slot < 4:
		var pawn: CharacterBody2D = _make_hunter(slot, _roster[slot], _controls_locally(slot))
		host.add_child(pawn)
		pawn.global_position = MAP.SPAWNS[slot]
		_attach_shadow(pawn)
		_attach_nameplate(pawn)
		_hunters.append(pawn)
		slot += 1


func _make_hunter(slot: int, char_id: String, local: bool) -> CharacterBody2D:
	var pawn: CharacterBody2D = PLAYER_SCENE.instantiate() as CharacterBody2D
	pawn.name = "Hunter%d" % slot
	pawn.set("coop_slot", slot)
	pawn.set("forced_character_id", char_id)
	pawn.set("skip_local_upgrades", true)
	pawn.set("is_local_pawn", slot == _local_slot())
	pawn.set("accept_local_input", local)
	pawn.set("follow_host_snap", _live_session() and _session_is_guest())
	return pawn


func _patch_pvp(pawn: CharacterBody2D, slot: int) -> void:
	if pawn == null:
		return
	pawn.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	pawn.floor_snap_length = 0.0
	pawn.collision_layer = 2
	pawn.collision_mask = 1
	pawn.set("plane_locomotion", true)
	var team := StringName("brawl_%d" % slot)
	var hitbox: Hitbox = pawn.get_node_or_null("%Hitbox") as Hitbox
	var hurtbox: Hurtbox = pawn.get_node_or_null("%Hurtbox") as Hurtbox
	if hitbox:
		hitbox.team = team
	if hurtbox:
		hurtbox.team = team
	var st: PlayerStats = pawn.get("stats") as PlayerStats
	if st != null:
		var copy: PlayerStats = st.duplicate(true) as PlayerStats
		copy.gravity = 0.0
		copy.jump_velocity = 0.0
		copy.max_fall_speed = 2400.0
		pawn.set("stats", copy)
	var cam: Camera2D = pawn.get_node_or_null("Camera2D") as Camera2D
	if cam:
		cam.enabled = false


func _wire_death(pawn: CharacterBody2D) -> void:
	if pawn == null or not pawn.has_signal("died"):
		return
	if not pawn.died.is_connected(_on_hunter_died):
		pawn.died.connect(_on_hunter_died)


func _attach_bots() -> void:
	_bots.clear()
	if _session_is_guest():
		return
	var slot: int = 0
	while slot < _hunters.size():
		if _slot_is_human(slot):
			slot += 1
			continue
		var bot: Node = BOT_SCRIPT.new()
		bot.name = "BrawlBot%d" % slot
		add_child(bot)
		if bot.has_method("setup"):
			bot.call("setup", _hunters[slot], _nearest_rival(_hunters[slot]))
		_bots.append(bot)
		slot += 1


func _nearest_rival(pawn: CharacterBody2D) -> CharacterBody2D:
	var best: CharacterBody2D = null
	var best_d: float = 1.0e9
	for other: CharacterBody2D in _hunters:
		if other == pawn or other == null:
			continue
		if int(other.get("hp")) <= 0:
			continue
		var d: float = pawn.global_position.distance_to(other.global_position)
		if d < best_d:
			best_d = d
			best = other
	return best


func _spawn_hud() -> void:
	_hud = HUD_SCRIPT.new() as CanvasLayer
	_hud.name = "BrawlHud"
	add_child(_hud)
	_hud.set("on_rematch", restart_match)
	_hud.set("on_leave", leave_match)
	if _hud.has_method("bind_hunters"):
		_hud.call("bind_hunters", _hunters)
	if _hud.has_method("set_time_left"):
		_hud.call("set_time_left", _time_left)


func _spawn_touch() -> void:
	var touch: CanvasLayer = TOUCH_SCENE.instantiate() as CanvasLayer
	touch.name = "CombatTouchControls"
	touch.set("hud_band_height", 188.0)
	add_child(touch)


func _face_inward() -> void:
	var mid := MAP.MAP_SIZE * 0.5
	for pawn: CharacterBody2D in _hunters:
		if pawn == null or not pawn.has_method("apply_input_frame"):
			continue
		var dir: float = 1.0 if pawn.global_position.x < mid.x else -1.0
		pawn.call("apply_input_frame", dir, 0, 0)


func _setup_camera() -> void:
	if _cam == null:
		_cam = Camera2D.new()
		_cam.name = "Camera2D"
		add_child(_cam)
	_cam.enabled = true
	_cam.make_current()
	_cam.position_smoothing_enabled = true
	_cam.position_smoothing_speed = 6.0
	_cam.limit_left = 0
	_cam.limit_top = 0
	_cam.limit_right = int(MAP.MAP_SIZE.x)
	_cam.limit_bottom = int(MAP.MAP_SIZE.y)
	_follow_camera()


func _follow_camera() -> void:
	if _cam == null:
		return
	var local: CharacterBody2D = get_hunter(_local_slot())
	if local == null or not is_instance_valid(local):
		return
	_cam.global_position = local.global_position


func _local_vertical_axis() -> float:
	var pawn: CharacterBody2D = get_hunter(_local_slot())
	if pawn == null or not bool(pawn.get("accept_local_input")):
		return 0.0
	if not InputMap.has_action("move_up") or not InputMap.has_action("move_down"):
		return 0.0
	return Input.get_axis("move_up", "move_down")


func _apply_plane_vertical(pawn: CharacterBody2D, axis: float) -> void:
	if pawn == null or not is_instance_valid(pawn):
		return
	if int(pawn.get("hp")) <= 0:
		pawn.velocity.y = 0.0
		return
	var speed: float = 220.0
	if pawn.has_method("get_move_speed"):
		speed = float(pawn.call("get_move_speed"))
	else:
		var st: PlayerStats = pawn.get("stats") as PlayerStats
		if st != null:
			speed = st.move_speed
	pawn.velocity.y = axis * speed


func _zero_all_vertical() -> void:
	for pawn: CharacterBody2D in _hunters:
		if pawn != null and is_instance_valid(pawn):
			pawn.velocity.y = 0.0


func _check_end() -> void:
	if _over:
		return
	var alive: Array[CharacterBody2D] = []
	for pawn: CharacterBody2D in _hunters:
		if _hp_of(pawn) > 0:
			alive.append(pawn)
	if alive.is_empty():
		_finish("Empate")
		return
	if alive.size() == 1:
		_finish("%s venceu" % _display_of(alive[0]))
		return
	if _time_left <= 0.0:
		_finish(_winner_by_hp())


func _winner_by_hp() -> String:
	var best_hp: int = -1
	var winners: Array[CharacterBody2D] = []
	for pawn: CharacterBody2D in _hunters:
		var h: int = _hp_of(pawn)
		if h > best_hp:
			best_hp = h
			winners = [pawn]
		elif h == best_hp:
			winners.append(pawn)
	if winners.size() != 1:
		return "Empate"
	return "%s venceu" % _display_of(winners[0])


func _on_hunter_died() -> void:
	_check_end()


func _finish(text: String) -> void:
	if _over:
		return
	_over = true
	_close_pause()
	for pawn: CharacterBody2D in _hunters:
		if pawn == null:
			continue
		pawn.set("accept_local_input", false)
		if pawn.has_method("apply_input_frame"):
			pawn.call("apply_input_frame", 0.0, 0, 0)
	if _hud != null and _hud.has_method("show_winner"):
		_hud.call("show_winner", text)
	print("[BrawlArena] fim: %s" % text)


func _toggle_pause() -> void:
	if _over:
		return
	if _pause_layer != null and is_instance_valid(_pause_layer):
		_close_pause()
		return
	get_tree().paused = true
	Engine.time_scale = 1.0
	_pause_layer = CanvasLayer.new()
	_pause_layer.name = "PauseMenu"
	_pause_layer.layer = 80
	_pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_pause_layer)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_layer.add_child(dim)
	var box := VBoxContainer.new()
	box.position = Vector2(440, 200)
	box.custom_minimum_size = Vector2(400, 260)
	box.add_theme_constant_override("separation", 14)
	_pause_layer.add_child(box)
	var title := Label.new()
	title.text = "PAUSA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Palette.CREAM)
	box.add_child(title)
	box.add_child(_pause_btn("Continuar", _close_pause))
	box.add_child(_pause_btn("De novo", restart_match))
	box.add_child(_pause_btn("Sair", leave_match))


func _pause_btn(text: String, cb: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 56)
	btn.process_mode = Node.PROCESS_MODE_ALWAYS
	btn.pressed.connect(cb)
	return btn


func _close_pause() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	if _pause_layer != null and is_instance_valid(_pause_layer):
		_pause_layer.queue_free()
	_pause_layer = null


func _hp_of(pawn: CharacterBody2D) -> int:
	if pawn == null or not is_instance_valid(pawn):
		return 0
	return int(pawn.get("hp"))


func _display_of(pawn: CharacterBody2D) -> String:
	if pawn == null:
		return "Caçador"
	var id: String = str(pawn.get("applied_character_id"))
	var def: CharacterDef = CharacterCatalog.find(id)
	if def != null and def.display_name != "":
		return def.display_name
	return id.capitalize()


func _attach_shadow(pawn: CharacterBody2D) -> void:
	var shadow := Polygon2D.new()
	shadow.name = "GroundShadow"
	shadow.z_index = -1
	shadow.color = Color(0.02, 0.03, 0.04, 0.42)
	var pts: PackedVector2Array = PackedVector2Array()
	var i: int = 0
	while i < 16:
		var ang: float = TAU * float(i) / 16.0
		pts.append(Vector2(cos(ang) * 28.0, sin(ang) * 10.0 + 4.0))
		i += 1
	shadow.polygon = pts
	pawn.add_child(shadow)


func _attach_nameplate(pawn: CharacterBody2D) -> void:
	var lab := Label.new()
	lab.name = "Nameplate"
	lab.position = Vector2(-70.0, -168.0)
	lab.size = Vector2(140.0, 22.0)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.add_theme_font_size_override("font_size", 14)
	lab.add_theme_color_override("font_color", Palette.CREAM)
	lab.add_theme_color_override("font_shadow_color", Palette.SHADOW)
	lab.add_theme_constant_override("shadow_offset_x", 1)
	lab.add_theme_constant_override("shadow_offset_y", 1)
	lab.text = _display_of(pawn)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pawn.add_child(lab)
