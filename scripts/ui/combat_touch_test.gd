extends Control
## Cena de playtest: teclado + touch emitem as mesmas InputMap actions.
## Abra no editor (F6) ou defina como main temporária.

const ACTIONS: PackedStringArray = [
	"move_left",
	"move_right",
	"move_up",
	"move_down",
	"jump",
	"advance",
	"attack_basic",
	"skill_1",
	"skill_2",
	"ultimate",
	"pause",
]

@onready var status_label: Label = %StatusLabel
@onready var hint_label: Label = %HintLabel


func _ready() -> void:
	hint_label.text = (
		"PC: A/D ou ←/→ · Espaço pulo · Shift/F dash · Z/J atk · X/K H1 · C/L H2 · V/I ult · Esc pause\n"
		+ "Touch: botões na tela (multi-touch). Escopo: só input — sem combate."
	)
	_refresh_status()


func _process(_delta: float) -> void:
	_refresh_status()


func _refresh_status() -> void:
	var held: PackedStringArray = []
	var just: PackedStringArray = []
	for action in ACTIONS:
		if not InputMap.has_action(action):
			continue
		if Input.is_action_pressed(action):
			held.append(action)
		if Input.is_action_just_pressed(action):
			just.append(action)
	var lines: PackedStringArray = []
	lines.append("Actions no InputMap: %d / %d" % [_count_mapped(), ACTIONS.size()])
	lines.append("Held: %s" % (", ".join(held) if held.size() else "—"))
	lines.append("Just pressed: %s" % (", ".join(just) if just.size() else "—"))
	status_label.text = "\n".join(lines)


func _count_mapped() -> int:
	var n := 0
	for action in ACTIONS:
		if InputMap.has_action(action):
			n += 1
	return n
