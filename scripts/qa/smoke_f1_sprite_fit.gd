extends SceneTree
## F1 personagens — escala/pivô por bbox de alpha, camada procedural das anims
## estáticas, 9 PNG de oni distintos, pipeline EnemyAnim e cerimônia de morte.
## Uso: godot --headless --path . -s res://scripts/qa/smoke_f1_sprite_fit.gd

const PLAYER_SCENE := "res://scenes/characters/player/player.tscn"
const HUNTERS: PackedStringArray = [
	"tanjiro", "nezuko", "zenitsu", "inosuke", "tomioka", "rengoku", "shinobu", "kanao",
	"uzui", "tokito", "sanemi", "obanai", "gyomei", "yoriichi", "muzan",
]
const ONI_PNGS: PackedStringArray = [
	"oni_weak_side", "elite_side", "charger_side", "ranged_side", "boss_mist_side",
	"boss_fire_side", "boss_dual_side", "boss_castle_side", "boss_final_side",
]
const ONI_SCENES: PackedStringArray = [
	"oni_weak", "oni_elite", "oni_charger", "oni_ranged", "oni_boss",
	"oni_boss_fire", "oni_boss_dual", "oni_boss_castle", "oni_boss_final",
]
const TARGET_H: float = 160.0
const H_TOL: float = 3.0
const FEET_TOL: float = 2.0

var _failed: int = 0
var _floor: StaticBody2D


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== smoke_f1_sprite_fit ===")
	_make_floor()
	_check_lib_fit()
	_check_lib_json()
	_check_static_pose()
	_check_enemy_anim_paths()
	_check_enemy_death_plan()
	await _check_hunters()
	await _check_duel_height()
	await _check_static_flags()
	_check_oni_assets()
	await _check_oni_scenes()
	await _check_oni_death("oni_weak", false)
	await _check_oni_death("oni_boss_fire", true)
	if _failed > 0:
		print("=== F1 SPRITE_FIT FAIL === falhas=%d" % _failed)
		quit(1)
		return
	print("=== F1 SPRITE_FIT PASS ===")
	quit(0)


func _fail(msg: String) -> void:
	_failed += 1
	push_error("[f1] %s" % msg)
	print("  FAIL %s" % msg)


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		_fail(msg)


func _near(a: float, b: float, tol: float, msg: String) -> void:
	if absf(a - b) > tol:
		_fail("%s: %f != %f (tol %f)" % [msg, a, b, tol])


# ---------------------------------------------------------------- lib pura
func _check_lib_fit() -> void:
	var tex: Vector2i = Vector2i(512, 512)
	var used: Rect2i = Rect2i(150, 24, 212, 465)
	_near(SpriteFit.scale_for(used, tex, 160.0), 160.0 / 465.0, 0.00001, "scale_for bbox")
	var feet: Vector2 = SpriteFit.feet_vector(used, tex)
	_near(feet.x, 0.0, 0.001, "feet.x centrado")
	_near(feet.y, 489.0 - 256.0, 0.001, "feet.y = fundo do bbox - centro")
	# bbox descentrado: feet.x segue o centro do bbox
	var off: Vector2 = SpriteFit.feet_vector(Rect2i(300, 0, 100, 400), tex)
	_near(off.x, 350.0 - 256.0, 0.001, "feet.x descentrado")
	# bordas: vazio / fora da textura -> textura inteira; target 0 -> 0
	_near(SpriteFit.scale_for(Rect2i(), tex, 160.0), 160.0 / 512.0, 0.00001, "bbox vazio usa textura")
	_near(SpriteFit.scale_for(Rect2i(900, 900, 10, 10), tex, 160.0), 160.0 / 512.0, 0.00001, "bbox fora")
	_near(SpriteFit.scale_for(used, tex, 0.0), 0.0, 0.00001, "target 0")
	_near(SpriteFit.scale_for(used, tex, -5.0), 0.0, 0.00001, "target negativo")
	_near(SpriteFit.scale_for(used, Vector2i.ZERO, 160.0), 0.0, 0.00001, "textura 0")
	_near(SpriteFit.feet_vector(Rect2i(), tex).y, 256.0, 0.001, "feet bbox vazio = base da textura")
	# flip espelha só o x
	var fl: Vector2 = SpriteFit.flip_vector(Vector2(10.0, 200.0), true)
	_expect(fl == Vector2(-10.0, 200.0), "flip_vector true")
	_expect(SpriteFit.flip_vector(Vector2(10.0, 200.0), false) == Vector2(10.0, 200.0), "flip_vector false")
	# center_for: sem rotação, pés ficam em feet_pos; com 90 graus o vetor gira
	var c: Vector2 = SpriteFit.center_for(Vector2(5, 0), Vector2(0, 232), Vector2(0.5, 0.5), 0.0)
	_expect(c.is_equal_approx(Vector2(5, -116)), "center_for sem rotação %s" % c)
	var cr: Vector2 = SpriteFit.center_for(Vector2.ZERO, Vector2(0, 100), Vector2.ONE, PI * 0.5)
	_expect(cr.is_equal_approx(Vector2(100, 0)), "center_for rot 90 %s" % cr)
	var fit: Dictionary = SpriteFit.fit(used, tex, 160.0)
	_expect(fit.has("scale") and fit.has("feet"), "fit devolve scale+feet")


func _check_lib_json() -> void:
	var r: Rect2i = SpriteFit.rect_from_json('{"x":34,"y":70,"w":444,"h":419,"tex_w":512,"tex_h":512}')
	_expect(r == Rect2i(34, 70, 444, 419), "rect_from_json válido %s" % r)
	_expect(SpriteFit.rect_from_json("123").size == Vector2i.ZERO, "json inválido")
	_expect(SpriteFit.rect_from_json("[1,2]").size == Vector2i.ZERO, "json não-dict")
	_expect(SpriteFit.rect_from_json('{"x":1,"y":2,"w":3}').size == Vector2i.ZERO, "json sem h")
	_expect(SpriteFit.rect_from_json('{"x":"a","y":2,"w":3,"h":4}').size == Vector2i.ZERO, "json tipo errado")


func _check_static_pose() -> void:
	_expect(StaticPose.is_static(1) and StaticPose.is_static(2) and StaticPose.is_static(0), "is_static <=2")
	_expect(not StaticPose.is_static(3) and not StaticPose.is_static(7), "não-estático >=3")
	var lo: float = 9.0
	var hi: float = 0.0
	for i in 240:
		var p: Dictionary = StaticPose.idle(float(i) * 0.01, 0.0)
		lo = minf(lo, float(p["sy"]))
		hi = maxf(hi, float(p["sy"]))
		_expect(absf(float(p["x"])) <= StaticPose.IDLE_SWAY_PX + 0.001, "sway dentro de ±1.5")
		_expect(absf(float(p["rot"])) <= StaticPose.IDLE_ROCK_DEG + 0.001, "rotação dentro de ±0.6")
	_near(lo, 1.0, 0.002, "idle sy mínimo 1.0")
	_near(hi, 1.03, 0.002, "idle sy máximo 1.03")
	var a: Dictionary = StaticPose.idle(0.7, 0.0)
	var b: Dictionary = StaticPose.idle(0.7, 2.1)
	_expect(not is_equal_approx(float(a["sy"]), float(b["sy"])), "fase dessincroniza instâncias")
	# skill: antecipação em 0.08 s, lunge de 10 px, hitbox só liga depois do startup
	var ant: Dictionary = StaticPose.skill(0.08, 0.1, 0.14, 0.2)
	_near(float(ant["sx"]), 0.9, 0.001, "antecipação sx 0.9")
	_near(float(ant["sy"]), 1.08, 0.001, "antecipação sy 1.08")
	var pico: Dictionary = StaticPose.skill(0.1 + 0.07, 0.1, 0.14, 0.2)
	_near(float(pico["x"]), 10.0, 0.001, "lunge 10 px")
	var curto: Dictionary = StaticPose.skill(0.03, 0.04, 0.1, 0.2)
	_expect(float(curto["sx"]) < 1.0, "antecipação respeita startup curto")
	var ft: Dictionary = StaticPose.skill(0.1 + 0.14 + 0.05, 0.1, 0.14, 0.2)
	_expect(float(ft["x"]) > 0.0 and float(ft["x"]) < 14.0, "follow-through em curso")
	var fim: Dictionary = StaticPose.skill(5.0, 0.1, 0.14, 0.2)
	_expect(float(fim["x"]) == 0.0 and float(fim["sx"]) == 1.0, "volta ao neutro")
	var zero: Dictionary = StaticPose.skill(0.0, 0.0, 0.0, 0.0)
	_expect(is_finite(float(zero["x"])), "durações zero não dão NaN")
	var d0: Dictionary = StaticPose.dash(1.0, true)
	var d1: Dictionary = StaticPose.dash(1.0, false)
	_expect(float(d1["sx"]) > float(d0["sx"]), "dash sem frames estica mais")
	_near(float(StaticPose.dash(0.0, false)["sx"]), 1.0, 0.001, "dash relaxa em 1.0")


func _check_enemy_anim_paths() -> void:
	var fake_has: Callable = func(p: String) -> bool:
		return p.begins_with("res://assets/characters/enemies/elite/walk/") and (
			p.ends_with("/00.png") or p.ends_with("/01.png") or p.ends_with("/02.png")
		)
	var found: Array[String] = EnemyAnim.frame_paths("elite", "walk", fake_has)
	_expect(found.size() == 3, "3 frames resolvidos (%d)" % found.size())
	if found.size() == 3:
		_expect(found[0] == "res://assets/characters/enemies/elite/walk/00.png", "caminho 00 %s" % found[0])
		_expect(found[2].ends_with("/02.png"), "caminho 02")
	var none: Callable = func(_p: String) -> bool: return false
	_expect(EnemyAnim.frame_paths("elite", "walk", none).is_empty(), "sem pasta = vazio")
	var gap: Callable = func(p: String) -> bool: return p.ends_with("/00.png") or p.ends_with("/02.png")
	_expect(EnemyAnim.frame_paths("weak", "idle", gap).size() == 1, "para no primeiro buraco")
	var all: Callable = func(_p: String) -> bool: return true
	_expect(EnemyAnim.frame_paths("weak", "idle", all).size() == EnemyAnim.MAX_FRAMES, "teto de frames")
	_expect(EnemyAnim.frame_index(4, 0.0, 10.0, true) == 0, "frame 0 em t=0")
	_expect(EnemyAnim.frame_index(4, 0.35, 10.0, true) == 3, "frame 3 em 0.35s")
	_expect(EnemyAnim.frame_index(4, 0.45, 10.0, true) == 0, "loop volta")
	_expect(EnemyAnim.frame_index(4, 5.0, 10.0, false) == 3, "sem loop trava no último")
	_expect(EnemyAnim.frame_index(0, 1.0, 10.0, true) == 0, "sem frames = 0")
	_expect(EnemyAnim.anim_for("patrol", true, false) == "walk", "patrol andando")
	_expect(EnemyAnim.anim_for("chase", false, false) == "idle", "chase parado")
	_expect(EnemyAnim.anim_for("telegraph", false, false) == "telegraph", "telegraph")
	_expect(EnemyAnim.anim_for("slam", false, false) == "attack", "slam vira attack")
	_expect(EnemyAnim.anim_for("charge", true, false) == "attack", "charge vira attack")
	_expect(EnemyAnim.anim_for("attack", false, true) == "hurt", "hurt sobrepõe")
	_expect(EnemyAnim.anim_for("dead", true, true) == "death", "dead vence")
	_expect(EnemyAnim.anim_for("recover", false, false) == "idle", "recover idle")
	_near(EnemyAnim.pip_offset_y(null), -78.0, 0.001, "pip sem label")
	var lab: Label = Label.new()
	lab.offset_bottom = -150.0
	_near(EnemyAnim.pip_offset_y(lab), -150.0, 0.001, "pip no label")
	lab.free()
	# nenhuma pasta existe hoje: create não carrega nada e update não toca o sprite
	var ea: EnemyAnim = EnemyAnim.create("weak")
	_expect(not ea.has_any(), "sem arte: has_any falso")
	var spr: Sprite2D = Sprite2D.new()
	ea.update(spr, "walk", 0.1)
	_expect(spr.texture == null, "update sem clipe não mexe no sprite")
	spr.free()


func _check_enemy_death_plan() -> void:
	var n: Dictionary = EnemyDeath.plan(1.0, false)
	_near(float(n["dur"]), 0.35, 0.0001, "morte normal 0.35 s")
	_near(float(n["rot_deg"]), 12.0, 0.0001, "tomba 12° para a direita")
	_near(float(n["drop_px"]), 6.0, 0.0001, "queda 6 px")
	_near(float(n["poof_at"]), 0.175, 0.0001, "poof no meio")
	_expect(not bool(n["flash"]), "oni comum sem flash")
	var b: Dictionary = EnemyDeath.plan(-1.0, true)
	_near(float(b["dur"]), 0.7, 0.0001, "chefe 2x mais lento")
	_near(float(b["rot_deg"]), -12.0, 0.0001, "tomba para a esquerda")
	_expect(bool(b["flash"]), "chefe com flash")
	_expect(float(EnemyDeath.plan(0.0, false)["rot_deg"]) == 12.0, "knock 0 -> default direita")
	_expect(EnemyDeath.knock_dir(-50.0, 1.0) == -1.0, "knock pelo velocity")
	_expect(EnemyDeath.knock_dir(0.0, -1.0) == 1.0, "sem knock cai pra trás")
	_expect(EnemyDeath.knock_dir(0.0, 0.0) == 1.0, "sem knock nem facing")


# ---------------------------------------------------------------- player
## Chão com topo em y=0: o player nasce em (0,0) e fica em IDLE (sem queda/JUMP).
func _make_floor() -> void:
	_floor = StaticBody2D.new()
	_floor.collision_layer = 1
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(4000, 40)
	shape.shape = rect
	_floor.position = Vector2(0, 20)
	_floor.add_child(shape)
	root.add_child(_floor)


func _settle() -> void:
	for i in 4:
		await physics_frame


func _spawn_hunter(id: String) -> Node2D:
	var packed: PackedScene = load(PLAYER_SCENE) as PackedScene
	var p: Node2D = packed.instantiate() as Node2D
	p.set("forced_character_id", id)
	p.set("skip_local_upgrades", true)
	return p


## Altura real = bbox de alpha do 1o frame de idle x escala; pés = fundo do bbox no mundo.
func _measure(p: Node2D) -> Dictionary:
	var spr: AnimatedSprite2D = p.get("sprite") as AnimatedSprite2D
	var tex: Texture2D = spr.sprite_frames.get_frame_texture(&"idle", 0)
	var used: Rect2i = tex.get_image().get_used_rect()
	var base: float = float(p.get("_base_sprite_scale"))
	var local_bottom: Vector2 = Vector2(
		float(used.position.x) + float(used.size.x) * 0.5 - float(tex.get_width()) * 0.5,
		float(used.end.y) - float(tex.get_height()) * 0.5
	)
	if spr.flip_h:
		local_bottom.x = -local_bottom.x
	var feet_world: Vector2 = spr.global_position + (local_bottom * spr.scale).rotated(spr.rotation)
	return {"h": float(used.size.y) * base, "feet": feet_world - p.global_position}


func _check_hunters() -> void:
	for id: String in HUNTERS:
		var p: Node2D = _spawn_hunter(id)
		root.add_child(p)
		await _settle()
		var m: Dictionary = _measure(p)
		_near(float(m["h"]), TARGET_H, H_TOL, "%s altura visual" % id)
		var feet: Vector2 = m["feet"]
		_near(feet.y, 0.0, FEET_TOL, "%s pés em y=0" % id)
		_near(feet.x, 0.0, FEET_TOL + 1.0, "%s centro em x=0" % id)
		p.queue_free()
		await process_frame


func _check_duel_height() -> void:
	var p: Node2D = _spawn_hunter("rengoku")
	p.set("visual_height_px", 220.0)
	root.add_child(p)
	await _settle()
	var m: Dictionary = _measure(p)
	_near(float(m["h"]), 220.0, H_TOL, "duelo visual_height_px=220")
	_near((m["feet"] as Vector2).y, 0.0, FEET_TOL, "duelo pés em y=0")
	p.queue_free()
	await process_frame


func _check_static_flags() -> void:
	var rengoku: Node2D = _spawn_hunter("rengoku")
	var tanjiro: Node2D = _spawn_hunter("tanjiro")
	root.add_child(rengoku)
	root.add_child(tanjiro)
	await _settle()
	_expect(bool(rengoku.call("_anim_is_static", &"idle")), "idle do rengoku é estático")
	_expect(bool(rengoku.call("_anim_is_static", &"skill_1")), "skill_1 do rengoku é estática")
	_expect(not bool(rengoku.call("_anim_is_static", &"run")), "run do rengoku não é estático")
	_expect(not bool(tanjiro.call("_anim_is_static", &"idle")), "idle do tanjiro NÃO é estático")
	_expect(not bool(tanjiro.call("_anim_is_static", &"skill_1")), "skill_1 do tanjiro NÃO é estática")
	_expect(not bool(rengoku.call("_anim_is_static", &"inexistente")), "anim inexistente não é estática")
	# idle estático respira: sy varia ao longo de 1.2 s
	var spr: AnimatedSprite2D = rengoku.get("sprite") as AnimatedSprite2D
	var lo: float = 9.0
	var hi: float = 0.0
	for i in 80:
		await physics_frame
		lo = minf(lo, spr.scale.y)
		hi = maxf(hi, spr.scale.y)
	_expect(hi / lo > 1.012, "rengoku respira no idle (razão %f)" % (hi / lo))
	rengoku.queue_free()
	tanjiro.queue_free()
	await process_frame


# ---------------------------------------------------------------- onis
func _check_oni_assets() -> void:
	for n: String in ONI_PNGS:
		var path: String = "res://assets/characters/enemies/%s.png" % n
		_expect(ResourceLoader.exists(path), "PNG existe %s" % n)
		var tex: Texture2D = load(path) as Texture2D
		_expect(tex != null and tex.get_width() == 1024 and tex.get_height() == 1024, "PNG carrega 1024² %s" % n)
	# silhuetas diferentes: bbox solido distinto do oni base nas 8 variantes
	var base_rect: Rect2i = _solid_rect("oni_weak_side")
	for n: String in ONI_PNGS.slice(1):
		_expect(_solid_rect(n) != base_rect, "silhueta de %s difere do oni base" % n)


func _solid_rect(n: String) -> Rect2i:
	var img: Image = (load("res://assets/characters/enemies/%s.png" % n) as Texture2D).get_image()
	var xs: int = 99999
	var xe: int = -1
	var ys: int = 99999
	var ye: int = -1
	for y in range(0, 1024, 4):
		for x in range(0, 1024, 4):
			if img.get_pixel(x, y).a > 0.8:
				xs = mini(xs, x)
				xe = maxi(xe, x)
				ys = mini(ys, y)
				ye = maxi(ye, y)
	return Rect2i(xs, ys, xe - xs, ye - ys)


func _check_oni_scenes() -> void:
	var seen: Dictionary = {}
	for n: String in ONI_SCENES:
		var packed: PackedScene = load("res://scenes/characters/enemies/%s.tscn" % n) as PackedScene
		var oni: Node2D = packed.instantiate() as Node2D
		root.add_child(oni)
		await process_frame
		var spr: Sprite2D = oni.get("sprite") as Sprite2D
		_expect(spr != null and spr.texture != null, "%s tem sprite" % n)
		if spr != null and spr.texture != null:
			var tpath: String = spr.texture.resource_path
			_expect(not seen.has(tpath), "%s usa textura própria (%s)" % [n, tpath])
			seen[tpath] = true
			# pés em y=0: fundo do desenho (y=909 na textura) cai no chão do corpo
			var base_pos: Vector2 = oni.get("_sprite_base_pos") as Vector2
			var base_scale: Vector2 = oni.get("_sprite_base_scale") as Vector2
			var feet_y: float = base_pos.y + (909.0 - 512.0) * base_scale.y
			_near(feet_y, 0.0, 1.0, "%s pés do oni em y=0" % n)
			_expect(spr.modulate.is_equal_approx(Color.WHITE), "%s sem tint de modulate" % n)
		var kind: String = str(oni.get("anim_kind"))
		_expect(kind != "" and not seen.has("kind:" + kind), "%s anim_kind único (%s)" % [n, kind])
		seen["kind:" + kind] = true
		oni.queue_free()
		await process_frame


## Morte com cerimônia: `defeated` 1x, moeda 1x, tomba 12° no sentido do knock,
## esmaece e some depois da duração (chefe = 2x).
func _check_oni_death(scene: String, boss: bool) -> void:
	var packed: PackedScene = load("res://scenes/characters/enemies/%s.tscn" % scene) as PackedScene
	var oni: Node2D = packed.instantiate() as Node2D
	if boss:
		oni.set("skip_intro", true)
	root.add_child(oni)
	await process_frame
	var spr: Sprite2D = oni.get("sprite") as Sprite2D
	var counter: Array[int] = [0]
	oni.connect("defeated", func() -> void: counter[0] += 1)
	var moedas_antes: int = _count_coins()
	oni.set("velocity", Vector2(-120.0, 0.0))
	oni.call("_on_defeated")
	oni.call("_on_defeated")
	_expect(counter[0] == 1, "%s: defeated emitido 1x (%d)" % [scene, counter[0]])
	var dur: float = 0.7 if boss else 0.35
	await create_timer(dur + 0.05).timeout
	_expect(_count_coins() == moedas_antes + 1, "%s: 1 coin_pickup (%d)" % [scene, _count_coins() - moedas_antes])
	if is_instance_valid(oni):
		_near(rad_to_deg(spr.rotation), -12.0, 0.6, "%s tomba 12° para o lado do knock" % scene)
		_expect(spr.modulate.a < 0.05, "%s esmaeceu (a=%f)" % [scene, spr.modulate.a])
	await create_timer(0.9).timeout
	_expect(not is_instance_valid(oni), "%s some depois da cerimônia" % scene)
	for c: Node in root.get_children():
		if c.scene_file_path.contains("coin_pickup"):
			c.queue_free()
	await process_frame


func _count_coins() -> int:
	var n: int = 0
	for c: Node in root.get_children():
		if c.scene_file_path.contains("coin_pickup"):
			n += 1
	return n
