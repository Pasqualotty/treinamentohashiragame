extends Node
## Diretor de ondas de oni por fase.
## - Spawna packs sequenciais (weak / elite)
## - Espera limpar a onda antes da próxima
## - Emite waves_finished → StageController destrava a SAÍDA
## - Banners de cerimônia (onda / clear / saída) com tween
##
## Uso: filho da fase, ou instanciado pelo StageController.

signal wave_started(wave_index: int, total_waves: int, count: int)
signal wave_cleared(wave_index: int, total_waves: int)
signal waves_finished

const ONI_WEAK := preload("res://scenes/characters/enemies/oni_weak.tscn")
const ONI_ELITE := preload("res://scenes/characters/enemies/oni_elite.tscn")
const ONI_RANGED := preload("res://scenes/characters/enemies/oni_ranged.tscn")
const ONI_CHARGER := preload("res://scenes/characters/enemies/oni_charger.tscn")
const ONI_BOSS := preload("res://scenes/characters/enemies/oni_boss.tscn")

## Tipos de oni aceitos numa onda. O smoke valida a tabela de `_waves_for_stage`
## contra esta lista — typo vira falha de suíte, não um weak silencioso.
const KINDS: PackedStringArray = ["weak", "elite", "ranged", "charger", "boss"]

## stage_id → lista de ondas; cada onda = array de tipos de `KINDS`.
@export var stage_id: String = "w1_01"
@export var spawn_y: float = 500.0
@export var spawn_xs: PackedFloat32Array = PackedFloat32Array([520.0, 720.0, 920.0, 1100.0])
## Posição X usada especificamente pra spawn do "boss" (onda final de w1_boss).
@export var boss_spawn_x: float = 760.0
@export var delay_before_first: float = 0.6
@export var delay_between_waves: float = 1.1
@export var auto_start: bool = true
## Se true, remove inimigos já colocados na cena (Enemy1 etc.) e usa só as ondas.
@export var clear_scene_enemies_on_start: bool = true

var _waves: Array = []
var _wave_i: int = -1
var _alive: Array[Node] = []
var _running: bool = false
var _finished: bool = false
var _label: Label
var _banner: Label
var _banner_bg: ColorRect
var _banner_layer: CanvasLayer
var _banner_tween: Tween


func _ready() -> void:
	_waves = _waves_for_stage(stage_id)
	_ensure_hud_label()
	_ensure_banner()
	if clear_scene_enemies_on_start:
		_clear_preplaced_enemies()
	if auto_start:
		call_deferred("_begin")


func is_finished() -> bool:
	return _finished


func _begin() -> void:
	if _running or _finished:
		return
	_running = true
	if delay_before_first > 0.0:
		_set_label("Prepare-se…")
		await _flash_banner("PREPARE-SE", Color(1.0, 0.92, 0.7, 1.0), 0.85)
		await get_tree().create_timer(maxf(0.0, delay_before_first - 0.85)).timeout
	await _run_all_waves()


func _run_all_waves() -> void:
	var total: int = _waves.size()
	if total <= 0:
		_finish()
		return
	for i in total:
		_wave_i = i
		var pack: Array = _waves[i] as Array
		_spawn_wave(pack)
		wave_started.emit(i + 1, total, pack.size())
		_set_label("Onda %d / %d  ·  onis: %d" % [i + 1, total, pack.size()])
		await _flash_banner("ONDA %d / %d" % [i + 1, total], Color(1.0, 0.88, 0.45, 1.0), 1.05)
		await _wait_wave_clear()
		if not is_inside_tree():
			return
		wave_cleared.emit(i + 1, total)
		if i < total - 1:
			_set_label("Próxima onda…")
			await _flash_banner("ONDA LIMPA!", Color(0.55, 1.0, 0.7, 1.0), 0.9)
			if delay_between_waves > 0.0:
				await get_tree().create_timer(maxf(0.0, delay_between_waves - 0.35)).timeout
		else:
			await _flash_banner("ONDA LIMPA!", Color(0.55, 1.0, 0.7, 1.0), 0.75)
	_finish()


func _finish() -> void:
	_finished = true
	_running = false
	_set_label("SAÍDA ABERTA →")
	# Banner de saída não bloqueia o sinal (fire-and-forget visual).
	_flash_banner_async("SAÍDA ABERTA →", Color(0.45, 0.95, 1.0, 1.0), 1.35)
	waves_finished.emit()
	print("[WaveDirector] all waves done stage=%s" % stage_id)


func _spawn_wave(pack: Array) -> void:
	_alive.clear()
	var parent: Node = get_parent()
	if parent == null:
		parent = self
	var idx: int = 0
	for kind_v: Variant in pack:
		var kind: String = str(kind_v)
		var scene: PackedScene = _scene_for_kind(kind)
		var oni: Node = scene.instantiate()
		parent.add_child(oni)
		if oni is Node2D:
			var x: float
			if kind == "boss":
				# Boss spawna numa posição fixa e legível — não empilha com spawn_xs.
				x = boss_spawn_x
			else:
				x = spawn_xs[idx % spawn_xs.size()]
				# Espalha um pouco para não empilhar.
				x += float(idx) * 28.0
			(oni as Node2D).global_position = Vector2(x, spawn_y)
		if oni.has_signal("defeated"):
			oni.connect("defeated", _on_oni_defeated.bind(oni), CONNECT_ONE_SHOT)
		_alive.append(oni)
		idx += 1


func _scene_for_kind(kind: String) -> PackedScene:
	match kind:
		"weak":
			return ONI_WEAK
		"elite":
			return ONI_ELITE
		"ranged":
			return ONI_RANGED
		"charger":
			return ONI_CHARGER
		"boss":
			return ONI_BOSS
	# Tipo desconhecido virava `weak` em silêncio: um typo na tabela de ondas
	# passava despercebido. Continua caindo em `weak` para não travar a fase,
	# mas reclama alto.
	push_error("WaveDirector: tipo de oni desconhecido '%s' — usando weak" % kind)
	return ONI_WEAK


func _on_oni_defeated(oni: Node) -> void:
	_alive.erase(oni)
	# limpa inválidos
	var keep: Array[Node] = []
	for n: Node in _alive:
		if is_instance_valid(n):
			var died: Variant = n.get("_died")
			if died == true:
				continue
			var hp_v: Variant = n.get("hp")
			if hp_v != null and int(hp_v) <= 0:
				continue
			keep.append(n)
	_alive = keep


func _wait_wave_clear() -> void:
	while is_inside_tree():
		_prune_alive()
		if _alive.is_empty() and not _has_living_enemies():
			return
		await get_tree().create_timer(0.15).timeout


func _prune_alive() -> void:
	var keep: Array[Node] = []
	for n: Node in _alive:
		if not is_instance_valid(n):
			continue
		var died: Variant = n.get("_died")
		if died == true:
			continue
		var hp_v: Variant = n.get("hp")
		if hp_v != null and int(hp_v) <= 0:
			continue
		keep.append(n)
	_alive = keep


func _has_living_enemies() -> bool:
	var tree := get_tree()
	if tree == null:
		return false
	for n: Node in tree.get_nodes_in_group("enemy"):
		if not is_instance_valid(n):
			continue
		var died: Variant = n.get("_died")
		if died == true:
			continue
		var hp_v: Variant = n.get("hp")
		if hp_v != null and int(hp_v) <= 0:
			continue
		return true
	return false


func _clear_preplaced_enemies() -> void:
	var parent: Node = get_parent()
	if parent == null:
		return
	for child: Node in parent.get_children():
		if child == self:
			continue
		if child.is_in_group("enemy"):
			child.queue_free()


func _ensure_hud_label() -> void:
	var layer := CanvasLayer.new()
	layer.name = "WaveHud"
	layer.layer = 40
	add_child(layer)
	_label = Label.new()
	_label.name = "WaveLabel"
	_label.position = Vector2(16, 140)
	_label.size = Vector2(600, 36)
	_label.add_theme_font_size_override("font_size", 20)
	_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.75, 1.0))
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_label.add_theme_constant_override("shadow_offset_x", 1)
	_label.add_theme_constant_override("shadow_offset_y", 1)
	_label.text = ""
	layer.add_child(_label)


func _ensure_banner() -> void:
	_banner_layer = CanvasLayer.new()
	_banner_layer.name = "WaveBanner"
	_banner_layer.layer = 55
	add_child(_banner_layer)

	_banner_bg = ColorRect.new()
	_banner_bg.name = "BannerBg"
	_banner_bg.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_banner_bg.offset_top = 168.0
	_banner_bg.offset_bottom = 248.0
	_banner_bg.color = Color(0.02, 0.04, 0.08, 0.0)
	_banner_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_layer.add_child(_banner_bg)

	_banner = Label.new()
	_banner.name = "BannerLabel"
	_banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_banner.offset_top = 172.0
	_banner.offset_bottom = 244.0
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 42)
	_banner.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	_banner.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	_banner.add_theme_constant_override("shadow_offset_x", 2)
	_banner.add_theme_constant_override("shadow_offset_y", 2)
	_banner.add_theme_constant_override("outline_size", 4)
	_banner.modulate.a = 0.0
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_layer.add_child(_banner)


func _set_label(t: String) -> void:
	if _label:
		_label.text = t


func _flash_banner_async(text: String, color: Color, hold: float = 1.0) -> void:
	# Não espera — usado no finish para não atrasar unlock.
	_flash_banner(text, color, hold)


func _flash_banner(text: String, color: Color, hold: float = 1.0) -> void:
	if _banner == null or not is_inside_tree():
		return
	if _banner_tween != null and is_instance_valid(_banner_tween):
		_banner_tween.kill()
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	_banner.modulate = Color(1, 1, 1, 0)
	_banner.scale = Vector2(0.72, 0.72)
	# Pivot no centro horizontal da tela (approx).
	_banner.pivot_offset = Vector2(_banner.size.x * 0.5, _banner.size.y * 0.5)
	if _banner_bg:
		_banner_bg.color = Color(0.02, 0.05, 0.1, 0.0)

	_banner_tween = create_tween()
	_banner_tween.set_parallel(true)
	_banner_tween.tween_property(_banner, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_banner_tween.tween_property(_banner, "scale", Vector2(1.08, 1.08), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if _banner_bg:
		_banner_tween.tween_property(_banner_bg, "color:a", 0.55, 0.18)
	_banner_tween.set_parallel(false)
	_banner_tween.tween_property(_banner, "scale", Vector2.ONE, 0.12)
	_banner_tween.tween_interval(maxf(0.15, hold - 0.45))
	_banner_tween.set_parallel(true)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if _banner_bg:
		_banner_tween.tween_property(_banner_bg, "color:a", 0.0, 0.28)
	await _banner_tween.finished


func _waves_for_stage(id: String) -> Array:
	## Prefere o resource (mundos novos). Tabela W1 abaixo fica de fallback.
	var from_def: Array = _waves_from_catalog(id)
	if not from_def.is_empty():
		return from_def
	## Cada onda = lista de tipos.
	match id:
		"w1_01":
			return [
				["weak", "weak"],
				["weak", "weak", "weak"],
				["weak", "elite"],
			]
		"w1_02":
			return [
				["weak", "weak", "weak"],
				["weak", "elite", "weak"],
				["weak", "weak", "elite", "weak"],
			]
		"w1_03":
			return [
				["weak", "weak", "elite"],
				["elite", "weak", "weak", "weak"],
				["weak", "elite", "elite"],
			]
		"w1_04":
			# Apresenta o `ranged` num layout vertical: o player aprende a subir
			# a escadaria sob fogo antes de encarar o mesmo tipo no boss.
			return [
				["weak", "ranged"],
				["ranged", "weak", "weak"],
				["elite", "ranged", "weak"],
			]
		"w1_05":
			# Apresenta o `charger` na arena aberta e fecha misturando os quatro
			# tipos — é o ensaio geral do ritmo do boss.
			return [
				["charger", "weak"],
				["ranged", "charger", "weak"],
				["elite", "charger", "ranged", "weak"],
			]
		"w1_boss":
			# 2 ondas de aquecimento (revisitam ranged/charger, já apresentados
			# nas fases 4 e 5) + BOSS como onda final. `_wait_wave_clear` já
			# espera _died/hp<=0 do boss antes de liberar `waves_finished`.
			return [
				["weak", "weak", "ranged"],
				["charger", "elite", "ranged"],
				["boss"],
			]
	# Sem default silencioso: uma fase nova sem ondas (ou um `stage_id` renomeado
	# num `.tres`) rodava com 2 ondas genéricas sem ninguém perceber. Agora falha
	# alto, e o smoke exige entrada aqui para todo id do catálogo.
	push_error("WaveDirector: fase sem ondas definidas em _waves_for_stage(): %s" % id)
	return []


func _waves_from_catalog(id: String) -> Array:
	var def: StageDef = WorldCatalog.find(id)
	if def == null:
		return []
	return def.wave_packs()
