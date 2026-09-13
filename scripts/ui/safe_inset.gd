class_name SafeInset
extends RefCounted
## Empurra botões e textos para longe do recorte do telefone.
## Não encolhe a tela inteira — isso abre uma faixa preta na lateral.
## Fundo (key art, dim) fica colado na borda. Stretch `expand` não muda.
## No PC a safe area é a janela: não empurra nada.


static func apply(ctrl: Control) -> void:
	if ctrl == null or not is_instance_valid(ctrl):
		return
	var pad: Vector4 = viewport_pad(ctrl.get_viewport())
	if pad == Vector4.ZERO:
		return
	if _is_full_rect(ctrl):
		for child in ctrl.get_children():
			var c := child as Control
			if c == null or _is_backdrop(c):
				continue
			_add_pad(c, pad)
		return
	_add_pad(ctrl, pad)


static func apply_chrome(nodes: Array) -> void:
	var pad: Vector4 = Vector4.ZERO
	for item in nodes:
		var ctrl := item as Control
		if ctrl == null or not is_instance_valid(ctrl):
			continue
		if pad == Vector4.ZERO:
			pad = viewport_pad(ctrl.get_viewport())
			if pad == Vector4.ZERO:
				return
		if _is_backdrop(ctrl):
			continue
		_add_pad(ctrl, pad)


static func apply_canvas_layer(layer: CanvasLayer) -> void:
	if layer == null or not is_instance_valid(layer):
		return
	var pad: Vector4 = Vector4.ZERO
	for child in layer.get_children():
		var ctrl := child as Control
		if ctrl == null or not _is_full_rect(ctrl):
			continue
		if pad == Vector4.ZERO:
			pad = viewport_pad(ctrl.get_viewport())
			if pad == Vector4.ZERO:
				return
		if _is_backdrop(ctrl):
			continue
		_add_pad(ctrl, pad)


static func viewport_pad(vp: Viewport) -> Vector4:
	return _viewport_pad(vp)


static func _add_pad(ctrl: Control, pad: Vector4) -> void:
	ctrl.offset_left += pad.x
	ctrl.offset_top += pad.y
	ctrl.offset_right -= pad.z
	ctrl.offset_bottom -= pad.w


static func _is_full_rect(ctrl: Control) -> bool:
	return is_equal_approx(ctrl.anchor_left, 0.0) \
		and is_equal_approx(ctrl.anchor_top, 0.0) \
		and is_equal_approx(ctrl.anchor_right, 1.0) \
		and is_equal_approx(ctrl.anchor_bottom, 1.0)


static func _is_backdrop(ctrl: Control) -> bool:
	var n := String(ctrl.name)
	if n.begins_with("Bg") or n == "Dim" or n.ends_with("Dim"):
		return true
	if (ctrl is ColorRect or ctrl is TextureRect) and _is_full_rect(ctrl):
		return true
	return false


## left, top, right, bottom em px do viewport visível (já com stretch expand).
static func _viewport_pad(vp: Viewport) -> Vector4:
	if vp == null:
		return Vector4.ZERO
	var os := OS.get_name()
	if os != "Android" and os != "iOS":
		return Vector4.ZERO
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	var win := Rect2i(DisplayServer.window_get_position(), DisplayServer.window_get_size())
	if win.size.x <= 0 or win.size.y <= 0:
		return Vector4.ZERO
	if safe.size.x <= 0 or safe.size.y <= 0:
		return Vector4.ZERO
	if safe.encloses(win) or safe == win:
		return Vector4.ZERO
	var left_px: int = maxi(0, safe.position.x - win.position.x)
	var top_px: int = maxi(0, safe.position.y - win.position.y)
	var right_px: int = maxi(0, win.end.x - safe.end.x)
	var bottom_px: int = maxi(0, win.end.y - safe.end.y)
	if left_px == 0 and top_px == 0 and right_px == 0 and bottom_px == 0:
		return Vector4.ZERO
	var vis: Vector2 = vp.get_visible_rect().size
	if vis.x < 8.0 or vis.y < 8.0:
		return Vector4.ZERO
	var sx: float = vis.x / float(win.size.x)
	var sy: float = vis.y / float(win.size.y)
	var pad := Vector4(
		float(left_px) * sx,
		float(top_px) * sy,
		float(right_px) * sx,
		float(bottom_px) * sy
	)
	# Recorte de telefone é fino. Número grande = conta errada = faixa na lateral.
	var cap_x: float = vis.x * 0.12
	var cap_y: float = vis.y * 0.12
	if pad.x > cap_x or pad.z > cap_x or pad.y > cap_y or pad.w > cap_y:
		return Vector4.ZERO
	return pad
