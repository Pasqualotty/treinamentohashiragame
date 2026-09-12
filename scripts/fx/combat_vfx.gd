class_name CombatVfx
extends RefCounted
## Orquestra juice de impacto/dash em 1 chamada. Player só faz hook curto.
## Autoloads resolvidos via root (seguro em `godot -s` sem identifier global).

const DASH_TICK_SEC: float = 0.028
## dash_tick não spawna mais que isto no autoload Fx por frame.
const MAX_NODES_PER_TICK: int = 2

static var _dash_tick_i: int = 0


static func _root() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop == null or not (loop is SceneTree):
		return null
	return (loop as SceneTree).root


static func _fx() -> Node:
	var r: Node = _root()
	return r.get_node_or_null("Fx") if r else null


static func _audio() -> Node:
	var r: Node = _root()
	return r.get_node_or_null("Audio") if r else null


static func dash_start(pos: Vector2, facing: float, sprite: AnimatedSprite2D) -> void:
	var audio: Node = _audio()
	if audio and audio.has_method("play_sfx"):
		audio.call("play_sfx", "dash", randf_range(0.94, 1.08))
	var fx: Node = _fx()
	if fx == null:
		return
	var f: float = signf(facing) if not is_zero_approx(facing) else 1.0
	var heel: Vector2 = pos + Vector2(-f * 14.0, 6.0)
	if fx.has_method("dust"):
		fx.call("dust", heel, f)
	if fx.has_method("dash_burst"):
		fx.call("dash_burst", heel, f)
	if fx.has_method("afterimage"):
		fx.call("afterimage", sprite)
	if fx.has_method("flash"):
		fx.call("flash", Color(0.55, 0.9, 1.0, 0.10), 0.10)
	_dash_tick_i = 0


static func dash_tick(sprite: Node, pos: Vector2, facing: float) -> void:
	## Afterimage (filho do player, fora do cap) + no máx. 1 dust no Fx.
	var fx: Node = _fx()
	if fx and sprite is AnimatedSprite2D and fx.has_method("afterimage"):
		fx.call("afterimage", sprite)
	_dash_tick_i += 1
	if fx == null:
		return
	if (_dash_tick_i % 2) != 0:
		return
	var f: float = signf(facing) if not is_zero_approx(facing) else 1.0
	if fx.has_method("dust"):
		fx.call("dust", pos + Vector2(-f * 10.0, 6.0), f)


static func swing_slash(pos: Vector2, facing: float, kind: StringName, tint: Color = Color(0, 0, 0, 0)) -> void:
	var fx: Node = _fx()
	if fx and fx.has_method("slash"):
		fx.call("slash", pos, facing, kind, tint)


static func hit_burst(pos: Vector2, kind: StringName, damage: int, crit: bool) -> void:
	var fx: Node = _fx()
	if fx == null:
		return
	var color: Color = Color(1.0, 0.92, 0.82, 1.0)
	var amount: int = 8
	match kind:
		&"skill":
			color = Color(0.357, 0.553, 0.937, 1.0)
			amount = 10
		&"ultimate":
			color = Color(0.910, 0.722, 0.290, 1.0)
			amount = 12
		_:
			color = Color(1.0, 0.92, 0.82, 1.0)
	if crit:
		color = Color(0.910, 0.722, 0.290, 1.0)
		amount = maxi(amount, 11)
	if fx.has_method("spark"):
		fx.call("spark", pos, color, amount)
	if fx.has_method("impact"):
		fx.call("impact", pos)
	if fx.has_method("damage_number"):
		fx.call("damage_number", pos + Vector2(0.0, -18.0), damage, crit)
