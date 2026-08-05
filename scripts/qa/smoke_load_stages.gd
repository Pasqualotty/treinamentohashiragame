extends SceneTree
## Headless: carrega e instancia as 4 fases W1 + world_map.
## Uso: godot --headless --path . -s res://scripts/qa/smoke_load_stages.gd

const STAGES: PackedStringArray = [
	"res://scenes/battle/stage_w1_01.tscn",
	"res://scenes/battle/stage_w1_02.tscn",
	"res://scenes/battle/stage_w1_03.tscn",
	"res://scenes/battle/stage_w1_boss.tscn",
	"res://scenes/world/world_map.tscn",
]

const STAGE_IDS: PackedStringArray = ["w1_01", "w1_02", "w1_03", "w1_boss"]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failed: int = 0

	for path: String in STAGES:
		var res: Resource = load(path)
		if res == null:
			push_error("[smoke] FAIL load: %s" % path)
			failed += 1
			continue
		var node: Node = (res as PackedScene).instantiate()
		if node == null:
			push_error("[smoke] FAIL instantiate: %s" % path)
			failed += 1
			continue
		root.add_child(node)
		# Um frame pra _ready rodar (StageController / world_map).
		await process_frame
		# Valida stage_id se for controller de fase.
		if node.get("stage_id") != null and str(node.get("stage_id")) != "":
			var sid: String = str(node.get("stage_id"))
			if sid not in STAGE_IDS and not path.ends_with("world_map.tscn"):
				push_error("[smoke] unexpected stage_id=%s in %s" % [sid, path])
				failed += 1
			else:
				print("[smoke] OK stage_id=%s path=%s" % [sid, path])
		else:
			print("[smoke] OK load %s" % path)
		node.queue_free()
		await process_frame

	# StageDef resources
	var defs: PackedStringArray = [
		"res://resources/stages/stage_w1_01.tres",
		"res://resources/stages/stage_w1_02.tres",
		"res://resources/stages/stage_w1_03.tres",
		"res://resources/stages/stage_w1_boss.tres",
	]
	for dpath: String in defs:
		var def: Resource = load(dpath)
		if def == null:
			push_error("[smoke] FAIL StageDef: %s" % dpath)
			failed += 1
		else:
			print("[smoke] OK StageDef %s id=%s" % [dpath, def.get("stage_id")])

	print("[smoke] cleared IDs canônicos: %s" % ", ".join(STAGE_IDS))
	if failed > 0:
		print("[smoke] FAILED count=%d" % failed)
		quit(1)
	print("[smoke] ALL PASSED")
	quit(0)
