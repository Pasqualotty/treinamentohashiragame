extends Control
## Loja de upgrades — compra com coins_banked, persiste em Game.upgrades / save.json.
## Cards com ícone por atributo, preview "antes → depois" do efeito, animação de
## compra (pop dourado) e feedback de moedas insuficientes (shake).

@onready var coins_label: Label = %CoinsLabel
@onready var status_label: Label = %StatusLabel
@onready var list: VBoxContainer = %UpgradeList

## stat_key -> símbolo do card (sem asset novo, consistente com emoji já usado no hub/HUD).
const STAT_ICONS := {
	"max_hp": "❤",
	"attack_damage": "⚔",
	"move_speed": "💨",
	"dash_cooldown": "🌀",
}

var _stat_icon_colors: Dictionary = {}


func _ready() -> void:
	_stat_icon_colors = {
		"max_hp": Palette.CRIMSON_BRIGHT,
		"attack_damage": Palette.GOLD_BRIGHT,
		"move_speed": Palette.WATER_BRIGHT,
		"dash_cooldown": Palette.WATER_BRIGHT,
	}
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
	# Refresh in-place (não recria os nós) pra não cortar a animação de compra
	# disparada pelo próprio _on_buy_pressed no mesmo frame.
	_refresh_header()
	_refresh_row_states()


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
	panel.custom_minimum_size = Vector2(0, 104)
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

	row.add_child(_make_icon_badge(def))

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

	var bottom_row := HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", 14)
	info.add_child(bottom_row)

	var level_lbl := Label.new()
	level_lbl.name = "Level"
	level_lbl.add_theme_font_size_override("font_size", 14)
	level_lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 0.95, 1))
	bottom_row.add_child(level_lbl)

	var preview_lbl := Label.new()
	preview_lbl.name = "Preview"
	preview_lbl.add_theme_font_size_override("font_size", 14)
	preview_lbl.add_theme_color_override("font_color", Palette.GOLD_BRIGHT)
	bottom_row.add_child(preview_lbl)

	var buy := Button.new()
	buy.name = "BuyButton"
	buy.custom_minimum_size = Vector2(140, 48)
	buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	buy.pressed.connect(_on_buy_pressed.bind(def.id))
	row.add_child(buy)

	panel.set_meta("upgrade_id", def.id)
	_apply_row_state(panel, def)
	return panel


func _make_icon_badge(def: UpgradeDef) -> Control:
	var wrap := PanelContainer.new()
	wrap.name = "IconWrap"
	wrap.custom_minimum_size = Vector2(56, 56)
	wrap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var badge_col: Color = _stat_icon_colors.get(def.stat_key, Palette.GOLD)
	var icon_style := StyleBoxFlat.new()
	icon_style.bg_color = Palette.with_alpha(badge_col, 0.22)
	icon_style.border_color = Palette.with_alpha(badge_col, 0.85)
	icon_style.set_border_width_all(2)
	icon_style.set_corner_radius_all(28)
	wrap.add_theme_stylebox_override("panel", icon_style)
	var icon_lbl := Label.new()
	icon_lbl.text = str(STAT_ICONS.get(def.stat_key, "★"))
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_lbl.add_theme_font_size_override("font_size", 24)
	wrap.add_child(icon_lbl)
	return wrap


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
	var preview_lbl: Label = panel.find_child("Preview", true, false) as Label
	var buy: Button = panel.find_child("BuyButton", true, false) as Button
	if title:
		title.text = def.display_name
	if level_lbl:
		level_lbl.text = "Nível %d / %d" % [level, def.max_level]
	if preview_lbl:
		preview_lbl.text = _format_preview(def, level)
	if buy == null:
		return
	if def.is_maxed(level):
		buy.text = "MÁX"
		buy.disabled = true
	else:
		var cost: int = def.cost_for_next_level(level)
		buy.text = "Comprar\n🪙 %d" % cost
		buy.disabled = not Game.can_buy_upgrade(def.id)


func _format_preview(def: UpgradeDef, level: int) -> String:
	if def.is_maxed(level):
		return ""
	var stats: PlayerStats = Game.build_player_stats()
	if stats == null:
		return ""
	var current_val: float = float(stats.get(def.stat_key))
	var next_val: float = current_val + def.value_per_level
	if def.stat_key == "dash_cooldown":
		return "%.2fs → %.2fs" % [current_val, next_val]
	return "%d → %d" % [int(round(current_val)), int(round(next_val))]


func _find_row(upgrade_id: String) -> Control:
	for child in list.get_children():
		if child.has_meta("upgrade_id") and str(child.get_meta("upgrade_id")) == upgrade_id:
			return child
	return null


func _on_buy_pressed(upgrade_id: String) -> void:
	if is_instance_valid(Audio):
		Audio.play_sfx("ui_click")
	var panel: Control = _find_row(upgrade_id)
	if Game.buy_upgrade(upgrade_id):
		var def: UpgradeDef = Game.get_upgrade_def(upgrade_id)
		var name_str: String = def.display_name if def else upgrade_id
		status_label.text = "Comprou %s → nível %d" % [name_str, Game.get_upgrade_level(upgrade_id)]
		if is_instance_valid(Audio):
			Audio.play_sfx("coin")
		_play_purchase_feedback(panel)
	else:
		if Game.get_upgrade_def(upgrade_id) and Game.get_upgrade_def(upgrade_id).is_maxed(Game.get_upgrade_level(upgrade_id)):
			status_label.text = "Upgrade já no máximo"
		else:
			status_label.text = "Moedas insuficientes"
			_play_insufficient_feedback(panel)


## Pop dourado no card comprado — confirma a compra sem precisar de texto extra.
func _play_purchase_feedback(panel: Control) -> void:
	if panel == null:
		return
	panel.pivot_offset = panel.size * 0.5
	var tw: Tween = create_tween()
	tw.tween_property(panel, "scale", Vector2(1.045, 1.045), 0.1) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(panel, "self_modulate", Palette.GOLD_BRIGHT, 0.1)
	tw.chain().tween_property(panel, "self_modulate", Color(1, 1, 1, 1), 0.35)


## Shake (via rotation, não position — evita brigar com o VBoxContainer) + flash
## vermelho quando faltam moedas.
func _play_insufficient_feedback(panel: Control) -> void:
	if panel == null:
		return
	panel.pivot_offset = panel.size * 0.5
	var tw: Tween = create_tween()
	for i in range(3):
		tw.tween_property(panel, "rotation", deg_to_rad(2.2), 0.045)
		tw.tween_property(panel, "rotation", deg_to_rad(-2.2), 0.045)
	tw.tween_property(panel, "rotation", 0.0, 0.04)
	tw.parallel().tween_property(panel, "self_modulate", Palette.CRIMSON_BRIGHT, 0.06)
	tw.chain().tween_property(panel, "self_modulate", Color(1, 1, 1, 1), 0.3)


func _on_back_pressed() -> void:
	SceneRouter.to_hub()
