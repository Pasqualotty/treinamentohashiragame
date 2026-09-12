extends Node2D
## Arena placeholder do modo batalha (feel Brawl): plano 2D, PvP.
## Com LanSession + peer: roster 2P, cada celular o seu. Sem dummy.
## F6 / smoke sem sessão: dummy local no 2º corpo.

const PLAYER_SCENE: PackedScene = preload("res://scenes/characters/player/player.tscn")
const TOUCH_SCENE: PackedScene = preload("res://scenes/ui/combat_touch_controls.tscn")
const HUD_SCRIPT: Script = preload("res://scripts/modes/brawl/brawl_hud.gd")
const BOT_SCRIPT: Script = preload("res://scripts/modes/brawl/brawl_bot.gd")

const MATCH_TIME: float = 90.0
const DEFAULT_IDS: PackedStringArray = ["inosuke", "nezuko"]
const SPAWN_P1 := Vector2(380.0, 430.0)
const SPAWN_P2 := Vector2(900.0, 430.0)

var _p1: CharacterBody2D
var _p2: CharacterBody2D
var _bot: Node
var _hud: CanvasLayer
var _time_left: float = MATCH_TIME
var _over: bool = false
var _roster: PackedStringArray = DEFAULT_IDS
var _debug_vertical_on: Array[bool] = [false, false]
var _debug_vertical: PackedFloat32Array = PackedFloat32Array([0.0, 0.0])


func _ready() -> void:
	process_priority = -10
	var cam: Camera2D = get_node_or_null("Camera2D") as Camera2D
	if cam:
		cam.make_current()
	_roster = _resolve_roster()
	_time_left = _resolve_match_time()
	if _lan_peers():
		LanSession.mark_entered_stage()
	_spawn_hunters()
	_patch_pvp(_p1, 0)
	_patch_pvp(_p2, 1)
	_wire_death(_p1)
	_wire_death(_p2)
	_attach_bot()
	_spawn_hud()
	_spawn_touch()
	_face_each_other()
	if is_instance_valid(Audio) and Audio.has_method("play_bgm"):
		Audio.play_bgm("stage")
	if uses_lan_roster():
		print("[BrawlArena] sessão roster=%s vs %s dummy=nao" % [_roster[0], _roster[1]])
	else:
		print("[BrawlArena] F6 standalone roster=%s vs %s" % [_roster[0], _roster[1]])


func _physics_process(delta: float) -> void:
	if _over:
		_zero_vertical(_p1)
		_zero_vertical(_p2)
		return
	_time_left = maxf(0.0, _time_left - delta)
	if _hud != null and _hud.has_method("set_time_left"):
		_hud.call("set_time_left", _time_left)
	_apply_plane_vertical(_p1, _axis_for(0, _local_vertical_axis()))
	var bot_v: float = 0.0
	if _bot != null:
		bot_v = float(_bot.get("desired_vertical"))
	_apply_plane_vertical(_p2, _axis_for(1, bot_v))
	_check_end()


func get_hunter(slot: int) -> CharacterBody2D:
	if slot == 0:
		return _p1
	return _p2


func get_hunters() -> Array[CharacterBody2D]:
	var out: Array[CharacterBody2D] = []
	if _p1 != null:
		out.append(_p1)
	if _p2 != null:
		out.append(_p2)
	return out


func is_match_over() -> bool:
	return _over


func get_time_left() -> float:
	return _time_left


func uses_lan_roster() -> bool:
	return _live_session()


func has_dummy() -> bool:
	return _bot != null and is_instance_valid(_bot)


func hunter_team(slot: int) -> StringName:
	var pawn: CharacterBody2D = get_hunter(slot)
	if pawn == null:
		return &""
	var hit: Hitbox = pawn.get_node_or_null("%Hitbox") as Hitbox
	if hit == null:
		return &""
	return hit.team


func debug_pause_bot() -> void:
	if _bot != null:
		_bot.set_physics_process(false)
		_bot.set("desired_vertical", 0.0)
	_debug_vertical_on[0] = true
	_debug_vertical[0] = 0.0
	_debug_vertical_on[1] = true
	_debug_vertical[1] = 0.0
	if _p1:
		_p1.velocity = Vector2.ZERO
	if _p2:
		_p2.velocity = Vector2.ZERO


func debug_set_vertical(slot: int, axis: float) -> void:
	if slot < 0 or slot > 1:
		return
	_debug_vertical_on[slot] = true
	_debug_vertical[slot] = axis
	_apply_plane_vertical(get_hunter(slot), axis)


func _axis_for(slot: int, fallback: float) -> float:
	if slot >= 0 and slot < _debug_vertical_on.size() and _debug_vertical_on[slot]:
		return _debug_vertical[slot]
	return fallback


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


func _ids_from_session() -> PackedStringArray:
	var ids := PackedStringArray(["tanjiro", "nezuko"])
	if has_meta("smoke_lan_roster"):
		var raw: Variant = get_meta("smoke_lan_roster")
		if raw is Dictionary:
			var meta := raw as Dictionary
			ids[0] = str(meta.get("char_0", ids[0]))
			ids[1] = str(meta.get("char_1", ids[1]))
			return ids
	if not is_instance_valid(LanSession):
		return ids
	var roster: Array = LanSession.get_roster()
	for item: Variant in roster:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var rec := item as Dictionary
		var slot: int = int(rec.get("slot", -1))
		if slot == 0 or slot == 1:
			ids[slot] = str(rec.get("char_id", ids[slot]))
	return ids


func _resolve_roster() -> PackedStringArray:
	if _live_session():
		var from_lan: PackedStringArray = _ids_from_session()
		if from_lan.size() >= 2:
			return from_lan
	var gm: Node = get_node_or_null("/root/GameMode")
	if gm != null:
		var from_prop: Variant = gm.get("brawl_ids")
		var parsed: PackedStringArray = _as_id_pair(from_prop)
		if parsed.size() >= 2:
			return parsed
		if gm.has_method("get_brawl_roster"):
			parsed = _as_id_pair(gm.call("get_brawl_roster"))
			if parsed.size() >= 2:
				return parsed
	return DEFAULT_IDS


func _resolve_match_time() -> float:
	var gm: Node = get_node_or_null("/root/GameMode")
	if gm != null:
		var t: Variant = gm.get("brawl_match_time")
		if t != null and float(t) > 5.0:
			return float(t)
	return MATCH_TIME


func _as_id_pair(raw: Variant) -> PackedStringArray:
	var out: PackedStringArray = []
	if raw is PackedStringArray:
		out = raw
	elif raw is Array:
		for item: Variant in raw:
			out.append(str(item))
	if out.size() < 2:
		return PackedStringArray()
	return PackedStringArray([out[0], out[1]])


func _spawn_hunters() -> void:
	var host: Node = get_node_or_null("Hunters")
	if host == null:
		host = Node2D.new()
		host.name = "Hunters"
		add_child(host)
	if host is Node2D:
		(host as Node2D).y_sort_enabled = true
	_p1 = _make_hunter(0, _roster[0], _controls_locally(0))
	_p2 = _make_hunter(1, _roster[1], _controls_locally(1))
	host.add_child(_p1)
	host.add_child(_p2)
	_p1.global_position = SPAWN_P1
	_p2.global_position = SPAWN_P2
	_attach_shadow(_p1)
	_attach_shadow(_p2)
	_attach_nameplate(_p1)
	_attach_nameplate(_p2)


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


func _attach_bot() -> void:
	if _live_session():
		return
	_bot = BOT_SCRIPT.new()
	_bot.name = "BrawlBot"
	add_child(_bot)
	if _bot.has_method("setup"):
		_bot.call("setup", _p2, _p1)


func _spawn_hud() -> void:
	_hud = HUD_SCRIPT.new() as CanvasLayer
	_hud.name = "BrawlHud"
	add_child(_hud)
	if _hud.has_method("bind_hunters"):
		_hud.call("bind_hunters", _p1, _p2)
	if _hud.has_method("set_time_left"):
		_hud.call("set_time_left", _time_left)


func _spawn_touch() -> void:
	var touch: CanvasLayer = TOUCH_SCENE.instantiate() as CanvasLayer
	touch.name = "CombatTouchControls"
	add_child(touch)


func _face_each_other() -> void:
	if _p1 != null and _p1.has_method("apply_input_frame"):
		_p1.call("apply_input_frame", 1.0, 0, 0)
	if _p2 != null and _p2.has_method("apply_input_frame"):
		_p2.call("apply_input_frame", -1.0, 0, 0)


func _local_vertical_axis() -> float:
	if _p1 == null or not bool(_p1.get("accept_local_input")):
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
	var st: PlayerStats = pawn.get("stats") as PlayerStats
	if st != null:
		speed = st.move_speed
	pawn.velocity.y = axis * speed


func _zero_vertical(pawn: CharacterBody2D) -> void:
	if pawn != null and is_instance_valid(pawn):
		pawn.velocity.y = 0.0


func _check_end() -> void:
	if _over:
		return
	var h1: int = _hp_of(_p1)
	var h2: int = _hp_of(_p2)
	if h1 <= 0 and h2 <= 0:
		_finish("Empate")
		return
	if h1 <= 0:
		_finish("%s venceu" % _display_of(_p2))
		return
	if h2 <= 0:
		_finish("%s venceu" % _display_of(_p1))
		return
	if _time_left <= 0.0:
		if h1 == h2:
			_finish("Empate")
		elif h1 > h2:
			_finish("%s venceu" % _display_of(_p1))
		else:
			_finish("%s venceu" % _display_of(_p2))


func _on_hunter_died() -> void:
	_check_end()


func _finish(text: String) -> void:
	if _over:
		return
	_over = true
	if _p1 != null and _p1.has_method("apply_input_frame"):
		_p1.set("accept_local_input", false)
		_p1.call("apply_input_frame", 0.0, 0, 0)
	if _p2 != null and _p2.has_method("apply_input_frame"):
		_p2.call("apply_input_frame", 0.0, 0, 0)
	if _hud != null and _hud.has_method("show_winner"):
		_hud.call("show_winner", text)
	print("[BrawlArena] fim: %s" % text)


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
