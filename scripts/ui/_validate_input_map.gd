extends SceneTree
## Headless smoke: InputMap actions + carrega cena touch.
## Uso: godot --headless --path . -s res://scripts/ui/_validate_input_map.gd

const REQUIRED: PackedStringArray = [
	"move_left", "move_right", "move_up", "move_down",
	"jump", "advance", "attack_basic", "skill_1", "skill_2", "ultimate", "pause",
]


func _initialize() -> void:
	var failed := false
	for action in REQUIRED:
		if not InputMap.has_action(action):
			push_error("MISSING action: %s" % action)
			failed = true
		else:
			var events := InputMap.action_get_events(action)
			print("OK action=%s events=%d" % [action, events.size()])
			if events.is_empty() and action not in ["move_up", "move_down"]:
				# Optional axes may be empty later; core actions must have keys.
				if action.begins_with("move_") == false or action in ["move_left", "move_right"]:
					if events.is_empty():
						push_error("NO EVENTS for action: %s" % action)
						failed = true

	var packed: PackedScene = load("res://scenes/ui/combat_touch_controls.tscn") as PackedScene
	if packed == null:
		push_error("FAIL load combat_touch_controls.tscn")
		failed = true
	else:
		var inst := packed.instantiate()
		if inst == null:
			push_error("FAIL instantiate combat_touch_controls")
			failed = true
		else:
			print("OK instantiate combat_touch_controls: %s" % inst.get_class())
			inst.free()

	var test_packed: PackedScene = load("res://scenes/ui/combat_touch_test.tscn") as PackedScene
	if test_packed == null:
		push_error("FAIL load combat_touch_test.tscn")
		failed = true
	else:
		print("OK load combat_touch_test.tscn")

	if failed:
		print("VALIDATE_INPUT_MAP FAILED")
		quit(1)
	else:
		print("VALIDATE_INPUT_MAP PASSED")
		quit(0)
