extends SceneTree
## Smoke headless: valida que a fase W1 carrega, tem player, input map e waves.
## Uso:
##   godot --headless --path . -s res://scripts/qa/smoke_playable_w1.gd

const STAGE := "res://scenes/battle/stage_w1_01.tscn"
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

	if ok:
		print("=== SMOKE PASS ===")
		quit(0)
	else:
		print("=== SMOKE FAIL ===")
		quit(1)
