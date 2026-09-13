extends Node2D
## Duelo 1v1 de frente: um round, dois corpos, vencedor em PT.
## Porta própria — não passa pelo JOGAR / mapa.
## Com LanSession + peer: roster 2P, cada celular o seu. Sem dummy.
## F6 / smoke sem sessão: o 2º lutador é dummy local (InputFrame).
##
## Facing canônico (GDD): arte de combate olha ESQUERDA.
## `flip_h` só quando `_facing > 0`. Não inverter. Não flipar PNG.
##
## HUD próprio: vitalidade dos dois + ROUND. Sem ONDA / moeda de fase.

const TOUCH_SCENE := preload("res://scenes/ui/combat_touch_controls.tscn")
const _UiFont := preload("res://scripts/ui/ui_font.gd")
const CINZEL := preload("res://assets/fonts/Cinzel-Bold.ttf")

const TEAM_LEFT := &"duel_left"
const TEAM_RIGHT := &"duel_right"
const CHAR_LEFT := "inosuke"
const CHAR_RIGHT := "nezuko"

const FACE_RIGHT := 1.0
const FACE_LEFT := -1.0

const INTRO_SEC := 1.55
const DUMMY_REACH := 108.0
const DUMMY_ATK_CD := 0.9

## Player.State.IDLE / ATTACK_BASIC — não importar player.gd.
const STATE_IDLE := 0
const STATE_ATTACK := 4

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
@onready var _hp_left_bar: ProgressBar = %HpLeftBar
@onready var _hp_left_label: Label = %HpLeftLabel
@onready var _hp_right_bar: ProgressBar = %HpRightBar
@onready var _hp_right_label: Label = %HpRightLabel
@onready var _hp_left_block: PanelContainer = %HpLeft
@onready var _hp_right_block: PanelContainer = %HpRight

var _phase: Phase = Phase.INTRO
var _dummy_frozen: bool = true
var _dummy_atk_cd: float = 0.0
var _settled: bool = false
var _intro_left: float = INTRO_SEC


func _ready() -> void:
	_UiFont.ensure_theme_space()
	_apply_round_font()
	if _camera:
		_camera.make_current()
	_result_root.visible = false
	_round_label.text = TEXT_ROUND
	_round_label.visible = true
	_voltar.pressed.connect(_on_voltar)
	_style_duel_hud()
	var left_id: String = CHAR_LEFT
	var right_id: String = CHAR_RIGHT
	if _live_session():
		var ids: PackedStringArray = _ids_from_session()
		left_id = ids[0]
		right_id = ids[1]
		if _lan_peers():
			LanSession.mark_entered_stage()
	var local_slot: int = _local_slot()
	_prepare_fighter(_left, left_id, local_slot == 0, TEAM_LEFT, FACE_RIGHT)
	_prepare_fighter(_right, right_id, local_slot == 1, TEAM_RIGHT, FACE_LEFT)
	if _live_session() and _session_is_guest():
		if _left:
			_left.set("follow_host_snap", true)
			_left.set("accept_local_input", false)
		if _right:
			_right.set("follow_host_snap", true)
			_right.set("accept_local_input", false)
	_bind_hp(_left, _hp_left_bar, _hp_left_label, _on_left_hp)
	_bind_hp(_right, _hp_right_bar, _hp_right_label, _on_right_hp)
	_set_locked(true)
	_pose_intro()
	_spawn_touch()
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


func uses_lan_roster() -> bool:
	return _live_session()


func is_dummy_active() -> bool:
	return not _live_session()


func _apply_round_font() -> void:
	var fv := FontVariation.new()
	fv.base_font = CINZEL
	fv.spacing_space = _UiFont.SPACE_PAD_PX
	if _round_label:
		_round_label.add_theme_font_override("font", fv)
	if _result_label:
		_result_label.add_theme_font_override("font", fv)


func _style_duel_hud() -> void:
	_style_hp_panel(_hp_left_block)
	_style_hp_panel(_hp_right_block)
	_style_hp_bar(_hp_left_bar)
	_style_hp_bar(_hp_right_bar)


func _style_hp_panel(block: PanelContainer) -> void:
	if block == null:
		return
	var panel := StyleBoxFlat.new()
	panel.bg_color = Palette.with_alpha(Palette.PANEL, 0.78)
	panel.border_color = Palette.with_alpha(Palette.GOLD, 0.6)
	panel.set_border_width_all(2)
	panel.set_corner_radius_all(10)
	panel.content_margin_left = 10
	panel.content_margin_right = 10
	panel.content_margin_top = 6
	panel.content_margin_bottom = 8
	panel.shadow_color = Color(0, 0, 0, 0.35)
	panel.shadow_size = 4
	block.add_theme_stylebox_override("panel", panel)


func _style_hp_bar(bar: ProgressBar) -> void:
	if bar == null:
		return
	var bg_box := StyleBoxFlat.new()
	bg_box.bg_color = Palette.with_alpha(Palette.CRIMSON_DIM, 0.95)
	bg_box.border_color = Palette.with_alpha(Palette.GOLD, 0.5)
	bg_box.set_border_width_all(1)
	bg_box.set_corner_radius_all(8)
	bg_box.content_margin_left = 3
	bg_box.content_margin_top = 3
	bg_box.content_margin_right = 3
	bg_box.content_margin_bottom = 3
	var fill_box := StyleBoxFlat.new()
	fill_box.bg_color = Palette.CRIMSON
	fill_box.set_corner_radius_all(6)
	fill_box.border_color = Palette.CRIMSON_BRIGHT
	fill_box.border_width_top = 2
	bar.add_theme_stylebox_override("background", bg_box)
	bar.add_theme_stylebox_override("fill", fill_box)
	bar.show_percentage = false


func _bind_hp(fighter: Node, bar: ProgressBar, label: Label, cb: Callable) -> void:
	_refresh_hp_widgets(fighter, bar, label)
	if fighter and fighter.has_signal("hp_changed") and not fighter.is_connected("hp_changed", cb):
		fighter.connect("hp_changed", cb)


func _on_left_hp(current: int, max_hp: int) -> void:
	_set_hp_widgets(_hp_left_bar, _hp_left_label, current, max_hp)


func _on_right_hp(current: int, max_hp: int) -> void:
	_set_hp_widgets(_hp_right_bar, _hp_right_label, current, max_hp)


func _refresh_hp_widgets(fighter: Node, bar: ProgressBar, label: Label) -> void:
	if fighter == null or not fighter.has_method("get_hp"):
		return
	_set_hp_widgets(bar, label, int(fighter.call("get_hp")), int(fighter.call("get_max_hp")))


func _set_hp_widgets(bar: ProgressBar, label: Label, current: int, max_hp: int) -> void:
	var mx: float = maxf(float(max_hp), 1.0)
	if bar:
		bar.max_value = mx
		bar.value = clampf(float(current), 0.0, mx)
	if label:
		label.text = "%d / %d" % [current, max_hp]


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
	var left_fb: String = CHAR_LEFT
	if _live_session() and is_instance_valid(Game):
		var mine: String = str(Game.current_character_id)
		if not mine.is_empty():
			left_fb = mine
	var ids := PackedStringArray([left_fb, CHAR_RIGHT])
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
	_snap_fighter(fighter, dir, STATE_IDLE)


func _snap_fighter(fighter: Node, dir: float, state_id: int) -> void:
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
	fighter.call("apply_host_snap", body.global_position, 0.0, dir, state_id, hp_now, breath, breath_m)


func _pose_intro() -> void:
	## Inosuke: pose de ataque (2 lâminas estendidas). Nezuko idle, PNG intocado.
	if _left:
		_left.set("follow_host_snap", true)
		_snap_fighter(_left, FACE_RIGHT, STATE_ATTACK)
		_freeze_attack_frame(_left, 0)
		_disable_hitbox(_left)
	if _right:
		_right.set("follow_host_snap", true)
		_snap_fighter(_right, FACE_LEFT, STATE_IDLE)


func _freeze_attack_frame(fighter: Node, frame_i: int) -> void:
	var spr: AnimatedSprite2D = fighter.find_child("AnimatedSprite2D", true, false) as AnimatedSprite2D
	if spr == null or spr.sprite_frames == null:
		return
	if not spr.sprite_frames.has_animation(&"attack"):
		return
	spr.play(&"attack")
	spr.pause()
	var count: int = spr.sprite_frames.get_frame_count(&"attack")
	if count > 0:
		spr.frame = clampi(frame_i, 0, count - 1)


func _disable_hitbox(fighter: Node) -> void:
	var hit: Node = fighter.get_node_or_null("Hitbox")
	if hit and hit.has_method("disable"):
		hit.call("disable")


func _set_locked(locked: bool) -> void:
	_dummy_frozen = locked
	var allow: bool = (not locked) and _phase != Phase.RESULT
	if _left:
		_left.set("accept_local_input", allow and _controls_locally(0))
		if locked and _left is CharacterBody2D:
			(_left as CharacterBody2D).velocity = Vector2.ZERO
	if _right:
		_right.set("accept_local_input", allow and _controls_locally(1))
		if locked and _right is CharacterBody2D:
			(_right as CharacterBody2D).velocity = Vector2.ZERO
		if locked and _right.has_method("apply_input_frame"):
			_right.call("apply_input_frame", 0.0, 0, 0)


func _begin_fight() -> void:
	if _phase != Phase.INTRO:
		return
	_phase = Phase.FIGHT
	if not (_live_session() and _session_is_guest()):
		if _left:
			_left.set("follow_host_snap", false)
		if _right:
			_right.set("follow_host_snap", false)
	_set_locked(false)
	_snap_fighter(_left, FACE_RIGHT, STATE_IDLE)
	_snap_fighter(_right, FACE_LEFT, STATE_IDLE)


func _tick_dummy() -> void:
	if _live_session():
		return
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


func _spawn_touch() -> void:
	var touch: CanvasLayer = TOUCH_SCENE.instantiate() as CanvasLayer
	add_child(touch)


func _on_voltar() -> void:
	if is_instance_valid(SceneRouter) and SceneRouter.has_method("to_hub"):
		SceneRouter.to_hub()
		return
	get_tree().change_scene_to_file("res://scenes/main_menu/hub.tscn")
