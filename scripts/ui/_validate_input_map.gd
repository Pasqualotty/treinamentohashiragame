extends SceneTree
## Headless smoke: InputMap actions + carrega cena touch (stick + botões).
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

	if not ClassDB.class_exists("VirtualJoystick"):
		push_error("FAIL VirtualJoystick class missing (need Godot 4.7+)")
		failed = true
	else:
		print("OK ClassDB VirtualJoystick")

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
			# Enter tree so _ready builds stick + buttons
			get_root().add_child(inst)
			await process_frame
			await process_frame
			var expected_btns: PackedStringArray = [
				"Btn_advance", "Btn_jump",
				"Btn_attack_basic", "Btn_skill_1", "Btn_skill_2", "Btn_ultimate", "Btn_pause",
			]
			var touch_root: Node = inst.get_node_or_null("TouchRoot")
			if touch_root == null:
				push_error("FAIL TouchRoot missing after ready")
				failed = true
			else:
				var stick: Node = touch_root.get_node_or_null("VirtualStick")
				if stick == null:
					push_error("FAIL missing VirtualStick")
					failed = true
				elif not (stick is VirtualJoystick):
					push_error("FAIL VirtualStick not VirtualJoystick (%s)" % stick.get_class())
					failed = true
				else:
					var vj := stick as VirtualJoystick
					if String(vj.action_left) != "move_left" or String(vj.action_right) != "move_right":
						push_error(
							"FAIL stick actions left=%s right=%s"
							% [vj.action_left, vj.action_right]
						)
						failed = true
					else:
						print(
							"OK VirtualStick action_left=%s action_right=%s size=%.0f"
							% [vj.action_left, vj.action_right, vj.joystick_size]
						)
				for btn_name in expected_btns:
					var b: Node = touch_root.get_node_or_null(btn_name)
					if b == null:
						push_error("FAIL missing button node: %s" % btn_name)
						failed = true
					elif b is TouchScreenButton:
						# Preferido: multi-touch nativo (stick + ATK).
						var tsb := b as TouchScreenButton
						if tsb.texture_normal == null:
							push_error("FAIL no texture_normal on %s" % btn_name)
							failed = true
						elif String(tsb.action).is_empty():
							push_error("FAIL empty action on %s" % btn_name)
							failed = true
						else:
							print("OK button=%s TouchScreenButton action=%s" % [btn_name, tsb.action])
					elif b is TextureButton:
						var tb := b as TextureButton
						if tb.texture_normal == null:
							push_error("FAIL no texture_normal on %s" % btn_name)
							failed = true
						else:
							print("OK button=%s TextureButton (legacy single-pointer)" % btn_name)
					elif b is BaseButton:
						print("OK button=%s BaseButton" % btn_name)
					else:
						push_error("FAIL %s not a button type (%s)" % [btn_name, b.get_class()])
						failed = true
			# Labels baked nos botões de ação (move L/R saiu pro stick)
			var labeled_ok: int = 0
			for action_name in ["jump", "advance", "attack_basic", "ultimate", "pause"]:
				var lp := "res://assets/ui/touch/labeled/%s.png" % action_name
				if ResourceLoader.exists(lp):
					labeled_ok += 1
				else:
					push_error("FAIL missing labeled texture: %s" % lp)
					failed = true
			print("OK labeled textures=%d" % labeled_ok)
			# Simula action_press como teclado/stick faria
			Input.action_press("move_right")
			await process_frame
			if not Input.is_action_pressed("move_right"):
				push_error("FAIL Input.action_press(move_right) not held")
				failed = true
			else:
				print("OK action_press move_right")
			Input.action_release("move_right")
			# Strength path (stick / axis) — get_axis deve reagir a press strength
			Input.action_press("move_left", 0.75)
			await process_frame
			var axis_val: float = Input.get_axis("move_left", "move_right")
			if axis_val > -0.5:
				push_error("FAIL get_axis after move_left strength: %s" % axis_val)
				failed = true
			else:
				print("OK get_axis move_left strength=%.2f axis=%.2f" % [0.75, axis_val])
			Input.action_release("move_left")
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
