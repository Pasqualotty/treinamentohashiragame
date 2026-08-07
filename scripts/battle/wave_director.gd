extends Node
## Diretor de ondas de oni por fase.
## - Spawna packs sequenciais (weak / elite)
## - Espera limpar a onda antes da próxima
## - Emite waves_finished → StageController destrava a SAÍDA
##
## Uso: filho da fase, ou instanciado pelo StageController.

signal wave_started(wave_index: int, total_waves: int, count: int)
signal wave_cleared(wave_index: int, total_waves: int)
signal waves_finished

const ONI_WEAK := preload("res://scenes/characters/enemies/oni_weak.tscn")
const ONI_ELITE := preload("res://scenes/characters/enemies/oni_elite.tscn")

## stage_id → lista de ondas; cada onda = array de "weak"|"elite"
@export var stage_id: String = "w1_01"
@export var spawn_y: float = 500.0
@export var spawn_xs: PackedFloat32Array = PackedFloat32Array([520.0, 720.0, 920.0, 1100.0])
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


func _ready() -> void:
	_waves = _waves_for_stage(stage_id)
	_ensure_hud_label()
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
		await get_tree().create_timer(delay_before_first).timeout
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
		await _wait_wave_clear()
		if not is_inside_tree():
			return
		wave_cleared.emit(i + 1, total)
		if i < total - 1 and delay_between_waves > 0.0:
			_set_label("Próxima onda…")
			await get_tree().create_timer(delay_between_waves).timeout
	_finish()


func _finish() -> void:
	_finished = true
	_running = false
	_set_label("SAÍDA ABERTA →")
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
		var scene: PackedScene = ONI_ELITE if kind == "elite" else ONI_WEAK
		var oni: Node = scene.instantiate()
		parent.add_child(oni)
		if oni is Node2D:
			var x: float = spawn_xs[idx % spawn_xs.size()]
			# Espalha um pouco para não empilhar.
			x += float(idx) * 28.0
			(oni as Node2D).global_position = Vector2(x, spawn_y)
		if oni.has_signal("defeated"):
			oni.connect("defeated", _on_oni_defeated.bind(oni), CONNECT_ONE_SHOT)
		_alive.append(oni)
		idx += 1


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


func _set_label(t: String) -> void:
	if _label:
		_label.text = t


func _waves_for_stage(id: String) -> Array:
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
		"w1_boss":
			return [
				["weak", "weak"],
				["elite", "weak", "elite"],
				["elite", "elite", "elite"],
			]
		_:
			return [
				["weak", "weak"],
				["weak", "elite"],
			]
