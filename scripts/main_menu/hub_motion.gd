extends RefCounted
## Movimento do hub: entrada escalonada das placas, pop do JOGAR e bounce de toque.
## Helpers estáticos pequenos; o hub só chama. Tudo por Tween (nada em `_process`).
## Os Controls das colunas são filhos de VBoxContainer: a posição final é lida depois
## do layout assentar e o tween sempre termina nela, então um re-sort do container
## no meio da entrada não deixa nada fora do lugar.

const SLIDE := 40.0
const STAGGER := 0.05
const PLATE_TIME := 0.35
const BOTTOM_RISE := 24.0
const BOTTOM_TIME := 0.4
const FADE_TIME := 0.3
const POP_FROM := Vector2(1.06, 1.06)
const POP_TIME := 0.25
const PRESS_SCALE := Vector2(0.96, 0.96)
const PRESS_TIME := 0.06
const RELEASE_TIME := 0.22
const _META := &"hub_bounce_tween"


## Estado inicial da entrada: tudo invisível antes do primeiro frame (sem flash "pronto").
static func hide_for_intro(items: Array) -> void:
	for n in items:
		var c := n as CanvasItem
		if c != null:
			c.modulate.a = 0.0


## Dispara a entrada. `left`/`right`: placas; `fades`: nós que só fazem fade (caçador, nome);
## `bottom`: barra inferior; `play`: botão que termina com o pop.
static func play_intro(owner: Node, left: Array, right: Array, fades: Array,
		bottom: Control, play: Control) -> Tween:
	var tw: Tween = owner.create_tween().set_parallel(true)
	_slide_group(tw, left, -SLIDE, 0.0)
	_slide_group(tw, right, SLIDE, 0.0)
	for n in fades:
		_fade_in(tw, n as CanvasItem, 0.0)
	_rise_bottom(tw, bottom)
	_pop_play(tw, play)
	return tw


static func _slide_group(tw: Tween, nodes: Array, dx: float, delay0: float) -> void:
	for i in range(nodes.size()):
		var c := nodes[i] as Control
		if c == null:
			continue
		var final_pos: Vector2 = c.position
		c.position = final_pos + Vector2(dx, 0.0)
		var delay: float = delay0 + STAGGER * float(i)
		tw.tween_property(c, "position", final_pos, PLATE_TIME) \
			.set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_fade_in(tw, c, delay, PLATE_TIME)


static func _fade_in(tw: Tween, c: CanvasItem, delay: float, time: float = FADE_TIME) -> void:
	if c == null:
		return
	tw.tween_property(c, "modulate:a", 1.0, time).set_delay(delay)


static func _rise_bottom(tw: Tween, bottom: Control) -> void:
	if bottom == null:
		return
	var final_pos: Vector2 = bottom.position
	bottom.position = final_pos + Vector2(0.0, BOTTOM_RISE)
	tw.tween_property(bottom, "position", final_pos, BOTTOM_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_fade_in(tw, bottom, 0.0, BOTTOM_TIME)


## JOGAR: depois que tudo entrou, um pop 1.06 -> 1.0 com pivô central.
static func _pop_play(tw: Tween, play: Control) -> void:
	if play == null:
		return
	play.pivot_offset = play.size * 0.5
	tw.chain().tween_property(play, "scale", Vector2.ONE, POP_TIME) \
		.from(POP_FROM).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## --- Bounce de toque ------------------------------------------------------

static func bind_bounce(btn: BaseButton) -> void:
	if btn == null:
		return
	btn.button_down.connect(_on_down.bind(btn))
	btn.button_up.connect(_on_up.bind(btn))


static func _on_down(btn: BaseButton) -> void:
	_scale_to(btn, PRESS_SCALE, PRESS_TIME, Tween.TRANS_SINE)


static func _on_up(btn: BaseButton) -> void:
	_scale_to(btn, Vector2.ONE, RELEASE_TIME, Tween.TRANS_BACK)


static func _scale_to(btn: BaseButton, target: Vector2, time: float, trans: Tween.TransitionType) -> void:
	if not is_instance_valid(btn):
		return
	var old: Variant = btn.get_meta(_META, null)
	if old is Tween and (old as Tween).is_valid():
		(old as Tween).kill()
	btn.pivot_offset = btn.size * 0.5
	var tw: Tween = btn.create_tween()
	tw.tween_property(btn, "scale", target, time).set_trans(trans).set_ease(Tween.EASE_OUT)
	btn.set_meta(_META, tw)
