extends Control
## Evento da semana. Uma ação: Receber.

@onready var title_label: Label = %TitleLabel
@onready var desc_label: Label = %DescLabel
@onready var progress_label: Label = %ProgressLabel
@onready var status_label: Label = %StatusLabel
@onready var back_btn: Button = %BackButton
@onready var primary_btn: Button = %PrimaryButton

var _navigating: bool = false


func _ready() -> void:
	SafeInset.apply(self)
	var card: PanelContainer = get_node_or_null("Card") as PanelContainer
	if card != null:
		card.add_theme_stylebox_override("panel", MetaChrome.card_style())
	MetaChrome.apply_ghost(back_btn)
	MetaChrome.apply_cta(primary_btn)
	if not SceneRouter.navigation_failed.is_connected(_on_nav_failed):
		SceneRouter.navigation_failed.connect(_on_nav_failed)
	_refresh()


func _on_nav_failed(_path: String) -> void:
	_navigating = false


func _refresh() -> void:
	Game.sync_diario_calendar()
	var spec: Dictionary = WeekEvent.event_for_week(Game.event_week)
	var goal: int = int(spec.get("goal", 3))
	var have: int = mini(Game.event_clears, goal)
	title_label.text = str(spec.get("title", "Treino da semana"))
	desc_label.text = str(spec.get("desc", ""))
	progress_label.text = "%d/%d" % [have, goal]
	if Game.event_claimed:
		status_label.text = "Recompensa da semana já recebida."
		primary_btn.disabled = true
		primary_btn.text = "Receber"
		return
	if have >= goal:
		status_label.text = "Treino pronto. +%d XP." % int(spec.get("xp", 0))
		primary_btn.disabled = false
		primary_btn.text = "Receber"
		return
	status_label.text = "Limpe mais fases nesta semana."
	primary_btn.disabled = true
	primary_btn.text = "Receber"


func _on_primary_pressed() -> void:
	var result: Dictionary = Game.claim_week_event()
	if bool(result.get("ok", false)):
		status_label.text = "Recompensa guardada."
		if is_instance_valid(Audio):
			Audio.play_sfx("coin")
		_refresh()
		return
	if str(result.get("reason", "")) == "save_failed":
		status_label.text = Game.SAVE_FAIL_COPY
		return
	_refresh()


func _on_back_pressed() -> void:
	if _navigating:
		return
	_navigating = true
	if not SceneRouter.to_hub():
		_navigating = false
