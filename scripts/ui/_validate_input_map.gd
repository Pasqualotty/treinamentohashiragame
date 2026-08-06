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

	for tex_path in [
		"res://assets/ui/touch/btn_red.png",
		"res://assets/ui/touch/btn_orange.png",
		"res://assets/ui/touch/btn_blue.png",
		"res://assets/ui/touch/btn_purple.png",
		"res://assets/ui/touch/buttons_row.png",
	]:
		if not ResourceLoader.exists(tex_path):
			push_error("MISSING texture: %s" % tex_path)
			failed = true
		else:
			print("OK texture=%s" % tex_path)

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
			# hide_on_desktop default must be false (PC playtest)
			if inst.get("hide_on_desktop") == true:
				push_error("FAIL hide_on_desktop default should be false")
				failed = true
			else:
				print("OK hide_on_desktop default=false")
			# Enter tree so _ready builds buttons
			get_root().add_child(inst)
			await process_frame
			await process_frame
			var expected_btns: PackedStringArray = [
				"Btn_move_left", "Btn_move_right", "Btn_advance", "Btn_jump",
				"Btn_attack_basic", "Btn_skill_1", "Btn_skill_2", "Btn_ultimate", "Btn_pause",
			]
			var touch_root: Node = inst.get_node_or_null("TouchRoot")
			if touch_root == null:
				push_error("FAIL TouchRoot missing after ready")
				failed = true
			else:
				for btn_name in expected_btns:
					var b: Node = touch_root.get_node_or_null(btn_name)
					if b == null:
						push_error("FAIL missing button node: %s" % btn_name)
						failed = true
					elif b is TouchScreenButton:
						var tsb := b as TouchScreenButton
						if tsb.texture_normal == null:
							push_error("FAIL no texture_normal on %s" % btn_name)
							failed = true
						else:
							print("OK button=%s action=%s" % [btn_name, tsb.action])
					else:
						push_error("FAIL %s not TouchScreenButton" % btn_name)
						failed = true
			# Labels ASCII (no mojibake / special pause glyphs)
			var labels_node: Node = inst.get_node_or_null("Labels")
			if labels_node:
				for child in labels_node.get_children():
					if child is Label:
						var t: String = (child as Label).text
						for bad in ["◄", "►", "❚", "ã", "ç", "\ufffd"]:
							if bad in t:
								push_error("FAIL non-ASCII/mojibake label: %s" % t)
								failed = true
				print("OK labels count=%d" % labels_node.get_child_count())
			inst.queue_free()
			await process_frame

	var test_packed: PackedScene = load("res://scenes/ui/combat_touch_test.tscn") as PackedScene
	if test_packed == null:
		push_error("FAIL load combat_touch_test.tscn")
		failed = true
	else:
		print("OK load combat_touch_test.tscn")

	var hud_packed: PackedScene = load("res://scenes/ui/combat_hud.tscn") as PackedScene
	if hud_packed == null:
		push_error("FAIL load combat_hud.tscn")
		failed = true
	else:
		var hud := hud_packed.instantiate()
		get_root().add_child(hud)
		await process_frame
		var breath_title := hud.find_child("BreathTitle", true, false) as Label
		if breath_title and ("ã" in breath_title.text or "ç" in breath_title.text):
			push_error("FAIL BreathTitle has broken/special chars: %s" % breath_title.text)
			failed = true
		else:
			print("OK combat_hud BreathTitle=%s" % (breath_title.text if breath_title else "?"))
		hud.queue_free()
		await process_frame

	if failed:
		print("VALIDATE_INPUT_MAP FAILED")
		quit(1)
	else:
		print("VALIDATE_INPUT_MAP PASSED")
		quit(0)
