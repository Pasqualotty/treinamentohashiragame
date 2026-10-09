extends Control
## Missões do dia. Cena só liga a regra pura e o save.

@onready var list: VBoxContainer = %MissionList
@onready var status_label: Label = %StatusLabel
@onready var back_btn: Button = %BackButton
@onready var primary_btn: Button = %PrimaryButton

var _navigating: bool = false
var _focus_id: String = ""
var _entered: bool = false


func _ready() -> void:
	SafeInset.apply(self)
	MetaChrome.setup_screen(self, "diario", get_node_or_null("Title") as Label, status_label, back_btn, primary_btn)
	if not SceneRouter.navigation_failed.is_connected(_on_nav_failed):
		SceneRouter.navigation_failed.connect(_on_nav_failed)
	_rebuild()


func _on_nav_failed(_path: String) -> void:
	_navigating = false


func _rebuild() -> void:
	Game.sync_diario_calendar()
	for child in list.get_children():
		child.queue_free()
	var first_ready: String = ""
	var cards: Array = []
	for spec: Dictionary in DailyMissions.missions_for_day(Game.mission_day):
		var mid: String = str(spec.get("id", ""))
		var card := _make_card(spec)
		list.add_child(card)
		cards.append(card)
		if first_ready.is_empty() and _can_claim(mid, spec):
			first_ready = mid
	if _focus_id.is_empty() or not _can_claim(_focus_id, DailyMissions.find_mission(Game.mission_day, _focus_id)):
		_focus_id = first_ready
	_refresh_status()
	_animate_cards(cards)


## Cascata só na primeira montagem — depois de Receber a lista não pisca de novo.
func _animate_cards(cards: Array) -> void:
	if _entered:
		return
	_entered = true
	UiMotion.enter_stagger(cards)


func _can_claim(mid: String, spec: Dictionary) -> bool:
	if spec.is_empty() or Game.is_mission_claimed(mid):
		return false
	return Game.mission_progress_of(mid) >= int(spec.get("goal", 1))


func _make_card(spec: Dictionary) -> Control:
	var mid: String = str(spec.get("id", ""))
	var goal: int = int(spec.get("goal", 1))
	var done: int = Game.mission_progress_of(mid)
	var claimed: bool = Game.is_mission_claimed(mid)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 88)
	panel.add_theme_stylebox_override("panel", MetaChrome.card_style())
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	panel.add_child(row)
	var title := Label.new()
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Palette.CREAM)
	title.text = str(spec.get("title", ""))
	row.add_child(title)
	var desc := Label.new()
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", Palette.with_alpha(Palette.CREAM, 0.78))
	var state: String = "Recebida" if claimed else "%d / %d" % [mini(done, goal), goal]
	desc.text = "%s  ·  %s" % [str(spec.get("desc", "")), state]
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(desc)
	if _can_claim(mid, spec):
		var pick := Button.new()
		pick.text = "Escolher"
		pick.custom_minimum_size = Vector2(0, 44)
		MetaChrome.apply_ghost(pick)
		pick.pressed.connect(func() -> void:
			_focus_id = mid
			_refresh_status()
		)
		UiMotion.press_bounce(pick)
		row.add_child(pick)
	return panel


func _refresh_status() -> void:
	if Game.all_daily_missions_claimed():
		status_label.text = Game.MISSIONS_DONE_COPY
		primary_btn.text = "Receber"
		primary_btn.disabled = true
		return
	var spec: Dictionary = DailyMissions.find_mission(Game.mission_day, _focus_id)
	if spec.is_empty():
		status_label.text = "Complete uma missão e toque em Receber."
		primary_btn.text = "Receber"
		primary_btn.disabled = true
		return
	if _can_claim(_focus_id, spec):
		status_label.text = "Pronta: %s. +%d XP e %d moedas." % [
			str(spec.get("title", "")), int(spec.get("xp", 0)), int(spec.get("coins", 0))
		]
		primary_btn.text = "Receber"
		primary_btn.disabled = false
		return
	status_label.text = "Ainda falta: %s." % str(spec.get("title", ""))
	primary_btn.text = "Receber"
	primary_btn.disabled = true


func _on_primary_pressed() -> void:
	var result: Dictionary = Game.claim_daily_mission(_focus_id)
	if bool(result.get("ok", false)):
		status_label.text = "Recompensa guardada."
		if is_instance_valid(Audio):
			Audio.play_sfx("coin")
		_rebuild()
		return
	if str(result.get("reason", "")) == "save_failed":
		status_label.text = Game.SAVE_FAIL_COPY
		return
	if str(result.get("reason", "")) == "already":
		status_label.text = "Essa já foi recebida."
		_rebuild()
		return
	_refresh_status()


func _on_back_pressed() -> void:
	if _navigating:
		return
	_navigating = true
	if not SceneRouter.to_hub():
		_navigating = false
