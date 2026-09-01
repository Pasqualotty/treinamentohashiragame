class_name BossCommon
extends RefCounted
## Helpers puros de chefe: fase por HP, telegraph, HUD, facing, coin drop.
## Funções pequenas (CRAP ≤ 15). Sem state machine — cada chefe só liga.

const PHASE_P1: int = 0
const PHASE_P2: int = 1
const PHASE_P3: int = 2
const P2_HP_RATIO: float = 0.6
const P3_HP_RATIO: float = 0.25
const HP_LAYER: int = 58
const BANNER_LAYER: int = 59


static func hp_ratio(hp: int, max_hp: int) -> float:
	if max_hp <= 0:
		return 0.0
	return clampf(float(hp) / float(max_hp), 0.0, 1.0)


static func phase_from_ratio(pct: float, p2_at: float = P2_HP_RATIO, p3_at: float = P3_HP_RATIO) -> int:
	if pct <= p3_at:
		return PHASE_P3
	if pct <= p2_at:
		return PHASE_P2
	return PHASE_P1


static func next_phase(current: int, hp: int, max_hp: int) -> int:
	var candidate: int = phase_from_ratio(hp_ratio(hp, max_hp))
	if candidate > current:
		return candidate
	return current


static func did_advance(current: int, nxt: int) -> bool:
	return nxt > current


static func phase_speed_mult(phase: int) -> float:
	match phase:
		PHASE_P2:
			return 0.88
		PHASE_P3:
			return 0.72
		_:
			return 1.0


static func phase_cooldown_mult(phase: int) -> float:
	match phase:
		PHASE_P2:
			return 0.8
		PHASE_P3:
			return 0.6
		_:
			return 1.0


static func phase_weight_mult(phase: int) -> float:
	match phase:
		PHASE_P2:
			return 1.15
		PHASE_P3:
			return 1.3
		_:
			return 1.0


static func telegraph_duration(base: float, phase: int) -> float:
	return maxf(0.0, base) * phase_speed_mult(phase)


static func recovery_duration(base: float, phase: int) -> float:
	var mult: float = 0.75 if phase == PHASE_P3 else 1.0
	return maxf(0.0, base) * mult


static func is_boss_kind(kind: String) -> bool:
	if kind == "boss":
		return true
	return kind.begins_with("boss_")


static func alive_count(nodes: Array) -> int:
	var n: int = 0
	for m: Variant in nodes:
		if m is Node and is_instance_valid(m):
			n += 1
	return n


static func disable_hitboxes(boxes: Array) -> void:
	for item: Variant in boxes:
		if item == null:
			continue
		if item is Hitbox:
			(item as Hitbox).disable()
		elif item is Object and (item as Object).has_method("disable"):
			item.call("disable")


static func arm_hitbox(hb: Hitbox, damage: int, knock: Vector2, pos_x: float, facing_dir: float = 0.0) -> void:
	if hb == null:
		return
	hb.damage = damage
	hb.knockback = knock
	if not is_zero_approx(facing_dir) and hb.has_method("set_facing"):
		hb.set_facing(facing_dir)
	hb.position.x = pos_x
	hb.enable()


static func is_hitbox_active(hb: Node) -> bool:
	if hb == null:
		return false
	if hb is Hitbox:
		return (hb as Hitbox).is_active()
	return false


static func apply_facing(sprite: Sprite2D, hitbox: Node2D, facing: float, hitbox_base_x: float) -> void:
	## Arte base olha pra esquerda: flip_h só quando facing > 0.
	if sprite:
		sprite.flip_h = facing > 0.0
	if hitbox:
		hitbox.position.x = hitbox_base_x * facing


static func find_player(tree: SceneTree) -> Node2D:
	if tree == null:
		return null
	var nodes: Array[Node] = tree.get_nodes_in_group("player")
	if nodes.is_empty():
		return null
	var n: Node = nodes[0]
	if n is Node2D:
		return n as Node2D
	return null


static func spawn_coin_drop(host: Node2D, coin_scene: PackedScene, reward: int, facing: float) -> Node:
	if host == null or coin_scene == null:
		return null
	var parent_node: Node = host.get_parent()
	if parent_node == null and host.get_tree():
		parent_node = host.get_tree().current_scene
	if parent_node == null:
		push_error("[BossCommon] sem parent pra drop de moeda")
		return null
	var coin: Node = coin_scene.instantiate()
	if coin == null:
		push_error("[BossCommon] falha ao instanciar coin_pickup")
		return null
	parent_node.add_child(coin)
	if coin is Node2D:
		(coin as Node2D).global_position = host.global_position + Vector2(facing * 12.0, -44.0)
		(coin as Node2D).z_index = 25
	if coin.has_method("setup"):
		coin.call("setup", reward)
	elif "value" in coin:
		coin.set("value", reward)
	return coin


static func attach_hp_bar(host: Node, boss_name: String, max_hp: int, hp: int, fill: Color = Color(0.77, 0.24, 0.24, 1.0)) -> Dictionary:
	var layer := CanvasLayer.new()
	layer.name = "BossHpLayer"
	layer.layer = HP_LAYER
	host.add_child(layer)
	layer.add_child(_make_hp_bg())
	var name_label: Label = _make_hp_name(boss_name)
	layer.add_child(name_label)
	var bar: ProgressBar = _make_hp_progress(max_hp, hp, fill)
	layer.add_child(bar)
	var text_label: Label = _make_hp_text()
	layer.add_child(text_label)
	var ui: Dictionary = {
		"layer": layer,
		"bar": bar,
		"name_label": name_label,
		"text_label": text_label,
	}
	refresh_hp(ui, hp, max_hp, null)
	return ui


static func refresh_hp(ui: Dictionary, hp: int, max_hp: int, floating: Label = null) -> void:
	var bar: ProgressBar = ui.get("bar", null) as ProgressBar
	if bar:
		bar.max_value = float(maxi(1, max_hp))
		bar.value = float(hp)
	var text_label: Label = ui.get("text_label", null) as Label
	if text_label:
		text_label.text = "%d / %d" % [hp, max_hp]
	if floating:
		floating.text = "HP %d/%d" % [hp, max_hp]


static func fade_hp_layer(host: Node, layer: CanvasLayer) -> void:
	if host == null or layer == null:
		return
	var tw: Tween = host.create_tween()
	tw.tween_interval(0.4)
	tw.set_parallel(true)
	for child: Node in layer.get_children():
		if child is CanvasItem:
			tw.tween_property(child, "modulate:a", 0.0, 0.5)


static func attach_banner(host: Node) -> Dictionary:
	var layer := CanvasLayer.new()
	layer.name = "BossBannerLayer"
	layer.layer = BANNER_LAYER
	host.add_child(layer)
	var bg := ColorRect.new()
	bg.name = "BossBannerBg"
	bg.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bg.offset_top = 300.0
	bg.offset_bottom = 372.0
	bg.color = Color(0.02, 0.03, 0.07, 0.0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(bg)
	var banner: Label = _make_banner_label()
	layer.add_child(banner)
	return {"layer": layer, "bg": bg, "banner": banner, "tween": null}


static func play_banner(host: Node, ui: Dictionary, text: String, color: Color, hold: float = 1.2) -> Tween:
	if host == null or not host.is_inside_tree():
		return null
	var banner: Label = ui.get("banner", null) as Label
	var bg: ColorRect = ui.get("bg", null) as ColorRect
	if banner == null:
		return null
	var prev: Tween = ui.get("tween", null) as Tween
	if prev != null and is_instance_valid(prev):
		prev.kill()
	banner.text = text
	banner.add_theme_color_override("font_color", color)
	banner.modulate = Color(1, 1, 1, 0)
	banner.scale = Vector2(0.7, 0.7)
	banner.pivot_offset = Vector2(banner.size.x * 0.5, banner.size.y * 0.5)
	if bg:
		bg.color = Color(0.02, 0.03, 0.07, 0.0)
	var tw: Tween = host.create_tween()
	_banner_in(tw, banner, bg)
	tw.set_parallel(false)
	tw.tween_property(banner, "scale", Vector2.ONE, 0.12)
	tw.tween_interval(maxf(0.15, hold - 0.5))
	_banner_out(tw, banner, bg)
	ui["tween"] = tw
	return tw


static func _banner_in(tw: Tween, banner: Label, bg: ColorRect) -> void:
	tw.set_parallel(true)
	tw.tween_property(banner, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(banner, "scale", Vector2(1.06, 1.06), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if bg:
		tw.tween_property(bg, "color:a", 0.5, 0.2)


static func _banner_out(tw: Tween, banner: Label, bg: ColorRect) -> void:
	tw.set_parallel(true)
	tw.tween_property(banner, "modulate:a", 0.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if bg:
		tw.tween_property(bg, "color:a", 0.0, 0.3)


static func _make_hp_bg() -> ColorRect:
	var bg := ColorRect.new()
	bg.name = "BossHpBg"
	bg.anchor_left = 0.5
	bg.anchor_right = 0.5
	bg.offset_left = -230.0
	bg.offset_right = 230.0
	bg.offset_top = 16.0
	bg.offset_bottom = 66.0
	bg.color = Color(0.05, 0.04, 0.09, 0.78)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bg


static func _make_hp_name(boss_name: String) -> Label:
	var lab := Label.new()
	lab.name = "BossNameLabel"
	lab.anchor_left = 0.5
	lab.anchor_right = 0.5
	lab.offset_left = -230.0
	lab.offset_right = 230.0
	lab.offset_top = 18.0
	lab.offset_bottom = 38.0
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.text = boss_name
	lab.add_theme_font_size_override("font_size", 16)
	lab.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6, 1.0))
	_shadow_label(lab)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lab


static func _make_hp_progress(max_hp: int, hp: int, fill: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.name = "BossHpBar"
	bar.anchor_left = 0.5
	bar.anchor_right = 0.5
	bar.offset_left = -214.0
	bar.offset_right = 214.0
	bar.offset_top = 40.0
	bar.offset_bottom = 60.0
	bar.show_percentage = false
	bar.max_value = float(maxi(1, max_hp))
	bar.value = float(hp)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg_box := StyleBoxFlat.new()
	bg_box.bg_color = Color(0.1, 0.05, 0.07, 0.95)
	bg_box.border_color = Color(0.55, 0.45, 0.2, 0.7)
	bg_box.set_border_width_all(1)
	bg_box.set_corner_radius_all(6)
	var fill_box := StyleBoxFlat.new()
	fill_box.bg_color = fill
	fill_box.set_corner_radius_all(5)
	bar.add_theme_stylebox_override("background", bg_box)
	bar.add_theme_stylebox_override("fill", fill_box)
	return bar


static func _make_hp_text() -> Label:
	var lab := Label.new()
	lab.name = "BossHpText"
	lab.anchor_left = 0.5
	lab.anchor_right = 0.5
	lab.offset_left = -214.0
	lab.offset_right = 214.0
	lab.offset_top = 40.0
	lab.offset_bottom = 60.0
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lab.add_theme_font_size_override("font_size", 13)
	lab.add_theme_color_override("font_color", Color(1, 0.95, 0.9, 1))
	_shadow_label(lab)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lab


static func _make_banner_label() -> Label:
	var banner := Label.new()
	banner.name = "BossBannerLabel"
	banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	banner.offset_top = 304.0
	banner.offset_bottom = 368.0
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.add_theme_font_size_override("font_size", 34)
	banner.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	banner.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	banner.add_theme_constant_override("shadow_offset_x", 2)
	banner.add_theme_constant_override("shadow_offset_y", 2)
	banner.add_theme_constant_override("outline_size", 4)
	banner.modulate.a = 0.0
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return banner


static func _shadow_label(lab: Label) -> void:
	lab.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	lab.add_theme_constant_override("shadow_offset_x", 1)
	lab.add_theme_constant_override("shadow_offset_y", 1)


static func tween_slam(host: Node, hb: Hitbox, dir: float, range_x: float, duration: float) -> void:
	if host == null or hb == null:
		return
	var tw: Tween = host.create_tween()
	tw.tween_property(hb, "position:x", dir * range_x, duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
