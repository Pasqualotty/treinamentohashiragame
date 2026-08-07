extends Area2D
## Portal / goal no fim da fase. Emite `reached` quando o player entra.
## Visual: FECHADA legível; pulse/glow quando desbloqueado.

signal reached(body: Node2D)

@export var one_shot: bool = true

var _fired: bool = false
var _locked: bool = true
var _pulse_tween: Tween
var _scale_tween: Tween


func _ready() -> void:
	monitorable = false
	# Player sandbox = layer 2; player move = layer 1 — aceita ambos.
	if collision_mask == 0:
		collision_mask = 1 | 2
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	# Começa trancado; StageController chama set_locked(false) quando as ondas acabam
	# (ou logo no ready se use_waves=false / lock desligado).
	set_locked(true)


func is_locked() -> bool:
	return _locked


## Trava/destrava o portal (monitoring + visual + pulse).
func set_locked(locked: bool) -> void:
	_locked = locked
	monitoring = not locked
	visible = true
	_apply_visual_locked(locked)
	if locked:
		_stop_pulse()
	else:
		_start_pulse()


func _apply_visual_locked(locked: bool) -> void:
	var label := get_node_or_null("Label") as Label
	if label:
		if locked:
			label.text = "FECHADA"
			label.add_theme_font_size_override("font_size", 18)
			label.add_theme_color_override("font_color", Color(1.0, 0.38, 0.32, 1.0))
			label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
			label.add_theme_color_override("font_outline_color", Color(0.15, 0.02, 0.02, 0.95))
			label.add_theme_constant_override("shadow_offset_x", 2)
			label.add_theme_constant_override("shadow_offset_y", 2)
			label.add_theme_constant_override("outline_size", 3)
		else:
			label.text = "SAIDA"
			label.add_theme_font_size_override("font_size", 18)
			label.add_theme_color_override("font_color", Color(0.55, 1.0, 0.95, 1.0))
			label.add_theme_color_override("font_shadow_color", Color(0, 0.15, 0.2, 0.9))
			label.add_theme_color_override("font_outline_color", Color(0.02, 0.12, 0.15, 0.9))
			label.add_theme_constant_override("shadow_offset_x", 2)
			label.add_theme_constant_override("shadow_offset_y", 2)
			label.add_theme_constant_override("outline_size", 2)

	var glow := get_node_or_null("PortalGlow") as CanvasItem
	if glow:
		glow.modulate = Color(0.45, 0.45, 0.5, 0.55) if locked else Color(0.75, 1.15, 1.35, 1.0)

	var vis := get_node_or_null("PortalVisual") as CanvasItem
	if vis:
		vis.modulate = Color(0.38, 0.38, 0.42, 0.5) if locked else Color(1.05, 1.15, 1.2, 1.0)


func _start_pulse() -> void:
	_stop_pulse()
	var glow := get_node_or_null("PortalGlow") as CanvasItem
	var vis := get_node_or_null("PortalVisual") as CanvasItem
	if glow:
		glow.modulate = Color(0.7, 1.05, 1.25, 0.85)
		_pulse_tween = create_tween().set_loops()
		_pulse_tween.tween_property(glow, "modulate", Color(0.95, 1.25, 1.45, 1.0), 0.55) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_pulse_tween.tween_property(glow, "modulate", Color(0.7, 1.05, 1.25, 0.75), 0.55) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if vis is Control:
		var c := vis as Control
		c.pivot_offset = c.size * 0.5
		var base_scale := Vector2.ONE
		c.scale = base_scale
		_scale_tween = create_tween().set_loops()
		_scale_tween.tween_property(c, "scale", base_scale * 1.08, 0.55) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_scale_tween.tween_property(c, "scale", base_scale, 0.55) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	elif vis is Node2D:
		var n2 := vis as Node2D
		var base_s := Vector2.ONE
		n2.scale = base_s
		_scale_tween = create_tween().set_loops()
		_scale_tween.tween_property(n2, "scale", base_s * 1.08, 0.55) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_scale_tween.tween_property(n2, "scale", base_s, 0.55) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_pulse() -> void:
	if _pulse_tween != null and is_instance_valid(_pulse_tween):
		_pulse_tween.kill()
	_pulse_tween = null
	if _scale_tween != null and is_instance_valid(_scale_tween):
		_scale_tween.kill()
	_scale_tween = null
	var glow := get_node_or_null("PortalGlow") as CanvasItem
	var vis := get_node_or_null("PortalVisual") as CanvasItem
	if glow and _locked:
		glow.modulate = Color(0.45, 0.45, 0.5, 0.55)
	if vis:
		if vis is Control:
			(vis as Control).scale = Vector2.ONE
		elif vis is Node2D:
			(vis as Node2D).scale = Vector2.ONE
		if _locked:
			vis.modulate = Color(0.38, 0.38, 0.42, 0.5)


func _on_body_entered(body: Node2D) -> void:
	if _locked:
		return
	if _fired and one_shot:
		return
	if body == null or not body.is_in_group("player"):
		return
	_fired = true
	reached.emit(body)
