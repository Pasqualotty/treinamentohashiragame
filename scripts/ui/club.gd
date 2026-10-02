extends Control
## Clube local. Nome no aparelho + amigos do save. Sem IP.

@onready var name_input: LineEdit = %NameInput
@onready var friend_list: VBoxContainer = %FriendList
@onready var empty_label: Label = %EmptyLabel
@onready var status_label: Label = %StatusLabel
@onready var back_btn: Button = %BackButton
@onready var primary_btn: Button = %PrimaryButton

var _navigating: bool = false


func _ready() -> void:
	SafeInset.apply(self)
	MetaChrome.apply_ghost(back_btn)
	MetaChrome.apply_cta(primary_btn)
	MetaChrome.apply_line_edit(name_input)
	name_input.max_length = Game.MAX_PLAYER_NAME_LEN
	name_input.text = Game.get_club_name()
	if not SceneRouter.navigation_failed.is_connected(_on_nav_failed):
		SceneRouter.navigation_failed.connect(_on_nav_failed)
	_rebuild_friends()
	status_label.text = "Nome só neste aparelho."


func _on_nav_failed(_path: String) -> void:
	_navigating = false


func _rebuild_friends() -> void:
	for child in friend_list.get_children():
		child.queue_free()
	var names: Array[String] = []
	for d: Dictionary in Game.friends:
		var n := Game.sanitize_player_name(str(d.get("name", "")))
		if not n.is_empty():
			names.append(n)
	empty_label.visible = names.is_empty()
	empty_label.text = "Chama alguém em Amigos."
	for n in names:
		var row := PanelContainer.new()
		row.custom_minimum_size = Vector2(0, 48)
		row.add_theme_stylebox_override("panel", MetaChrome.card_style())
		var lab := Label.new()
		lab.text = n
		lab.add_theme_font_size_override("font_size", 18)
		lab.add_theme_color_override("font_color", Palette.CREAM)
		row.add_child(lab)
		friend_list.add_child(row)


func _on_primary_pressed() -> void:
	var result: Dictionary = Game.set_club_name(name_input.text)
	if bool(result.get("ok", false)):
		name_input.text = Game.get_club_name()
		status_label.text = "Nome do clube guardado."
		return
	if str(result.get("reason", "")) == "save_failed":
		status_label.text = Game.SAVE_FAIL_COPY
		return
	status_label.text = "Escreve um nome visível."


func _on_back_pressed() -> void:
	if _navigating:
		return
	_navigating = true
	if not SceneRouter.to_hub():
		_navigating = false
