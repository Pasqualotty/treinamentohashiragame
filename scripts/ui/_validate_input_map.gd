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
					elif b is TextureButton:
						var tb := b as TextureButton
						if tb.texture_normal == null:
							push_error("FAIL no texture_normal on %s" % btn_name)
							failed = true
						else:
							print("OK button=%s TextureButton" % btn_name)
					elif b is TouchScreenButton:
						var tsb := b as TouchScreenButton
						if tsb.texture_normal == null:
							push_error("FAIL no texture_normal on %s" % btn_name)
							failed = true
						else:
							print("OK button=%s action=%s" % [btn_name, tsb.action])
					elif b is BaseButton:
						print("OK button=%s BaseButton" % btn_name)
					else:
						push_error("FAIL %s not a button type (%s)" % [btn_name, b.get_class()])
						failed = true
			# Labels agora vão baked no PNG (assets/ui/touch/labeled/*)
			var labeled_ok: int = 0
			for action_name in ["move_left", "jump", "attack_basic", "ultimate", "pause"]:
				var lp := "res://assets/ui/touch/labeled/%s.png" % action_name
				if ResourceLoader.exists(lp):
					labeled_ok += 1
				else:
					push_error("FAIL missing labeled texture: %s" % lp)
					failed = true
			print("OK labeled textures=%d" % labeled_ok)
			# Simula action_press como o botão faz
			Input.action_press("move_right")
			await process_frame
			if not Input.is_action_pressed("move_right"):
				push_error("FAIL Input.action_press(move_right) not held")
				failed = true
			else:
				print("OK action_press move_right")
			Input.action_release("move_right")
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
