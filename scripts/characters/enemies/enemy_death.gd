class_name EnemyDeath
extends RefCounted
## Morte de oni com cerimônia: o corpo tomba (12° no sentido do knock + queda de
## 6 px), dessatura/esmaece em 0.35 s e o poof dispara no meio. Chefe = 2x mais
## lento + flash branco. NÃO mexe no sinal `defeated` nem no coin_pickup — isso
## continua no script do oni (só o pickup credita moeda).

const DURATION: float = 0.35
const BOSS_SLOWDOWN: float = 2.0
const TILT_DEG: float = 12.0
const DROP_PX: float = 6.0
const FADE_TO: Color = Color(0.52, 0.52, 0.58, 0.0)
const BOSS_FLASH: Color = Color(1.0, 1.0, 1.0, 0.75)


## Plano puro da morte: {dur, rot_deg, drop_px, poof_at, flash}.
static func plan(knock_dir: float, boss: bool) -> Dictionary:
	var dir: float = signf(knock_dir) if not is_zero_approx(knock_dir) else 1.0
	var dur: float = DURATION * (BOSS_SLOWDOWN if boss else 1.0)
	return {"dur": dur, "rot_deg": TILT_DEG * dir, "drop_px": DROP_PX, "poof_at": dur * 0.5, "flash": boss}


## Sentido do knock: velocity.x do hit; sem knock, tomba para trás do facing.
static func knock_dir(velocity_x: float, facing: float) -> float:
	if not is_zero_approx(velocity_x):
		return signf(velocity_x)
	return -signf(facing) if not is_zero_approx(facing) else 1.0


## Toca a cerimônia no `sprite`; `on_poof` roda no meio. Devolve a duração.
static func play(
	host: Node, sprite: Sprite2D, knock: float, boss: bool, on_poof: Callable, frames: EnemyAnim = null
) -> float:
	var p: Dictionary = plan(knock, boss)
	var dur: float = float(p["dur"])
	if host == null or not host.is_inside_tree():
		return dur
	if bool(p["flash"]):
		_flash_white(host)
	if sprite != null:
		var tw: Tween = host.create_tween()
		tw.set_parallel(true)
		tw.tween_property(sprite, "rotation", deg_to_rad(float(p["rot_deg"])), dur) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(sprite, "position:y", sprite.position.y + float(p["drop_px"]), dur) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(sprite, "modulate", FADE_TO, dur)
		if frames != null and frames.has_clip("death"):
			tw.tween_method(func(t: float) -> void: frames.scrub(sprite, "death", t), 0.0, 1.0, dur)
	if on_poof.is_valid():
		host.get_tree().create_timer(float(p["poof_at"])).timeout.connect(on_poof)
	return dur


static func _flash_white(host: Node) -> void:
	var fx: Node = host.get_node_or_null("/root/Fx")
	if fx != null and fx.has_method("flash"):
		fx.call("flash", BOSS_FLASH, 0.22)
