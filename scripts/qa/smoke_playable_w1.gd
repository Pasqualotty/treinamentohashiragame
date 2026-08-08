extends SceneTree
## Smoke headless: valida que a fase W1 carrega, tem player, input map e waves.
## Depois do check profundo na fase 1, roda um check de jogabilidade mínima nas
## fases novas (4 e 5): player, ondas, inimigos e saída trancada.
## Uso:
##   godot --headless --path . -s res://scripts/qa/smoke_playable_w1.gd

const STAGE := "res://scenes/battle/stage_w1_01.tscn"
## Fases extras cobertas pelo check leve — as novas do Mundo 1.
const EXTRA_STAGES := [
	"res://scenes/battle/stage_w1_04.tscn",
	"res://scenes/battle/stage_w1_05.tscn",
]
## Teto de frames esperando os spawns da primeira onda (banner + delay inicial).
const SPAWN_WAIT_FRAMES := 600
const REQUIRED_ACTIONS := [
	"move_left", "move_right", "jump", "advance",
	"attack_basic", "skill_1", "skill_2", "ultimate", "pause",
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var ok := true
	print("=== smoke_playable_w1 ===")

	for a: String in REQUIRED_ACTIONS:
		if not InputMap.has_action(a):
			push_error("MISSING InputMap action: %s" % a)
			ok = false
		else:
			print("OK action: ", a)

	# Autoloads
	for name: String in ["Game", "Audio", "SceneRouter", "CombatFeel"]:
		if root.get_node_or_null("/root/%s" % name) == null:
			# Autoloads aparecem como filhos de root com o nome
			var found := false
			for c in root.get_children():
				if c.name == name:
					found = true
					break
			if not found:
				# Em -s script mode, autoloads do project.godot ainda carregam.
				var n = Engine.get_main_loop()
				print("check autoload ", name, " main_loop=", n)
		print("autoload check: ", name)

	var err := change_scene_to_file(STAGE)
	if err != OK:
		push_error("change_scene_to_file failed: %s" % err)
		quit(2)
		return

	# Espera frames de setup
	for i in 20:
		await process_frame

	var scene := current_scene
	if scene == null:
		push_error("current_scene null")
		quit(3)
		return
	print("scene: ", scene.name, " ", scene.scene_file_path)

	var players := get_nodes_in_group("player")
	if players.is_empty():
		push_error("no player in group")
		ok = false
	else:
		var p: Node = players[0]
		print("player ok pos=", (p as Node2D).global_position if p is Node2D else "?")
		if p is CharacterBody2D:
			var body := p as CharacterBody2D
			print("player collision_layer=", body.collision_layer, " mask=", body.collision_mask)
			print("player floor_snap=", body.floor_snap_length)

	# Simula input de movimento por alguns frames
	Input.action_press("move_right")
	var start_x := 0.0
	if not players.is_empty() and players[0] is Node2D:
		start_x = (players[0] as Node2D).global_position.x
	for i in 30:
		await physics_frame
	Input.action_release("move_right")

	if not players.is_empty() and players[0] is Node2D:
		var end_x: float = (players[0] as Node2D).global_position.x
		var dx: float = end_x - start_x
		print("move_right dx=", dx)
		if dx < 8.0:
			push_error("player did not move enough under move_right (dx=%s)" % dx)
			ok = false
		else:
			print("OK player moves")

	# Feel mínimo: stats de buffer/coyote/accel no player canônico.
	if not players.is_empty():
		var pnode: Node = players[0]
		var st = pnode.get("stats") if pnode else null
		if st == null:
			push_error("player.stats ausente (feel)")
			ok = false
		else:
			var coyote: float = float(st.get("coyote_time"))
			var ibuf: float = float(st.get("input_buffer")) if "input_buffer" in st else -1.0
			var accel: float = float(st.get("move_accel")) if "move_accel" in st else -1.0
			print("feel coyote=", coyote, " input_buffer=", ibuf, " move_accel=", accel)
			if coyote < 0.08 or coyote > 0.25:
				push_error("coyote_time fora da faixa feel (got %s)" % coyote)
				ok = false
			if ibuf < 0.08 or ibuf > 0.20:
				push_error("input_buffer fora de 100-150ms feel (got %s)" % ibuf)
				ok = false
			else:
				print("OK input_buffer")
			if accel < 500.0:
				push_error("move_accel demasiado baixo (got %s)" % accel)
				ok = false
			else:
				print("OK move_accel")
		# CombatFeel API de hit tipado
		var cf: Node = root.get_node_or_null("/root/CombatFeel")
		if cf == null:
			for c in root.get_children():
				if c.name == "CombatFeel":
					cf = c
					break
		if cf == null:
			push_error("CombatFeel autoload ausente")
			ok = false
		elif not cf.has_method("hit_impact_typed") or not cf.has_method("reset_time_scale"):
			push_error("CombatFeel sem hit_impact_typed/reset_time_scale")
			ok = false
		else:
			print("OK CombatFeel feel API")

	# Touch controls + wave director presentes?
	var touch := scene.find_child("TouchRoot", true, false)
	if touch == null:
		# CanvasLayer child name
		var found_touch := false
		for c in scene.get_children():
			if c is CanvasLayer and c.get_script() and str(c.get_script().resource_path).contains("combat_touch"):
				found_touch = true
				print("OK touch controls layer: ", c.name)
				break
		if not found_touch:
			# Stage adds instantiated scene as child
			for c in scene.get_children():
				if String(c.name).contains("CombatTouch") or c.find_child("Btn_move_left", true, false):
					found_touch = true
					print("OK touch via child: ", c.name)
					break
		if not found_touch:
			push_error("touch controls not found")
			ok = false
	else:
		print("OK TouchRoot")

	var wd := scene.find_child("WaveDirector", true, false)
	if wd == null:
		push_error("WaveDirector missing")
		ok = false
	else:
		print("OK WaveDirector")

	# Espera um pouco para spawns da onda 1
	for i in 45:
		await process_frame
	var enemies := get_nodes_in_group("enemy")
	print("enemies after wave start: ", enemies.size())
	if enemies.is_empty():
		push_error("no enemies spawned by waves")
		ok = false
	else:
		print("OK enemies present")

	# Fases novas: check leve de jogabilidade (carrega, player, ondas, saída).
	for extra: String in EXTRA_STAGES:
		if not await _check_extra_stage(extra):
			ok = false

	if ok:
		print("=== SMOKE PASS ===")
		quit(0)
	else:
		print("=== SMOKE FAIL ===")
		quit(1)


## Check leve de uma fase: troca de cena, confere player/ondas/inimigos/saída.
func _check_extra_stage(path: String) -> bool:
	print("--- stage: ", path)
	var err := change_scene_to_file(path)
	if err != OK:
		push_error("change_scene_to_file failed (%s): %s" % [path, err])
		return false
	for i in 20:
		await process_frame
	var scene := current_scene
	if scene == null:
		push_error("current_scene null after loading %s" % path)
		return false

	var ok := true
	if get_nodes_in_group("player").is_empty():
		push_error("no player in group (%s)" % path)
		ok = false

	var wd := scene.find_child("WaveDirector", true, false)
	if wd == null:
		push_error("WaveDirector missing (%s)" % path)
		ok = false

	var goal := scene.find_child("Goal", true, false)
	if goal == null:
		push_error("Goal missing (%s)" % path)
		ok = false
	elif goal.has_method("is_locked") and not bool(goal.call("is_locked")):
		push_error("Goal já destrancado antes das ondas (%s)" % path)
		ok = false

	# Espera os spawns da onda 1 (banner de abertura + delay inicial).
	var waited := 0
	while waited < SPAWN_WAIT_FRAMES and get_nodes_in_group("enemy").is_empty():
		await process_frame
		waited += 1
	var enemies := get_nodes_in_group("enemy")
	if enemies.is_empty():
		push_error("no enemies spawned by waves (%s)" % path)
		ok = false
	else:
		print("OK ", path, " enemies=", enemies.size(), " frames=", waited)
	return ok
