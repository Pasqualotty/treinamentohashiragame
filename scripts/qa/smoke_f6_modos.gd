extends SceneTree
## F6 modos: HUD do brawl (chrome, Cinzel, chip, rastro), tela final, duelo e despill.
## Uso: godot --headless --path . -s res://scripts/qa/smoke_f6_modos.gd

const ARENA := "res://scenes/modes/brawl/brawl_arena.tscn"
const DUEL := "res://scenes/modes/duel/duel.tscn"
const MODES_DIR := "res://assets/modes"
const MAGENTA_MAX: int = 30

var _failed: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok %s" % msg)
		return
	_failed += 1
	print("  FAIL %s" % msg)


func _run() -> void:
	await _brawl()
	await _duel()
	_despill()
	if _failed == 0:
		print("=== F6 MODOS PASS ===")
		quit(0)
	else:
		print("=== F6 MODOS FAIL (%d) ===" % _failed)
		quit(1)


func _brawl() -> void:
	var arena: Node = (load(ARENA) as PackedScene).instantiate()
	root.add_child(arena)
	await create_timer(1.6).timeout
	var hud: Node = arena.get_node("BrawlHud")
	_check_blocks(hud)
	_check_chip(hud)
	_check_no_label_over_nametags(arena)
	await _check_trail(arena, hud)
	_check_winner(hud)
	arena.queue_free()
	await process_frame


func _check_blocks(hud: Node) -> void:
	var panels: Array[PanelContainer] = []
	for n: Node in hud.find_children("*", "PanelContainer", true, false):
		if n.name != "TimeChip" and n.find_child("NameLabel", true, false) != null:
			panels.append(n as PanelContainer)
	_check(panels.size() == 4, "4 blocos de caçador são PanelContainer (%d)" % panels.size())
	var lbl: Label = panels[0].find_child("NameLabel", true, false) as Label
	var font: Font = lbl.get_theme_font("font")
	_check(font != null and _font_path(font).contains("Cinzel"), "nome usa Cinzel")
	_check(lbl.get_theme_font_size("font_size") == 16, "nome em tamanho 16")
	var tick: Array[Node] = panels[0].find_children("*", "BarTicks", true, false)
	_check(tick.size() == 1, "respiração com BarTicks")
	_check(_has_local_border(panels), "borda do jogador local é a mais forte")


func _has_local_border(panels: Array[PanelContainer]) -> bool:
	var strong: int = 0
	for p: PanelContainer in panels:
		var sb := p.get_theme_stylebox("panel") as StyleBoxFlat
		if sb.border_color.a > 0.9:
			strong += 1
	return strong == 1


func _font_path(font: Font) -> String:
	if font is FontVariation:
		return (font as FontVariation).base_font.resource_path
	return font.resource_path


func _check_chip(hud: Node) -> void:
	var chip: Node = hud.find_child("TimeChip", true, false)
	_check(chip is PanelContainer, "chip do tempo é PanelContainer")
	var lbl := chip.find_child("TimeLabel", true, false) as Label
	_check(lbl != null and _font_path(lbl.get_theme_font("font")).contains("Cinzel"), "tempo em Cinzel")
	hud.call("set_time_left", 5.0)
	_check(lbl.get_theme_color("font_color") == Color(0.94, 0.4, 0.38, 1.0), "abaixo de 10 s fica carmesim")
	hud.call("set_time_left", 60.0)
	_check(lbl.get_theme_color("font_color") == Color(0.909804, 0.721569, 0.290196, 1.0), "acima de 10 s volta ao ouro")


func _check_no_label_over_nametags(arena: Node) -> void:
	var bad: int = 0
	for n: Node in arena.find_children("*", "Label", true, false):
		var lbl := n as Label
		if lbl.is_visible_in_tree() and lbl.global_position.y > 150.0 and lbl.global_position.y < 260.0:
			if lbl.get_parent() is Node2D:
				continue # nametag do caçador (mundo), não HUD
			bad += 1
			print("    label sobre a área dos nametags: '%s' y=%.0f" % [lbl.text, lbl.global_position.y])
	_check(bad == 0, "nenhum Label de HUD entre y 150 e 260")


func _check_trail(arena: Node, hud: Node) -> void:
	var bar0: ProgressBar = hud.find_children("HudTrail", "", true, false)[0].get_parent() as ProgressBar
	_check(bar0 != null, "barra de vida do HUD tem HudTrail")
	# Barra isolada: sem bots mexendo na vida, o tempo é determinístico.
	var bar := ProgressBar.new()
	bar.max_value = 100.0
	bar.value = 100.0
	arena.add_child(bar)
	var trail: Node = HudTrail.attach(bar, 3.0)
	await process_frame
	bar.value = 60.0
	await process_frame
	await process_frame
	_check(float(trail.call("get_trail_value")) > 90.0, "rastro fica acima da vida logo após o dano")
	await create_timer(1.2).timeout
	_check(absf(float(trail.call("get_trail_value")) - 60.0) < 1.0, "rastro desce até a vida em ~1 s")
	bar.queue_free()


func _check_winner(hud: Node) -> void:
	_check(not bool(hud.call("has_exit_actions")), "sem overlay antes do fim")
	hud.call("show_winner", "Inosuke venceu", "Último caçador de pé")
	_check(bool(hud.call("has_exit_actions")), "show_winner mostra o overlay")
	var ov: Node = hud.find_child("EndOverlay", true, false)
	var buttons: Array[Node] = ov.find_children("*", "Button", true, false)
	_check(buttons.size() == 2, "overlay final com 2 botões")
	var title: Label = ov.call("get_title_label") as Label
	_check(title.text == "Inosuke venceu" and _font_path(title.get_theme_font("font")).contains("Cinzel"), "título Cinzel")
	_check(title.get_theme_font_size("font_size") == 44, "título tamanho 44")


func _duel() -> void:
	var duel: Node = (load(DUEL) as PackedScene).instantiate()
	root.add_child(duel)
	await create_timer(0.4).timeout
	for title_name: String in ["%HpLeftTitle", "%HpRightTitle"]:
		var lbl := duel.get_node(title_name) as Label
		_check(_font_path(lbl.get_theme_font("font")).contains("Cinzel") and lbl.get_theme_font_size("font_size") == 18, "%s em Cinzel 18" % title_name)
	for bar_name: String in ["%HpLeftBar", "%HpRightBar"]:
		_check(duel.get_node(bar_name).get_node_or_null("HudTrail") != null, "%s com rastro" % bar_name)
	for bar_name: String in ["%BreathLeftBar", "%BreathRightBar"]:
		_check(not duel.get_node(bar_name).find_children("*", "BarTicks", false, false).is_empty(), "%s com ticks" % bar_name)
	_check(str(duel.call("get_banner_text")) == "ROUND 1", "banner ROUND 1 intacto")
	duel.call("_on_fighter_died", 1)
	await process_frame
	var res: Control = duel.get_node("%ResultRoot") as Control
	_check(res.visible and str(duel.call("get_result_text")) != "", "resultado aparece")
	var lbl := duel.get_node("%ResultLabel") as Label
	_check(lbl.get_theme_font_size("font_size") == 40, "resultado em Cinzel 40")
	_check(res.find_children("Letterbox*", "ColorRect", true, false).size() == 2, "resultado com letterbox")
	_check(duel.get_node("%RematchButton") is Button and duel.get_node("%LobbyButton") is Button, "resultado com De novo e Lobby")
	duel.queue_free()
	await process_frame


func _despill() -> void:
	var worst: int = 0
	var count: int = 0
	for path: String in _pngs(MODES_DIR):
		var img: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
		var n: int = _magenta_pixels(img)
		worst = maxi(worst, n)
		count += 1
		if n >= MAGENTA_MAX:
			print("    %s tem %d pixels magenta" % [path, n])
	_check(count > 0 and worst < MAGENTA_MAX, "sem franja magenta em %d PNGs (pior=%d)" % [count, worst])


func _magenta_pixels(img: Image) -> int:
	var n: int = 0
	for y: int in img.get_height():
		for x: int in img.get_width():
			var c: Color = img.get_pixel(x, y)
			if c.a > 0.0 and c.r > 150.0 / 255.0 and c.b > 150.0 / 255.0 and c.g < 120.0 / 255.0:
				n += 1
	return n


func _pngs(dir_path: String) -> PackedStringArray:
	var out := PackedStringArray()
	for d: String in DirAccess.get_directories_at(dir_path):
		out.append_array(_pngs(dir_path.path_join(d)))
	for f: String in DirAccess.get_files_at(dir_path):
		if f.ends_with(".png"):
			out.append(dir_path.path_join(f))
	return out
