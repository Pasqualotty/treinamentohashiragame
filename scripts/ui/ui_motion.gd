class_name UiMotion
extends RefCounted
## Movimento de interface reutilizável: entrada em cascata, aperto de botão,
## pop e contador. Funções pequenas; as telas só chamam.

const PRESS_SCALE := 0.96
const ENTER_TIME := 0.26
const MAX_STAGGER_DELAY := 0.5


## Cada item entra com fade 0→1 e sobe `slide` px, atrasado `step` s do anterior.
## Espera 1 frame antes de ler a posição: containers só arrumam os filhos no fim do frame.
static func enter_stagger(nodes: Array, step: float = 0.05, slide: float = 16.0) -> void:
	var items: Array[Control] = []
	for n in nodes:
		var ctrl := n as Control
		if ctrl != null and is_instance_valid(ctrl):
			ctrl.modulate.a = 0.0
			items.append(ctrl)
	if items.is_empty():
		return
	await items[0].get_tree().process_frame
	for i in items.size():
		_enter_one(items[i], minf(float(i) * step, MAX_STAGGER_DELAY), slide)


static func _enter_one(ctrl: Control, delay: float, slide: float) -> void:
	if not is_instance_valid(ctrl):
		return
	var target: Vector2 = ctrl.position
	ctrl.position = target + Vector2(0.0, slide)
	var tw: Tween = ctrl.create_tween().set_parallel(true)
	tw.tween_property(ctrl, "modulate:a", 1.0, ENTER_TIME).set_delay(delay)
	tw.tween_property(ctrl, "position", target, ENTER_TIME).set_delay(delay) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Botão encolhe a 0.96 ao apertar e volta com TRANS_BACK ao soltar.
static func press_bounce(btn: BaseButton) -> void:
	if btn == null or btn.has_meta("press_bounce"):
		return
	btn.set_meta("press_bounce", true)
	btn.button_down.connect(_press_down.bind(btn))
	btn.button_up.connect(_press_up.bind(btn))


## Aplica press_bounce em todo botão debaixo de `root`.
static func bounce_all(root: Node) -> void:
	if root == null:
		return
	if root is BaseButton:
		press_bounce(root as BaseButton)
	for child in root.get_children():
		bounce_all(child)


static func _press_down(btn: BaseButton) -> void:
	if not is_instance_valid(btn):
		return
	btn.pivot_offset = btn.size * 0.5
	var tw: Tween = btn.create_tween()
	tw.tween_property(btn, "scale", Vector2(PRESS_SCALE, PRESS_SCALE), 0.06)


static func _press_up(btn: BaseButton) -> void:
	if not is_instance_valid(btn):
		return
	var tw: Tween = btn.create_tween()
	tw.tween_property(btn, "scale", Vector2.ONE, 0.2) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Pop de confirmação: cresce `mult` e volta a 1.
static func pop(node: Control, mult: float = 1.12) -> void:
	if node == null or not is_instance_valid(node):
		return
	node.pivot_offset = node.size * 0.5
	var tw: Tween = node.create_tween()
	tw.tween_property(node, "scale", Vector2(mult, mult), 0.1) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", Vector2.ONE, 0.16) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Contador animado; o último texto é EXATAMENTE `fmt % to`.
static func count_up(label: Label, from: int, to: int, dur: float = 0.6, fmt: String = "%d") -> void:
	if label == null or not is_instance_valid(label):
		return
	if label.has_meta("count_tween"):
		var old: Variant = label.get_meta("count_tween")
		if old is Tween and (old as Tween).is_valid():
			(old as Tween).kill()
	if dur <= 0.0 or from == to:
		label.text = fmt % to
		return
	var tw: Tween = label.create_tween()
	label.set_meta("count_tween", tw)
	tw.tween_method(_set_count.bind(label, fmt), float(from), float(to), dur) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_set_final.bind(label, fmt, to))


static func _set_count(value: float, label: Label, fmt: String) -> void:
	if is_instance_valid(label):
		label.text = fmt % int(round(value))


static func _set_final(label: Label, fmt: String, to: int) -> void:
	if is_instance_valid(label):
		label.text = fmt % to
