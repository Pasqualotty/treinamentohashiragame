extends SceneTree
## Capturas 1280x720 do brawl e do duelo (HUD, card de abertura, tela final).
## NÃO usar --headless (viewport dummy = PNG nulo). HASHIRA_CAPTURE_DIR = pasta de saída.
## Uso: godot --path . --resolution 1280x720 -s res://scripts/qa/capture_f6_modos.gd

const ARENA := "res://scenes/modes/brawl/brawl_arena.tscn"
const DUEL := "res://scenes/modes/duel/duel.tscn"

var _out: String = ""


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
	var ok: bool = await _brawl() and await _duel()
	print("CAPTURE_F6 ", "DONE" if ok else "FAIL")
	quit(0 if ok else 1)


func _brawl() -> bool:
	var inst: Node = (load(ARENA) as PackedScene).instantiate()
	root.add_child(inst)
	await create_timer(0.8).timeout
	var ok: bool = await _save("brawl-1-card.png")
	await create_timer(2.4).timeout
	ok = ok and await _save("brawl-2-jogo.png")
	var hunters: Array = inst.call("get_hunters")
	(hunters[1] as Node).set("hp", 12)
	await create_timer(0.2).timeout
	ok = ok and await _save("brawl-3-dano.png")
	inst.call("_finish", "Inosuke venceu", hunters[0])
	await create_timer(0.7).timeout
	ok = ok and await _save("brawl-4-fim.png")
	inst.queue_free()
	await process_frame
	return ok


func _duel() -> bool:
	var inst: Node = (load(DUEL) as PackedScene).instantiate()
	root.add_child(inst)
	await create_timer(0.5).timeout
	var ok: bool = await _save("duel-1-round.png")
	await create_timer(2.5).timeout
	(inst.call("get_right_fighter") as Node).call("apply_damage", 40, Vector2.ZERO)
	await create_timer(0.3).timeout
	ok = ok and await _save("duel-2-dano.png")
	inst.call("_on_fighter_died", 1)
	await create_timer(0.8).timeout
	ok = ok and await _save("duel-3-resultado.png")
	inst.queue_free()
	await process_frame
	return ok


func _save(file: String) -> bool:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	if img == null or img.get_width() < 1200:
		print("CAPTURE FAIL ", file)
		return false
	var err: Error = img.save_png(_out.path_join(file))
	print("saved ", file, " err=", err)
	return err == OK
