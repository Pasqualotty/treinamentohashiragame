extends Control
## Loja de upgrades — compra com coins_banked, persiste em Game.upgrades / save.json.

@onready var coins_label: Label = %CoinsLabel
@onready var status_label: Label = %StatusLabel
@onready var list: VBoxContainer = %UpgradeList


func _ready() -> void:
	if not Game.coins_changed.is_connected(_on_coins_changed):
		Game.coins_changed.connect(_on_coins_changed)
	if not Game.upgrades_changed.is_connected(_on_upgrades_changed):
		Game.upgrades_changed.connect(_on_upgrades_changed)
	_rebuild_list()
	_refresh_header()
	status_label.text = "Compre upgrades com moedas banked"


func _on_coins_changed(_total: int) -> void:
	_refresh_header()
	_refresh_row_states()


func _on_upgrades_changed() -> void:
	_refresh_header()
	_rebuild_list()


func _refresh_header() -> void:
	coins_label.text = "🪙 %d" % Game.coins_banked


func _rebuild_list() -> void:
	for child in list.get_children():
		child.queue_free()
	var catalog: Array[UpgradeDef] = Game.get_upgrade_catalog()
	for def in catalog:
		list.add_child(_make_row(def))


func _make_row(def: UpgradeDef) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 96)
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.with_alpha(Palette.PANEL, 0.92)
	style.border_color = Palette.with_alpha(Palette.GOLD, 0.55)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	panel.add_child(row)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 4)
	row.add_child(info)

	var title := Label.new()
	title.name = "Title"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.98, 0.93, 0.8, 1))
	info.add_child(title)

	var desc := Label.new()
	desc.name = "Desc"
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", Color(0.78, 0.8, 0.75, 1))
	desc.text = def.description
	info.add_child(desc)

	var level_lbl := Label.new()
	level_lbl.name = "Level"
	level_lbl.add_theme_font_size_override("font_size", 14)
	level_lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 0.95, 1))
	info.add_child(level_lbl)

	var buy := Button.new()
	buy.name = "BuyButton"
	buy.custom_minimum_size = Vector2(140, 48)
	buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	buy.pressed.connect(_on_buy_pressed.bind(def.id))
	row.add_child(buy)

	panel.set_meta("upgrade_id", def.id)
	_apply_row_state(panel, def)
	return panel


func _refresh_row_states() -> void:
	for child in list.get_children():
		if not child.has_meta("upgrade_id"):
			continue
		var uid: String = str(child.get_meta("upgrade_id"))
		var def: UpgradeDef = Game.get_upgrade_def(uid)
		if def:
			_apply_row_state(child, def)


func _apply_row_state(panel: Control, def: UpgradeDef) -> void:
	var level: int = Game.get_upgrade_level(def.id)
	var title: Label = panel.find_child("Title", true, false) as Label
	var level_lbl: Label = panel.find_child("Level", true, false) as Label
	var buy: Button = panel.find_child("BuyButton", true, false) as Button
	if title:
		title.text = def.display_name
	if level_lbl:
		level_lbl.text = "Nível %d / %d" % [level, def.max_level]
	if buy == null:
		return
	if def.is_maxed(level):
		buy.text = "MÁX"
		buy.disabled = true
	else:
		var cost: int = def.cost_for_next_level(level)
		buy.text = "Comprar\n🪙 %d" % cost
		buy.disabled = not Game.can_buy_upgrade(def.id)


func _on_buy_pressed(upgrade_id: String) -> void:
	if is_instance_valid(Audio):
		Audio.play_sfx("ui_click")
	if Game.buy_upgrade(upgrade_id):
		var def: UpgradeDef = Game.get_upgrade_def(upgrade_id)
		var name_str: String = def.display_name if def else upgrade_id
		status_label.text = "Comprou %s → nível %d" % [name_str, Game.get_upgrade_level(upgrade_id)]
		if is_instance_valid(Audio):
			Audio.play_sfx("coin")
	else:
		if Game.get_upgrade_def(upgrade_id) and Game.get_upgrade_def(upgrade_id).is_maxed(Game.get_upgrade_level(upgrade_id)):
			status_label.text = "Upgrade já no máximo"
		else:
			status_label.text = "Moedas insuficientes"


func _on_back_pressed() -> void:
	SceneRouter.to_hub()
