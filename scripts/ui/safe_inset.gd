class_name SafeInset
extends RefCounted
## Empurra um Control raiz para a área segura do display (notch, canto, barra de gesto).
## Não troca `window/stretch/aspect=expand` — só offset em px do viewport.
## No desktop a safe area cobre a janela inteira: não empurra.


static func apply(ctrl: Control) -> void:
	if ctrl == null or not is_instance_valid(ctrl):
		return
	_write_offsets(ctrl, _viewport_pad(ctrl.get_viewport()))


static func apply_canvas_layer(layer: CanvasLayer) -> void:
	if layer == null or not is_instance_valid(layer):
		return
	for child in layer.get_children():
		var ctrl := child as Control
		if ctrl != null and _is_full_rect(ctrl):
			apply(ctrl)


static func _write_offsets(ctrl: Control, pad: Vector4) -> void:
	if pad == Vector4.ZERO:
		return
	ctrl.offset_left = pad.x
	ctrl.offset_top = pad.y
	ctrl.offset_right = -pad.z
	ctrl.offset_bottom = -pad.w


static func _is_full_rect(ctrl: Control) -> bool:
	return is_equal_approx(ctrl.anchor_left, 0.0) \
		and is_equal_approx(ctrl.anchor_top, 0.0) \
		and is_equal_approx(ctrl.anchor_right, 1.0) \
		and is_equal_approx(ctrl.anchor_bottom, 1.0)


## left, top, right, bottom em px do viewport visível (já com stretch expand).
static func _viewport_pad(vp: Viewport) -> Vector4:
	if vp == null:
		return Vector4.ZERO
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	var win := Rect2i(DisplayServer.window_get_position(), DisplayServer.window_get_size())
	if win.size.x <= 0 or win.size.y <= 0:
		return Vector4.ZERO
	if safe.size.x <= 0 or safe.size.y <= 0:
		return Vector4.ZERO
	# Janela inteira já está na safe area (PC, janela, sem notch).
	if safe.encloses(win) or safe == win:
		return Vector4.ZERO
	var left_px: int = maxi(0, safe.position.x - win.position.x)
	var top_px: int = maxi(0, safe.position.y - win.position.y)
	var right_px: int = maxi(0, win.end.x - safe.end.x)
	var bottom_px: int = maxi(0, win.end.y - safe.end.y)
	if left_px == 0 and top_px == 0 and right_px == 0 and bottom_px == 0:
		return Vector4.ZERO
	var vis: Vector2 = vp.get_visible_rect().size
	var sx: float = vis.x / float(win.size.x)
	var sy: float = vis.y / float(win.size.y)
	return Vector4(
		float(left_px) * sx,
		float(top_px) * sy,
		float(right_px) * sx,
		float(bottom_px) * sy
	)
