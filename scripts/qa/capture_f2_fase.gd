extends SceneTree
## Capturas 1280x720 da fase (F2): intro, onda, combate, portal trancado/aberto, clear, chefe.
## Precisa de janela real — NÃO usar --headless. HASHIRA_CAPTURE_DIR = pasta de saída.
## Uso: godot --path . --resolution 1280x720 -s res://scripts/qa/capture_f2_fase.gd

const TOUCH := "res://scenes/ui/combat_touch_controls.tscn"

var _out: String = ""
var _chrome: GDScript


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	root.size = Vector2i(1280, 720)
	_out = OS.get_environment("HASHIRA_CAPTURE_DIR")
	if _out.is_empty():
		print("CAPTURE FAIL HASHIRA_CAPTURE_DIR vazio")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	_chrome = load("res://scripts/ui/stage_chrome.gd")
	await _desktop_shots()
	await _mobile_shots()
	await _boss_shot()
	print("CAPTURE_F2 DONE")
	quit(0)


func _desktop_shots() -> void:
	_chrome.force_touch = 0
	var stage: Node = await _open("res://scenes/battle/stage_w1_01.tscn")
	await _wait(0.6)
	await _shot("desk-intro-0.6s")
	await _wait(1.9)
	await _shot("desk-combat-2.5s")
	await _wait(1.0)
	await _shot("desk-wave-card")
	stage.call("_play_clear_ceremony", 42)
	await _wait(1.3)
	await _shot("desk-clear")


func _mobile_shots() -> void:
	_chrome.force_touch = 1
	var stage: Node = await _open("res://scenes/battle/stage_w1_01.tscn")
	_force_touch_controls(stage)
	await _wait(2.5)
	await _shot("mobile-combat-2.5s")
	_move_player(stage, 1180.0)
	await _wait(0.6)
	await _shot("mobile-portal-locked")
	stage.call("_set_goal_locked", false)
	await _wait(1.0)
	await _shot("mobile-portal-open")


func _boss_shot() -> void:
	_chrome.force_touch = 0
	await _open("res://scenes/battle/stage_w1_boss.tscn")
	await _wait(1.5)
	await _shot("desk-boss-1.5s")


func _open(path: String) -> Node:
	if current_scene != null:
		current_scene.queue_free()
		await process_frame
	change_scene_to_file(path)
	for i in 6:
		await process_frame
	return current_scene


## Desktop esconde os controles de toque; recria visível para a captura "mobile".
func _force_touch_controls(stage: Node) -> void:
	for c in stage.get_children():
		if c is CanvasLayer and c.get("hide_on_desktop") != null:
			c.queue_free()
	var t: CanvasLayer = (load(TOUCH) as PackedScene).instantiate()
	t.set("hide_on_desktop", false)
	stage.add_child(t)


func _move_player(stage: Node, x: float) -> void:
	var p := get_nodes_in_group("player")
	if not p.is_empty():
		(p[0] as Node2D).global_position.x = x


func _wait(sec: float) -> void:
	await create_timer(sec).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	var path := _out.path_join("f2-%s.png" % name)
	print("saved ", path, " ", img.get_width(), "x", img.get_height(), " err=", img.save_png(path))
