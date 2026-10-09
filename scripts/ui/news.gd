extends Control
## Notícias estáticas. Toque abre o texto.

@onready var list: VBoxContainer = %NewsList
@onready var body_label: Label = %BodyLabel
@onready var status_label: Label = %StatusLabel
@onready var back_btn: Button = %BackButton
@onready var primary_btn: Button = %PrimaryButton

var _navigating: bool = false
var _open_id: String = ""


func _ready() -> void:
	SafeInset.apply(self)
	var body_panel: PanelContainer = get_node_or_null("Columns/BodyPanel") as PanelContainer
	if body_panel != null:
		body_panel.add_theme_stylebox_override("panel", MetaChrome.card_style())
	MetaChrome.setup_screen(self, "diario", get_node_or_null("Title") as Label, status_label, back_btn, primary_btn)
	if not SceneRouter.navigation_failed.is_connected(_on_nav_failed):
		SceneRouter.navigation_failed.connect(_on_nav_failed)
	_rebuild()
	var arts: Array[Dictionary] = HunterNews.articles()
	if not arts.is_empty():
		_open_id = str(arts[0].get("id", ""))
	_show_open()


func _on_nav_failed(_path: String) -> void:
	_navigating = false


func _rebuild() -> void:
	for child in list.get_children():
		child.queue_free()
	var buttons: Array = []
	for art: Dictionary in HunterNews.articles():
		var aid: String = str(art.get("id", ""))
		var btn := Button.new()
		btn.text = str(art.get("title", ""))
		btn.custom_minimum_size = Vector2(0, 52)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		MetaChrome.apply_ghost(btn)
		btn.pressed.connect(_open.bind(aid))
		UiMotion.press_bounce(btn)
		list.add_child(btn)
		buttons.append(btn)
	UiMotion.enter_stagger(buttons)


func _open(article_id: String) -> void:
	_open_id = article_id
	_show_open()


func _show_open() -> void:
	var art: Dictionary = HunterNews.find_article(_open_id)
	if art.is_empty():
		body_label.text = "Toque numa notícia para ler."
		status_label.text = "Nada selecionado."
		primary_btn.disabled = HunterNews.articles().is_empty()
		return
	body_label.text = str(art.get("body", ""))
	status_label.text = str(art.get("title", ""))
	primary_btn.disabled = false
	primary_btn.text = "Ler"


func _on_primary_pressed() -> void:
	if _open_id.is_empty():
		var arts: Array[Dictionary] = HunterNews.articles()
		if arts.is_empty():
			return
		_open_id = str(arts[0].get("id", ""))
	_show_open()


func _on_back_pressed() -> void:
	if _navigating:
		return
	_navigating = true
	if not SceneRouter.to_hub():
		_navigating = false
