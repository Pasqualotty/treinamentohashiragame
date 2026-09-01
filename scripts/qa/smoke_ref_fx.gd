extends SceneTree
## Garante que os sprites de FX da referência existem e o helper carrega.

const PATHS: PackedStringArray = [
	"res://assets/fx/slash/00.png",
	"res://assets/fx/slash/03.png",
	"res://assets/fx/water/00.png",
	"res://assets/fx/impact/00.png",
	"res://assets/fx/impact/05.png",
	"res://scenes/fx/sheet_burst.tscn",
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failed := 0
	for p: String in PATHS:
		if not ResourceLoader.exists(p):
			print("FAIL missing %s" % p)
			failed += 1
	var packed: PackedScene = load("res://scenes/fx/sheet_burst.tscn") as PackedScene
	if packed == null:
		print("FAIL sheet_burst tscn")
		failed += 1
	else:
		var n: Node = packed.instantiate()
		if n == null or not n.has_method("play_sheet"):
			print("FAIL sheet_burst instance")
			failed += 1
		else:
			n.free()
	if failed > 0:
		print("=== REF FX FAIL ===")
		quit(1)
		return
	print("=== REF FX PASS ===")
	quit(0)
